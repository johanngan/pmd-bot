-- Reading state info that's accessible to the player.
-- Mostly just draws from stateinfo with restricted access, and closely mimics the API.

require 'string'
require 'table'

require 'utils.copy'
require 'utils.stringutils'
require 'mechanics.species'
local rangeutils = require 'mechanics.rangeutils'
require 'dynamicinfo.StateData'
require 'dynamicinfo.stateinfo'
local mapHelpers = require 'dynamicinfo.mapHelpers'

visibleinfo = {}

-- Register a field to the state model that just retrieves the corresponding field from stateinfo
local function registerProxyField(state, fieldPathSpec)
    local pathComponents = stringutils.split(fieldPathSpec, '.')
    local field = table.remove(pathComponents)
    -- Recurse down the path to the leaf
    local stateinfoContainer = stateinfo.state
    local container = state
    for _, subcontainerName in ipairs(pathComponents) do
        stateinfoContainer = stateinfoContainer[subcontainerName]
        -- If the container doesn't exist yet, create it
        if container[subcontainerName] == nil then
            container[subcontainerName] = {}
        end
        container = container[subcontainerName]
    end
    -- Define a new cacheless field at the leaf
    local stateinfoField = stateinfoContainer[field]
    container[field] = StateData:new(false)
    -- Define the read method on that field as a proxy to the stateinfo field
    container[field].read = function(self) return stateinfoField() end
end

---- BEGIN STATE DATA MODEL ----
visibleinfo.state = {}
local state = visibleinfo.state

-- Proxy fields --
proxyFields = {
    'dungeon.dungeonID',
    'dungeon.visibilityRadius',
    'dungeon.floor',
    -- Player should explicitly know everything about team members, except
    -- maybe turn countdowns for statuses (which, theoretically, are still
    -- more-or-less implicitly knowable) and exact IQ stats (but that doesn't
    -- really matter much...maybe add something to deal with this later)
    'dungeon.entities.team',
    'dungeon.conditions.weather',
    'dungeon.conditions.weatherIsNullified',
    'dungeon.conditions.thiefAlert',
    'dungeon.conditions.gravity',
    'dungeon.conditions.luminous',
    'dungeon.conditions.darkness',
    'player.team',
    'player.leader',
    'player.money',
    'player.bag',
    'player.bagCapacity',
    'player.canSeeEnemies',
    'player.canSeeItems',
    'player.canSeeTrapsAndHiddenStairs',
    'player.canSeeStairs',
}
for _, field in ipairs(proxyFields) do
    registerProxyField(state, field)
end

--- BEGIN NON-PROXY FIELDS ---

-- Known floor layout
state.dungeon.layout = StateData:new()
function state.dungeon.layout:read()
    local layout = {}
    local fullLayout = stateinfo.state.dungeon.layout()
    local leader = stateinfo.state.player.leader()
    local x0 = leader.xPosition
    local y0 = leader.yPosition
    for y, row in ipairs(fullLayout) do
        local newRow = {}
        for x, tile in ipairs(row) do
            -- Filter out any information that the player isn't privy to
            local newTile = {}
            if rangeutils.onMapOrScreen(x, y, x0, y0, fullLayout) then
                newTile = copy.deepcopySimple(fullLayout[y][x])

                if not (x == x0 and y == y0) then
                    -- Can't know this for sure without prior memories
                    newTile.inMonsterHouse = nil
                end

                if newTile.isStairs then
                    local hiddenStairs = stateinfo.state.dungeon.entities.hiddenStairs()
                    -- If all these conditions are true, then we shouldn't know about
                    -- the stairs on this tile, and we should mask its presence.
                    -- Otherwise, we do indeed know about these stairs.
                    newTile.isStairs = not (
                        hiddenStairs ~= nil and
                        hiddenStairs.xPosition == x and hiddenStairs.yPosition == y and
                        state.dungeon.entities.hiddenStairs() == nil -- Note: visibleinfo.state here
                    )
                end

                if not rangeutils.visitedOrOnScreen(x, y, x0, y0, fullLayout) then
                    -- Hard to know this for sure without visiting
                    newTile.inShop = nil
                end

                -- Note: the exact value of the room index isn't something we should know,
                -- but it isn't very meaningful anyway beyond uniquely identifying each room,
                -- which is something we do know.
            else
                -- These are the only things we know
                newTile.visibleOnMap = false
                newTile.visited = false
            end
            table.insert(newRow, newTile)
        end
        table.insert(layout, newRow)
    end
    return layout
