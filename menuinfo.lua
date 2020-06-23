-- Reading state info from memory specifically related to menuing

require 'utils/enum'
require 'utils/memoryrange'
require 'stateinfo'

menuinfo = {}

-- Enum for menu names
menuinfo.MENU, menuinfo.MENU_NAMES = enum.register({
    'None',
    'MessageBox',
    'DialogueBox',
    'Main',
    'Moves',
    'MoveAction',
    'Bag',
    'ItemAction',
    'ItemFor',
    'Team',
    'LeaderAction',
    'TeammateAction',
    'IQ',
    'IQAction',
    'Tactics',
    'TacticsAction',
    'Others',
    'Ground',
    'Stairs',
    'Rest',
}, 1, 'menu')
local MENU, MENU_NAMES = menuinfo.MENU, menuinfo.MENU_NAMES

---- BEGIN INTERNAL TABLES ----

-- 2-byte "codes" for each menu at 0x022A7A74. Not sure if they're intended to be
-- used as codes, but they do seem to be identifying
local menuCodes = {
    [1] = MENU.None,
    [141] = MENU.MessageBox,
    [166] = MENU.DialogueBox,
    [279] = MENU.Main,
    [329] = MENU.Moves,
    [417] = MENU.MoveAction,
    [343] = MENU.Bag,
    [392] = MENU.ItemAction, -- 4 options. Includes equipped held/unusable items.
    [406] = MENU.ItemAction, -- 5 options. Includes held items and items that can't be "used", as well as equipped consumables
    [420] = MENU.ItemAction, -- 6 options. Includes "consumable" items like food, thrown items, and orbs
    [189] = MENU.ItemFor,
    [121] = MENU.Team, -- 1-member party
    [151] = MENU.Team, -- 2-member party
    [181] = MENU.Team, -- 3-member party
    [196] = MENU.Team, -- 4-member party
    [220] = MENU.LeaderAction, -- 1-member party
    [250] = MENU.LeaderAction, -- 2-member party
    [280] = MENU.LeaderAction, -- 3-member party
    [295] = MENU.LeaderAction, -- 4-member party
    [294] = MENU.TeammateAction, -- 2-member party
    [324] = MENU.TeammateAction, -- 3-member party
    [339] = MENU.TeammateAction, -- 4-member party
    [307] = MENU.IQ,
    [355] = MENU.IQAction,
    [325] = MENU.Tactics,
    [373] = MENU.TacticsAction,
    [239] = MENU.Others,
    [140] = MENU.Ground, -- 5 options. Includes "unusable" items and thrown items on the ground
    [154] = MENU.Ground, -- 6 options. Includes "consumable" items on the ground and shop items
    [119] = MENU.Stairs, -- 3 options. Also includes wonder tiles and traps when you use through Ground, but that's unusual
    [97] = MENU.Rest,
}
setmetatable(menuCodes, {__index = function(table, key) return 'Unknown' end})

-- The cursor index for many menus is stored in a volatile location, but in this case
-- there's a reliable double pointer that points to where the cursor index is stored
-- In fact, pretty much all menu indexes are stored this way...except the Moves menu
-- for some reason, which is stored at a stable address
local volatileCursorInfo = {
    [MENU.Main] = 0x020B34D4,
    [MENU.MoveAction] = 0x020B3474,
    [MENU.Bag] = 0x020B34A4,
    [MENU.ItemAction] = 0x020B3474,
    [MENU.ItemFor] = 0x020B34D4,
    [MENU.Team] = 0x20B34BC,
    [MENU.LeaderAction] = 0x020B3474,
    [MENU.TeammateAction] = 0x020B3474,
    [MENU.IQ] = 0x020B3474,
    [MENU.IQAction] = 0x020B3474,
    [MENU.Tactics] = 0x020B3474,
    [MENU.TacticsAction] = 0x020B3474,
    [MENU.Others] = 0x020B3474,
    [MENU.Ground] = 0x020B3474,
    [MENU.Stairs] = 0x020B34A4,
    [MENU.Rest] = 0x020B3474,
}

