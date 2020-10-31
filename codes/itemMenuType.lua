require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for item "menu types" (what menu options are available for a given item)
codes.ITEM_MENU_TYPE, codes.ITEM_MENU_TYPE_NAMES = enum.register({
    'UsableWithTarget',
    'Orb',
    'ThrowingItem',
    'HeldItem',
}, 1, 'menu type')