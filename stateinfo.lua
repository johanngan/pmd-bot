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
-- Parse a range of bytes into a list of tile objects
local TILE_BYTES = 20   -- Each tile is represented by 20 bytes
local function parseTiles(bytes)
    local tiles = {}
    for start=1,#bytes,TILE_BYTES do
        local tile = {}
        -- 0x00: a bitfield
        tile.terrain = AND(bytes[start], 0x03)
        tile.inShop = AND(bytes[start], 0x20) ~= 0
        tile.inMonsterHouse = AND(bytes[start], 0x40) ~= 0
        -- 0x01: stairs flag
        tile.isStairs = bytes[start + 0x01] == 2
        -- 0x02: map visibility flag
        tile.visibleOnMap = bytes[start + 0x02] ~= 0
        -- 0x07: room index; will be -1 if in a hall
        tile.room = memoryrange.unsignedToSigned(bytes[start + 0x07], 1)

        table.insert(tiles, tile)
    end
    return tiles
end
local UPPER_LEFT_CORNER = 0x021BE288
local NROWS = 30
local NCOLS = 54
function state.dungeon.layout:read()
    local layout = {}
    for i=0,NROWS-1 do
        -- Offset by 2 extra tiles each row because there's a rectangular boundary
        -- of tiles around the dungeon's "interactable tiles". These tiles are
        -- always impassable, so there's no point in reading them
        table.insert(layout, parseTiles(memory.readbyterange(
            UPPER_LEFT_CORNER + i*(NCOLS+2)*TILE_BYTES, NCOLS*TILE_BYTES)))
        -- Advance frame in between loading rows to reduce frame stuttering
        emu.frameadvance()
    end
    return layout
end
-- Convenience utility for the stairs position
state.dungeon.stairs = StateData:new()
function state.dungeon.stairs:read()
    for y, row in ipairs(state.dungeon.layout()) do
        for x, tile in ipairs(row) do
            if tile.isStairs then
                return x, y
            end
        end
    end
end

-- Subcontainer for entities in the dungeon
state.dungeon.entities = {}


-- Team list
state.dungeon.entities.team = StateData:new()
local ALL_MONSTER_PTRS_START = 0x021CC85C  -- Start of internal list of all monster ptrs
local ACTIVE_MONSTER_PTRS_START = 0x21CC8AC    -- Start of internal list of all active monster ptrs
-- Search through the active monster pointers from the range [activeIdxLo, activeIdxHi]
-- in the active pointer list. Return a list with all of them that lie in the range
-- [allIdxLo, allIdxHi] within the list of all monster pointers. Indexes start from 0.
local function getActiveMonstersPtrs(activeIdxLo, activeIdxHi, allIdxLo, allIdxHi)
    local activePtrs = memoryrange.readListUnsigned(
        ACTIVE_MONSTER_PTRS_START + 4*activeIdxLo, 4, activeIdxHi-activeIdxLo+1)
    local allPtrLo = memoryrange.readbytesUnsigned(ALL_MONSTER_PTRS_START + 4*allIdxLo, 4)
    local allPtrHi = memoryrange.readbytesUnsigned(ALL_MONSTER_PTRS_START + 4*allIdxHi, 4)
    local filteredActivePtrs = {}
    for _, ptr in ipairs(activePtrs) do
        if ptr >= allPtrLo and ptr <= allPtrHi then
            table.insert(filteredActivePtrs, ptr)
        end
    end
    return filteredActivePtrs
end
-- Read a single monster given its data block address
local function readMonster(address)
    local monster = {}
    monster.xPosition = memory.readwordsigned(address + 0x04)
    monster.yPosition = memory.readwordsigned(address + 0x06)

    -- The original address ends in a pointer to a table with many important values
    local infoTableStart = memoryrange.readbytesUnsigned(address + 0xB4, 4)
    monster.species = memory.readword(infoTableStart + 0x002)
    monster.isEnemy = memory.readbyteunsigned(infoTableStart + 0x006) == 1
    monster.isLeader = memory.readbyteunsigned(infoTableStart + 0x007) == 1
    monster.level = memory.readbyteunsigned(infoTableStart + 0x00A)
    monster.IQ = memory.readwordsigned(infoTableStart + 0x00E)
    monster.HP = memory.readwordsigned(infoTableStart + 0x010)
    monster.maxHP = memory.readwordsigned(infoTableStart + 0x012)
    monster.attack = memory.readbyteunsigned(infoTableStart + 0x01A)
    monster.specialAttack = memory.readbyteunsigned(infoTableStart + 0x01B)
    monster.defense = memory.readbyteunsigned(infoTableStart + 0x01C)
    monster.specialDefense = memory.readbyteunsigned(infoTableStart + 0x01D)
    monster.experience = memoryrange.readbytesSigned(infoTableStart + 0x020, 4)
    -- 0x024-0x043: stat boosts/drops
    monster.direction = memory.readbyteunsigned(infoTableStart + 0x04C)
    monster.heldItemQuantity = memory.readwordunsigned(infoTableStart + 0x064)
    monster.heldItem = memory.readwordunsigned(infoTableStart + 0x066)
    -- 0x0A9-11E: statuses
    -- 0x124-0x12B: move 1 info
    -- 0x12C-0x133: move 2 info
    -- 0x134-0x13B: move 3 info
    -- 0x13C-0x143: move 4 info
    monster.belly = (
        memory.readwordsigned(infoTableStart + 0x146) +
        memory.readwordsigned(infoTableStart + 0x148) / 1000
    )

    return monster
