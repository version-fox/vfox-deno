
local util = {}

util.ReleaseURL = "https://raw.githubusercontent.com/denoland/deno/main/Releases.md"
util.DownloadURL = "https://github.com/denoland/deno/releases/download/v%s/%s"

function util:getOsTypeAndArch()
    local osType = RUNTIME.osType
    local archType = RUNTIME.archType
    if RUNTIME.osType == "darwin" then
        osType = "apple-darwin"
    elseif RUNTIME.osType == "windows" then
        osType = "pc-windows-msvc"
    elseif RUNTIME.osType == "linux" then
        osType = "unknown-linux-gnu"
    else
        error("Deno does not support " .. RUNTIME.osType .. " os")
    end
    if RUNTIME.archType == "amd64" then
        archType = "x86_64"
    elseif RUNTIME.archType == "arm64" then
        archType = "aarch64"
    else
        error("Deno does not support " .. RUNTIME.archType .. " architecture")
    end
    return {
        osType = osType, archType = archType
    }
end



return util