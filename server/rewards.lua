--- Paying a vote: every entry in Config.Rewards through the adapter for the
--- framework that is running, then any milestone the player's lifetime count
--- hits, then the announcement, the webhook and the gtaservers:vote event.
Rewards = {}

local framework = 'none'
local ESX, QBCore
local warnedFor = {}

---@return string 'esx', 'qb', 'qbx' or 'none'
function Rewards.detect()
  if GetResourceState('es_extended') == 'started' then
    local ok, shared = pcall(function()
      return exports['es_extended']:getSharedObject()
    end)
    if ok and shared then
      ESX = shared
      framework = 'esx'
    end
  elseif GetResourceState('qbx_core') == 'started' then
    framework = 'qbx'
  elseif GetResourceState('qb-core') == 'started' then
    local ok, core = pcall(function()
      return exports['qb-core']:GetCoreObject()
    end)
    if ok and core then
      QBCore = core
      framework = 'qb'
    end
  end
  if framework ~= 'none' then
    warnedFor = {}
  end
  return framework
end

--- Detection is retried while nothing has been found: this resource may well
--- have started before es_extended did, and a framework looked for only at
--- boot would stay missing for the life of the server.
---@return string
function Rewards.framework()
  if framework == 'none' then
    return Rewards.detect()
  end
  return framework
end

--- Printed once per reward type, not once per retry: an unpaid vote is tried
--- again on every poll.
local function warnNoFramework(kind)
  if warnedFor[kind] then return end
  warnedFor[kind] = true
  print(L('no_framework_for', kind))
end

local function hasOxInventory()
  return GetResourceState('ox_inventory') == 'started'
end

local money = {
  esx = function(src, reward)
    local player = ESX.GetPlayerFromId(src)
    if not player then return false end
    local account = reward.account == 'cash' and 'money' or reward.account
    player.addAccountMoney(account, reward.amount)
    return true
  end,
  qb = function(src, reward)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    player.Functions.AddMoney(reward.account or 'cash', reward.amount, 'gtaservers vote')
    return true
  end,
  qbx = function(src, reward)
    return exports.qbx_core:AddMoney(src, reward.account or 'cash', reward.amount, 'gtaservers vote') ~= false
  end,
}

local item = {
  esx = function(src, reward)
    local player = ESX.GetPlayerFromId(src)
    if not player then return false end
    player.addInventoryItem(reward.name, reward.count or 1)
    return true
  end,
  qb = function(src, reward)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    return player.Functions.AddItem(reward.name, reward.count or 1) ~= false
  end,
  qbx = function(src, reward)
    return exports.qbx_core:AddItem(src, reward.name, reward.count or 1) ~= false
  end,
}

--- A player picks their own name, and it reaches a console command line and
--- the chat box from here: quotes and semicolons could add arguments to a
--- command, and angle brackets could reach a chat theme that renders HTML.
---@param value any
---@return string
local function clean(value)
  local text = tostring(value):gsub("[%c\"';<>\\]", ''):gsub('%^%d', '')
  if #text > 64 then
    text = text:sub(1, 64)
  end
  return text
end

--- Replaces {id}, {name}, {identifier}, {votes} and {reward} in config strings.
local function substitute(template, ctx)
  return (tostring(template):gsub('{(%w+)}', function(key)
    local value = ctx[key]
    if value == nil then return '{' .. key .. '}' end
    return clean(value)
  end))
end

--- Runs one reward entry.
---@return boolean true when the reward reached the player
local function give(src, reward, vote, ctx)
  local kind = reward.type
  if kind == 'money' then
    local adapter = money[Rewards.framework()]
    if not adapter then
      warnNoFramework('money')
      return false
    end
    return adapter(src, reward) ~= false
  elseif kind == 'item' then
    if hasOxInventory() then
      return exports.ox_inventory:AddItem(src, reward.name, reward.count or 1) ~= false
    end
    local adapter = item[Rewards.framework()]
    if not adapter then
      warnNoFramework('item')
      return false
    end
    return adapter(src, reward) ~= false
  elseif kind == 'command' then
    ExecuteCommand(substitute(reward.run, ctx))
    return true
  elseif kind == 'event' then
    TriggerEvent(reward.name, src, vote)
    return true
  elseif kind == 'function' then
    return reward.run(src, vote) ~= false
  end
  print(('[gtaservers] Unknown reward type "%s" in config.lua'):format(tostring(kind)))
  return false
end

--- The webhook is the owner's own Discord; nothing here reaches
--- gtaservers.org. Mentions are disabled because a player could name
--- themselves @everyone.
local function webhook(text)
  if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end
  PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
    content = text,
    allowed_mentions = { parse = {} },
  }), {
    ['Content-Type'] = 'application/json',
  })
end

---@param src number
---@param vote { id: number, identifier: string, name: string, voted_at: number, total_votes: number, forced: boolean?, note: string? }
---@return boolean true when the vote was paid; false to leave it for a later poll
function Rewards.pay(src, vote)
  local name = vote.name or GetPlayerName(src) or 'player'
  local ctx = {
    id = src,
    name = name,
    identifier = vote.identifier or '',
    votes = vote.total_votes or 0,
    reward = Config.RewardDescription or '',
  }

  local attempted, paid = 0, 0
  for index, reward in ipairs(Config.Rewards or {}) do
    attempted = attempted + 1
    local ok, result = pcall(give, src, reward, vote, ctx)
    if ok and result then
      paid = paid + 1
    elseif not ok then
      print(L('reward_failed', tostring(reward.type or index), name, tostring(result)))
    end
  end

  -- Nothing landed at all: usually the framework is not up yet, or the player
  -- object does not exist a few seconds into their join. Report the vote
  -- unpaid so the next poll tries again, rather than claiming it and telling
  -- the player they were paid. A reward list that partly succeeded counts as
  -- paid: a retry would run the whole list again and pay the rest twice.
  if attempted > 0 and paid == 0 then
    return false
  end

  local milestone = Config.Milestones and vote.total_votes and Config.Milestones[vote.total_votes]
  if milestone then
    for index, reward in ipairs(milestone) do
      local ok, err = pcall(give, src, reward, vote, ctx)
      if not ok then
        print(L('reward_failed', 'milestone ' .. tostring(reward.type or index), name, tostring(err)))
      end
    end
  end

  if Config.RewardDescription and Config.RewardDescription ~= '' then
    Notify(src, L('reward_paid', Config.RewardDescription))
  end

  if not vote.forced and Config.Announce and Config.Announce ~= '' then
    TriggerClientEvent('chat:addMessage', -1, { args = { 'Vote', substitute(Config.Announce, ctx) } })
  end

  local who = Config.WebhookIdentifier and (' (' .. ctx.identifier .. ')') or ''
  webhook(vote.forced
    and ('Forced vote reward for %s%s%s'):format(name, who, vote.note and (': ' .. vote.note) or '')
    or ('%s voted for the server%s (vote #%d, %d lifetime)'):format(name, who, vote.id or 0, ctx.votes))

  TriggerEvent('gtaservers:vote', src, vote)
  return true
end
