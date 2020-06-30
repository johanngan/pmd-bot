# In-game actions

This module contains functions that perform the necessary inputs to perform a various high-level actions in game, such as using a move or consuming an item. To make the bot perform a certain action, just call the corresponding function with any necessary arguments (at a time that's appropriate, of course, otherwise it might cause unintended behavior). If possible, you should avoid directly dealing with emulator input.

All exposed actions in this module have an optional `verbose` flag (default: `false`) as their final parameter. If set to true, the bot will report a message when it performs the action.

- The [`basicactions`](basicactions.lua) submodule contains common "basic" actions that execute a sequence of inputs in game without much decision logic. These action functions have no return values.
- The [`smartactions`](smartactions.lua) submodule contains useful actions with more advanced decision-making behind them, and only actually perform the action if certain in-game conditions are met. These action functions return `true` if the action was successfully performed and `false` otherwise.