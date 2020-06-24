-- Reading state info from memory

require 'table'

require 'utils.memoryrange'
require 'utils.StateData'
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
    return memory.readbyte(0x021BA62B) == 0
end

-- Container for information related to the dungeon
state.dungeon = {}

-- ID of the current dungeon
state.dungeon.dungeonID = StateData:new()
function state.dungeon.dungeonID:read()
    return memory.readwordsigned(0x022AB4FE)
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

-- Convenience field for the stairs position
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
    local activeTrapPtrs = entityHelpers.getActiveNonMonsterPtrs(64, 128)
    return entityHelpers.readTrapList(activeTrapPtrs)
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
-- Turns left for Water Sport. Will be 0 if not in effect
state.dungeon.conditions.waterSportTurnsLeft = StateData:new()
function state.dungeon.conditions.waterSportTurnsLeft:read()
    return memory.readbyteunsigned(0x021C6A90)
end
-- Stole from Kecleon flag
state.dungeon.conditions.thiefAlert = StateData:new()
function state.dungeon.conditions.thiefAlert:read()
    return memory.readbyteunsigned(0x021BA4C4) ~= 0
end

-- Subcontainer for turn counters
state.dungeon.counters = {}
-- Countdown until wind
state.dungeon.counters.wind = StateData:new()
function state.dungeon.counters.wind:read()
    return memory.readwordsigned(0x021BA4B8)
end
-- Counter for passive damage from bad weather
state.dungeon.counters.weatherDamage = StateData:new()
function state.dungeon.counters.weatherDamage:read()
    -- Counts down from 9 to 0, damage when it resets to 9
    return memory.readbyteunsigned(0x021C6A8E)
end
-- Counter for passive damage from statuses
state.dungeon.counters.statusDamage = StateData:new()
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
        state.dungeon.layout,
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
        state.dungeon.conditions.weather,
        state.dungeon.conditions.weatherTurnsLeft,
        state.dungeon.conditions.weatherIsNullified,
        state.dungeon.conditions.mudSportTurnsLeft,
        state.dungeon.conditions.waterSportTurnsLeft,
        state.dungeon.conditions.thiefAlert,
        state.dungeon.counters.wind,
        state.dungeon.counters.weatherDamage,
        state.dungeon.counters.statusDamage,
        state.dungeon.counters.enemySpawn,
        state.player.money,
        state.player.bag,
    })
    return state
end

return stateinfo