# Sample agents

This directory contains sample bot implementations. For directions on how to write a bot, see the [main README](../README.md).

- [`BaseAgent.lua`](BaseAgent.lua) contains an abstract base class for Agents. All concrete Agent classes should inherit from this base class. To create a new Agent subclass, do the following:
    1. Import the module into your new Agent file with `local BaseAgent = require 'agent.BaseAgent'`.
    2. Instantiate your new subclass as an instance of `BaseAgent` with `Agent = BaseAgent:__instance__()`.
    3. Override methods as necessary. The purposes of each method that you might want to override are described in the main README. You _must_ override the `act(state, visible)` method. Optionally, you can also override the `init(state, visible)`, `setupTurn(state, visible)`, and `finalizeTurn()` methods.
    4. Make sure to end the module file by returning your `Agent` class with `return Agent`.
- [`Agent.lua`](Agent.lua) contains the default sample agent. It is capable of exploring, attacking enemies, selecting moves, picking up items, restoring HP and Belly, and more. By default, it only uses state information that would be available to a human player. If you want it to use all possible state information, you can set it to omniscient mode by setting `Agent.omniscient` to `true`.
- [`SimpleAgent.lua`](SimpleAgent.lua) contains a simple agent with less capability than the default agent. It only has an omniscient mode, won't use moves (only the regular attack), and lacks much of the complicated logic of the default agent. While it is potentially less useful than the default agent from an automation perspective, the code is simpler and easier for a beginner to understand, which makes it a better starting point for understanding the overall botting framework.