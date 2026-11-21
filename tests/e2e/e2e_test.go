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
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"
)

// The release the exact-version steps install and run, the spec that installs
// the newest 2.x, a version no release has, and the plugin's README.
const (
	denoPinned  = "2.7.0"
	denoMajor   = "2"
	unknownDeno = "9.9.9"
	readmeURL   = "https://github.com/version-fox/vfox-deno/blob/main/README.md"
)

// denoFirstLinux is the first release with a download for Linux with x86_64. Its
// archive stores deno without the execute bit, so the plugin has to set it.
const denoFirstLinux = "0.36.0"

// TestE2E installs and runs the Deno plugin with the real vfox binary. Each
// step is a subtest, and the steps run in order against one isolated
// environment. A failed step does not stop the later ones unless they cannot
// run without it. It is skipped under -short.
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("TestE2E runs vfox and downloads Deno; it is skipped under -short")
	}
	h := newHarness(t)
	if !t.Run("1 setup vfox and the plugin", h.setup) {
		t.Fatal("setup failed; the other steps need vfox and the plugin")
	}
	t.Run("2 info links the README", h.infoLinksReadme)
	t.Run("3 search lists 2.7.0", h.searchListsPinned)
	t.Run("4 install deno@2 verifies the checksum and current reports it", h.installLatestMajor)
	t.Run("5 install deno@2.7.0 and run it", h.installPinned)
	t.Run("6 install accepts a leading v", h.installVPrefixed)
	t.Run("7 install rejects an unknown version", h.installUnknown)
	t.Run("8 detect and link a copy", h.detectAndLink)
	t.Run("9 install the first Linux release and run it", h.installFirstLinux)
	t.Run("10 cleanup", h.cleanup)
}

