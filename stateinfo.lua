-- Reading state info from memory

require 'statemodel'

stateinfo = {}

function stateinfo.canAct()
    print('canAct()')
    return true
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