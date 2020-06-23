require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for menu names
codes.MENU, codes.MENU_NAMES = enum.register({
    'None',
    'MessageBox',
    'DialogueBox',
    'Main',
    'Moves',
    'MoveAction',
    'Bag',
    'ItemAction',
    'ItemFor',
    'Team',
    'LeaderAction',
    'TeammateAction',
    'IQ',
    'IQAction',
    'Tactics',
    'TacticsAction',
    'Others',
    'Ground',
    'Stairs',
    'Rest',
    'YesNo',
    'NewMove',
    'NewMoveAction',
}, 1, 'menu')