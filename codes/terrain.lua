require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for terrain IDs
codes.TERRAIN, codes.TERRAIN_NAMES = enum.register({
    'Wall',
    'Normal',
    'WaterOrLava',  -- Seem to share code; the actual terrain it represents varies by dungeon
    'Chasm',
}, 0, 'terrain')