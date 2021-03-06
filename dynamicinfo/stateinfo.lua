-- Reading state info from memory

require 'table'

require 'codes.weather'

require 'utils.memoryrange'
require 'dynamicinfo.StateData'
require 'dynamicinfo.menuinfo'
local mapHelpers = require 'dynamicinfo.mapHelpers'
local entityHelpers = require 'dynamicinfo.entityHelpers'
local conditionHelpers = require 'dynamicinfo.conditionHelpers'

stateinfo = {}

---- BEGIN STATE DATA MODEL ----
stateinfo.state = {}
local state = stateinfo.state

-- Rough indicator of whether or not the game is accepting input
state.canAct = StateData:new(false)
function state.canAct:read()
    -- This address seems like an action code of some sort; it's
    -- located within the leader's data block. Seems to be 0 when
    -- input is allowed, except for when certain menus and dialogue
    -- boxes are open?
    return memory.readbyte(0x021BA572) == 0 or
        -- If in a menu (that's not a message), you're always in control
        (menuinfo.menuIsOpen() and not menuinfo.messageIsOpen())
end

-- Container for information related to the dungeon
state.dungeon = {}

-- ID of the current dungeon
state.dungeon.dungeonID = StateData:new()
function state.dungeon.dungeonID:read()
    return memory.readwordsigned(0x022AB4FE)
end

-- Visibility radius of the current dungeon
local DEFAULT_VISIBILITY_RADIUS = 2
state.dungeon.visibilityRadius = StateData:new()
function state.dungeon.visibilityRadius:read()
    local visRad = memory.readbyteunsigned(0x021D3F71)
    return (visRad ~= 0 and visRad or DEFAULT_VISIBILITY_RADIUS)
end

-- Current floor #
state.dungeon.floor = StateData:new()
function state.dungeon.floor:read()
    return memory.readbyte(0x021BA47D)
end

-- Floor layout
state.dungeon.layout = StateData:new()
function state.dungeon.layout:read()
    local layout = {}
    for y=1,mapHelpers.NROWS do
        table.insert(layout, mapHelpers.readTileRow(y))
        -- Advance frame in between loading rows to reduce frame stuttering
        emu.frameadvance()
    end
    return layout
end
-- This is a lightweight method to refresh just the visibility fields
-- in the layout tiles
function state.dungeon.layout:refreshTileVisibility()
    local layout = self()
    for y=1,mapHelpers.NROWS do
        mapHelpers.refreshTileRowVisibility(layout[y], y)
    end
end

-- Convenience field for the stairs position
-- Note that this might be normal stairs or hidden stairs; whichever
-- is found first
state.dungeon.stairs = StateData:new()
function state.dungeon.stairs:read()
    return mapHelpers.findStairs(state.dungeon.layout())
end

-- Subcontainer for entities in the dungeon
state.dungeon.entities = {}

-- Team list
state.dungeon.entities.team = StateData:new()
function state.dungeon.entities.team:read()
    local activeTeamPtrs = entityHelpers.getActiveMonstersPtrs(0, 3, 0, 3)
    return entityHelpers.readMonsterList(activeTeamPtrs)
end

-- Enemy list
state.dungeon.entities.enemies = StateData:new()
function state.dungeon.entities.enemies:read()
    local activeEnemyPtrs = entityHelpers.getActiveMonstersPtrs(1, 19, 4, 19)
    return entityHelpers.readMonsterList(activeEnemyPtrs)
end

-- Item list
state.dungeon.entities.items = StateData:new()
function state.dungeon.entities.items:read()
    local activeItemPtrs = entityHelpers.getActiveNonMonsterPtrs(0, 63)
    return entityHelpers.readItemList(activeItemPtrs)
end

-- Trap list
state.dungeon.entities.traps = StateData:new()
function state.dungeon.entities.traps:read()
    -- Trap indexes are grouped with items indexes; traps start at 64
    local activeTrapPtrs = entityHelpers.getActiveNonMonsterPtrs(64, 127)
    return entityHelpers.readTrapList(activeTrapPtrs)
end

-- Hidden stairs
state.dungeon.entities.hiddenStairs = StateData:new()
function state.dungeon.entities.hiddenStairs:read()
    -- Hidden stairs are stored after the tile list at index 128
    local activeHiddenStairsPtrs = entityHelpers.getActiveNonMonsterPtrs(128, 128)
    if #activeHiddenStairsPtrs > 0 then
        -- There will only ever be 1
        return entityHelpers.readHiddenStairs(activeHiddenStairsPtrs[1])
    end
    return nil
end

-- Subcontainer for dungeon-wide conditions
state.dungeon.conditions = {}
-- Weather type
state.dungeon.conditions.weather = StateData:new()
function state.dungeon.conditions.weather:read()
    return memory.readbyteunsigned(0x021C6A6C)
end
-- Natural weather type on the floor
state.dungeon.conditions.naturalWeather = StateData:new()
function state.dungeon.conditions.naturalWeather:read()
    return memory.readbyteunsigned(0x021C6A6D)
end
-- Turns left for weather condition
state.dungeon.conditions.weatherTurnsLeft = StateData:new()
function state.dungeon.conditions.weatherTurnsLeft:read()
    return conditionHelpers.weatherTurnsLeft(
        state.dungeon.conditions.weather(), state.dungeon.conditions.naturalWeather())
end
-- Cloud Nine/Air Lock in effect
state.dungeon.conditions.weatherIsNullified = StateData:new()
function state.dungeon.conditions.weatherIsNullified:read()
    return memory.readbyteunsigned(0x021C6A91) ~= 0
end

-- Turns left for Mud Sport. Will be 0 if not in effect
state.dungeon.conditions.mudSportTurnsLeft = StateData:new()
function state.dungeon.conditions.mudSportTurnsLeft:read()
    return memory.readbyteunsigned(0x021C6A8F)
end
-- If Mud Sport is active. Convenience field.
state.dungeon.conditions.mudSport = StateData:new(false)
function state.dungeon.conditions.mudSport:read()
    return state.dungeon.conditions.mudSportTurnsLeft() > 0
end

-- Turns left for Water Sport. Will be 0 if not in effect
state.dungeon.conditions.waterSportTurnsLeft = StateData:new()
function state.dungeon.conditions.waterSportTurnsLeft:read()
    return memory.readbyteunsigned(0x021C6A90)
end
-- If Water Sport is active. Convenience field.
state.dungeon.conditions.waterSport = StateData:new(false)
function state.dungeon.conditions.waterSport:read()
    return state.dungeon.conditions.waterSportTurnsLeft() > 0
end

-- Stole from Kecleon flag
state.dungeon.conditions.thiefAlert = StateData:new()
function state.dungeon.conditions.thiefAlert:read()
    return memory.readbyteunsigned(0x021BA4C4) ~= 0
end
-- Gravity
state.dungeon.conditions.gravity = StateData:new()
function state.dungeon.conditions.gravity:read()
    return memory.readbyteunsigned(0x021CC830) ~= 0
end
-- Luminous (like after using a Luminous Orb)
state.dungeon.conditions.luminous = StateData:new()
function state.dungeon.conditions.luminous:read()
    return memory.readbyteunsigned(0x021D3F73) ~= 0
end
-- Darkness (obscures vision in hallways)
state.dungeon.conditions.darkness = StateData:new()
function state.dungeon.conditions.darkness:read()
    -- 0x021D3F74 is a flag for natural lighting.
    -- The luminous condition will also negate darkness
    return (memory.readbyteunsigned(0x021D3F74) == 0
            and not state.dungeon.conditions.luminous())
end

-- Subcontainer for turn counters
state.dungeon.counters = {}
-- Countdown until wind
state.dungeon.counters.wind = StateData:new()
function state.dungeon.counters.wind:read()
    return memory.readwordsigned(0x021BA4B8)
end
-- Number of warning the player has received about the wind. Convenience field.
state.dungeon.counters.windWarnings = StateData:new(false)
function state.dungeon.counters.windWarnings:read()
    local wind = state.dungeon.counters.wind()
    if wind <= 0 then
        -- 0: It's right nearby! It's gusting hard!
        return 4
    elseif wind <= 49 then
        -- 49: It's getting closer!
        return 3
    elseif wind <= 149 then
        -- 149: Something's approaching...
        return 2
    elseif wind <= 249 then
        -- 249: Something's stirring...
        return 1
    else
        -- No warnings yet...
        return 0
    end
end

-- Counter for passive damage from bad weather
state.dungeon.counters.weatherDamage = StateData:new()
function state.dungeon.counters.weatherDamage:read()
    -- Counts down from 9 to 0, damage when it resets to 9
    return memory.readbyteunsigned(0x021C6A8E)
end
-- Turns since the last round of passive damage from bad weather.
-- Will be nil if no damaging weather is in effect. Convenience field.
state.dungeon.counters.turnsSinceWeatherDamage = StateData:new(false)
function state.dungeon.counters.turnsSinceWeatherDamage:read()
    local weather = state.dungeon.conditions.weather()
    if (weather == codes.WEATHER.Sandstorm or weather == codes.WEATHER.Hail)
        and not state.dungeon.conditions.weatherIsNullified() then
        return 9 - state.dungeon.counters.weatherDamage()
    end
    return nil
end

-- Counter for enemy spawns
state.dungeon.counters.enemySpawn = StateData:new()
function state.dungeon.counters.enemySpawn:read()
    return memory.readwordsigned(0x021BA4B6)
end

-- Container for information related to the player/team
state.player = {}

-- Convenience pointer to state.dungeon.entities.team
state.player.team = state.dungeon.entities.team
-- Convenience pointer to state.dungeon.entities.team[1]
state.player.leader = StateData:new(false)
function state.player.leader:read()
    return state.dungeon.entities.team()[1]
end
function state.player.leader:flagForReload()
    state.dungeon.entities.team:flagForReload()
end

-- Current money
state.player.money = StateData:new()
function state.player.money:read()
    return memoryrange.readbytesSigned(0x022A4BB8, 4)
end

-- List of items in bag
state.player.bag = StateData:new()
local BAG_START = 0x022A3824
local ITEM_SIZE = 6
function state.player.bag:read()
    local bag = {}
    local i = 0
    while true do
        local item = entityHelpers.readItemInfoTable(BAG_START + i*ITEM_SIZE)
        -- Read until an empty slot is encountered
        if not item then
            break
        end
        table.insert(bag, item)
        i = i + 1
    end
    return bag
end

-- Maximum number of items in bag
state.player.bagCapacity = StateData:new()
local BAG_LEVEL_PTR = 0x022AB15C
local BAG_CAPACITY_TABLE_HEAD = 0x020A27D4
function state.player.bagCapacity:read()
    local bagLevel = memory.readbyteunsigned(BAG_LEVEL_PTR)
    local bagCapacityPtr = BAG_CAPACITY_TABLE_HEAD + 4*bagLevel
    -- The table is an array of contiguous 4-byte signed integers, with the
    -- head value containing the bag capacity for bag level 0, the next element
    -- the capacity for bag level 1, etc. Minimum possible value is 1.
    return math.max(memoryrange.readbytesSigned(bagCapacityPtr, 4), 1)
end

-- Whether the player can detect all enemies on the floor
state.player.canSeeEnemies = StateData:new()
function state.player.canSeeEnemies:read()
    -- 0x021D3F76 is a composite flag for the leader having the Power Ears status or holding X-Ray Specs
    -- Enemies will also be revealed if the dungeon is luminous
    return (memory.readbyteunsigned(0x021D3F76) ~= 0) or state.dungeon.conditions.luminous()
end
-- Whether the player can detect all items on the floor
state.player.canSeeItems = StateData:new()
function state.player.canSeeItems:read()
    -- Composite flag for the leader having the Scanning status or holding X-Ray Specs
    return memory.readbyteunsigned(0x021D3F77) ~= 0
end
-- Whether the player can see all traps
state.player.canSeeTrapsAndHiddenStairs = StateData:new()
function state.player.canSeeTrapsAndHiddenStairs:read()
    return memory.readbyteunsigned(0x021D3F78) ~= 0
end
-- Whether the player can see the stairs location. This may be redundant with the leader having the
-- Stair Spotter status... Not sure
state.player.canSeeStairs = StateData:new()
function state.player.canSeeStairs:read()
    return memory.readbyteunsigned(0x021D3F7A) ~= 0
end

---- END STATE DATA MODEL ----

-- Forces reload on a StateData list
local function flagListForReload(stateDataList)
    for _, data in ipairs(stateDataList) do
        data:flagForReload()
    end
end

-- Forces reload for appropriate stuff every floor
function stateinfo.reloadEveryFloor(state)
    flagListForReload({
        state.dungeon.visibilityRadius,
        state.dungeon.layout,   -- This is expensive! Doing this every turn tanks performance.
        state.dungeon.stairs,
        state.dungeon.conditions.naturalWeather,
    })
    return state
end

-- Forces reload for appropriate stuff every turn
function stateinfo.reloadEveryTurn(state)
    flagListForReload({
        state.dungeon.floor,
        state.dungeon.entities.team,
        state.dungeon.entities.enemies,
        state.dungeon.entities.items,
        state.dungeon.entities.traps,
        state.dungeon.entities.hiddenStairs,
        state.dungeon.conditions.weather,
        state.dungeon.conditions.weatherTurnsLeft,
        state.dungeon.conditions.weatherIsNullified,
        state.dungeon.conditions.mudSportTurnsLeft,
        state.dungeon.conditions.waterSportTurnsLeft,
        state.dungeon.conditions.thiefAlert,
        state.dungeon.conditions.gravity,
        state.dungeon.conditions.luminous,
        state.dungeon.conditions.darkness,
        state.dungeon.counters.wind,
        state.dungeon.counters.weatherDamage,
        state.dungeon.counters.enemySpawn,
        state.player.money,
        state.player.bag,
        state.player.canSeeEnemies,
        state.player.canSeeItems,
        state.player.canSeeTrapsAndHiddenStairs,
        state.player.canSeeStairs,
    })
    -- Refresh the visibility status of tiles. This is much lighter weight than
    -- a full reload.
    state.dungeon.layout:refreshTileVisibility()
    return state
end

return stateinfo