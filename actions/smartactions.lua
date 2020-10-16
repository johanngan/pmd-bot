-- Useful "smart" action subroutines that can check state info before trying
-- to act, and possibly perform more complex decision-making.
-- Will return a flag for whether or not the action was successful or not.
--
-- All public actions have a verbose flag as a final optional parameter
-- (default false).

require 'codes.item'
require 'codes.move'

require 'mechanics.item'
require 'mechanics.move'

require 'utils.messages'

require 'actions.basicactions'

smartactions = {}

-- Look for an item in the bag. If it exists, return the first matching index
-- (0-indexed) that's greater than or equal to startIdx (default 0), and the
-- item itself. Otherwise, return nil
local function searchBag(bag, item, startIdx)
    local startIdx = startIdx or 0
    for i=startIdx,#bag-1 do
        local bagItem = bag[i+1]    -- Access using 1-indexing
        if bagItem.itemType == item then 
            return i, bagItem
        end
    end
end

-- Use an item if it's in the bag and isn't sticky
function smartactions.useItemIfPossible(itemAction, item, bag, verbose)
    local itemIdx, bagItem = searchBag(bag, item)
    while itemIdx do
        if bagItem.isSticky then
            itemIdx, bagItem = searchBag(bag, item, itemIdx + 1)
        else
            messages.reportIfVerbose('Using ' ..
                codes.ITEM_NAMES[item] .. '.', verbose)
            itemAction(itemIdx)
            return true
        end
    end
    return false
end

-- Use a Max Elixir if a usable one is in the bag.
function smartactions.useMaxElixirIfPossible(bag, verbose)
    return smartactions.useItemIfPossible(basicactions.eatFoodItem,
        codes.ITEM.MaxElixir, bag, verbose)
end

-- Restore some stat by using an item if the stat falls below some threshold.
-- Attempt to use the item that restores the most without being wasteful.
-- If allowWaste is false, the non-wasteful condition is strictly enforced.
-- possibleItemsWithRestoreValues should be a list of {item: value} pairs.
local function useRestoringItemWithThreshold(
    bag, stat, statMax, threshold, allowWaste, possibleItemsWithRestoreValues, verbose)
    -- Don't need restoration
    if stat > threshold then return false end
    local statDeficit = statMax - stat
    -- Collect a list of all usable restoration items in the bag
    local bestItem = nil
    local bestItemValue = nil
    for _, item in ipairs(bag) do
        local itemValue = possibleItemsWithRestoreValues[item.itemType]
        if itemValue ~= nil and not item.isSticky then
            if bestItem == nil and (allowWaste or itemValue <= statDeficit) then
                -- This is the first usable item we've found
                bestItem = item
                bestItemValue = itemValue
            elseif itemValue <= statDeficit and itemValue > bestItemValue then
                -- The new item restores more than the current best, and still isn't wasteful
                bestItem = item
                bestItemValue = itemValue
            elseif bestItemValue > statDeficit and itemValue < bestItemValue then
                -- The current best item is wasteful. Reduce the value to be less wasteful
                -- This condition should only be hit if allowWaste is true
                bestItem = item
                bestItemValue = itemValue
            end
        end
    end
    if bestItem ~= nil then
        return smartactions.useItemIfPossible(
            basicactions.eatFoodItem, bestItem.itemType, bag, verbose)
    end
    return false    -- No items found
end

-- Eat a food item if hungry (belly <= threshold), and a usable one exists.
-- Try to use the one that restores the most belly without being wasteful.
function smartactions.eatFoodIfHungry(bag, belly, maxBelly, threshold, allowWaste, verbose)
    return useRestoringItemWithThreshold(bag, belly, maxBelly or 100,
        threshold or 50, allowWaste, mechanics.item.lists.food, verbose)
end

-- eatFoodIfHungry with a threshold of 0
function smartactions.eatFoodIfBellyEmpty(bag, belly, verbose)
    return smartactions.eatFoodIfHungry(bag, belly, nil, 0, true, verbose)
end

-- Use a healing item if health is low (HP <= threshold), and a usable one
-- exists. Try to use the one that restored the most HP without being wasteful.
function smartactions.healIfLowHP(bag, HP, maxHP, threshold, allowWaste, verbose)
    return useRestoringItemWithThreshold(bag, HP, maxHP,
        threshold, allowWaste, mechanics.item.lists.healing, verbose)
end

-- Use a move at some index (0-indexed) if it has PP, isn't sealed, and isn't
-- subsequent in a link chain
function smartactions.useMoveIfPossible(moveIdx, moveList, verbose)
    local move = moveList[moveIdx+1]   -- Access using 1-indexing
    if move and move.PP > 0 and not move.isSealed and not move.isDisabled
        and not move.subsequentInLinkChain then
        messages.reportIfVerbose('Using ' ..
            codes.MOVE_NAMES[move.moveID] .. '.', verbose)
        basicactions.useMove(moveIdx)
        return true
    end
    return false
end

-- Use a move at some index (0-indexed) if possible, and if the target is
-- in range of the user.
function smartactions.useMoveIfInRange(moveIdx, moveList, user, target, layout, verbose)
    local moveID = moveList[moveIdx+1].moveID    -- Access using 1-indexing
    if mechanics.move.inRange(moveID, target.xPosition, target.yPosition,
        user.xPosition, user.yPosition, layout) then
        return smartactions.useMoveIfPossible(moveIdx, moveList, verbose)
    end
    return false
end

return smartactions