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

--- Reads the SHA-256 digest of a Deno download from the `.sha256sum` file that
--- each Deno release publishes next to its archive. PreInstall hands the digest
--- to vfox, which compares it with the downloaded file before it unpacks it.
local checksum = {}

--- Returns the last part of a path written with / or \.
--- @param path string
--- @return string
local function base_name(path)
    return path:match("[^/\\]*$")
end

--- Returns the address of the checksum file of a download: the archive's
--- address with `.sha256sum` appended, which is how Deno names them.
--- @param url string
--- @return string
function checksum.url_for(url)
    return url .. ".sha256sum"
end

--- Returns the lower-case SHA-256 digest that a checksum file gives for
--- filename, or nil and the reason it gives none. The file is sha256sum's
--- output, `<digest>  <name>` (with `*` before the name in binary mode), or
--- the digest alone.
--- @param content string The body of the checksum file
--- @param filename string The archive the digest must be for
--- @return string|nil digest
--- @return string|nil reason
function checksum.parse(content, filename)
    if type(content) ~= "string" then
        return nil, "the checksum file is empty"
    end
    for line in content:gmatch("[^\r\n]+") do
        local digest, name = line:match("^%s*(%x+)%s+%*?(.-)%s*$")
        if digest == nil then
            digest = line:match("^%s*(%x+)%s*$")
        end
        if digest ~= nil then
            if #digest ~= 64 then
                return nil, "the checksum file holds no SHA-256 digest"
            end
            if name ~= nil and name ~= "" and filename ~= nil and base_name(name) ~= base_name(filename) then
                return nil, "the checksum file is for " .. name
            end
            return digest:lower()
        end
    end
    return nil, "the checksum file holds no digest"
end

return checksum
