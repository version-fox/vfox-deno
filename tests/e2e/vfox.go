// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package e2e

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

const (
	// vfoxVersion is the vfox release the harness pins. Unless VFOX_BIN names
	// another binary, it is downloaded from GitHub.
	vfoxVersion = "1.1.0"

	// vfoxReleaseURL is the GitHub download directory of vfoxVersion.
	vfoxReleaseURL = "https://github.com/version-fox/vfox/releases/download/v" + vfoxVersion + "/"

	// maxVfoxArchive bounds one downloaded archive; the largest pinned one is
	// about 14 MB.
	maxVfoxArchive = 64 << 20

	// commandTimeout bounds one child process, such as a Deno download.
	commandTimeout = 15 * time.Minute
)

// minVfoxVersion is the oldest vfox the harness accepts: `vfox link --detect`
// needs 1.1.0.
var minVfoxVersion = [3]int{1, 1, 0}

// vfoxPin is one published vfox archive: its file name, the SHA-256 of the
// whole archive, and the entry inside it that holds the vfox binary.
type vfoxPin struct {
	Asset  string
	SHA256 string
	Binary string
}

// vfoxPins maps GOOS/GOARCH to the pinned archive of vfoxVersion. The digests
// are those in the release's checksums.txt.
var vfoxPins = map[string]vfoxPin{
	"linux/amd64": {
		Asset:  "vfox_1.1.0_linux_x86_64.tar.gz",
		SHA256: "3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4",
		Binary: "vfox_1.1.0_linux_x86_64/vfox",
	},
	"linux/arm64": {
		Asset:  "vfox_1.1.0_linux_aarch64.tar.gz",
		SHA256: "e702e057dfe588200727dfb3cf786d181b13f015cbcc9e13679a3edcfd07e430",
		Binary: "vfox_1.1.0_linux_aarch64/vfox",
	},
	"windows/amd64": {
		Asset:  "vfox_1.1.0_windows_x86_64.zip",
		SHA256: "1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a",
		Binary: "vfox_1.1.0_windows_x86_64/vfox.exe",
	},
	"windows/arm64": {
		Asset:  "vfox_1.1.0_windows_aarch64.zip",
		SHA256: "67bf5c8b3bde5c1b3fc06dcaa460db9bb1dc9fc587b467d1dc96205377767465",
		Binary: "vfox_1.1.0_windows_aarch64/vfox.exe",
	},
}

// acquireVfox returns the path of the vfox binary to test with. The binary is
// extracted into a fresh directory under dir. VFOX_BIN, when set, must be an
// absolute path to an existing file and wins over the download. Otherwise the
// pinned archive for this GOOS/GOARCH is downloaded, its SHA-256 is checked
// before anything is extracted, and only its vfox binary is kept.
func acquireVfox(t testing.TB, dir string) string {
	t.Helper()
	if bin := os.Getenv("VFOX_BIN"); bin != "" {
		if !filepath.IsAbs(bin) {
			t.Fatalf("VFOX_BIN=%q: want an absolute path to a vfox binary", bin)
		}
		info, err := os.Stat(bin)
		if err != nil {
			t.Fatalf("VFOX_BIN=%q: %v", bin, err)
		}
		if info.IsDir() {
			t.Fatalf("VFOX_BIN=%q is a directory, not a vfox binary", bin)
		}
		t.Logf("vfox: VFOX_BIN %s", bin)
		return bin
	}
	key := runtime.GOOS + "/" + runtime.GOARCH
	pin, ok := vfoxPins[key]
	if !ok {
		t.Fatalf("no pinned vfox %s for %s: set VFOX_BIN to an absolute path of a vfox %s binary",
			vfoxVersion, key, vfoxVersion)
	}
	archive := downloadPinned(t, pin)
	bin, err := extractVfox(archive, pin, dir)
	if err != nil {
		t.Fatalf("extract vfox: %v", err)
	}
	t.Logf("vfox: %s matches its pinned SHA-256; binary extracted to %s", pin.Asset, bin)
	return bin
}

