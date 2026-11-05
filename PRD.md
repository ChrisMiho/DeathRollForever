# DeathRollForever — Product Requirements (PRD)

Draft 1, 2026-11-05. Status: hashing out flow and UI. No code, no repo yet.

## 1. What it is

A World of Warcraft: Forever addon that runs multiplayer death roll events in
party, raid or guild chat. One host with the addon runs the game. Everyone else
can play with nothing but chat: type the join word, then `/roll` when called.
Players who also have the addon get a live window, a ROLL button, optional
auto-roll, and a payment ledger that ticks off debts as trades happen.

Target client: WoW Forever (`_forever_`, Interface 16001, modern retail API).

## 2. Goals and non-goals

Goals
- Run a whole event (lobby, rolling, eliminations, winner, ledger) from chat.
- Require the addon only on the host.
- Keep the game moving: timers, nudges, forfeits, kicks.
- Make settling up visible: who owes whom, who has paid.

Non-goals for version 1
- Say, yell, general or custom channels (Blizzard blocks automatic posting there).
- Two-player private games by whisper (maybe later).
- Anything that needs a server or a website.

## 3. Roles

| Role | Needs addon | What they do |
|------|-------------|--------------|
| Host | Yes | Starts the game, can kick, cancel, extend. May also play. |
| Player | No | Types the join word in chat, then `/roll` when called. |
| Addon player | Yes | Same, plus the window, ROLL button, auto-roll, ledger. |
| Watcher | Yes | In the chat but did not join. Sees the window; can close it. |

## 4. Game flow

### Phase 1: Announce and lobby
1. Host runs `/dr start raid 1` (chat, wager in gold, optional first-roll number and join time).
2. Addon posts the kickoff line (see section 5) in that chat.
3. Anyone who types the join word (default `1`) in that chat is added, in the order they typed it. Host joins the same way or with `/dr join`.
4. Countdown lines at 30s, 15s, 10s, 5s, each with the player count.
5. At 0: joining closes. Fewer than 2 players cancels the game with a message.

### Phase 2: Rolling
6. Addon posts the roll order and calls the first player: "Alice, /roll 1000".
7. The called player rolls. Only that player's roll, with exactly the expected range, counts. Wrong range: a nudge with the right range. Anyone else's roll: ignored.
8. On a valid roll, the next player in order is called with "1-<that roll>".
9. Rolling 1 eliminates the player. The addon announces it, resets the range to the start number, and calls the next player in order.
10. Turn timer, default 30s. At 15s left, a reminder in chat. At 0, the player is out as a forfeit. Host can change the timer or set it to 0 for no forfeit, and can `/dr kick` anyone at any time.
11. Last player standing wins.

### Phase 3: Result and settling
12. Addon posts the winner and the ledger: every eliminated player owes the winner the wager.
13. Debts are tracked by the addons. When a loser trades the winner the wager, the addon that saw the trade (payer's or winner's) marks it paid and tells the other addons.
14. `/dr owed` reposts the outstanding ledger at any time.
15. The game is saved to history for stats.

### Rules summary
- First roll: the start number (default 1000). Each next roll: 1 to the previous result.
- Order: join order. After an elimination, the next player in order starts fresh at the start number.
- One game per host at a time. A second host starting a game in the same chat is refused with a warning.
- Minimum 2 players. The host does not have to play.

### Wager amounts
- Stored in copper, the game's own unit (1g = 100s = 10,000c), so any amount
  works and trade detection compares exact copper.
- Accepted when typing, in the command or the form: a plain number means gold
  (`5` = 5g); suffixes `g`, `s`, `c` in any combination with or without spaces
  (`1g`, `50s`, `1g50s`, `1g 50s 45c`, `45c`); decimal gold (`1.5g` = 1g 50s).
  Anything else is rejected with a message showing the accepted forms.
- Minimum 1c. No maximum beyond what the trade window allows.
- Shown in chat as plain text with only the non-zero parts: `1g`, `50s`,
  `1g 50s 45c`. Shown in the window with the game's coin icons.
- The ledger total is the per-person amount times the number of losers, in
  copper, then formatted the same way (4 losers at 50s = `2g`).

## 5. Announcements (exact text, draft)

Prefix every line with `[DeathRoll]`. Money is shown as plain text, for example
`1g`, `50s`, `1g 50s 45c` (see Wager amounts in section 4).

