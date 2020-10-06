-- Utilities for calculating damage
-- Sources:
-- https://gamefaqs.gamespot.com/ds/955859-pokemon-mystery-dungeon-explorers-of-sky/faqs/75112/damage-mechanics-guide
-- https://gamefaqs.gamespot.com/ds/955859-pokemon-mystery-dungeon-explorers-of-sky/faqs/58391
--  - Erratic Player section
require 'math'

require 'codes.type'
local typeMatchups = require 'mechanics.typeMatchups'

if mechanics == nil then
    mechanics = {}
end

mechanics.power = {}

-- Boost a move's power based on its ginseng level
function mechanics.power.applyGinsengBoost(basePower, ginsengLevel)
    return basePower + ginsengLevel
end

-- Apply stat modifiers to an attacker and defender given the dungeon
-- state and return the modified stats
function mechanics.power.applyStatModifiers(attacker, defender, state)
    -- TODO. Lots of complicated cases...
    -- Need to properly handle nullables so state can be either
    -- the full state of the visible state
end

-- Calculates the base damage of a move when used on a target
function mechanics.power.calcBaseDamage(movePower, offensiveStat, defensiveStat, attackerLevel)
    -- Supposedly there's also a multiplier for monster "not members of a team"...
    -- Not sure what that means exactly
    return (
        (offensiveStat + movePower) * 39168 / 65536
        - defensiveStat / 2
        + 50 * math.log(10*( (offensiveStat-defensiveStat)/8 + attackerLevel + 50 ))
        - 311
    )
end

-- Calculate the damage dealt by an attack, before randomization
function mechanics.power.calcDamage(attack, attacker, defender, state)
    -- TODO. Lots of complicated cases...
    -- Probably don't need to handle nullables here; can't even calculate
    -- base damage without full knowledge
end


-- Calculates the type effectiveness multiplier for pure types
function mechanics.power.typeChart(attackType, targetType, erraticPlayer)
    local erraticPlayer = erraticPlayer or false
    local typeMultipliers = erraticPlayer and
        typeMatchups.multipliersErraticPlayer or typeMatchups.multipliers
    return typeMultipliers[typeMatchups.matchupTable[attackType][targetType]]
end

-- Calculates the type effectiveness multiplier for type combinations
function mechanics.power.typeEffectiveness(attackType, targetType1, targetType2, erraticPlayer)
    local targetType2 = targetType2 or codes.TYPE.None
    -- Don't count the same type twice
    if targetType1 == targetType2 then targetType2 = codes.TYPE.None end
    return (mechanics.power.typeChart(attackType, targetType1, erraticPlayer) *
            mechanics.power.typeChart(attackType, targetType2, erraticPlayer))
end

-- Extract a primary/secondary type from a single type/dual type input
local function extractTypes(typeList)
    local typeList = (type(typeList) == 'table') and typeList or {typeList}
    return typeList[1], typeList[2] or codes.TYPE.None
end

-- Calculate a damage heuristic of (multiplier) * (power) that doesn't only
-- requires visible information
function mechanics.power.calcDamageHeuristic(
    movePower, moveType, attackerTypes, defenderTypes, erraticPlayer)
    -- Starting damage heuristic
    local heuristic = movePower

    -- Unpack types
    local attackerType1, attackerType2 = extractTypes(attackerTypes)
    local defenderType1, defenderType2 = extractTypes(defenderTypes)

    -- STAB
    if (moveType == attackerType1 or moveType == attackerType2)
        and moveType ~= codes.TYPE.None then
        heuristic = heuristic * 1.5
    end

    -- Type effectiveness
    heuristic = heuristic * mechanics.power.typeEffectiveness(
        moveType, defenderType1, defenderType2, erraticPlayer)

    return heuristic
end