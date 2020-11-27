require 'table'

require 'codes.item'
require 'codes.itemCategory'

require 'mechanics.LookupTable'

if mechanics == nil then
    mechanics = {}
end

mechanics.item = LookupTable:new('mechanics/data/item_data.csv')

-- Generate a lightweight, in-memory reference for stateinfo and smartactions
if mechanics.item.sprites == nil or mechanics.item.menuTypes == nil then
    mechanics.item.sprites = {}
    mechanics.item.menuTypes = {}

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
        mechanics.item.menuTypes[id] = fullItemList[i].menuType
    end
    mechanics.item:flushCache()
end

-- Checks if an item is used via eating/ingesting
function mechanics.item.isIngested(itemCode)
    local category = mechanics.item(itemCode).category
    return category == codes.ITEM_CATEGORY.EdibleWithEffect
        or category == codes.ITEM_CATEGORY.Food
end

-- Subsets of certain classes of items for convenience
mechanics.item.lists = {}

-- Healing items mapped to their HP restoration values
mechanics.item.lists.healing = {
    [codes.ITEM.SitrusBerry] = 100,
    [codes.ITEM.OranBerry] = 100,
}
-- Food items mapped to their belly restoration values
-- This doesn't include things like seeds whose primary purpose
-- isn't belly restoration
mechanics.item.lists.food = {
    [codes.ITEM.GoldenApple] = 200, -- Full restoration, but max belly can't go above 200
    [codes.ITEM.HugeApple] = 200,   -- Full restoration, but max belly can't go above 200
    [codes.ITEM.BigApple] = 100,
    [codes.ITEM.Unnamed0x071] = 55,
    [codes.ITEM.WonderGummi] = 50,
    [codes.ITEM.Apple] = 50,
    [codes.ITEM.GrimyFood] = 30,
    -- These are the "normal" restoration value for Gummis.
    -- If the type matches, the Gummi will restore 30 belly
    -- If the type somewhat matches (super-effective), the Gummi will restore 20 belly
    -- If the type doesn't match (not very effective), the Gummi will restore 10 belly
    -- If the type really doesn't match (little effect), the Gummi will restore 5 belly
    [codes.ITEM.WhiteGummi] = 15,
    [codes.ITEM.RedGummi] = 15,
    [codes.ITEM.BlueGummi] = 15,
    [codes.ITEM.GrassGummi] = 15,
    [codes.ITEM.YellowGummi] = 15,
    [codes.ITEM.ClearGummi] = 15,
    [codes.ITEM.OrangeGummi] = 15,
    [codes.ITEM.PinkGummi] = 15,
    [codes.ITEM.BrownGummi] = 15,
    [codes.ITEM.SkyGummi] = 15,
    [codes.ITEM.GoldGummi] = 15,
    [codes.ITEM.GreenGummi] = 15,
    [codes.ITEM.GrayGummi] = 15,
    [codes.ITEM.PurpleGummi] = 15,
    [codes.ITEM.RoyalGummi] = 15,
    [codes.ITEM.BlackGummi] = 15,
    [codes.ITEM.SilverGummi] = 15,
    [codes.ITEM.Unnamed0x072] = 15,
    [codes.ITEM.Gravelyrock] = 10,
    [codes.ITEM.Unnamed0x08A] = 5,
}