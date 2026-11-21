-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- PreInstall asks Available for the release list and the checksum file of the
-- download. Both are answered from tables here, so the tests stay offline.
local test = require("vfox.test")

local RELEASES = table.concat({
    "# Releases",
    "### 2.9.8 / 2026.10.21",
    "### 2.7.0 / 2026.06.01",
    "### 2.1.10 / 2025.01.01",
    "### 2.1.4 / 2024.12.01",
    "### 1.46.3 / 2025.02.01",
    "",
}, "\n")
local DIGEST = string.rep("ab", 32)

local state = {}
local requests = {}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        table.insert(requests, request.url)
        if request.url:sub(-#".sha256sum") == ".sha256sum" then
            if state.checksum ~= nil then
                return state.checksum.response, state.checksum.err
            end
            local name = request.url:match("([^/]+)%.sha256sum$")
            return { status_code = 200, body = DIGEST .. "  " .. name .. "\n" }
        end
        return { status_code = 200, body = RELEASES }
    end,
})

local cases = 0

--- Installs requested and returns the package PreInstall gives.
local function install(requested)
    return plugin:PreInstall({ version = requested })
end

--- Checks that PreInstall for requested gives version and url, and the digest when there is one.
local function resolves(requested, version, url, sha256)
    local package = install(requested)
    assert(package.version == version, requested .. ": expected " .. version .. ", got " .. tostring(package.version))
    assert(package.url == url, requested .. ": expected " .. url .. ", got " .. tostring(package.url))
    assert(
        package.sha256 == sha256,
        requested .. ": expected sha256 " .. tostring(sha256) .. ", got " .. tostring(package.sha256)
    )
    cases = cases + 1
end

--- Checks that PreInstall for requested fails with an error containing text.
local function fails(requested, text)
    local ok, err = pcall(install, requested)
    assert(not ok, requested .. ": expected an error containing " .. text)
    assert(tostring(err):find(text, 1, true), requested .. ": " .. tostring(err))
    cases = cases + 1
end

local function download(version, filename)
    return "https://github.com/denoland/deno/releases/download/v" .. version .. "/" .. filename
end

local LINUX = "deno-x86_64-unknown-linux-gnu.zip"

-- Versions: latest, a major, a minor, an exact release, and the forms users type.
resolves("latest", "2.9.8", download("2.9.8", LINUX), DIGEST)
resolves("2", "2.9.8", download("2.9.8", LINUX), DIGEST)
resolves("2.1", "2.1.10", download("2.1.10", LINUX), DIGEST)
resolves("2.1.4", "2.1.4", download("2.1.4", LINUX), DIGEST)
resolves("1", "1.46.3", download("1.46.3", LINUX), DIGEST)
resolves("v2.7.0", "2.7.0", download("2.7.0", LINUX), DIGEST)
resolves("  2.7.0 ", "2.7.0", download("2.7.0", LINUX), DIGEST)

-- A minor is a whole number before its dot: 2.1.1 is not 2.1.10.
fails("2.1.1", "Could not resolve version: 2.1.1")
fails("9.9.9", "Could not resolve version: 9.9.9")
fails("", "No version given")

-- The checksum file is fetched next to the archive.
requests = {}
install("2.7.0")
assert(requests[#requests] == download("2.7.0", LINUX) .. ".sha256sum", requests[#requests])
cases = cases + 1

-- Other platforms name their own builds.
RUNTIME.osType = "windows"
RUNTIME.archType = "arm64"
resolves("2.9.8", "2.9.8", download("2.9.8", "deno-aarch64-pc-windows-msvc.zip"), DIGEST)
RUNTIME.osType = "windows"
RUNTIME.archType = "amd64"
resolves("2.9.8", "2.9.8", download("2.9.8", "deno-x86_64-pc-windows-msvc.zip"), DIGEST)
RUNTIME.osType = "darwin"
RUNTIME.archType = "arm64"
resolves("2.9.8", "2.9.8", download("2.9.8", "deno-aarch64-apple-darwin.zip"), DIGEST)
RUNTIME.osType = "linux"
RUNTIME.archType = "arm64"
resolves("2.9.8", "2.9.8", download("2.9.8", "deno-aarch64-unknown-linux-gnu.zip"), DIGEST)
RUNTIME.archType = "386"
fails("2.9.8", "Deno does not support 386 architecture")
RUNTIME.archType = "amd64"

-- A 404 for the checksum file is the one answer that means Deno published none:
-- the install goes on without a digest, and says so.
local printed = {}
local real_print = print
print = function(message)
    table.insert(printed, message)
end
state.checksum = { response = { status_code = 404, body = "Not Found" } }
printed = {}
local no_checksum = install("1.46.3")
assert(no_checksum.sha256 == nil, "expected no digest, got " .. tostring(no_checksum.sha256))
assert(no_checksum.url == download("1.46.3", LINUX), no_checksum.url)
assert(#printed == 1, "expected one note, got " .. #printed)
assert(printed[1] == "Cannot verify the download: Deno publishes no checksum for " .. LINUX, printed[1])
cases = cases + 1
print = real_print

-- Every other answer must give a digest for this build. When it does not, the
-- install stops, so nothing is installed unverified. vfox wraps the error of a
-- failed request, so the reason is looked for, not compared.
local function checksum_stops(response, err, reason)
    state.checksum = { response = response, err = err }
    local ok, failure = pcall(install, "2.7.0")
    assert(not ok, "expected the install to stop, got " .. tostring(failure))
    assert(tostring(failure):find(reason, 1, true), tostring(failure))
    cases = cases + 1
end
checksum_stops(nil, "timeout", "could not fetch")
checksum_stops({ status_code = 503, body = "unavailable" }, nil, "HTTP 503")
checksum_stops(
    { status_code = 200, body = DIGEST .. "  deno-aarch64-apple-darwin.zip\n" },
    nil,
    "the checksum file is for deno-aarch64-apple-darwin.zip"
)
checksum_stops({ status_code = 200, body = "" }, nil, "the checksum file holds no digest")
checksum_stops(
    { status_code = 200, body = "abcdef12  " .. LINUX .. "\n" },
    nil,
    "the checksum file holds no SHA-256 digest"
)
state.checksum = nil

print("PASS: " .. cases .. " PreInstall cases")
