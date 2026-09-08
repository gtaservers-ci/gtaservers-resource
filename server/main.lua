--- Start-up, player identity and the two commands.

--- The identifier a player votes as, from Config.Identifier.
---@param src number
---@return string?
function PlayerIdentity(src)
  local kind = Config.Identifier or 'license'
  if type(kind) == 'function' then
    local id = kind(src)
    return id and tostring(id) or nil
  end
  return GetPlayerIdentifierByType(src, kind)
    or GetPlayerIdentifierByType(src, 'license')
    or GetPlayerIdentifierByType(src, 'fivem')
    or GetPlayerIdentifierByType(src, 'discord')
end

---@param src number
---@param message string
function Notify(src, message)
  TriggerClientEvent('gtaservers:notify', src, message)
end

---@param untilAt number? unix time
---@return string
local function countdown(untilAt)
  local seconds = math.max(0, (tonumber(untilAt) or 0) - os.time())
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  if hours > 0 then
    return ('%dh %02dm'):format(hours, minutes)
  end
  return ('%dm'):format(math.max(1, minutes))
end

CreateThread(function()
  local warned = false
  while Api.token() == '' do
    if not warned then
      print(L('start_no_token'))
      warned = true
    end
    Wait(15000)
  end

  local public = Api.publicHalf()
  if not public then
    print(L('start_bad_token'))
    return
  end

  -- Announced in the FiveM server list, where gtaservers.org reads it back to
  -- verify the listing. It holds none of the secret half of the token.
  SetConvarServerInfo('gtaservers', public)

  Rewards.detect()
  Sync.start()
end)

RegisterCommand(Config.Command or 'vote', function(source)
  if source == 0 then
    print(L('console_cannot_vote'))
    return
  end
  if not State.verified then
    Notify(source, L('not_set_up'))
    return
  end
  local identifier = PlayerIdentity(source)
  if not identifier then
    Notify(source, L('vote_unavailable'))
    return
  end
  local src = source
  Api.post('/api/resource/vote-link', { identifier = identifier, name = GetPlayerName(src) }, function(status, data)
    if status ~= 200 or type(data.url) ~= 'string' then
      Notify(src, L('vote_unavailable'))
      return
    end
    if data.already_voted then
      Notify(src, L('already_voted', countdown(data.next_vote_at)))
      return
    end
    Sync.expectVote()
    TriggerClientEvent('gtaservers:openVote', src, data.url, Config.OpenBrowser ~= false)
  end)
end, false)

RegisterCommand('forcevote', function(source, args)
  if source ~= 0 and not IsPlayerAceAllowed(source, Config.AdminAce or 'gtaservers.admin') then
    Notify(source, L('forcevote_denied'))
    return
  end
  local reply = function(message)
    if source == 0 then print(message) else Notify(source, message) end
  end
  local target = tonumber(args[1])
  if not target then
    reply(L('forcevote_usage'))
    return
  end
  local name = GetPlayerName(target)
  if not name then
    reply(L('forcevote_no_player', tostring(args[1])))
    return
  end
  local note = #args > 1 and table.concat(args, ' ', 2) or nil
  local by = source == 0 and 'console' or (GetPlayerName(source) .. ' (' .. tostring(PlayerIdentity(source)) .. ')')
  local vote = {
    id = 0,
    identifier = PlayerIdentity(target) or '',
    name = name,
    voted_at = os.time(),
    total_votes = 0,
    forced = true,
    note = note,
  }
  local ok, err = pcall(Rewards.pay, target, vote)
  if not ok then
    reply(L('reward_failed', 'forced', name, tostring(err)))
    return
  end
  print(L('forced', name, vote.identifier, by, note and (': ' .. note) or ''))
  reply(L('forcevote_done', name, tostring(target)))
end, false)
