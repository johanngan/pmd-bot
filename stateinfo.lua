-- Reading state info from memory

require 'table'

require 'utils/memoryrange'
require 'utils/StateData'

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

-- Subcontainer for entities in the dungeon
state.dungeon.entities = {}
-- Team list
state.dungeon.entities.team = StateData:new()
-- Enemy list
state.dungeon.entities.enemies = StateData:new()
-- Item list
state.dungeon.entities.items = StateData:new()
-- Trap list
state.dungeon.entities.traps = StateData:new()

-- Subcontainer for dungeon-wide conditions
state.dungeon.conditions = {}
-- Weather type
state.dungeon.conditions.weather = StateData:new()
-- Turns left for weather condition
state.dungeon.conditions.weatherTurnsLeft = StateData:new()
-- Subsubcontainer for other conditions
state.dungeon.conditions.misc = StateData:new()

-- Subcontainer for turn counters
state.dungeon.counters = {}
-- Countdown until wind
state.dungeon.counters.wind = StateData:new()
function state.dungeon.counters.wind:read()
    return memory.readwordsigned(0x021BA4B8)
end
-- Counter for passive damage from bad weather
state.dungeon.counters.weatherDamage = StateData:new()
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
        state.dungeon.conditions.misc,
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