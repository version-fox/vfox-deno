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

--- Finds Deno installs that are already on the machine, for `vfox link --detect`.
--- A candidate folder counts when it holds the `deno` executable, and the
--- version is what that executable reports from `deno --version`, so a file
--- that is not a working Deno is skipped.
local detect = {}

--- Reports whether the platform is Windows, which changes the path separator,
--- the shell commands, the executable's name and the home directory.
--- @return boolean
local function is_windows()
    return RUNTIME ~= nil and RUNTIME.osType == "windows"
end

--- Returns the name of the Deno executable on this platform.
--- @return string
local function exe_name()
    if is_windows() then
        return "deno.exe"
    end
    return "deno"
end

--- Returns the path separator of this platform.
--- @return string
local function sep()
    if is_windows() then
        return "\\"
    end
    return "/"
end

--- Joins two path segments with the platform separator.
--- @param left string
--- @param right string
--- @return string
function detect.join(left, right)
    local last = left:sub(-1)
    if last == "/" or last == "\\" then
        return left .. right
    end
    return left .. sep() .. right
end

--- Joins segments onto base, or returns "" when base is missing, so an unset
--- variable never turns into a path relative to the root.
--- @param base string|nil
--- @return string
local function from(base, ...)
    if base == nil or base == "" then
        return ""
    end
    local path = base
    for _, segment in ipairs({ ... }) do
        path = detect.join(path, segment)
    end
    return path
end

--- Returns value without the blanks around it.
--- @param value string
--- @return string
local function trim(value)
    return (value:match("^%s*(.-)%s*$"))
end

--- Returns a directory path without its trailing separators, in lower case on
--- Windows, so one folder written two ways is seen once.
--- @param path string
--- @return string
local function key(path)
    local value = (path:gsub("[/\\]+$", ""))
    if is_windows() then
        value = value:lower()
    end
    return value
end

