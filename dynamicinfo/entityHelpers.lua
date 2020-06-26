-- Helpers for reading entities (monsters, items, and traps) from memory

require 'table'
require 'utils.memoryrange'
local statusHelpers = require 'dynamicinfo.statusHelpers'

local entityHelpers = {}

-- General function for reading a list of entities given a list of data block addresses
local function readEntityList(addresses, readEntity)
    local entities = {}
    for _, addr in ipairs(addresses) do
        table.insert(entities, readEntity(addr))
        -- If there's frame stuttering each turn, try advancing the frame
        -- in between loading entities
        -- emu.frameadvance()
    end
    return entities
end

---- BEGIN MONSTER STUFF ----

-- Search through the active monster pointers from the range [activeIdxLo, activeIdxHi]
-- in the active pointer list. Return a list with all of them that lie in the range
-- [allIdxLo, allIdxHi] within the list of all monster pointers. Indexes start from 0.
local ALL_MONSTER_PTRS_START = 0x021CC85C  -- Start of internal list of all monster ptrs
local ACTIVE_MONSTER_PTRS_START = 0x21CC8AC    -- Start of internal list of all active monster ptrs
function entityHelpers.getActiveMonstersPtrs(activeIdxLo, activeIdxHi, allIdxLo, allIdxHi)
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

-- Read a single move given its data block address
function entityHelpers.readMove(address)
    local bitfield = memory.readbyteunsigned(address)
    -- Check if the move slot is empty
    if AND(bitfield, 0x01) == 0 then
        return nil
    end
    local move = {}
    move.subsequentInLinkChain = AND(bitfield, 0x02) ~= 0
    move.isSet = AND(bitfield, 0x08) ~= 0
    move.isSealed = memory.readbyteunsigned(address + 0x02) ~= 0
    move.moveID = memory.readwordunsigned(address + 0x04)
    move.PP = memory.readbyteunsigned(address + 0x06)
    move.ginsengBoost = memory.readbyteunsigned(address + 0x07)
    return move
end

