-- Helpers for item-related logic

require 'math'
require 'table'

require 'actions.smartactions'

require 'codes.color'
require 'codes.item'
require 'codes.itemSprite'

require 'mechanics.LookupTable'
require 'mechanics.item'

require 'utils.pathfinder'

local itemLogic = {}

-- Read all the priorities in
local itemCodes = {}
for id=codes.ITEM.Nothing,codes.ITEM.Unnamed0x577 do
    table.insert(itemCodes, id)
end
local priorityLookup = LookupTable:new('agent/logic/item_strategy.csv')
local itemPriorities = {}
local heldItemPriorities = {}
local discardItemByUsing = {}
local spritePriorities = {}
local spriteCanDiscardByUsing = {}
local priorityList = {}
for _, itemWithStrategy in ipairs(priorityLookup(itemCodes)) do
    itemPriorities[itemWithStrategy.ID] = itemWithStrategy.priority
    heldItemPriorities[itemWithStrategy.ID] = itemWithStrategy.heldPriority
    discardItemByUsing[itemWithStrategy.ID] = itemWithStrategy.discardByUsing
    table.insert(priorityList, itemWithStrategy.priority)
    -- For a given sprite type, color pair, let the priority be the maximum
    -- priority of all items in that group.
    local sprite = mechanics.item.sprites[itemWithStrategy.ID]
    if spritePriorities[sprite.type] == nil then
        spritePriorities[sprite.type] = {}
    end
    if spritePriorities[sprite.type][sprite.color] == nil then
        spritePriorities[sprite.type][sprite.color] = -math.huge
    end
    spritePriorities[sprite.type][sprite.color] = math.max(
        spritePriorities[sprite.type][sprite.color], itemWithStrategy.priority
    )
    -- Let the sprite discardByUsing be the OR of all the discardByUsing flags.
    if spriteCanDiscardByUsing[sprite.type] == nil then
        spriteCanDiscardByUsing[sprite.type] = {}
    end
    if spriteCanDiscardByUsing[sprite.type][sprite.color] == nil then
        spriteCanDiscardByUsing[sprite.type][sprite.color] = false
    end
    spriteCanDiscardByUsing[sprite.type][sprite.color] =
        spriteCanDiscardByUsing[sprite.type][sprite.color] or
            itemWithStrategy.discardByUsing
end
-- Clear out the cache since we're done with it
priorityLookup:flushCache()
-- Get the highest and lowest priorities, and the minimum nonzero difference
-- between any two priorities
table.sort(priorityList)
itemLogic.MIN_PRIORITY, itemLogic.MAX_PRIORITY = math.huge, -math.huge
local minPriorityDiff, prevPriority = math.huge, -math.huge
for _, priority in ipairs(priorityList) do
    itemLogic.MIN_PRIORITY = math.min(itemLogic.MIN_PRIORITY, priority)
    itemLogic.MAX_PRIORITY = math.max(itemLogic.MAX_PRIORITY, priority)
    local priorityDiff = priority - prevPriority
    if priorityDiff > 0 and priorityDiff < minPriorityDiff then
        minPriorityDiff = priorityDiff
    end
    prevPriority = priority
end

-- Resolves an item's priority based on available info
function itemLogic.resolveItemPriority(item)
    -- Default to above the max priority. If an item isn't known, we should
    -- be curious as to what it is before making a decision to reject it
    local priority = itemLogic.MAX_PRIORITY + minPriorityDiff
    if item.itemType then
        priority = itemPriorities[item.itemType]
    elseif item.sprite.type then
        -- The actual item type isn't known, so describe the sprite instead
        priority = spritePriorities[item.sprite.type][item.sprite.color]
    end
    -- If an item is known to be sticky, it should be worth less than if it
    -- were non-sticky, but still remain above anything normally below it
    if item.isSticky then
        priority = priority - minPriorityDiff / 2
    end
    return priority
end

-- Resolves an item's discard by using status based on available info
function itemLogic.resolveDiscardabilityByUse(item)
    -- Default to true. If an item isn't known, we should be curious as to
    -- what it is before making a decision to reject it.
    local discardByUsing = true
    if item.itemType then
        discardByUsing = discardItemByUsing[item.itemType]
    elseif item.sprite.type then
        discardByUsing = spriteCanDiscardByUsing[item.sprite.type][item.sprite.color]
    end
    -- If an item is known to be sticky or in a shop, we can't actually use it,
    -- so we shouldn't consider it discardable by use
    if item.isSticky or item.inShop then
        discardByUsing = false
    end
    return discardByUsing
end

-- Resolves an item's holding priority based on available info
function itemLogic.resolveHeldPriority(item)
    -- An item must be known to have a held priority
    -- Sticky items should never be equipped
    if item.itemType and not item.isSticky then
        return heldItemPriorities[item.itemType]
    end
    return nil
end

-- Find the index (0-indexed) of the lowest priority item in the bag,
-- and the corresponding priority value. Held items are skipped since
-- they can't be swapped out. Returns a nil index if no non-held items
function itemLogic.getLowestPriorityItem(bag)
    local lowIdx, lowPriority = nil, math.huge
    for i, item in ipairs(bag) do
        if item.heldBy == 0 then
            local priority = itemLogic.resolveItemPriority(item)
            if priority < lowPriority then
                lowIdx = i - 1  -- Convert to 0-indexing
                lowPriority = priority
            end
        end
    end
    return lowIdx, lowPriority
end

-- Check if an item is worth swapping with something in the bag. If so,
-- return the bag index (0-indexed). Otherwise, return nil
function itemLogic.idxToSwap(item, bag)
    local worstItemIdx, worstPriority = itemLogic.getLowestPriorityItem(bag)
    if worstItemIdx and itemLogic.resolveItemPriority(item) > worstPriority then
        return worstItemIdx
    end
    return nil
