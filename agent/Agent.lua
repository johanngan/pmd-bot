-- Class for deciding on what actions to take based on the current state

require 'math'
require 'table'

require 'utils.enum'
require 'utils.mathutils'
require 'utils.messages'
require 'utils.pathfinder'

require 'codes.menu'
require 'codes.species'
require 'codes.status'
require 'codes.terrain'
require 'codes.trap'
require 'codes.weather'

require 'actions.basicactions'
require 'actions.smartactions'

require 'mechanics.move'
require 'mechanics.species'
local rangeutils = require 'mechanics.rangeutils'

require 'dynamicinfo.menuinfo'

local itemLogic = require 'agent.logic.itemLogic'
local moveLogic = require 'agent.logic.moveLogic'

Agent = {}
Agent.name = 'Agent'
-- Set this to false if you want your bot to use only visible information!
Agent.omniscient = false

-- This is just boilerplate code for the class
function Agent:new(state, visible)
    obj = {}
    setmetatable(obj, self)
    self.__index = self
    self:init(state, visible)
    return obj
end

-- Pathfinding target types
local TARGET, _ = enum.register({
    'Stairs',
    'Item',
    'Explore',
})

-- This function will be called just once when the bot starts up.
function Agent:init(state, visible)
    -- If you want your bot to have a state or a memory, initialize stuff here!
    self.pathMoves = nil -- The path moves list, as returned by pathfinder.getMoves()
    self.target = {}
    self.target.pos = nil    -- The actual target position
    self.target.type = nil   -- Factored into decision-making
    self.target.name = nil   -- For message reporting
    -- Soft targets will get recomputed at the next turn. Hard targets will be seen through
    self.target.soft = nil

    -- Preload all the mechanics info for the leader's current moves into memory
    local moveIDs = {}
    for _, move in ipairs(state.player.leader().moves) do
        table.insert(moveIDs, move.moveID)
    end
    mechanics.move(moveIDs)
end

-- Checks if a position is the target position
function Agent:isTargetPos(pos)
    -- The first condition handles if both positions are nil.
    -- Otherwise, neither can be nil for the check to work.
    return (self.target.pos == pos) or (
        self.target.pos ~= nil and pos ~= nil
        and pathfinder.comparePositions(pos, self.target.pos)
    )
end

-- Set the target, with an optional type and name
function Agent:setTarget(targetPos, targetType, targetName, soft)
    if not self:isTargetPos(targetPos) then
        self.target.pos = targetPos
        self.pathMoves = nil -- Need to calculate a new path
    end
    self.target.type = targetType
    self.target.name = targetName
    self.target.soft = soft
end

-- Compute the path to the target from some origin if necessary.
-- The resulting path is stored in the pathMoves property.
function Agent:findTargetPath(x0, y0, layout, mustAvoid, avoidIfPossible)
    local mustAvoid = mustAvoid or {}
    if not self.pathMoves or #self.pathMoves == 0 or
        not pathfinder.comparePositions({x0, y0}, self.pathMoves[1].start) or
        -- Note: the "path" argument of pathContainsPosition doesn't have to be
        -- continuous; mustAvoid is a list of (x, y) pairs so is still a valid "path"
        pathfinder.pathContainsPosition(mustAvoid, self.pathMoves[1].dest) then
        -- Path is nonexistent, obsolete, or invalid. Find a new path
        -- Omit the target tile itself from the must avoid list
        local mustAvoidOmitTarget = {}
        for _, avoid in ipairs(mustAvoid) do
            if not pathfinder.comparePositions(avoid, self.target.pos) then
                table.insert(mustAvoidOmitTarget, avoid)
            end
        end
        local path = pathfinder.getPath(layout, x0, y0, self.target.pos[1], self.target.pos[2],
            nil, mustAvoidOmitTarget, avoidIfPossible)
        if not path then
            -- "must avoid" was a lie...as a last ditch effort, drop most of
            -- the must avoid requirement (unless it triggered the path recomputation; keep that).
            -- If that still fails, something has gone wrong
            local mustAvoidMinimal = nil
            if self.pathMoves and
                pathfinder.pathContainsPosition(mustAvoid, self.pathMoves[1].dest) then
                mustAvoidMinimal = {self.pathMoves[1].dest}
            end
            path = assert(
                pathfinder.getPath(layout, x0, y0, self.target.pos[1], self.target.pos[2],
                    nil, mustAvoidMinimal, avoidIfPossible),
                'Something went wrong. Unable to find path.'
            )
        end
        self.pathMoves = pathfinder.getMoves(path)
    end
