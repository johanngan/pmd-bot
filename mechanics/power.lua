-- Utilities for calculating damage
-- Sources:
-- https://gamefaqs.gamespot.com/ds/955859-pokemon-mystery-dungeon-explorers-of-sky/faqs/75112/damage-mechanics-guide
-- https://gamefaqs.gamespot.com/ds/955859-pokemon-mystery-dungeon-explorers-of-sky/faqs/58391
--  - Erratic Player section
require 'math'

require 'codes.ability'
require 'codes.type'
require 'codes.weather'

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


-- Functions for calculating a damage multiplier due to certain special abilities
-- All the functions (for an ability, not including helpers) take the attack type
-- and the target's types
local function multSpecificType(attackType, specificType, multiplier)
    return attackType == specificType and (multiplier or 0) or 1
end

local function multiplierThickFat(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Fire, 0.5)
        * multSpecificType(attackType, codes.TYPE.Ice, 0.5)
end

local function multiplierVoltAbsorb(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Electric, -1)
end

local function multiplierWaterAbsorb(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Water, -1)
end

local function multiplierLightningRod(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Electric)
end

local function multiplierWonderGuard(attackType, targetType1, targetType2)
    if attackType == codes.TYPE.None or
        (mechanics.power.typeChart(attackType, targetType1) *
            mechanics.power.typeChart(attackType, targetType2)) > 1 then
        return 1
    end
    return 0
end

local function multiplierLevitate(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Ground)
end

local function multiplierFlashFire(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Fire)
end

local function multiplierDrySkin(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Water, -1)
        * multSpecificType(attackType, codes.TYPE.Fire, 1.5)
end

local function multiplierHeatproof(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Fire, 0.5)
end

local function multiplierMotorDrive(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Electric)
end

local function multiplierSolidRock(attackType, targetType1, targetType2)
    if mechanics.power.typeChart(attackType, targetType1) *
        mechanics.power.typeChart(attackType, targetType2) > 1 then
        return 0.75
    end
    return 1
end

local function multiplierFilter(attackType, targetType1, targetType2)
    return multiplierSolidRock(attackType, targetType1, targetType2)
end

local function multiplierStormDrain(attackType, targetType1, targetType2)
    return multSpecificType(attackType, codes.TYPE.Water)
end

local ABILITY_MULTIPLIERS = {
    [codes.ABILITY.ThickFat] = multiplierThickFat,
    [codes.ABILITY.VoltAbsorb] = multiplierVoltAbsorb,
    [codes.ABILITY.WaterAbsorb] = multiplierWaterAbsorb,
    [codes.ABILITY.LightningRod] = multiplierLightningRod,
    [codes.ABILITY.WonderGuard] = multiplierWonderGuard,
    [codes.ABILITY.Levitate] = multiplierLevitate,
    [codes.ABILITY.FlashFire] = multiplierFlashFire,
    [codes.ABILITY.DrySkin] = multiplierDrySkin,
    [codes.ABILITY.Heatproof] = multiplierHeatproof,
    [codes.ABILITY.MotorDrive] = multiplierMotorDrive,
    [codes.ABILITY.SolidRock] = multiplierSolidRock,
    [codes.ABILITY.Filter] = multiplierFilter,
    [codes.ABILITY.StormDrain] = multiplierStormDrain,
}

function mechanics.power.abilityMultiplier(attackType, targetType1, targetType2, ability)
    local targetType1 = targetType1 or codes.TYPE.None
    local targetType2 = targetType2 or codes.TYPE.None
    local multFunction = ABILITY_MULTIPLIERS[ability]
    return multFunction and multFunction(attackType, targetType1, targetType2) or 1
end

-- Functions for calculating a damage multiplier due to certain weather conditions
-- All the functions take the attack type
local function multiplierSunny(attackType)
    return multSpecificType(attackType, codes.TYPE.Fire, 1.5)
        * multSpecificType(attackType, codes.TYPE.Water, 0.5)
end

local function multiplierCloudy(attackType)
    if attackType == codes.TYPE.None or attackType == codes.TYPE.Normal then
        return 1
    end
    return 0.75
