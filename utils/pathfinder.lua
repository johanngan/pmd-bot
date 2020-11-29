-- Interfaces between this application and the Jumper package

require 'math'
require 'table'

require 'utils.containers'
require 'utils.copy'
require 'utils.mathutils'
require 'codes.terrain'
require 'codes.direction'
local Grid = require 'Jumper.jumper.grid'
local Pathfinder = require 'Jumper.jumper.pathfinder'

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

local function cornerCuttable(terrain)
    return terrain == codes.TERRAIN.Normal
        or terrain == codes.TERRAIN.WaterOrLava
        or terrain == codes.TERRAIN.Chasm
end

-- Given a grid map (from layoutToMap()), find a path.
-- Provide a "walkable" terrain code or function of the form:
--     walkable(terrain) -> true/false
-- to specify which types of terrain are walkable.
-- Optionally a "cuttable" parameter, similar to walkable, but specifying which types
-- of terrain are corner cuttable. Uses the default cornerCuttable if none is provided
-- Return the path as a list of (x, y) pairs, or nil if the pathfinding failed
local function getPathFromMap(map, startx, starty, endx, endy, walkable, cuttable)
    local cuttable = cuttable or cornerCuttable
    local finder = Pathfinder(Grid(map), 'ASTAR', walkable, cuttable)
    finder:setTunnelling(false)
    local path = finder:getPath(startx, starty, endx, endy)

    if path then
        return pathToList(path)
    end
    return nil
end

local AVOID_CODE = -1   -- Mock terrain code for corner-cuttable position to avoid
local AVOID_CODE_HARD = -2  -- Mock terrain code for non-corner-cuttable position to avoid
-- Given a layout object (from state.dungeon.layout), find a path.
-- Optionally provide a "walkable" terrain code or function of the form:
--     walkable(terrain) -> true/false
-- to specify which types of terrain are walkable. Defaults to just normal terrain
-- Optionally provide a list of (x, y) pairs that must be avoided, and ones to avoid
-- if possible. If avoiding the latter isn't possible, the returned path may not
-- respect the wish.
-- Return the path as a list of (x, y) pairs, or nil if the pathfinding failed
function pathfinder.getPath(layout, startx, starty, endx, endy,
    walkable, mustAvoid, avoidIfPossible)
    local walkable = walkable or codes.TERRAIN.Normal
    -- Wrap walkable in a function for consistent calling
    local walkableFn = type(walkable) == 'function' and walkable or
        function(terrain) return terrain == walkable end
    local function walkFn(terrain)
        return walkableFn(terrain)
            and terrain ~= AVOID_CODE
            and terrain ~= AVOID_CODE_HARD
    end
    local function cutFn(terrain) return cornerCuttable(terrain) or terrain == AVOID_CODE end

    -- Replace the grid spaces that MUST be avoided with the special avoid codes
    local baseTerrainMap = layoutToMap(layout)
    if mustAvoid and #mustAvoid > 0 then
        for _, avoid in ipairs(mustAvoid) do
            -- Could use either cornerCuttable or cutFn here; it should make no difference
            -- since baseTerrainMap shouldn't have any avoid codes yet
            local origCuttable = cutFn(baseTerrainMap[avoid[2]][avoid[1]])
            -- If the original terrain is corner-cuttable, use the corner-cuttable avoid code,
            -- otherwise use the hard (non-corner-cuttable) avoid code
            baseTerrainMap[avoid[2]][avoid[1]] = origCuttable and AVOID_CODE or AVOID_CODE_HARD
        end
    end

    if avoidIfPossible and #avoidIfPossible > 0 then
        -- Replace the specific grid spaces that would be nice to avoid with the
        -- special avoid codes
        local terrainMap = copy.deepcopySimple(baseTerrainMap)
        for _, avoid in ipairs(avoidIfPossible) do
            -- Need to use cutFn here since terrainMap might be starting with some avoid
            -- codes already
            local origCuttable = cutFn(terrainMap[avoid[2]][avoid[1]])
            terrainMap[avoid[2]][avoid[1]] = origCuttable and AVOID_CODE or AVOID_CODE_HARD
        end

        local path = getPathFromMap(terrainMap, startx, starty, endx, endy, walkFn, cutFn)
        if path then
            return path
        end
        -- If that failed, forget about the optional avoids and do pathfinding without them
    end

    return getPathFromMap(baseTerrainMap, startx, starty, endx, endy, walkFn, cutFn)
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
-- Returns nil if there's no clean direction.
function pathfinder.getDirection(dx, dy)
    -- Normalize by |dx| if possible, otherwise normalize by |dy|
    if dx ~= 0 then
        dy = dy / math.abs(dx)
        dx = mathutils.sign(dx)
    else
        dy = mathutils.sign(dy)
    end
    return dirMap[dx] and dirMap[dx][dy]
end

local dirMapInv = {}
for dx, dxList in pairs(dirMap) do
    for dy, dir in pairs(dxList) do
        dirMapInv[dir] = {dx, dy}
    end
end
-- A sort of inverse of getDirection. Returns dx, dy for a given direction
function pathfinder.resolveDirection(dir)
    return unpack(dirMapInv[dir])
end

