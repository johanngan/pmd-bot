-- Decision function for each turn

require 'actions'

decisions = {}

function decisions.decideActions(state, actionQueue)
    print('decideActions()')
    return {function() print('action') end}
end

return decisions