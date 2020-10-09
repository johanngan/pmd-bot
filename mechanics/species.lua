require 'table'

require 'codes.species'
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