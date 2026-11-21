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

local util = require("util")
local http = require("http")

--- Returns the stable versions that Deno has released for this platform, newest
--- first. The list comes from the headings of Deno's Releases.md, which name
--- each release as `### 2.9.8 / 2026.10.21`. Pre-releases are left out, and so
--- are the releases with no download for this platform (see util:noDownloadReason).
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    local resp, err = http.get({
        url = util.ReleaseURL,
    })
    if err ~= nil or resp == nil then
        error("Failed to fetch Deno releases from " .. util.ReleaseURL .. ": " .. tostring(err or "empty response"))
    end
    if resp.status_code ~= 200 then
        error("Failed to fetch Deno releases: HTTP " .. tostring(resp.status_code))
    end
    local listed = 0
    local result = {}
    local seen = {}
    for line in string.gmatch(resp.body or "", "[^\r\n]+") do
        local version = line:match("^###%s+v?(%d+%.%d+%.%d+)%s*/")
        if version and not seen[version] then
            seen[version] = true
            listed = listed + 1
            if util:noDownloadReason(version) == nil then
                table.insert(result, {
                    version = version,
                    note = "",
                })
            end
        end
    end
    if listed == 0 then
        error("No Deno versions found in " .. util.ReleaseURL .. "; the upstream response may have changed")
    end
    if #result == 0 then
        error("No Deno version has a download for this platform in " .. util.ReleaseURL)
    end
    return result
end