| Moment | Text |
|--------|------|
| Kickoff | `[DeathRoll] Death roll starting! 1g per person, first roll 1-1000. Type 1 here to join. 60 seconds!` |
| 30s / 15s / 10s / 5s | `[DeathRoll] 30 seconds left to join! (4 in: Alice, Bob, Carl, Dan)` |
| Close | `[DeathRoll] Joining closed! 5 players. Order: Alice, Bob, Carl, Dan, Eve.` |
| Call | `[DeathRoll] Alice, /roll 1000` |
| Wrong range | `[DeathRoll] Bob, wrong range! /roll 734` |
| Reminder | `[DeathRoll] Bob, 15 seconds to roll!` |
| Forfeit | `[DeathRoll] Bob did not roll in time and is OUT. 4 left.` |
| Out | `[DeathRoll] Carl rolled 1 and is OUT! 3 left. Range resets. Dan, /roll 1000` |
| Winner | `[DeathRoll] WINNER: Eve! Alice, Bob, Carl, Dan each owe Eve 1g (4g total).` |
| Paid (optional) | `[DeathRoll] Bob paid Eve 1g. 3 outstanding.` |
| Cancel | `[DeathRoll] Game cancelled by the host.` |
| Too few | `[DeathRoll] Not enough players (need 2). Game cancelled.` |

## 6. Commands (`/dr` or `/deathroll`)

```
/dr                           open or close the window
/dr start raid 1              host: start in raid chat, 1g per person
/dr start party 50s           host: party chat, 50 silver per person
/dr start raid 1g50s          host: 1 gold 50 silver per person
/dr start guild 5 500 90      host: guild chat, 5g, first roll 1-500, 90s to join
/dr join                      join the open game (same as typing the join word)
/dr roll                      make your roll (same as the ROLL button)
/dr auto on | off             roll automatically on your turn, if the game allows it
/dr kick Bob                  host: remove a player
/dr extend 30                 host: add 30s to the join countdown
/dr cancel                    host: cancel the game
/dr owed                      post the outstanding ledger to chat
/dr stats [Bob]               your record overall, or against Bob
/dr set timer 45              change a default: timer, jointime, joinword, startroll
/dr help
/dr selftest                  run the addon's built-in tests (developer use)
```

Chat argument accepts only `party`, `raid`, `guild`. Anything else is an error.

## 7. The window

Movable, remembers its position, opens itself when a game is announced in a
chat you are in. One window, five views: new game, lobby, game, result,
settings. The first four swap by phase; settings opens from a gear icon in the
title bar of any view and returns to where you were.

New game view (shown when no game is running)
- Chat: Party / Raid / Guild (only the ones you are currently in are enabled)
- Wager per person, text box. Accepts `1g`, `50s`, `1g 50s 45c`, `1.5g`, or a
  plain number for gold. The parsed amount is echoed under the Start button
  with coin icons, and a bad entry disables Start with a short hint.
- A small `?` button right of the wager box. Hovering it opens a standard game
  tooltip to its right, styled like an item or spell tooltip rather than a
  block of text. A gold title, then one line per rule: the rule on the left in
  gold, an example on the right in white. Where an example shows what the
  entry is worth, the amount is drawn with the game's coin icons (the same
  ones as the echo under Start). The minimum sits alone at the bottom in grey.

  Line by line, left column gold and right column white unless noted:

  | Left                   | Right                |
  |------------------------|----------------------|
  | Wager formats (title)  |                      |
  | Plain number is gold   | 5 = 5[g]             |
  | Suffixes g, s, c       | 1g 50s 45c           |
  | Spaces optional        | 1g50s                |
  | Decimal gold           | 1.5g = 1[g] 50[s]    |
  | (blank line)           |                      |
  | Minimum 1c (grey)      |                      |

  `[g]`, `[s]`, `[c]` stand for the gold, silver and copper coin icons. Builder
  note: this is a plain GameTooltip with double lines; the coin strings come
  from the same helper that formats the echo under Start.
- First roll (default 1000)
- Time to join in seconds (default 60)
- Join word (default 1)
- Start button. Equivalent to `/dr start`.
- Last game's values are remembered, so a repeat event is one click.

Settings view (gear icon)
- Join time slider, 10 to 300 seconds
- Turn timer slider, 0 (off) to 120 seconds
- First roll, text box
- Join word, text box
- Auto-roll on my turn, checkbox
- Post paid notices in chat, checkbox
- Open the window automatically when a game is announced, checkbox
- Window scale slider, 80 to 150 percent
- Reset to defaults button, Back button
- The same panel is reachable from the game's Settings > AddOns list, which
  shows one entry with an "Open settings" button.

Lobby view
- Title line: "Death roll in raid chat, 1g per person, first roll 1-1000"
- Countdown: big "0:42" that turns red under 10s
- Joined players in join order, with a count
- Host only: Extend 30s button, Cancel button
- Everyone: Join button (types the join word for you)

Game view
- Roll order as a vertical list. Eliminated players struck through and dimmed.
  The current player highlighted. Your own name marked.
- Status line: "Bob is up: /roll 734"
- Last five rolls: "Alice rolled 734 (1-1000)", "Bob rolled 512 (1-900)", ...
- Big ROLL button, enabled only on your turn, showing the range ("ROLL 1-734")
- Turn timer bar under the status line
- Host only: Kick button next to the current player, Cancel button