end

-- Convenience field for the stairs position, if known
-- Like with stateinfo, this might be normal stairs or hidden stairs
state.dungeon.stairs = StateData:new()
function state.dungeon.stairs:read()
    -- Note: visibleinfo.state here
    return mapHelpers.findStairs(state.dungeon.layout())
end

-- List of known enemies
state.dungeon.entities.enemies = StateData:new()
function state.dungeon.entities.enemies:read()
    local enemies = {}
    local leader = stateinfo.state.player.leader()
    local x0 = leader.xPosition
    local y0 = leader.yPosition
    for _, enemy in ipairs(stateinfo.state.dungeon.entities.enemies()) do
        -- We only know about an enemy if we can see all enemies on the floor,
        -- or it's in the visibility region,
        local x = enemy.xPosition
        local y = enemy.yPosition
        if stateinfo.state.player.canSeeEnemies() or
            rangeutils.inVisibilityRegion(x, y, x0, y0, stateinfo.state.dungeon) then
            local newEnemy = {}
            if rangeutils.onScreen(x, y, x0, y0) then
                newEnemy = copy.deepcopySimple(enemy)
                if enemy.features.species ~= enemy.features.apparentSpecies then
                    -- Don't know the real species;
                    -- for convenience set it to the apparent one rather than nil
                    newEnemy.features.species = newEnemy.features.apparentSpecies
                    -- The types and abilities should appear as the apparent species', not
                    -- the true species'
                    local apparentTypes = mechanics.species.types[newEnemy.features.apparentSpecies]
                    local apparentAbilities = mechanics.species.abilities[newEnemy.features.apparentSpecies]
                    newEnemy.features.primaryType = apparentTypes.primary
                    newEnemy.features.secondaryType = apparentTypes.secondary
                    newEnemy.features.primaryAbility = apparentAbilities.primary
                    newEnemy.features.secondaryAbility = apparentAbilities.secondary
                end
                -- The gender isn't readily visible
                newEnemy.features.gender = nil
                -- No stats known, only modifiers (which you could argue those
                -- are only partially knowable, but ehhhh...seems hard)
                newEnemy.stats = {modifiers = newEnemy.stats.modifiers}
                newEnemy.heldItemQuantity = nil
                newEnemy.heldItem = nil                
                -- Variable-length field: set these to nil (means "unknown"),
                -- which is semantically different from an empty list (means "no moves")
                newEnemy.moves = nil
                newEnemy.belly = nil
                -- Like noted with team members, statuses aren't explicitly known
                -- but are probably implicitly knowable, so keep them. But maybe
                -- in the future this should be handled more carefully...
            else
                -- Off-screen; we only know that it is an enemy, and where it is
                newEnemy.xPosition = enemy.xPosition
                newEnemy.yPosition = enemy.yPosition
                newEnemy.isEnemy = enemy.isEnemy
                newEnemy.isLeader = enemy.isLeader
                newEnemy.isAlly = enemy.isAlly
                newEnemy.features = {}
                -- This is an empty shell of the stats struct
                newEnemy.stats = {modifiers = {speedCounters = {up={}, down={}}}}
                -- Leave statuses and moves are variable-length fields; leave as nil
            end
            table.insert(enemies, newEnemy)
        end            
    end
    return enemies
end

-- List of known items
state.dungeon.entities.items = StateData:new()
function state.dungeon.entities.items:read()
    local items = {}
    local leader = stateinfo.state.player.leader()
    local x0 = leader.xPosition
    local y0 = leader.yPosition
    for _, item in ipairs(stateinfo.state.dungeon.entities.items()) do
        -- We only know about an item if we can see all items on the floor,
        -- or it's in the visibility region
        local x = item.xPosition
        local y = item.yPosition        
        if stateinfo.state.player.canSeeItems() or
            rangeutils.inVisibilityRegion(x, y, x0, y0, stateinfo.state.dungeon) then
            local newItem = {}
            if rangeutils.onScreen(x, y, x0, y0) then
                -- Note: the item position just being visited isn't enough because
                -- items can be dropped off-screen, and you won't have seen them before
                newItem = copy.deepcopySimple(item)
                -- If we're standing on the item, we know everything
                if not (x == x0 and y == y0) then
                    -- Otherwise, we lack some info
                    newItem.isSticky = nil
                    newItem.amount = nil
                    newItem.itemType = nil
                end
            else
                -- Off-screen; we only know where the item is
                newItem.xPosition = item.xPosition
                newItem.yPosition = item.yPosition
                newItem.sprite = {}
            end
            table.insert(items, newItem)
        end
    end
    return items
