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
	"crypto/sha256"
	"encoding/hex"
	"maps"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"strings"
	"testing"
)

// TestCheckPin checks that an archive passes only with the SHA-256 its pin
// records: the same bytes with one byte changed fail, and so does another
// platform's pin. It runs under -short.
func TestCheckPin(t *testing.T) {
	archive := []byte("vfox archive bytes")
	sum := sha256.Sum256(archive)
	pin := vfoxPin{Asset: "vfox_1.1.0_linux_x86_64.tar.gz", SHA256: hex.EncodeToString(sum[:])}
	if err := checkPin(archive, pin); err != nil {
		t.Fatalf("checkPin with the matching digest: %v", err)
	}
	if err := checkPin(append([]byte("x"), archive...), pin); err == nil {
		t.Error("checkPin accepted an archive whose digest differs")
	}
	if err := checkPin(archive, vfoxPins["linux/amd64"]); err == nil {
		t.Error("checkPin accepted an archive against another platform's pin")
	}
}

// TestVfoxPins checks the pinned archives: the four platforms, a 64-digit
// lower-case SHA-256 each, asset names for vfoxVersion, and the binary entry
// each archive must hold. It runs under -short.
func TestVfoxPins(t *testing.T) {
	if vfoxVersion != "1.1.0" {
		t.Errorf("vfoxVersion = %q, want 1.1.0", vfoxVersion)
	}
	wantKeys := []string{"linux/amd64", "linux/arm64", "windows/amd64", "windows/arm64"}
	if got := slices.Sorted(maps.Keys(vfoxPins)); !slices.Equal(got, wantKeys) {
		t.Fatalf("pinned platforms = %q, want %q", got, wantKeys)
	}
	sha := regexp.MustCompile(`^[0-9a-f]{64}$`)
	for key, pin := range vfoxPins {
		goos, _, _ := strings.Cut(key, "/")
		ext, exe := ".tar.gz", "vfox"
		if goos == "windows" {
			ext, exe = ".zip", "vfox.exe"
		}
		if !sha.MatchString(pin.SHA256) {
			t.Errorf("%s: SHA256 %q is not 64 lower-case hex digits", key, pin.SHA256)
		}
		if !strings.HasPrefix(pin.Asset, "vfox_"+vfoxVersion+"_") || !strings.HasSuffix(pin.Asset, ext) {
			t.Errorf("%s: asset %q is not a vfox %s %s archive", key, pin.Asset, vfoxVersion, ext)
		}
		dir := strings.TrimSuffix(pin.Asset, ext)
		if want := dir + "/" + exe; pin.Binary != want {
			t.Errorf("%s: binary entry %q, want %q", key, pin.Binary, want)
		}
	}
}

// TestCleanOutputRemovesEscapesAndSplitsRedraws checks that colour and title
// escapes are removed, that carriage returns become line breaks, and that the
// log keeps only the last of a run of progress lines. It runs under -short.
func TestCleanOutputRemovesEscapesAndSplitsRedraws(t *testing.T) {
	raw := []byte("\x1b[94mdeno\x1b[0m\r\nDownloading...   1% [>   ]\rDownloading...  50% [==>]\rDownloading... 100%\r\nVerifying checksum abc...\n\x1b]0;title\x07done\n")
	clean := cleanOutput(raw)
	wantClean := "deno\nDownloading...   1% [>   ]\nDownloading...  50% [==>]\nDownloading... 100%\nVerifying checksum abc...\ndone\n"
	if clean != wantClean {
		t.Fatalf("cleanOutput:\n got %q\nwant %q", clean, wantClean)
	}
	wantLog := "deno\nDownloading... 100%\nVerifying checksum abc...\ndone"
	if got := logText(clean); got != wantLog {
		t.Fatalf("logText:\n got %q\nwant %q", got, wantLog)
	}
}

