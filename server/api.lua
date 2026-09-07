--- The one way this resource talks to gtaservers.org: POST JSON with the
--- server token as a bearer, get JSON back. Three routes exist and nothing
--- else calls them (docs/server-owner-design.html in the site's repo).
Api = {}

local BASE = GetConvar('gtaservers_api', 'https://gtaservers.org')
VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'

function Api.base()
  return BASE
end

function Api.token()
  return GetConvar('gtaservers_token', '')
end

--- The eight characters after `gs_`: what the server announces publicly.
function Api.publicHalf()
  return Api.token():match('^gs_(%w%w%w%w%w%w%w%w)_%w+$')
end

--- cb(status, data): status is 0 when the request never got an answer, and
--- data is the decoded body or an empty table.
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

function Api.errorCode(data)
  return type(data) == 'table' and type(data.error) == 'table' and data.error.code or nil
end

--- Why a not_verified refusal was given: one of the reasons printReason knows
--- (waiting_for_directory, server_offline, wrong_listing, frozen).
function Api.errorReason(data)
  return type(data) == 'table' and type(data.error) == 'table' and data.error.reason or nil
end