Result view
- "Winner: Eve"
- Ledger: one line per loser, "Bob owes Eve 1g", with a tick once paid
- Your record against the winner: "vs Eve: 2 wins, 3 losses, -2g"
- Close button

Faction flair
- The window is tinted by your own faction, read from the game at load:
  Alliance blue, Horde red. The tint is used on the title bar, the
  current-player highlight, the turn timer bar and the ROLL button.
  Everything else stays neutral so names and numbers remain readable.
- A small faction crest sits next to the title.
- If a group ever mixes factions (cross-faction grouping), each player's name
  gets a small crest in their own faction colour. Single-faction groups show
  no per-name crests, to keep the list clean.

## 8. Settings and defaults

| Setting | Default | Change with |
|---------|---------|-------------|
| Join time | 60s | `/dr start ... <seconds>` or `/dr set jointime` |
| Join word | `1` | `/dr set joinword` |
| Start roll | 1000 | `/dr start ... <number>` or `/dr set startroll` |
| Turn timer | 30s (0 = off) | `/dr set timer` |
| Auto-roll | off | `/dr auto on` |
| Paid lines in chat | on | `/dr set paidchat off` |
| Open window automatically | on | settings view |
| Window scale | 100% | settings view |

Every setting is also in the window's settings view (section 7). The commands
are shortcuts for the same values.

## 9. Ledger and payments

- At the end, each eliminated player owes the winner the wager. The ledger lists
  every debt as owed or paid.
- Payment detection: the addon watches the trade window. When a trade completes
  between a loser and the winner with at least the wager in gold from the loser,
  that debt is marked paid. Either side's addon can see it; whichever does tells
  the others.
- The ledger survives the host logging off, since each addon keeps its own copy.
- Debts are informational. The addon never moves gold.

## 10. How addons stay in sync (short)

- The host's addon is the single source of truth. After every change it
  broadcasts the whole scoreboard as hidden addon messages to the same party,
  raid or guild. Non-host addons draw whatever they last received.
- Payment notices are peer to peer; no host needed.
- Messages carry a version number. Newer-version messages are ignored with a notice.
- Library: AceComm-3.0 (with LibStub, CallbackHandler-1.0, ChatThrottleLib).
  It splits long messages and rate-limits sending.

## 10a. Dependencies and packaging

- Libraries are not committed. They are listed in `.pkgmeta` as externals
  pulled from the official Ace3 repository (https://github.com/WoWUIDev/Ace3)
  and land in `Libs/`, which is git-ignored.
- Releases are built by the BigWigsMods packager
  (https://github.com/BigWigsMods/packager) as a GitHub Action on every version
  tag. It fetches the libraries, stamps the version into the `.toc`, and
  attaches a ready-to-install zip to the GitHub release. Friends install from
  that zip, never from the raw repository.
- For local development the same `.pkgmeta` is used to fetch `Libs/` on this
  PC, so the in-game copy matches what a release would contain.

## 11. Saved data

- Defaults (section 8) and window position.
- Finished games: date, chat, host, wager, players, winner, ledger with paid flags.
- The host's live game, so a `/reload` by the host resumes it.

## 12. Step 0: setup (later, not now)

- GitHub repository for this folder, with `.gitignore`, `.pkgmeta`, `LICENSE`,
  `CHANGELOG.md` and a README.
- Folder link from `_forever_\Interface\AddOns\DeathRollForever` to this folder
  (this PC only, never shared).
- Editor with Lua support (VS Code, the Lua extension and WoW API definitions).
- Lua 5.1 or LuaJIT, LuaRocks, luacheck (lint) and busted (unit tests) for
  checks outside the game.
- GitHub Actions: lint and tests on every push; packager release on every tag.
- Versioning: semantic version tags (`v0.1.0`), changelog updated per release.
- BugSack and BugGrabber are already installed for catching errors in-game.

## 13. Milestones

1. Hello: addon loads, and four in-game checks: roll message pattern, auto-roll from a timer allowed or not, roll visibility at a distance in a raid, chat posting works.
2. Rules engine with `/dr selftest`.
3. Host: lobby, countdown, announcements.
4. Host: rolling, eliminations, winner.
5. Window: all five views, including the new game form and settings.
6. Sync: addon players see the window live, ROLL button works.
7. Ledger and trade detection.
8. History, stats, polish.

## 14. Open questions

1. Window: is the game view showing the right things at a glance? What is missing, what is noise?
2. Turn timer: keep forfeit at 0s as the default, or default to reminder only?
3. Roll order: join order, or shuffle at close?
4. Announcement prefix: `[DeathRoll]`, or something shorter like `[DR]`?
5. Late joiners after close: ignore silently, or whisper them "joining closed"?
6. Paid lines in chat: on by default, or window only?
