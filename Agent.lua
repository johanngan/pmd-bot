-- Class for deciding on what actions to take based on the current state

require 'codes.direction'
require 'actions'

require 'jumper.grid'
require 'jumper.pathfinder'

Agent = {}

-- This is just boilerplate code for the class
function Agent:new(state)
    obj = {}
    setmetatable(obj, self)
    self.__index = self
    self:init(state)
    return obj
end

-- This function will be called just once when the bot starts up.
function Agent:init(state)
    -- If you want your bot to have a state or a memory, initialize stuff here!
end

-- Perform some actions based on the current state of the dungeon (and the bot's own state)
function Agent:act(state)
    print('act()')
    actions.nothing()
end