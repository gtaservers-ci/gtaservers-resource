Locales = Locales or {}

Locales['en'] = {
  -- players
  vote_link = 'Vote for this server: %s',
  vote_opened = 'Opening the vote page in your browser. If nothing opens, use the link above.',
  already_voted = 'You have already voted. You can vote again in %s.',
  not_set_up = 'Voting is not set up on this server yet.',
  vote_unavailable = 'Voting is unavailable right now. Try again in a minute.',
  reward_paid = 'Thanks for voting! You received %s.',
  console_cannot_vote = 'Type /vote in game, not in the console.',
  forcevote_denied = 'You are not allowed to use /forcevote.',
  forcevote_usage = 'Usage: /forcevote <player id> [note]',
  forcevote_no_player = 'No player with id %s is online.',
  forcevote_done = 'Forced a vote reward for %s (id %s).',

  -- console
  start_no_token = '[gtaservers] No token set. Add your server at https://gtaservers.org/owners, then put `set gtaservers_token "gs_..."` in server.cfg.',
  start_bad_token = '[gtaservers] The gtaservers_token convar does not look like a token (gs_xxxxxxxx_...). Copy it again from your dashboard.',
  start_waiting = '[gtaservers] Waiting for the FiveM server list to show this server with the token (usually under three minutes).',
  start_offline = '[gtaservers] This server is not in the FiveM server list right now; the token verifies once it appears.',
  start_wrong_listing = '[gtaservers] The token is running on a different listing than the one it was issued for. Add this server on your dashboard to get its own.',
  start_frozen = '[gtaservers] The listing is frozen on gtaservers.org; no transfer can complete.',
  start_linked = '[gtaservers] Linked to gtaservers.org as "%s". Rewards are on.',
  start_revoked = '[gtaservers] The token was revoked. Get a new one from https://gtaservers.org/owners and put it in server.cfg.',
  start_not_ready = '[gtaservers] gtaservers.org is not accepting tokens yet. Retrying.',
  update_available = '[gtaservers] Version %s is available (you run %s): https://github.com/gtaservers-ci/gtaservers-resource/releases',
  reward_failed = '[gtaservers] Reward %s failed for %s: %s',
  no_framework_for = '[gtaservers] No framework found for a %s reward; use a command reward or install ESX, QBCore or Qbox.',
  forced = '[gtaservers] Forced reward for %s (%s) by %s%s',
}

--- Looks a string up in the configured locale, falling back to English, and
--- formats it with the arguments given.
function L(key, ...)
  local locale = (Config and Config.Locale) or 'en'
  local table = Locales[locale] or Locales['en']
  local text = table[key] or Locales['en'][key] or key
  if select('#', ...) > 0 then
    return string.format(text, ...)
  end
  return text
end
