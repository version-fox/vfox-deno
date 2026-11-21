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

--- Returns path in single quotes for the shell that io.popen runs commands
--- with, so a folder whose name has a space or a quote stays one argument.
--- @param path string
--- @return string
local function quote(path)
    return "'" .. (path:gsub("'", "'\\''")) .. "'"
end

--- Extension point, called after PreInstall, can perform additional operations,
--- such as file operations for the SDK installation directory or compile source code.
--- Some Deno archives leave deno without the execute bit: the Linux archive of
--- 0.36.0 holds it as -rw-r--r--, so vfox exec fails with permission denied. On
--- Linux and macOS this sets the bit on deno in the SDK installation directory,
--- which is the folder EnvKeys puts on PATH. Windows has no execute bit, so
--- nothing is done there.
--- @param ctx table Context information
--- ctx.sdkInfo.deno.path is the SDK installation directory. ctx.rootPath is the
--- folder above it, and is used only when vfox gives no SDK information.
function PLUGIN:PostInstall(ctx)
    if RUNTIME.osType == "windows" then
        return
    end
    local sdk = ctx.sdkInfo and ctx.sdkInfo["deno"]
    local exe = ((sdk and sdk.path) or ctx.rootPath) .. "/deno"
    -- chmod's error output is kept. "done" is printed only when deno is executable
    -- afterwards, so a chmod that is refused does no harm when the bit is already set.
    local command = "chmod 755 " .. quote(exe) .. " 2>&1; test -x " .. quote(exe) .. " && echo done"
    local handle = io.popen(command, "r")
    if handle == nil then
        error("Cannot set the execute bit on " .. exe .. ": the shell could not be started")
    end
    local output = handle:read("*a") or ""
    handle:close()
    if output:match("done\n$") == nil then
        local reason = output:gsub("%s+$", "")
        if reason == "" then
            reason = "the file is still not executable"
        end
        error("Cannot set the execute bit on " .. exe .. ": " .. reason)
    end
end
