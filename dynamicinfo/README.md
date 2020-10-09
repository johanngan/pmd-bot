# State information

State information is read directly from RAM. The three primary files are:

- [`stateinfo.lua`](stateinfo.lua), which lazily reads dungeon information such as the dungeon layout, entities in the dungeon, and the player's bag.
- [`visibleinfo.lua`](visibleinfo.lua), which filters the full state information from `stateinfo` into a model containing only information that would be accessible to a human player.
- [`menuinfo.lua`](menuinfo.lua), which reads information related to menuing, such as the current menu open and the position of the menu cursor.

## The `StateData` class
The [`StateData` class](StateData.lua) handles caching and lazy reading of dungeon information. These objects form the basis of the dungeon state model used by the bot to access environmental information (through the variables `state` and `visible` in [`Agent:act(state, visible)`](../Agent.lua)). All `StateData` instances behave as follows:

- When called, they return the data they represent.
- Have the field `doesCache` that determines whether or not they should cache their data after the first read. This defaults to true, but can be set in the constructor.
- Store any cached data in the `cache` field.
- Have an internal flag `isStale` that controls if the cache should be refreshed upon the next call. This should be set to true by calling the `flagForReload()` method.
- Implement a `read()` method that retrieves the necessary data from memory (without regards to any caching behavior).

## The dungeon state model
The bot accesses the entire dungeon state as a single object (`stateinfo.state`), defined in [`stateinfo.lua`](stateinfo.lua). The data is organized in a tree structure with the following format:

- `state`: The state model object
    - `dungeon`: Subcontainer for "external" information
        - `dungeonID()`: The [dungeon ID](../codes/dungeon.lua) of the current dungeon
        - `visibilityRadius()`: How far away the player can see enemies in a dark hallway. Also controls how many tiles around the leader get revealed on the map during exploration.
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
            - `luminous()`: Flag for whether the floor is luminous (no darkness, with floor layout and enemies visible)
            - `darkness()`: Flag for whether the floor is dark (affects visibility in halls)
        - `counters`: Subcontainer for "dungeon counters" that tick every turn
            - `wind()`: Turns left before the dungeon wind blows you out
            - `weatherDamage()`: Turns left before getting damaged by weather, if applicable. Counts from 9 to 0, damage occurs when it resets to 9.
            - `enemySpawn()`: Counter for new enemy spawns in the dungeon.
    - `player`: Subcontainer for "internal" information about the player
        - `team()`: Alias for `state.dungeon.entities.team()`
        - `leader()`: Alias for the first team member
        - `money()`: Amount of money carried
        - `bag()`: Ordered list of items currently in the bag
        - `bagCapacity()`: Maximum number of items the player can carry in the bag
        - `canSeeEnemies()`: Flag for whether the player can see all enemies on the floor
        - `canSeeItems()`: Flag for whether the player can see all items on the floor
        - `canSeeTrapsAndHiddenStairs()`: Flag for whether the player can see unrevealed traps and hidden stairs
        - `canSeeStairs()`: Flag for whether the player can see location of the stairs (both normal and hidden) without having found them through exploration

Nodes with parentheses after their names are `StateData` objects, whose value should be accessed by calling them. Otherwise, they're just normal table fields (accessed without a call).

### Tiles
Returned in a grid by the `layout()` field. Tiles have the following fields:

- `terrain`: The tile's [terrain code](../codes/terrain.lua)
- `isJunction`: Flag for whether or not the tile is a junction (includes the exits of a room, and branch points in hallways)
- `inShop`: Flag for whether or not the tile is in a Kecleon shop
- `inMonsterHouse`: Flag for whether or not the tile is in a Monster House
- `isStairs`: Flag for whether or not the tile is a floor exit (includes normal stairs, hidden stairs, and Warp Zones)
- `visibleOnMap`: Flag for whether or not the tile is visible on the player's map
- `visited`: Flag for whether or not the tile has been visited by the player
- `room`: The ID of the room the tile is in. Will be -1 if in a hallway.

