require 'utils.enum'
require 'codes.item'

if codes == nil then
    codes = {}
end

-- Enum for colors.
-- The set of colors was chosen to be able to uniquely identify different
-- color palettes within each item sprite type while still being loosely
-- correct, and do not reflect the actual color palette IDs in the internal
-- item_p.bin file.
codes.COLOR, codes.COLOR_NAMES = enum.register({
    'Red',
    'Brown',
    'Orange',
    'Gold',
    'Yellow',
    'Lime',
    'Green',
    'DarkGreen',
    'MintGreen',
    'Cyan',
    'LightBlue',
    'Blue',
    'DarkBlue',
    'Lavender',
    'Indigo',
    'Purple',
    'Magenta',
    'HotPink',
    'Pink',
    'Black',
    'Gray',
    'Silver',
    'LightGray',
    'White',
}, 1, 'color')