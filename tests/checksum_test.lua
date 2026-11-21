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

local test = require("vfox.test")
test.load()
local checksum = require("checksum")

local NAME = "deno-x86_64-unknown-linux-gnu.zip"
-- The digest Deno 2.9.8 publishes for NAME, read from its .sha256sum on 2026-11-21.
local DIGEST = "e890975bc2549807bbcc0b584ffafda72cc7c93349dd99c80483dd784f6c4609"

local cases = 0

--- Checks that content gives digest for filename.
local function gives(content, filename, digest)
    local got, reason = checksum.parse(content, filename)
    assert(got == digest, ("%q: expected %s, got %s (%s)"):format(content, digest, tostring(got), tostring(reason)))
    cases = cases + 1
end

--- Checks that content gives no digest, and the reason given.
local function rejects(content, filename, reason)
    local got, why = checksum.parse(content, filename)
    assert(got == nil, ("%q: expected no digest, got %s"):format(content, tostring(got)))
    assert(why == reason, ("%q: expected reason %q, got %q"):format(content, reason, tostring(why)))
    cases = cases + 1
end

-- sha256sum's output, as Deno publishes it.
gives(DIGEST .. "  " .. NAME .. "\n", NAME, DIGEST)
-- Binary mode puts a * before the name.
gives(DIGEST .. " *" .. NAME .. "\n", NAME, DIGEST)
-- The digest alone, with Windows line endings.
gives(DIGEST .. "\r\n", NAME, DIGEST)
-- A digest written in upper case is compared in lower case.
gives(DIGEST:upper() .. "  " .. NAME, NAME, DIGEST)
-- A path before the name is compared by its last part only.
gives(DIGEST .. "  dist/" .. NAME, NAME, DIGEST)

-- A file for another archive must not be trusted for this one.
rejects(DIGEST .. "  deno-aarch64-apple-darwin.zip", NAME, "the checksum file is for deno-aarch64-apple-darwin.zip")
-- A digest that is not SHA-256 is no digest.
rejects("abcdef12  " .. NAME, NAME, "the checksum file holds no SHA-256 digest")
rejects("", NAME, "the checksum file holds no digest")
rejects("# nothing here\n", NAME, "the checksum file holds no digest")
rejects(nil, NAME, "the checksum file is empty")

-- Windows archives carry PowerShell's Get-FileHash output. This is the file of
-- deno 2.9.8's x86_64 Windows archive, read on 2026-11-21: CRLF line ends, the
-- digest in capitals and the path the build machine wrote.
local WINDOWS_NAME = "deno-x86_64-pc-windows-msvc.zip"
local WINDOWS_DIGEST = "CBA84B26E0DF5AE7F74FC66B86A95B866872A86292EBD84FA1E959927EDD93BF"
local WINDOWS_PATH = "C:\\a\\deno\\deno\\target\\release\\" .. WINDOWS_NAME
local WINDOWS = "\r\nAlgorithm : SHA256\r\nHash      : "
    .. WINDOWS_DIGEST
    .. "\r\nPath      : "
    .. WINDOWS_PATH
    .. "\r\n\r\n"
gives(WINDOWS, WINDOWS_NAME, WINDOWS_DIGEST:lower())
-- A byte order mark in front of the file changes nothing.
gives("\239\187\191" .. WINDOWS, WINDOWS_NAME, WINDOWS_DIGEST:lower())
-- The Path line is optional: the Hash line alone gives the digest.
gives("Algorithm : SHA256\r\nHash      : " .. WINDOWS_DIGEST .. "\r\n", WINDOWS_NAME, WINDOWS_DIGEST:lower())
-- The Path line names another archive, which must not be trusted.
rejects(WINDOWS, "deno-aarch64-pc-windows-msvc.zip", "the checksum file is for " .. WINDOWS_PATH)
-- An algorithm other than SHA-256 is refused, whatever its digest looks like.
rejects(
    "Algorithm : SHA512\r\nHash      : " .. string.rep("ab", 64) .. "\r\n",
    WINDOWS_NAME,
    "the checksum file is for SHA512, not SHA-256"
)
-- A Hash line that is not 64 hexadecimal digits is no SHA-256 digest.
rejects(
    "Algorithm : SHA256\r\nHash      : " .. string.rep("g", 64) .. "\r\n",
    WINDOWS_NAME,
    "the checksum file holds no SHA-256 digest"
)
rejects("Hash : abc\r\n", WINDOWS_NAME, "the checksum file holds no SHA-256 digest")

assert(checksum.url_for("https://example.com/deno.zip") == "https://example.com/deno.zip.sha256sum")
cases = cases + 1

print("PASS: " .. cases .. " checksum cases")
