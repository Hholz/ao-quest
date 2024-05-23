-- Initialize global variables to store the latest game state and game host process
gameState = gameState or nil
isActionInProgress = isActionInProgress or false -- Prevents the agent from taking multiple actions at once.
logEntries = logEntries or {}

-- Define colors for console output
colorCodes = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

-- Function to add logs
function addLog(entry, text)
    logEntries[entry] = logEntries[entry] or {}
    table.insert(logEntries[entry], text)
end

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function arePointsInRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Function to calculate Euclidean distance between two points
function getDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Function to find the nearest enemy player
function getNearestEnemy()
    local closestEnemy = nil
    local minimumDistance = math.huge
    local selfPlayer = gameState.Players[ao.id]

    for playerId, playerState in pairs(gameState.Players) do
        if playerId ~= ao.id then
            local distanceToEnemy = getDistance(selfPlayer.x, selfPlayer.y, playerState.x, playerState.y)
            if distanceToEnemy < minimumDistance then
                closestEnemy = playerState
                minimumDistance = distanceToEnemy
            end
        end
    end

    return closestEnemy
end

-- Function to move towards the nearest enemy player
function approachNearestEnemy()
    local selfPlayer = gameState.Players[ao.id]
    local nearestEnemy = getNearestEnemy()

    if nearestEnemy then
        -- Calculate direction towards the enemy
        local directionX = nearestEnemy.x - selfPlayer.x
        local directionY = nearestEnemy.y - selfPlayer.y

        -- Normalize direction vector
        local magnitude = math.sqrt(directionX^2 + directionY^2)
        directionX = directionX / magnitude
        directionY = directionY / magnitude

        -- Move towards the enemy (for simplicity, let's assume a fixed speed)
        local newX = selfPlayer.x + directionX
        local newY = selfPlayer.y + directionY

        -- Check if the new position is within the game boundaries
        if newX >= 0 and newX <= gameState.GameWidth and newY >= 0 and newY <= gameState.GameHeight then
            -- Update player position
            ao.send({ Target = Game, Action = "Move", Player = ao.id, X = newX, Y = newY })
        end
    end
end

-- Function to evade attacks
function dodgeAttacks()
    -- Implement evasion tactics here
    -- For simplicity, let's assume random movement
    local randomX = math.random(0, gameState.GameWidth)
    local randomY = math.random(0, gameState.GameHeight)

    -- Move to a random position within the game boundaries
    ao.send({ Target = Game, Action = "Move", Player = ao.id, X = randomX, Y = randomY })
end

-- Function to find the weakest player
function getWeakestPlayer()
    local weakestOpponent = nil
    local lowestHealth = math.huge

    for playerId, playerState in pairs(gameState.Players) do
        if playerId ~= ao.id then
            local opponent = playerState

            if opponent.health < lowestHealth then
                weakestOpponent = opponent
                lowestHealth = opponent.health
            end
        end
    end

    return weakestOpponent
end

-- Function to attack the weakest player
function attackWeakestPlayer()
    local weakestOpponent = getWeakestPlayer()

    if weakestOpponent and weakestOpponent.health < 0.7 then
        local attackEnergy = gameState.Players[ao.id].energy * weakestOpponent.health
        print(colorCodes.red .. "Attacking weakest player with energy: " .. attackEnergy .. colorCodes.reset)
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(attackEnergy) }) -- Attack with energy proportional to opponent's health
        isActionInProgress = false -- Reset isActionInProgress after attacking
        return true
    end

    return false
end

-- Function to decide whether to attack or evade based on health and energy
function chooseDefenseOrOffense()
    local selfPlayer = gameState.Players[ao.id]

    if selfPlayer.health < 0.3 then
        print("Health is low, evading attacks.")
        dodgeAttacks()
    elseif selfPlayer.energy < 0.2 then
        print("Energy is low, conserving energy.")
    else
        attackWeakestPlayer()
    end
end

-- Function to decide the next action based on player proximity and energy
function determineNextAction()
    local selfPlayer = gameState.Players[ao.id]

    -- If health is low, prioritize defense
    if selfPlayer.health < 0.5 then
        chooseDefenseOrOffense()
    else
        -- Check if there are weak opponents to attack
        if not attackWeakestPlayer() then
            print("No weak opponents found. Moving towards nearest enemy.")
            approachNearestEnemy()
        end
    end
end

-- Handler to print game announcements and trigger game state updates
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            ao.send({ Target = ao.id, Action = "AutoPay" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not isActionInProgress then
            isActionInProgress = true  -- isActionInProgress logic added
            ao.send({ Target = Game, Action = "GetGameState" })
        elseif isActionInProgress then -- isActionInProgress logic added
            print("Previous action still in progress. Skipping.")
        end

        print(colorCodes.green .. msg.Event .. ": " .. msg.Data .. colorCodes.reset)
    end
)

-- Handler to trigger game state updates
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        if not isActionInProgress then -- isActionInProgress logic added
            isActionInProgress = true  -- isActionInProgress logic added
            print(colorCodes.gray .. "Getting game state..." .. colorCodes.reset)
            ao.send({ Target = Game, Action = "GetGameState" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)

-- Handler to automate payment confirmation when waiting period starts
Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function(msg)
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Handler to update the game state upon receiving game state information
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        gameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Print 'gameState' for detailed view.")
        print("Energy: " .. gameState.Players[ao.id].energy)
    end
)

-- Handler to decide the next best action
Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
        if gameState.GameMode ~= "Playing" then
            print("Game not started")
            isActionInProgress = false -- isActionInProgress logic added
            return
        end
        print("Deciding next action.")
        determineNextAction()
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)

-- Handler to automatically attack when hit by another player
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        if not isActionInProgress then -- isActionInProgress logic added
            isActionInProgress = true  -- isActionInProgress logic added
            local playerEnergy = gameState.Players[ao.id].energy
            if playerEnergy == nil then
                print(colorCodes.red .. "Unable to read energy." .. colorCodes.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
            elseif playerEnergy == 0 then
                print(colorCodes.red .. "Player has insufficient energy." .. colorCodes.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
            else
                print(colorCodes.red .. "Returning attack." .. colorCodes.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) }) -- Attack with full energy
            end
            isActionInProgress = false -- isActionInProgress logic added
            ao.send({ Target = ao.id, Action = "Tick" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)
