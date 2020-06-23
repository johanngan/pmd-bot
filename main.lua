-- Main dispatcher for the bot

require 'stateinfo'
require 'menuinfo'
require 'actions'
require 'decisions'
require 'utils.execute'

-- Convenience function for reporting messages on screen
-- emu.message crashes the emulator for some reason
function report_message(message)
    local MESSAGE_X = 0
    local MESSAGE_Y = -190
    gui.text(MESSAGE_X, -MESSAGE_Y, message)
end

report_message('Bot engaged.')

-- The state
local state = stateinfo.state
-- Needed to detect a floor change
local currentFloor = 0
-- Queue of actions for the bot the execute
local actionQueue = {}
-- Pause of a few frames after completing an action; to give time for internal stuff
-- in memory to update right after input
local ACTION_COOLDOWN_FRAMES = 20

-- Main execution loop for the bot
while true do
    emu.frameadvance()
    -- If the bot cannot act because of in-game animation, loading, etc.,
    -- then don't do anything; just wait
    if state.canAct() then
        -- If there's been a floor change, do necessary updates to the dungeon state
        if currentFloor ~= state.dungeon.floor() then
            currentFloor = state.dungeon.floor()
            state = stateinfo.reloadEveryFloor(state)
            emu.frameadvance()  -- intermediate frame advance to combat lag
        end
        -- Do updates for frequently changing things whenever the player has control
        state = stateinfo.reloadEveryTurn(state)
        emu.frameadvance()

        -- Decide how to act based on the state and the current action queue
        actionQueue = decisions.decideActions(state, actionQueue)
        emu.frameadvance()

        -- Execute the next action in the queue
        actionQueue = execute.stepActionQueue(actionQueue)
        -- Cooldown
        for i=1,ACTION_COOLDOWN_FRAMES do
            emu.frameadvance()
        end
    elseif menuinfo.messageIsOpen() then
        -- If there seems to be a menu open, then maybe the canAct flag got locked.
        -- Try pressing B to regain control
        joypad.set({B=true})
        emu.frameadvance()
    end
end