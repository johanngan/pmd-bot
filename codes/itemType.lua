require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for item type IDs, according to the internal item_p.bin file.
-- The actual names aren't in the files and were chosen manually.
--
-- Anything tagged with "Unused" is an index never referenced in the
-- internal item_p.bin file, and is included here as a placeholder.
codes.ITEM_TYPE, codes.ITEM_TYPE_NAMES = enum.register({
    'ThrowingSpike',
    'ThrowingStone',
    'EdibleWithEffect',   -- Edible items with effects, like Seeds and Vitamins
    'Food', -- Belly-restoring items like Apples and Gummis
    'HeldItem', -- E.g., scarves
    'TM',
    'Money',
    'Unused0x07',
    'Other',    -- Miscellaneous items like evolution items, tickets, etc.
    'Orb',
    'Chest',    -- Corresponds to the "Chest" sprite; things that look like the Link Box. NOT Treasure Boxes and such.
    'UsedTM',
    'TreasureBox1', -- Maybe each category has different awards? 
    'TreasureBox2',
    'TreasureBox3',
    'ExclusiveItem'
}, 0, 'item type')