-- Useful action subroutines

require 'table'

require 'utils.enum'
require 'menuinfo'

actions = {}

-- Enum for directions (matches the internal direction index in-game)
actions.DIRECTION, actions.DIRECTION_NAMES = enum.register(
    {'Down', 'DownRight', 'Right', 'UpRight', 'Up', 'UpLeft', 'Left', 'DownLeft'},
    0, 'direction'
)

---- BEGIN INTERNAL STUFF ----

-- Mapping from valid direction strings to inputs, for convenience
local directionInputs = {
    [actions.DIRECTION.Down]={down=true},
    [actions.DIRECTION.DownRight]={down=true, right=true},
    [actions.DIRECTION.Right]={right=true},
    [actions.DIRECTION.UpRight]={up=true, right=true},
    [actions.DIRECTION.Up]={up=true},
    [actions.DIRECTION.UpLeft]={up=true, left=true},
    [actions.DIRECTION.Left]={left=true},
    [actions.DIRECTION.DownLeft]={down=true, left=true},
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
    combined = {}
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
    advance(5)
end

-- Navigate to a certain index in a menu
local function navMenuIndex(currentIndex, targetIndex, incDirection, decDirection)
    if currentIndex == targetIndex then
        return
    end

    -- Default to up and down for navigation
    local incDirection = incDirection or actions.DIRECTION.Down
    local decDirection = decDirection or actions.DIRECTION.Up

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
function actions.nothing()
end

-- Mash B to get out of any menus, or X+B to cancel message boxes
-- Optionally specify a menu index to stop at upon reaching
function actions.closeMenus(stopAtMenu)
    while menuinfo.menuIsOpen() do
        if menuinfo.getMenu() == stopAtMenu then
            break
        end

        if menuinfo.messageIsOpen() then
            joypad.set({X=true})
            waitForMenuTransition()
        end
        joypad.set({B=true})
        waitForMenuTransition()
    end
end

-- Mash X+B to close any message boxes
function actions.closeMessages()
    local alternate = {{X=true}, {B=true}}
    local i = 1
    while menuinfo.messageIsOpen() do
        i = 1 + (i % #alternate)
        joypad.set(alternate[i])
        waitForMenuTransition()
    end
end

-- Rest in place
function actions.rest()
    actions.closeMenus()
    joypad.set({A=true, B=true})
    emu.frameadvance()
end

-- Use a basic attack
function actions.attack()
    actions.closeMenus()
    joypad.set({A=true})
    emu.frameadvance()
end

-- Walk in some direction
function actions.walk(direction)
    dirInput = directionInputs[direction]
    actions.closeMenus()
    joypad.set(dirInput)
    emu.frameadvance()
end

-- Face some direction
function actions.face(direction)
    dirInput = directionInputs[direction]
    actions.closeMenus()
    hold({Y=true}, 2)
    joypad.set(combineInputs({Y=true}, dirInput))
    emu.frameadvance()
end

-- Open the main menu
function actions.openMainMenu()
    actions.closeMenus(menuinfo.MENU.Main)
    while menuinfo.getMenu() ~= menuinfo.MENU.Main do
        joypad.set({X=true})
        waitForMenuTransition()
    end
end

-- Open the moves menu
function actions.openMovesMenu()
    actions.closeMenus(menuinfo.MENU.Moves)
    while menuinfo.getMenu() ~= menuinfo.MENU.Moves do
        joypad.set({X=true})
        waitForMenuTransition()
    end
end

-- Open the treasure bag menu
function actions.openBagMenu()
    actions.closeMenus(menuinfo.MENU.Bag)
    while menuinfo.getMenu() ~= menuinfo.MENU.Bag do
        hold({B=true}, 2)
        waitForMenuTransition()
    end
end

-- Use a move at a given index
function actions.useMove(index)
    actions.openMovesMenu()
    navMenuIndex(menuinfo.getMenuCursorIndex(), index)
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == menuinfo.MENU.MoveAction
    navMenuIndex(menuinfo.getMenuCursorIndex(), 0)
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Select an item at some index
function actions.selectItem(index)
    local menuLength = menuinfo.maxMenuLengths[menuinfo.MENU.Bag]
    local relIndex = index % menuLength
    local pageIndex = math.floor(index / menuLength)

    actions.openBagMenu()
    navMenuIndex(menuinfo.getMenuPageIndex(), pageIndex,
        actions.DIRECTION.Right, actions.DIRECTION.Left)
    navMenuIndex(menuinfo.getMenuCursorIndex(), relIndex)
    repeat
        joypad.set({A=true})
        waitForMenuTransition()
    until menuinfo.getMenu() == menuinfo.MENU.ItemAction
end

-- Take some action with an item at a given index
function actions.itemAction(index, actionIndex)
    actions.selectItem(index)
    navMenuIndex(menuinfo.getMenuCursorIndex(), actionIndex)
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Take some action with an item at a given index on a teammate
function actions.itemActionOnTeammate(index, actionIndex, teammate)
    local teammate = teammate or 0    -- Default to using on the leader

    actions.itemAction(index, actionIndex)
    while menuinfo.getMenu() ~= menuinfo.MENU.ItemFor do
        joypad.set({A=true})
        waitForMenuTransition()
    end
    navMenuIndex(menuinfo.getMenuCursorIndex(), teammate)
    joypad.set({A=true})
    waitForMenuTransition()
end

-- Use an item at a given index
function actions.useRegularItem(index)
    actions.itemAction(index, 0)
end

-- Eat/ingest an item at a given index
function actions.eatFoodItem(index, teammate)
    actions.itemActionOnTeammate(index, 0, teammate)
end

-- Equip a held item at a given index.
function actions.equipHeldItem(index, teammate)
    actions.itemActionOnTeammate(index, 0, teammate)
end

-- Unequip a held item at a given index.
function actions.unequipHeldItem(index)
    actions.itemAction(index, 0)
end

return actions