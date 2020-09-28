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
- [A modified version of the Jumper library](https://github.com/johanngan/Jumper) for pathfinding.

## Installation
1. Retrieve the repository locally (for example, by doing `git clone https://github.com/johanngan/pmd-bot.git` through the command line).
2. Retrieve the [modified Jumper library](https://github.com/johanngan/Jumper), and copy the `jumper/` directory into PMD-Bot's top-level directory (the same level as this README).

## Usage
### Prerequisites
- Have Windows
- Install DeSmuME
- PMD-Bot is written for the **North American version of _Pokémon Mystery Dungeon: Explorers of Sky_**. No guarantees that it'll work on other versions.
- Before you can run any scripts, you'll need to set up Lua on DeSmuME. The [FCEUX Lua](https://tasvideos.github.io/fceux/web/help/fceux.html?LuaScripting.html) documentation is for the FCEUX emulator, not DeSmuME, but is mostly applicable.
    - If you need some help, here's a link to the [necessary Lua binaries](https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip/download). Extract the archive and copy `lua5.1.dll` and `lua51.dll` into the same directory as your DeSmuME executable file. After doing this, you should be able to run Lua scripts on DeSmuME.

### Writing a bot
Most of the botting logic is written in the file [`Agent.lua`](Agent.lua). This repository comes with an example bot, but you can change the bot as you see fit. You'll mainly be modifying the `Agent:act()` method, which contains the main logic for the bot. You might also change `Agent:attackEnemy()`, which holds attack selection logic, but this is really just a helper function; you could instead just cram this logic directly into `Agent:act()`. Additionally, if you want to set up state information for your bot, you can do so in `Agent:init()`, which is called only once at startup.

The bot makes direct use of the following utilities:

- [Dungeon state information](dynamicinfo) is accessed through the _full_ `state` (`stateinfo.state`) and _visible_ `state` (`visibleinfo.state`) objects passed to `Agent:act()`.
- [Actions in game](actions) are performed using the `actions` module.
- [Internal ID codes](codes) are referenced from the `codes` module.
- [Game mechanics utilities](mechanics) are referenced from the `mechanics` module.
- [Other utilities](utils) include pathfinding and message reporting, which are handled in their respective submodules in `utils`.

Modifying `Agent.lua` should be sufficient for many use cases. However, if you need to change the nature of the main execution loop, you can modify [`main.lua`](main.lua).

### Running a bot
These instructions assume the interface of DeSmuME 0.9.12, but hopefully they won't change much in future versions.

1. Start up _Pokémon Mystery Dungeon: Explorers of Sky (NA)_, and enter a dungeon (this you'll have to do manually).
2. In the DeSmuME "Tools" menu, select "Lua Scripting" -> "New Lua Script Window..."
3. In the window that just opened, click "Browse..." and select `main.lua` in the PMD-Bot directory.
4. The bot should start automatically. If not, start it by clicking "Run".
