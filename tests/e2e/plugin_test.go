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
	"archive/zip"
	"bytes"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// TestPackPluginContents packs the real repository and checks the zip against
// the repository itself: exactly metadata.lua and the *.lua files under hooks/
// and lib/, with no directory entries, and every entry holding the source
// bytes. It runs under -short.
func TestPackPluginContents(t *testing.T) {
	root, err := filepath.Abs(filepath.Join("..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	zipPath := filepath.Join(t.TempDir(), "deno.zip")
	if err := PackPlugin(root, zipPath); err != nil {
		t.Fatalf("PackPlugin(%s): %v", root, err)
	}
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		t.Fatal(err)
	}
	defer zr.Close()

	var got []string
	for _, f := range zr.File {
		if f.FileInfo().IsDir() || strings.HasSuffix(f.Name, "/") {
			t.Errorf("zip has a directory entry %q", f.Name)
			continue
		}
		got = append(got, f.Name)
	}
	want := wantPluginFiles(t, root)
	if !slices.Equal(got, want) {
		t.Fatalf("zip entries:\n got %q\nwant %q", got, want)
	}
	for _, f := range zr.File {
		src, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(f.Name)))
		if err != nil {
			t.Fatal(err)
		}
		rc, err := f.Open()
		if err != nil {
			t.Fatal(err)
		}
		data, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(data, src) {
			t.Errorf("%s: contents differ from the repository file", f.Name)
		}
	}
}

// wantPluginFiles lists what the plugin zip must hold for the repository at
// root. It walks the tree with io/fs, a different API from the filepath walk
// that PluginFiles uses.
func wantPluginFiles(t *testing.T, root string) []string {
	t.Helper()
	want := []string{"metadata.lua"}
	fsys := os.DirFS(root)
	for _, dir := range []string{"hooks", "lib"} {
		err := fs.WalkDir(fsys, dir, func(name string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if !d.IsDir() && path.Ext(name) == ".lua" {
				want = append(want, name)
			}
			return nil
		})
		if err != nil {
			t.Fatal(err)
		}
	}
	slices.Sort(want)
	return want
}

// TestPluginFilesSelection checks which files are picked from a synthetic
// repository: Lua files under hooks/ and lib/, including nested ones, and
// nothing else, whatever lies beside them. It runs under -short.
func TestPluginFilesSelection(t *testing.T) {
	root := t.TempDir()
	files := map[string]string{
		"metadata.lua":           "PLUGIN = {}\n",
		"Injection.lua":          "-- not packaged\n",
		"README.md":              "# not packaged\n",
		"tests/hooks_test.lua":   "-- not packaged\n",
		"hooks/available.lua":    "-- packaged\n",
		"hooks/notes.txt":        "not packaged\n",
		"hooks/nested/extra.lua": "-- packaged\n",
		"lib/util.lua":           "-- packaged\n",
	}
	for name, body := range files {
		p := filepath.Join(root, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	got, err := PluginFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"hooks/available.lua", "hooks/nested/extra.lua", "lib/util.lua", "metadata.lua"}
	if !slices.Equal(got, want) {
		t.Fatalf("PluginFiles:\n got %q\nwant %q", got, want)
	}
}

// TestPackPluginNeedsMetadata checks that packing fails without metadata.lua,
// so a wrong working directory cannot produce an empty plugin. It runs under
// -short.
func TestPackPluginNeedsMetadata(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "hooks"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "hooks", "available.lua"), []byte("-- x\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := PackPlugin(dir, filepath.Join(t.TempDir(), "deno.zip")); err == nil {
		t.Fatal("PackPlugin without metadata.lua succeeded")
	}
}