### Monsters
Returned in a list by the `team()` and `enemies()` fields, and also returned by the `leader()` field. Monsters have the following structure:

- `xPosition`: The monster's _x_ position in the dungeon
- `yPosition`: The monster's _y_ position in the dungeon
- `isEnemy`: Flag for whether or not the monster is an enemy
- `isLeader`: Flag for whether or not the monster is the party leader
- `isAlly`: Flag for whether or not an "enemy" is actually an ally (appears yellow on the map)
- `isShopkeeper`: Flag for whether or not the monster is a (still friendly) Kecleon shopkeeper
- `direction`: The [direction](../codes/direction.lua) that the monster is facing
- `heldItemQuantity`: The quantity of the monster's held item, if applicable
- `heldItem`: The [item ID](../codes/item.lua) of the monster's held item
- `belly`: The amount of belly the monster has
- `features`: Mostly stuff on the "Features" page in-game
    - `species`: The [species ID](../codes/species.lua)
    - `apparentSpecies`: The apparent [species ID](../codes/species.lua). Normally the same as `species`, but can differ if the monster used Transform.
    - `gender`: The [gender ID](../codes/gender.lua). Note that gender is not usually random, and will typically be set to its default for the species.
    - `primaryType`: The [type ID](../codes/type.lua) of the monster's primary type
    - `secondaryType`: The [type ID](../codes/type.lua) of the monster's secondary type
    - `primaryAbility`: The [ability ID](../codes/ability.lua) of the monster's primary ability
    - `secondaryAbility`: The [ability ID](../codes/ability.lua) of the monster's secondary ability
- `stats`: Mostly stuff seen on the "Stats" page in-game
    - `level`: The monster's level
    - `IQ`: The monster's IQ stat
    - `HP`: The monster's current HP
    - `maxHP`: The monster's maximum HP
    - `attack`: The monster's Attack stat
    - `specialAttack`: The monster's Special Attack stat
    - `defense`: The monster's Defense stat
    - `specialDefense`: The monster's Special Defense stat
    - `experience`: The amount of experience the monster has
    - `modifiers`: Table of stat modifiers. For most stats (except speed), the normal value is 10, and it goes up to 20 and down to 0.
        - `attackStage`: The monster's Attack stage
        - `specialAttackStage`: The monster's Special Attack stage
        - `defenseStage`: The monster's Defense stage
        - `specialDefenseStage`: The monster's Special Defense stage
        - `accuracyStage`: The monster's accuracy stage
        - `evasionStage`: The monster's evasion stage
        - `speedStage`: The monster's speed stage. The normal value is 1, and it goes up to 4 and down to 0.
        - `speedCounters`: Lists of "speed counters" that tick down to 0. The current speed stage is equal to `(# nonzero up) - (# nonzero down)`, but kept in the range 0-4.
            - `up`: List of the 5 "up" counters
            - `down`: List of the 5 "down" counters
- `statuses`: List of status effects on the monster
- `moves`: List of the monster's moves

#### Statuses
Stored in a list in a monster's `statuses` field. Statuses have the following (nil if not applicable) fields:

- `statusType`: The [status ID](../codes/status.lua)
- `turnsLeft`: The number of turns left of the status
- `effectCountdown`: The number of turns left for a recurring effect of the status to occur, such as damage or healing

Note: the Stockpile status is special, and has the field `stage` that holds the stockpile stage.

#### Moves
Stored in a list in a monster's `moves` field. Moves have the following fields:

- `subsequentInLinkChain`: Flag for whether or not the move is in a link chain and isn't the starting move
- `isSet`: Flag for whether or not the move is set
- `isLastUsed`: Flag for whether or not the move was the last one used (important for Encore)
- `isDisabled`: Flag for whether or not the move is disabled (e.g. by Torment)
- `isSealed`: Flag for whether or not the move is sealed (e.g. by a Seal Trap)
- `moveID`: The [move ID](../codes/move.lua)
- `PP`: The amount of PP left for the move
- `ginsengBoost`: The number of Ginseng boosts on the move

