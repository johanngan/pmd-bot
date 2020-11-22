-- Class for representing lookup tables, which read specified data from
-- lookup table files in csv format and cache it for subsequent lookups.

require 'io'
require 'math'
require 'string'
require 'table'

require 'utils.containers'
require 'utils.stringutils'

LookupTable = {}

-- Path to the underlying table file
LookupTable.filepath = nil
-- Current file handle, if open
LookupTable.file = nil
-- Buffer size in bytes for chunked file reading. Reading lines in chunks
-- improves performance over reading single lines at a time
LookupTable.bufferSize = nil
-- Cached data from previous lookups
LookupTable.cache = nil
-- Delimeter between fields
LookupTable.delimeter = nil

function LookupTable:new(filepath, delimeter)
    obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.filepath = filepath
    obj.file = nil
    obj.bufferSize = 2^13   -- 8 kB
    obj.cache = {}
    obj.delimeter = delimeter or ','
    return obj
end

-- Flush the cache
function LookupTable:flushCache()
    self.cache = {}
end

-- Open the underlying file
function LookupTable:open()
    self.file = assert(io.open(self.filepath, "r"))
end

-- Close the underlying file
function LookupTable:close()
    assert(self.file:close())
    self.file = nil
end

-- Translate a primary key to row number in the table file, where
-- row number should be 0-indexed
function LookupTable:keyRow(key)
    -- Default: Assume the keys are integers starting from 0,
    -- and that the table file has a header row that should be skipped
    return key + 1
end

local NUMBER_TYPE = "number"
local INTEGER_TYPE = "integer"
local STRING_TYPE = "string"
local BOOLEAN_TYPE = "boolean"
local function interpretDataType(dtype)
    -- If the data type string ends in a question mark, the field is nullable
    local nullable = false
    if string.sub(dtype, -1) == '?' then
        nullable = true
        -- Strip off the question mark
        dtype = string.sub(dtype, 1, -2)
    end

    local dtype = string.lower(dtype)   -- Case-insensitive
    local numberTypeNames = {NUMBER_TYPE, "numeric", "n", "float", "f", "double"}
    local integerTypeNames = {INTEGER_TYPE, "int", "i", "d"}
    local stringTypeNames = {STRING_TYPE, "str", "s", "text"}
    local booleanTypeNames = {BOOLEAN_TYPE, "bool", "b"}

    local allTypes = {numberTypeNames, integerTypeNames, stringTypeNames, booleanTypeNames}
    for _, typeNames in ipairs(allTypes) do
        if containers.arrayContains(typeNames, dtype) then
            return typeNames[1], nullable
        end
    end
    -- Failed to match any types
    return nil, nullable
end

local function strToBool(strval)
    -- Try converting to a number first
    local flag = tonumber(strval)
    if flag ~= nil then
        return flag ~= 0
    end

    -- String wasn't a number. Look for appropriate string values instead
    local strvalLower = string.lower(strval) -- Case-insensitive
    local trueNames = {"true", "t", "yes", "y"}
    local falseNames = {"false", "f", "no", "n"}
    if containers.arrayContains(trueNames, strvalLower) then return true end
    if containers.arrayContains(falseNames, strvalLower) then return false end

    -- Nothing works. Error out
    error('Could not cast "' .. strval .. '" to boolean')
end

-- Parse a single piece of data in string format, given its field name.
-- Returns a cleaned field name and the data value
function LookupTable:parseField(fieldStr, fieldname)
    -- If the fieldname is tagged with a data type (with the suffix ":%s*<dtype>"),
    -- then parse it as such.
    local fname, dtypeStr = string.match(fieldname, "(.*%S)%s*:%s*([^:%s]+)$")
    if dtypeStr ~= nil then
        local dtype, nullable = interpretDataType(dtypeStr)
        -- If nullable and the string is empty, return nil for the value
        if nullable and fieldStr == '' then
            return fname, nil
        end

        if dtype == NUMBER_TYPE or dtype == INTEGER_TYPE then
            -- Convert to number
            local n = tonumber(fieldStr) or error(
                'Could not convert "' .. fieldStr .. '" to number')
            -- If specified, floor to integer
            if dtype == INTEGER_TYPE then n = math.floor(n) end
            return fname, n
        elseif dtype == STRING_TYPE then
            return fname, fieldStr
        elseif dtype == BOOLEAN_TYPE then
            return fname, strToBool(fieldStr)
        else
            error("Invalid data type " .. dtypeStr)
        end
    end
    -- No valid data type specified. Assume numeric data,
    -- but fall back to string data if the conversion fails
    return fieldname, tonumber(fieldStr) or fieldStr
