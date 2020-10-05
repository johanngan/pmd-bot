require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for move target types.
-- This vaguely resembles the order used internally in waza_p.bin, but
-- not exactly, and some codes here don't exist internally.
codes.MOVE_TARGET, codes.MOVE_TARGET_NAMES = enum.register({
    'Enemies',
    'Party',
    'All',
    'User',
    'AllExceptUser',
    'Teammates',
    'Dungeon',  -- Moves that modify the dungeon itself
    'Special',  -- For unusual moves
}, 0, 'target')