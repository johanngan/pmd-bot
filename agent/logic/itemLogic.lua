-- Helpers for item-related logic

require 'codes.color'
require 'codes.item'
require 'codes.itemSprite'

local itemLogic = {}

-- Resolves an item's name based on available info
itemLogic.DEFAULT_ITEM_NAME = 'Item'

function itemLogic.resolveItemName(item)
    if item.itemType then
        return codes.ITEM_NAMES[item.itemType]
    elseif item.sprite.type then
        -- The actual item type isn't known, so describe the sprite instead
        return codes.COLOR_NAMES[item.sprite.color] .. ' ' ..
            codes.ITEM_SPRITE_NAMES[item.sprite.type]
    end
    -- The item hasn't even been seen
    return itemLogic.DEFAULT_ITEM_NAME
end

return itemLogic