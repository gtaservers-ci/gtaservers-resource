fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gtaservers'
description 'Vote rewards for your gtaservers.org listing: /vote opens the vote page, votes are paid in game.'
author 'gtaservers.org'
version '1.0.3'
-- MIT, see LICENSE beside this file: install it, change it, ship your changes.
license 'MIT'
url 'https://gtaservers.org/developer'

-- config.lua is a server script on purpose: it can hold a Discord webhook,
-- and a shared script would hand every player a copy.
server_scripts {
  'config.lua',
  'locales/*.lua',
  'server/api.lua',
  'server/rewards.lua',
  'server/sync.lua',
  'server/main.lua',
}

client_scripts {
  'locales/*.lua',
  'client/main.lua',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/app.js',
}
