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

assert(checksum.url_for("https://example.com/deno.zip") == "https://example.com/deno.zip.sha256sum")
cases = cases + 1

print("PASS: " .. cases .. " checksum cases")
