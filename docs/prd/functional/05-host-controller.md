# 05 Host controller: slash commands, chat in, lines out, the ticker

Status: v1 implemented; v2 additions draft (section "v2 additions" below). Last verified against code: 2026-11-05. Owns `src/Host.lua`, `src/Init.lua`.

## Purpose and scope

The only glue in v1. It wires `/dr` to the engine, feeds chat events into the
engine, posts every rendered line, and ticks the engine once a second. It
contains no rules and no text of its own beyond the local messages listed
below.

Out of scope: a window, sync, anything persistent, kick, extend.

## Depends on / blocks

Depends on: 01, 02, 03, 04 and [contracts.md](../contracts.md) sections 5.5
and 7. Phase 0: `[P0-POST]` (blocking), `[P0-ROLL]`, `[P0-DISTANCE]`.
Blocks: nothing in v1. It is the last package.

## Behaviour

### Slash commands (`Init.lua`)

`SlashCmdList.DEATHROLLFOREVER` passes its text to `Parse.Command` and
dispatches on `name`:

| `name` | Action |
|--------|--------|
| `g`, `guild`, `p`, `party`, `r`, `raid` | `Parse.StartArgs(name, args)`; on error print it; else `Host.Start(result)`; on error print it |
| `cancel` | `Host.Cancel()`; on error print it |
| `help`, `` (empty) | print the help lines |
| anything else | print `Unknown command.` then the help lines |

The `PLAYER_LOGIN` library check and the loaded line stay as they are.

### `Host.Start(opts)`

1. If `Host.IsHosting()`: return `nil, ALREADY_RUNNING`.
2. Check membership: `GUILD` needs `IsInGuild()`, `PARTY` needs
   `IsInGroup()`, `RAID` needs `IsInRaid()`. Otherwise return `nil,
   NOT_IN_<channel>`.
3. Fill `opts.startRoll` from `Rules.DEFAULTS` when nil, and add `host =
   Ambiguate(UnitName("player"), "short")`, `joinWord`, `joinTime`,
   `turnTimer` from `Rules.DEFAULTS`.
4. `game, events = Rules.New(opts, GetTime())`. Keep `game` in a local.
5. Post the events (below). Register the chat events for that channel only
   (table in contracts section 7) and `CHAT_MSG_SYSTEM`. Start
   `C_Timer.NewTicker(1, tick)`. Return `true`.

### Post (internal)

For each event in order, for each line of `Chat.Render(event, game)`:
`SendChatMessage(line, game.channel)` `[P0-POST]`. After posting, if
`not Rules.IsLive(game)`: stop the ticker, unregister the chat events, drop
the game.

### Chat events

- Channel message `(text, sender)`: only while hosting. `name =
  Ambiguate(sender, "short")`. If `Parse.JoinWord(text, game.joinWord)`:
  post `Rules.Join(game, name, GetTime())`.
- `CHAT_MSG_SYSTEM (text)`: only while hosting. `name, roll, min, max =
  Parse.Roll(text)`; if nil, ignore. `[P0-ROLL]` answered 2026-11-05: the
  host's own roll shows with the host's name like everyone else's, never as
  "You", so no mapping is needed. `name = Ambiguate(name, "short")`. Post
  `Rules.Roll(game, name, roll, min, max, GetTime())`.

### Tick

Every second: post `Rules.Tick(game, GetTime(), math.random)`.

### `Host.Cancel()`

If not hosting: `nil, NOT_RUNNING`. Else post `Rules.Cancel(game, GetTime())`
and return `true`.

### Leaving the chat

