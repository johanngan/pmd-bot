-- Class for deciding on what actions to take based on the current state
local BaseAgent = require 'agent.BaseAgent'

require 'math'
require 'table'

require 'utils.enum'
require 'utils.mathutils'
require 'utils.messages'
require 'utils.pathfinder'

require 'codes.menu'
require 'codes.mobility'
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

local Agent = BaseAgent:__instance__()
Agent.name = 'Agent'

-- Set this to false if you want your bot to use only visible information!
Agent.omniscient = false

-- Pathfinding target types
local TARGET, _ = enum.register({
    'Stairs',
    'Item',
    'WonderTile',
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
    -- ID of the last enemy attacked
    self.lastEnemyAttacked = nil
    -- Current HP; will be set at the beginning of each turn
    self.currentHP = nil
    -- HP at the start of the previous turn
    self.previousHP = nil
    -- Flag for if an HP-restoring item was used this turn
    self.healedThisTurn = false
    -- Flag for if an HP-restoring item was used last turn
    self.healedLastTurn = false

    -- Preload all the mechanics info for the leader's current moves into memory
    local moveIDs = {}
    for _, move in ipairs(state.player.leader().moves) do
        table.insert(moveIDs, move.moveID)
    end
    mechanics.move(moveIDs)
end

-- This function will be called right before the act() method is called, unless the
-- turnOngoing flag is set. Change it to reset the bot state at the start of a turn.
function Agent:setupTurn(state, visible)
    self.currentHP = state.player.leader().stats.HP
end

-- This function will be called right after the act() method returns, unless the
-- turnOngoing flag is set. Change it to prepare or record data for the bot to
-- use in future turns.
function Agent:finalizeTurn()
    self.previousHP = self.currentHP
    self.currentHP = nil

    self.healedLastTurn = self.healedThisTurn
    self.healedThisTurn = false
end

-- A wrapper around smartactions.healIfLowHP, with a bit of extra logic
function Agent:healIfSensible(state, HP, maxHP, threshold, allowWaste, verbose)
    if self.healedLastTurn and self.currentHP and self.previousHP and
        self.currentHP <= self.previousHP then
        -- Forgo healing if we just healed last turn but our HP isn't any higher than it
        -- was before the heal; this probably means we're under attack from a threatening
        -- enemy that can outdamage our healing, and it doesn't make sense to heal again
        -- in this case (it'd be wasting supplies only to take more damage anyway)
        return false
    end
    if smartactions.healIfLowHP(state, HP, maxHP, threshold, allowWaste, verbose) then
        self.healedThisTurn = true
        return true
    end
    return false
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

-- Normal stage for all stats except speed (for which the normal stage is 1)
local NORMAL_STAT_STAGE = 10
-- Checks the lowest stat stage of a monster. Returns nil if uncertain
-- The list of stats defaults to all stats except evasion and speed
local function lowestStatStage(entity, stats)
    local stats = stats or {
        'attack',
        'specialAttack',
        'defense',
        'specialDefense',
        'accuracy'
    }

    local modifiers = entity.stats.modifiers
    local lowestStage = nil
    for _, stat in ipairs(stats) do
        local stageField = stat .. 'Stage'
        if modifiers[stageField] and
            (lowestStage == nil or modifiers[stageField] < lowestStage) then
            lowestStage = modifiers[stageField]
        end
    end
    return lowestStage
end

-- Checks if a path contains a tile that's off screen and out of visibility range;
-- see the comment by the call in scanNearbyEntities
local function pathVisibleOrOnScreen(path, x0, y0, dungeon)
    for _, pos in ipairs(path) do
        if not rangeutils.visibleOrOnScreen(pos[1], pos[2], x0, y0, dungeon) then
            return false
        end
    end
    return true
end

-- Scan a list of entities and check if any are in visibility range and within
-- some path length. Return a list of the closest ones and the paths to them, with
-- the form {entity, path} for each item.
-- Optionally specify a checkValidity(entity) function that only returns an entity
-- if it satisfies the given validity check, and a walkableWithEntity(terrain, entity) function
-- for the pathfinder
local function scanNearbyEntities(entities, x0, y0, dungeon,
    checkValidity, walkableWithEntity, avoidIfPossible, maxSteps)
    -- By default, allow paths to be of arbitrary length
    local maxSteps = maxSteps or math.huge
    local nearestEntities = {}
    for _, entity in ipairs(entities) do
        -- Allow the entity to be in visibility range OR on screen; if an entity isn't
        -- known about, visibleinfo will handle that and the entity won't be included in
        -- the entities list.
        if rangeutils.visibleOrOnScreen(entity.xPosition, entity.yPosition, x0, y0, dungeon)
            and (checkValidity == nil or checkValidity(entity)) then
            -- Wrap walkableWithEntity so that the pathfinder can understand it
            local walkable = walkableWithEntity
                and function(terrain) return walkableWithEntity(terrain, entity) end
                or nil
            -- Search for a path to the entity
            local path = pathfinder.getPath(dungeon.layout(),
                x0, y0, entity.xPosition, entity.yPosition, walkable, nil, avoidIfPossible)
            -- Reject the path if it goes out of visibility range and off screen at all,
            -- since these are to entities that are technically reachable but only by a
            -- circuitous path, which is undesirable.
            -- maxSteps + 1 because path includes the starting point
            if path and #path <= maxSteps + 1 and
                pathVisibleOrOnScreen(path, x0, y0, dungeon) then
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
function Agent:attackEnemy(enemy, leader, availableInfo, underAttack)
    -- Wrap in an Agent method in case we want to use internal state in the future
    return moveLogic.attackEnemyWithBestMove(enemy, leader, availableInfo, underAttack)
end

-- Perform some actions based on the current state of the dungeon (and the bot's own state)
-- This is a very simple sample strategy. Change it to fit your botting needs.
function Agent:act(state, visible)
    -- Use only as much information as is available to the agent
    local availableInfo = self.omniscient and state or visible

    -- If in a Yes/No prompt, try to exit
    if menuinfo.getMenu() == codes.MENU.YesNo then
        basicactions.selectYesNo(1, true)
        self.turnOngoing = true -- Not turn-ending
        return
    end

    -- If trying to learn a new move, don't
    if menuinfo.getMenu() == codes.MENU.NewMove then
        basicactions.selectMoveToForget(4, true)
        self.turnOngoing = true -- Not turn-ending
        return
    end

    local leader = availableInfo.player.leader()
    -- The largest stat drop out of all stats except evasion (not very important)
    -- and speed (not affected by Wonder Tiles)
    local statDeficit = NORMAL_STAT_STAGE - (lowestStatStage(leader) or NORMAL_STAT_STAGE)
    -- Net damage taken since last turn
    local damageTaken = (self.previousHP or self.currentHP) - self.currentHP
    -- If the damage taken is fairly high, assume there's a threatening attacker
    -- and make decisions based on that. "A lot" means at least 25% of the player's
    -- max HP, or at least 30
    local underAttack = damageTaken >= math.min(leader.stats.maxHP / 4, 30)

    -- Health is critically low; try to heal.
    -- "Critically low" means less than 25% HP (add 1 to numerator/denominator)
    --      (this roughly coincides with when the UI starts flashing)
    local threshold = 0.25 * (leader.stats.maxHP + 1) - 1
    -- ceil(threshold) - 1 because the parameter is treated as inclusive in this function
    if self:healIfSensible(availableInfo, leader.stats.HP, leader.stats.maxHP,
        math.ceil(threshold) - 1, true, true) then
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
        -- Count how many enemies are in range of this move that aren't immune
        local move = leader.moves[idx]
        local nEnemiesInRange = 0
        for _, enemy in ipairs(availableInfo.dungeon.entities.enemies()) do
            if not enemy.isShopkeeper and not enemy.isAlly and
                mechanics.move.inRange(move.moveID, enemy.xPosition, enemy.yPosition,
                    leader.xPosition, leader.yPosition, availableInfo.dungeon.layout()) and
                moveLogic.expectedDamageHeuristic(move, leader, enemy,
                    availableInfo.dungeon.conditions) > 0 then
                -- Enemy is within attack range
                nEnemiesInRange = nEnemiesInRange + 1
            end
        end
        -- Use the move if possible
        -- Subtract 1 to convert from 1-indexing to 0-indexing
        if nEnemiesInRange >= 3 and
            smartactions.useMoveIfPossible(idx-1, leader.moves, leader, true) then
            return
        end
    end

    -- Try to cure statuses that absolutely need urgent attention and can't wait
    if smartactions.cureStatusIfPossible(state, itemLogic.urgentStatuses) then
        return
    end

    -- For certain logic, we need to consider enemies, which are impassable
    -- and MUST be avoided.
    local mustAvoid = {}
    for _, enemy in ipairs(availableInfo.dungeon.entities.enemies()) do
        -- Shopkeepers and allies can be passed through
        if not enemy.isShopkeeper and not enemy.isAlly then
            table.insert(mustAvoid, {enemy.xPosition, enemy.yPosition})
        end
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
    -- If the target was an item (if we get in here, the item must still be there),
    -- defer unsetting the target until we can pick it up (later, after we check
    -- for enemies nearby)
    if self:isTargetPos({leader.xPosition, leader.yPosition}) and
        self.target.type ~= TARGET.Item then
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
                    availableInfo.player.bagCapacity()) or
                    itemLogic.resolveDiscardabilityByUse(item)
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
        elseif statDeficit >= 2 then
            -- If any relevant stat is at least 2 stages below normal, and there's a
            -- Wonder Tile nearby, head towards it.
            local nearestWTiles = scanNearbyEntities(
                availableInfo.dungeon.entities.traps(),
                leader.xPosition, leader.yPosition, availableInfo.dungeon,
                function(trap) return trap.trapType == codes.TRAP.WonderTile end)
            if #nearestWTiles > 0 then
                -- Just pick the first Wonder Tile found if there are multiple equally close ones
                local nearestWTile, path = nearestWTiles[1].entity, nearestWTiles[1].path
                -- Set a soft target; if an item or the stairs becomes visible, we'll want to
                -- target those instead
                self:setTarget({nearestWTile.xPosition, nearestWTile.yPosition},
                    TARGET.WonderTile, 'Wonder Tile', true)
                -- Might as well save the path we just calculated
                self.pathMoves = pathfinder.getMoves(path)
                explore = false
            end
        end
        -- If explore is still true by this point, there are two possibilities:
        --  1. No items or stairs are visible, and no Wonder Tile is needed/visible
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
        -- If the target is off-screen, force it to be soft. This isn't strictly necessary
        -- with the current targeting code since only items can be hard targets, and they'll
        -- currently they'll only be targeted either if on screen or in visibility range anyway,
        -- but there's little harm in setting this. Forcing off-screen targets to be soft
        -- is a good way to ensure that, e.g., in omniscient mode, stuff that appears on-screen
        -- is prioritized.
        if self.target.pos and not rangeutils.onScreen(self.target.pos[1], self.target.pos[2],
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
            local mobility = enemy.features.species and
                mechanics.species(enemy.features.species).mobility or
                codes.MOBILITY.Normal   -- Fallback if we don't know the species

            -- Check the terrain the enemy is currently standing on. If it's not a
            -- terrain the enemy could normally walk on, there must be some mobility
            -- modifier at play, such as All-Terrain Hiker, Absolute Mover,
            -- a Mobile Scarf, or a Mobile Orb.
            local layout = availableInfo.dungeon.layout()
            local enemyTerrain = layout[enemy.yPosition][enemy.xPosition].terrain
            if enemyTerrain and not mechanics.species.walkable[mobility](
                enemyTerrain, DUNGEON_HAS_LAVA) then
                if enemyTerrain ~= codes.TERRAIN.Wall then
                    -- Assume All-Terrain Hiker
                    mobility = codes.MOBILITY.Hovering
                else
                    -- Assume full mobility (e.g. Mobile Scarf)
                    return true
                end
            end

            return mechanics.species.walkable[mobility](terrain, DUNGEON_HAS_LAVA)
        end
    )
    -- Unless actively threatened, only pay attention to enemies if they're on screen
    local nearestRelevantEnemies = nearestEnemies
    if not underAttack then
        nearestRelevantEnemies = {}
        for i, enemyWithPath in ipairs(nearestEnemies) do
            local enemy = enemyWithPath.entity
            if rangeutils.onScreen(enemy.xPosition, enemy.yPosition,
                leader.xPosition, leader.yPosition) then
                table.insert(nearestRelevantEnemies, enemyWithPath)
            end
        end
    end

    if #nearestRelevantEnemies > 0 then
        -- An enemy is in the vicinity and can approach us
        -- All enemies in the list will be the same distance away. Prioritize attacking
        -- the same enemy as before if it's in this list, in order to focus on one
        -- enemy at a time.
        table.sort(nearestRelevantEnemies,
            function(enemyWithPath1, enemyWithPath2)
                return self.lastEnemyAttacked and
                    enemyWithPath1.entity.index == self.lastEnemyAttacked
            end
        )

        -- Go through enemies one-by-one until an action is taken
        for _, enemyWithPath in ipairs(nearestRelevantEnemies) do
            local nearestEnemy, pathToEnemy = enemyWithPath.entity, enemyWithPath.path

            -- Do a few preparatory checks before engaging with the enemy
            local engageWithEnemy = true
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

                -- Additionally, if we're actively threatened, count the enemy as close if the
                -- target is off screen; the target is too far away and we should instead focus
                -- on the imminent threat.
                if underAttack then
                    enemyIsClose = not rangeutils.onScreen(self.target.pos[1], self.target.pos[2],
                        leader.xPosition, leader.yPosition)
                end

                -- Force recompute the target path first.
                local pathToTarget = pathfinder.getPath(availableInfo.dungeon.layout(),
                    leader.xPosition, leader.yPosition, self.target.pos[1], self.target.pos[2],
                    nil, mustAvoid, avoidIfPossible)

                -- If we're already treating the enemy as close, we can skip some pathfinding work
                if not enemyIsClose then
                    -- Special case: if the bag is full and the target is an item, it'll take
                    -- an extra turn to swap a bag item for it, so we'll need to add 1 to the
                    -- path length
                    local extraTargetSteps = 0
                    if self.target.type == TARGET.Item and
                        #availableInfo.player.bag() >= availableInfo.player.bagCapacity() then
                        extraTargetSteps = 1
                    end
                    -- Next, compute the path from the enemy to the target
                    local enemySpecies = nearestEnemy.features.species
                    local enemyPathToTarget = pathfinder.getPath(
                        availableInfo.dungeon.layout(),
                        nearestEnemy.xPosition, nearestEnemy.yPosition,
                        self.target.pos[1], self.target.pos[2],
                        function(terrain)
                            -- Fallback if we don't know the species
                            if enemySpecies == nil then
                                return terrain == codes.TERRAIN.Normal
                            end
                            return mechanics.species.walkable[
                                mechanics.species(enemySpecies).mobility](
                                terrain, DUNGEON_HAS_LAVA
                            )
                        end
                    )
                    -- If pathToTarget is nil, the enemy is probably in the way
                    enemyIsClose = pathToTarget == nil or
                        (enemyPathToTarget ~= nil and
                        #enemyPathToTarget <= #pathToTarget + extraTargetSteps)
                end

                -- If the stat deficit is really severe (at least 5 stages), and a
                -- Wonder Tile is currently being targeted and is reachable, ignore the
                -- enemy regardless of how close it is.
                -- (But if the enemy is not close then still go through the other prep checks first)
                if self.target.type == TARGET.WonderTile and pathToTarget and statDeficit >= 5 then
                    engageWithEnemy = false
                end
            end

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
                    if self:healIfSensible(availableInfo, leader.stats.HP, leader.stats.maxHP,
                        0.375 * leader.stats.maxHP, true, true) then
                        return
                    end

                    -- Restore PP if a Max Elixir is in the bag and all offensive moves are out of PP
                    if moveLogic.checkOffensiveMoves(leader.moves) == 0 and
                        smartactions.useMaxElixirIfPossible(availableInfo, true) then
                        return
                    end

                    -- If we're actively threatened, that's it for prep. Otherwise, try a few
                    -- more things...
                    if not underAttack then
                        -- If belly is empty, restore it
                        if smartactions.eatFoodIfBellyEmpty(availableInfo, leader.belly, true) then
                            return
                        end

                        -- If going for an item or a Wonder Tile, just go for it
                        if self.target.type == TARGET.Item or
                            self.target.type == TARGET.WonderTile then
                            engageWithEnemy = false
                        else
                            -- Equip a better held item if there is one
                            if itemLogic.equipBestItem(availableInfo) then
                                return
                            end

                            -- If there's nothing else to do, and belly is even somewhat low,
                            -- we might as well eat something (provided we're not being wasteful)
                            if smartactions.eatFoodIfHungry(availableInfo, leader.belly,
                                leader.maxBelly, leader.maxBelly - 50, false, true) then
                                return
                            end
                        end
                    end
                end
            end

            if engageWithEnemy then
                -- We've decided to engage. Now deal with the enemy
                -- First, heal off any debilitating statuses if possible
                if smartactions.cureStatusIfPossible(state, itemLogic.debilitatingStatuses) then
                    return
                end

                -- If no teammates or allies are in the way, first try to attack with something in-range
                local allyPositions = {}
                for i, teammate in ipairs(availableInfo.dungeon.entities.team()) do
                    -- Don't include the leader
                    if i > 1 then
                        table.insert(allyPositions, {teammate.xPosition, teammate.yPosition})
                    end
                end
                for _, enemy in ipairs(availableInfo.dungeon.entities.enemies()) do
                    if enemy.isShopkeeper or enemy.isAlly then
                        -- Can't shoot through shopkeepers and allies either
                        table.insert(allyPositions, {enemy.xPosition, enemy.yPosition})
                    end
                end
                if not pathfinder.pathIntersects(pathToEnemy, allyPositions) and
                    self:attackEnemy(nearestEnemy, leader, availableInfo, underAttack) then
                    -- Attack sequence was successful; record this enemy so we know to focus
                    -- on it in subsequent turns
                    self.lastEnemyAttacked = nearestEnemy.index
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

                    -- Rest if terrified
                    if hasStatus(leader, codes.STATUS.Terrified) then
                        messages.report('Terrified. Resting in place.')
                        basicactions.rest()
                        return
                    end

                    -- Rest if confused; see more detailed comment near the end of the code
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
            -- non-damaging weather, no status, no damage is actively being taken), then rest
            -- Allow for damageTaken to up to 1 (e.g. the first turn of an empty belly)
            if self.target.type == TARGET.Stairs and leader.stats.HP < leader.stats.maxHP and
                leader.belly > 0 and #leader.statuses == 0 and (not (
                    availableInfo.dungeon.conditions.weather() == codes.WEATHER.Sandstorm or
                    availableInfo.dungeon.conditions.weather() == codes.WEATHER.Hail
                ) or availableInfo.dungeon.conditions.weatherIsNullified()) and
                damageTaken <= 1 then
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

    -- If we're not headed for an item and there's a better item to equip than what
    -- we currently have, equip it
    if self.target.type ~= TARGET.Item and itemLogic.equipBestItem(availableInfo) then
        return
    end

    -- If terrified and already on the target, the following actions won't be possible,
    -- so rest instead
    if self:isTargetPos({leader.xPosition, leader.yPosition}) and
        hasStatus(leader, codes.STATUS.Terrified) then
            messages.report('Terrified. Resting in place.')
        basicactions.rest()
        return
    end

    -- If we're standing on the target item but haven't picked it up yet, try to
    if self.target.type == TARGET.Item and
        self:isTargetPos({leader.xPosition, leader.yPosition}) then
        -- Clear the target and return regardless of whether retrieval is
        -- successful; if it's unsuccessful, something weird happened (maybe
        -- an item was Knocked Off and fell underneath the player, but the bag
        -- is already full), so starting from a fresh target next iteration is safer.
        if not itemLogic.retrieveItemUnderfoot(availableInfo) then
            -- If retrieving the item failed, as a backup try to use it if it's discardable.
            -- What probably happened is that the item wasn't worth picking up.
            if not itemLogic.useDiscardableItemUnderfoot(state) then
                self.turnOngoing = true -- Failed to take any action, so a turn hasn't been consumed
            end
        end
        self:setTarget(nil)
        return
    end

    -- If we got to this point in the logic, and we're on the stairs,
    -- and it's the current target, climb
    if self.target.type == TARGET.Stairs and
        self:isTargetPos({leader.xPosition, leader.yPosition}) then
        self:setTarget(nil)  -- Clear the target
        basicactions.climbStairs(true)
        return
    end

    -- If we're targeting a Wonder Tile and standing on it already,
    -- trigger it
    if self.target.type == TARGET.WonderTile and
        self:isTargetPos({leader.xPosition, leader.yPosition}) then
        self:setTarget(nil) -- Clear the target
        basicactions.triggerTile(true)
        return
    end

    -- If there are any bad persistent status conditions that can be cured, cure them
    if smartactions.cureStatusIfPossible(state, itemLogic.persistentStatuses) then
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

return Agent