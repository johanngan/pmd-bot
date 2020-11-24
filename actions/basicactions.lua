-- Useful basic action subroutines
--
-- All public actions have a verbose flag as a final optional parameter
-- (default false).

require 'table'

require 'codes.direction'
require 'codes.menu'
require 'dynamicinfo.menuinfo'
require 'utils.messages'

basicactions = {}

---- BEGIN INTERNAL STUFF ----

-- Mapping from valid direction strings to inputs, for convenience
local directionInputs = {
    [codes.DIRECTION.Down]={down=true},
    [codes.DIRECTION.DownRight]={down=true, right=true},
    [codes.DIRECTION.Right]={right=true},
    [codes.DIRECTION.UpRight]={up=true, right=true},
    [codes.DIRECTION.Up]={up=true},
    [codes.DIRECTION.UpLeft]={up=true, left=true},
    [codes.DIRECTION.Left]={left=true},
    [codes.DIRECTION.DownLeft]={down=true, left=true},
}

-- Advance some number of frames
local function advance(nframes)
    for i=1,nframes do
        emu.frameadvance()
    end
end

-- Hold an input for some number of frames
local function hold(input, nframes)
    for i=1,nframes do
        joypad.set(input)
        emu.frameadvance()
    end
end

-- Combine two input tables
local function combineInputs(input1, input2)
    local combined = {}
    for k in pairs(input1) do
        combined[k] = true
    end
    for k in pairs(input2) do
        combined[k] = true
    end
    return combined
end

-- Wait for a menu transition (between selecting a menu item and regaining input control)
-- Since menuinfo.inMenuTransition is a few frames short on both ends, add a few more
-- waiting frames before and after menuinfo.inMenuTransition indicates
local function waitForMenuTransition()
    advance(3)
    while menuinfo.inMenuTransition() do
        emu.frameadvance()
    end
    advance(6)
end

-- Navigate to a certain index in a menu
local function navMenuIndex(currentIndex, targetIndex, incDirection, decDirection)
    if currentIndex == targetIndex then
        return
    end

    -- Default to up and down for navigation
    local incDirection = incDirection or codes.DIRECTION.Down
    local decDirection = decDirection or codes.DIRECTION.Up

    local diff = targetIndex - currentIndex
    local dirInput = directionInputs[(diff > 0) and incDirection or decDirection]
    for i=1,math.abs(diff) do
        joypad.set(dirInput)
        waitForMenuTransition()
    end
end

-- Navigate to a certain cursor index in a menu
local function navCursorIndex(targetIndex)
    while menuinfo.getMenuCursorIndex() ~= targetIndex do
        navMenuIndex(menuinfo.getMenuCursorIndex(), targetIndex)
    end
end

-- Navigate to a certain page index in a menu
local function navPageIndex(targetIndex)
    -- If the current menu doesn't support a page index, just abort
    if pcall(menuinfo.getMenuPageIndex) then
        while menuinfo.getMenuPageIndex() ~= targetIndex do
            navMenuIndex(menuinfo.getMenuPageIndex(), targetIndex,
                codes.DIRECTION.Right, codes.DIRECTION.Left)
        end
    end
end

-- Navigate to a certain absolute index in a paged menu
local function navAbsoluteIndex(targetIndex, pageLength)
    local relIndex = targetIndex % pageLength
    local pageIndex = math.floor(targetIndex / pageLength)

    navPageIndex(pageIndex)
    navCursorIndex(relIndex)
end

---- END INTERNAL STUFF ----

---- BEGIN PUBLIC STUFF ----

-- Literally do nothing
function basicactions.nothing(verbose)
    messages.reportIfVerbose('Doing nothing.', verbose)
end

-- Mash B to get out of any menus, not including message boxes
-- Optionally specify a menu index to stop at upon reaching
function basicactions.closeMenus(stopAtMenu, verbose)
    messages.reportIfVerbose('Closing menus.', verbose)

    while menuinfo.menuIsOpen() and not menuinfo.messageIsOpen() do
        if menuinfo.getMenu() == stopAtMenu then
            break
        end
        joypad.set({B=true})
        waitForMenuTransition()
    end
end

