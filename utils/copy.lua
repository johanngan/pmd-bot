-- Table copying code from https://gist.github.com/tylerneylon/81333721109155b2d244
copy = {}

-- Simple function if metatables and self-referencing tables aren't used
function copy.deepcopySimple(obj)
    if type(obj) ~= 'table' then return obj end
    local result = {}
    for k, v in pairs(obj) do
        result[copy.deepcopySimple(k)] = copy.deepcopySimple(v)
    end
    return result
end

-- More thorough function that preserves metatables and handles self references
function copy.deepcopy(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
  
    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do
        res[copy.deepcopy(k, s)] = copy.deepcopy(v, s)
    end
    return setmetatable(res, getmetatable(obj))
end

return copy