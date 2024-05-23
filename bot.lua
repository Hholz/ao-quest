-- Initializing global variables
LatestGameState = LatestGameState or nil
Game = Game or "0rVZYFxvfJpO__EfOz0_PUQ3GFE9kEaES0GkUDNXjvE"
Counter = Counter or 0
FixTarget = FixTarget or nil
LockingTarget = LockingTarget or nil
Logs = Logs or {}
InAction = InAction or false

DirectionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}

colors = {
  red = "\\27[31m",
  green = "\\27[32m",
  blue = "\\27[34m",
  reset = "\\27[0m",
  gray = "\\27[90m"
}

function addLog(msg, text)
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

function inRange(x1, y1, x2, y2, range)
  local rangeX, rangeY = 0, 0
  if math.abs(x1 - x2) > 20 then
    rangeX = 41 - math.abs(x1 - x2)
  else
    rangeX = math.abs(x1 - x2)
  end

  if math.abs(y1 - y2) > 20 then
    rangeY = 41 - math.abs(y1 - y2)
  else
    rangeY = math.abs(y1 - y2)
  end

  return (rangeX + rangeY) <= range
end

function decideNextAction()
  if FixTarget and LatestGameState.Players[FixTarget] then
    LockingTarget = FixTarget
  else
    -- Select a random target
    local players = {}
    for k, v in pairs(LatestGameState.Players) do
      if k ~= ao.id then
        table.insert(players, k)
      end
    end
    if #players > 0 then
      LockingTarget = players[math.random(#players)]
    else
      LockingTarget = nil
    end
  end

  if LockingTarget and LatestGameState.Players[LockingTarget] then
    local target = LatestGameState.Players[LockingTarget]
    local me = LatestGameState.Players[ao.id]

    if inRange(me.x, me.y, target.x, target.y, 5) then
      local attackEnergy = math.min(me.energy, 20)
      ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(attackEnergy)})
    else
      local direction = DirectionMap[math.random(#DirectionMap)]
      ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction})
    end
  else
    local direction = DirectionMap[math.random(#DirectionMap)]
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction})
  end
end

Handlers = Handlers or {}

Handlers.utils = {
  hasMatchingTag = function(tag, value)
    return function(msg)
      return msg[tag] == value
    end
  end
}

Handlers.add = function(name, condition, action)
  Handlers[name] = {condition = condition, action = action}
end

Handlers.handle = function(msg)
  for _, handler in pairs(Handlers) do
    if handler.condition(msg) then
      handler.action(msg)
    end
  end
end

-- Handlers
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print 'LatestGameState' for detailed view.")
  end
)

Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      InAction = false
      return
    end
    print("Deciding next action.")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then
      InAction = true
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == nil then
        print(colors.red .. "Unable to read energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
      elseif playerEnergy == 0 then
        print(colors.red .. "Player has insufficient energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      elseif playerEnergy < 20 then
        print("Energy too low for an effective counterattack. Evading instead.")
        local direction = DirectionMap[math.random(#DirectionMap)]
        ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction})
      else
        print(colors.red .. "Returning attack." .. colors.reset)
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
      end
      InAction = false
      ao.send({Target = ao.id, Action = "Tick"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

