require 'math'

require 'codes.move'
require 'codes.moveCategory'
require 'codes.moveRange'
require 'codes.terrain'
require 'utils.pathfinder'
local rangeutils = require 'mechanics.rangeutils'
require 'mechanics.LookupTable'

if mechanics == nil then
    mechanics = {}
end

mechanics.move = LookupTable:new('mechanics/data/move_data.csv')

-- Functions for testing if a target is in range of a move range class.
-- All the functions take in positions for a target (x, y) and a user (x0, y0),
-- and a floor layout object. They return true if the target is in range,
-- false if the target is out of range, or nil if it's uncertain.
local function inRangeSpecial(x, y, x0, y0, layout)
    -- These moves are special; no way to know the range without more info
    return nil
end

local function inRangeUser(x, y, x0, y0, layout)
    -- These moves can be used anywhere
    return true
end

local function inRangeUnderfoot(x, y, x0, y0, layout)
    -- These moves can be used on any open floor tiles within a room,
    -- with the exception of junctions (room exits), stairs, and shops.
    -- (halls, walls, or any other out-of-room-tiles are not allowed)
    local tile = layout[y0][x0]
    return tile.terrain == codes.TERRAIN.Normal and tile.room >= 0
        and not tile.isJunction and not tile.isStairs and not tile.inShop
end

-- "Walkable" for attacks when pathfinding
local function attackCanPass(terrain)
    return terrain == codes.TERRAIN.Normal
        or terrain == codes.TERRAIN.WaterOrLava
        or terrain == codes.TERRAIN.Chasm
end
local function inRangeFront(x, y, x0, y0, layout)
    local path = pathfinder.getPath(layout, x0, y0, x, y, attackCanPass)
    -- Path includes starting point; 1 step away gives a path of 2
    return path ~= nil and #path <= 2
end

local function inRangeFrontWithCornerCutting(x, y, x0, y0, layout)
    return rangeutils.inRange(x, y, x0, y0, 1) and attackCanPass(layout[y][x].terrain)
end

local function inRangeFrontAndSides(x, y, x0, y0, layout)
    -- Wide Slash can hit in walls
    return rangeutils.inRange(x, y, x0, y0, 1)
end

local function inRangeNearby(x, y, x0, y0, layout)
    -- 1-tile AOE moves. These also hit in walls
    return rangeutils.inRange(x, y, x0, y0, 1)
end

