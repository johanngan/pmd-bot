require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for weather IDs, according to the internal files
codes.WEATHER, codes.WEATHER_NAMES = enum.register({
    'Clear',
    'Sunny',
    'Sandstorm',
    'Cloudy',
    'Rain',
    'Hail',
    'Fog',
    'Snow',
}, 0, 'weather condition')