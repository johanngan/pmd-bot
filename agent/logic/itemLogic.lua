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
local priorityLookup = LookupTable:new('agent/logic/item_priority.csv')
local itemPriorities = {}
local spritePriorities = {}
local priorityList = {}
for _, itemWithPriority in ipairs(priorityLookup(itemCodes)) do
    itemPriorities[itemWithPriority.ID] = itemWithPriority.priority
    table.insert(priorityList, itemWithPriority.priority)
    -- For a given sprite type, color pair, let the priority be the maximum
    -- priority of all items in that group
    local sprite = mechanics.item.sprites[itemWithPriority.ID]
    if spritePriorities[sprite.type] == nil then
        spritePriorities[sprite.type] = {}
    end
    if spritePriorities[sprite.type][sprite.color] == nil then
        spritePriorities[sprite.type][sprite.color] = -math.huge
    end
    spritePriorities[sprite.type][sprite.color] = math.max(
        spritePriorities[sprite.type][sprite.color], itemWithPriority.priority
    )
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

-- Resolves an items' priority based on available info
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