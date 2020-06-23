-- Simple enum implementation. Valid access returns a code, otherwise an error is raised
enum = {}

-- Return an enum table from a list of keys, with an optional starting index,
--  as well as a name for the entire enum (for error reporting only)
-- Also returns an inverse table
function enum.register(enumKeys, startIndex, enumName)
    local newEnum = {}
    local invTable = {}
    local i = startIndex or 1
    local enumName = enumName or 'enum'
    for _, name in ipairs(enumKeys) do
        -- Don't allow duplicates
        if newEnum[name] then
            error('Duplicate enum key "' .. name .. '"', 2)
        end
        newEnum[name] = i
        invTable[i] = name
        i = i + 1
    end
    setmetatable(newEnum, {__index = function(table, key)
        error('Invalid ' .. enumName .. ' name "' .. key .. '"', 2)
    end })
    return newEnum, invTable
end

return enum