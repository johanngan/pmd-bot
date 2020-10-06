require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for type IDs according to internal files
codes.TYPE, codes.TYPE_NAMES = enum.register({
    'None',
    'Normal',
    'Fire',
    'Water',
    'Grass',
    'Electric',
    'Ice',
    'Fighting',
    'Poison',
    'Ground',
    'Flying',
    'Psychic',
    'Bug',
    'Rock',
    'Ghost',
    'Dragon',
    'Dark',
    'Steel',
    'Neutral',  -- This is never used for moves nor monsters, but include for completeness
}, 0, 'type')