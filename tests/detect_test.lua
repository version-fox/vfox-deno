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

-- Detect looks at folders and runs `deno --version`. The VM disables io.popen,
-- so this file replaces the environment, the file system and the processes with
-- tables: the files that exist, the output each executable prints, and the
-- entries of each folder.
local test = require("vfox.test")
local plugin = test.load({
    os = "linux",
    arch = "amd64",
})
local detect = require("detect_deno")

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

io.popen = function(command)
    local target = command:match("'(.-)'") or command:match('"(.-)"') or ""
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
        lines = function()
            return output:gmatch("[^\r\n]+")
        end,
        close = function()
            return true
        end,
    }
end

--- Forgets the files, outputs and folders of the previous scenario.
local function reset(platform_env)
    env = platform_env
    files = {}
    outputs = {}
    dirs = {}
end

--- Puts an executable called name (deno by default) in folder, which prints output for --version.
local function deno_in(folder, output, name)
    local exe = norm(folder .. "/" .. (name or "deno"))
    files[exe] = true
    outputs[exe] = output
end

--- Lists the children of folder, as the platform's ls or dir would.
local function children(folder, names)
    dirs[norm(folder)] = names
end

--- The text `deno --version` prints first.
local function banner(version)
    return "deno "
        .. version
        .. " (stable, release, x86_64-unknown-linux-gnu)\nv8 13.0.245.12-rusty\ntypescript 5.9.2\n"
end

--- The installs Detect returns, one line each: version, path and note.
local function summary()
    local lines = {}
    for _, item in ipairs(plugin:Detect({})) do
        table.insert(lines, item.version .. " " .. item.path .. " (" .. item.note .. ")")
    end
    return table.concat(lines, "\n")
end

--- Checks that Detect returns exactly the lines of want.
local function expect(want)
    local got = summary()
    assert(got == want, "expected:\n" .. want .. "\ngot:\n" .. got)
    cases = cases + 1
end

-- The version is the first line of `deno --version`, and only a Deno banner counts.
assert(detect.parse_version(banner("2.9.8")) == "2.9.8")
assert(detect.parse_version("deno 2.2.0-rc.1 (release, x86_64-unknown-linux-gnu)\n") == "2.2.0-rc.1")
assert(detect.parse_version("deno 2.7.0 (stable, release, aarch64-pc-windows-msvc)\r\n") == "2.7.0")
-- Build metadata after the plus sign is not part of the version name.
assert(detect.parse_version("deno 2.7.0+fb4db33 (stable, release, x86_64-unknown-linux-gnu)\n") == "2.7.0")
assert(detect.parse_version("deno 2.2.0-rc.1+abc1234 (release, x86_64-unknown-linux-gnu)\n") == "2.2.0-rc.1")
assert(detect.parse_version("") == nil)
assert(detect.parse_version("node v22.1.0\n") == nil)
---@diagnostic disable-next-line: param-type-mismatch
assert(detect.parse_version(nil) == nil)
cases = cases + 1

-- Versions sort by their numbers, and a pre-release comes before its release.
local sorted = { "2.10.0", "2.9.8", "2.2.0", "2.2.0-rc.1", "1.46.3" }
table.sort(sorted, function(a, b)
    return detect.compare(a, b) < 0
end)
assert(table.concat(sorted, " ") == "1.46.3 2.2.0-rc.1 2.2.0 2.9.8 2.10.0", table.concat(sorted, " "))
cases = cases + 1

-- The install script's folder, from DENO_INSTALL and from ~/.deno.
reset({ HOME = "/home/test", DENO_INSTALL = "/custom/deno", PATH = "/usr/bin" })
deno_in("/custom/deno/bin", banner("2.9.8"))
expect("2.9.8 /custom/deno/bin (installed by the Deno install script)")

reset({ HOME = "/home/test", PATH = "/usr/bin" })
deno_in("/home/test/.deno/bin", banner("2.9.8"))
expect("2.9.8 /home/test/.deno/bin (installed by the Deno install script)")

-- Cargo, asdf, mise and PATH together. Each version appears once, and the
-- folders are found in the order the fixed locations come first.
reset({
    HOME = "/home/test",
    PATH = "/usr/local/bin:relative/bin:/home/test/.vfox/bin:/data/vfox/bin",
    VFOX_HOME = "/data/vfox",
})
deno_in("/home/test/.cargo/bin", banner("2.7.0"))
children("/home/test/.asdf/installs/deno", { "2.1.4", "2.2.0-rc.1" })
deno_in("/home/test/.asdf/installs/deno/2.1.4/bin", banner("2.1.4"))
deno_in("/home/test/.asdf/installs/deno/2.2.0-rc.1", banner("2.2.0-rc.1"))
children("/home/test/.local/share/mise/installs/deno", { "2.6.10" })
deno_in("/home/test/.local/share/mise/installs/deno/2.6.10", banner("2.6.10"))
deno_in("/usr/local/bin", banner("2.9.8"))
-- Relative PATH entries, and anything under vfox's own folders, are never reported.
deno_in("relative/bin", banner("1.0.0"))
deno_in("/home/test/.vfox/bin", banner("2.0.0"))
deno_in("/data/vfox/bin", banner("2.0.1"))
expect([[
2.1.4 /home/test/.asdf/installs/deno/2.1.4/bin (installed by asdf)
2.2.0-rc.1 /home/test/.asdf/installs/deno/2.2.0-rc.1 (installed by asdf)
2.6.10 /home/test/.local/share/mise/installs/deno/2.6.10 (installed by mise)
2.7.0 /home/test/.cargo/bin (installed by Cargo)
2.9.8 /usr/local/bin (found on PATH)]])

-- A folder reached twice, or a version found twice, is reported once: the first wins.
reset({ HOME = "/home/test", DENO_INSTALL = "/custom/deno", PATH = "/home/test/.deno/bin:/custom/deno/bin" })
deno_in("/custom/deno/bin", banner("2.9.8"))
deno_in("/home/test/.deno/bin", banner("2.9.8"))
expect("2.9.8 /custom/deno/bin (installed by the Deno install script)")

-- A file named deno that does not run is not an install.
reset({ HOME = "/home/test", PATH = "/usr/bin" })
deno_in("/usr/bin", "")
expect("")

-- Nothing installed means nothing found.
reset({ HOME = "/home/test", PATH = "/usr/bin" })
expect("")

-- vfox's own folders are never offered, even when they hold a working Deno: a
-- .vfox folder anywhere, and the folder VFOX_HOME names.
reset({
    HOME = "/home/test",
    VFOX_HOME = "/data/vfox",
    PATH = "/home/test/.vfox/cache/deno/v-2.1.4/deno-2.1.4:/data/vfox/sdks/deno/bin",
})
deno_in("/home/test/.vfox/cache/deno/v-2.1.4/deno-2.1.4", banner("2.1.4"))
deno_in("/data/vfox/sdks/deno/bin", banner("2.2.0"))
expect("")

print("PASS: " .. cases .. " Detect cases")
