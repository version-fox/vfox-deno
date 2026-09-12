package.path = "./lib/?.lua;" .. package.path
PLUGIN = {}
RUNTIME = { osType = "linux", archType = "amd64" }
local state = {}
package.preload.http = function()
    return {
        get = function()
            return state.response, state.requestError
        end,
    }
end
dofile("hooks/available.lua")
dofile("hooks/pre_install.lua")
local function fails(fn, expected)
    local ok, err = pcall(fn)
    assert(not ok, "expected error: " .. expected)
    assert(tostring(err):find(expected, 1, true), tostring(err))
end
state.requestError = "timeout"
fails(function()
    PLUGIN:Available({})
end, "timeout")
fails(function()
    PLUGIN:PreInstall({ version = "latest" })
end, "timeout")
state.requestError = nil
state.response = { status_code = 503, body = "unavailable" }
fails(function()
    PLUGIN:Available({})
end, "503")
state.response = { status_code = 200, body = "# Releases\nupstream format changed\n" }
fails(function()
    PLUGIN:PreInstall({ version = "latest" })
end, "No Deno versions")
state.response.body =
    "### 2.1.10 / 2025.01.01\r\n### v2.1.9 / 2024.12.20\n### 2.1.10 / 2025.01.01\n#### Other notes\n### 2.2.0-rc.1 / 2025.01.02\n"
local versions = PLUGIN:Available({})
assert(#versions == 2, #versions)
assert(versions[1].version == "2.1.10")
assert(versions[2].version == "2.1.9")
assert(PLUGIN:PreInstall({ version = "latest" }).version == "2.1.10")
assert(PLUGIN:PreInstall({ version = "2.1" }).version == "2.1.10")
assert(PLUGIN:PreInstall({ version = "2.1.9" }).version == "2.1.9")
fails(function()
    PLUGIN:PreInstall({ version = "9.9.9" })
end, "Could not resolve")
print("Deno network, parsing and resolution cases passed")