// TestParseSearchAndList checks the lines of `vfox search` and `vfox list`
// that the steps read: the versions in order, and the marks for the version in
// use and for links. It runs under -short.
func TestParseSearchAndList(t *testing.T) {
	search := "Available versions:\n - 2.9.8\n - 2.7.0\n - 2.7.0-rc.1\n"
	if got, want := parseSearch(search), []string{"2.9.8", "2.7.0", "2.7.0-rc.1"}; !slices.Equal(got, want) {
		t.Errorf("parseSearch = %q, want %q", got, want)
	}

	list := "-> 2.9.8 — current\n-> 2.7.0 (linked → /x/deno-install/bin)\n-> 2.6.0\n"
	items := parseList(list)
	want := []listedVersion{
		{Version: "2.9.8", Current: true},
		{Version: "2.7.0", Linked: true},
		{Version: "2.6.0"},
	}
	if !slices.Equal(items, want) {
		t.Errorf("parseList = %+v, want %+v", items, want)
	}
	if !isLinked(items, "2.7.0") || isLinked(items, "2.9.8") || isLinked(items, "2.6.0") {
		t.Errorf("isLinked reports the wrong versions for %+v", items)
	}
	if got := parseList("no available version\n"); len(got) != 0 {
		t.Errorf("parseList on an empty list = %+v, want none", got)
	}
}

// TestChecksumProblem checks what counts as a verified download: a digest of a
// length vfox supports, and no `Checksum is not provided` warning. It runs under
// -short.
func TestChecksumProblem(t *testing.T) {
	sha256 := strings.Repeat("e", 64)
	cases := []struct {
		name string
		out  string
		ok   bool
	}{
		{
			name: "verified",
			out:  "Preinstalling deno@2.7.0...\nVerifying checksum " + sha256 + "...\nInstall deno@2.7.0 success! \n",
			ok:   true,
		},
		{
			name: "sha1 digest",
			out:  "Verifying checksum " + strings.Repeat("a", 40) + "...\n",
			ok:   true,
		},
		{
			name: "no checksum given",
			out:  "Verifying checksum ...\nWARNING: Checksum is not provided, skip verify...\nInstall deno@2.7.0 success! \n",
		},
		{
			name: "no verification line",
			out:  "Install deno@2.7.0 success! \n",
		},
		{
			name: "digest of no algorithm",
			out:  "Verifying checksum abc...\n",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			problem := checksumProblem(tc.out)
			if (problem == "") != tc.ok {
				t.Errorf("checksumProblem = %q, want ok=%v", problem, tc.ok)
			}
		})
	}
}

// TestInstalledVersion checks which release an install's output names, for a
// fresh install and for one already in place. It runs under -short.
func TestInstalledVersion(t *testing.T) {
	cases := map[string]string{
		"Preinstalling deno@2.9.8...\nInstall deno@2.9.8 success! \n": "2.9.8",
		"deno@2.7.0 is already installed\n":                           "2.7.0",
		"Install deno@2.9.8 failed\n":                                 "",
	}
	for out, want := range cases {
		got, ok := installedVersion(out)
		if (want != "") != ok || got != want {
			t.Errorf("installedVersion(%q) = %q, %v; want %q", out, got, ok, want)
		}
	}
}

// TestVfoxVersionCheck checks how `vfox --version` output is read and compared
// with the 1.1.0 minimum. It runs under -short.
func TestVfoxVersionCheck(t *testing.T) {
	cases := []struct {
		out     string
		version [3]int
		found   bool
		atLeast bool
	}{
		{out: "vfox version 1.1.0\n", version: [3]int{1, 1, 0}, found: true, atLeast: true},
		{out: "vfox version v1.1.1\n", version: [3]int{1, 1, 1}, found: true, atLeast: true},
		{out: "vfox version 1.0.13\n", version: [3]int{1, 0, 13}, found: true},
		{out: "vfox version 2.0.0\n", version: [3]int{2, 0, 0}, found: true, atLeast: true},
		{out: "no version printed\n"},
	}
	for _, tc := range cases {
		got, found := vfoxVersionOf(tc.out)
		if found != tc.found || (found && got != tc.version) {
			t.Errorf("vfoxVersionOf(%q) = %v, %v; want %v, %v", tc.out, got, found, tc.version, tc.found)
		}
		if found && versionAtLeast(got, minVfoxVersion) != tc.atLeast {
			t.Errorf("versionAtLeast(%v, 1.1.0) = %v, want %v", got, !tc.atLeast, tc.atLeast)
		}
	}
}

