-- Useful "smart" action subroutines that can check state info before trying
-- to act, and possibly perform more complex decision-making.
-- Will return a flag for whether or not the action was successful or not.
--
-- All public actions have a verbose flag as a final optional parameter
-- (default false).

require 'codes.item'
require 'codes.itemMenuType'
require 'codes.menu'
require 'codes.move'
require 'codes.status'
require 'codes.terrain'

require 'mechanics.item'
require 'mechanics.move'

require 'utils.enum'
require 'utils.messages'

require 'actions.basicactions'

smartactions = {}

local ACTION, ACTION_NAMES = enum.register({
    'Use',
    'Give',
    'Take',
    'PickUp',
    'Place',
    'Swap',
    'Throw',
    'Set',
})
local MENU_MODE = enum.register({
    'Normal',
    'Held',
    'Underfoot',
})
local function actionSpec(actionType, followupMenu, possibleIfSticky)
    local followupMenu = followupMenu or codes.MENU.None
    if possibleIfSticky == nil then
        possibleIfSticky = true
    end
    return {action=actionType, followup=followupMenu, possibleIfSticky=possibleIfSticky}
end

-- Maps [menu type] -> [item mode] -> [action index]
--  -> (action type, follow-up type, possible if sticky)
local actionSpecMap = {
    [codes.ITEM_MENU_TYPE.UsableWithTarget] = {
        [MENU_MODE.Normal] = {
            [0] = actionSpec(ACTION.Use, codes.MENU.ItemFor, false),
            [1] = actionSpec(ACTION.Give, codes.MENU.ItemFor),
            [2] = actionSpec(ACTION.Place),
            [3] = actionSpec(ACTION.Throw),
        },
        [MENU_MODE.Held] = {
            [0] = actionSpec(ACTION.Take, nil, false),
            [1] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap, false),
            [2] = actionSpec(ACTION.Use, codes.MENU.ItemFor, false),
        },
        [MENU_MODE.Underfoot] = {
            [0] = actionSpec(ACTION.PickUp),
            [1] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap),
            [2] = actionSpec(ACTION.Use, codes.MENU.ItemFor, false),
            [3] = actionSpec(ACTION.Throw),
        },
    },
    [codes.ITEM_MENU_TYPE.Orb] = {
        [MENU_MODE.Normal] = {
            [0] = actionSpec(ACTION.Use, nil, false),
            [1] = actionSpec(ACTION.Give, codes.MENU.ItemFor),
            [2] = actionSpec(ACTION.Place),
            [3] = actionSpec(ACTION.Throw),
        },
        [MENU_MODE.Held] = {
            [0] = actionSpec(ACTION.Take, nil, false),
            [1] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap, false),
            [2] = actionSpec(ACTION.Use, nil, false),
        },
        [MENU_MODE.Underfoot] = {
            [0] = actionSpec(ACTION.PickUp),
            [1] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap),
            [2] = actionSpec(ACTION.Use, nil, false),
            [3] = actionSpec(ACTION.Throw),
        },
    },
    [codes.ITEM_MENU_TYPE.ThrowingItem] = {
        [MENU_MODE.Normal] = {
            [0] = actionSpec(ACTION.Throw, nil, false),
            [1] = actionSpec(ACTION.Give, codes.MENU.ItemFor),
            [2] = actionSpec(ACTION.Place),
            [3] = actionSpec(ACTION.Set),
        },
        [MENU_MODE.Held] = {
            [0] = actionSpec(ACTION.Throw, nil, false),
            [1] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap, false),
            [2] = actionSpec(ACTION.Take, nil, false),
        },
        [MENU_MODE.Underfoot] = {
            [0] = actionSpec(ACTION.PickUp),
            [1] = actionSpec(ACTION.Throw, nil, false),
            [2] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap),
        },
    },
    [codes.ITEM_MENU_TYPE.HeldItem] = {
        [MENU_MODE.Normal] = {
            [0] = actionSpec(ACTION.Give, codes.MENU.ItemFor),
            [1] = actionSpec(ACTION.Place),
            [2] = actionSpec(ACTION.Throw),
        },
        [MENU_MODE.Held] = {
            [0] = actionSpec(ACTION.Take, nil, false),
            [1] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap, false),
        },
        [MENU_MODE.Underfoot] = {
            [0] = actionSpec(ACTION.PickUp),
            [1] = actionSpec(ACTION.Swap, codes.MENU.ItemSwap),
            [2] = actionSpec(ACTION.Throw),
        },
    }
}
local function findActionIdx(actionSpecs, actionCode)
    for idx, spec in pairs(actionSpecs) do
        if spec.action == actionCode then return idx end
    end
    return nil
