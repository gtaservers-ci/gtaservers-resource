# Changelog

Every released version of the gtaservers resource, newest first. The top
entry's version must match `version` in fxmanifest.lua: CI fails the pull
request if they drift, because a change that ships without a bump never
reaches anybody (the site's "update available" notice compares the two).

## 1.1.0 - 2026-09-07

- A vote is no longer counted as paid when the reward did not actually reach
  the player. Until now a reward that could not be given (no framework running,
  or a player whose character had not loaded yet) was still reported paid: the
  player was thanked, and the vote was spent with nothing to show for it. Such
  a vote is now retried on the following polls, and only given up on (with a
  console line naming it) after ten of them.
- Votes cast while a player was away are paid as their character loads, rather
  than a few seconds after they connect, which was usually too early for ESX,
  QBCore or Qbox to have a player to pay.
- The framework is looked for again while none has been found, instead of only
  once at start-up. A server that started this resource before es_extended
  would otherwise never pay a money or item reward.
- Player names are stripped of quotes, semicolons and angle brackets before
  they go into a `command` reward or the announcement, so a name cannot add
  arguments to a console command or markup to the chat box.
- `/vote` is limited to once every ten seconds per player, and now shows up in
  the chat suggestion list.
- New `Config.Notify`: hand player-facing messages to your own notification
  system instead of chat.
- New `Config.WebhookIdentifier`, off by default: the Discord webhook line no
  longer carries the player's `license:...` identifier unless you ask for it.
  Webhook posts also no longer resolve mentions, so a player cannot name
  themselves `@everyone` and ping your staff channel.

## 1.0.5 - 2026-09-07

- Code cleanup: tidier comments and doc annotations across the Lua. Nothing
  behaves differently.
- The locale lookup no longer shadows Lua's `table` library, which would have
  broken any locale string added below it that used `table.concat`.

## 1.0.4 - 2026-09-07

- A server that cannot reach gtaservers.org now says so in the console. Until
  now a sync that got no answer at all (DNS, TLS or an outbound firewall on the
  game server) printed nothing, so a server could sit claimed and never paying
  a reward with no sign of why.
- A sync whose answer never arrives no longer stops the loop for good. It could
  previously leave the resource looking loaded and healthy while it had quietly
  stopped asking for votes.
- A saved claim list that cannot be read no longer takes the whole sync loop
  with it. It is a safety net against paying a vote twice across a restart, and
  losing it is worth far less than losing rewards entirely.

## 1.0.3 - 2026-09-07

- Fixes `/vote` answering "Voting is not set up on this server yet." on servers
  that are verified, and rewards never paying with it. The site changed the
  shape of its sync reply; the resource now reads it, treats a successful sync
  as verified, and only reports the server as unverified when the site actually
  says so (with the reason it gives).
- The version, reward description, framework and player count a server reports
  reach the site again, so the dashboard and the "update available" notice stop
  showing every server as 0.0.0.

## 1.0.2 - 2026-09-07

- The console notices, the README and the manifest link to
  `gtaservers.org/developer`. The owner area moved there from `/owners` and
  `/server-owners`, which only still work as redirects.

## 1.0.1 - 2026-09-07

- The "update available" console notice links to the releases page on GitHub.
  The site no longer serves the resource itself, so the address it printed
  before (`gtaservers.org/download/resource`) no longer exists.

## 1.0.0 - 2026-09-07

- First release. `/vote` opens the vote page and prints the link in chat,
  votes are paid in game from `config.lua`, and `/forcevote` runs a reward
  for testing.
