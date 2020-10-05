require 'mechanics.LookupTable'

if mechanics == nil then
    mechanics = {}
end

mechanics.move = LookupTable:new('mechanics/data/move_data.csv')