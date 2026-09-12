local util = require("util")
local http = require("http")
--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    local resp, err = http.get({
        url = util.ReleaseURL,
    })
    if err ~= nil or resp == nil then
        error("Failed to fetch Deno releases from " .. util.ReleaseURL .. ": " .. tostring(err or "empty response"))
    end
    if resp.status_code ~= 200 then
        error("Failed to fetch Deno releases: HTTP " .. tostring(resp.status_code))
    end
    local result = {}
    local seen = {}
    for line in string.gmatch(resp.body or "", "[^\r\n]+") do
        local version = line:match("^###%s+v?(%d+%.%d+%.%d+)%s*/")
        if version and not seen[version] then
            seen[version] = true
            table.insert(result, {
                version = version,
                note = "",
            })
        end
    end
    if #result == 0 then
        error("No Deno versions found in " .. util.ReleaseURL .. "; the upstream response may have changed")
    end
    return result
end
