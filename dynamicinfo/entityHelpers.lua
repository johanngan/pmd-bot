-- Helpers for reading entities (monsters, items, and traps) from memory

require 'table'
require 'utils.memoryrange'

local entityHelpers = {}

-- General function for reading a list of entities given a list of data block addresses
local function readEntityList(addresses, readEntity)
    local entities = {}
    for _, addr in ipairs(addresses) do
        table.insert(entities, readEntity(addr))
        -- Advance frame in between loading entities to reduce frame stuttering
        emu.frameadvance()
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
    -- Need to mod with 600 since the non-default genders have different IDs for some reason
    monster.species = memory.readword(infoTableStart + 0x002) % N_DEFAULT_GENDER
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
    monster.primaryType = memory.readbyteunsigned(infoTableStart + 0x05E)
    monster.secondaryType = memory.readbyteunsigned(infoTableStart + 0x05F)
    monster.primaryAbility = memory.readbyteunsigned(infoTableStart + 0x060)
    monster.secondaryAbility = memory.readbyteunsigned(infoTableStart + 0x061)
    monster.heldItemQuantity = memory.readwordunsigned(infoTableStart + 0x064)
    monster.heldItem = memory.readwordunsigned(infoTableStart + 0x066)
    -- 0x0A9-11E: statuses
    monster.moves = {}
    local MOVE1_OFFSET = 0x124
    local MOVE_SIZE = 8
    for i=0,3 do
        local move = entityHelpers.readMove(infoTableStart + MOVE1_OFFSET + i*MOVE_SIZE)
        if not move then break end  -- Stop reading moves if the slot is empty
        table.insert(monster.moves, move)
    end
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
    local item = {}
    item.itemState = memory.readwordunsigned(infoTableStart)
    if item.itemState == 0 then
        return nil  -- Nonexistent item
    end
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