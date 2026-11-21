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
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

// pluginDirs are the directories whose Lua files belong to the plugin zip,
// next to metadata.lua at the top.
var pluginDirs = []string{"hooks", "lib"}

// PluginFiles lists the files of the plugin at repoRoot that make up its zip:
// metadata.lua, and every *.lua file under hooks/ and lib/. The names are
// sorted, use forward slashes, and are relative to repoRoot. Nothing else (no
// tests, docs or CI files) is listed.
func PluginFiles(repoRoot string) ([]string, error) {
	if _, err := os.Stat(filepath.Join(repoRoot, "metadata.lua")); err != nil {
		return nil, fmt.Errorf("plugin root %s: %w", repoRoot, err)
	}
	files := []string{"metadata.lua"}
	for _, dir := range pluginDirs {
		err := filepath.WalkDir(filepath.Join(repoRoot, dir), func(p string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() || filepath.Ext(p) != ".lua" {
				return nil
			}
			rel, err := filepath.Rel(repoRoot, p)
			if err != nil {
				return err
			}
			files = append(files, filepath.ToSlash(rel))
			return nil
		})
		if err != nil {
			return nil, fmt.Errorf("plugin %s: %w", dir, err)
		}
	}
	sort.Strings(files)
	return files, nil
}

// PackPlugin writes the plugin zip for the repository at repoRoot to zipPath.
// The zip holds exactly the files PluginFiles lists, at its root and with
// forward-slash names. It has no directory entries. `vfox add --source` takes
// the file as it is.
func PackPlugin(repoRoot, zipPath string) (err error) {
	files, err := PluginFiles(repoRoot)
	if err != nil {
		return err
	}
	out, err := os.Create(zipPath)
	if err != nil {
		return err
	}
	defer func() {
		if cerr := out.Close(); err == nil {
			err = cerr
		}
	}()
	zw := zip.NewWriter(out)
	for _, name := range files {
		if err := addZipFile(zw, repoRoot, name); err != nil {
			return err
		}
	}
	return zw.Close()
}

// addZipFile adds repoRoot/name to zw under name, keeping its modification
// time and permissions.
func addZipFile(zw *zip.Writer, repoRoot, name string) error {
	src := filepath.Join(repoRoot, filepath.FromSlash(name))
	info, err := os.Stat(src)
	if err != nil {
		return err
	}
	hdr, err := zip.FileInfoHeader(info)
	if err != nil {
		return err
	}
	hdr.Name = name
	hdr.Method = zip.Deflate
	w, err := zw.CreateHeader(hdr)
	if err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	_, err = io.Copy(w, in)
	return err
}
