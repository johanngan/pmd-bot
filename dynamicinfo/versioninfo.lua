-- Reading game version info

require 'utils.enum'

versioninfo = {}

local REGION, REGION_NAMES = enum.register({'NA', 'EU', 'JP'}, 1, 'region')
local GAME, GAME_NAMES = enum.register({'Time', 'Darkness', 'Sky'}, 1, 'game')

local function version(region, game)
    return {region=region, game=game}
end

local function cmpVersion(v1, v2)
    return v1.region == v2.region and v1.game == v2.game
end

-- https://github.com/SkyTemple/skytemple-files/blob/master/skytemple_files/_resources/ppmdu_config/pmd2data.xml#L37
local VERSION_CODES = {
    [0x271A] = version(REGION.NA, GAME.Sky),
    [0x0854] = version(REGION.NA, GAME.Sky), -- Wii U VC
    [0x6AD6] = version(REGION.NA, GAME.Darkness),
    [0xE309] = version(REGION.NA, GAME.Time),

    [0x64AF] = version(REGION.EU, GAME.Sky),
    [0x2773] = version(REGION.EU, GAME.Sky), -- Wii U VC
    [0xBB01] = version(REGION.EU, GAME.Darkness),
    [0x725F] = version(REGION.EU, GAME.Time),

    [0x87B5] = version(REGION.JP, GAME.Sky),
    [0x30C6] = version(REGION.JP, GAME.Darkness),
    [0x09C7] = version(REGION.JP, GAME.Time)
}

local SUPPORTED_VERSIONS = {
    version(REGION.NA, GAME.Sky),
}

-- Read the game version. Returns nil if unknown.
function versioninfo.getVersion()
    return VERSION_CODES[memory.readword(0x0200000E, 0x0200000F)]
end

local function versionStr(v)
    if v == nil then
        return 'Unknown'
    end
    return '[' .. REGION_NAMES[v.region] .. '] ' .. 'Explorers of ' .. GAME_NAMES[v.game]
end

function versioninfo.getVersionName()
    return versionStr(versioninfo.getVersion())
end

local function isSupported(v)
    for _, supported in ipairs(SUPPORTED_VERSIONS) do
        if cmpVersion(v, supported) then
            return true
        end
    end
    return false
end

local function printSupportedVersions()
    print('Supported versions:')
    for i, v in ipairs(SUPPORTED_VERSIONS) do
        print('- ' .. versionStr(v))
    end
    print('')
end

local function validate(v)
    if v == nil then
        error('Detected unknown version')
    end
    if not isSupported(v) then
        error('Detected unsupported version: ' .. versionStr(v))
    end
end

function versioninfo.validateVersion()
    status, err = pcall(validate, versioninfo.getVersion())
    if not status then
        printSupportedVersions()
        error(err)
    end
end

return versioninfo