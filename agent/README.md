# Sample agents

This directory contains sample bot implementations. For directions on how to write a bot, see the [main README](../README.md).

- [`Agent.lua`](Agent.lua) contains the default sample agent. It is capable of exploring, attacking enemies, selecting moves, picking up items, restoring HP and Belly, and more. By default, it only uses state information that would be available to a human player. If you want it to use all possible state information, you can set it to omniscient mode by setting `Agent.omniscient` to `true`.
- [`BasicAgent.lua`](BasicAgent.lua) contains a basic agent with less capability than the default agent. It only has an omniscient mode, won't use moves (only the regular attack), and lacks much of the complicated logic of the default agent. While it is potentially less useful than the default agent from an automation perspective, the code is simpler and easier for a beginner to understand, which makes it a better starting point for understanding the overall botting framework.
