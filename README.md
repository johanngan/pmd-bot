# pmd-bot
PMD-Bot is a botting framework for _Pokémon Mystery Dungeon: Explorers of Sky_. You can use it to write fully autonomous dungeon bots! For example, you can write a bot that does runs of Mystery Dungeons without human input. Watch the [showcase video](https://www.youtube.com/watch?v=DqSmy8Cc5Ms)!

- PMD-Bot is written in [FCEUX Lua](https://tasvideos.github.io/fceux/web/help/fceux.html?LuaScripting.html) and runs on DeSmuME for Windows (Lua scripting is sadly not supported on DeSmuME for Mac/Linux).

## How it works
Broadly, PMD-Bot runs using a three-step process, repeated every turn:

1. Detect what's happening in the dungeon by read state information from RAM.
2. Make decisions on how to act based on the current state.
3. Make the necessary inputs (including menu navigation) in order to perform whatever action was decided on.

For a more detailed discussion, see [Writing a bot](#writing-a-bot).

## Dependencies
- [A modified version of the Jumper library](https://github.com/johanngan/Jumper) for pathfinding (included as a submodule of this repository).

## Installation
1. Retrieve the repository locally with the Jumper submodule (for example, by doing `git clone --recursive https://github.com/johanngan/pmd-bot.git` through the command line).
2. If you cloned the project but forgot to pull the submodule with the `--recursive` option, run `git submodule update --init` from within the PMD-Bot repository to set up the modified Jumper library.

## Usage
### Prerequisites
- Have Windows
- Install DeSmuME
- PMD-Bot is written for the **North American version of _Pokémon Mystery Dungeon: Explorers of Sky_**. No guarantees that it'll work on other versions.
- Before you can run any scripts, you'll need to set up Lua on DeSmuME. The [FCEUX Lua](https://tasvideos.github.io/fceux/web/help/fceux.html?LuaScripting.html) documentation is for the FCEUX emulator, not DeSmuME, but is mostly applicable.
    - If you need some help, here's a link to the [necessary Lua binaries](https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip/download). Extract the archive and copy `lua5.1.dll` and `lua51.dll` into the same directory as your DeSmuME executable file. After doing this, you should be able to run Lua scripts on DeSmuME.

### Writing a bot
Bots are defined through the `Agent` class, which is used by the main execution loop in [`main.lua`](main.lua). The `Agent:act()` method contains the main logic for the bot. This method is called every turn with the current dungeon information, and should take some action each turn in response to the environment. If you want to set up state information for your bot, you can do so in `Agent:new()`, which is called only once at instantiation. If you want to run any code at the beginning or end of each turn, right before or after `Agent:act()`, you can do so in `Agent:setupTurn()` and `Agent:finalizeTurn()`.

`Agent:setupTurn()` and `Agent:finalizeTurn()` will _not_ be called if the `Agent.turnOngoing` flag is set, so if you want an action in `Agent:act()` not to be treated as turn-ending, set the flag before returning. Note that the main loop will always reset `Agent.turnOngoing` to `false` before calling `Agent:act()` (i.e., it assumes by default that each call will consume a turn), so _you must explicitly set `Agent.turnOngoing` to `true` in `Agent:act()` every time you want to continue a turn_.

Note that since the return of `Agent:act()` may not necessarily signify the end of the turn (more events could still happen that change the state), `Agent:finalizeTurn()` should not rely on data that could dynamically change as the turn progresses, and should only be used to manipulate static data stored within the `Agent` instance.

This repository comes with example bots in the [`agent`](agent) directory. However, you can modify them or write new ones to suit your needs. To write a new bot, create a file that implements the `Agent` class (with `new(state, visible)`, `act(state, visible)`, `setupTurn(state, visible)`, and `finalizeTurn()` methods). To switch out the current bot with another, modify the `require` statement in [`main.lua`](main.lua) to use the file containing the desired bot.

The example bots make direct use of the following utilities:

- [Dungeon state information](dynamicinfo) is accessed through the _full_ `state` (`stateinfo.state`) and _visible_ `state` (`visibleinfo.state`) objects passed to `Agent:act()`.
- [Actions in game](actions) are performed using the `actions` module.
- [Internal ID codes](codes) are referenced from the `codes` module.
- [Game mechanics utilities](mechanics) are referenced from the `mechanics` module.
- [Other utilities](utils) include pathfinding and message reporting, which are handled in their respective submodules in `utils`.

Modifying [`Agent.lua`](agent/Agent.lua) should be sufficient for many use cases. However, if you need to change the nature of the main execution loop, you can also modify [`main.lua`](main.lua).

### Running a bot
These instructions assume the interface of DeSmuME 0.9.12, but hopefully they won't change much in future versions.

1. Start up _Pokémon Mystery Dungeon: Explorers of Sky (NA)_, and enter a dungeon (this you'll have to do manually).
2. In the DeSmuME "Tools" menu, select "Lua Scripting" -> "New Lua Script Window..."
3. In the window that just opened, click "Browse..." and select `main.lua` in the PMD-Bot directory.
4. The bot should start automatically. If not, start it by clicking "Run".
