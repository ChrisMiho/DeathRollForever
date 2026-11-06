# 05 Host controller: slash commands, chat in, lines out, the ticker

Status: draft v3. Last verified against code: not yet. Owns `src/Host.lua`, `src/Init.lua`.

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
| `g`, `guild`, `p`, `party`, `r`, `raid` | `Parse.StartArgs(name, args)`; on error print it; else `Host.Start(result)`; on error print it |
| `cancel` | `Host.Cancel()`; on error print it |
| `help` | print the help lines |
| anything else (`show` included) | print `Unknown command.` then the help lines |

The `PLAYER_LOGIN` library check and the loaded line stay as they are: the
loaded line ends with `Type /dr.`, which now opens the window.

### `Host.Start(opts)`

1. If `Host.IsHosting()`: return `nil, ALREADY_RUNNING`.
2. Check membership: `GUILD` needs `IsInGuild()`, `PARTY` needs
   `IsInGroup()`, `RAID` needs `IsInRaid()`. Otherwise return `nil,
   NOT_IN_<channel>`.
3. Fill `opts.rollMax` from `Rules.DEFAULTS` when nil, and add `host =
   Ambiguate(UnitName("player"), "short")`, `joinWord`, `joinTime`,
   `rollTime` from `Rules.DEFAULTS`.
4. `game, events = Rules.New(opts, GetTime())`. Keep `game` in a local.
5. Register the chat events for that channel only (table in contracts
   section 7) and `CHAT_MSG_SYSTEM`. Start `C_Timer.NewTicker(1, tick)`.
   Post the events (below), so the listener sees a game whose ticker is
   already running. Return `true`.

### Post (internal)

For each event in order, for each line of `Chat.Render(event, game)`:
`SendChatMessage(line, game.channel)` `[P0-POST]`. Then call the
`OnChange` listener with the game. Then, if `not Rules.IsLive(game)`: stop
the ticker, unregister the chat events, drop the game.

### Chat events

- Channel message `(text, sender)`: only while hosting. `name =
  Ambiguate(sender, "short")`. If `Parse.JoinWord(text, game.joinWord)`:
  post `Rules.Join(game, name, GetTime())`.
- `CHAT_MSG_SYSTEM (text)`: only while hosting. `name, roll, min, max =
  Parse.Roll(text)`; if nil, ignore. `[P0-ROLL]`: the host's own roll shows
  with the host's name like everyone else's, never as "You", so no mapping
  is needed. `name = Ambiguate(name, "short")`. Post `Rules.Roll(game,
  name, roll, min, max, GetTime())`.

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
error. Errors raised inside `fn` are not caught: a broken window breaks
loudly in the host's own client, which is what we want during development.

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
| unknown command | `Unknown command.` followed by the help lines |

Help lines, printed one per `ns.Print`:

```
/dr                          open the window
/dr g <wager> [roll max]     start in guild chat (1g, 50s, 1g50s, 1.5g)
/dr p <wager> [roll max]     start in party chat
/dr r <wager> [roll max]     start in raid chat
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

Edits `src/Host.lua` (`rollMax`, `rollTime`, the tick without `rng`) and
`src/Init.lua` (the dispatch table and the help lines). No spec file: this
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
| IG-05-02 | `/dr help` | the six help lines in your chat frame, `/dr` first; `/dr show` gives `Unknown command.` and the same six |
| IG-05-03 | `/dr x 1g` | `Usage: /dr g|p|r <wager> [roll max]` locally |
| IG-05-04 | `/dr g abc` | `Enter an amount like 5, 1g 50s or 1.5g` locally |
| IG-05-05 | `/dr g 1g 1` | `Roll max must be a whole number from 2 to 1000000` locally |
| IG-05-06 | `/dr p 1g` while not in a party | `You are not in a party.` locally |
| IG-05-07 | `/dr cancel` with no game | `No game is running.` locally |
| IG-05-08 | `/dr g 100g` | the kickoff line in guild chat, ending with the stay-near sentence `[P0-POST]` |
| IG-05-09 | `/dr g 1g` again | `A game is already running. Type /dr cancel first.` locally; nothing in chat |
| IG-05-10 | you and two others type `1`; one types `1` twice; one types `one` | countdown lines at 30, 15, 5 showing 3 names in the order typed `[P0-POST]` from a timer |
| IG-05-11 | wait for 0 | `Joining closed! 3 players in: ...`, then `Everyone, type /roll 100 now! 45 seconds.` |
| IG-05-12 | someone who did not join types `/roll 100` | nothing posted |
| IG-05-13 | a player types `/roll 50` | `..., wrong range. Type /roll 100` |
| IG-05-14 | a player types `/roll 100` twice | nothing posted for either; the first number is the one in the window |
| IG-05-15 | you, as host, roll | your own roll counts `[P0-ROLL]` |
| IG-05-16 | one player waits | `20 seconds! Still to roll: <name>. Type /roll 100`, then 10, then 5, then `<name> did not roll in time and sits out.` and the result line |
| IG-05-17 | everyone rolls | the result line at once: `WINNER: <name> with <n>! <name> rolled <m> and owes <winner> <amount>.` and no further lines; `/dr g 1g` starts a new game |
| IG-05-18 | two players roll the same highest number (keep rolling games until it happens, or use `/roll 2`-style low roll max: `/dr g 1g 2`) | `Tie for highest: A, B. Tied players, type /roll 2 again! 45 seconds.`; only their rolls count; then the result |
| IG-05-19 | `/dr g 1g 2` with three players | a tie on one or both ends almost every time; check the lines for a low tie and for both ends |
| IG-05-20 | in a tie-break, the tied players do not roll | `Nobody rolled the tie-break. Game cancelled.` |
| IG-05-21 | `/dr g 1g`, then `/dr cancel` during the lobby, and again during rolling | `Game cancelled by the host.` each time; no more countdown or reminder lines afterwards |
| IG-05-22 | `/dr g 1g`, nobody joins | at 0: `Not enough players (need 2). Game cancelled.` |
| IG-05-23 | `/dr g 1g`, two join, nobody rolls | the sits-out line naming both, then `Not enough players (need 2). Game cancelled.` |
| IG-05-24 | `/dr g 1g 1000` | kickoff says `rolls 1-1000`, the call says `/roll 1000`, a roll of `/roll 100` is a wrong range |
| IG-05-25 | a guild member far away and not grouped rolls | counts, or does not `[P0-DISTANCE]` |
| IG-05-26 | `/dr r 50s` in a raid with players across the zone | works like guild; countdown and calls are seen by all |
| IG-05-27 | `/reload` mid-game | the game is gone; `/dr cancel` says `No game is running.` (expected limitation) |

## Mockup references

None.

## Open questions

None.
