local util = require("util")
--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    local type = util:getOsTypeAndArch()
    if version == "latest" then
        local lists = self:Available({})
        version = lists[1].version
    end
    local filename = "deno-" .. type.archType .. "-" .. type.osType .. ".zip"
    return {
        version = version,
        url = util.DownloadURL:format(version, filename),
    }
end