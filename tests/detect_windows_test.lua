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

-- The Windows roots: the install script, Cargo, Scoop, winget, Program Files
-- and PATH. Folders are faked as in detect_test.lua.
local test = require("vfox.test")
local plugin = test.load({
    os = "windows",
    arch = "amd64",
})

local env = {}
local files = {}
local outputs = {}
local dirs = {}
local cases = 0

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

-- The handle has read and close only, as vfox's io.popen handle has on Windows.
io.popen = function(command)
    local target = command:match('"(.-)"') or ""
    local output
    if command:find("--version", 1, true) then
        output = outputs[norm(target)] or ""
    else
        output = table.concat(dirs[norm(target)] or {}, "\n")
    end
    return {
        read = function()
            return output
        end,
        close = function()
            return true
        end,
    }
end

--- Puts deno.exe in folder, which prints output for --version.
local function deno_in(folder, output)
    local exe = norm(folder .. "\\deno.exe")
    files[exe] = true
    outputs[exe] = output
end

--- Lists the folders in folder.
local function children(folder, names)
    dirs[norm(folder)] = names
end

local function banner(version)
    return "deno " .. version .. " (stable, release, x86_64-pc-windows-msvc)\r\nv8 13.0.245.12-rusty\r\n"
end

local function summary()
    local lines = {}
    for _, item in ipairs(plugin:Detect({})) do
        table.insert(lines, item.version .. " " .. item.path .. " (" .. item.note .. ")")
    end
    return table.concat(lines, "\n")
end

local function expect(want)
    local got = summary()
    assert(got == want, "expected:\n" .. want .. "\ngot:\n" .. got)
    cases = cases + 1
end

local WINGET = "C:\\Users\\test\\AppData\\Local\\Microsoft\\WinGet\\Packages"
local WINGET_DENO = WINGET .. "\\DenoLand.Deno_Microsoft.Winget.Source_8wekyb3d8bbwe"

env = {
    USERPROFILE = "C:\\Users\\test",
    LOCALAPPDATA = "C:\\Users\\test\\AppData\\Local",
    ProgramFiles = "C:\\Program Files",
    -- Quoted entries lose their quotes, and relative ones are skipped.
    PATH = 'C:\\Tools;"C:\\Program Files\\Deno";C:\\Users\\test\\scoop\\apps\\deno\\current;relative\\bin',
}
deno_in("C:\\Users\\test\\.deno\\bin", banner("2.9.8"))
deno_in("C:\\Users\\test\\scoop\\apps\\deno\\current", banner("2.7.0"))
children(WINGET, { "DenoLand.Deno_Microsoft.Winget.Source_8wekyb3d8bbwe", "Other.Tool_8wekyb3d8bbwe" })
deno_in(WINGET_DENO, banner("2.8.0"))
-- Another package's folder in the same place is not a Deno install.
deno_in(WINGET .. "\\Other.Tool_8wekyb3d8bbwe", banner("9.9.9"))
deno_in("C:\\Program Files\\Deno", banner("2.6.10"))
deno_in("C:\\Tools", banner("2.5.0"))
deno_in("relative\\bin", banner("1.0.0"))
expect(table.concat({
    "2.5.0 C:\\Tools (found on PATH)",
    "2.6.10 C:\\Program Files\\Deno (installed system-wide)",
    "2.7.0 C:\\Users\\test\\scoop\\apps\\deno\\current (installed by Scoop)",
    "2.8.0 " .. WINGET_DENO .. " (installed by winget)",
    "2.9.8 C:\\Users\\test\\.deno\\bin (installed by the Deno install script)",
}, "\n"))

-- The Scoop folder is found through SCOOP when it is set, and the install
-- script's folder through DENO_INSTALL.
files = {}
outputs = {}
dirs = {}
env = {
    USERPROFILE = "C:\\Users\\test",
    SCOOP = "D:\\scoop",
    DENO_INSTALL = "D:\\deno",
    PATH = "",
}
deno_in("D:\\scoop\\apps\\deno\\current", banner("2.7.0"))
deno_in("D:\\deno\\bin", banner("2.9.8"))
expect(table.concat({
    "2.7.0 D:\\scoop\\apps\\deno\\current (installed by Scoop)",
    "2.9.8 D:\\deno\\bin (installed by the Deno install script)",
}, "\n"))

print("PASS: " .. cases .. " Windows Detect cases")
