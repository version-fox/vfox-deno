local util = require("util")
local http = require("http")
--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    local resp, err = http.get({
        url = util.ReleaseURL
    })
    if err ~= nil or resp.status_code ~= 200 then
        return {}
    end
    local result = {}
    for line in string.gmatch(resp.body, '([^\n]*)\n?') do
        if string.match(line, "^###") then
            local start = string.sub(line, 5)
            local version = string.sub(start, 1, -14)
            if string.sub(version, 1, 1) == "v" then
                version = string.sub(version, 2)
            end
            table.insert(result, {
                version = version,
                note = ""
            })
        end
    end
    return result
end