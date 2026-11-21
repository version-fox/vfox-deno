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

// Package e2e is the end-to-end harness for the vfox Deno plugin.
//
// TestE2E runs the real vfox binary natively on the host, with no containers.
// It packages this repository's plugin into a zip, adds it to vfox, and then
// drives info, search, install, exec, detect/link and uninstall against Deno's
// GitHub releases. Linux and Windows (amd64 and arm64) use the pinned vfox
// described below; any other host needs VFOX_BIN.
//
// Every run gets one temporary root, removed when the test ends. It holds a
// VFOX_HOME whose name contains a space, as a Windows user profile may, a
// fake HOME (also USERPROFILE), a DENO_INSTALL directory and an empty working
// directory. Child processes get a fixed PATH of system directories only, so a
// Deno installed on the host is never picked up by accident. Shell activation
// variables (__VFOX_*) are dropped too, because the harness never activates
// vfox. Everything else is inherited, so proxies, tokens and SYSTEMROOT still
// apply.
//
// vfox is pinned to 1.1.0. Unless VFOX_BIN names an absolute path to a vfox
// binary, the harness downloads the pinned archive for this GOOS/GOARCH and
// checks its SHA-256 before extracting anything. Either way the harness
// requires vfox 1.1.0 or later. Deno is pinned to 2.7.0, and deno@2 (the newest
// 2.x) is installed too.
//
// Network-touching vfox commands (search, install, and exec, which installs a
// missing version) are retried E2E_RETRY_ATTEMPTS times (default 3), with a
// linear backoff of 10s times the attempt number. Expected failures are not
// retried.
//
// Run from tests/e2e, the module root:
//
//	go test -v -timeout 40m -run TestE2E ./...
//
// To test with a vfox binary you already have, give its absolute path:
//
//	VFOX_BIN=/abs/path/to/vfox go test -v -timeout 40m -run TestE2E ./...
//
// The unit tests need neither network nor vfox. They cover plugin packaging,
// the vfox pins, retries and output parsing, and run with:
//
//	go test -short ./...
package e2e
