require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for Pokemon IQ groups, according to the internal monster.md file
-- Anything tagged with "Unused" is an index never referenced in the
-- internal monster.md file, and is included here as a placeholder.
codes.IQ_GROUP, codes.IQ_GROUP_NAMES = enum.register({
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'Unused0x08',
    'Unused0x09',
    'I',
    'J',
    'Unused0x0C',
    'Unused0x0D',
    'Unused0x0E',
    'None',
}, 0, 'IQ group')