-- Given a path as a list of (x, y) coordinates, return a list of moves that
-- consist of start (xy pair), direction (DIRECTION enum), and destination (xy pair)
-- fields
function pathfinder.getMoves(pathlist)
    local movelist = {}
    local endPos = pathlist[1]
    for i=2,#pathlist do
        local startPos = endPos
        endPos = pathlist[i]
        local dx, dy = endPos[1]-startPos[1], endPos[2]-startPos[2]
        table.insert(movelist,
            {start=startPos, direction=pathfinder.getDirection(dx, dy), dest=endPos}
        )
    end
    return movelist
end

-- Cardinal directions first
local DIRECTION_LIST = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}, {1, 1}, {1, -1}, {-1, -1}, {-1, 1}}
-- Perform a breadth-first search from a starting position until a tile
-- is found that does not satisfy validTile(tile). If an invalid tile is
-- found, return the last valid tile position, and the path to it.
-- Otherwise, return nil for both.
function pathfinder.exploreLayout(layout, startx, starty, validTile, walkable)
    -- By default, a valid tile is one that has a known terrain type
    local validTile = validTile or function(tile) return tile.terrain ~= nil end

    local walkable = walkable or codes.TERRAIN.Normal
    -- Wrap a non-function walkable value in a function for consistent calling
    local walkableFn = walkable
    if type(walkable) ~= 'function' then
        walkableFn = function(terrain) return terrain == walkable end
    end

    -- Setup
    local predecessors = {} -- predecessors[y][x] == {pos={x0, y0}, pathlen=n} if processed
    for y, _ in pairs(layout) do
        predecessors[y] = {}
    end
    -- Inject the starting position
    -- tileQueue elements are structured as {pos={x, y}, tile=tile_object}
    local tileQueue = containers.Deque:new()
    tileQueue:pushBack({pos={startx, starty}, tile=layout[starty][startx]})
    predecessors[starty][startx] = {pathlen=0}  -- No predecessor tile because this is the start

    while tileQueue:length() > 0 do
        local tileQueueEntry = tileQueue:popFront()
        local x, y = tileQueueEntry.pos[1], tileQueueEntry.pos[2]
        -- Go through neighbors
        for _, dr in ipairs(DIRECTION_LIST) do
            local dx, dy = dr[1], dr[2]
            -- Check that the position is in the layout and hasn't been processed already
            if layout[y+dy] and layout[y+dy][x+dx] and not predecessors[y+dy][x+dx] then
                local nbr = layout[y+dy][x+dx]
                local nbrTerrain = nbr.terrain
                -- If the neighbor is invalid, pretend it were walkable. We're not quite
                -- done yet, since we might still be able to rule the neighbor out as
                -- unreachable if this is a diagonal neighbor and we know the corners
                -- aren't cuttable.
                local invalid = not validTile(nbr)
                if invalid then
                    nbrTerrain = codes.TERRAIN.Normal
                end
                -- Check that the neighbor is valid and walkable
                if nbrTerrain and walkableFn(nbrTerrain) then
                    -- If the direction is not cardinal, make sure the corners are cuttable
                    -- Since we check cardinal directions first, we're guaranteed to know
                    -- the terrain at the "corners"
                    if dx == 0 or dy == 0 or (
                        layout[y+dy][x] and cornerCuttable(layout[y+dy][x].terrain) and
                        layout[y] and layout[y][x+dx] and cornerCuttable(layout[y][x+dx].terrain)
                    ) then
                        -- If the tile was invalid, then we're done
                        if invalid then
                            -- Trace the path back to the starting position. Include the starting
                            -- and ending positions to be consistent with the Jumper API
                            local path = {}
                            local parent = {x, y}
                            for i=predecessors[y][x].pathlen+1,1,-1 do
                                path[i] = parent
                                parent = predecessors[parent[2]][parent[1]].pos
                            end
                            return {x, y}, path
                        end

                        -- Otherwise, add the neighbor tile to the queue and keep going
                        tileQueue:pushBack({pos={x+dx, y+dy}, tile=nbr})
                        -- Record the predecessor to avoid redundant processing
                        predecessors[y+dy][x+dx] = {
                            pos={x, y},
                            pathlen=predecessors[y][x].pathlen + 1
                        }
                    end
                end
            end
        end
    end
    return nil, nil -- All tiles reachable tiles were valid
end

-- Utility function: compare positions {x1, y1} and {x2, y2}
function pathfinder.comparePositions(pos1, pos2)
    return pos1[1] == pos2[1] and pos1[2] == pos2[2]
end

-- Utility function: check if a path contains a position {x, y}
function pathfinder.pathContainsPosition(path, pos)
    for _, step in ipairs(path) do
        if pathfinder.comparePositions(step, pos) then
            return true
        end
    end
    return false
end

-- Utility function: check if a path contains at least one of a list of positions
function pathfinder.pathIntersects(path, posList)
    for _, pos in ipairs(posList) do
        if pathfinder.pathContainsPosition(path, pos) then
            return true
        end
    end
    return false
end

-- Utility function: calculate the step-distance between two points
function pathfinder.stepDistance(pos1, pos2)
    return math.max(math.abs(pos1[1] - pos2[1]), math.abs(pos1[2] - pos2[2]))
end

return pathfinder