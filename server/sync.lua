--- The loop: every poll_seconds (30 at rest, 5 for two minutes after anyone
--- types /vote, and at once when someone joins) ask gtaservers.org for the
--- unrewarded votes, pay the players who are online, and claim what was paid.
--- The site holds the only copy of the state; the one thing kept here is the
--- handful of vote ids paid but not yet acknowledged, so a crash in that gap
--- re-sends the claim instead of paying twice.
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

local online = {}      -- identifier -> server id
local joined = {}      -- identifiers that joined since the last successful sync
local joinedSet = {}
local pending = {}     -- vote ids paid, not yet acknowledged by claim
local pendingSet = {}
local pollSeconds = 30
local hotUntil = 0
local inFlight = false
local lastReason = nil
local warnedVersion = nil

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

--- Called after a /vote: poll fast for a couple of minutes so the reward
--- lands seconds after the vote does.
function Sync.expectVote()
  hotUntil = os.time() + HOT_SECONDS
end

function Sync.online()
  return online
end

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

function Sync.tick()
  if inFlight or Api.token() == '' then return end
  inFlight = true

  local batch = joined
  joined = {}

  Api.post('/api/resource/sync', {
    version = VERSION,
    reward = Config.RewardDescription,
    players = #GetPlayers(),
    framework = Rewards.framework(),
    joined = batch,
  }, function(status, data)
    inFlight = false

    if status ~= 200 then
      for _, id in ipairs(batch) do joined[#joined + 1] = id end
      local code = Api.errorCode(data)
      if code == 'token_revoked' or code == 'bad_token' then
        State.verified = false
        printReason('revoked')
      elseif code == 'not_ready' then
        printReason('not_ready')
      end
      return
    end

    for _, id in ipairs(batch) do joinedSet[id] = nil end
    State.lastSyncAt = os.time()
    State.server = data.server
    State.latestVersion = data.latest_version
    if type(data.poll_seconds) == 'number' and data.poll_seconds >= 5 then
      pollSeconds = data.poll_seconds
    end

    if data.latest_version and data.latest_version ~= VERSION and warnedVersion ~= data.latest_version then
      warnedVersion = data.latest_version
      print(L('update_available', data.latest_version, VERSION))
    end

    local wasVerified = State.verified
    State.verified = data.verified == true
    State.reason = data.reason
    if State.verified then
      if not wasVerified then
        print(L('start_linked', (data.server and data.server.name) or ''))
        lastReason = nil
      end
    else
      printReason(data.reason)
      return
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
  -- Pay a vote they cast while away within seconds of loading in.
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
  loadPending()
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
