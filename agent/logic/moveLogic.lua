-- Helpers for move-related logic

require 'actions.basicactions'
require 'actions.smartactions'

require 'codes.move'
require 'codes.moveRange'

require 'mechanics.move'
require 'mechanics.power'

require 'utils.pathfinder'

local moveLogic = {}

local function expectedDamageHeuristic(move, attacker, defender)
    local attackerTypes = {attacker.features.primaryType, attacker.features.secondaryType}
    local defenderTypes = {defender.features.primaryType, defender.features.secondaryType}
    local defenderAbilities = {defender.features.primaryAbility, defender.features.secondaryAbility}

    local moveInfo = mechanics.move(move.moveID)
    local ginseng = move.ginsengBoost or 0
    ginseng = moveInfo.boostableByGinseng and ginseng or 0
    local power = mechanics.power.applyGinsengBoost(moveInfo.basePower, ginseng)
    local damage = mechanics.power.calcDamageHeuristic(power,
        moveInfo.type, attackerTypes, defenderTypes, defenderAbilities)
    -- Weight the damage heuristic by the move accuracy
    -- "Male" accuracy is the "base" accuracy; "Female" accuracy is higher
    damage = damage * moveInfo.accuracyMale / 100
    -- If the move is multihitting, also factor that in
    -- strikes == 0 means a random # of hits (2-5). Use 3, the expected # of hits
    -- (from the main series in Gen IV)
    local strikes = moveInfo.strikes > 0 and moveInfo.strikes or 3
    damage = damage * strikes
    return damage
end

local function isUsable(move)
    return move.PP > 0 and not move.isSealed and not move.isDisabled
        and not move.subsequentInLinkChain
end

local function hitsTeammatesAOE(moveID)
    return mechanics.move.isAOE(moveID) and mechanics.move.hasFriendlyFire(moveID)
end

-- Similar to smartactions.useMoveIfInRange, but turn to face the enemy if
-- the range check passes. Also falls back to the basic attack if idx is invalid.
local function tryAttack(idx, leader, enemy, layout)
    local move = leader.moves[idx]
    local moveID = move and move.moveID or codes.MOVE.regularattack
    if not mechanics.move.inRange(moveID, enemy.xPosition, enemy.yPosition,
        leader.xPosition, leader.yPosition, layout) then
        return false
    end

    -- The direction to face the enemy if needed/possible
    local direction = pathfinder.getDirection(
        enemy.xPosition - leader.xPosition,
        enemy.yPosition - leader.yPosition
    )
    if direction and leader.direction ~= direction then
        basicactions.face(direction)
    end

    if moveID == codes.MOVE.regularattack then
        basicactions.attack(true)
        return true
    end
    -- idx-1 to convert 1-indexing to 0-indexing
    return smartactions.useMoveIfPossible(idx-1, leader.moves, true)
end

