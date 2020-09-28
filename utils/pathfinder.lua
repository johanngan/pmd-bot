-- Interfaces between this application and the Jumper package

require 'math'
require 'table'

require 'codes.terrain'
require 'codes.direction'
local Grid = require 'jumper.grid'
local Pathfinder = require 'jumper.pathfinder'

pathfinder = {}

-- Convert a layout object to the map format used by Jumper,
-- with each cell containing the terrain type
local function layoutToMap(layout)
    local map = {}
    for _, layoutRow in ipairs(layout) do
        local mapRow = {}
        for _, tile in ipairs(layoutRow) do
            -- If the terrain is unknown (nil), treat it as a wall
            table.insert(mapRow, tile.terrain or codes.TERRAIN.Wall)
        end
        table.insert(map, mapRow)
    end
    return map
end

-- Convert a path object output by Jumper to a list of (x, y) pairs
local function pathToList(path)
    local pathlist = {}
    for node, _ in path:iter() do
        table.insert(pathlist, {node:getX(), node:getY()})
    end
    return pathlist
end

-- Given a layout object (from state.dungeon.layout), find a path.
-- Optionally provide a "walkable" terrain code or function of the form:
--     walkable(terrain) -> true/false
-- to specify which types of terrain are walkable. Defaults to just normal terrain
-- Return the path as a list of (x, y) pairs, or nil if the pathfinding failed
function pathfinder.getPath(layout, startx, starty, endx, endy, walkable)
    local grid = Grid(layoutToMap(layout))
    local walkable = walkable or codes.TERRAIN.Normal
    local cornerCuttable = function(terrain)
        return terrain == codes.TERRAIN.Normal
            or terrain == codes.TERRAIN.WaterOrLava
            or terrain == codes.TERRAIN.Chasm
    end
    local finder = Pathfinder(grid, 'ASTAR', walkable, cornerCuttable)
    finder:setTunnelling(false)
    local path = finder:getPath(startx, starty, endx, endy)
    if path then
        return pathToList(path)
    end
    return nil
end

-- The "separation vector" direction for some (dx, dy) between two adjacent tiles
local dirMap = {
    [-1] = {
        [-1] = codes.DIRECTION.UpLeft,
        [0] = codes.DIRECTION.Left,
        [1] = codes.DIRECTION.DownLeft,
    },
    [0] = {
        [-1] = codes.DIRECTION.Up,
        [1] = codes.DIRECTION.Down,
    },
    [1] = {
        [-1] = codes.DIRECTION.UpRight,
        [0] = codes.DIRECTION.Right,
        [1] = codes.DIRECTION.DownRight,
    },
}
function pathfinder.getDirection(dx, dy)
    return dirMap[dx][dy]
end

-- Given a path as a list of (x, y) coordinates, return a list of moves that
-- consist of start (xy pair) and direction (DIRECTION enum) fields
function pathfinder.getMoves(pathlist)
    local movelist = {}
    local endPos = pathlist[1]
    for i=2,#pathlist do
        local startPos = endPos
        endPos = pathlist[i]
        local dx, dy = endPos[1]-startPos[1], endPos[2]-startPos[2]
        table.insert(movelist,
            {start=startPos, direction=pathfinder.getDirection(dx, dy)}
        )
    end
    return movelist
end

-- Utility function: compare positions {x1, y1} and {x2, y2}
function pathfinder.comparePositions(pos1, pos2)
    return pos1[1] == pos2[1] and pos1[2] == pos2[2]
end

-- Utility function: calculate the step-distance between two points
function pathfinder.stepDistance(pos1, pos2)
    return math.max(math.abs(pos1[1] - pos2[1]), math.abs(pos1[2] - pos2[2]))
end

return pathfinder