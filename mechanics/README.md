# Game mechanics references

_Explorers of Sky_ (and _Pokémon_ in general) has fairly rich game mechanics, many of which are complex enough that hard-coding becomes inconvenient, but structured enough that they can be retrieved in a regular format. This directory contains utilities for retrieving such information, including:

- [TODO] [Dungeon characteristics](dungeon.lua)
- [Item characteristics](item.lua)
- [Move characteristics](move.lua)
- [WIP] [Move power calculation](power.lua)
- [TODO] [Pokémon species characteristics](species.lua)

All reference submodules, when imported, define an aptly named subtable in the `mechanics` global variable.