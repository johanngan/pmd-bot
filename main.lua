-- Main dispatcher for the bot

require 'utils.nicknames'
require 'utils.messages'
require 'dynamicinfo.versioninfo'
require 'dynamicinfo.stateinfo'
require 'dynamicinfo.visibleinfo'
require 'dynamicinfo.menuinfo'
local Agent = require 'agent.Agent'

-- Confirm that the version is supported
versioninfo.validateVersion()

-- Temporarily set the leader's nickname to "Lua"
nicknames.setLeaderNicknameTemp('Lua')

-- The state
local state = stateinfo.state
local visible = visibleinfo.state
-- Needed to detect a floor change
local currentFloor = 0
local currentWind = -1
-- Agent that decides what actions to take every turn
local bot = Agent:new(state, visible)
messages.report(bot.name .. ' engaged.')
-- Pause of a few frames after completing an action; to give time for internal stuff
-- in memory to update right after input
local ACTION_COOLDOWN_FRAMES = 3

-- Main execution loop for the bot
while true do
    emu.frameadvance()
    -- If the bot cannot act because of in-game animation, loading, etc.,
    -- then don't do anything; just wait
    if state.canAct() then
        -- If there's been a floor change, do necessary updates to the dungeon state
        -- Alternatively, since the floor might not change with hidden stairs, as a
        -- backup check if the wind counter is more than it was before
        if currentFloor ~= state.dungeon.floor() or
            state.dungeon.counters.wind() > currentWind then
            currentFloor = state.dungeon.floor()
            state = stateinfo.reloadEveryFloor(state)
            visible = visibleinfo.reloadEveryFloor(visible)
            emu.frameadvance()  -- intermediate frame advance to combat lag
        end
        currentWind = state.dungeon.counters.wind()
        -- Do updates for frequently changing things whenever the player has control
        state = stateinfo.reloadEveryTurn(state)
        visible = visibleinfo.reloadEveryTurn(visible)
        emu.frameadvance()

        bot:setupActFinalize(state, visible)
        emu.frameadvance()

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