### Items
Returned in a list by the `items()` and `bag()` fields. Items have the following fields:

- `xPosition`: The item's _x_ position in the dungeon, if on the ground
- `yPosition`: The item's _y_ position in the dungeon, if on the ground
- `inShop`: Flag for whether or not the item is in a Kecleon shop
- `isSticky`: Flag for whether or not the item is sticky
- `isSet`: Flag for whether or not the item is set, if in the bag
- `heldBy`: Index of the party member holding the item, if in the bag
- `amount`: Amount code, if applicable. Note: seems like for Poké this value doesn't correspond to the literal amount.
- `itemType`: The [item ID](../codes/item.lua)
- `sprite`: The item sprite when the item is on the floor
    - `type`: The [item sprite ID](../codes/itemSprite.lua)
    - `color`: The main [color ID](../codes/color.lua) of sprite

### Traps
Returned in a list by the `traps()` field. Traps have the following fields:

- `xPosition`: The trap's _x_ position in the dungeon
- `yPosition`: The trap's _y_ position in the dungeon
- `isRevealed`: Flag for whether or not the trap is revealed to the player
- `trapType`: The [trap ID](../codes/trap.lua)
- `isTriggerableByTeam`: Whether or not the trap will trigger when a team member steps on it
- `isTriggerableByEnemies`: Whether or not the trap will trigger when an enemy steps on it

## Refreshing
A lot of the dungeon state model uses caching, so that the bot doesn't need to reload the entire dungeon state every turn. Information to be reloaded every turn is designated in `stateinfo.reloadEveryTurn()`, while information to be reloaded only once per floor is designated in `stateinfo.reloadEveryFloor()`.

## The _visible_ dungeon state model
The bot can also access the _visible_ dungeon state as a single object (`visibleinfo.state`), defined in [`visibleinfo.lua`](visibleinfo.lua). The data model follows almost exactly the same format as the full dungeon state object (`stateinfo.state`), except with fields containing inaccessible information set to `nil`. In most cases, only leaf nodes in the state model (non-table fields) are set to `nil`, so as to avoid causing errors in code from accessing fields in invalid subtables. Notable exceptions to this general format are described in the following sections.

### Removed fields
Certain fields are completely inaccessible to the player, and as such are removed entirely from the state model in `visibleinfo.state`. Removed fields include:
- `dungeon.conditions.naturalWeather()`
- `dungeon.conditions.weatherTurnsLeft()`
- `dungeon.counters.enemySpawn()`

### Modified fields
A few fields are modified from `stateinfo.state` because their full specifications are inaccessible to the player, but it does not make sense to simply remove access to certain fields. Modified fields include:
- `dungeon.conditions.mudSport()` takes the place of `dungeon.conditions.mudSportTurnsLeft()`. The modified field is a boolean flag for whether or not Mud Sport is active.
- `dungeon.conditions.waterSport()` takes the place of `dungeon.conditions.waterSportTurnsLeft()`. The modified field is a boolean flag for whether or not Water Sport is active.
- `dungeon.counters.windWarnings()` takes the place of `dungeon.counters.wind()`. The modified field is the number of warnings the player has received about the approaching wind.
- `dungeon.counters.turnsSinceWeatherDamage()` takes the place of `dungeon.counters.weatherDamage()`. The modified field is the number of turns that have passed since the last round of passive damage from inclement weather.

### Variable-length array fields
Empty tables already have a well-defined meaning with variable-length array fields. As such, they will instead be set to `nil` in `visibleinfo.state` if their values are unknown. The following fields are nullable variable-length arrays:
- `monster.statuses`
- `monster.moves`