end
-- Read a list of monsters given a list of data block addresses
local function readMonsterList(addresses)
    local monsters = {}
    for _, addr in ipairs(addresses) do
        table.insert(monsters, readMonster(addr))
        -- Advance frame in between loading monsters to reduce frame stuttering
        emu.frameadvance()
    end
    return monsters
end
function state.dungeon.entities.team:read()
    local activeTeamPtrs = getActiveMonstersPtrs(0, 3, 0, 3)
    return readMonsterList(activeTeamPtrs)
end

-- Enemy list
state.dungeon.entities.enemies = StateData:new()
function state.dungeon.entities.enemies:read()
    local activeEnemyPtrs = getActiveMonstersPtrs(1, 19, 4, 19)
    return readMonsterList(activeEnemyPtrs)
end

-- Item list
local FIRST_NON_MONSTER_PTR = 0x021CD960
local DATA_BLOCK_SIZE = 184
-- Get pointer to active non-monster entities in a given index range (starting at 0)
local function getActiveNonMonsterPtrs(idxLo, idxHi)
    activePtrs = {}
    for i=idxLo,idxHi do
        local ptr = FIRST_NON_MONSTER_PTR + i*DATA_BLOCK_SIZE
        -- The first byte is nonzero if active
        if memory.readbyteunsigned(ptr) ~= 0 then
            table.insert(activePtrs, ptr)
        end
    end
    return i
end
-- Read an item at a given address
local function readItem(address)
    local item = {}
    item.xPosition = memory.readwordsigned(address + 0x04)
    item.yPosition = memory.readwordsigned(address + 0x06)

    -- The original address ends in a pointer to a table with important values
    local infoTableStart = memoryrange.readbytesUnsigned(address + 0xB4, 4)
    item.itemState = memory.readwordunsigned(infoTableStart)
    item.amount = memory.readwordunsigned(infoTableStart + 0x02)
    item.itemType = memory.readwordunsigned(infoTableStart + 0x04)

    return item
end
state.dungeon.entities.items = StateData:new()
function state.dungeon.entities.items:read()
    local activeItemPtrs = getActiveNonMonsterPtrs(0, 63)
    local items = {}
    for _, addr in ipairs(activeItemPtrs) do
        table.insert(items, readItem(addr))
    end
    return items
end

-- Trap list
state.dungeon.entities.traps = StateData:new()
-- Read a trap at a given address
local function readTrap(address)
    local trap = {}
    trap.xPosition = memory.readwordsigned(address + 0x04)
    trap.yPosition = memory.readwordsigned(address + 0x06)
    trap.isRevealed = memory.readbyteunsigned(address + 0x20) ~= 0

    -- The original address ends in a pointer to a table with important values
    local infoTableStart = memoryrange.readbytesUnsigned(address + 0xB4, 4)
    trap.trapType = memory.readbyteunsigned(infoTableStart)
    -- Not sure if isActive is really a meaningful value, or if it will always be true...
    trap.isActive = memory.readbyteunsigned(infoTableStart + 0x01)
    trap.isActive = (trap.isActive == 0 or trap.isActive == 2)
    
    return trap
end
function state.dungeon.entities.traps:read()
    -- Trap indexes are grouped with items indexes; traps start at 64
    local activeTrapPtrs = getActiveNonMonsterPtrs(64, 128)
    local traps = {}
    for _, addr in ipairs(activeTrapPtrs) do
        table.insert(traps, readTrap(addr))
    end
    return traps
end

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
        state.dungeon.stairs,
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