end

-- Parse a single row of data in string format (newlines stripped) into an object,
-- given an array of field names
function LookupTable:parseRow(rowStr, fieldnames)
    local data = {}
    for i, field in ipairs(stringutils.split(rowStr, self.delimeter)) do
        local fname, fvalue = self:parseField(field, fieldnames[i])
        data[fname] = fvalue
    end
    return data
end

-- Actually reading data from file, given a list of primary keys to read
function LookupTable:read(keys)
    local data = {} -- List of data to return

    if #keys == 0 then
        return data
    end

    -- Convert the keys into row numbers
    local rowNumbersIndexes = {}
    local rowNumbers = {}
    for i, key in ipairs(keys) do
        table.insert(rowNumbersIndexes, i)
        table.insert(rowNumbers, self:keyRow(key))
    end
    -- Sort the row numbers in ascending order, keeping track of the index
    -- in the rowNumbers array.
    table.sort(rowNumbersIndexes,
        function(a, b) return rowNumbers[a] < rowNumbers[b] end
    )
    -- The first row number can't be 0 or smaller; 0 is the header row!
    if rowNumbers[rowNumbersIndexes[1]] <= 0 then
        error("Can't read data in row " .. rowNumbers[rowNumbersIndexes[1]])
    end

    self:open()

    local lineNumber = 0    -- Current line number (0-indexed)
    local targetRowNumberIndex = 1    -- Index of next row number to look out for (1-indexed)
    -- Read the field names from the header row
    local fieldnames = stringutils.split(self.file:read("*l"), self.delimeter)
    lineNumber = lineNumber + 1

    -- Read the data from the rows identified by the specified keys
    while true do
        -- Read bufferSize bytes + characters up to the end of the next line,
        -- if bufferSize doesn't exactly stop us at the end of a line
        local buffer, rest = self.file:read(self.bufferSize, "*l")
        if not buffer then break end -- Done
        -- Concatenate the "rest" line to the end of the buffer, putting
        -- the line feed back in to be consistent with the rest of the
        -- raw bytes read into the buffer
        if rest then buffer = buffer .. rest .. '\n' end
        -- If the buffer still doesn't end in a newline, we must have reached
        -- the end of the file. Append a newline for standardization
        if string.sub(buffer, -1) ~= '\n' then buffer = buffer .. '\n' end

        -- Count the number of newlines to determine how many rows are in the buffer
        _, newlines = string.gsub(buffer, '\n', '\n')
        local lastLineNumber = lineNumber + newlines - 1    -- Last line in the buffer
        -- Iterate over lines
        local bufferLineNumber = 0  -- Line number relative to the start of the buffer
        for line in string.gmatch(buffer, "([^\r\n]*)\r?\n") do
            if targetRowNumberIndex > #rowNumbersIndexes or
                rowNumbers[rowNumbersIndexes[targetRowNumberIndex]] > lastLineNumber then
                -- No more rows of interest in this buffer
                break
            end
            while rowNumbers[rowNumbersIndexes[targetRowNumberIndex]]
                == lineNumber + bufferLineNumber do
                -- This is a row of interest. Parse it, then increment the target row number index
                data[rowNumbersIndexes[targetRowNumberIndex]] = self:parseRow(line, fieldnames)
                targetRowNumberIndex = targetRowNumberIndex + 1
            end
            bufferLineNumber = bufferLineNumber + 1 -- The next line to read
        end
        lineNumber = lineNumber + newlines
    end

    self:close()

    -- If there are target rows that haven't been found, they must be invalid
    if targetRowNumberIndex <= #rowNumbersIndexes then
        error("Key not found: " .. keys[rowNumbersIndexes[targetRowNumberIndex]])
    end

    return data
end

-- Calling the table returns the data for a given key or list of keys,
-- and also caches it for later lookups
function LookupTable.__call(self, keys)
    local listInput = type(keys) == 'table'
    local keyList = listInput and keys or {keys}

    -- Determine which keys haven't been seen before
    local newKeys = {}
    for i, key in ipairs(keyList) do
        if self.cache[key] == nil then
            table.insert(newKeys, key)
        end
    end
    -- Read new data if necessary
    if #newKeys > 0 then
        -- Cache the new data
        for i, data in ipairs(self:read(newKeys)) do
            self.cache[newKeys[i]] = data
        end
    end

    -- Return results from the cache, which now definitely has all the
    -- necessary data
    local output = {}
    for _, key in ipairs(keyList) do
        table.insert(output, self.cache[key])
    end
    -- Unwrap the output if the input was a single key
    return listInput and output or output[1]
end

return LookupTable