-- Useful basic action subroutines

require 'table'

require 'codes.direction'
require 'codes.menu'
require 'dynamicinfo.menuinfo'

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

---- END INTERNAL STUFF ----

---- BEGIN PUBLIC STUFF ----

-- Literally do nothing
function basicactions.nothing()
end

-- Mash B to get out of any menus, not including message boxes
-- Optionally specify a menu index to stop at upon reaching
function basicactions.closeMenus(stopAtMenu)
    while menuinfo.menuIsOpen() and not menuinfo.messageIsOpen() do
        if menuinfo.getMenu() == stopAtMenu then
            break
        end
        joypad.set({B=true})
        waitForMenuTransition()
    end
end

-- Mash X+B to close any message boxes
function basicactions.closeMessages()
    local alternate = {{X=true}, {B=true}}
    local i = 1
    while menuinfo.messageIsOpen() do
        i = 1 + (i % #alternate)
        joypad.set(alternate[i])
        waitForMenuTransition()
    end
end

-- Rest in place
function basicactions.rest()
    basicactions.closeMenus()
    joypad.set({A=true, B=true})
    emu.frameadvance()
end

-- Use a basic attack
function basicactions.attack()
    basicactions.closeMenus()
    joypad.set({A=true})
    emu.frameadvance()
end

-- Walk in some direction
function basicactions.walk(direction)
    local dirInput = directionInputs[direction]
    basicactions.closeMenus()
    joypad.set(dirInput)
    emu.frameadvance()
end

-- Face some direction
function basicactions.face(direction)
    local dirInput = directionInputs[direction]
    repeat  -- Until the input registers
        basicactions.closeMenus()
        hold({Y=true}, 2)
    until menuinfo.turningOnTheSpot()
    joypad.set(combineInputs({Y=true}, dirInput))
    emu.frameadvance()
end

-- Open the main menu
function basicactions.openMainMenu()
    basicactions.closeMenus(codes.MENU.Main)
    while menuinfo.getMenu() ~= codes.MENU.Main do
        joypad.set({X=true})
        waitForMenuTransition()
    end
end

-- Open the moves menu
function basicactions.openMovesMenu()
    basicactions.closeMenus(codes.MENU.Moves)
    while menuinfo.getMenu() ~= codes.MENU.Moves do
        joypad.set({X=true})
        waitForMenuTransition()
    end
end

-- Open the treasure bag menu
function basicactions.openBagMenu()
    basicactions.closeMenus(codes.MENU.Bag)
    while menuinfo.getMenu() ~= codes.MENU.Bag do
        hold({B=true}, 2)
        waitForMenuTransition()
    end
end

-- Open the ground menu
function basicactions.openGroundMenu()
    basicactions.openMainMenu()
    while menuinfo.getMenuCursorIndex() ~= 4 do
        navMenuIndex(menuinfo.getMenuCursorIndex(), 4)
    end
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Use a move at a given index
function basicactions.useMove(index)
    basicactions.openMovesMenu()
    while menuinfo.getMenuCursorIndex() ~= index do
        navMenuIndex(menuinfo.getMenuCursorIndex(), index)
    end
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.MoveAction
    while menuinfo.getMenuCursorIndex() ~= 0 do
        navMenuIndex(menuinfo.getMenuCursorIndex(), 0)
    end
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Select an item at some index
function basicactions.selectItem(index)
    local menuLength = menuinfo.maxMenuLengths[codes.MENU.Bag]
    local relIndex = index % menuLength
    local pageIndex = math.floor(index / menuLength)

    basicactions.openBagMenu()
    while menuinfo.getMenuPageIndex() ~= pageIndex do
        navMenuIndex(menuinfo.getMenuPageIndex(), pageIndex,
            codes.DIRECTION.Right, codes.DIRECTION.Left)
    end
    while menuinfo.getMenuCursorIndex() ~= relIndex do
        navMenuIndex(menuinfo.getMenuCursorIndex(), relIndex)
    end
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.ItemAction
end

-- Take some action with an item at a given index
function basicactions.itemAction(index, actionIndex)
    basicactions.selectItem(index)
    while menuinfo.getMenuCursorIndex() ~= actionIndex do
        navMenuIndex(menuinfo.getMenuCursorIndex(), actionIndex)
    end
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Take some action with an item at a given index on a teammate
function basicactions.itemActionOnTeammate(index, actionIndex, teammate)
    local teammate = teammate or 0    -- Default to using on the leader

    basicactions.itemAction(index, actionIndex)
    while menuinfo.getMenu() ~= codes.MENU.ItemFor do
        joypad.set({A=true})
        waitForMenuTransition()
    end
    while menuinfo.getMenuCursorIndex() ~= teammate do
        navMenuIndex(menuinfo.getMenuCursorIndex(), teammate)
    end
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Use an item at a given index
function basicactions.useRegularItem(index)
    basicactions.itemAction(index, 0)
end

-- Eat/ingest an item at a given index
function basicactions.eatFoodItem(index, teammate)
    basicactions.itemActionOnTeammate(index, 0, teammate)
end

-- Equip a held item at a given index
function basicactions.equipHeldItem(index, teammate)
    basicactions.itemActionOnTeammate(index, 0, teammate)
end

-- Unequip a held item at a given index
function basicactions.unequipHeldItem(index)
    basicactions.itemAction(index, 0)
end

-- Climbs the stairs when standing on them
function basicactions.climbStairs()
    while menuinfo.getMenu() ~= codes.MENU.Stairs do
        waitForMenuTransition()
        -- If the stairs menu still isn't open after waiting, try opening
        -- the ground menu
        if menuinfo.getMenu() ~= codes.MENU.Stairs then
            basicactions.openGroundMenu()
        end
    end
    while menuinfo.getMenuCursorIndex() ~= 0 do
        navMenuIndex(menuinfo.getMenuCursorIndex(), 0)
    end
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Pick an option in a Yes/No prompt. 0 for yes, 1 for no. Defaults to no
function basicactions.selectYesNo(selection)
    -- If not in a Yes/No prompt, just return
    if menuinfo.getMenu() ~= codes.MENU.YesNo then return end
    local selection = selection or 1
    while menuinfo.getMenuCursorIndex() ~= selection do
        navMenuIndex(menuinfo.getMenuCursorIndex(), selection)
    end
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Pick a move to forget when learning a new move (if you already have 4 moves).
-- Defaults to passing up the new move
function basicactions.selectMoveToForget(selection)
    -- If not in a new move prompt, just return
    if menuinfo.getMenu() ~= codes.MENU.NewMove then return end
    local selection = selection or 4
    while menuinfo.getMenuCursorIndex() ~= selection do
        navMenuIndex(menuinfo.getMenuCursorIndex(), selection)
    end
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.NewMoveAction
    while menuinfo.getMenuCursorIndex() ~= 0 do
        navMenuIndex(menuinfo.getMenuCursorIndex(), 0)
    end
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == codes.MENU.YesNo
    basicactions.selectYesNo(0)
end

return basicactions