end

-- Checks if a monster has some status. Returns nil if uncertain
local function hasStatus(monster, statusType)
    if monster.statuses == nil then return nil end
    for _, status in ipairs(monster.statuses) do
        if status.statusType == statusType then
            return true
        end
    end
    return false
end

-- Scan a list of entities and check if any are in visibility range and within
-- some path length. Return a list of the closest ones and the paths to them, with
-- the form {entity, path} for each item.
-- Optionally specify a checkValidity(entity) function that only returns an entity
-- if it satisfies the given validity check, and a walkableWithEntity(terrain, entity) function
-- for the pathfinder
local function scanNearbyEntities(entities, x0, y0, dungeon,
    checkValidity, walkableWithEntity, avoidIfPossible, maxSteps)
    local maxSteps = maxSteps or 10
    local nearestEntities = {}
    for _, entity in ipairs(entities) do
        if rangeutils.inVisibilityRegion(entity.xPosition, entity.yPosition, x0, y0, dungeon)
            and (checkValidity == nil or checkValidity(entity)) then
            -- Wrap walkableWithEntity so that the pathfinder can understand it
            local walkable = walkableWithEntity
                and function(terrain) return walkableWithEntity(terrain, entity) end
                or nil
            -- Search for a path to the entity
            local path = pathfinder.getPath(dungeon.layout(),
                x0, y0, entity.xPosition, entity.yPosition, walkable, nil, avoidIfPossible)
            -- maxSteps + 1 because path includes the starting point
            if path and #path <= maxSteps + 1 then
                if #nearestEntities > 0 and #path < #(nearestEntities[1].path) then
                    nearestEntities = {}
                end
                if #nearestEntities == 0 or #path == #(nearestEntities[1].path) then
                    table.insert(nearestEntities, {entity=entity, path=path})
                end
            end
        end
    end
    return nearestEntities
end

-- Decide how to attack an enemy given the circumstances, and perform the action.
-- Returns true if the attack was successfully used, or false if not.
-- If you're using different Pokemon, it might be sufficient just to rewrite this
-- method, and leave the main dungeon-crawling logic as is.
function Agent:attackEnemy(enemy, leader, availableInfo)
    -- Wrap in an Agent method in case we want to use internal state in the future
    return moveLogic.attackEnemyWithBestMove(enemy, leader, availableInfo)
end

