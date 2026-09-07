--- Nothing here touches the game: the link goes to chat, and to the NUI page
--- that opens it in the player's browser. Both work on Legacy and Enhanced.

RegisterNetEvent('gtaservers:openVote', function(url, openBrowser)
  if type(url) ~= 'string' then return end
  TriggerEvent('chat:addMessage', { args = { 'Vote', L('vote_link', url) } })
  if openBrowser then
    SendNUIMessage({ action = 'open', url = url })
  end
end)

RegisterNetEvent('gtaservers:notify', function(message)
  if type(message) ~= 'string' then return end
  TriggerEvent('chat:addMessage', { args = { 'Vote', message } })
end)
