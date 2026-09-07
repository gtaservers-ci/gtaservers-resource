# Changelog

Every released version of the gtaservers resource, newest first. The top
entry's version must match `version` in fxmanifest.lua: CI fails the pull
request if they drift, because a change that ships without a bump never
reaches anybody (the site's "update available" notice compares the two).

## 1.0.1 - 2026-09-07

- The "update available" console notice links to the releases page on GitHub.
  The site no longer serves the resource itself, so the address it printed
  before (`gtaservers.org/download/resource`) no longer exists.

## 1.0.0 - 2026-09-07

- First release. `/vote` opens the vote page and prints the link in chat,
  votes are paid in game from `config.lua`, and `/forcevote` runs a reward
  for testing.
