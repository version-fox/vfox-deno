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

--- The first release with a download for each platform, by the names that
--- util:getOsTypeAndArch returns. Before it Deno published its archives under
--- other names, such as `deno_linux_x64.gz` in 0.35.0. Taken from the GitHub
--- release assets on 2026-11-21.
util.FirstDownload = {
    ["unknown-linux-gnu"] = { x86_64 = "0.36.0", aarch64 = "1.40.3" },
    ["apple-darwin"] = { x86_64 = "0.36.0", aarch64 = "1.6.0" },
    ["pc-windows-msvc"] = { x86_64 = "0.36.0", aarch64 = "2.6.8" },
}

--- The releases with no archive on any platform. Deno has the tag v1.10.0, but
--- GitHub has no release for it, so there is nothing to download.
util.NoDownload = {
    ["1.10.0"] = true,
}

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

--- Returns true when release number a is older than b. Both are X.Y.Z, and the
--- parts are compared as numbers, so 1.9.2 is older than 1.10.0.
--- @param a string
--- @param b string
--- @return boolean
local function older(a, b)
    local x = { a:match("^(%d+)%.(%d+)%.(%d+)$") }
    local y = { b:match("^(%d+)%.(%d+)%.(%d+)$") }
    for i = 1, 3 do
        local m, n = tonumber(x[i]), tonumber(y[i])
        if m ~= n then
            return m < n
        end
    end
    return false
end

--- Returns why Deno has no download of version for the platform vfox runs on,
--- or nil when it has one. Only an exact release number such as 2.7.0 is
--- checked; anything else, such as `2` or `latest`, gives nil.
--- @param version string
--- @return string|nil reason
function util:noDownloadReason(version)
    if not version:match("^%d+%.%d+%.%d+$") then
        return nil
    end
    local platform = self:getOsTypeAndArch()
    if self.NoDownload[version] then
        return "Deno published no archive for it on any platform"
    end
    local first = self.FirstDownload[platform.osType][platform.archType]
    if older(version, first) then
        return "downloads for this platform start with " .. first
    end
    return nil
end

return util
