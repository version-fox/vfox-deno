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

-- Available reads Deno's Releases.md, so these tests answer its requests from
-- a table and never reach the network.
local test = require("vfox.test")

local state = {}
local requests = {}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        table.insert(requests, request.url)
        return state.response, state.requestError
    end,
})

local cases = 0

--- Returns the versions Available lists for the response in state.
local function listed()
    local versions = {}
    for _, item in ipairs(plugin:Available({})) do
        table.insert(versions, item.version)
    end
    return table.concat(versions, " ")
end

--- Checks that Available fails with an error containing every one of texts.
--- vfox wraps the error of a failed request, so the texts are looked for, not
--- compared.
local function fails(...)
    local ok, err = pcall(function()
        plugin:Available({})
    end)
    assert(not ok, "expected an error")
    for _, text in ipairs({ ... }) do
        assert(tostring(err):find(text, 1, true), text .. " not in: " .. tostring(err))
    end
    cases = cases + 1
end

-- The heading format of Deno's Releases.md, with the parts Available must skip:
-- a repeated release, a pre-release, a `v` prefix, and other headings.
state.requestError = nil
state.response = {
    status_code = 200,
    body = table.concat({
        "# Releases",
        "",
        "### 2.9.8 / 2026.10.21",
        "- fix(core): something",
        "### 2.9.7 / 2026.09.16",
        "#### Notes",
        "### 2.9.8 / 2026.10.21",
        "### 2.2.0-rc.1 / 2025.01.02",
        "### v2.7.0 / 2026.08.01",
        "### 2.1.10 / 2025.01.01\r",
        "",
    }, "\n"),
}
assert(listed() == "2.9.8 2.9.7 2.7.0 2.1.10", listed())
assert(requests[#requests] == "https://raw.githubusercontent.com/denoland/deno/main/Releases.md", requests[#requests])
cases = cases + 1

local RELEASES_URL = "https://raw.githubusercontent.com/denoland/deno/main/Releases.md"

-- A timeout names the release list it could not fetch.
state.requestError = "timeout"
state.response = nil
fails("Failed to fetch Deno releases from " .. RELEASES_URL, "timeout")

-- A failing status says which.
state.requestError = nil
state.response = { status_code = 503, body = "unavailable" }
fails("Failed to fetch Deno releases: HTTP 503")

-- A page without release headings means the upstream format changed.
state.response = { status_code = 200, body = "# Releases\nupstream format changed\n" }
fails("No Deno versions found")

-- Each platform lists the releases from its first download on, and 1.10.0 has no
-- download on any platform, so it is left out everywhere. The headings are Deno's
-- own, with a release either side of each first download.
state.requestError = nil
state.response = {
    status_code = 200,
    body = table.concat({
        "# Releases",
        "### 2.6.8 / 2026.02.02",
        "### 2.6.7 / 2026.01.29",
        "### 1.40.3 / 2024.02.01",
        "### 1.40.2 / 2024.01.26",
        "### 1.10.1 / 2021.05.11",
        "### 1.10.0 / 2021.05.11",
        "### 1.6.0 / 2020.12.08",
        "### 1.5.4 / 2020.11.23",
        "### v0.36.0 / 2020.03.11",
        "### v0.35.0 / 2020.02.28",
        "### v0.0.0 / 2018.05.14 - 2018.06.22 / Golang Prototype",
        "",
    }, "\n"),
}

--- Sets the platform that Available reads.
local function platform(os_type, arch_type)
    RUNTIME.osType = os_type
    RUNTIME.archType = arch_type
end

local x86_list = "2.6.8 2.6.7 1.40.3 1.40.2 1.10.1 1.6.0 1.5.4 0.36.0"
local platform_lists = {
    { "linux", "amd64", x86_list },
    { "darwin", "amd64", x86_list },
    { "windows", "amd64", x86_list },
    { "linux", "arm64", "2.6.8 2.6.7 1.40.3" },
    { "darwin", "arm64", "2.6.8 2.6.7 1.40.3 1.40.2 1.10.1 1.6.0" },
    { "windows", "arm64", "2.6.8" },
}
for _, item in ipairs(platform_lists) do
    platform(item[1], item[2])
    local got = listed()
    assert(got == item[3], item[1] .. "/" .. item[2] .. " lists " .. got)
    cases = cases + 1
end

-- A platform with no release from its first download on has nothing to list.
state.response = { status_code = 200, body = "# Releases\n### 1.5.4 / 2020.11.23\n" }
platform("windows", "arm64")
fails("No Deno version has a download for this platform")

-- A platform that Deno does not build for fails the same way the install does.
platform("linux", "386")
fails("Deno does not support 386 architecture")

platform("linux", "amd64")
print("PASS: " .. cases .. " Available cases")
