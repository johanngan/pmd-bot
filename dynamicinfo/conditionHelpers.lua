-- Helpers for reading floor-wide conditions from memory

require 'math'

local conditionHelpers = {}

local clearTurns = 0x021C6A6E   -- Start of the "turns of weather left" block
local permaClearTurns = 0x021C6A7E  -- Start of the "artificial permaweather" block
local weatherTurnsSize = 2  -- 2 bytes each
function conditionHelpers.weatherTurnsLeft(weatherType, naturalWeatherType)
    -- If the current weather matches the natural weather or it's permaweather,
    -- return "infinity"
    if (weatherType == naturalWeatherType or
        memory.readwordunsigned(permaClearTurns + weatherType*weatherTurnsSize) > 0) then
        return math.huge
    end
    -- Otherwise, return the actual (finite) turn counter value
    return memory.readwordunsigned(clearTurns + weatherType*weatherTurnsSize)
end

return conditionHelpers