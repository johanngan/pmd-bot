-- Helpers for reading monster statuses from memory; separated from entityHelpers
-- because they're annoying.

require 'table'
require 'codes.status'

local statusHelpers = {}

-- These statuses have an ID represented by a byte, with the value of that byte
-- being an offset for the status value. The "origin" for this status code varies by byte.
-- The status code when the byte is set to 1 (the "one value") is specified to fix the origin.
-- Some statuses also have an associated turn counter, and some also have an associated
-- effect (damage/healing) countdown. The offset of these can be optionally specified
local function readMultiStatusIndicator(infoTableStart, offset, oneValue,
    turnsOffset, effectOffset)
    local statusFlag = memory.readbytesigned(infoTableStart + offset)
    -- If the status flag is 0, it's inactive
    if statusFlag == 0 then return nil end

    local status = {}
    status.statusType = statusFlag - 1 + oneValue

    if turnsOffset then
        local turns = memory.readbyteunsigned(infoTableStart + turnsOffset)
        -- If turns is 0, then it's not applicable to the status; leave as nil
        if turns ~= 0 then
            status.turnsLeft = turns
        end
    end
    if effectOffset then
        -- If not applicable, this will just sit at 0
        status.effectCountdown = memory.readbyteunsigned(infoTableStart + effectOffset)
    end

    return status
end

-- These statuses "own" an entire byte to use as an indicator. They don't have any
-- associated counters
local function readSingleStatusIndicator(infoTableStart, offset, statusType)
    local statusFlag = memory.readbyteunsigned(infoTableStart + offset)
    -- If the status flag is 0; it's inactive
    return (statusFlag ~= 0) and {statusType=statusType} or nil
end


-- (offset, oneValue, [turnsOffset, [effectOffset]])
local multiStatusIndicators = {
    {0x0BD, codes.STATUS.Sleep, 0x0BE},
    {0x0BF, codes.STATUS.Burn, 0x0C0, 0x0C1},
    {0x0C4, codes.STATUS.Frozen, 0x0CC, 0x0CD},
    {0x0D0, codes.STATUS.Cringe, 0x0D1},
    {0x0D2, codes.STATUS.Bide, 0x0D3},
    {0x0D5, codes.STATUS.Reflect, 0x0D6, 0x0D7},
    {0x0D8, codes.STATUS.Cursed, 0x0DB, 0x0DC},
    {0x0E0, codes.STATUS.LeechSeed, 0x0E9, 0x0EA},
    {0x0EC, codes.STATUS.SureShot, 0x0ED},
    {0x0EE, codes.STATUS.LongToss},
    {0x0EF, codes.STATUS.Invisible, 0x0F0},
    {0x0F1, codes.STATUS.Blinker, 0x0F2},
    {0x0F3, codes.STATUS.Muzzled, 0x0F4},
    {0x0F5, codes.STATUS.MiracleEye, 0x0F6},
    {0x0F7, codes.STATUS.MagnetRise, 0x0F8},
}
-- (offset, statusType)
local singleStatusIndicators = {
    {0x0A9, codes.STATUS.Roost},
    {0x0F9, codes.STATUS.PowerEars},
    {0x0FA, codes.STATUS.Scanning},
    {0x0FB, codes.STATUS.StairSpotter},
    {0x0FD, codes.STATUS.Grudge},
    {0x0FE, codes.STATUS.Exposed},
}

-- Read a monster's statuses given the start address of its info table
-- Known status offsets: 0x0A9-11E
-- Each status is a table with an ID, and optional fields for turns left and damage countdowns
function statusHelpers.readStatusList(infoTableStart)
    local statuses = {}
    for _, args in ipairs(multiStatusIndicators) do
        table.insert(statuses, readMultiStatusIndicator(infoTableStart, unpack(args)))
    end
    for _, args in ipairs(singleStatusIndicators) do
        table.insert(statuses, readSingleStatusIndicator(infoTableStart, unpack(args)))
    end

    -- Weird "status" thing(?) where the Moves/Items/Team/Ground menu options are disabled
    local menuOptionsDisabled = memory.readbyteunsigned(infoTableStart + 0x104)
    if menuOptionsDisabled ~= 0 then
        table.insert(statuses, {
            statusType = codes.STATUS.MenuOptionsDisabled,
            turnsLeft = memory.readbyteunsigned(infoTableStart + 0x105)
        })
    end

    -- Perish Song and Stockpile are indicated by a single byte, with 0 meaning inactive
    -- and nonzero meaning a counter value
    local perishSongTurns = memory.readbyteunsigned(infoTableStart + 0x106)
    if perishSongTurns ~= 0 then
        table.insert(statuses, {
            statusType = codes.STATUS.PerishSong,
            turnsLeft = perishSongTurns,
            damageCountdown = perishSongTurns,
        })
    end

    local stockpileStage = memory.readbyteunsigned(infoTableStart + 0x11E)
    if stockpileStage ~= 0 then
        table.insert(statuses, {
            statusType = codes.STATUS.Stockpiling,
            stage = stockpileStage, -- A SPECIAL FIELD JUST FOR STOCKPILE
        })
    end

    return statuses
end

return statusHelpers