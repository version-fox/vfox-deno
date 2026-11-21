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

--- Reads the SHA-256 digest of a Deno download from the checksum file that each
--- Deno release publishes next to its archive. PreInstall hands the digest to
--- vfox, which compares it with the downloaded file before it unpacks it.
---
--- Deno publishes the file in two forms. Linux and macOS archives have the
--- output of sha256sum, `<digest>  <name>`. Windows archives have the output of
--- PowerShell's Get-FileHash, one `Key : value` line per field:
---   Algorithm : SHA256
---   Hash      : <digest, in capitals>
---   Path      : <where the build machine wrote the archive>
local checksum = {}

-- The UTF-8 byte order mark, which some tools write at the start of a file.
local BOM = "\239\187\191"

-- The algorithm names the plugin accepts, as Get-FileHash and sha256sum name them.
local ALGORITHMS = {
    SHA256 = true,
    ["SHA-256"] = true,
}

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
--- filename, or nil and the reason it gives none. The file may be in either
--- form (see above). When it names the archive, the name must be filename's
--- last part, so a file for another archive is never trusted. An algorithm
--- other than SHA-256 is refused, and so is a digest that is not 64 hexadecimal
--- digits.
--- @param content string The body of the checksum file
--- @param filename string The archive the digest must be for
--- @return string|nil digest
--- @return string|nil reason
function checksum.parse(content, filename)
    if type(content) ~= "string" then
        return nil, "the checksum file is empty"
    end
    if content:sub(1, #BOM) == BOM then
        content = content:sub(#BOM + 1)
    end
    local digest, name, algorithm
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*(%a+)%s*:%s*(.-)%s*$")
        if key ~= nil then
            key = key:lower()
            if key == "algorithm" then
                algorithm = value:upper()
            elseif key == "hash" and digest == nil then
                digest = value
            elseif key == "path" and name == nil then
                name = value
            end
        elseif digest == nil then
            local sum, sum_name = line:match("^%s*(%x+)%s+%*?(.-)%s*$")
            if sum == nil then
                sum = line:match("^%s*(%x+)%s*$")
            end
            if sum ~= nil then
                digest = sum
                name = sum_name
            end
        end
    end
    if digest == nil then
        return nil, "the checksum file holds no digest"
    end
    if algorithm ~= nil and not ALGORITHMS[algorithm] then
        return nil, "the checksum file is for " .. algorithm .. ", not SHA-256"
    end
    if #digest ~= 64 or digest:find("%X") then
        return nil, "the checksum file holds no SHA-256 digest"
    end
    if name ~= nil and name ~= "" and filename ~= nil and base_name(name) ~= base_name(filename) then
        return nil, "the checksum file is for " .. name
    end
    return digest:lower()
end

return checksum
