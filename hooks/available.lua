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

--- Returns all the stable versions that Deno has released, newest first. The
--- list comes from the headings of Deno's Releases.md, which name each release
--- as `### 2.9.8 / 2026.10.21`; pre-releases are left out.
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
    local result = {}
    local seen = {}
    for line in string.gmatch(resp.body or "", "[^\r\n]+") do
        local version = line:match("^###%s+v?(%d+%.%d+%.%d+)%s*/")
        if version and not seen[version] then
            seen[version] = true
            table.insert(result, {
                version = version,
                note = "",
            })
        end
    end
    if #result == 0 then
        error("No Deno versions found in " .. util.ReleaseURL .. "; the upstream response may have changed")
    end
    return result
end