-- Read a single monster given its data block address
local N_DEFAULT_GENDER = 600 -- Number of monster entities with their default genders
function entityHelpers.readMonster(address)
    local monster = {}
    monster.xPosition = memory.readwordsigned(address + 0x04)
    monster.yPosition = memory.readwordsigned(address + 0x06)

    -- The original address ends in a pointer to a table with many important values
    local infoTableStart = memoryrange.readbytesUnsigned(address + 0xB4, 4)

    -- Stuff seen on the "Features" page in-game, but add species, because belongs conceptually
    monster.features = {}
    -- Need to mod with 600 since the non-default genders have different IDs for some reason
    monster.features.species = memory.readwordunsigned(infoTableStart + 0x002) % N_DEFAULT_GENDER

    -- Other basic info
    monster.isEnemy = memory.readbyteunsigned(infoTableStart + 0x006) == 1
    monster.isLeader = memory.readbyteunsigned(infoTableStart + 0x007) == 1
    monster.isAlly = memory.readbyteunsigned(infoTableStart + 0x008) == 1   -- But not on team; for "enemies"
    monster.isShopkeeper = memory.readbyteunsigned(infoTableStart + 0x009) == 1

    -- Stuff seen on the "Stats" page in-game, and related stuff
    -- Exclude item from this subcontainer, because I think that's stupid
    monster.stats = {}
    monster.stats.level = memory.readbyteunsigned(infoTableStart + 0x00A)
    monster.stats.IQ = memory.readwordsigned(infoTableStart + 0x00E)
    monster.stats.HP = memory.readwordsigned(infoTableStart + 0x010)
    monster.stats.maxHP = memory.readwordsigned(infoTableStart + 0x012)
    monster.stats.attack = memory.readbyteunsigned(infoTableStart + 0x01A)
    monster.stats.specialAttack = memory.readbyteunsigned(infoTableStart + 0x01B)
    monster.stats.defense = memory.readbyteunsigned(infoTableStart + 0x01C)
    monster.stats.specialDefense = memory.readbyteunsigned(infoTableStart + 0x01D)
    monster.stats.experience = memoryrange.readbytesSigned(infoTableStart + 0x020, 4)
    -- Stat modifiers
    -- Note: Not the same [-6, 6] range as in the main series.
    -- Instead the normal value is 10, and goes up to 20 and down to 0.
    monster.stats.modifiers = {}
    monster.stats.modifiers.attackStage = memory.readwordsigned(infoTableStart + 0x024)
    monster.stats.modifiers.specialAttackStage = memory.readwordsigned(infoTableStart + 0x026)
    monster.stats.modifiers.defenseStage = memory.readwordsigned(infoTableStart + 0x028)
    monster.stats.modifiers.specialDefenseStage = memory.readwordsigned(infoTableStart + 0x02A)
    monster.stats.modifiers.accuracyStage = memory.readwordsigned(infoTableStart + 0x02C)
    monster.stats.modifiers.evasionStage = memory.readwordsigned(infoTableStart + 0x02E)
    -- Speed stages are stored internally with status conditions, but they fit in here more
    -- Speed stages go from 0-4, with 1 being normal
    monster.stats.modifiers.speedStage = memoryrange.readbytesSigned(infoTableStart + 0x110, 4)
    -- Internal counters determine when exactly how long speed modifiers will last
    monster.stats.modifiers.speedCounters = {}
    -- Speed boost/drop = (# nonzero u) - (# nonzero down), but forced between 0-4
    monster.stats.modifiers.speedCounters.up = {}
    monster.stats.modifiers.speedCounters.down = {}
    for i=0,4 do
        table.insert(monster.stats.modifiers.speedCounters.up,
            memory.readbyteunsigned(infoTableStart + 0x114 + i))
        table.insert(monster.stats.modifiers.speedCounters.down,
            memory.readbyteunsigned(infoTableStart + 0x119 + i))
    end

    -- Other info
    monster.direction = memory.readbyteunsigned(infoTableStart + 0x04C)

    -- More features
    monster.features.primaryType = memory.readbyteunsigned(infoTableStart + 0x05E)
    monster.features.secondaryType = memory.readbyteunsigned(infoTableStart + 0x05F)
    monster.features.primaryAbility = memory.readbyteunsigned(infoTableStart + 0x060)
    monster.features.secondaryAbility = memory.readbyteunsigned(infoTableStart + 0x061)

    -- Held item stuff
    monster.heldItemQuantity = memory.readwordunsigned(infoTableStart + 0x064)
    monster.heldItem = memory.readwordunsigned(infoTableStart + 0x066)

    -- Statuses
    monster.statuses = statusHelpers.readStatusList(infoTableStart)

    monster.moves = {}
    local MOVE1_OFFSET = 0x124
    local MOVE_SIZE = 8
    for i=0,3 do
        local move = entityHelpers.readMove(infoTableStart + MOVE1_OFFSET + i*MOVE_SIZE)
        if not move then break end  -- Stop reading moves if the slot is empty
        table.insert(monster.moves, move)
    end

    -- Belly. Integer part stored in one variable, and thousandths in another
    monster.belly = (
        memory.readwordsigned(infoTableStart + 0x146) +
        memory.readwordsigned(infoTableStart + 0x148) / 1000
    )

    return monster
end

-- Read a list of monsters given a list of data block addresses
function entityHelpers.readMonsterList(addresses)
    return readEntityList(addresses, entityHelpers.readMonster)
end

---- END MONSTER STUFF ----

-- Get pointer to active non-monster entities in a given index range (starting at 0)
local FIRST_NON_MONSTER_PTR = 0x021CD960
local DATA_BLOCK_SIZE = 184
function entityHelpers.getActiveNonMonsterPtrs(idxLo, idxHi)
    local activePtrs = {}
    for i=idxLo,idxHi do
        local ptr = FIRST_NON_MONSTER_PTR + i*DATA_BLOCK_SIZE
        -- The first byte is nonzero if active
        if memory.readbyteunsigned(ptr) ~= 0 then
            table.insert(activePtrs, ptr)
        end
    end
    return activePtrs
end

---- BEGIN ITEM STUFF ----

-- Read fields from an item's info table
function entityHelpers.readItemInfoTable(infoTableStart)
    local bitfield = memory.readbyteunsigned(infoTableStart)
    if AND(bitfield, 0x01) == 0 then
        return nil  -- Nonexistent item
    end
    local item = {}
    item.inShop = AND(bitfield, 0x02) ~= 0
    item.isSticky = AND(bitfield, 0x08) ~= 0
    item.isSet = AND(bitfield, 0x10) ~= 0
    -- Monster ID for holder; for held items in bag
    item.heldBy = memory.readbyteunsigned(infoTableStart + 0x01)
    item.amount = memory.readwordunsigned(infoTableStart + 0x02)
    item.itemType = memory.readwordunsigned(infoTableStart + 0x04)
    return item
end

-- Read an item at a given (entity) address
function entityHelpers.readItem(address)
    -- The original address ends in a pointer to a table with important values
    local infoTableStart = memoryrange.readbytesUnsigned(address + 0xB4, 4)
    local item = entityHelpers.readItemInfoTable(infoTableStart)
    -- Make sure the item exists before continuing
    if item then
        -- More info at the original address
        item.xPosition = memory.readwordsigned(address + 0x04)
        item.yPosition = memory.readwordsigned(address + 0x06)
    end
    return item
end

-- Read a list of items given a list of data block addresses
function entityHelpers.readItemList(addresses)
    return readEntityList(addresses, entityHelpers.readItem)
end

---- END ITEM STUFF ----

---- BEGIN TRAP STUFF ----

-- Read a trap at a given address
function entityHelpers.readTrap(address)
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

-- Read a list of traps given a list of data block addresses
function entityHelpers.readTrapList(addresses)
    return readEntityList(addresses, entityHelpers.readTrap)
end

---- END TRAP STUFF ----

return entityHelpers