If the host leaves the guild, party or raid mid-game, the next
`SendChatMessage` fails silently in the client and the game stalls. v1 does
not handle this; the host types `/dr cancel`. Later versions may detect
`GROUP_LEFT`.

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
/dr g <wager> [first roll]   start in guild chat (1g, 50s, 1g50s, 1.5g)
/dr p <wager> [first roll]   start in party chat
/dr r <wager> [first roll]   start in raid chat
/dr cancel                   cancel the running game
/dr help                     this list
```

Parse errors (`Parse.USAGE`, `Parse.FIRST_ROLL_ERROR`, `Money.ERROR`) are
printed as they come from 01 and 02.

## Interfaces

Implements [contracts.md section 5.5](../contracts.md#55-nshost). Uses
`Parse`, `Rules`, `Chat`, and the game API listed in contracts section 7,
every name of which goes into `.luacheckrc` `read_globals`.

## Files

Creates `src/Host.lua`. Edits `src/Init.lua` (replaces the hello handler) and
`.luacheckrc` (read_globals). No spec file: this module is glue.

## Acceptance criteria

### Automated (busted)

None. `luacheck .` must pass, which catches any API name not declared.

### In-game (manual)

Run on 2026-11-05 in a two-player party: IG-05-12, 13, 15 and 16 were seen in a full
game played to the winner line, with two-word character names throughout; the
host reported no failures in the rest.

Run these in a guild where at least two other characters can type, or in a
party with two alts on second accounts. Note what you see against each line.

| ID | Do | Expect |
|----|----|--------|
| IG-05-01 | `/dr` and `/dr help` | the five help lines in your chat frame, nothing in guild chat |
| IG-05-02 | `/dr x 1g` | `Usage: /dr g|p|r <wager> [first roll]` locally |
| IG-05-03 | `/dr g abc` | `Enter an amount like 5, 1g 50s or 1.5g` locally |
| IG-05-04 | `/dr p 1g` while not in a party | `You are not in a party.` locally |
| IG-05-05 | `/dr cancel` with no game | `No game is running.` locally |
| IG-05-06 | `/dr g 1g` | the kickoff line in guild chat `[P0-POST]` |
| IG-05-07 | `/dr g 1g` again | `A game is already running. Type /dr cancel first.` locally; nothing in chat |
| IG-05-08 | you and two others type `1`; one types `1` twice; one types `one` | countdown lines at 30, 15, 5 showing 3 names in the order typed `[P0-POST]` from a timer |
| IG-05-09 | wait for 0 | `Joining closed! 3 players in: ...`, then `Roll order: ...` (shuffled), then the first call |
| IG-05-10 | someone not called types `/roll 1000` | nothing posted |
| IG-05-11 | the called player types `/roll 500` | `..., wrong range. Type /roll 1000` |
| IG-05-12 | the called player types `/roll 1000` | the next call with `Type /roll <their result>` `[P0-ROLL]` |
| IG-05-13 | you, as host, are called and roll | your own roll counts `[P0-ROLL]` (the host's line uses the host's name, not "You") |
| IG-05-14 | the called player waits | reminders at 20, 10, 5, then `... did not roll in time and is OUT. 2 left.` and the next call with the same range |
| IG-05-15 | play until someone rolls 1 | `... rolled 1 and is OUT! ... Range resets.` then a call with `/roll 1000` |
| IG-05-16 | play to the end | `WINNER: ...! ... each owe ... 1g (2g total).` and no further lines; `/dr g 1g` starts a new game |
| IG-05-17 | `/dr g 1g`, then `/dr cancel` during the lobby, and again during rolling | `Game cancelled by the host.` each time; no more countdown or reminder lines afterwards |
| IG-05-18 | `/dr g 1g`, nobody joins | at 0: `Not enough players (need 2). Game cancelled.` |
| IG-05-19 | `/dr g 1g 500` | kickoff says `first roll 1-500`, first call says `/roll 500` |
| IG-05-20 | a guild member far away and not grouped rolls when called | counts, or does not `[P0-DISTANCE]` |
| IG-05-21 | `/dr r 50s` in a raid with players across the zone | works like guild; countdown and calls are seen by all |
| IG-05-22 | `/reload` mid-game | the game is gone; `/dr cancel` says `No game is running.` (v1 limitation, expected) |

## v2 additions

Added by the orchestrator in v2 scaffolding (Phase 1 of
[orchestration.md](../orchestration.md)), not by a package. Everything above
is unchanged.

### `Host.OnChange(fn)` (`Host.lua`)

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

### `/dr show` (`Init.lua`)

| `name` | Action |
|--------|--------|
| `show` | `ns.UI.Show()` |

The help lines gain one line, before `/dr help`:

```
/dr show                     open the window
```

### In-game (manual)

| ID | Do | Expect |
|----|----|--------|
| IG-05-23 | `/dr help` | six lines, `/dr show` among them |
| IG-05-24 | `/dr show` | the window opens (01-window's IG-06-01) |

## Mockup references

None.

## Open questions

None.
