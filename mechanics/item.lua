require 'table'

require 'codes.item'
require 'mechanics.LookupTable'

if mechanics == nil then
    mechanics = {}
end

mechanics.item = LookupTable:new('mechanics/data/item_data.csv')

-- Generate a lightweight, in-memory reference for stateinfo
if mechanics.item.sprites == nil then
    mechanics.item.sprites = {}

    local function sprite(itemInfo)
        return {type = itemInfo.sprite, color = itemInfo.color}
    end

    local itemCodes = {}
    for id=codes.ITEM.Nothing,codes.ITEM.Unnamed0x577 do
        table.insert(itemCodes, id)
    end

    -- Read the full table into memory, extract just the sprite info,
    -- then flush the cache to free up space again.
    local fullItemList = mechanics.item(itemCodes)
    for i, id in ipairs(itemCodes) do
        mechanics.item.sprites[id] = sprite(fullItemList[i])
    end
    mechanics.item:flushCache()
end