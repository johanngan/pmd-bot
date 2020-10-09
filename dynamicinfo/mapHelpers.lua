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

-- Read the row of tiles at a given y value (starts at 1)
local UPPER_LEFT_CORNER = 0x021BE288    -- at (x, y) = (1, 1)
function mapHelpers.readTileRow(y)
    -- Offset by 2 extra tiles each row because there's a rectangular boundary
    -- of tiles around the dungeon's "interactable tiles". These tiles at x = {0, 55}
    -- and y = {0, 31} are always impassable, so there's no point in reading them
    return mapHelpers.parseTiles(memory.readbyterange(UPPER_LEFT_CORNER +
        (y-1)*(mapHelpers.NCOLS+2)*TILE_BYTES, mapHelpers.NCOLS*TILE_BYTES))
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

---- BEGIN MAP VISIBILITY HELPERS ----

-- Whether or not (x, y) is within (xrad, yrad) of (x0, y0)
local function inRange(x, y, x0, y0, xrad, yrad)
    local yrad = yrad or xrad
    return math.abs(x - x0) <= xrad and math.abs(y - y0) <= yrad
end

-- Whether or not a position (x, y) is "on screen" when standing at a given position (x0, y0).
local SCREEN_X_RADIUS = 5
local SCREEN_Y_RADIUS = 4
function mapHelpers.onScreen(x, y, x0, y0)
    return inRange(x, y, x0, y0, SCREEN_X_RADIUS, SCREEN_Y_RADIUS)
end

-- Whether or not a position (x, y) is either "on screen" when standing at a given position (x0, y0),
-- or is visible on the map.
function mapHelpers.onMapOrScreen(x, y, x0, y0, layout)
    return layout[y][x].visibleOnMap or mapHelpers.onScreen(x, y, x0, y0)
end

-- Whether or not a position (x, y) is either "on screen" when standing at a given position (x0, y0),
-- or has been visited before.
function mapHelpers.visitedOrOnScreen(x, y, x0, y0, layout)
    return layout[y][x].visited or mapHelpers.onScreen(x, y, x0, y0)
end

-- Whether or not a position (x, y) is "visible" when standing at a given position (x0, y0),
-- in the context of the full dungeon layout.
function mapHelpers.inVisibilityRegion(x, y, x0, y0, dungeon)
    -- If there's lighting, the visibility region additionally includes anything on-screen
    if not dungeon.conditions.darkness() and mapHelpers.onScreen(x, y, x0, y0) then
        return true
    end

    local layout = dungeon.layout()
    local i0 = layout[y0][x0].room
    if i0 >= 0 then
        -- In a room. Visible tiles are all those in the room, along with the surrounding boundary
        for _, dy in ipairs({0, 1, -1}) do
            for _, dx in ipairs({0, 1, -1}) do
                if (x + dx > 0 and x + dx <= mapHelpers.NCOLS and
                    y + dy > 0 and y + dy <= mapHelpers.NROWS and
                    layout[y + dy][x + dx].room == i0) then
                        return true
                end
            end
        end
        return false
    end

    -- In a hallway
    return inRange(x, y, x0, y0, dungeon.visibilityRadius())
end

---- END MAP VISIBILITY HELPERS ----

return mapHelpers