// TestDenoVersionMatches checks that Deno's printed version names the pinned
// release, allowing build metadata after '+' only. It runs under -short.
func TestDenoVersionMatches(t *testing.T) {
	cases := map[string]bool{
		"2.7.0":         true,
		"2.7.0+fb4db33": true,
		"2.7.01":        false,
		"2.7.0-rc.1":    false,
		"2.7.1":         false,
		"2.7.0 extra":   false,
		"":              false,
	}
	for printed, want := range cases {
		if got := denoVersionMatches(printed, "2.7.0"); got != want {
			t.Errorf("denoVersionMatches(%q, 2.7.0) = %v, want %v", printed, got, want)
		}
	}
}

// TestIsolatedEnv checks the child environment for both platform families: the
// run's directories are set, PATH is the fixed system list, activation state is
// dropped, and other variables are kept. It runs under -short.
func TestIsolatedEnv(t *testing.T) {
	base := []string{
		"PATH=/host/bin",
		"HOME=/real/home",
		"VFOX_HOME=/old/home",
		"__VFOX_PID=42",
		"HTTPS_PROXY=http://proxy.example",
		"Path=/mixed/case",
	}
	const home, vfoxHome, install = "/run/home", "/run/vfox home", "/run/deno-install"

	posix := isolatedEnv(base, "linux", vfoxHome, home, install)
	assertEnv(t, posix, "linux", map[string]string{
		"VFOX_HOME":    vfoxHome,
		"HOME":         home,
		"USERPROFILE":  home,
		"DENO_INSTALL": install,
		"PATH":         "/usr/bin:/bin",
		"HTTPS_PROXY":  "http://proxy.example",
		"Path":         "/mixed/case",
	})
	assertNoText(t, posix, "__VFOX_PID", "/host/bin", "/real/home", "/old/home")

	win := isolatedEnv(base, "windows", vfoxHome, home, install)
	assertEnv(t, win, "windows", map[string]string{
		"VFOX_HOME":    vfoxHome,
		"HOME":         home,
		"USERPROFILE":  home,
		"DENO_INSTALL": install,
		"PATH":         `C:\Windows\System32;C:\Windows`,
		"HTTPS_PROXY":  "http://proxy.example",
	})
	assertNoText(t, win, "__VFOX_PID", "/host/bin", "/real/home", "/old/home", "/mixed/case")
}

// assertEnv checks that env holds each name exactly once with the wanted value.
// Names compare case-insensitively when goos is windows.
func assertEnv(t *testing.T, env []string, goos string, want map[string]string) {
	t.Helper()
	for name, value := range want {
		var values []string
		for _, kv := range env {
			k, v, ok := strings.Cut(kv, "=")
			if ok && foldFor(goos, k) == foldFor(goos, name) {
				values = append(values, v)
			}
		}
		if len(values) != 1 || values[0] != value {
			t.Errorf("%s: values %q, want exactly [%q]", name, values, value)
		}
	}
}

// assertNoText checks that no entry of env contains any of texts, which are
// names or values of variables that must have been replaced or dropped.
func assertNoText(t *testing.T, env []string, texts ...string) {
	t.Helper()
	for _, kv := range env {
		for _, text := range texts {
			if strings.Contains(kv, text) {
				t.Errorf("environment still has %q (matches %q)", kv, text)
			}
		}
	}
}

