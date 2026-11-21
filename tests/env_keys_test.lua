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
local plugin = test.load({
    os = "linux",
    arch = "amd64",
})

-- The only environment variable is PATH, which points at the installed folder.
local keys = plugin:EnvKeys({ path = "/home/test/.vfox/cache/deno/v-2.7.0/deno-2.7.0" })
assert(#keys == 1, "expected one variable, got " .. #keys)
assert(keys[1].key == "PATH", keys[1].key)
assert(keys[1].value == "/home/test/.vfox/cache/deno/v-2.7.0/deno-2.7.0", keys[1].value)

print("PASS: 1 EnvKeys case")
