# DeathRollForever — Product overview

Status: v2 released as v0.1.0 on 2026-11-06; v3 (one-round rules) in progress. The behaviour is in [docs/prd/](docs/prd/README.md);
this page is the intent and the roadmap. Anything written here and in a
feature document lives in the feature document.

## 1. What it is

A World of Warcraft: Forever addon that runs multiplayer death roll events in
guild, party or raid chat. One host with the addon runs the game. Everyone else
plays with nothing but chat: type the join word, then `/roll 100` once when
called. The highest roll wins and the lowest roll pays the difference as a
share of the wager, so a close game costs little and a heartbreaker costs
almost the whole stake.
Later versions give players who also have the addon a live window, a ROLL
button and a payment ledger that ticks off debts as trades happen.

Target client: WoW Forever (`_forever_`, Interface 16001, modern retail API).

## 2. Goals and non-goals

Goals
- Run a whole event (lobby, one round of rolls, the result, who owes what)
  from chat, in a couple of minutes.
- Require the addon only on the host.
- Keep the game moving: timers, reminders, sat-outs.
- Later: make settling up visible, who owes whom and who has paid.

Non-goals
- Say, yell, general or custom channels (Blizzard blocks automatic posting
  there).
- Two-player private games by whisper (maybe later).
- Anything that needs a server or a website.
- Moving gold. Debts are informational.

## 3. Roles

| Role | Needs addon | What they do |
|------|-------------|--------------|
| Host | Yes | Starts and can cancel the game. May also play |
| Player | No | Types the join word in chat, then `/roll 100` when called |
| Addon player (v4+) | Yes | Same, plus the window, ROLL button, ledger |
| Watcher (v4+) | Yes | In the chat but did not join. Sees the window |

## 4. Roadmap

| Version | Adds | Spec |
|---------|------|------|
| v1 | Host runs a whole game from chat: `/dr g 1g`, join by typing `1`, countdowns, shuffled order, calls that say what to type, 45 s turns with reminders and forfeit, winner line with who owes what | superseded by v3 |
| v2 | The host's window: form, lobby, rolling and winner states, Roll and Cancel buttons, faction tint | [docs/prd/visual.md](docs/prd/visual.md) |
| v3 | One-round rules: everyone rolls once, highest wins, lowest pays `(highest - lowest) x wager / roll max`; sat-outs, tie-breaks; the window redrawn; a `?` hover box; `/dr` opens the window | [docs/prd/functional.md](docs/prd/functional.md), [docs/prd/visual.md](docs/prd/visual.md) |
| v3.1 | Solo games: you against 1 to 40 bots in the window, no chat, no group needed; for practice and for testing a release alone | [docs/prd/functional/06-solo.md](docs/prd/functional/06-solo.md) |
| v4 | Sync: addon players see the window live, ROLL button, auto-roll if the client allows it | not yet written; notes in section 5 |
| v5 | Ledger and trade detection: the debt marked paid, `/dr owed`, paid notices in chat | not yet written; notes in section 5 |
| v6 | Settings, saved variables, history and stats, host resumes after `/reload` | not yet written; notes in section 5 |

Decisions already taken for later versions are in the
[decisions log](docs/prd/functional.md#8-decisions-log).

## 5. Design notes for later versions

These are intent, kept here until each version gets its feature documents.
They are not contracts.

### The window (v2)

The window spec is [docs/prd/visual.md](docs/prd/visual.md). It builds the
host's window with the form, lobby, rolling and winner states, Roll and
Cancel, the `?` hover box and the faction tint, movable and resizable. The
rest of this note (remembering position, auto-open, settings, Join and Kick,
the ledger ticks, crests per name) moves to v4 to v6.

Movable, remembers its position, opens itself when a game is announced in a
chat you are in. One window, five views: new game, lobby, game, result,
settings. The first four swap by phase; settings opens from a gear icon in the
title bar and returns to where you were.

- **New game:** chat (guild, party, raid; only the ones you are in enabled),
  wager box with the parsed amount echoed in coin icons and a `?` tooltip
  listing the accepted forms, roll max, time to join, join word, Start.
  Last game's values remembered.
- **Lobby:** title line, big countdown that turns red under 10 s, joined
  players in join order with a count, Join button, host-only Cancel.
- **Game:** who is still to roll dimmed at the top, the highest roll tinted,
  the lowest under it, the rest fanned out from both ends, status line with
  what to type, big ROLL button until you have rolled, roll timer bar,
  host-only Kick and Cancel.
- **Result:** winner, the ledger with a tick per paid debt, your record
  against the winner, Close.
- **Settings:** join time, roll time, roll max, join word, auto-roll, paid
  notices in chat, auto-open, window scale, reset, back. Also reachable from
  the game's AddOns options.
- **Faction flair:** title bar, highlight, timer bar and ROLL button tinted
  Alliance blue or Horde red from your own faction; a small crest by the
  title; per-name crests only in mixed-faction groups.

### Sync (v4)

The host's addon is the single source of truth and broadcasts the whole game
after every change as hidden addon messages (AceComm-3.0) to the same chat.
Non-host addons draw whatever they last received. Messages carry a version;
newer versions are ignored with a notice. Whether auto-roll can exist depends
on the Phase 0 `[P0-AUTOROLL]` check.

### Ledger and payments (v5)

At the end, the loser owes the winner the amount the result line said. The
addon watches the trade window; when the loser trades the winner at least
that amount, the debt is marked paid by whichever addon saw it, which tells the others and
posts a paid line in chat (on by default, with a setting to turn it off).
`/dr owed` reposts the outstanding ledger. Every addon keeps its own copy, so
the ledger survives the host logging off.

### Saved data, history, stats (v6)

Settings and window position; finished games with date, chat, host, wager,
players, winner and ledger; the host's live game so a `/reload` resumes it.
`/dr stats [name]` shows your record overall or against one player.

## 6. Dependencies and packaging

Libraries come from the Ace3 repository via `.pkgmeta`, releases are built by
the BigWigsMods packager on every version tag, and `scripts/build.sh` runs the
same packager locally. Details in `CLAUDE.md` and the README.
