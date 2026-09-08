--- The poll loop: every pollSeconds (5 for two minutes after a /vote, and at
--- once when a player joins) ask gtaservers.org for unrewarded votes, pay the
--- players who are online, and claim what was paid.
Sync = {}

State = {
  verified = false,
  reason = nil,
  server = nil,
  latestVersion = nil,
  lastSyncAt = 0,
}

local KVP_PENDING = 'gtaservers:pending_claim'
local HOT_SECONDS = 120
local HOT_INTERVAL = 5
--- How long a sync may be in flight before another is allowed, so a callback
--- that never fires cannot hold the loop shut for the life of the server.
local STUCK_SECONDS = 60

local online = {}      -- identifier -> server id
local joined = {}      -- identifiers that joined since the last successful sync
local joinedSet = {}
local pending = {}     -- vote ids paid, not yet acknowledged by claim
local pendingSet = {}
local pollSeconds = 30
local hotUntil = 0
local inFlight = false
local inFlightAt = 0
local lastReason = nil
local lastFailure = nil
local warnedVersion = nil

--- The saved list is a safety net against paying a vote twice across a
--- restart, not the state: gtaservers.org holds that. An unreadable store
--- costs at worst one double payment, so it must never stop the loop.
local function loadPending()
  local raw = GetResourceKvpString(KVP_PENDING)
  if raw and raw ~= '' then
    local ok, ids = pcall(json.decode, raw)
    if ok and type(ids) == 'table' then
      for _, id in ipairs(ids) do
        pending[#pending + 1] = id
        pendingSet[id] = true
      end
    end
  end
end

local function savePending()
  if #pending == 0 then
    DeleteResourceKvp(KVP_PENDING)
  else
    SetResourceKvp(KVP_PENDING, json.encode(pending))
  end
end

local function markPending(id)
  if pendingSet[id] then return end
  pending[#pending + 1] = id
  pendingSet[id] = true
  savePending()
end

local function clearPending(ids)
  local drop = {}
  for _, id in ipairs(ids) do drop[id] = true end
  local kept = {}
  for _, id in ipairs(pending) do
    if drop[id] then
      pendingSet[id] = nil
    else
      kept[#kept + 1] = id
    end
  end
  pending = kept
  savePending()
end

local function claim()
  if #pending == 0 then return end
  local ids = {}
  for index, id in ipairs(pending) do
    if index > 200 then break end
    ids[#ids + 1] = id
  end
  Api.post('/api/resource/claim', { vote_ids = ids }, function(status)
    if status == 200 then
      clearPending(ids)
    end
  end)
end

--- Poll fast for a couple of minutes, so a reward lands seconds after a vote.
function Sync.expectVote()
  hotUntil = os.time() + HOT_SECONDS
end

---@return table<string, number> identifier -> server id
function Sync.online()
  return online
end

--- Printed once and again only when it changes, to keep a stuck server from
--- writing a console line every poll forever.
local function printReason(reason)
  if reason == lastReason then return end
  lastReason = reason
  if reason == 'server_offline' then
    print(L('start_offline'))
  elseif reason == 'wrong_listing' then
    print(L('start_wrong_listing'))
  elseif reason == 'frozen' then
    print(L('start_frozen'))
  elseif reason == 'revoked' then
    print(L('start_revoked'))
  elseif reason == 'not_ready' then
    print(L('start_not_ready'))
  else
    print(L('start_waiting'))
  end
end

--- A failure with no reason behind it: the request never arrived, or the site
--- answered something unexpected. Deduplicated like printReason.
local function printFailure(key, ...)
  if lastFailure == key then return end
  lastFailure = key
  print(L(key, ...))
end

function Sync.tick()
  if Api.token() == '' then return end
  if inFlight and os.time() - inFlightAt < STUCK_SECONDS then return end
  inFlight = true
  inFlightAt = os.time()

  local batch = joined
  joined = {}

  Api.post('/api/resource/sync', {
    config = {
      version = VERSION,
      reward = Config.RewardDescription,
      players = #GetPlayers(),
      framework = Rewards.framework(),
    },
    joined = batch,
  }, function(status, data)
    inFlight = false

    -- Anything but a 200 means no votes: the site refuses the route with 403
    -- not_verified, and a reason, until the listing is claimed.
    if status ~= 200 then
      for _, id in ipairs(batch) do joined[#joined + 1] = id end
      local code = Api.errorCode(data)
      if code == 'token_revoked' or code == 'bad_token' then
        State.verified = false
        printReason('revoked')
      elseif code == 'not_verified' then
        State.verified = false
        State.reason = Api.errorReason(data)
        printReason(State.reason)
      elseif code == 'not_ready' then
        printReason('not_ready')
      elseif status == 0 then
        -- DNS, TLS or an outbound firewall on the game server: the site never
        -- saw the request.
        printFailure('sync_unreachable', Api.base())
      elseif status ~= 429 then
        printFailure('sync_failed', tostring(status))
      end
      return
    end

    for _, id in ipairs(batch) do joinedSet[id] = nil end
    State.lastSyncAt = os.time()
    lastFailure = nil

    local config = type(data.config) == 'table' and data.config or {}
    State.server = config.server
    State.latestVersion = config.latest_version
    if type(config.poll_seconds) == 'number' and config.poll_seconds >= 5 then
      pollSeconds = config.poll_seconds
    end

    if config.latest_version and config.latest_version ~= VERSION and warnedVersion ~= config.latest_version then
      warnedVersion = config.latest_version
      print(L('update_available', config.latest_version, VERSION))
    end

    local wasVerified = State.verified
    State.verified = true
    State.reason = nil
    if not wasVerified then
      print(L('start_linked', (config.server and config.server.name) or ''))
      lastReason = nil
    end

    for _, vote in ipairs(data.votes or {}) do
      local src = online[vote.identifier]
      if src and not pendingSet[vote.id] and GetPlayerName(src) then
        markPending(vote.id)
        local ok, err = pcall(Rewards.pay, src, vote)
        if not ok then
          print(L('reward_failed', 'vote ' .. tostring(vote.id), vote.name or vote.identifier, tostring(err)))
        end
      end
    end

    claim()
  end)
end

AddEventHandler('playerJoining', function()
  local src = source
  local identifier = PlayerIdentity(src)
  if not identifier then return end
  online[identifier] = src
  if not joinedSet[identifier] then
    joinedSet[identifier] = true
    joined[#joined + 1] = identifier
  end
  -- Pay a vote cast while away within seconds of loading in.
  SetTimeout(3000, Sync.tick)
end)

AddEventHandler('playerDropped', function()
  local src = source
  for identifier, id in pairs(online) do
    if id == src then
      online[identifier] = nil
    end
  end
end)

function Sync.start()
  local loaded, err = pcall(loadPending)
  if not loaded then
    print(L('pending_unreadable', tostring(err)))
  end
  -- Players already connected when the resource (re)starts.
  for _, id in ipairs(GetPlayers()) do
    local src = tonumber(id)
    local identifier = PlayerIdentity(src)
    if identifier then
      online[identifier] = src
      if not joinedSet[identifier] then
        joinedSet[identifier] = true
        joined[#joined + 1] = identifier
      end
    end
  end
  if #pending > 0 then
    claim()
  end
  CreateThread(function()
    while true do
      Sync.tick()
      local interval = os.time() < hotUntil and HOT_INTERVAL or pollSeconds
      Wait(interval * 1000)
    end
  end)
end
