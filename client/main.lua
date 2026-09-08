RegisterNetEvent('gtaservers:openVote', function(url, openBrowser)
  if type(url) ~= 'string' then return end
  TriggerEvent('chat:addMessage', { args = { 'Vote', L('vote_link', url) } })
  if openBrowser then
    -- html/app.js hands the link to the player's browser.
    SendNUIMessage({ action = 'open', url = url })
  end
end)

RegisterNetEvent('gtaservers:notify', function(message)
  if type(message) ~= 'string' then return end
  TriggerEvent('chat:addMessage', { args = { 'Vote', message } })
end)
