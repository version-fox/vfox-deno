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

-- PostInstall runs chmod on deno in the SDK installation directory, then checks
-- that deno is executable. The VM disables io.popen, so this file replaces it
-- with a table that records each command and answers with the output the shell
-- would print: chmod's own messages, then "done" when deno is executable.
local test = require("vfox.test")
local plugin = test.load({
    os = "linux",
    arch = "amd64",
})

local commands = {}
local printed = ""
local spawn_fails = false

io.popen = function(command)
    table.insert(commands, command)
    if spawn_fails then
        return nil
    end
    return {
        read = function()
            return printed
        end,
        close = function()
            return true
        end,
    }
end

-- vfox 1.1.0 gives the version folder as rootPath, and the SDK folder, the one
-- that holds deno, in sdkInfo.
local ROOT = "/home/test/.vfox/cache/deno/v-0.36.0"
local SDK = ROOT .. "/deno-0.36.0"
local DENO = SDK .. "/deno"
local cases = 0

--- The context PostInstall gets when the SDK folder is sdk_path.
local function context(sdk_path)
    return {
        rootPath = ROOT,
        sdkInfo = { deno = { name = "deno", version = "0.36.0", path = sdk_path } },
    }
end

--- The command PostInstall runs for the file at path, written as the shell reads it between single quotes.
local function command_for(path)
    return "chmod 755 '" .. path .. "' 2>&1; test -x '" .. path .. "' && echo done"
end

--- Checks that PostInstall for ctx runs exactly one command, want, and succeeds because the shell printed output.
local function sets_bit(ctx, want, output)
    printed = output
    commands = {}
    plugin:PostInstall(ctx)
    assert(#commands == 1, "expected one command, got " .. #commands)
    assert(commands[1] == want, "expected " .. want .. ", got " .. commands[1])
    cases = cases + 1
end

--- Checks that PostInstall for ctx, with the shell printing output, fails with an error containing want.
local function fails(ctx, output, want)
    printed = output
    local ok, err = pcall(function()
        plugin:PostInstall(ctx)
    end)
    assert(not ok, "expected an error: " .. want)
    assert(tostring(err):find(want, 1, true), tostring(err))
    cases = cases + 1
end

-- Linux: chmod 755 on deno, then test that it is executable.
sets_bit(context(SDK), command_for(DENO), "done\n")

-- macOS installs are the same, and the same command runs.
RUNTIME.osType = "darwin"
sets_bit(context(SDK), command_for(DENO), "done\n")
RUNTIME.osType = "linux"

-- A folder with a space and a quote in its name is quoted for the shell.
sets_bit(
    context("/home/test/it's here/deno-0.36.0"),
    command_for("/home/test/it'\\''s here/deno-0.36.0/deno"),
    "done\n"
)

-- Without SDK information, the root path is the folder that holds deno.
sets_bit({ rootPath = "/home/test/flat" }, command_for("/home/test/flat/deno"), "done\n")

-- chmod is refused, but deno is executable already: the install goes on.
sets_bit(
    context(SDK),
    command_for(DENO),
    "chmod: changing permissions of '" .. DENO .. "': Operation not permitted\ndone\n"
)

-- Windows has no execute bit: nothing runs, and nothing is an error.
RUNTIME.osType = "windows"
printed = ""
commands = {}
plugin:PostInstall(context(SDK))
assert(#commands == 0, "expected no command on Windows, got " .. #commands)
cases = cases + 1
RUNTIME.osType = "linux"

-- deno is still not executable after chmod: the error names the file and carries
-- the message chmod printed, or says so when chmod printed nothing.
local MISSING = "chmod: cannot access '" .. DENO .. "': No such file or directory"
local DENIED = "chmod: changing permissions of '" .. DENO .. "': Operation not permitted"
fails(context(SDK), MISSING .. "\n", "Cannot set the execute bit on " .. DENO .. ": " .. MISSING)
fails(context(SDK), DENIED .. "\n", "Cannot set the execute bit on " .. DENO .. ": " .. DENIED)
fails(context(SDK), "", "Cannot set the execute bit on " .. DENO .. ": the file is still not executable")

-- The shell cannot be started at all.
spawn_fails = true
fails(context(SDK), "", "Cannot set the execute bit on " .. DENO .. ": the shell could not be started")
spawn_fails = false

print("PASS: " .. cases .. " PostInstall cases")
