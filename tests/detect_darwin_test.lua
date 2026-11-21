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

-- Homebrew keeps the real Deno under opt/deno, and links it into bin. The
-- opt folder is the one reported, as its path does not change with upgrades.
local test = require("vfox.test")
local plugin = test.load({
    os = "darwin",
    arch = "arm64",
})

local env = {}
local files = {}
local outputs = {}

local function norm(path)
    return (path:gsub("\\", "/"))
end

os.getenv = function(name)
    return env[name]
end

io.open = function(path)
    if files[norm(path)] == nil then
        return nil
    end
    return {
        read = function()
            return ""
        end,
        close = function()
            return true
        end,
    }
end

io.popen = function(command)
    local target = command:match("'(.-)'") or ""
    local output = ""
    if command:find("--version", 1, true) then
        output = outputs[norm(target)] or ""
    end
    return {
        read = function()
            return output
        end,
        lines = function()
            return output:gmatch("[^\r\n]+")
        end,
        close = function()
            return true
        end,
    }
end

local function deno_in(folder, version)
    local exe = norm(folder .. "/deno")
    files[exe] = true
    outputs[exe] = "deno " .. version .. " (stable, release, aarch64-apple-darwin)\nv8 13.0.245.12-rusty\n"
end

env = {
    HOME = "/Users/test",
    PATH = "/opt/homebrew/bin:/usr/local/bin",
}
deno_in("/opt/homebrew/opt/deno/bin", "2.9.8")
deno_in("/opt/homebrew/bin", "2.9.8")
deno_in("/usr/local/bin", "2.7.0")

local found = {}
for _, item in ipairs(plugin:Detect({})) do
    table.insert(found, item.version .. " " .. item.path .. " (" .. item.note .. ")")
end
local got = table.concat(found, "\n")
local want = table.concat({
    "2.7.0 /usr/local/bin (found on PATH)",
    "2.9.8 /opt/homebrew/opt/deno/bin (installed by Homebrew)",
}, "\n")
assert(got == want, "expected:\n" .. want .. "\ngot:\n" .. got)

print("PASS: 1 macOS Detect case")
