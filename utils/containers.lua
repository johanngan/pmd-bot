-- Container utilities
containers = {}

function containers.arrayContains(array, value)
    for _, element in ipairs(array) do
        if element == value then return true end
    end
    return false
end

-- Double-ended queue implementation taken (mostly) from https://www.lua.org/pil/11.4.html
containers.Deque = {}
function containers.Deque:new()
    obj = {first = 0, last = -1}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function containers.Deque:pushFront(value)
    local first = self.first - 1
    self.first = first
    self[first] = value
end

function containers.Deque:pushBack(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

function containers.Deque:popFront()
    local first = self.first
    if first > self.last then error("deque is empty") end
    local value = self[first]
    self[first] = nil        -- to allow garbage collection
    self.first = first + 1
    return value
end

function containers.Deque:popBack()
    local last = self.last
    if self.first > last then error("deque is empty") end
    local value = self[last]
    self[last] = nil         -- to allow garbage collection
    self.last = last - 1
    return value
end

function containers.Deque:length()
    return self.last - self.first + 1
end

return containers