---- END INTERNAL TABLES ----

-- Maximum number of positions in each menu, if applicable
menuinfo.maxMenuLengths = {
    [MENU.Main] = 7,
    [MENU.Moves] = 4,
    [MENU.MoveAction] = 6,
    [MENU.Bag] = 8,
    [MENU.ItemAction] = 6,
    [MENU.ItemFor] = 4,
    [MENU.Team] = 4,
    [MENU.LeaderAction] = 5,
    [MENU.TeammateAction] = 7,
    [MENU.IQ] = 8,
    [MENU.IQAction] = 3,
    [MENU.Tactics] = 8,
    [MENU.TacticsAction] = 3,
    [MENU.Others] = 7,
    [MENU.Ground] = 6,
    [MENU.Stairs] = 3,
    [MENU.Rest] = 2,
}

-- Rough indicator of whether or not the game is in a
-- (typically short) menu transition sequence
-- the period of "on" time seems to be too small on both ends by a few frames,
-- depending on the menu transition
function menuinfo.inMenuTransition()
    return (memory.readbyte(0x0228B06A) ~= 0) and stateinfo.state.canAct()
end

-- Get the current menu's internal code
function menuinfo.getMenuCode()
    return memory.readword(0x022A7A74, 0x022A7A75)
end

-- Get the current menu
function menuinfo.getMenu()
    return menuCodes[menuinfo.getMenuCode()]
end

-- Get the string name of the current menu
function menuinfo.getMenuName()
    return MENU_NAMES[menuinfo.getMenu()]
end

-- Detect whether any sort of menu is open or not (including messages)
function menuinfo.menuIsOpen()
    return menuinfo.getMenu() ~= MENU.None
end

-- Detect whether a message/dialogue box is open
function menuinfo.messageIsOpen()
    local currentMenu = menuinfo.getMenu()
    return currentMenu == MENU.MessageBox or currentMenu == MENU.DialogueBox
end

-- Get the cursor index for a menu for menus with a volatile index location
local function getVolatileCursorIndex(address, offset, length)
    local offset = offset or 0xC0    -- This is the usual offset, for whatever reason
    local length = length or 2  -- Usually reading 2 bytes is enough
    local cursorPtr = memoryrange.readbytesUnsigned(address, 4) + offset
    return memoryrange.readbytesSigned(cursorPtr, length)
end
-- The page index, if applicable, is usually a 4-byte signed integer
-- near the relative cursor index
local function getVolatilePageIndex(address)
    return getVolatileCursorIndex(address, 0xCC, 4)
end

-- Get the cursor index for the current menu (0-indexed)
function menuinfo.getMenuCursorIndex()
    local currentMenu = menuinfo.getMenu()

    -- Moves menu is a weird outlier
    if currentMenu == MENU.Moves then
        return memory.readwordsigned(0x020AFE7E)
    end

    local ptr = volatileCursorInfo[currentMenu]
    -- If interacting with wonder tile/trap underfoot, the menu code is the same as
    -- for stairs, but the double pointer to the cursor index is located elsewhere.
    -- Luckily there's a different address we can use to distinguish these cases.
    if currentMenu == MENU.Stairs and memoryrange.readbytesSigned(0x020B3490, 4) == 1040 then
        -- Location is the same as other Ground menus
        ptr = volatileCursorInfo[MENU.Ground]
    end

    if ptr then
        return getVolatileCursorIndex(ptr)
    end

    -- Unknown menu or has no associated index
    error('Menu "' .. menuinfo.getMenuName() .. '" has no cursor index')
end

-- Get the page index for the current menu (if applicable) (0-indexed)
function menuinfo.getMenuPageIndex()
    local currentMenu = menuinfo.getMenu()

    -- These are the only menus that you should ask for a page index on
    if currentMenu == MENU.Bag or currentMenu == MENU.IQ then
        return getVolatilePageIndex(volatileCursorInfo[currentMenu])
    end

    -- Unknown menu or has no associated page index
    error('Menu "' .. menuinfo.getMenuName() .. '" has no page index')
end

return menuinfo