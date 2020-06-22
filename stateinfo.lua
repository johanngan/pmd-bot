-- Reading state info from memory

require 'statemodel'

stateinfo = {}

-- Rough indicator of whether or not the game is accepting input
function stateinfo.canAct()
    return memory.readbyte(0x021BA62B) == 0
end

function stateinfo.loadState()
    print('loadState()')
    return {dungeon={floor=1}}
end

function stateinfo.reloadEveryFloor(state)
    print('reloadEveryFloor()')
    return state
end

function stateinfo.reloadEveryTurn(state)
    print('reloadEveryTurn()')
    return state
end

return stateinfo