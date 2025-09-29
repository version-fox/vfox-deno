local util = require("util")
--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    local lists = self:Available({})

    if version == "latest" then
        return result(lists[1].version)
    end

    local prefix = version .. "."
    for k, v in ipairs(lists) do
        if v.version == version then
            return result(v.version)
        elseif string.sub(v.version, 1, #prefix) == prefix then
            return result(v.version)
        end
    end

    error("Could not resolve version: " .. tostring(version))
end

function result(version)
    local type = util:getOsTypeAndArch()
    local filename = "deno-" .. type.archType .. "-" .. type.osType .. ".zip"
    return {
        version = version,
        url = util.DownloadURL:format(version, filename)
    }
end
