require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for item sprite IDs, according to the internal item_p.bin file.
-- The actual names aren't in the files and were chosen manually.
--
-- Anything tagged with a "2" is a second internal index for the same sprite
-- (they correspond to different color palettes), and are included for
-- completeness, but NOT used by PMD-Bot. Anything tagged with "Unused" is an
-- index never referenced in the internal item_p.bin file, and is included here
-- as a placeholder.
codes.ITEM_SPRITE, codes.ITEM_SPRITE_NAMES = enum.register({
    'ThrowingSpike',
    'ThrowingStone',
    'Berry',
    'Apple',
    'Scarf',
    'Box',
    'Coin',
    'MusicNote',
    'TM',
    'Unused0x09',
    'Chest',
    'Unused0x0B',
    'Drink',
    'Glasses',
    'Seed',
    'Orb',
    'Key',
    'Gummi',
    'Pyramid',
    'TreasureBox',
    'PatternedScale',
    'Unused0x15',
    'Unused0x16',
    'Unused0x17',
    'TreasureBox2', -- Not used by PMD-Bot
    'SmoothScale',
    'FuzzyTail',
    'Tag',
    'Charm',
    'Shard',
    'Gummi2',   -- Not used by PMD-Bot
    'Crown',
    'Fang',
    'Hair',
    'Dust',
    'Flask',
    'SmoothTail',
    'ExclusiveScarf',
    'Horn',
    'Claw',
    'Silk',
    'Leaf',
    'Heart',
    'Hat',
    'Wing',
    'Unused0x2D',
    'Slab',
    'Brooch',
    'Unused0x30',
    'Gem',
    'Tooth',
    'Flower',
    'ExclusiveBow',
    'Bow',
    'Ring',
    'EvolutionStone',
    'Silk2',    -- Not used by PMD-Bot
    'Cape',
    'Belt',
    'Thorn',
    'Mask',
    'EvolutionRock',
    'ManaphyEgg',
}, 0, 'sprite')