// downloadPinned fetches the archive of pin, retrying the transfer, and fails
// the test unless its SHA-256 is the pinned one.
func downloadPinned(t testing.TB, pin vfoxPin) []byte {
	t.Helper()
	url := vfoxReleaseURL + pin.Asset
	var data []byte
	err := retry(mustRetryAttempts(t), retryWait, t.Logf, func(int) (bool, string) {
		var err error
		data, err = fetch(url)
		if err != nil {
			return false, err.Error()
		}
		return true, ""
	})
	if err != nil {
		t.Fatalf("download %s: %v", url, err)
	}
	if err := checkPin(data, pin); err != nil {
		t.Fatal(err)
	}
	return data
}

// checkPin returns an error unless archive has the SHA-256 that pin records.
// It runs before anything is extracted.
func checkPin(archive []byte, pin vfoxPin) error {
	sum := sha256.Sum256(archive)
	if got := hex.EncodeToString(sum[:]); got != pin.SHA256 {
		return fmt.Errorf("%s: SHA-256 %s does not match the pinned %s", pin.Asset, got, pin.SHA256)
	}
	return nil
}

// fetch returns the body of a GET of url. The body may be at most
// maxVfoxArchive bytes.
func fetch(url string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GET %s: %s", url, resp.Status)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxVfoxArchive+1))
	if err != nil {
		return nil, fmt.Errorf("GET %s: %w", url, err)
	}
	if len(data) > maxVfoxArchive {
		return nil, fmt.Errorf("GET %s: larger than %d bytes", url, maxVfoxArchive)
	}
	return data, nil
}

// extractVfox writes the vfox binary of pin, read from archive, into a fresh
// directory under dir, and returns the binary's path. No other entry is read.
func extractVfox(archive []byte, pin vfoxPin, dir string) (string, error) {
	var bin []byte
	var err error
	switch {
	case strings.HasSuffix(pin.Asset, ".tar.gz"):
		bin, err = readTarGzEntry(archive, pin.Binary)
	case strings.HasSuffix(pin.Asset, ".zip"):
		bin, err = readZipEntry(archive, pin.Binary)
	default:
		return "", fmt.Errorf("%s: unknown archive type", pin.Asset)
	}
	if err != nil {
		return "", fmt.Errorf("%s: %w", pin.Asset, err)
	}
	out, err := os.MkdirTemp(dir, "vfox-bin-")
	if err != nil {
		return "", err
	}
	path := filepath.Join(out, filepath.Base(pin.Binary))
	if err := os.WriteFile(path, bin, 0o755); err != nil {
		return "", err
	}
	return path, nil
}

// readTarGzEntry returns the contents of the regular file name in a gzipped
// tar archive.
func readTarGzEntry(archive []byte, name string) ([]byte, error) {
	gz, err := gzip.NewReader(bytes.NewReader(archive))
	if err != nil {
		return nil, err
	}
	defer gz.Close()
	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, err
		}
		if hdr.Name == name && hdr.Typeflag == tar.TypeReg {
			return io.ReadAll(tr)
		}
	}
	return nil, fmt.Errorf("no entry %q", name)
}

// readZipEntry returns the contents of the file name in a zip archive.
func readZipEntry(archive []byte, name string) ([]byte, error) {
	zr, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
	if err != nil {
		return nil, err
	}
	for _, f := range zr.File {
		if f.Name != name {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return nil, err
		}
		data, err := io.ReadAll(rc)
		rc.Close()
		return data, err
	}
	return nil, fmt.Errorf("no entry %q", name)
}

// harness is the state of one run: the temporary root and the directories in
// it, the vfox binary under test, the environment child processes get, and
// what earlier steps learned for later ones.
type harness struct {
	ctx         context.Context // the test's context; bounds every child process
	attempts    int             // retry budget of network-touching vfox commands
	vfoxBin     string          // absolute path of the vfox under test
	root        string          // temporary root of the run, removed at cleanup
	vfoxHome    string          // VFOX_HOME; its name contains a space
	home        string          // HOME and USERPROFILE
	denoInstall string          // DENO_INSTALL
	workDir     string          // working directory of child processes
	env         []string        // environment of child processes
	pinnedExec  string          // Deno.execPath() of the 2.7.0 install, set by step 5
}

