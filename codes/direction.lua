require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for directions (matches the internal direction index in-game)
codes.DIRECTION, codes.DIRECTION_NAMES = enum.register({
    'Down',
    'DownRight',
    'Right',
    'UpRight',
    'Up',
    'UpLeft',
    'Left',
    'DownLeft',
}, 0, 'direction')