end

-- These actions are always prevented when under Embargo
local preventedByEmbargo = {
    [ACTION.Use] = true,
    [ACTION.Throw] = true,
}

local function isHeld(item)
    return item.heldBy > 0
end

-- true if placing is possible, false if not, and nil if the place
-- option is completely gone from the menu
local function placeOptionStatus(x, y, layout, traps)
    if layout[y][x].isStairs then return nil end
    for _, trap in ipairs(traps) do
        if trap.xPosition == x and trap.yPosition == y then
            return nil
        end
    end

    if layout[y][x].terrain ~= codes.TERRAIN.Normal then return false end

    return true
end

-- Gets the item at a certain position, or nil if there's nothing
local function groundItem(items, x, y)
    for _, item in ipairs(items) do
        if item.xPosition == x and item.yPosition == y then
            return item
        end
    end
    return nil
end

-- Checks if a monster has some status. Returns nil if uncertain
local function hasStatus(monster, statusType)
    if monster.statuses == nil then return nil end
    for _, status in ipairs(monster.statuses) do
        if status.statusType == statusType then
            return true
        end
    end
    return false
end

-- Perform some action with an item if possible.
-- itemIdx is 0-indexed. A value of -1 means the item underfoot.
-- followupIdx is also 0-indexed, if non-nil.
-- state can be either from stateinfo or visibleinfo; it makes no difference.
local function itemActionIfPossible(actionCode, itemIdx, state, followupIdx, verboseMessage)
    local leader = state.player.leader()
    local bag = state.player.bag()

    local underfoot = (itemIdx == -1)
    local item = nil
    if underfoot then
        item = groundItem(state.dungeon.entities.items(), leader.xPosition, leader.yPosition)
        -- If no items matched, there are no items underfoot
        if not item then return false end
    else
        assert(itemIdx < #bag and itemIdx >= 0, 'Bag index ' .. itemIdx .. ' out of range.')
        -- Convert to 1-indexing for access
        item = bag[itemIdx+1]
    end

    local held = isHeld(item)
    assert(not (held and underfoot), 'Item cannot be both held and underfoot.')

    -- If the action is "Swap" and the item is neither held nor underfoot,
    -- redirect the action to "Place". They're essentially interchangeable,
    -- just that Place turns into Swap when there's another item underfoot.
    if actionCode == ACTION.Swap and not held and not underfoot then
        actionCode = ACTION.Place
    end

    local menuType = mechanics.item.menuTypes[item.itemType]

    -- For throwing items, "Use" and "Throw" are synonymous
    if menuType == codes.ITEM_MENU_TYPE.ThrowingItem and actionCode == ACTION.Use then
        actionCode = ACTION.Throw
    end

    local menuMode = MENU_MODE.Normal
    if held then menuMode = MENU_MODE.Held end
    if underfoot then menuMode = MENU_MODE.Underfoot end

    actionSpecs = actionSpecMap[menuType][menuMode]
    -- actionIdx is 0-indexed
    local actionIdx = findActionIdx(actionSpecs, actionCode)
    assert(actionIdx, 'Invalid action: cannot ' .. ACTION_NAMES[actionCode] ..
        (held and ' held' or '') .. (underfoot and ' underfoot' or '') .. ' ' ..
        codes.ITEM_NAMES[item.itemType] .. '.')
    local action = actionSpecs[actionIdx]

    assert(action.followup == codes.MENU.None or followupIdx, 'Action ' ..
        ACTION_NAMES[actionCode] .. ' requires a followup index but none was given.')
    if action.followup == codes.MENU.ItemSwap then
        assert(not isHeld(bag[followupIdx+1]), 'Cannot swap out held item (' ..
            codes.ITEM_NAMES[bag[followupIdx+1].itemType] .. ').')
    end

    -- Make sure the action can be done if under Embargo
    if preventedByEmbargo[actionCode] and hasStatus(leader, codes.STATUS.Embargo) then
        return false
    end

    -- If picking up an item, check that there's space
    if actionCode == ACTION.PickUp and #bag >= state.player.bagCapacity() then
        return false
    end

    if item.isSticky and not action.possibleIfSticky then return false end

    -- If the action comes after a "Place" action then we need to check that
    -- the option isn't disabled
    local placeIdx = findActionIdx(actionSpecs, ACTION.Place)
    if placeIdx and actionIdx >= placeIdx then
        local placeStatus = placeOptionStatus(leader.xPosition, leader.yPosition,
            state.dungeon.layout(), state.dungeon.entities.traps())
        if not placeStatus then
            if actionCode == ACTION.Place then return false end
            -- The option is completely gone
            if placeStatus == nil then
                -- Shift the action index back by 1
                actionIdx = actionIdx - 1
            end
        end
    end

    -- We're good to go. Carry out the action.
    if verboseMessage then
        local firstPart = verboseMessage
        local secondPart = nil
        if type(verboseMessage) == 'table' then
            firstPart = verboseMessage[1]
            secondPart = verboseMessage[2]
        end
        local message = firstPart .. ' ' .. codes.ITEM_NAMES[item.itemType]
        if secondPart then
            message = message .. ' ' .. secondPart
        end
        message = message .. '.'
        messages.report(message)
    end

    -- Carry out the primary action
    if underfoot then
        basicactions.openGroundMenu()
        -- Abort if the menu isn't right
        assert(menuinfo.getMenu() == codes.MENU.Ground, 'No item underfoot.')
        basicactions.makeMenuSelection(actionIdx)
    else
        basicactions.itemAction(itemIdx, actionIdx)
    end

    -- If necessary, carry out the followup action
    -- If using an item held by a party member other than the leader, ignore the followup
    -- if it's an ItemFor menu, since the holder of the item will automatically be targeted
    if action.followup ~= codes.MENU.None and
        not (action.followup == codes.MENU.ItemFor and item.heldBy > 1) then
        basicactions.itemFollowupAction(action.followup, followupIdx)
    end

    return true
end

-- itemIdx and teammate are both 0-indexed
function smartactions.useItemIfPossible(itemIdx, state, teammate, verbose)
    local verboseMessage = nil
    if verbose then
        verboseMessage = 'Using'
        if teammate then
            verboseMessage = {verboseMessage, 'on teammate ' .. (teammate+1)}
        end
    end

    -- Default to using on the leader if needed
    return itemActionIfPossible(ACTION.Use, itemIdx, state, teammate or 0, verboseMessage)
end

-- itemIdx and teammate are both 0-indexed
function smartactions.giveItemIfPossible(itemIdx, state, teammate, verbose)
    local verboseMessage = nil
    if verbose then
        verboseMessage = 'Giving'
        if teammate then
            verboseMessage = {verboseMessage, 'to teammate ' .. (teammate+1)}
        end
    end

    -- Default to using on the leader if needed
    return itemActionIfPossible(ACTION.Give, itemIdx, state, teammate or 0, verboseMessage)
end

-- itemIdx is 0-indexed
function smartactions.takeItemIfPossible(itemIdx, state, verbose)
    local verboseMessage = verbose and 'Taking' or nil

    return itemActionIfPossible(ACTION.Take, itemIdx, state, nil, verboseMessage)
end

-- itemIdx is 0-indexed
function smartactions.pickUpItemIfPossible(itemIdx, state, verbose)
    local verboseMessage = verbose and 'Picking up' or nil

    return itemActionIfPossible(ACTION.PickUp, itemIdx, state, nil, verboseMessage)
end

-- This turns into swapping if there's an item underfoot
-- itemIdx is 0-indexed
function smartactions.placeItemIfPossible(itemIdx, state, verbose)
    local verboseMessage = verbose and 'Placing' or nil

    return itemActionIfPossible(ACTION.Place, itemIdx, state, nil, verboseMessage)
end

-- itemIdx and swapBagIdx are both 0-indexed
function smartactions.swapItemIfPossible(itemIdx, state, swapBagIdx, verbose)
    -- If swapBagIdx is -1, make it nil to signify underfoot
    if swapBagIdx == -1 then swapBagIdx = nil end

    local verboseMessage = nil
    if verbose then
        verboseMessage = 'Swapping out'
        local otherItem, conjunction = nil, 'and'
        if swapBagIdx then
            otherItem = state.player.bag()[swapBagIdx+1]
        else
            -- Look underfoot
            local leader = state.player.leader()
            otherItem = groundItem(state.dungeon.entities.items(),
                leader.xPosition, leader.yPosition)
            conjunction = 'for'
        end
        -- If there's another item, include it in the message
        if otherItem then
            verboseMessage = {'Swapping', conjunction .. ' ' ..
                codes.ITEM_NAMES[otherItem.itemType]}
        end
    end

    return itemActionIfPossible(ACTION.Swap, itemIdx, state, swapBagIdx, verboseMessage)
end

-- itemIdx is 0-indexed
function smartactions.throwItemIfPossible(itemIdx, state, verbose)
    local verboseMessage = verbose and 'Throwing' or nil

    return itemActionIfPossible(ACTION.Throw, itemIdx, state, nil, verboseMessage)
end

-- itemIdx is 0-indexed
function smartactions.setItemIfPossible(itemIdx, state, verbose)
    local verboseMessage = verbose and 'Setting' or nil

    return itemActionIfPossible(ACTION.Set, itemIdx, state, nil, verboseMessage)
end

-- Look for an item in the bag. If it exists, return the first matching index
-- (0-indexed) that's greater than or equal to startIdx (default 0), and the
-- item itself. Otherwise, return nil
local function searchBag(bag, itemType, startIdx)
    local startIdx = startIdx or 0
    for i=startIdx,#bag-1 do
        local bagItem = bag[i+1]    -- Access using 1-indexing
        if bagItem.itemType == itemType then
            return i, bagItem
        end
    end
end

-- Search for items in the bag, and try to take the action with first possible occurrence.
-- validityFn is an extra validity check to perform not done by the actionFn. If nil,
-- no extra checks will be performed.
-- Variadic arguments should be everything for actionFn except itemIdx and state.
local function itemTypeActionIfPossible(validityFn, actionFn, itemType, state, ...)
    local bag = state.player.bag()
    local itemIdx, bagItem = searchBag(bag, itemType)
    while itemIdx do
        if (validityFn == nil or validityFn(bagItem)) and
            actionFn(itemIdx, state, unpack(arg)) then
            return true
        end
        itemIdx, bagItem = searchBag(bag, itemType, itemIdx + 1)
    end
    return false
end

function smartactions.useItemTypeIfPossible(itemType, state, verbose)
    return itemTypeActionIfPossible(nil,
        smartactions.useItemIfPossible, itemType, state, nil, verbose)
end

function smartactions.useMaxElixirIfPossible(state, verbose)
    return smartactions.useItemTypeIfPossible(codes.ITEM.MaxElixir, state, verbose)
end

-- Restore some stat by using an item if the stat falls below some threshold.
-- Attempt to use the item that restores the most without being wasteful.
-- If allowWaste is false, the non-wasteful condition is strictly enforced.
-- possibleItemsWithRestoreValues should be a list of {item: value} pairs.
local function useRestoringItemWithThreshold(
    state, stat, statMax, threshold, allowWaste, possibleItemsWithRestoreValues, verbose)
    -- Don't need restoration
    if stat > threshold then return false end
    local statDeficit = statMax - stat
    -- Collect a list of all usable restoration items in the bag
    local bestItem = nil
    local bestItemValue = nil
    for _, item in ipairs(state.player.bag()) do
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
        return smartactions.useItemTypeIfPossible(bestItem.itemType, state, verbose)
    end
    return false    -- No items found
end

-- Eat a food item if hungry (belly <= threshold), and a usable one exists.
-- Try to use the one that restores the most belly without being wasteful.
function smartactions.eatFoodIfHungry(state, belly, maxBelly, threshold, allowWaste, verbose)
    return useRestoringItemWithThreshold(state, belly, maxBelly or 100,
        threshold or 50, allowWaste, mechanics.item.lists.food, verbose)
end

-- eatFoodIfHungry with a threshold of 0
function smartactions.eatFoodIfBellyEmpty(state, belly, verbose)
    return smartactions.eatFoodIfHungry(state, belly, nil, 0, true, verbose)
end

-- Use a healing item if health is low (HP <= threshold), and a usable one
-- exists. Try to use the one that restored the most HP without being wasteful.
function smartactions.healIfLowHP(state, HP, maxHP, threshold, allowWaste, verbose)
    -- Check for Heal Block
    if hasStatus(state.player.leader(), codes.STATUS.HealBlock) then
        return false
    end

    return useRestoringItemWithThreshold(state, HP, maxHP,
        threshold, allowWaste, mechanics.item.lists.healing, verbose)
end

function smartactions.giveItemTypeIfPossible(itemType, state, verbose)
    return itemTypeActionIfPossible(function(item) return not isHeld(item) end,
        smartactions.giveItemIfPossible, itemType, state, nil, verbose)
end

function smartactions.throwItemTypeIfPossible(itemType, state, verbose)
    return itemTypeActionIfPossible(function(item) return not isHeld(item) or
            mechanics.item.menuTypes[item.itemType] == codes.ITEM_MENU_TYPE.ThrowingItem
        end,
        smartactions.throwItemIfPossible, itemType, state, nil, verbose)
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