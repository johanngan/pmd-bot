require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for move damage categories.
-- These codes are used internally in waza_p.bin.
codes.MOVE_CATEGORY, codes.MOVE_CATEGORY_NAMES = enum.register({
    'Physical',
    'Special',
    'Status',
}, 0, 'category')