Config = {}

-- The command players type. /vote opens the vote page in their browser.
Config.Command = 'vote'

-- Open the vote page in the player's browser (FiveM asks them once to allow
-- it). The link is also printed in chat, for players who decline.
Config.OpenBrowser = true

-- How players are identified. 'license' is the Rockstar account: everyone has
-- one, it is the same on every server and on both Legacy and Enhanced, and it
-- is what ESX, QBCore and Qbox key their player tables on. 'license2',
-- 'fivem', 'discord' and 'steam' also work, as does a function(source)
-- returning your own id as a string.
Config.Identifier = 'license'

-- Shown on your gtaservers.org listing: "Vote and get $5,000 cash in-game".
-- Up to 60 characters.
Config.RewardDescription = '$5,000 cash'

-- What every vote pays. ESX, QBCore and Qbox are detected automatically, and
-- ox_inventory is used for items when it is running. 'command' runs a console
-- command and works on any server. Placeholders in command strings:
--   {id}          the player's server id
--   {name}        their name
--   {identifier}  their identifier, e.g. license:8f2a...
--   {votes}       their lifetime vote count for this server
Config.Rewards = {
  { type = 'money', account = 'cash', amount = 5000 },
  -- { type = 'item',     name = 'vote_crate', count = 1 },
  -- { type = 'command',  run = 'givecar {id} sultan' },
  -- { type = 'event',    name = 'myserver:onVote' },          -- TriggerEvent(name, source, vote)
  -- { type = 'function', run = function(source, vote) end },
}

-- Extra rewards when a player's lifetime vote count for this server hits a
-- number. The count comes from gtaservers.org, so it survives wipes.
Config.Milestones = {
  -- [10] = { { type = 'command', run = 'announce {name} has voted 10 times!' } },
}

-- A chat line for everyone when a vote is rewarded. {reward} is the reward
-- description above. Set to '' to disable.
Config.Announce = '{name} just voted for the server. Type /vote for {reward}!'

-- A Discord webhook that gets one line per reward. Leave empty for none.
Config.DiscordWebhook = ''

-- The ace that allows /forcevote in game (the server console can always use
-- it): add_ace group.admin gtaservers.admin allow
Config.AdminAce = 'gtaservers.admin'

Config.Locale = 'en'
