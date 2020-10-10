-- Utility functions for map range and visibility

local rangeutils = {}

-- Whether or not (x, y) is within (xrad, yrad) of (x0, y0)
function rangeutils.inRange(x, y, x0, y0, xrad, yrad)
    local yrad = yrad or xrad
    return math.abs(x - x0) <= xrad and math.abs(y - y0) <= yrad
end

-- Whether or not a position (x, y) is "on screen" when standing at a given position (x0, y0).
local SCREEN_X_RADIUS = 5
local SCREEN_Y_RADIUS = 4
function rangeutils.onScreen(x, y, x0, y0)
    return rangeutils.inRange(x, y, x0, y0, SCREEN_X_RADIUS, SCREEN_Y_RADIUS)
end

-- Whether or not a position (x, y) is either "on screen" when standing at a given position (x0, y0),
-- or is visible on the map.
function rangeutils.onMapOrScreen(x, y, x0, y0, layout)
    return layout[y][x].visibleOnMap or rangeutils.onScreen(x, y, x0, y0)
end

-- Whether or not a position (x, y) is either "on screen" when standing at a given position (x0, y0),
-- or has been visited before.
function rangeutils.visitedOrOnScreen(x, y, x0, y0, layout)
    return layout[y][x].visited or rangeutils.onScreen(x, y, x0, y0)
end

-- Whether or not a position (x, y) is in "room range", meaning in a room or in the
-- surrounding 1-tile boundary. Returns nil if (x0, y0) is not in a room
function rangeutils.inRoomRange(x, y, x0, y0, layout)
    local i0 = layout[y0][x0].room
    if i0 >= 0 then
        -- In a room, or in the surrounding boundary
        for _, dy in ipairs({0, 1, -1}) do
            for _, dx in ipairs({0, 1, -1}) do
                if (layout[y + dy] ~= nil and layout[y + dy][x + dx] ~= nil -- on the grid
                    and layout[y + dy][x + dx].room == i0) then
                        return true
                end
            end
        end
        return false
    end
    return nil
end

-- Whether or not a position (x, y) is "visible" when standing at a given position (x0, y0),
-- in the context of the full dungeon layout.
function rangeutils.inVisibilityRegion(x, y, x0, y0, dungeon)
    -- If there's lighting, the visibility region additionally includes anything on-screen
    if not dungeon.conditions.darkness() and rangeutils.onScreen(x, y, x0, y0) then
        return true
    end

    -- In a room, the range extends throughout the room and on the 1-tile boundary
    local roomRange = rangeutils.inRoomRange(x, y, x0, y0, dungeon.layout())
    if roomRange ~= nil then
        return roomRange
    end

    -- In a hallway
    return rangeutils.inRange(x, y, x0, y0, dungeon.visibilityRadius())
end

return rangeutils