--- Reports whether a path is inside vfox's own directories: any `.vfox`
--- folder, or the folder VFOX_HOME names. vfox's installs are never offered
--- back as found installs.
--- @param path string
--- @return boolean
local function is_vfox_managed(path)
    local normalized = (path:gsub("\\", "/")):lower() .. "/"
    if normalized:find("/.vfox/", 1, true) ~= nil then
        return true
    end
    local vfox_home = os.getenv("VFOX_HOME")
    if vfox_home ~= nil and vfox_home ~= "" then
        local root = (vfox_home:gsub("\\", "/")):lower():gsub("/+$", "") .. "/"
        if normalized:sub(1, #root) == root then
            return true
        end
    end
    return false
end

--- Reports whether path is absolute on this platform. Relative PATH entries
--- are skipped, as they name a different folder in every directory.
--- @param path string
--- @return boolean
local function is_absolute(path)
    if is_windows() then
        return path:match("^%a:[\\/]") ~= nil or path:sub(1, 2) == "\\\\"
    end
    return path:sub(1, 1) == "/"
end

--- Quotes a path for the shell that io.popen runs commands with.
--- @param path string
--- @return string
local function quote(path)
    if is_windows() then
        return '"' .. path .. '"'
    end
    return "'" .. (path:gsub("'", "'\\''")) .. "'"
end

--- Reports whether a file or folder exists at path.
--- @param path string
--- @return boolean
local function exists(path)
    local file = io.open(path, "rb")
    if file == nil then
        return false
    end
    file:close()
    return true
end

--- Lists the names of the entries in dir, without . and .., or {}. On Windows
--- only folders are listed, which is all the callers look for.
--- @param dir string
--- @return table
local function list_children(dir)
    if dir == "" then
        return {}
    end
    local command
    if is_windows() then
        command = 'dir /b /ad "' .. dir .. '" 2>nul'
    else
        command = "ls -1 " .. quote(dir) .. " 2>/dev/null"
    end
    local handle = io.popen(command, "r")
    if handle == nil then
        return {}
    end
    -- Only read and close are used: vfox's io.popen handle on Windows has no
    -- lines method, so the output is read whole and split here.
    local output = handle:read("*a") or ""
    handle:close()
    local names = {}
    for line in output:gmatch("[^\r\n]+") do
        local name = trim(line)
        if name ~= "" and name ~= "." and name ~= ".." then
            table.insert(names, name)
        end
    end
    return names
end

--- Returns the version that `deno --version` reports first, such as `2.9.8`
--- from `deno 2.9.8 (stable, release, x86_64-unknown-linux-gnu)`, or nil. Build
--- metadata after a plus sign is left out, as `deno 2.7.0+fb4db33` names the
--- release 2.7.0 that `vfox install` names too.
--- @param output string
--- @return string|nil
function detect.parse_version(output)
    if type(output) ~= "string" then
        return nil
    end
    local first_line = output:match("^[^\r\n]*") or ""
    return first_line:match("^%s*deno%s+(%d+%.%d+%.%d+%-[%w%.%-]+)") or first_line:match("^%s*deno%s+(%d+%.%d+%.%d+)")
end

--- Returns the version that the executable reports, or nil when it does not run.
--- @param exe string
--- @return string|nil
local function version_of(exe)
    local stderr = is_windows() and "2>nul" or "2>/dev/null"
    local handle = io.popen(quote(exe) .. " --version " .. stderr, "r")
    if handle == nil then
        return nil
    end
    local output = handle:read("*a") or ""
    handle:close()
    return detect.parse_version(output)
end

--- Orders two versions by their numbers, so 2.10.0 comes after 2.9.8. A
--- pre-release comes before the release it leads to, as 2.2.0-rc.1 before 2.2.0.
--- Returns a negative number when a sorts first, zero when they are equal and a
--- positive number when a sorts last.
--- @param a string
--- @param b string
--- @return integer
function detect.compare(a, b)
    local function split(version)
        local base = version:match("^[%d%.]+") or ""
        local numbers = {}
        for number in base:gmatch("%d+") do
            table.insert(numbers, tonumber(number))
        end
        return numbers, version:sub(#base + 1)
    end
    local numbers_a, rest_a = split(a)
    local numbers_b, rest_b = split(b)
    for i = 1, math.max(#numbers_a, #numbers_b) do
        local x, y = numbers_a[i] or 0, numbers_b[i] or 0
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    if rest_a == rest_b then
        return 0
    end
    if rest_a == "" then
        return 1
    end
    if rest_b == "" then
        return -1
    end
    return rest_a < rest_b and -1 or 1
end

--- Returns the folders that the Deno install script, Cargo, Homebrew, asdf,
--- mise, Scoop, winget and Program Files use, as {kind, path, note, prefix}.
--- kind "dir" holds the executable itself. "versions" holds one folder per
--- version, with the executable in it or in its bin folder. "children" holds
--- one folder per install, and prefix narrows them to the names it starts with.
--- @return table
local function candidate_roots()
    local roots = {}
    local function add(kind, path, note, prefix)
        if path ~= nil and path ~= "" then
            table.insert(roots, { kind = kind, path = path, note = note, prefix = prefix })
        end
    end

    local home = is_windows() and os.getenv("USERPROFILE") or os.getenv("HOME")
    local script_note = "installed by the Deno install script"
    local deno_install = os.getenv("DENO_INSTALL")
    if deno_install ~= nil and deno_install ~= "" then
        add("dir", from(deno_install, "bin"), script_note)
    end
    add("dir", from(home, ".deno", "bin"), script_note)
    add("dir", from(home, ".cargo", "bin"), "installed by Cargo")

    if is_windows() then
        local scoop = os.getenv("SCOOP")
        if scoop ~= nil and scoop ~= "" then
            add("dir", from(scoop, "apps", "deno", "current"), "installed by Scoop")
        end
        add("dir", from(home, "scoop", "apps", "deno", "current"), "installed by Scoop")
        local local_app_data = os.getenv("LOCALAPPDATA")
        add("children", from(local_app_data, "Microsoft", "WinGet", "Packages"), "installed by winget", "DenoLand.Deno")
        local program_files = os.getenv("ProgramFiles") or "C:\\Program Files"
        add("dir", from(program_files, "Deno"), "installed system-wide")
    else
        add("dir", from("/opt/homebrew", "opt", "deno", "bin"), "installed by Homebrew")
        add("dir", from("/usr/local", "opt", "deno", "bin"), "installed by Homebrew")
        add("dir", from("/home/linuxbrew/.linuxbrew", "opt", "deno", "bin"), "installed by Homebrew")
        add("dir", from(home, ".linuxbrew", "opt", "deno", "bin"), "installed by Homebrew")
        add("versions", from(home, ".asdf", "installs", "deno"), "installed by asdf")
        add("versions", from(home, ".local", "share", "mise", "installs", "deno"), "installed by mise")
        local mise_data = os.getenv("MISE_DATA_DIR")
        add("versions", from(mise_data, "installs", "deno"), "installed by mise")
    end
    return roots
end

--- Returns the folders of PATH that are absolute, in order.
--- @return table
local function path_entries()
    local value = os.getenv("PATH") or ""
    local separator = is_windows() and ";" or ":"
    local entries = {}
    for entry in (value .. separator):gmatch("(.-)" .. separator) do
        local dir = (trim(entry):gsub('^"(.*)"$', "%1"))
        if dir ~= "" and is_absolute(dir) then
            table.insert(entries, dir)
        end
    end
    return entries
end

--- Finds every Deno install on the machine that vfox did not install. The
--- fixed locations come first, then PATH. Each version is reported once, from
--- the first location that holds it, and the list is sorted by version.
--- @return table Found installs as { version, path, note }, where path is the folder holding deno
function detect.find_all()
    local found = {}
    local seen_dirs = {}
    local seen_versions = {}

    local function consider(dir, note)
        if dir == "" or seen_dirs[key(dir)] or is_vfox_managed(dir) then
            return
        end
        seen_dirs[key(dir)] = true
        local exe = detect.join(dir, exe_name())
        if not exists(exe) then
            return
        end
        local version = version_of(exe)
        if version == nil or seen_versions[version] then
            return
        end
        seen_versions[version] = true
        table.insert(found, { version = version, path = dir, note = note })
    end

    for _, root in ipairs(candidate_roots()) do
        if root.kind == "dir" then
            consider(root.path, root.note)
        elseif root.kind == "children" then
            for _, name in ipairs(list_children(root.path)) do
                if root.prefix == nil or name:sub(1, #root.prefix) == root.prefix then
                    consider(detect.join(root.path, name), root.note)
                end
            end
        elseif root.kind == "versions" then
            for _, name in ipairs(list_children(root.path)) do
                local version_dir = detect.join(root.path, name)
                consider(version_dir, root.note)
                consider(detect.join(version_dir, "bin"), root.note)
            end
        end
    end
    for _, dir in ipairs(path_entries()) do
        consider(dir, "found on PATH")
    end

    table.sort(found, function(a, b)
        return detect.compare(a.version, b.version) < 0
    end)
    return found
end

return detect