-- Mash X+B to close any message boxes
function basicactions.closeMessages(verbose)
    messages.reportIfVerbose('Closing messages.', verbose)

    local alternate = {{X=true}, {B=true}}
    local i = 1
    while menuinfo.messageIsOpen() do
        i = 1 + (i % #alternate)
        joypad.set(alternate[i])
        waitForMenuTransition()
    end
end

-- Rest in place
function basicactions.rest(verbose)
    messages.reportIfVerbose('Resting.', verbose)

    basicactions.closeMenus()
    joypad.set({A=true, B=true})
    emu.frameadvance()
end

-- Use a basic attack
function basicactions.attack(verbose)
    messages.reportIfVerbose('Using regular attack.', verbose)

    basicactions.closeMenus()
    joypad.set({A=true})
    emu.frameadvance()
end

-- Walk in some direction
function basicactions.walk(direction, verbose)
    messages.reportIfVerbose('Walking ' .. codes.DIRECTION_NAMES[direction] .. '.', verbose)

    local dirInput = directionInputs[direction]
    basicactions.closeMenus()
    joypad.set(dirInput)
    emu.frameadvance()
end

-- Face some direction
function basicactions.face(direction, verbose)
    messages.reportIfVerbose('Facing ' .. codes.DIRECTION_NAMES[direction] .. '.', verbose)

    local dirInput = directionInputs[direction]
    repeat  -- Until the input registers
        basicactions.closeMenus()
        hold({Y=true}, 2)
    until menuinfo.turningOnTheSpot()
    joypad.set(combineInputs({Y=true}, dirInput))
    emu.frameadvance()
end

-- Just pressing X repeatedly to open a specific menu is somewhat dangerous
-- because X can't close menus. This function adds some extra logic
-- that tracks the current menu, and retries closing all menus if
-- it stays the same for too long.
local function guardedXPresses(targetMenu, maxIdleCycles)
    -- Max # of iterations to try pressing X on the same menu before
    -- retrying to close all menus
    local maxIdleCycles = maxIdleCycles or 3

    basicactions.closeMenus(targetMenu)
    local prevMenu = menuinfo.getMenu()
    local idleCycles = 0
    while menuinfo.getMenu() ~= targetMenu do
        joypad.set({X=true})
        waitForMenuTransition()

        -- Guard logic; if the menu isn't changing, increment a counter
        -- If that counter exceeds the threshold, retry closing all menus
        if prevMenu == menuinfo.getMenu() then
            idleCycles = idleCycles + 1
        end
        if idleCycles > maxIdleCycles then
            idleCycles = 0
            basicactions.closeMenus(targetMenu)
        end
        prevMenu = menuinfo.getMenu()
    end
end

-- Open the main menu
function basicactions.openMainMenu(verbose)
    messages.reportIfVerbose('Opening main menu.', verbose)

    guardedXPresses(codes.MENU.Main)
end

-- Open the moves menu
function basicactions.openMovesMenu(verbose)
    messages.reportIfVerbose('Opening moves menu.', verbose)

    guardedXPresses(codes.MENU.Moves)
end

-- Open the treasure bag menu
function basicactions.openBagMenu(verbose)
    messages.reportIfVerbose('Opening bag.', verbose)

    basicactions.closeMenus(codes.MENU.Bag)
    while menuinfo.getMenu() ~= codes.MENU.Bag do
        hold({B=true}, 2)
        waitForMenuTransition()
    end
end

-- Make a selection on an open menu
function basicactions.makeMenuSelection(index, verbose)
    messages.reportIfVerbose('Selection menu option ' .. (index+1), verbose)

    navCursorIndex(index)
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Open the ground menu
function basicactions.openGroundMenu(verbose)
    messages.reportIfVerbose('Checking underfoot.', verbose)

    basicactions.openMainMenu()
    basicactions.makeMenuSelection(4)
end

-- Use a move at a given index
function basicactions.useMove(index, verbose)
    messages.reportIfVerbose('Using move ' .. (index+1) .. '.', verbose)

    basicactions.openMovesMenu()
    navCursorIndex(index)
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.MoveAction
    basicactions.makeMenuSelection(0)
end

-- Select an item at some index
function basicactions.selectItem(index, verbose)
    messages.reportIfVerbose('Selecting item ' .. (index+1) .. '.', verbose)

    basicactions.openBagMenu()
    navAbsoluteIndex(index, menuinfo.maxMenuLengths[codes.MENU.Bag])
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.ItemAction
end

-- Take some action with an item at a given index
function basicactions.itemAction(index, actionIndex, verbose)
    messages.reportIfVerbose('Using item ' .. (index+1) .. ' with action ' ..
        (actionIndex+1) .. '.', verbose)

    basicactions.selectItem(index)
    basicactions.makeMenuSelection(actionIndex)
end

-- Take a followup action for an item
function basicactions.itemFollowupAction(followupMenu, followupIndex, verbose)
    messages.reportIfVerbose('Following up with action ' ..
        (followupIndex+1) .. '.', verbose)

    while menuinfo.getMenu() ~= followupMenu do
        joypad.set({A=true})
        waitForMenuTransition()
    end
    navAbsoluteIndex(followupIndex, menuinfo.maxMenuLengths[followupMenu])
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Take some action with an item at a given index on a teammate
function basicactions.itemActionOnTeammate(index, actionIndex, teammate, verbose)
    local text = 'Using item ' .. (index+1) .. ' with action ' .. (actionIndex+1)
    if teammate then
        text = text .. ' on teammate ' .. (teammate+1)
    end
    text = text .. '.'
    messages.reportIfVerbose(text, verbose)

    local teammate = teammate or 0    -- Default to using on the leader

    basicactions.itemAction(index, actionIndex)
    basicactions.itemFollowupAction(codes.MENU.ItemFor, teammate)
end

-- Use an item at a given index
function basicactions.useRegularItem(index, verbose)
    messages.reportIfVerbose('Using item ' .. (index+1) .. '.', verbose)

    basicactions.itemAction(index, 0)
end

-- Eat/ingest an item at a given index
function basicactions.eatFoodItem(index, teammate, verbose)
    local text = 'Eating item ' .. (index+1)
    if teammate then
        text = text .. ' [teammate ' .. (teammate+1) .. ']'
    end
    text = text .. '.'
    messages.reportIfVerbose(text, verbose)

    basicactions.itemActionOnTeammate(index, 0, teammate)
end

-- Equip a held item at a given index
function basicactions.equipHeldItem(index, teammate, verbose)
    local text = 'Equipping item ' .. (index+1)
    if teammate then
        text = text .. ' on teammate ' .. (teammate+1)
    end
    text = text .. '.'
    messages.reportIfVerbose(text, verbose)

    basicactions.itemActionOnTeammate(index, 0, teammate)
end

-- Unequip a held item at a given index
function basicactions.unequipHeldItem(index, verbose)
    messages.reportIfVerbose('Unequipping item ' .. (index+1) .. '.', verbose)

    basicactions.itemAction(index, 0)
end

-- Climbs the stairs when standing on them
function basicactions.climbStairs(verbose)
    messages.reportIfVerbose('Proceeding to next floor.', verbose)

    while menuinfo.getMenu() ~= codes.MENU.Stairs do
        waitForMenuTransition()
        -- If the stairs menu still isn't open after waiting, try opening
        -- the ground menu
        if menuinfo.getMenu() ~= codes.MENU.Stairs then
            basicactions.openGroundMenu()
        end
    end
    basicactions.makeMenuSelection(0)
end

-- Triggers a tile when standing on it
function basicactions.triggerTile(verbose)
    messages.reportIfVerbose('Triggering tile.', verbose)

    -- Triggering a tile is equivalent to climbing stairs
    basicactions.climbStairs(false)
end

-- Pick an option in a Yes/No prompt. 0 for yes, 1 for no. Defaults to no
function basicactions.selectYesNo(selection, verbose)
    messages.reportIfVerbose('Selecting "' .. ((selection == 0) and 'Yes' or 'No') .. '".', verbose)

    -- If not in a Yes/No prompt, just return
    if menuinfo.getMenu() ~= codes.MENU.YesNo then return end
    local selection = selection or 1
    basicactions.makeMenuSelection(selection)
end

-- Pick a move to forget when learning a new move (if you already have 4 moves).
-- Defaults to passing up the new move
function basicactions.selectMoveToForget(selection, verbose)
    messages.reportIfVerbose('Forgetting move ' .. (selection+1) .. '.', verbose)

    -- If not in a new move prompt, just return
    if menuinfo.getMenu() ~= codes.MENU.NewMove then return end
    local selection = selection or 4
    navCursorIndex(selection)
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.NewMoveAction
    navCursorIndex(0)
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.YesNo
    basicactions.selectYesNo(0)
end

return basicactions