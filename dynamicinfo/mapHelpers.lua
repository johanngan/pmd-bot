-- Helpers for reading map/layout info from memory

require 'table'
require 'utils.memoryrange'

local mapHelpers = {}

-- Dimensions of the floor grid
mapHelpers.NROWS = 30
mapHelpers.NCOLS = 54

-- Parse a range of bytes into a list of tile objects
local TILE_BYTES = 20   -- Each tile is represented by 20 bytes
function mapHelpers.parseTiles(bytes)
    local tiles = {}
    for start=1,#bytes,TILE_BYTES do
        local tile = {}
        -- 0x00: a bitfield
        tile.terrain = AND(bytes[start], 0x03)
        -- Room tiles next to a corridor, as well as branching points in a corridor
        -- Only applies to natural junctions, not ones made by Absolute Mover
        tile.isJunction = AND(bytes[start], 0x08) ~= 0
        tile.inShop = AND(bytes[start], 0x20) ~= 0
        tile.inMonsterHouse = AND(bytes[start], 0x40) ~= 0
        -- 0x01: stairs flag (also includes warp zones)
        tile.isStairs = AND(bytes[start + 0x01], 0x02) ~= 0
        -- 0x02, bit 0: map visibility flag
        tile.visibleOnMap = AND(bytes[start + 0x02], 0x1) ~= 0
        -- 0x02, bit 1: visited flag
        tile.visited = AND(bytes[start + 0x02], 0x2) ~= 0
        -- 0x07: room index; will be -1 if in a hall
        tile.room = memoryrange.unsignedToSigned(bytes[start + 0x07], 1)

        table.insert(tiles, tile)
    end
    return tiles
end

-- Calculates the starting address of a row at some y-position (starting at x=1)
local UPPER_LEFT_CORNER = 0x021BE288    -- at (x, y) = (1, 1)
local function calcRowStartAddr(y)
    return UPPER_LEFT_CORNER + (y-1)*(mapHelpers.NCOLS+2)*TILE_BYTES
end

-- Read the row of tiles at a given y value (starts at 1)
function mapHelpers.readTileRow(y)
    -- Offset by 2 extra tiles each row because there's a rectangular boundary
    -- of tiles around the dungeon's "interactable tiles". These tiles at x = {0, 55}
    -- and y = {0, 31} are always impassable, so there's no point in reading them
    return mapHelpers.parseTiles(memory.readbyterange(
        calcRowStartAddr(y), mapHelpers.NCOLS*TILE_BYTES))
end

-- Update just the visibility of a tile, without touching other stuff.
-- Mutates a tile object given the starting address of its data block.
function mapHelpers.refreshTileVisibility(tile, addr)
    local bitfield = memory.readbyteunsigned(addr + 0x02)
    tile.visibleOnMap = AND(bitfield, 0x1) ~= 0
    tile.visited = AND(bitfield, 0x2) ~= 0
end

-- Refresh the visibility of a row of tiles at a given y-position
function mapHelpers.refreshTileRowVisibility(row, y)
    local rowStartAddr = calcRowStartAddr(y)
    for x, tile in ipairs(row) do
        mapHelpers.refreshTileVisibility(tile, rowStartAddr + (x-1)*TILE_BYTES)
    end
end

-- Find the stairs in some floor layout (grid of tiles, stored row-major)
-- Might be normal stairs or hidden stairs, whichever comes up first
function mapHelpers.findStairs(layout)
    for y, row in ipairs(layout) do
        for x, tile in ipairs(row) do
            if tile.isStairs then
                return x, y
            end
        end
    end
    return nil
end

return mapHelpers