-- Utility for registering multiple exit functions

require 'table'

scriptexit = {}
local _exitFunctions = {}

function scriptexit.registerexit(fn)
    if not fn then
        -- Clear the exit functions
        _exitFunctions = {}
        emu.registerexit(nil)
        return
    end

    table.insert(_exitFunctions, fn)
    emu.registerexit(function()
        for _, exitFn in ipairs(_exitFunctions) do exitFn() end
    end)
end
