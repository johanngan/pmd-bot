-----------------------------------------------------------------
-- NOTE: THIS FILE CONTAINS THE CODE FOR THE AGENT BASE CLASS. --
-- DO NOT MODIFY THIS FILE UNLESS YOU KNOW WHAT YOU'RE DOING.  --
-----------------------------------------------------------------

local BaseAgent = {}

-- This is just boilerplate code for the class. When subclassing BaseAgent,
-- create an instance with __instance__, then override the relevant methods
function BaseAgent:__instance__()
    obj = {}
    setmetatable(obj, self)
    self.__index = self
    self.name = 'Agent'
    -- Flag for whether or not a turn is ongoing. Set this in Agent:act() to
    -- indicate that its return does not indicate the end of a turn, and that
    -- the next call to Agent:act() is not starting on a fresh turn
    self.turnOngoing = false
    return obj
end

-- This function calls init and returns the class. Do NOT call this with BaseAgent,
-- since this does not actually instantiate a BaseAgent object with the correct
-- metatables. This is intended to be called with subclasses of BaseAgent, which
-- are actually pre-created BaseAgent instances (via __instance__).
function BaseAgent:new(state, visible)
    self:init(state, visible)
    return self
end

-- This function will be called once at startup. If you want your bot to retain
-- state or a memory, initialize stuff here!
function BaseAgent:init(state, visible)
end

-- This function will be called right before the act() method is called, unless the
-- turnOngoing flag is set. Change it to reset the bot state at the start of a turn.
function BaseAgent:setupTurn(state, visible)
end

-- This function will be called right after the act() method returns, unless the
-- turnOngoing flag is set. Change it to prepare or record data for the bot to
-- use in future turns.
function BaseAgent:finalizeTurn()
end

-- Perform some actions based on the current state of the dungeon (and the bot's own state)
-- This is a very simple sample strategy. Change it to fit your botting needs.
function BaseAgent:act(state, visible)
    error('Not implemented.')
end

-- This wraps act() with calls to setupTurn() and finalizeTurn() if
-- the turnOngoing flag is not set. It resets the turnOngoing flag to false
-- before calling act(), under the assumption that act() will set it explicitly
-- when needed.
function BaseAgent:setupActFinalize(state, visible)
    -- If this is a new turn, perform setup
    if not self.turnOngoing then self:setupTurn(state, visible) end
    -- Assume a turn will be consumed unless explicitly overridden from within act().
    self.turnOngoing = false
    -- Perform an action based on the current state.
    self:act(state, visible)
    -- If the turn is over, finalize
    if not self.turnOngoing then self:finalizeTurn() end
end

return BaseAgent