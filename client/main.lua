RegisterNetEvent('gtaservers:openVote', function(url, openBrowser)
  if type(url) ~= 'string' then return end
  TriggerEvent('chat:addMessage', { args = { 'Vote', L('vote_link', url) } })
  if openBrowser then
    -- html/app.js hands the link to the player's browser.
    SendNUIMessage({ action = 'open', url = url })
    TriggerEvent('chat:addMessage', { args = { 'Vote', L('vote_opened') } })
  end
end)

RegisterNetEvent('gtaservers:notify', function(message)
  if type(message) ~= 'string' then return end
  TriggerEvent('chat:addMessage', { args = { 'Vote', message } })
end)

RegisterNetEvent('gtaservers:suggest', function(command)
  if type(command) ~= 'string' then return end
  TriggerEvent('chat:addSuggestion', '/' .. command, L('suggestion_vote'))
end)

-- The command is named in config.lua, so ask the server what to suggest.
AddEventHandler('onClientResourceStart', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  TriggerServerEvent('gtaservers:requestSuggestion')
end)
