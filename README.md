# gtaservers

Vote rewards for your gtaservers.org listing. Players type `/vote`, the vote
page opens in their browser, and the vote is paid in game with a reward you
choose. One resource for FiveM Legacy and FiveM for GTAV Enhanced.

The source is at https://github.com/gtaservers-ci/gtaservers-resource, a
read-only mirror of the copy in the gtaservers.org repository where this is
developed. Every release overwrites it, so a pull request opened there is lost
(open an issue instead). Past versions, their notes and their zips are on that
repository's releases page; CHANGELOG.md beside this file has the same notes.

## Install

1. Sign in at https://gtaservers.org/developer and add your server. You get a
   token and the two lines below.
2. Unzip this folder to `resources/gtaservers/`.
3. Add to `server.cfg`, in either order:

   ```
   ensure gtaservers
   set gtaservers_token "gs_..."
   ```

   `set`, never `sets`. `sets` would publish your token in the FiveM server
   list, and any token seen there is revoked.

4. Restart. The console prints `Linked to gtaservers.org as "<your server>"`
   within a few minutes, once the FiveM server list has picked up the server.
5. Edit `config.lua`: what a vote pays, and the reward text shown on your
   listing. Test it with `/forcevote <player id>`.

## Commands

- `/vote` — for players. Opens the vote page in their browser (FiveM asks them
  once to allow it) and prints the link in chat. A player who already voted is
  told when they can vote again.
- `/forcevote <player id> [note]` — runs the reward for a player exactly as a
  real vote would, for testing or compensation. Never counts as a vote. Needs
  `add_ace group.admin gtaservers.admin allow`, or the server console.

## config.lua

```lua
Config.RewardDescription = '$5,000 cash'   -- shown on your listing, up to 60 characters

Config.Rewards = {
  { type = 'money',   account = 'cash', amount = 5000 },        -- ESX, QBCore, Qbox
  -- { type = 'item',     name = 'vote_crate', count = 1 },      -- ox_inventory or the framework
  -- { type = 'command',  run = 'givecar {id} sultan' },         -- {id} {name} {identifier} {votes}
  -- { type = 'event',    name = 'myserver:onVote' },            -- TriggerEvent(name, source, vote)
  -- { type = 'function', run = function(source, vote) end },
}

Config.Milestones = { [10] = { { type = 'command', run = 'announce {name} has voted 10 times!' } } }

Config.Notify = function(source, message) end   -- your notification system, instead of chat
Config.WebhookIdentifier = false                -- put license:... in the Discord line too
```

Other scripts can listen for `gtaservers:vote` (`source, vote`), which fires
after every reward; `vote.forced` is true for `/forcevote`.

## How it works

The resource announces the public half of your token as a server-info var.
gtaservers.org reads it back from the FiveM directory on the listing the
token was issued for, and that is what proves the server is yours. Every 30
seconds (5 seconds for two minutes after a `/vote`, and at once when a player
joins or their character loads) it asks gtaservers.org for the votes that have
not been rewarded, pays the ones whose player is online, and reports them paid.
A vote whose reward could not be given is left unpaid and tried again on the
next polls, so nothing is spent without reaching the player. A vote cast while a
player was away, or for a server they have never joined, is paid when they
join, for up to 30 days. Nothing is stored here but the token in your
`server.cfg` and, briefly, the ids of votes paid but not yet reported.

Local development: `set gtaservers_api "http://127.0.0.1:8787"` points the
resource at a local copy of the site.
