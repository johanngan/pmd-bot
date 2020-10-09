require 'mechanics.LookupTable'

if mechanics == nil then
    mechanics = {}
end

mechanics.species = LookupTable:new('mechanics/data/monster_data.csv')