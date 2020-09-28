require 'string'

local function isArray(table)
    local i = 0
    for _ in pairs(table) do
        i = i + 1
        if table[i] == nil then
            return false
        end
    end
    return true
end

-- Pretty printing for a nested table
local INDENT_SIZE = 6
function printnested(table, baseIndent)
    local baseIndent = baseIndent or 0
    local spaces = string.rep(' ', baseIndent)

    if type(table) ~= 'table' then
        print(spaces .. tostring(table))
        return
    end

    local tableIsArray = isArray(table)
    local iter = tableIsArray and ipairs or pairs
    for key, val in iter(table) do
        if type(val) == 'table' then
            if tableIsArray then
                print(spaces .. '#' .. tostring(key) .. '. ')
            else
                print(spaces .. tostring(key) .. ':')
            end
            printnested(val, baseIndent + INDENT_SIZE)
        else
            if tableIsArray then
                print(spaces .. '#' .. tostring(key) .. '. ' .. tostring(val))
            else
                print(spaces .. tostring(key) .. '=' .. tostring(val))
            end
        end
    end
end