end

-- Find the index (0-indexed) of the highest priority held item in the bag
-- to equip. Items already held are skipped, as are sticky items and other
-- items with nil priority. Returns a nil index if no valid held items, the
-- best item is already equipped, or the current held item is sticky.
function itemLogic.idxToEquip(bag, teammate)
    local teammate = teammate or 0  -- 0 for the leader
    local holder = teammate + 1 -- The internal held index is 1-indexed (0 means no holder)

    local highIdx, highPriority = nil, -math.huge
    local currentHeldPriority = nil
    for i, item in ipairs(bag) do
        if item.heldBy == 0 then
            -- This is not a held item. Check the priority
            local priority = itemLogic.resolveHeldPriority(item)
            if priority and priority > highPriority then
                highIdx = i - 1 -- Convert to 0-indexing
                highPriority = priority
            end
        elseif item.heldBy == holder then
            -- This is the current held item

            -- Held item is sticky! We're not going to be able to equip
            -- anything else, so return nil
            if item.isSticky then return nil end
            -- Otherwise, record the priority
            currentHeldPriority = itemLogic.resolveHeldPriority(item)
        end
    end

    -- Only return the best index if it beats the current held item
    if highPriority then
        if currentHeldPriority then
            if highPriority > currentHeldPriority then
                return highIdx
            end
        else
            return highIdx
        end
    end
    return nil
end

-- Check if an item is desirable for picking up or not
function itemLogic.shouldPickUp(item, bag, bagCapacity)
    -- Ignore Kecleon's stuff
    if item.inShop then return false end
    -- If the bag has room, why not?
    if #bag < bagCapacity then return true end
    -- Otherwise, pick it up if something else can be swapped out
    return itemLogic.idxToSwap(item, bag) ~= nil
end

-- Get the item at a given position, or nil if there is none
function itemLogic.itemAtPos(pos, items)
    for _, item in ipairs(items) do
        if pathfinder.comparePositions(pos, {item.xPosition, item.yPosition}) then
            return item
        end
    end
    return nil
end

-- Swap an item underfoot for something lower priority in the bag
function itemLogic.swapItemUnderfoot(state)
    local leader = state.player.leader()
    local item = itemLogic.itemAtPos({leader.xPosition, leader.yPosition},
        state.dungeon.entities.items())
    if not item then return false end

    local idx = itemLogic.idxToSwap(item, state.player.bag())
    if idx then
        return smartactions.swapItemIfPossible(idx, state, nil, true)
    end
    return false
end

-- Pick up an item underfoot, or swap it for something lower priority in the bag
function itemLogic.retrieveItemUnderfoot(state)
    -- If we can just pick it up, no need to bother with the swapping logic
    if smartactions.pickUpItemIfPossible(-1, state, true) then return true end
    return itemLogic.swapItemUnderfoot(state)
end

-- Use an item underfoot if it's discardable by use.
function itemLogic.useDiscardableItemUnderfoot(state)
    local leader = state.player.leader()
    local item = itemLogic.itemAtPos({leader.xPosition, leader.yPosition},
        state.dungeon.entities.items())
    if not item then return false end

    if itemLogic.resolveDiscardabilityByUse(item) then
        return smartactions.useItemIfPossible(-1, state, nil, true)
    end
    return false
end

-- Equip an item from the bag
function itemLogic.equipBestItem(state, teammate)
    -- Proxy default teammate to idxToEquip and giveItemIfPossible
    local idx = itemLogic.idxToEquip(state.player.bag(), teammate)
    if idx then
        return smartactions.giveItemIfPossible(idx, state, teammate, true)
    end
    return false
end

-- Statuses that urgently need to be cured, and can't just be waited out
itemLogic.urgentStatuses = {
    codes.STATUS.PerishSong,
}
-- Statuses that are debilitating or potentially debilitating during combat,
-- and should be cured ASAP if possible, even while engaged with an enemy
itemLogic.debilitatingStatuses = {
    codes.STATUS.Sleep,
    codes.STATUS.Nightmare,
    codes.STATUS.Yawning,
    codes.STATUS.Napping,

    codes.STATUS.Paralysis,

    codes.STATUS.Frozen,
    codes.STATUS.Wrapped,
    codes.STATUS.Petrified,

    codes.STATUS.Cringe,
    codes.STATUS.Confused,
    codes.STATUS.Paused,
    codes.STATUS.Cowering,
    codes.STATUS.Infatuated,

    codes.STATUS.Decoy,
    codes.STATUS.HealBlock,
    codes.STATUS.Embargo,

    codes.STATUS.Whiffer,

    codes.STATUS.Blinker,

    codes.STATUS.Muzzled,

    codes.STATUS.PerishSong,
}
-- Statuses that don't go away quickly on their own, and whose lingering effects are
-- quite harmful. These should be healed if there's nothing else more important to do
itemLogic.persistentStatuses = {
    codes.STATUS.Burn,
    codes.STATUS.Poisoned,
    codes.STATUS.BadlyPoisoned,
    codes.STATUS.Cursed,
    codes.STATUS.Decoy,
    codes.STATUS.PerishSong,
}

-- Resolves an item's name based on available info
itemLogic.DEFAULT_ITEM_NAME = 'Item'

function itemLogic.resolveItemName(item)
    if item.itemType then
        return codes.ITEM_NAMES[item.itemType]
    elseif item.sprite.type then
        -- The actual item type isn't known, so describe the sprite instead
        return codes.COLOR_NAMES[item.sprite.color] .. ' ' ..
            codes.ITEM_SPRITE_NAMES[item.sprite.type]
    end
    -- The item hasn't even been seen
    return itemLogic.DEFAULT_ITEM_NAME
end

return itemLogic