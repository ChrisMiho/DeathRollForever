# 05 Host controller: slash commands, chat in, lines out, the ticker

Status: draft v3.1 (v3 plus solo games, see 06-solo; names, whispers and the client's roll text 2026-11-11). Last verified against code: not yet. Owns `src/Host.lua`, `src/Init.lua`.

## Purpose and scope

The only glue besides the window. It wires `/dr` to the engine and the
window, feeds chat events into the engine, posts every rendered line, and
ticks the engine once a second. It contains no rules and no text of its own
beyond the local messages listed below.

Out of scope: the window itself (visual/), sync, anything persistent, kick,
extend.

## Depends on / blocks

Depends on: 01, 02, 03, 04 and [contracts.md](../contracts.md) sections 5.5
and 7. Phase 0: `[P0-POST]`, `[P0-ROLL]`, `[P0-DISTANCE]`.
Blocks: nothing.

## Behaviour

### Slash commands (`Init.lua`)

`SlashCmdList.DEATHROLLFOREVER` passes its text to `Parse.Command` and
dispatches on `name`:

| `name` | Action |
|--------|--------|
| `` (empty) | `ns.UI.Show()` |
| `g`, `guild`, `p`, `party`, `r`, `raid`, `solo` | `Parse.StartArgs(name, args)`; on error print it; else `Host.Start(result)`; on error print it. A solo game opens the window by itself (01-window: a Host change shows a hidden window) |
| `cancel` | `Host.Cancel()`; on error print it |
| `help` | print the help lines |
| anything else (`show` included) | print `Unknown command.` then the help lines |

The `PLAYER_LOGIN` library check and the loaded line stay as they are: the
loaded line ends with `Type /dr.`, which now opens the window.

### `Host.Start(opts)`

1. If `Host.IsHosting()`: return `nil, ALREADY_RUNNING`.
2. Check membership: `GUILD` needs `IsInGuild()`, `PARTY` needs
   `IsInGroup()`, `RAID` needs `IsInRaid()`. Otherwise return `nil,
   NOT_IN_<channel>`. `SOLO` needs nothing.
3. The first `Start` builds the roll pattern: `Parse.RollPattern(
   RANDOM_ROLL_RESULT)`, or `Parse.ROLL_PATTERN` when that gives `nil`, so a
   client in another language reads rolls too. Kept for the session.
4. Build the `Rules.New` options in a new table (the caller's table is
   never changed): `channel` and `wager` from the caller, `rollMax` from
   the caller or `Rules.DEFAULTS`, `host = Host.PlayerName()`, and
   `joinWord`, `joinTime`, `rollTime` from `Rules.DEFAULTS`.
   For `SOLO`: `rollTime = Solo.ROLL_TIME`, and `players =
   Solo.Players(host, UnitFactionGroup("player"), bots or Solo.BOTS,
   math.random)` with the caller's `bots`.
5. `game, events = Rules.New(opts, GetTime())`. Keep `game` in a local.
6. Register the chat events for that channel only (table in contracts
   section 7; none for `SOLO`) and `CHAT_MSG_SYSTEM`. Start
   `C_Timer.NewTicker(1, tick)`. Post the events (below), so the listener
   sees a game whose ticker is already running. Return `true`.

### `Host.PlayerName()`

`Parse.PlayerName(GetUnitName("player", true))`: the host's character
name, without the Forever surname `GetUnitName` adds. The window uses it
for `(you)`; `Start` uses it as `host`.

### Names

Every player is known by `Parse.PlayerName`: a join by the chat sender's,
a roll by the roll line's. The sender carries a realm and the roll line a
Forever surname; both reduce to the character name, so a joined player's
roll matches whichever way the client writes the name. The second value of
`Parse.PlayerName`, the name with the surname, goes to `Rules.Join` and
`Rules.Roll` as `fullName`, and `Start` passes the host's own as
`fullNames = { [host] = hostFullName }`, so chat and the window show
surnames.

### Post (internal)

For each event in order, for each line of `Chat.Render(event, game)`:
`SendChatMessage(line, "WHISPER", nil, name)` when `Chat.WhisperTo(event)`
gives a name (a wrong range, to the player who rolled it), else
`SendChatMessage(line, game.channel)` `[P0-POST]`. A `SOLO` game sends
nothing and prints nothing: no `Chat.Render`, no `SendChatMessage`, no
`ns.Print`. Then, for a `SOLO` game, schedule the bots (below) if the list
held a `call` or a `tieBreak`. Then call the `OnChange` listener with the
game. Then, if `not Rules.IsLive(game)`: stop the ticker, unregister the
chat events, drop the game.

### Bot rolls (internal, `SOLO` only)

`plan = Solo.Plan(game, host, math.random)`. For each `{ name, delay, roll
}`: `C_Timer.After(delay, fn)` where `fn` checks that the game it was made
for is still the hosted game (the same table) and still on the same
`round`, and if so posts `Rules.Roll(game, name, roll, 1, game.rollMax,
GetTime())`. A roll whose game was cancelled, finished or moved on to
another round does nothing. The engine does the rest: the last roll
settles the round, and a tie-break or an all-equal rerun starts a round
that schedules the next bot rolls.

### Chat events

- Channel message `(text, sender)`: only while hosting. `name =
  Parse.PlayerName(sender)`. If `name` and `Parse.JoinWord(text,
  game.joinWord)`: post `Rules.Join(game, name, GetTime())`.
- `CHAT_MSG_SYSTEM (text)`: only while hosting. `rawName, roll, min, max =
  Parse.Roll(text, rollPattern)`, `name = Parse.PlayerName(rawName)`; if
  nil, ignore. `[P0-ROLL]`: the host's own roll shows with the host's name
  like everyone else's, never as "You", so no mapping is needed. Post
  `Rules.Roll(game, name, roll, min, max, GetTime())`.

### Tick

Every second: post `Rules.Tick(game, GetTime())`. No `rng`: v3 has no
shuffle.

### `Host.Cancel()`

If not hosting: `nil, NOT_RUNNING`. Else post `Rules.Cancel(game, GetTime())`
and return `true`.

### `Host.OnChange(fn)`

Stores `fn` in a local; a second call replaces the first. `Host` calls
`fn(game)`:

- at the end of `Host.Start`, after the kickoff is posted and the ticker
  started;
- at the end of `post`, after the lines are sent and **before** `stop()`
  drops a game that is no longer live;
- at the end of every `tick`, even when `Rules.Tick` returned no events (the
  window redraws its countdown from this).

`fn` is never called with `nil`, and never when `Host.Start` returned an
error. `fn` runs under `pcall`: an error inside it is printed to the host
through `ns.Print` as `WINDOW_ERROR` with the error text, and the game goes
on exactly as if the window had not been there. In particular a game that is
no longer live is dropped whether or not `fn` raised, so the ticker never
reports a finished or cancelled game again. (Before 0.3.0 errors were not
caught, and an error while drawing the result left the host holding the
finished game: its ticker handed the result to the window every second, so
Reset flipped back to the winner view.)

### Leaving the chat

If the host leaves the guild, party or raid mid-game, the next
`SendChatMessage` fails silently in the client and the game stalls. This is
not handled; the host cancels. A later version may detect `GROUP_LEFT`.

## Exact user-facing text (local, host only, via `ns.Print`)

| Constant | Text |
|----------|------|
| `ALREADY_RUNNING` | `A game is already running. Type /dr cancel first.` |
| `NOT_IN_GUILD` | `You are not in a guild.` |
| `NOT_IN_PARTY` | `You are not in a party.` |
| `NOT_IN_RAID` | `You are not in a raid.` |
| `NOT_RUNNING` | `No game is running.` |
| `WINDOW_ERROR` | `Window error (the game goes on in chat): <error text>` |
| unknown command | `Unknown command.` followed by the help lines |

Help lines, printed one per `ns.Print`. The bot count in the solo line is
`Solo.BOTS`, filled in when the list prints:

```
/dr                          open the window
/dr g <wager> [roll max]     start in guild chat (1g, 50s, 1g50s, 1.5g)
/dr p <wager> [roll max]     start in party chat
/dr r <wager> [roll max]     start in raid chat
/dr solo <wager> [roll max]  practise alone against 10 bots
/dr cancel                   cancel the running game
/dr help                     this list
```

Parse errors (`Parse.USAGE`, `Parse.ROLL_MAX_ERROR`, `Money.ERROR`) are
printed as they come from 01 and 02.

## Interfaces

Implements [contracts.md section 5.5](../contracts.md#55-nshost). Uses
`Parse`, `Rules`, `Chat`, `UI.Show`, and the game API listed in contracts
section 7, every name of which goes into `.luacheckrc` `read_globals`.

## Files

Edits `src/Host.lua` (`rollMax`, `rollTime`, the tick without `rng`; v3.1:
`SOLO` in `Start`, `post` and the bot rolls) and `src/Init.lua` (the
dispatch table and the help lines; v3.1: `solo` and its help line). No spec file: this
module is glue.

## Acceptance criteria

### Automated (busted)

None. `luacheck .` must pass, which catches any API name not declared.

### In-game (manual)

Run these in a guild where at least two other characters can type, or in a
party with two alts on second accounts. Note what you see against each line.

| ID | Do | Expect |
|----|----|--------|
| IG-05-01 | `/dr` | the window opens; nothing in your chat frame |
| IG-05-02 | `/dr help` | the seven help lines in your chat frame, `/dr` first, `/dr solo` after `/dr r`; `/dr show` gives `Unknown command.` and the same seven |
| IG-05-03 | `/dr x 1g` | `Usage: /dr g|p|r|solo <wager> [roll max]` locally |
| IG-05-04 | `/dr g abc` | `Enter an amount like 5, 1g 50s or 1.5g` locally |
| IG-05-05 | `/dr g 1g 1` | `Roll max must be a whole number from 2 to 1000000` locally |
| IG-05-06 | `/dr p 1g` while not in a party | `You are not in a party.` locally |
| IG-05-07 | `/dr cancel` with no game | `No game is running.` locally |
| IG-05-08 | `/dr g 100g` | the kickoff line in guild chat, ending with the stay-near sentence `[P0-POST]` |
| IG-05-09 | `/dr g 1g` again | `A game is already running. Type /dr cancel first.` locally; nothing in chat |
| IG-05-10 | you and two others type `1`; one types `1` twice; one types `one` | countdown lines at 30, 15, 5 showing 3 names in the order typed `[P0-POST]` from a timer |
| IG-05-11 | wait for 0 | `Joining closed! 3 players in: ...`, then `Everyone, type /roll 100 now! 45 seconds.` |
| IG-05-12 | someone who did not join types `/roll 100` | nothing posted |
| IG-05-13 | a player types `/roll 50` | that player gets a whisper from you: `[DeathRoll] Wrong range, that roll does not count. Type /roll 100`; nothing in the game's chat |
| IG-05-14 | a player types `/roll 100` twice | nothing posted for either; the first number is the one in the window |
| IG-05-15 | you, as host, roll | your own roll counts `[P0-ROLL]` |
| IG-05-15b | a character with a Forever surname types `1`, then `/roll 100` | their roll counts: no sit-out line for them, the window shows their full name with the surname and the roll, and the result line names them with the surname |
| IG-05-16 | one player waits | `20 seconds! Still to roll: <name>. Type /roll 100`, then 10, then 5, then `<name> did not roll in time and sits out.` and the result line |
| IG-05-17 | everyone rolls | the result line at once: `WINNER: <name> with <n>! <name> rolled <m> and owes <winner> <amount>.` and no further lines; `/dr g 1g` starts a new game |
| IG-05-18 | two players roll the same highest number (keep rolling games until it happens, or use `/roll 2`-style low roll max: `/dr g 1g 2`) | `Tie for highest: A, B. Tied players, type /roll 2 again! 45 seconds.`; only their rolls count; then the result |
| IG-05-19 | `/dr g 1g 2` with three players | a tie on one or both ends almost every time; check the lines for a low tie and for both ends |
| IG-05-20 | in a tie for highest, the tied players do not roll | `Nobody rolled the tie for highest. Game cancelled.` |
| IG-05-20b | in a tie for lowest, the tied players do not roll | `WINNER: <name> with <n>! <A> and <B> rolled <m>, skipped the tie-break and each owe <winner> <amount>.` |
| IG-05-21 | `/dr g 1g`, then `/dr cancel` during the lobby, and again during rolling | `Game cancelled by the host.` each time; no more countdown or reminder lines afterwards |
| IG-05-22 | `/dr g 1g`, nobody joins | at 0: `Not enough players (need 2). Game cancelled.` |
| IG-05-23 | `/dr g 1g`, two join, nobody rolls | the sits-out line naming both, then `Not enough players (need 2). Game cancelled.` |
| IG-05-24 | `/dr g 1g 1000` | kickoff says `rolls 1-1000`, the call says `/roll 1000`, a roll of `/roll 100` is a wrong range |
| IG-05-25 | a guild member far away and not grouped rolls | counts, or does not `[P0-DISTANCE]` |
| IG-05-26 | `/dr r 50s` in a raid with players across the zone | works like guild; countdown and calls are seen by all |
| IG-05-27 | `/reload` mid-game | the game is gone; `/dr cancel` says `No game is running.` (expected limitation) |

Solo games (06-solo). These need no guild, no group and nobody else:

| ID | Do | Expect |
|----|----|--------|
| IG-05-28 | not in a group, window closed: `/dr solo 1g` | the window opens straight on the round: you and 10 bots with names from your faction's list, `Rolled 0 of 11`, 15 seconds on the bar, `Solo, 1g per person, roll 1-100` under the title. Nothing in any chat and nothing in your chat frame |
| IG-05-29 | watch for 5 seconds | every bot has rolled within 5 seconds of the start, at scattered moments, with no line or call per bot; the list sorts itself as they land |
| IG-05-30 | click `Roll 1-100` (or type `/roll 100`) | your roll counts like a bot's; the result shows at once when you are the last |
| IG-05-31 | `/dr solo 1g 2` a few times | ties almost every game: the tied bots re-roll on their own; when you are tied, you roll again yourself |
| IG-05-32 | `/dr solo 1g`, do not roll | after 15 seconds you sit out and the result shows the bots only |
| IG-05-33 | `/dr solo 1g`, then `/dr cancel` (or the window's `Cancel`) | the window goes back to the form; no bot roll arrives afterwards; nothing in chat. `/dr solo 1g` again starts a fresh game with new names |

## Mockup references

None.

## Open questions

None.
