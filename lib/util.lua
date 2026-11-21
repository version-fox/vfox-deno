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

local util = {}

util.ReleaseURL = "https://raw.githubusercontent.com/denoland/deno/main/Releases.md"
util.DownloadURL = "https://github.com/denoland/deno/releases/download/v%s/%s"

--- Returns the operating system and CPU names that Deno's release files use
--- for the platform vfox runs on, such as `unknown-linux-gnu` and `x86_64`.
--- @return table { osType, archType }
function util:getOsTypeAndArch()
    local osType = RUNTIME.osType
    local archType = RUNTIME.archType
    if RUNTIME.osType == "darwin" then
        osType = "apple-darwin"
    elseif RUNTIME.osType == "windows" then
        osType = "pc-windows-msvc"
    elseif RUNTIME.osType == "linux" then
        osType = "unknown-linux-gnu"
    else
        error("Deno does not support " .. RUNTIME.osType .. " os")
    end
    if RUNTIME.archType == "amd64" then
        archType = "x86_64"
    elseif RUNTIME.archType == "arm64" then
        archType = "aarch64"
    else
        error("Deno does not support " .. RUNTIME.archType .. " architecture")
    end
    return {
        osType = osType,
        archType = archType,
    }
end

return util
