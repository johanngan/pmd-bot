-- String manipulation utilities
stringutils = {}

-- Split a string by one or more delimeters into an array of substrings
-- delim is string concatenation of 1-character delimeters
function stringutils.split(str, delim)
    local delim = delim or ' '
    substrs = {}
    for substr in string.gmatch(str .. delim, '([^' .. delim .. ']*)' .. delim) do
        table.insert(substrs, substr)
    end
    return substrs
end

return stringutils