// setup acquires vfox, checks that it is 1.1.0 or later, packages this
// repository's plugin and adds it to vfox.
func (h *harness) setup(t *testing.T) {
	h.vfoxBin = acquireVfox(t, h.root)
	ver := h.vfox(t, "--version")
	if !ver.ok() {
		t.Fatalf("vfox --version failed: %s", ver)
	}
	got, ok := vfoxVersionOf(ver.Output)
	if !ok {
		t.Fatalf("vfox --version printed no version: %s", logText(ver.Output))
	}
	if !versionAtLeast(got, minVfoxVersion) {
		t.Fatalf("vfox %s is older than the required %s", versionString(got), versionString(minVfoxVersion))
	}
	repo, err := filepath.Abs(filepath.Join("..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	zipPath := filepath.Join(h.root, "plugin", "deno.zip")
	if err := os.MkdirAll(filepath.Dir(zipPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := PackPlugin(repo, zipPath); err != nil {
		t.Fatalf("package the plugin from %s: %v", repo, err)
	}
	t.Logf("plugin: packed %s into %s", repo, zipPath)
	add := h.vfox(t, "add", "deno", "--source", zipPath)
	if !add.ok() {
		t.Fatalf("vfox add deno failed: %s", add)
	}
}

// infoLinksReadme checks that the notes `vfox info deno` prints link the README.
func (h *harness) infoLinksReadme(t *testing.T) {
	info := h.vfox(t, "info", "deno")
	if !info.ok() {
		t.Fatalf("vfox info deno failed: %s", info)
	}
	if !strings.Contains(info.Output, readmeURL) {
		t.Errorf("vfox info deno does not print %s", readmeURL)
	}
}

// searchListsPinned checks that `vfox search deno` lists the pinned release.
func (h *harness) searchListsPinned(t *testing.T) {
	search := h.vfoxRetry(t, "search", "deno")
	versions := parseSearch(search.Output)
	if !slices.Contains(versions, denoPinned) {
		t.Errorf("vfox search deno does not list %s; it listed %d versions", denoPinned, len(versions))
	}
}

// installLatestMajor installs the newest 2.x and checks three things: vfox
// verified the download, the release it installed is a 2.x, and `vfox current
// deno` reports that release.
//
// vfox current reports a version only where one is in use, and after a plain
// install nothing is. The harness runs neither `vfox use` nor activation, so
// the release is named in a .vfox.toml in the working directory, the project
// file vfox reads, which currentPinned removes again.
func (h *harness) installLatestMajor(t *testing.T) {
	install := h.vfoxRetry(t, "install", "deno@"+denoMajor)
	if problem := checksumProblem(install.Output); problem != "" {
		t.Errorf("vfox install deno@%s: %s", denoMajor, problem)
	}
	version, ok := installedVersion(install.Output)
	if !ok || !strings.HasPrefix(version, "2.") {
		t.Fatalf("vfox install deno@%s did not name a 2.x release: %s", denoMajor, logText(install.Output))
	}
	current := h.currentPinned(t, version)
	items := parseList(current.Output)
	if !current.ok() || len(items) != 1 || items[0].Version != version {
		t.Errorf("vfox current deno: want -> %s, got %s", version, logText(current.Output))
	}
}

// currentPinned runs `vfox current deno` in the working directory, where a
// .vfox.toml names version as deno's version. The file is removed afterwards,
// so later steps do not see it.
func (h *harness) currentPinned(t *testing.T, version string) commandResult {
	t.Helper()
	project := filepath.Join(h.workDir, ".vfox.toml")
	if err := os.WriteFile(project, []byte("[tools]\ndeno = \""+version+"\"\n"), 0o644); err != nil {
		t.Fatalf("write %s: %v", project, err)
	}
	defer os.Remove(project)
	return h.vfox(t, "current", "deno")
}

// installPinned installs Deno 2.7.0 and runs it through vfox exec. Deno must
// report the pinned release, and the binary it runs must lie inside VFOX_HOME.
func (h *harness) installPinned(t *testing.T) {
	install := h.vfoxRetry(t, "install", "deno@"+denoPinned)
	if problem := checksumProblem(install.Output); problem != "" {
		t.Errorf("vfox install deno@%s: %s", denoPinned, problem)
	}
	// Where vfox put the release. It is logged, not checked, so a failing step
	// shows the layout of the install it ran against.
	logTree(t, h.vfoxHome)
	spec := "deno@" + denoPinned
	h.checkDenoVersion(t, spec)
	if p, ok := h.denoExecPath(t, spec, h.vfoxHome); ok {
		h.pinnedExec = p
	}
}

// installVPrefixed checks that a leading v is accepted: deno@v2.7.0 exits 0
// and names exactly 2.7.0, whether it installs it or finds it installed.
func (h *harness) installVPrefixed(t *testing.T) {
	install := h.vfoxRetry(t, "install", "deno@v"+denoPinned)
	if version, ok := installedVersion(install.Output); !ok || version != denoPinned {
		t.Errorf("vfox install deno@v%s named %q, want %s: %s", denoPinned, version, denoPinned, logText(install.Output))
	}
}

// installUnknown checks that a version no release has fails with the plugin's
// resolution error. It is not retried, because the failure is the expected
// outcome.
func (h *harness) installUnknown(t *testing.T) {
	res := h.vfox(t, "install", "deno@"+unknownDeno)
	if res.Err != nil {
		t.Fatalf("vfox install deno@%s did not run: %s", unknownDeno, res)
	}
	if res.ExitCode == 0 {
		t.Errorf("vfox install deno@%s exited 0, want a failure", unknownDeno)
	}
	if !strings.Contains(res.Output, "Could not resolve version") {
		t.Errorf("vfox install deno@%s printed no `Could not resolve version`: %s", unknownDeno, logText(res.Output))
	}
}

// detectAndLink simulates a Deno that vfox did not install. It copies the
// 2.7.0 binary to DENO_INSTALL/bin, uninstalls vfox's own copy, and runs
// `vfox link --detect -y`, which must find and link the copy. The link must
// then show in `vfox list`, run the same binary, and survive `vfox uninstall`,
// which removes the link only.
func (h *harness) detectAndLink(t *testing.T) {
	if h.pinnedExec == "" {
		t.Fatal("step 5 did not leave a 2.7.0 binary inside VFOX_HOME to copy")
	}
	spec := "deno@" + denoPinned
	binDir := filepath.Join(h.denoInstall, "bin")
	dst := filepath.Join(binDir, denoBinaryName())
	if err := copyKeepMode(h.pinnedExec, dst); err != nil {
		t.Fatalf("copy %s to %s: %v", h.pinnedExec, dst, err)
	}
	t.Logf("copied %s to %s", h.pinnedExec, dst)

	if res := h.vfox(t, "uninstall", spec); !res.ok() {
		t.Fatalf("vfox uninstall %s failed: %s", spec, res)
	}
	// Detect only finds copies that vfox does not hold, so the install must be gone.
	before := h.vfox(t, "list", "deno")
	if !before.ok() {
		t.Fatalf("vfox list deno failed before the link: %s", before)
	}
	for _, item := range parseList(before.Output) {
		if item.Version == denoPinned && !item.Linked {
			t.Fatalf("vfox still lists %s as installed after uninstall; the link check would prove nothing", denoPinned)
		}
	}

	detect := h.vfox(t, "link", "--detect", "-y", "deno")
	if !detect.ok() {
		t.Fatalf("vfox link --detect -y deno failed: %s", detect)
	}
	if mentions(detect.Output, h.vfoxHome) {
		t.Errorf("vfox link --detect -y deno mentions VFOX_HOME %s", h.vfoxHome)
	}
	after := h.vfox(t, "list", "deno")
	if !after.ok() || !isLinked(parseList(after.Output), denoPinned) {
		t.Errorf("vfox list deno does not show %s as linked: %s", denoPinned, logText(after.Output))
	}

	h.checkDenoVersion(t, spec)
	h.denoExecIs(t, spec, dst)

	if res := h.vfox(t, "uninstall", spec); !res.ok() {
		t.Fatalf("vfox uninstall %s (the link) failed: %s", spec, res)
	}
	if _, err := os.Stat(dst); err != nil {
		t.Errorf("vfox uninstall removed the linked binary %s: %v", dst, err)
	}
}

// installFirstLinux installs Deno 0.36.0, the first release with a download for
// Linux with x86_64, and runs it through vfox exec. Its archive leaves deno
// without the execute bit, so the plugin has to set the bit after unpacking:
// without it, exec fails with permission denied. The step runs only on Linux
// with x86_64. On Windows there is no execute bit to check, and on Linux with
// arm64 this release has no download.
func (h *harness) installFirstLinux(t *testing.T) {
	if runtime.GOOS != "linux" || runtime.GOARCH != "amd64" {
		t.Skipf("the execute-bit check of Deno %s runs on Linux with x86_64; this host is %s/%s",
			denoFirstLinux, runtime.GOOS, runtime.GOARCH)
	}
	spec := "deno@" + denoFirstLinux
	h.vfoxRetry(t, "install", spec)
	res := h.vfox(t, "exec", spec, "--", "deno", "--version")
	if !res.ok() {
		t.Fatalf("vfox exec %s failed: %s", spec, res)
	}
	first, _, _ := strings.Cut(strings.TrimSpace(res.Output), "\n")
	if got, want := strings.TrimSpace(first), "deno "+denoFirstLinux; got != want {
		t.Errorf("deno --version printed %q first, want %q", got, want)
	}
}

// cleanup uninstalls every version that is still installed. It is best
// effort: a failure is logged, and the temporary root is removed either way.
func (h *harness) cleanup(t *testing.T) {
	listed := h.vfox(t, "list", "deno")
	if !listed.ok() {
		t.Logf("cleanup: vfox list deno failed, so nothing was uninstalled; the temporary root is removed anyway")
		return
	}
	for _, item := range parseList(listed.Output) {
		if res := h.vfox(t, "uninstall", "deno@"+item.Version); !res.ok() {
			t.Logf("cleanup: deno@%s was not uninstalled; the temporary root is removed anyway", item.Version)
		}
	}
}

// execDeno runs a `deno eval` of expr through vfox exec for spec, such as
// deno@2.7.0. A missing version makes exec install it first, which downloads,
// so exec is retried like an install. The command is named by its file name:
// on Windows, vfox 1.1.0's exec finds a command on the SDK's PATH only when the
// name carries its extension, so `deno` alone is not found there.
func (h *harness) execDeno(t *testing.T, spec, expr string) commandResult {
	t.Helper()
	return h.vfoxRetry(t, "exec", spec, "--", denoBinaryName(), "eval", expr)
}

// checkDenoVersion runs `deno eval` through vfox exec for spec and checks the
// version Deno prints. It must name the pinned release, with build metadata
// after a '+' allowed.
func (h *harness) checkDenoVersion(t *testing.T, spec string) {
	t.Helper()
	res := h.execDeno(t, spec, "console.log(Deno.version.deno)")
	got := strings.TrimSpace(res.Output)
	if !denoVersionMatches(got, denoPinned) {
		t.Errorf("Deno.version.deno printed %q, want %s, optionally followed by +build metadata", got, denoPinned)
	}
}

// denoExecPath runs Deno.execPath() through vfox exec for spec, and returns
// the path it prints. It reports an error unless that path lies inside dir.
func (h *harness) denoExecPath(t *testing.T, spec, dir string) (string, bool) {
	t.Helper()
	res := h.execDeno(t, spec, "console.log(Deno.execPath())")
	p := strings.TrimSpace(res.Output)
	inside, err := within(p, dir)
	if err != nil || !inside {
		t.Errorf("Deno.execPath() printed %q, want a path inside %s (%v)", p, dir, err)
		return p, false
	}
	return p, true
}

// denoVersionMatches reports whether printed, the trimmed version Deno printed,
// names the release want. Deno may append build metadata, as in 2.7.0+fb4db33,
// so the release must be followed by the end of the text or by '+'.
func denoVersionMatches(printed, want string) bool {
	return printed == want || strings.HasPrefix(printed, want+"+")
}

// denoExecIs runs Deno.execPath() through vfox exec for spec and checks that
// the executable it names is the file want. It compares the two files, not the
// paths: vfox links a folder with a junction on Windows, and filepath.EvalSymlinks
// cannot resolve a junction, so a path that runs through the link would fail
// the path check there.
func (h *harness) denoExecIs(t *testing.T, spec, want string) {
	t.Helper()
	res := h.execDeno(t, spec, "console.log(Deno.execPath())")
	p := strings.TrimSpace(res.Output)
	same, err := sameFile(p, want)
	if err != nil || !same {
		t.Errorf("Deno.execPath() printed %q, want the file %s (%v)", p, want, err)
	}
}

// sameFile reports whether a and b name the same file. os.Stat follows a link
// or junction to the file it reaches, and os.SameFile compares the files
// themselves, so a path that runs through a link matches the file it leads to.
func sameFile(a, b string) (bool, error) {
	ai, err := os.Stat(a)
	if err != nil {
		return false, err
	}
	bi, err := os.Stat(b)
	if err != nil {
		return false, err
	}
	return os.SameFile(ai, bi), nil
}

// denoBinaryName is the Deno executable's file name on this platform: deno.exe
// on Windows, deno elsewhere.
func denoBinaryName() string {
	if runtime.GOOS == "windows" {
		return "deno.exe"
	}
	return "deno"
}

// logTree logs every entry under dir, relative to it, with a trailing slash for
// folders. It shows where vfox put an install, for a step that later cannot
// find the files it expects.
func logTree(t *testing.T, dir string) {
	t.Helper()
	var entries []string
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			entries = append(entries, "unreadable: "+p+": "+err.Error())
			return nil
		}
		rel, err := filepath.Rel(dir, p)
		if err != nil || rel == "." {
			return nil
		}
		name := filepath.ToSlash(rel)
		if d.IsDir() {
			name += "/"
		}
		entries = append(entries, name)
		return nil
	})
	if err != nil {
		t.Logf("list %s: %v", dir, err)
	}
	t.Logf("entries under %s:\n%s", dir, strings.Join(entries, "\n"))
}

// copyKeepMode copies the file src to dst, creating dst's directory, and gives
// dst the permission bits of src.
func copyKeepMode(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	info, err := in.Stat()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, info.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	// The umask may have removed bits that OpenFile was asked to set.
	return os.Chmod(dst, info.Mode().Perm())
}

// within reports whether path names something inside dir. Both are resolved
// through symlinks first, and compared case-insensitively on windows.
func within(path, dir string) (bool, error) {
	p, err := filepath.EvalSymlinks(path)
	if err != nil {
		return false, err
	}
	d, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return false, err
	}
	rel, err := filepath.Rel(fold(d), fold(p))
	if err != nil {
		return false, err
	}
	outside := rel == "." || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel)
	return !outside, nil
}

// mentions reports whether text contains path, or the path with its symlinks
// resolved. The comparison ignores case on windows.
func mentions(text, path string) bool {
	if path == "" {
		return false
	}
	candidates := []string{path}
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		candidates = append(candidates, resolved)
	}
	for _, c := range candidates {
		if strings.Contains(fold(text), fold(c)) {
			return true
		}
	}
	return false
}
