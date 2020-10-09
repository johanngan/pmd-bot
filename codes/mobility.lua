require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for Pokemon mobility types, according to the internal monster.md file
codes.MOBILITY, codes.MOBILITY_NAMES = enum.register({
    'Normal',       -- Just normal terrain
    'Unused0x01',   -- Never referenced in monster.md; included here as a placeholder
    'Hovering',     -- Normal, water, lava (will be burned), chasm
    'Intangible',   -- Normal, water, lava (will be burned), chasm, walls
    'Lava',         -- Normal, lava
    'Water',        -- Normal, water
}, 0, 'mobility')