// TestWithinResolvesInsideAndOutside checks the path comparison used for
// VFOX_HOME and DENO_INSTALL: a file inside a directory is inside it, and a
// sibling or the directory itself is not. It runs under -short.
func TestWithinResolvesInsideAndOutside(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	inside := filepath.Join(bin, "deno")
	outside := filepath.Join(dir, "other")
	for _, p := range []string{inside, outside} {
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if ok, err := within(inside, bin); err != nil || !ok {
		t.Errorf("within(%s, %s) = %v, %v; want true", inside, bin, ok, err)
	}
	if ok, err := within(outside, bin); err != nil || ok {
		t.Errorf("within(%s, %s) = %v, %v; want false", outside, bin, ok, err)
	}
	if ok, err := within(bin, bin); err != nil || ok {
		t.Errorf("within(%s, itself) = %v, %v; want false", bin, ok, err)
	}
}

// TestSameFileFollowsLinks checks the file comparison that step 8 uses for a
// linked install: a file names itself, a different file does not match it, and
// a path that runs through a folder link matches the file the link leads to. The
// link case needs the platform to allow links, and is skipped where it does not
// (Windows without developer mode). It runs under -short.
func TestSameFileFollowsLinks(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "bin")
	if err := os.MkdirAll(target, 0o755); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(target, "deno")
	other := filepath.Join(dir, "other")
	for _, p := range []string{file, other} {
		if err := os.WriteFile(p, []byte("x"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if ok, err := sameFile(file, file); err != nil || !ok {
		t.Errorf("sameFile(file, itself) = %v, %v; want true", ok, err)
	}
	if ok, err := sameFile(other, file); err != nil || ok {
		t.Errorf("sameFile(other, file) = %v, %v; want false, two files with equal content are not the same file", ok, err)
	}
	link := filepath.Join(dir, "link")
	if err := os.Symlink(target, link); err != nil {
		t.Skipf("the platform does not allow folder links here: %v", err)
	}
	if ok, err := sameFile(filepath.Join(link, "deno"), file); err != nil || !ok {
		t.Errorf("sameFile(through link, file) = %v, %v; want true", ok, err)
	}
	if _, err := sameFile(filepath.Join(link, "missing"), file); err == nil {
		t.Errorf("sameFile of a missing file through the link = nil error; want an error")
	}
}

// TestExtractVfoxFromBothArchiveKinds extracts a synthetic tar.gz and zip
// archive and checks that only the binary entry is written, with the right name
// and, on unix, execute permission. A missing entry is an error. It runs under
// -short.
func TestExtractVfoxFromBothArchiveKinds(t *testing.T) {
	payload := []byte("fake vfox\n")
	cases := []struct {
		name     string
		archive  []byte
		pin      vfoxPin
		wantBase string
	}{
		{
			name:    "tar.gz",
			archive: tarGzWith(t, "vfox_1.1.0_linux_x86_64/vfox", payload),
			pin: vfoxPin{
				Asset:  "vfox_1.1.0_linux_x86_64.tar.gz",
				Binary: "vfox_1.1.0_linux_x86_64/vfox",
			},
			wantBase: "vfox",
		},
		{
			name:    "zip",
			archive: zipWith(t, "vfox_1.1.0_windows_x86_64/vfox.exe", payload),
			pin: vfoxPin{
				Asset:  "vfox_1.1.0_windows_x86_64.zip",
				Binary: "vfox_1.1.0_windows_x86_64/vfox.exe",
			},
			wantBase: "vfox.exe",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			bin, err := extractVfox(tc.archive, tc.pin, dir)
			if err != nil {
				t.Fatalf("extractVfox: %v", err)
			}
			if filepath.Base(bin) != tc.wantBase {
				t.Errorf("binary named %q, want %q", filepath.Base(bin), tc.wantBase)
			}
			if data, err := os.ReadFile(bin); err != nil || !bytes.Equal(data, payload) {
				t.Errorf("binary contents = %q, %v; want the payload", data, err)
			}
			if info, err := os.Stat(bin); err == nil && runtime.GOOS != "windows" && info.Mode().Perm()&0o100 == 0 {
				t.Errorf("binary mode %v is not executable", info.Mode())
			}
		})
	}
	missing := vfoxPin{Asset: "vfox_1.1.0_linux_x86_64.tar.gz", Binary: "other/vfox"}
	if _, err := extractVfox(tarGzWith(t, "vfox_1.1.0_linux_x86_64/vfox", payload), missing, t.TempDir()); err == nil {
		t.Error("extractVfox succeeded without the pinned entry")
	}
}

// tarGzWith returns a gzipped tar archive holding one regular file.
func tarGzWith(t *testing.T, name string, data []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	if err := tw.WriteHeader(&tar.Header{Name: name, Mode: 0o755, Size: int64(len(data)), Typeflag: tar.TypeReg}); err != nil {
		t.Fatal(err)
	}
	if _, err := tw.Write(data); err != nil {
		t.Fatal(err)
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

// zipWith returns a zip archive holding one file.
func zipWith(t *testing.T, name string, data []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	w, err := zw.Create(name)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := w.Write(data); err != nil {
		t.Fatal(err)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}