end

-- List of known traps
state.dungeon.entities.traps = StateData:new()
function state.dungeon.entities.traps:read()
    local traps = {}
    local leader = stateinfo.state.player.leader()
    local x0 = leader.xPosition
    local y0 = leader.yPosition
    for _, trap in ipairs(stateinfo.state.dungeon.entities.traps()) do
        local x = trap.xPosition
        local y = trap.yPosition
        -- Filter out any traps we don't know about
        if (stateinfo.state.player.canSeeTrapsAndHiddenStairs() or trap.isRevealed) and
            rangeutils.onMapOrScreen(x, y, x0, y0, stateinfo.state.dungeon.layout()) then
            local newTrap = copy.deepcopySimple(trap)
            if not (trap.isRevealed or
               rangeutils.onScreen(x, y, x0, y0, stateinfo.state.dungeon.layout())) then
                -- We haven't ever seen the trap, so we don't know what type it is
                -- Note: the trap position just being visited isn't enough because
                -- an unrevealed trap in a visited + offscreen room could become
                -- visible on the map after putting on Goggle Specs, without us
                -- ever having seen what it is
                newTrap.trapType = nil
            end
            table.insert(traps, newTrap)
        end
    end
    return traps
end

-- Hidden stairs, if known
state.dungeon.entities.hiddenStairs = StateData:new()
function state.dungeon.entities.hiddenStairs:read()
    local hiddenStairs = stateinfo.state.dungeon.entities.hiddenStairs()
    if hiddenStairs ~= nil then
        local leader = stateinfo.state.player.leader()
        local x0 = leader.xPosition
        local y0 = leader.yPosition
        -- If hidden stairs exist, make sure we actually know they're there
        if (stateinfo.state.player.canSeeStairs()
            or ((stateinfo.state.player.canSeeTrapsAndHiddenStairs() or hiddenStairs.isRevealed)
                and rangeutils.onMapOrScreen(hiddenStairs.xPosition, hiddenStairs.yPosition,
                                             x0, y0, stateinfo.state.dungeon.layout())
            )
        ) then
            return hiddenStairs
        end
    end
    return nil
end

-- If Mud Sport is active.
state.dungeon.conditions.mudSport = StateData:new(false)
function state.dungeon.conditions.mudSport:read()
    return stateinfo.state.dungeon.conditions.mudSportTurnsLeft() > 0
end
-- If Water Sport is active.
state.dungeon.conditions.waterSport = StateData:new(false)
function state.dungeon.conditions.waterSport:read()
    return stateinfo.state.dungeon.conditions.waterSportTurnsLeft() > 0
end

-- Subcontainer for counters. Need to define this explicitly since there
-- weren't any proxy fields within this subcontainer
state.dungeon.counters = {}
-- Number of warning the player has received about the wind
state.dungeon.counters.windWarnings = StateData:new(false)
function state.dungeon.counters.windWarnings:read()
    local wind = stateinfo.state.dungeon.counters.wind()
    if wind <= 0 then
        -- 0: It's right nearby! It's gusting hard!
        return 4
    elseif wind <= 49 then
        -- 49: It's getting closer!
        return 3
    elseif wind <= 149 then
        -- 149: Something's approaching...
        return 2
    elseif wind <= 249 then
        -- 249: Something's stirring...
        return 1
    else
        -- No warnings yet...
        return 0
    end
end

-- Turns since the last round of passive damage from bad weather
state.dungeon.counters.turnsSinceWeatherDamage = StateData:new(false)
function state.dungeon.counters.turnsSinceWeatherDamage:read()
    return 9 - stateinfo.state.dungeon.counters.weatherDamage()
end

--- END NON-PROXY FIELDS ---

---- END STATE DATA MODEL ----

-- Forces reload on a StateData list
local function flagListForReload(stateDataList)
    for _, data in ipairs(stateDataList) do
        data:flagForReload()
    end
end

-- Forces reload for appropriate stuff every turn
function visibleinfo.reloadEveryTurn(state)
    flagListForReload({
        state.dungeon.layout,
        state.dungeon.stairs,
        state.dungeon.entities.enemies,
        state.dungeon.entities.items,
        state.dungeon.entities.traps,
        state.dungeon.entities.hiddenStairs,
    })
    return state
end

return visibleinfo