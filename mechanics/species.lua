require 'table'

require 'codes.species'
require 'codes.mobility'
require 'codes.terrain'
require 'mechanics.LookupTable'

if mechanics == nil then
    mechanics = {}
end

mechanics.species = LookupTable:new('mechanics/data/monster_data.csv')

-- Generate lightweight, in-memory references for stateinfo/visibleinfo
if (mechanics.species.genders == nil
    or mechanics.species.types == nil
    or mechanics.species.abilities == nil) then

    mechanics.species.genders = {}
    mechanics.species.types = {}
    mechanics.species.abilities = {}

    local function genders(speciesInfo)
        return {[0] = speciesInfo.primaryGender, [1] = speciesInfo.secondaryGender}
    end

    local function types(speciesInfo)
        return {primary = speciesInfo.primaryType, secondary = speciesInfo.secondaryType}
    end

    local function abilities(speciesInfo)
        return {primary = speciesInfo.primaryAbility, secondary = speciesInfo.secondaryAbility}
    end

    local speciesCodes = {}
    for id=codes.SPECIES.None,codes.SPECIES.reserve_45 do
        table.insert(speciesCodes, id)
    end

    -- Read the full table into memory, extract just the gender/type info,
    -- then flush the cache to free up space again.
    local fullSpeciesList = mechanics.species(speciesCodes)
    for i, id in ipairs(speciesCodes) do
        mechanics.species.genders[id] = genders(fullSpeciesList[i])
        mechanics.species.types[id] = types(fullSpeciesList[i])
        mechanics.species.abilities[id] = abilities(fullSpeciesList[i])
    end
    mechanics.species:flushCache()
end

-- Functions specifying what kinds of terrain are walkable for a given mobility type
-- All the functions take in a terrain code and return true of false if the terrain
-- is walkable, or nil if it's uncertain. An optional final parameter specifies if
-- the dungeon has lava, which disambiguates the WaterOrLava terrain code.
local function walkableNormal(terrain, lava)
    return terrain == codes.TERRAIN.Normal
end

local function walkableUnused(terrain, lava)
    -- Who knows...
    return nil
end

local function walkableHovering(terrain, lava)
    return terrain == codes.TERRAIN.Normal
        or terrain == codes.TERRAIN.WaterOrLava
        or terrain == codes.TERRAIN.Chasm
end

local function walkableIntangible(terrain, lava)
    -- Can go through anything
    return true
end

local function walkableLava(terrain, lava)
    if terrain == codes.TERRAIN.WaterOrLava then return lava end
    return terrain == codes.TERRAIN.Normal
end

local function walkableWater(terrain, lava)
    if terrain == codes.TERRAIN.WaterOrLava then
        if lava ~= nil then
            return not lava
        else
            return nil
        end
    end
    return terrain == codes.TERRAIN.Normal
end

mechanics.species.walkable = {
    [codes.MOBILITY.Normal] = walkableNormal,
    [codes.MOBILITY.Unused0x01] = walkableUnused,
    [codes.MOBILITY.Hovering] = walkableHovering,
    [codes.MOBILITY.Intangible] = walkableIntangible,
    [codes.MOBILITY.Lava] = walkableLava,
    [codes.MOBILITY.Water] = walkableWater,
}