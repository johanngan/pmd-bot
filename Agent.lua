-- Class for deciding on what actions to take based on the current state

require 'table'

require 'codes.direction'
require 'codes.item'
require 'codes.menu'
require 'dynamicinfo.menuinfo'
require 'actions.basicactions'
require 'actions.smartactions'
require 'utils.pathfinder'

Agent = {}

-- This is just boilerplate code for the class
function Agent:new(state)
    obj = {}
    setmetatable(obj, self)
    self.__index = self
    self:init(state)
    return obj
end

-- This function will be called just once when the bot starts up.
function Agent:init(state)
    -- If you want your bot to have a state or a memory, initialize stuff here!
    self.path = nil
    self.targetPos = nil
end

-- Set the target position
function Agent:setTargetPos(targetPos)
    if not (self.targetPos and targetPos) or
        not pathfinder.comparePositions(self.targetPos, targetPos) then
        self.targetPos = targetPos
        self.path = nil -- Need to calculate a new path
    end
end

-- Return the tile under an entity
local function tileUnder(entity, layout)
    return layout[entity.yPosition][entity.xPosition]
end

-- Perform some actions based on the current state of the dungeon (and the bot's own state)
-- This is a very simple sample strategy. Change it to fit your botting needs.
function Agent:act(state)
    -- If in a Yes/No prompt, try to exit
    if menuinfo.getMenu() == codes.MENU.YesNo then
        basicactions.selectYesNo(1)
        return
    end

    -- If trying to learn a new move, don't
    if menuinfo.getMenu() == codes.MENU.NewMove then
        basicactions.selectMoveToForget(4)
        return
    end

    local leader = state.player.leader()

    -- If no target position exists, or it's been reached, set it to the stairs
    if not self.targetPos or pathfinder.comparePositions(
        {leader.xPosition, leader.yPosition}, self.targetPos) then
        self:setTargetPos({state.dungeon.stairs()})
    end

    -- If on the stairs and it's the current target, climb
    if pathfinder.comparePositions(self.targetPos, {state.dungeon.stairs()}) and
        pathfinder.comparePositions({leader.xPosition, leader.yPosition},
            {state.dungeon.stairs()}) then
        self:setTargetPos(nil)  -- Clear the target
        basicactions.climbStairs()
        return
    end

    -- If there are items in the room, and there's room in the bag, go to pick them up
    if #state.player.bag() < 48 and pathfinder.comparePositions(
        self.targetPos, {state.dungeon.stairs()}) then
        local leaderRoom = tileUnder(leader, state.dungeon.layout()).room
        if leaderRoom ~= -1 then -- -1 means hallway
            for _, item in ipairs(state.dungeon.entities.items()) do
                -- Don't touch Kecleon's stuff
                if tileUnder(item, state.dungeon.layout()).room == leaderRoom and
                    not item.inShop then
                    self:setTargetPos({item.xPosition, item.yPosition})
                    break
                end
            end
        end
    end

    -- If HP is low and there's an Oran Berry in the bag, eat it
    if leader.stats.HP <= leader.stats.maxHP - 100 then
        if smartactions.useItemIfPossible(basicactions.eatFoodItem,
            codes.ITEM.OranBerry, state.player.bag()) then
            return
        end
    end

    -- If belly is low and there's an Apple in the bag, eat it
    if leader.belly <= 50 then
        if smartactions.useItemIfPossible(basicactions.eatFoodItem,
            codes.ITEM.Apple, state.player.bag()) then
            return
        end
    end

    -- If an enemy is nearby, attack it (unless it's a shopkeeper)
    for _, enemy in ipairs(state.dungeon.entities.enemies()) do
        if not enemy.isShopkeeper and pathfinder.stepDistance(
            {leader.xPosition, leader.yPosition}, {enemy.xPosition, enemy.yPosition}) <= 1 then
            -- Step distance is quick to calculate, but isn't 100% accurate. We
            -- really need to check that the actual path distance is 1. That way
            -- we won't try to (regular) attack around corners.
            local pathToEnemy = pathfinder.getPath(
                state.dungeon.layout(),
                leader.xPosition, leader.yPosition,
                enemy.xPosition, enemy.yPosition
            )
            -- Exists, and just includes start and end, so path length is 1
            if pathToEnemy and #pathToEnemy == 2 then
                local direction = pathfinder.getDirection(
                    enemy.xPosition-leader.xPosition,
                    enemy.yPosition-leader.yPosition
                )
                if leader.direction ~= direction then
                    basicactions.face(direction)
                end
                basicactions.attack()
                return
            end
        end
    end

    -- If nothing of interest is nearby, keep moving towards the target
    if not self.path or #self.path == 0 or not pathfinder.comparePositions(
        {leader.xPosition, leader.yPosition}, self.path[1].start) then
        -- Path is nonexistent or obsolete. Find a new path
        local path = pathfinder.getPath(
            state.dungeon.layout(),
            leader.xPosition, leader.yPosition,
            unpack(self.targetPos)
        )
        if not path then
            error('Something went wrong. Unable to find path.')
        end
        self.path = pathfinder.getMoves(path)
    end
    if #self.path > 0 then
        -- Not already on target
        local direction = table.remove(self.path, 1).direction
        basicactions.walk(direction)
    end
end