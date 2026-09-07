# Changelog

Every released version of the gtaservers resource, newest first. The top
entry's version must match `version` in fxmanifest.lua: CI fails the pull
request if they drift, because a change that ships without a bump never
reaches anybody (the site's "update available" notice compares the two).

## 1.0.0 - 2026-09-07

- First release. `/vote` opens the vote page and prints the link in chat,
  votes are paid in game from `config.lua`, and `/forcevote` runs a reward
  for testing.