// newHarness creates the run's temporary root and its directories, removes
// the root when the test ends, and fixes the environment of child processes.
func newHarness(t *testing.T) *harness {
	t.Helper()
	root, err := os.MkdirTemp("", "vfox-deno-e2e-")
	if err != nil {
		t.Fatalf("create the temporary root: %v", err)
	}
	t.Cleanup(func() {
		if err := os.RemoveAll(root); err != nil {
			t.Logf("remove %s: %v", root, err)
		}
	})
	h := &harness{
		ctx:         t.Context(),
		attempts:    mustRetryAttempts(t),
		root:        root,
		vfoxHome:    filepath.Join(root, "vfox home"),
		home:        filepath.Join(root, "home"),
		denoInstall: filepath.Join(root, "deno-install"),
		workDir:     filepath.Join(root, "work"),
	}
	for _, dir := range []string{h.vfoxHome, h.home, h.workDir} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	h.env = isolatedEnv(os.Environ(), runtime.GOOS, h.vfoxHome, h.home, h.denoInstall)
	t.Logf("run root %s; VFOX_HOME %s", root, h.vfoxHome)
	return h
}

// isolatedEnv returns base with the variables that point vfox and Deno at the
// run's directories replaced: VFOX_HOME, HOME, USERPROFILE and DENO_INSTALL.
// PATH becomes a fixed list of system directories, so that a host Deno is not
// found by accident. Shell activation state (__VFOX_*) is dropped. Everything
// else is kept, so proxies, tokens and SYSTEMROOT still apply. Names compare
// case-insensitively when goos is windows.
func isolatedEnv(base []string, goos, vfoxHome, home, denoInstall string) []string {
	path := "/usr/bin:/bin"
	if goos == "windows" {
		path = `C:\Windows\System32;C:\Windows`
	}
	set := []string{
		"VFOX_HOME=" + vfoxHome,
		"HOME=" + home,
		"USERPROFILE=" + home,
		"DENO_INSTALL=" + denoInstall,
		"PATH=" + path,
	}
	replaced := make(map[string]bool, len(set))
	for _, kv := range set {
		name, _, _ := strings.Cut(kv, "=")
		replaced[foldFor(goos, name)] = true
	}
	activation := foldFor(goos, "__VFOX_")
	env := make([]string, 0, len(base)+len(set))
	for _, kv := range base {
		name, _, _ := strings.Cut(kv, "=")
		folded := foldFor(goos, name)
		if replaced[folded] || strings.HasPrefix(folded, activation) {
			continue
		}
		env = append(env, kv)
	}
	return append(env, set...)
}

// foldFor lower-cases s when goos is windows, where environment names and
// paths compare case-insensitively, and returns s unchanged otherwise.
func foldFor(goos, s string) string {
	if goos == "windows" {
		return strings.ToLower(s)
	}
	return s
}

// fold is foldFor for the platform the test runs on.
func fold(s string) string {
	return foldFor(runtime.GOOS, s)
}

// commandResult is the outcome of one child process.
type commandResult struct {
	Command  string // the command line, for logs
	ExitCode int    // the exit code; -1 when the process never started or was killed
	Output   string // stdout and stderr together, after cleanOutput
	Err      error  // why the process did not run to an exit code, such as a timeout
}

// ok reports whether the process ran to the end and exited with 0.
func (r commandResult) ok() bool {
	return r.Err == nil && r.ExitCode == 0
}

// String renders the result for logs: the command, its status, then its
// output with progress redraws collapsed.
func (r commandResult) String() string {
	status := fmt.Sprintf("exit %d", r.ExitCode)
	if r.Err != nil {
		status += ": " + r.Err.Error()
	}
	return fmt.Sprintf("$ %s\n%s\n%s", r.Command, status, logText(r.Output))
}

