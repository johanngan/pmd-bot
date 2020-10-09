require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for Pokemon gender IDs, according to the internal monster.md file
codes.GENDER, codes.GENDER_NAMES = enum.register({
    'None', -- Only used for invalid gender variants. Genderless has its own code.
    'Male',
    'Female',
    'Genderless',
}, 0, 'gender')