-- Decide how to attack an enemy given the circumstances, and perform the action.
-- Returns true if the attack was successfully used, or false if not.
function moveLogic.attackEnemyWithBestMove(enemy, leader, availableInfo)
    local teammatesExist = #availableInfo.dungeon.entities.team() > 1
    local movepool = {}
    for i, move in ipairs(leader.moves) do
        if isUsable(move)
            and mechanics.move.isOffensive(move.moveID)
            and (
                -- Try not to save room-clearing moves for special circumstances,
                -- unless they're the only moves left
                mechanics.move(move.moveID).range < codes.MOVE_RANGE.Room or
                moveLogic.onlyAOEOffensiveMoves(leader.moves, false, math.huge)
            )
            and not (teammatesExist and hitsTeammatesAOE(move.moveID))
            and expectedDamageHeuristic(move, leader, enemy) > 0 then
            table.insert(movepool, {
                idx=i,
                damage=expectedDamageHeuristic(move, leader, enemy),
                pp=move.PP,
            })
        end
    end

    -- If the enemy is threatening (STAB super effective), attack it with
    -- any move possible, rather than waiting for the best move to be in range.
    -- Otherwise, only try to use the best move; if out of range, do nothing.
    -- This helps (just a little bit) to mitigate projectile spam.
    local threatened =
        (mechanics.power.typeEffectiveness(enemy.features.primaryType,
        leader.features.primaryType, leader.features.secondaryType) > 1) or
        (mechanics.power.typeEffectiveness(enemy.features.secondaryType,
        leader.features.primaryType, leader.features.secondaryType) > 1)

    -- Out of the selected moves, try the ones that do the most damage and have
    -- the most PP first, based on a damage heuristic (take the product of the
    -- two quantities). Break ties with power. This helps balance doing the most
    -- damage and conserving PP.
    --
    -- If threatened, use just the damage heuristic as the primary sorting key,
    -- only using PP to break ties, since we want to deal with the threat as
    -- quickly as possible.
    local sortingFn = function(a, b)
        local aProd = a.damage*a.pp
        local bProd = b.damage*b.pp
        if aProd == bProd then return a.damage > b.damage end
        return aProd > bProd
    end
    if threatened then
        sortingFn = function(a, b)
            if a.damage == b.damage then return a.pp > b.pp end
            return a.damage > b.damage
        end
    end
    table.sort(movepool, sortingFn)
    -- Append an invalid index (basic attack) as a last resort
    table.insert(movepool, {idx=-1, damage=0})

    local highestDamage = movepool[1].damage
    for _, idxAndDamage in ipairs(movepool) do
        if not threatened and idxAndDamage.damage < highestDamage then break end
        if tryAttack(idxAndDamage.idx, leader, enemy, availableInfo.dungeon.layout()) then
            return true
        end
    end

    -- No attacks were used
    return false
end

-- Checks how many offensive moves still have PP, and also the total
-- number of offensive moves
function moveLogic.checkOffensiveMoves(moves)
    local nOffensiveMoves = 0
    local nOffensiveMovesWithPP = 0
    for _, move in ipairs(moves) do
        if mechanics.move.isOffensive(move.moveID) then
            nOffensiveMoves = nOffensiveMoves + 1
            if move.PP > 0 then
                nOffensiveMovesWithPP = nOffensiveMovesWithPP + 1
            end
        end
    end
    return nOffensiveMovesWithPP, nOffensiveMoves
end

-- Gets a list of indexes (1-indexed) for offensive AOE moves that won't
-- hit teammates if any exist, and also the number of those that have PP left.
-- The indexes will be in descending order by range, then by base power
function moveLogic.getOffensiveAOEMoves(moves, teammatesExist, AOESize)
    local teammatesExist = teammatesExist or false
    -- By default, exclude Wide Slash; it's partly directional so the logic would be more complicated
    local AOESize = AOESize or 8

    local AOEMoveIdxs = {}
    local nAOEMovesWithPP = 0
    for i, move in ipairs(moves) do
        -- Exclude Wide Slash; it's partly directional so the logic would be more complicated
        if mechanics.move.isOffensive(move.moveID) and mechanics.move.isAOE(move.moveID, AOESize)
            and not (teammatesExist and mechanics.move.hasFriendlyFire(move.moveID)) then
            table.insert(AOEMoveIdxs, i)
            if move.PP > 0 then
                nAOEMovesWithPP = nAOEMovesWithPP + 1
            end
        end
        -- Sort by highest range, then highest base power
        table.sort(AOEMoveIdxs, function(i1, i2)
            local info1 = mechanics.move(moves[i1].moveID)
            local info2 = mechanics.move(moves[i2].moveID)
            if info1.range ~= info2.range then return info1.range > info2.range end
            return info1.basePower > info2.basePower
        end)
    end
    return AOEMoveIdxs, nAOEMovesWithPP
end

-- Checks if the only offensive moves with PP left are AOE
function moveLogic.onlyAOEOffensiveMoves(moves, teammatesExist, AOESize)
    local nOffensiveMovesWithPP = moveLogic.checkOffensiveMoves(moves)
    -- Proxy defaults to getOffensiveAOEMoves
    local _, nAOEMovesWithPP = moveLogic.getOffensiveAOEMoves(moves, teammatesExist, AOESize)
    return nOffensiveMovesWithPP <= nAOEMovesWithPP
end

return moveLogic