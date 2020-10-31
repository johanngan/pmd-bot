# Internal ID codes

_Explorers of Sky_ represents a lot of data using internal ID codes. This includes things like:

- [Pokémon abilities](ability.lua)
- [Directions you can face within dungeons](direction.lua)
- [Mystery Dungeons](dungeon.lua)
- [Genders](gender.lua)
- [IQ groups](iqGroup.lua)
- [Items](item.lua)
- [Item categories](itemCategory.lua)
- [Item sprites](itemSprite.lua)
- [Mobility types](mobility.lua)
- [Pokémon moves](move.lua)
- [Move damage categories](moveCategory.lua)
- [Pokémon species](species.lua)
- [Status conditions](status.lua)
- [Types of tile terrains in dungeons](terrain.lua)
- [Types of traps in dungeons](trap.lua)
- [Pokémon types](type.lua)
- [Weather conditions in dungeons](weather.lua)

Additionally, PMD-Bot also defines ID codes for different [menus](menu.lua), [colors](color.lua), [item menu types](itemMenuType.lua), [move ranges](moveRange.lua), and [move targets](moveTarget.lua).

All ID code submodules, when imported, define two subtables in the `codes` global variable: a map from readable names to their ID codes (for use in botting code), and an inverse map (for message reporting and debugging). The inverse map has the suffix `_NAMES`.