-- Perform some actions based on the current state of the dungeon (and the bot's own state)
-- This is a very simple sample strategy. Change it to fit your botting needs.
function Agent:act(state, visible)
    -- Use only as much information as is available to the agent
    local availableInfo = self.omniscient and state or visible

    -- If in a Yes/No prompt, try to exit
    if menuinfo.getMenu() == codes.MENU.YesNo then
        basicactions.selectYesNo(1, true)
        return
    end

    -- If trying to learn a new move, don't
    if menuinfo.getMenu() == codes.MENU.NewMove then
        basicactions.selectMoveToForget(4, true)
        return
    end

    local leader = availableInfo.player.leader()

    -- Health is critically low; try to heal.
    -- "Critically low" means less than 25% HP (add 1 to numerator/denominator)
    --      (this roughly coincides with when the UI starts flashing)
    local threshold = 0.25 * (leader.stats.maxHP + 1) - 1
    -- ceil(threshold) - 1 because the parameter is treated as inclusive in this function
    if smartactions.healIfLowHP(availableInfo, leader.stats.HP,
        leader.stats.maxHP, math.ceil(threshold) - 1, true, true) then
        return
    end

    -- Check for good offensive AOE moves (without friendly fire if there are teammates)
    -- Also check how many still have PP
    local AOEMoveIdxs, nAOEMovesWithPP = moveLogic.getOffensiveAOEMoves(
        leader.moves, #availableInfo.dungeon.entities.team() > 1)

    -- If the leader has good AOE moves but all of them are out of PP, try to use a
    -- Max Elixir.
    if #AOEMoveIdxs > 0 and nAOEMovesWithPP == 0 then
        if smartactions.useMaxElixirIfPossible(availableInfo, true) then
            return
        end
    end

    -- If there are 3 or more enemies in range and the leader has a good offensive AOE
    -- move, use the best one available.
    for _, idx in ipairs(AOEMoveIdxs) do
        -- Count how many enemies are in range of this move
        local move = leader.moves[idx]
        local nEnemiesInRange = 0
        for _, enemy in ipairs(availableInfo.dungeon.entities.enemies()) do
            if not enemy.isShopkeeper and not enemy.isAlly and
                mechanics.move.inRange(move.moveID, enemy.xPosition, enemy.yPosition,
                    leader.xPosition, leader.yPosition, availableInfo.dungeon.layout()) then
                -- Enemy is within attack range
                nEnemiesInRange = nEnemiesInRange + 1
            end
        end
        -- Use the move if possible
        -- Subtract 1 to convert from 1-indexing to 0-indexing
        if nEnemiesInRange >= 3 and
            smartactions.useMoveIfPossible(idx-1, leader.moves, true) then
            return
        end
    end

    -- For certain logic, we need to consider enemies, which are impassable
    -- and MUST be avoided.
    local mustAvoid = {}
    for _, enemy in ipairs(availableInfo.dungeon.entities.enemies()) do
        table.insert(mustAvoid, {enemy.xPosition, enemy.yPosition})
    end
    -- Positions that we know have traps and want to avoid
    local avoidIfPossible = {}
    for _, trap in ipairs(availableInfo.dungeon.entities.traps()) do
        if trap.trapType ~= codes.TRAP.WonderTile and trap.isTriggerableByTeam then
            table.insert(avoidIfPossible, {trap.xPosition, trap.yPosition})
        end
    end

    -- Select a pathfinding target
    if self.target.type == TARGET.Item then
        -- If the old target was an item, make sure it (or at least, some item)
        -- is still there
        local itemIsGone = true
        for _, item in ipairs(availableInfo.dungeon.entities.items()) do
            if self:isTargetPos({item.xPosition, item.yPosition}) then
                itemIsGone = false
            end
        end
        if itemIsGone then self:setTarget(nil) end
    end
    if self:isTargetPos({leader.xPosition, leader.yPosition}) then
        -- If the target was an item (if we get in here, the item must still be there),
        -- Pick it up or swap it out if it makes sense to
        if self.target.type == TARGET.Item and
            not smartactions.pickUpItemIfPossible(-1, availableInfo, true) then
            if itemLogic.swapItemUnderfoot(availableInfo) then
                -- Swapping uses up the turn
                return
            end
        end
        -- The target has been reached, so clear it
        self:setTarget(nil)
    end

    -- If there is no target, or the target is a soft one, recompute a target
    if not self.target.pos or self.target.soft then
        local explore = true    -- Defaults to true unless another target is found
        -- When checking for items, don't touch Kecleon's stuff, and only pay attention to
        -- items either if the bag has room, or they're worth swapping into the bag
        local nearestItems = scanNearbyEntities(availableInfo.dungeon.entities.items(),
            leader.xPosition, leader.yPosition, availableInfo.dungeon,
            function(item)
                return itemLogic.shouldPickUp(item, availableInfo.player.bag(),
                    availableInfo.player.bagCapacity())
            end,
            nil, avoidIfPossible)
        if #nearestItems > 0 then
            -- Just pick the first item found if there are multiple equally close ones
            local nearestItem, path = nearestItems[1].entity, nearestItems[1].path

            -- A desirable item is nearby, so target that.
            -- If we haven't seen the item yet, we'll want to reload when the sprite
            -- becomes visible.
            local targetName = itemLogic.resolveItemName(nearestItem)
            self:setTarget({nearestItem.xPosition, nearestItem.yPosition},
                TARGET.Item, targetName, targetName == itemLogic.DEFAULT_ITEM_NAME)
            -- Might as well save the path we just calculated
            self.pathMoves = pathfinder.getMoves(path)
            explore = false
        elseif availableInfo.dungeon.stairs() then
            -- The location of the stairs is known. Target it if it's reachable with
            -- current layout information
            local x, y = availableInfo.dungeon.stairs()
            local path = pathfinder.getPath(availableInfo.dungeon.layout(),
                leader.xPosition, leader.yPosition, x, y, nil, nil, avoidIfPossible)
            if path then
                -- Set a soft target; if an item becomes visible, we'll want to target that instead
                self:setTarget({availableInfo.dungeon.stairs()}, TARGET.Stairs, 'Stairs', true)
                -- Might as well save the path we just calculated
                self.pathMoves = pathfinder.getMoves(path)
                explore = false
            end
        end
        -- If explore is still true by this point, there are two possibilities:
        --  1. No items or stairs are visible
        --  2. Stairs are visible but unreachable
        if explore then
            -- Target the nearest reachable tile that's unknown
            -- If the target is already an explore target, look for new tiles
            -- using the existing target position as the starting point. This
            -- encourages more natural exploration that follows through with an
            -- exploration target, rather capriciously doubling back (which can
            -- happen if you always start searching from the leader's position)
            local x0, y0 = leader.xPosition, leader.yPosition
            if self.target.type == TARGET.Explore then
                x0, y0 = self.target.pos[1], self.target.pos[2]
            end
            local pos, path = pathfinder.exploreLayout(availableInfo.dungeon.layout(), x0, y0)
            if pos then
                -- Explore targets are always soft, and can be changed at a moment's notice
                self:setTarget(pos, TARGET.Explore, nil, true)
                -- Don't save the path; we want to recompute it again to factor in traps
                -- and enemies, which exploreLayout() doesn't do.
            end
        end
        -- If the target is off-screen, force it to be soft
        if self.target.pos and rangeutils.onScreen(self.target.pos[1], self.target.pos[2],
            leader.xPosition, leader.yPosition) then
            self.target.soft = true
        end
    end
    -- The target should not be nil by this point
    assert(self.target.pos, 'Could not find target.')

    -- Use different decision-making depending on whether there's an enemy in the vicinity.
    -- Don't treat Kecleon and allies as real enemies. For pathfinding, allow whatever
    -- terrains the enemy can walk on.
    -- XXX: Assume water not lava for now, until mechanics.dungeon is implemented...
    local DUNGEON_HAS_LAVA = false
    local nearestEnemies = scanNearbyEntities(
        availableInfo.dungeon.entities.enemies(),
        leader.xPosition, leader.yPosition, availableInfo.dungeon,
        function(enemy)
            return not enemy.isShopkeeper
                and not enemy.isAlly
                and not hasStatus(enemy, codes.STATUS.Sleep)
        end,
        function(terrain, enemy)
            -- Fallback if we don't know the species
            if enemy.features.species == nil then
                return terrain == codes.TERRAIN.Normal
            end
            return mechanics.species.walkable[
                mechanics.species(enemy.features.species).mobility](terrain, DUNGEON_HAS_LAVA)
        end
    )
    -- Only pay attention to enemies if they're on screen
    local nearestEnemiesOnScreen = {}
    for i, enemyWithPath in ipairs(nearestEnemies) do
        local enemy = enemyWithPath.entity
        if rangeutils.onScreen(enemy.xPosition, enemy.yPosition,
            leader.xPosition, leader.yPosition) then
            table.insert(nearestEnemiesOnScreen, enemyWithPath)
        end
    end
    if #nearestEnemiesOnScreen > 0 then
        -- An enemy is in the vicinity and can approach us

        -- Go through enemies one-by-one until an action is taken
        for _, enemyWithPath in ipairs(nearestEnemiesOnScreen) do
            local nearestEnemy, pathToEnemy = enemyWithPath.entity, enemyWithPath.path

            -- Determine if the enemy is close enough that it needs immediate attention
            local enemyIsClose = false
            local pathMovesToEnemy = pathfinder.getMoves(pathToEnemy)
            if not rangeutils.inVisibilityRegion(self.target.pos[1], self.target.pos[2],
                leader.xPosition, leader.yPosition, availableInfo.dungeon) then
                -- If we're moving to a target not in visibility range, (e.g., we're exploring,
                -- or an omniscient agent is heading towards the stairs), then "close" means
                -- within 2 tiles
                enemyIsClose = #pathMovesToEnemy <= 2
            else
                -- Otherwise, "close" means that the enemy is at least as close
                -- to the target as the leader
                -- Force recompute the target path first.
                local pathToTarget = pathfinder.getPath(availableInfo.dungeon.layout(),
                    leader.xPosition, leader.yPosition, self.target.pos[1], self.target.pos[2],
                    nil, mustAvoid, avoidIfPossible)
                -- Next, compute the path from the enemy to the target
                local enemySpecies = nearestEnemy.features.species
                local enemyPathToTarget = pathfinder.getPath(
                    availableInfo.dungeon.layout(),
                    nearestEnemy.xPosition, nearestEnemy.yPosition,
                    self.target.pos[1], self.target.pos[2],
                    function(terrain)
                        -- Fallback if we don't know the species
                        if enemySpecies == nil then return terrain == codes.TERRAIN.Normal end
                        return mechanics.species.walkable[mechanics.species(enemySpecies).mobility](
                            terrain, DUNGEON_HAS_LAVA
                        )
                    end
                )
                -- If pathToTarget is nil, the enemy is probably in the way
                enemyIsClose = pathToTarget == nil or
                    (enemyPathToTarget ~= nil and #enemyPathToTarget <= #pathToTarget)
            end

            -- Do a few preparatory checks before engaging with the enemy
            local engageWithEnemy = true
            -- If the enemy is close by, need to skip the intermediate logic and deal with it now
            if not enemyIsClose then
                -- If the stairs are here, just make a beeline for them
                if self.target.type == TARGET.Stairs then
                    engageWithEnemy = false
                else
                    -- We're not escaping at this point, so take some precautions before
                    -- the enemy gets too close

                    -- Heal if HP is moderately low and there's healing items in the bag
                    -- "Moderately low" means 37.5% HP or lower
                    if smartactions.healIfLowHP(availableInfo, leader.stats.HP,
                        leader.stats.maxHP, 0.375 * leader.stats.maxHP, true, true) then
                        return
                    end

                    -- Restore PP if a Max Elixir is in the bag and all offensive moves are out of PP
                    if moveLogic.checkOffensiveMoves(leader.moves) == 0 and
                        smartactions.useMaxElixirIfPossible(availableInfo, true) then
                        return
                    end

                    -- If belly is empty, restore it
                    if smartactions.eatFoodIfBellyEmpty(availableInfo, leader.belly, true) then
                        return
                    end

                    -- If going for an item, just go for it
                    if self.target.type == TARGET.Item then
                        engageWithEnemy = false
                    else
                        -- If there's nothing else to do, and belly is even somewhat low,
                        -- we might as well eat something (provided we're not being wasteful)
                        if smartactions.eatFoodIfHungry(availableInfo, leader.belly,
                            leader.maxBelly, leader.maxBelly - 50, false, true) then
                            return
                        end
                    end
                end
            end

            if engageWithEnemy then
                -- We've decided to engage. Now deal with the enemy
                -- If no teammates are in the way, first try to attack with something in-range
                local teammatePositions = {}
                for i, teammate in ipairs(availableInfo.dungeon.entities.team()) do
                    -- Don't include the leader
                    if i > 1 then
                        table.insert(teammatePositions, {teammate.xPosition, teammate.yPosition})
                    end
                end
                if not pathfinder.pathIntersects(pathToEnemy, teammatePositions) and
                    self:attackEnemy(nearestEnemy, leader, availableInfo) then
                    return
                end
                -- If that didn't work, see how to get to the enemy
                -- pathToEnemy was computed from the enemy's perspective. Now we recompute the
                -- path with the intention of following it ourselves.
                -- Omit the enemy's position from mustAvoid
                local mustAvoidExceptEnemy = {}
                for _, pos in ipairs(mustAvoid) do
                    if not pathfinder.comparePositions(pos,
                        {nearestEnemy.xPosition, nearestEnemy.yPosition}) then
                        table.insert(mustAvoidExceptEnemy, pos)
                    end
                end
                pathToEnemy = pathfinder.getPath(availableInfo.dungeon.layout(),
                    leader.xPosition, leader.yPosition,
                    nearestEnemy.xPosition, nearestEnemy.yPosition,
                    nil, mustAvoidExceptEnemy, avoidIfPossible)
                if pathToEnemy then
                    -- If we can find a path, approach
                    local text = 'Approaching enemy'
                    if nearestEnemy.features.species then
                        text = text .. ' ' .. codes.SPECIES_NAMES[nearestEnemy.features.species]
                    end
                    text = text .. '.'
                    messages.report(text)

                    -- Use random directional inputs if confused; see more detailed comment
                    -- near the end of the code
                    if hasStatus(leader, codes.STATUS.Confused) and
                        #availableInfo.dungeon.entities.team() > 1 then
                        messages.report('Confused. Resting in place.')
                        basicactions.rest()
                        return
                    end
                    basicactions.walk(pathfinder.getMoves(pathToEnemy)[1].direction)
                    return
                end
                -- Otherwise, the enemy can reach us, but we can't reach it. Just ignore the
                -- enemy being there and check the next one. If there are no more enemies
                -- to check, just continue proceeding towards the target. If one of them
                -- comes to a place we can reach, we'll deal with it then.
            end
        end
    else
        -- No enemies are in the vicinity

        -- Eat food if belly is empty and there's food in the bag
        if smartactions.eatFoodIfBellyEmpty(availableInfo, leader.belly, true) then
            return
        end
        -- Eat food if belly is low (50 below max), there's food in the bag, and it can
        -- be done without being wasteful
        if smartactions.eatFoodIfHungry(availableInfo, leader.belly,
            leader.maxBelly, leader.maxBelly - 50, false, true) then
            return
        end

        -- If the target is an item or stairs, and it hasn't been reached yet,
        -- ignore the rest of this logic
        if not (self.target.type == TARGET.Item or self.target.type == TARGET.Stairs) or
            self:isTargetPos({leader.xPosition, leader.yPosition}) then
            -- If on the stairs, HP isn't full, and it makes sense to rest (belly isn't empty,
            -- non-damaging weather, no status), then rest
            if self.target.type == TARGET.Stairs and leader.stats.HP < leader.stats.maxHP and
                leader.belly > 0 and #leader.statuses == 0 and (not (
                    availableInfo.dungeon.conditions.weather() == codes.WEATHER.Sandstorm or
                    availableInfo.dungeon.conditions.weather() == codes.WEATHER.Hail
                ) or availableInfo.dungeon.conditions.weatherIsNullified()) then
                basicactions.rest(true)
                return
            end

            -- If PP is low, use a Max Elixir if possible
            -- "Low PP" means if 25% or less (rounded) of offensive moves still have PP
            local nOffensiveMovesWithPP, nOffensiveMoves = moveLogic.checkOffensiveMoves(leader.moves)
            if nOffensiveMovesWithPP <= mathutils.round(0.25 * nOffensiveMoves) and
                smartactions.useMaxElixirIfPossible(availableInfo, true) then
                return
            end
        end
    end

    -- If we got to this point in the logic, we're on the stairs,
    -- and it's the current target, climb
    if self.target.type == TARGET.Stairs and
        self:isTargetPos({leader.xPosition, leader.yPosition}) then
        self:setTarget(nil)  -- Clear the target
        basicactions.climbStairs(true)
        return
    end

    -- If no other action was taken, walk towards the target
    self:findTargetPath(leader.xPosition, leader.yPosition,
        availableInfo.dungeon.layout(), mustAvoid, avoidIfPossible)
    if #self.pathMoves > 0 then
        -- Not already on target
        local text = ''
        if self.target.type == TARGET.Explore then
            text = 'Exploring'
        else
            text = 'Moving to target'
            if self.target.name then
                text = text .. ': ' .. self.target.name
            end
        end
        text = text .. '.'
        messages.report(text)

        -- If confused, and there are teammates, just rest. This helps prevent
        -- getting locked by trying to move into a teammate while confused
        -- (especially if you end up in a corner!), and moving randomly probably
        -- won't be helpful anyway
        if hasStatus(leader, codes.STATUS.Confused) and
            #availableInfo.dungeon.entities.team() > 1 then
            messages.report('Confused. Resting in place.')
            basicactions.rest()
            return
        end
        local direction = table.remove(self.pathMoves, 1).direction
        basicactions.walk(direction)
    end
end