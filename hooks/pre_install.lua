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

local http = require("http")
local util = require("util")
local checksum = require("checksum")

--- Returns the version the user typed without the blanks around it and without
--- the v that release tags carry, so `v2.7.0` is read as `2.7.0`.
--- @param version string
--- @return string
local function normalize(version)
    local value = (version or ""):match("^%s*(.-)%s*$")
    return value:match("^[vV](%d.*)$") or value
end

--- Picks the release that a requested version names from the list Available
--- returns, newest first: `latest`, a major, a minor or an exact version.
--- @param lists table
--- @param requested string
--- @return string
local function resolve(lists, requested)
    if requested == "latest" then
        return lists[1].version
    end
    local prefix = requested .. "."
    for _, item in ipairs(lists) do
        if item.version == requested or item.version:sub(1, #prefix) == prefix then
            return item.version
        end
    end
    error("Could not resolve version: " .. requested)
end

--- Returns the file name and the address of the Deno build for this platform.
--- @param version string
--- @return string filename
--- @return string url
local function package_for(version)
    local platform = util:getOsTypeAndArch()
    local filename = "deno-" .. platform.archType .. "-" .. platform.osType .. ".zip"
    return filename, util.DownloadURL:format(version, filename)
end

--- Fetches the SHA-256 digest of a build from the checksum file next to it.
--- Some Deno releases, Deno 1.46.3 among them, publish no checksum file at all:
--- a 404 is the one answer that means so, and the install goes on without a
--- digest, with a note. Every other answer must give a digest for this build.
--- When the file cannot be fetched, answers with an error, or names no digest
--- for this build, the install stops: a download is never installed unverified
--- because the checksum could not be read. A build that does not exist for the
--- platform fails in the download itself.
--- @param filename string
--- @param url string
--- @return string|nil digest nil only when Deno publishes no checksum file
local function digest_of(filename, url)
    local address = checksum.url_for(url)
    local resp, err = http.get({
        url = address,
    })
    if err ~= nil or resp == nil then
        error("Cannot verify the download: could not fetch " .. address .. ": " .. tostring(err or "empty response"))
    end
    if resp.status_code == 404 then
        print("Cannot verify the download: Deno publishes no checksum for " .. filename)
        return nil
    end
    if resp.status_code ~= 200 then
        error("Cannot verify the download: HTTP " .. tostring(resp.status_code) .. " from " .. address)
    end
    local digest, reason = checksum.parse(resp.body, filename)
    if digest == nil then
        error("Cannot verify the download: " .. reason .. " (" .. address .. ")")
    end
    return digest
end

--- Returns the version to install and where to download it. The download
--- carries the SHA-256 digest Deno publishes for it, which vfox verifies before
--- it unpacks the archive.
--- ctx.version is the version the user typed.
--- @param ctx table
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local requested = normalize(ctx.version)
    if requested == "" then
        error("No version given, for example: vfox install deno@2")
    end
    local version = resolve(self:Available({}), requested)
    local filename, url = package_for(version)
    local package = {
        version = version,
        url = url,
    }
    local digest = digest_of(filename, url)
    if digest ~= nil then
        package.sha256 = digest
    end
    return package
end