// runVfox runs the vfox binary under test with args, in the isolated
// environment, and waits for it. Stdout and stderr are captured together.
// Stdin is empty, so a prompt fails instead of hanging. It does not fail the
// test: callers decide what an exit code means.
func (h *harness) runVfox(args ...string) commandResult {
	ctx, cancel := context.WithTimeout(h.ctx, commandTimeout)
	defer cancel()
	var buf bytes.Buffer
	cmd := exec.CommandContext(ctx, h.vfoxBin, args...)
	cmd.Dir = h.workDir
	cmd.Env = h.env
	// A killed vfox can leave children, such as a Deno, holding the output
	// pipe open. WaitDelay makes Run return instead of waiting for them.
	cmd.WaitDelay = 30 * time.Second
	cmd.Stdout = &buf
	// The same writer for both streams: os/exec then writes from one goroutine
	// at a time, so buf needs no lock.
	cmd.Stderr = &buf
	res := commandResult{Command: "vfox " + strings.Join(args, " "), ExitCode: -1}
	var exitErr *exec.ExitError
	if err := cmd.Run(); err != nil && !errors.As(err, &exitErr) {
		res.Err = err
	}
	if cmd.ProcessState != nil {
		res.ExitCode = cmd.ProcessState.ExitCode()
	}
	if ctx.Err() != nil {
		res.Err = fmt.Errorf("stopped after %s: %w", commandTimeout, ctx.Err())
	}
	res.Output = cleanOutput(buf.Bytes())
	return res
}

// vfox runs one vfox command, logs it, and returns the result.
func (h *harness) vfox(t testing.TB, args ...string) commandResult {
	t.Helper()
	res := h.runVfox(args...)
	t.Logf("%s", res.String())
	return res
}

// vfoxRetry runs a network-touching vfox command. A non-zero exit is retried,
// up to h.attempts times with the linear backoff of retryWait, and each failed
// attempt's output is logged. The test fails if no attempt succeeds. Use it
// only for failures that are transient, never for an expected failure.
func (h *harness) vfoxRetry(t testing.TB, args ...string) commandResult {
	t.Helper()
	var last commandResult
	err := retry(h.attempts, retryWait, t.Logf, func(int) (bool, string) {
		last = h.runVfox(args...)
		return last.ok(), last.String()
	})
	if err != nil {
		t.Fatalf("%s: %v", last.Command, err)
	}
	t.Logf("%s", last.String())
	return last
}

// ansiEscape matches the CSI and OSC escape sequences vfox writes for colour
// and progress.
var ansiEscape = regexp.MustCompile(`\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)`)

// cleanOutput turns raw child output into text for matching and logging. It
// removes escape sequences, and it turns carriage returns, which progress bars
// use to redraw one line, into line breaks, so that each message is one line.
func cleanOutput(raw []byte) string {
	s := ansiEscape.ReplaceAllString(string(raw), "")
	s = strings.ReplaceAll(s, "\r\n", "\n")
	return strings.ReplaceAll(s, "\r", "\n")
}

// logText prepares cleaned output for a log. It drops blank lines, and of each
// run of download progress lines it keeps only the last.
func logText(s string) string {
	var lines []string
	for _, line := range strings.Split(s, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		if n := len(lines); n > 0 && isProgress(lines[n-1]) && isProgress(line) {
			lines[n-1] = line
			continue
		}
		lines = append(lines, line)
	}
	return strings.Join(lines, "\n")
}

// isProgress reports whether a line is one of vfox's download progress lines.
func isProgress(line string) bool {
	return strings.HasPrefix(line, "Downloading...")
}

