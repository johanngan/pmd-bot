-- Math utilities that aren't in the built-in module
require 'math'

mathutils = {}

function mathutils.round(x)
    return math.floor(x + 0.5)
end

function mathutils.sign(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end

return mathutils