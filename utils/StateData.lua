-- Class for representing state data repeatedly accessed from memory, with possible caching

StateData = {}

-- Flag for whether caching should be used or not. Defaults to true
StateData.doesCache = true
-- The actual cached data
StateData.cache = nil
-- Flag for whether the data is stale, and the current cache should be dropped
StateData.isStale = false

function StateData:new(doesCache)
    obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.doesCache = doesCache
    return obj
end

-- Abstract method. Actually reading the data from memory
function StateData:read()
    error('Not implemented', 2)
end

-- Flag the data for reloading upon the next access
function StateData:flagForReload()
    self.isStale = true
end

-- Calling the table returns the data, with potential caching functionality
function StateData.__call(self)
    -- Read new data only if necessary
    local data = self.cache
    if not self.doesCache or self.cache == nil or self.isStale then   
        data = {self.read()}    -- Wrap in a table to handle multiple outputs
        -- Cache if caching is enabled
        if self.doesCache then
            self.cache = data
        end
    end
    return unpack(data) -- Unwrap packed data with possibly multiple outputs
end

return StateData