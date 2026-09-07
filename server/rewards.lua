--- Paying a vote: every entry in Config.Rewards through the adapter for the
--- framework that is running, then any milestone the player's lifetime count
--- hits, then the announcement, the webhook and the event other scripts can
--- listen for. One pipeline for real votes and for /forcevote.
Rewards = {}

local framework = 'none'
local ESX, QBCore

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
  return framework
end

function Rewards.framework()
  return framework
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

local function substitute(template, ctx)
  return (tostring(template):gsub('{(%w+)}', function(key)
    local value = ctx[key]
    if value == nil then return '{' .. key .. '}' end
    return tostring(value)
  end))
end

local function give(src, reward, vote, ctx)
  local kind = reward.type
  if kind == 'money' then
    local adapter = money[framework]
    if not adapter then
      print(L('no_framework_for', 'money'))
      return
    end
    adapter(src, reward)
  elseif kind == 'item' then
    if hasOxInventory() then
      exports.ox_inventory:AddItem(src, reward.name, reward.count or 1)
      return
    end
    local adapter = item[framework]
    if not adapter then
      print(L('no_framework_for', 'item'))
      return
    end
    adapter(src, reward)
  elseif kind == 'command' then
    ExecuteCommand(substitute(reward.run, ctx))
  elseif kind == 'event' then
    TriggerEvent(reward.name, src, vote)
  elseif kind == 'function' then
    reward.run(src, vote)
  else
    print(('[gtaservers] Unknown reward type "%s" in config.lua'):format(tostring(kind)))
  end
end

local function webhook(text)
  if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end
  PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({ content = text }), {
    ['Content-Type'] = 'application/json',
  })
end

--- vote: { id, identifier, name, voted_at, total_votes, forced, note }
function Rewards.pay(src, vote)
  local name = vote.name or GetPlayerName(src) or 'player'
  local ctx = {
    id = src,
    name = name,
    identifier = vote.identifier or '',
    votes = vote.total_votes or 0,
    reward = Config.RewardDescription or '',
  }

  for index, reward in ipairs(Config.Rewards or {}) do
    local ok, err = pcall(give, src, reward, vote, ctx)
    if not ok then
      print(L('reward_failed', tostring(reward.type or index), name, tostring(err)))
    end
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

  webhook(vote.forced
    and ('Forced vote reward for %s (%s)%s'):format(name, ctx.identifier, vote.note and (': ' .. vote.note) or '')
    or ('%s voted for the server (%s, vote #%d, %d lifetime)'):format(name, ctx.identifier, vote.id or 0, ctx.votes))

  TriggerEvent('gtaservers:vote', src, vote)
end