local function sign(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end
-- General function for n=2, n=10
local function inRangeFrontN(x, y, x0, y0, layout, n)
    local dx = x - x0
    local dy = y - y0
    local dx_abs = math.abs(dx)
    local dy_abs = math.abs(dy)
    if dx_abs <= n and dy_abs <= n and
        (dx == 0 or dy == 0 or dx_abs == dy_abs) then
        -- The positioning is right; now check all tiles in between the user/target
        local dx_sgn = sign(dx)
        local dy_sgn = sign(dy)
        for i=1,math.max(dx_abs, dy_abs) do
            if not attackCanPass(layout[y0 + i*dy_sgn][x0 + i*dx_sgn].terrain) then
                return false
            end
        end
        return true
    end
    return false
end
local function inRangeFront2(x, y, x0, y0, layout)
    return inRangeFrontN(x, y, x0, y0, layout, 2)
end

local function inRangeNearby2(x, y, x0, y0, layout)
    -- Just Explosion. 2-tile AOE
    return rangeutils.inRange(x, y, x0, y0, 2)
end

local function inRangeFront10(x, y, x0, y0, layout)
    return inRangeFrontN(x, y, x0, y0, layout, 10)
end

local function inRangeRoom(x, y, x0, y0, layout)
    -- If in room: all tiles in the room + the surrounding boundary
    local roomRange = rangeutils.inRoomRange(x, y, x0, y0, layout)
    if roomRange ~= nil then return roomRange end
    -- If in hall: within a 2 tile radius
    return rangeutils.inRange(x, y, x0, y0, 2)
end

local function inRangeFloor(x, y, x0, y0, layout)
    -- Everything is in range
    return true
end

mechanics.move.inRange = {
    [codes.MOVE_RANGE.Special] = inRangeSpecial,
    [codes.MOVE_RANGE.User] = inRangeUser,
    [codes.MOVE_RANGE.Underfoot] = inRangeUnderfoot,
    [codes.MOVE_RANGE.Front] = inRangeFront,
    [codes.MOVE_RANGE.FrontWithCornerCutting] = inRangeFrontWithCornerCutting,
    [codes.MOVE_RANGE.FrontAndSides] = inRangeFrontAndSides,
    [codes.MOVE_RANGE.Nearby] = inRangeNearby,
    [codes.MOVE_RANGE.Front2] = inRangeFront2,
    [codes.MOVE_RANGE.Nearby2] = inRangeNearby2,
    [codes.MOVE_RANGE.Front10] = inRangeFront10,
    [codes.MOVE_RANGE.Room] = inRangeRoom,
    [codes.MOVE_RANGE.Floor] = inRangeFloor,
}

-- Maps moves that can hit multiple targest to the
-- maximum number of targets they can hit, not including the user
-- -1 denotes unknown
local AOE_RANGES = {
    [codes.MOVE_RANGE.Special] = -1,    -- Unknown
    [codes.MOVE_RANGE.FrontAndSides] = 5,
    [codes.MOVE_RANGE.Nearby] = 8,
    [codes.MOVE_RANGE.Nearby2] = 24,
    [codes.MOVE_RANGE.Room] = math.huge,    -- Arbitrarily large
    [codes.MOVE_RANGE.Floor] = math.huge,   -- Arbitrarily large
}
-- Check if a move can hit multiple targets at once.
-- Optionally, specify how many targets is considered "AOE".
-- Returns nil if unknown
function mechanics.move.isAOE(moveID, nEnemies)
    local aoeRange = AOE_RANGES[mechanics.move(moveID).range]
    if aoeRange == -1 then return nil end
    local nEnemies = nEnemies or 2
    return aoeRange ~= nil and aoeRange >= nEnemies
end

-- Maps moves to whether or not they can hit teammates. A value of
-- 1 means the intended targets are teammates, 2 means teammates probably
-- aren't intended targets. -1 Means unknown
local FRIENDLY_FIRE = {
    [codes.MOVE_TARGET.Party] = 1,
    [codes.MOVE_TARGET.All] = 2,
    [codes.MOVE_TARGET.AllExceptUser] = 2,
    [codes.MOVE_TARGET.Teammates] = 1,
    [codes.MOVE_TARGET.Special] = -1,
}
-- Check if a move can hit teammates, optionally, include moves whose
-- intended targets are teammates (like certain status moves)
-- Returns nil if unknown
function mechanics.move.hasFriendlyFire(moveID, allowIntended)
    local friendlyFire = FRIENDLY_FIRE[mechanics.move(moveID).target]
    if friendlyFire == -1 then return nil end
    local threshold = allowIntended and 1 or 2
    return friendlyFire ~= nil and friendlyFire >= threshold
end

-- Most moves with a nonstatus category are offensive in a typical sense,
-- with the exception of these moves. Only the table keys matter here;
-- the values are dummy values
local NONOFFENSIVE_NONSTATUS_MOVES = {
    [codes.MOVE.Nothing] = true,
    [codes.MOVE.VitalThrow] = true,
    [codes.MOVE.Pursuit] = true,
    [codes.MOVE.Strength] = true,
    [codes.MOVE.Counter] = true,
    [codes.MOVE.Bide] = true,
    [codes.MOVE.KnockOff] = true,
    [codes.MOVE.MirrorCoat] = true,
    [codes.MOVE.Revenge] = true,
    [codes.MOVE.Avalanche] = true,
    [codes.MOVE.Payback] = true,
    [codes.MOVE.MetalBurst] = true,
}
-- Most status moves are non-offensive, with the exception of these moves
-- 1 means the "status" move is offensive, -1 means it's unknown (depends)
local POSSIBLY_OFFENSIVE_STATUS_MOVES = {
    [codes.MOVE.NaturePower] = 1,   -- Will be some offensive move
    [codes.MOVE.SleepTalk] = -1,
    [codes.MOVE.Assist] = -1,
    [codes.MOVE.Metronome] = -1,
    [codes.MOVE.MeFirst] = -1,  -- Usually offensive, but fails if the target has no offensive moves
}

-- Check if a move is offensive or not. Returns nil if unknown
function mechanics.move.isOffensive(moveID)
    local cat = mechanics.move(moveID).category
    if cat == codes.MOVE_CATEGORY.Status then
        local statusOffensive = POSSIBLY_OFFENSIVE_STATUS_MOVES[moveID]
        if statusOffensive ~= nil then
            if statusOffensive == -1 then
                return nil
            end
            return true
        end
        return false
    end
    return not NONOFFENSIVE_NONSTATUS_MOVES[moveID]
end