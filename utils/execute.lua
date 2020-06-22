-- Utils to execute an action in the action queue
require 'table'

execute = {}

-- Execute an action. An action is either a function with no arguments,
-- or a list of {function, arguments}
function execute.executeAction(action)
    if type(action) == 'function' then
        -- Simple function: just run with no arguments
        action()
    elseif type(action) == 'table' then
        -- Function grouped with a possible argument list
        actionFn = action[1]
        args = action[2]
        if args == nil then
             -- No arguments
            actionFn()
        elseif type(args) ~= 'table' then
            -- Single argument
            actionFn(args)
        else
            -- Multiple arguments
            actionFn(unpack(args))
        end
    else
        error('Invalid action. An action must be either a function without arguments or' ..
            ' of the form {function}, {function, arg} or {function, {args}}', 2)
    end
end

-- Carry out the next action in the action queue
function execute.stepActionQueue(actionQueue)
    execute.executeAction(table.remove(actionQueue, 1))
    return actionQueue
end

return execute