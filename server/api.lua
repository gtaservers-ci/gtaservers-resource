--- HTTP to gtaservers.org. POST JSON with the server token as a bearer, get
--- JSON back.
Api = {}

local BASE = GetConvar('gtaservers_api', 'https://gtaservers.org')
VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'

---@return string
function Api.base()
  return BASE
end

---@return string
function Api.token()
  return GetConvar('gtaservers_token', '')
end

--- The eight characters after `gs_`, the half of the token the server
--- announces publicly.
---@return string?
function Api.publicHalf()
  return Api.token():match('^gs_(%w%w%w%w%w%w%w%w)_%w+$')
end

---@param path string
---@param body table?
---@param cb fun(status: number, data: table) status is 0 when nothing answered
function Api.post(path, body, cb)
  PerformHttpRequest(BASE .. path, function(status, text)
    local data = {}
    if text and text ~= '' then
      local ok, decoded = pcall(json.decode, text)
      if ok and type(decoded) == 'table' then
        data = decoded
      end
    end
    cb(status or 0, data)
  end, 'POST', json.encode(body or {}), {
    ['Content-Type'] = 'application/json',
    ['Authorization'] = 'Bearer ' .. Api.token(),
    ['User-Agent'] = 'gtaservers-resource/' .. VERSION,
  })
end

---@param data table
---@return string?
function Api.errorCode(data)
  return type(data) == 'table' and type(data.error) == 'table' and data.error.code or nil
end

--- waiting_for_directory, server_offline, wrong_listing or frozen.
---@param data table
---@return string?
function Api.errorReason(data)
  return type(data) == 'table' and type(data.error) == 'table' and data.error.reason or nil
end
