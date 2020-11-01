require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for move range types.
-- The order does not resemble the order used internally in waza_p.bin,
-- and some codes here don't exist internally.
-- Ranges are loosely ordered from "smallest" to "largest", as much as that
-- has a well-defined meaning.
codes.MOVE_RANGE, codes.MOVE_RANGE_NAMES = enum.register({
    'Special',      -- For unusual moves
    'User',         -- Affects the user itself
    'Underfoot',    -- The tile underneath the user
    'Front',        -- Directly in front, doesn't cut corners
    'FrontWithCornerCutting',   -- Directly in front, and cuts corners
    'FrontSpread',  -- Wide Slash. This also cuts corners
    'Nearby',   -- All tiles directly around the user
    'Front2',   -- 2 tiles ahead. This also cuts corners
    'Nearby2',  -- Within 2 spaces around the user
    'Front10',  -- 10 tiles ahead. This also cuts corners
    'Room',     -- Entire room
    'Floor',    -- Entire floor
}, 0, 'range')