var (
	// searchItem matches one version in `vfox search` output, as " - 2.9.8".
	searchItem = regexp.MustCompile(`(?m)^[ \t]*-[ \t]+(\S+)[ \t]*$`)
	// listItem matches one installed version in `vfox list` or `vfox current`
	// output, as "-> 2.9.8" followed by an optional marker.
	listItem = regexp.MustCompile(`(?m)^[ \t]*->[ \t]+(\S+)(.*)$`)
	// digestLine matches the line vfox prints when it verifies a checksum.
	digestLine = regexp.MustCompile(`(?m)^Verifying checksum ([0-9a-fA-F]+)\.\.\.[ \t]*$`)
	// vfoxVersionLine matches `vfox --version` output, such as "vfox version 1.1.0".
	vfoxVersionLine = regexp.MustCompile(`vfox version v?(\d+)\.(\d+)\.(\d+)`)
)

// parseSearch returns the versions `vfox search` lists, in the order printed.
func parseSearch(out string) []string {
	var versions []string
	for _, m := range searchItem.FindAllStringSubmatch(out, -1) {
		versions = append(versions, m[1])
	}
	return versions
}

// listedVersion is one installed version as `vfox list` or `vfox current`
// prints it.
type listedVersion struct {
	Version string // for example 2.7.0
	Linked  bool   // a link to a directory vfox did not install
	Current bool   // the version in use
}

// parseList returns the installed versions in out, in the order printed.
func parseList(out string) []listedVersion {
	var items []listedVersion
	for _, m := range listItem.FindAllStringSubmatch(out, -1) {
		items = append(items, listedVersion{
			Version: m[1],
			Linked:  strings.Contains(m[2], "(linked"),
			Current: strings.HasSuffix(strings.TrimSpace(m[2]), "current"),
		})
	}
	return items
}

// isLinked reports whether items lists version as a link.
func isLinked(items []listedVersion, version string) bool {
	for _, item := range items {
		if item.Version == version && item.Linked {
			return true
		}
	}
	return false
}

// checksumProblem says why the output of an install does not show that vfox
// verified the download, or returns "" when it does. Once the plugin supplies
// a checksum, vfox prints `Verifying checksum <digest>...`. Without one, vfox
// still prints the same prefix and then `Checksum is not provided`, so the
// warning is the failure to look for.
func checksumProblem(out string) string {
	switch {
	case strings.Contains(out, "Checksum is not provided"):
		return "output says `Checksum is not provided`: the plugin gave vfox no checksum"
	case !strings.Contains(out, "Verifying checksum"):
		return "output has no `Verifying checksum` line"
	}
	m := digestLine.FindStringSubmatch(out)
	if m == nil {
		return "`Verifying checksum` is not followed by a digest"
	}
	switch len(m[1]) {
	case 32, 40, 64, 128: // hex digests of MD5, SHA-1, SHA-256 and SHA-512
		return ""
	}
	return fmt.Sprintf("digest %q has the length of no checksum algorithm", m[1])
}

// installedLine matches the line vfox prints when an install succeeds, or when
// the release is installed already.
var installedLine = regexp.MustCompile(`(?m)^(?:Install deno@(\S+) success|deno@(\S+) is already installed)`)

// installedVersion returns the release that an install reports, such as 2.9.8.
func installedVersion(out string) (string, bool) {
	m := installedLine.FindStringSubmatch(out)
	if m == nil {
		return "", false
	}
	if m[1] != "" {
		return m[1], true
	}
	return m[2], true
}

// vfoxVersionOf reads the version from `vfox --version` output.
func vfoxVersionOf(out string) ([3]int, bool) {
	m := vfoxVersionLine.FindStringSubmatch(out)
	if m == nil {
		return [3]int{}, false
	}
	var v [3]int
	for i := range v {
		n, err := strconv.Atoi(m[i+1])
		if err != nil {
			return [3]int{}, false
		}
		v[i] = n
	}
	return v, true
}

// versionAtLeast reports whether v is at least least, comparing the major,
// minor and patch numbers in turn.
func versionAtLeast(v, least [3]int) bool {
	for i := range v {
		if v[i] != least[i] {
			return v[i] > least[i]
		}
	}
	return true
}

// versionString formats v as major.minor.patch.
func versionString(v [3]int) string {
	return fmt.Sprintf("%d.%d.%d", v[0], v[1], v[2])
}