end

local function multiplierRain(attackType)
    return multSpecificType(attackType, codes.TYPE.Water, 1.5)
        * multSpecificType(attackType, codes.TYPE.Fire, 0.5)
end

local function multiplierFog(attackType)
    return multSpecificType(attackType, codes.TYPE.Electric, 0.5)
end

local WEATHER_MULTIPLIERS = {
    [codes.WEATHER.Sunny] = multiplierSunny,
    [codes.WEATHER.Cloudy] = multiplierCloudy,
    [codes.WEATHER.Rain] = multiplierRain,
    [codes.WEATHER.Fog] = multiplierFog,
}

function mechanics.power.weatherMultiplier(attackType, weather)
    local weather = weather or codes.WEATHER.Clear
    local multFunction = WEATHER_MULTIPLIERS[weather]
    return multFunction and multFunction(attackType) or 1
end

-- Functions for calculating a damage multiplier due to *sport conditions
-- All the functions take the attack type
local function multiplierMudSport(attackType)
    return multSpecificType(attackType, codes.TYPE.Electric, 0.5)
end

local function multiplierWaterSport(attackType)
    return multSpecificType(attackType, codes.TYPE.Fire, 0.5)
end

function mechanics.power.sportMultiplier(attackType, mudSport, waterSport)
    local mult = 1
    if mudSport then
        mult = mult * multiplierMudSport(attackType)
    end
    if waterSport then
        mult = mult * multiplierWaterSport(attackType)
    end
    return mult
end

-- Extract a primary/secondary type from a single type/dual type input
local function extractTypes(typeList)
    local typeList = (type(typeList) == 'table') and typeList or {typeList}
    return typeList[1], typeList[2] or codes.TYPE.None
end

-- Extract a primary/secondary ability from a nil/single/dual ability input
local function extractAbilities(abilityList)
    local abilityList = abilityList or codes.ABILITY.None
    local abilityList = (type(abilityList) == 'table') and abilityList or {abilityList}
    return abilityList[1], abilityList[2] or codes.ABILITY.None
end

-- Calculate a damage heuristic of (multiplier) * (power) that doesn't only
-- requires visible information
function mechanics.power.calcDamageHeuristic(movePower,
    moveType, attackerTypes, defenderTypes, defenderAbilities,
    weather, mudSport, waterSport, erraticPlayer)
    -- Starting damage heuristic
    local heuristic = movePower

    -- Unpack types/abilities
    local attackerType1, attackerType2 = extractTypes(attackerTypes)
    local defenderType1, defenderType2 = extractTypes(defenderTypes)
    local defenderAbility1, defenderAbility2 = extractAbilities(defenderAbilities)
    -- Don't count the same ability twice
    if defenderAbility1 == defenderAbility2 then defenderAbility2 = codes.ABILITY.None end

    -- STAB
    if (moveType == attackerType1 or moveType == attackerType2)
        and moveType ~= codes.TYPE.None then
        heuristic = heuristic * 1.5
    end

    -- Type effectiveness
    heuristic = heuristic * mechanics.power.typeEffectiveness(
        moveType, defenderType1, defenderType2, erraticPlayer)

    -- Special ability effects
    local abilityMult1 = mechanics.power.abilityMultiplier(
        moveType, defenderType1, defenderType2, defenderAbility1)
    local abilityMult2 = mechanics.power.abilityMultiplier(
        moveType, defenderType1, defenderType2, defenderAbility2)
    if abilityMult1 < 0 and abilityMult2 < 0 then
        -- If both multipliers are negative, use the one with larger absolute value
        local mult = (abilityMult1 < abilityMult2) and abilityMult1 or abilityMult2
        heuristic = heuristic * mult
    else
        -- Otherwise, apply both multipliers
        heuristic = heuristic * abilityMult1 * abilityMult2
    end

    -- Weather effects
    heuristic = heuristic * mechanics.power.weatherMultiplier(moveType, weather)

    -- Mud/Water Sport effects
    heuristic = heuristic * mechanics.power.sportMultiplier(moveType, mudSport, waterSport)

    return heuristic
end