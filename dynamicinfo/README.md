# State information

State information is read directly from RAM. The two primary files are:

- [`stateinfo.lua`](stateinfo.lua), which lazily reads dungeon information such as the dungeon layout, entities in the dungeon, and the player's bag.
- [`menuinfo.lua`](menuinfo.lua), which reads information related to menuing, such as the current menu open and the position of the menu cursor.

## The `StateData` class
The [`StateData` class](StateData.lua) handles caching and lazy reading of dungeon information. These objects form the basis of the dungeon state model used by the bot to access environmental information (through the variable `state` in [`Agent:act(state)`](../Agent.lua)). All `StateData` instances behave as follows:

- When called, they return the data they represent.
- Have the field `doesCache` that determines whether or not they should cache their data after the first read. This defaults to true, but can be set in the constructor.
- Store any cached data in the `cache` field.
- Have an internal flag `isStale` that controls if the cache should be refreshed upon the next call. This should be set to true by calling the `flagForReload()` method.
- Implement a `read()` method that retrieves the necessary data from memory (without regards to any caching behavior).

## The dungeon state model
The bot accesses the entire dungeon state as a single object (`stateinfo.state`), defined in [`stateinfo.lua`](stateinfo.lua). The data is organized in a tree structure with the following format:

- `state`: The state model object
    - `dungeon`: Subcontainer for "external" information
        - `floor()`: Current floor number
        - `layout()`: Grid of tiles on the floor, ordered by position. Access using `layout()[y][x]`.
        - `stairs()`: Location of stairs on the floor. Returns two values (x, y). Could be normal or hidden stairs.
        - `entities`: Subcontainer for entities in the dungeon
            - `team()`: Ordered list of monsters currently in the player's party
            - `enemies()`: Ordered list of monsters not in the player's party
            - `items()`: Ordered list of items on the floor
            - `traps()`: Ordered list of traps on the floor
            - `hiddenStairs()`: Hidden stairs on the floor. Will be `nil` if there are none.
        - `conditions`: Subcontainer for floor-wide conditions
            - `weather()`: The ID for the current weather condition
            - `naturalWeather()`: The weather that the floor will revert to if no artificial weather is in effect
            - `weatherTurnsLeft()`: Turns left for artificial weather, if applicable
            - `weatherIsNullified()`: Flag for whether Cloud Nine/Air Lock is in effect
            - `mudSportTurnsLeft()`: Turns left for the effects of Mud Sport. Will be 0 if Mud Sport is inactive.
            - `waterSportTurnsLeft()`: Turns left for the effects of Water Sport. Will be 0 if Water Sport is inactive.
            - `thiefAlert()`: Flag for whether you've stolen from Kecleon
            - `gravity()`: Flag for whether gravity is in effect
        - `counters`: Subcontainer for "dungeon counters" that tick every turn
            - `wind()`: Turns left before the dungeon wind blows you out
            - `weatherDamage()`: Turns left before getting damaged by weather, if applicable. Counts from 9 to 0, damage occurs when it resets to 9.
            - `enemySpawn()`: Counter for new enemy spawns in the dungeon.
    - `player`: Subcontainer for "internal" information about the player
        - `team()`: Alias for `state.dungeon.entities.team()`
        - `leader()`: Alias for the first team member
        - `money()`: Amount of money carried
        - `bag()`: Ordered list of items currently in the bag

Nodes with parentheses after their names are `StateData` objects, whose value should be accessed by calling them). Otherwise, they're just normal table fields (accessed without a call).

## Refreshing
A lot of the dungeon state model uses caching, so that the bot doesn't need to reload the entire dungeon state every turn. Information to be reloaded every turn is designated in `stateinfo.reloadEveryTurn()`, while information to be reloaded only once per floor is designated in `stateinfo.reloadEveryFloor()`.
