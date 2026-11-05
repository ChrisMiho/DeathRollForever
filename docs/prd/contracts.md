# Contracts

Status: draft v1. Last verified against code: never (no feature code exists yet).

Everything that parallel builders share. A builder reads this, their own
feature document and `CLAUDE.md`, and nothing else. If a feature needs
something that is not here, the builder stops and asks the orchestrator.
Nobody changes this document on their own
([orchestration.md](orchestration.md), rule 1).

This version covers **v1: the host runs a game from chat**. Later versions
add modules; section 8 sketches them so v1 does not paint them into a corner,
but nothing there is a contract yet.

## 0. Phase 0 dependencies

Decisions that depend on the four in-game checks are tagged in every document:

| Tag | Check | What changes if the answer is bad |
|-----|-------|-----------------------------------|
| `[P0-ROLL]` | Exact text of the system message for `/roll`, for your own roll and for another player's | `Parse.ROLL_PATTERN`, and whether the host's own name appears as "You" |
| `[P0-POST]` | Addon code can post to guild, party and raid chat, both from a slash command and from a timer | Blocking. No design fallback; the product needs this |
| `[P0-DISTANCE]` | The host sees the roll system message from a guild member who is far away and not grouped | Kickoff line tells players to stay near the host, and the README recommends grouping for guild games |
| `[P0-AUTOROLL]` | Addon code can call `RandomRoll` from a timer (no hardware event) | Nothing in v1. Decides whether v2+ can offer auto-roll |

## 1. Module map (v1)

Every file starts with `local addonName, ns = ...` (or `local _, ns = ...`) and
hangs exactly one table off `ns`. Pure modules call no WoW API and are tested
with busted. Glue modules may call the WoW API and are tested in game.

| `ns.` table | File | Kind | Owner |
|-------------|------|------|-------|
| `ns.Money` | `src/Money.lua` | pure | [01-money](functional/01-money.md) |
| `ns.Parse` | `src/Parse.lua` | pure | [02-chat-parsing](functional/02-chat-parsing.md) |
| `ns.Rules` | `src/Rules.lua` | pure | [03-rules-engine](functional/03-rules-engine.md) |
| `ns.Chat` | `src/Chat.lua` | pure | [04-announcements](functional/04-announcements.md) |
| `ns.Host` | `src/Host.lua` | glue | [05-host-controller](functional/05-host-controller.md) |
| `ns.version`, `ns.Print` | `src/Init.lua` | glue | [05-host-controller](functional/05-host-controller.md) |

`ns.Print(text)` prints one line to the host's own chat frame, prefixed with
the addon name. It is never seen by other players.

### Load order (`DeathRollForever.toc`)

```
embeds.xml
src\Money.lua
src\Parse.lua
src\Rules.lua
src\Chat.lua
src\Host.lua
src\Init.lua
```

The orchestrator writes the `.toc` in the scaffolding step. A module may call
another module only at run time (inside functions), never at file load, so
load order only matters for `Init.lua`.

### Shared files and how to touch them

| File | Rule |
|------|------|
| `DeathRollForever.toc` | Orchestrator only |
| `src/Init.lua` | Owned by 05 in v1 |
| `.luacheckrc` | A builder may add names to `read_globals` and `globals`. Keep the lists sorted. The orchestrator resolves merge conflicts |
| `CHANGELOG.md` | A builder appends one line under `## [Unreleased]`. The orchestrator resolves merge conflicts |
| `spec/helper.lua` | A builder may add a helper only if their feature document says so |
| `.pkgmeta`, `embeds.xml` | Orchestrator only. No feature adds a library |

## 2. Conventions

- **Names.** A player is identified by character name without realm, as
  returned by `Ambiguate(name, "short")`. Comparisons are exact string
  comparisons. Glue code strips the realm at the boundary; pure modules never
  see a realm.
- **Money** is an integer number of copper. 1g = 10,000c, 1s = 100c.
- **Time** is seconds as a float from `GetTime()`. Pure modules take `now` as
  a parameter; they never call a clock.
- **Channels** are the strings `"GUILD"`, `"PARTY"`, `"RAID"`. These are also
  the values `SendChatMessage` takes.
- **Randomness** is injected. `Rules.Tick` takes an `rng` function with the
  signature `rng(n) -> integer in 1..n`. Glue passes `math.random`; tests pass
  a fixed function.
- **Errors.** Pure functions that validate input return `nil, errorText`,
  where `errorText` is user-facing text without any prefix. They raise with
  `error` only for programmer mistakes (wrong types).
- **Events** returned by `Rules` are plain tables with a `type` field. The
  caller never mutates them.
- **Text** that players see is defined in exactly one place: chat lines in
  04-announcements, local host messages in 05-host-controller, parse errors in
  01-money and 02-chat-parsing.
- **No new globals.** Everything goes through `ns`.

## 3. Constants

Defined on `ns.Rules`, used by Host and Chat. v1 has no settings; a later
version replaces these with saved settings.

```lua
Rules.DEFAULTS = { startRoll = 1000, joinTime = 60, turnTimer = 45, joinWord = "1" }
Rules.COUNTDOWN = { 30, 15, 5 }      -- seconds left to join when a countdown line posts
Rules.REMINDERS = { 20, 10, 5 }      -- seconds left in a turn when a reminder posts
Rules.MIN_PLAYERS = 2
```

## 4. Data structure: `game`

The whole state of one game. Created by `Rules.New`, mutated only by `Rules`
functions. v1 keeps it in memory on the host and nowhere else.

```lua
game = {
	id          = "Alice-1762300000",   -- host .. "-" .. math.floor(now) at New
	host        = "Alice",
	channel     = "GUILD",              -- "GUILD" | "PARTY" | "RAID"
	wager       = 10000,                -- copper per person
	startRoll   = 1000,
	joinWord    = "1",
	joinTime    = 60,
	turnTimer   = 45,
	phase       = "lobby",              -- "lobby" | "rolling" | "finished" | "cancelled"
	createdAt   = 1762300000.5,         -- now at New

	-- Lobby
	joined      = { "Alice", "Bob", "Carl" },  -- join order; frozen at close
	joinDeadline = 1762300060.5,        -- createdAt + joinTime
	countdownSent = {},                 -- { [30]=true, ... } markers already posted

	-- Rolling
	order       = { "Carl", "Alice", "Bob" },  -- shuffled once at close; never changes
	status      = { Alice="in", Bob="out", Carl="in" },   -- "in" | "out" | "forfeit"
	eliminated  = { "Bob" },            -- in elimination order
	turn        = 1,                    -- index into order of the player being called
	range       = 1000,                 -- the current maximum: "Type /roll 1000"
	turnDeadline = 1762300100.5,        -- set at every call
	remindersSent = {},                 -- { [20]=true, ... } for the current turn
	rolls       = {                     -- every valid roll, oldest first
		{ name="Carl", roll=734, max=1000 },
	},

	-- Finished
	winner      = nil,                  -- name, set when phase == "finished"
	endedAt     = nil,
	cancelReason = nil,                 -- "host" | "tooFew", set when phase == "cancelled"
}
```

Invariants:

- `turn` always points at a player whose status is `"in"` while
  `phase == "rolling"`.
- After a valid roll greater than 1: `range = roll`, `turn` advances to the
  next `"in"` player in `order`, wrapping.
- After a roll of 1: the roller is `"out"`, `range = startRoll`, `turn`
  advances.
- After a forfeit: the player is `"forfeit"`, `range` is unchanged, `turn`
  advances.
- Every call (`turn` changing, or the first call at close) sets
  `turnDeadline = now + turnTimer` and clears `remindersSent`.
- When exactly one player is `"in"`: `phase = "finished"`, `winner` set.

## 5. Public interfaces (v1)

Only what is listed here is public. A builder may add private local functions
freely and adds public functions only through the orchestrator.

### 5.1 `ns.Money`

```lua
Money.Parse(text)     -> copper | nil, errorText
Money.Format(copper)  -> "1g 50s 45c"      -- non-zero parts only; "0c" for zero
Money.Split(copper)   -> gold, silver, copper
Money.MIN             = 1                  -- copper
Money.MAX             = 9999999999         -- 999,999g 99s 99c
Money.ERROR           = "Enter an amount like 5, 1g 50s or 1.5g"
```

Accepted by `Parse`: a plain integer or decimal means gold (`5`, `1.5`); parts
with suffixes `g`, `s`, `c` in any order, each at most once, with or without
spaces (`1g`, `50s`, `1g50s`, `1g 50s 45c`, `45c`); a decimal is allowed only
on gold and only when it is the whole entry (`1.5g`, `1.5`). Everything else,
and any amount outside `MIN..MAX`, returns `nil, Money.ERROR`.

### 5.2 `ns.Parse`

```lua
Parse.ROLL_PATTERN    = "^(%S+) rolls (%d+) %((%d+)%-(%d+)%)$"   -- [P0-ROLL] draft
Parse.JoinWord(message, joinWord) -> boolean
Parse.Roll(systemMessage, pattern) -> name, roll, min, max | nil   -- pattern defaults to ROLL_PATTERN
Parse.Command(text)   -> { name = "g", args = { "1g", "500" } }     -- never fails; "" gives name ""
Parse.StartArgs(name, args) -> { channel = "GUILD", wager = 10000, startRoll = 500 or nil } | nil, errorText
                                               -- startRoll is nil when not given; Host fills the default
Parse.CHANNELS        = { g = "GUILD", guild = "GUILD", p = "PARTY", party = "PARTY", r = "RAID", raid = "RAID" }
Parse.USAGE           = "Usage: /dr g|p|r <wager> [first roll]"
Parse.FIRST_ROLL_ERROR = "First roll must be a whole number from 2 to 1000000"
```

### 5.3 `ns.Rules`

Every function takes a `game`, mutates it, and returns a list of events
(section 6). A call that does not apply (wrong phase, unknown or wrong player)
returns an empty list and changes nothing.

```lua
Rules.New(opts, now)                           -> game, events   -- events is { kickoff }
   -- opts = { host, channel, wager, startRoll, joinWord, joinTime, turnTimer }, all required
Rules.Join(game, name, now)                    -> events   -- lobby only
Rules.Tick(game, now, rng)                     -> events   -- countdowns, close, reminders, forfeits
Rules.Roll(game, name, roll, min, max, now)    -> events   -- rolling only
Rules.Cancel(game, now)                        -> events   -- lobby or rolling
Rules.Current(game)                            -> name, range | nil
Rules.Alive(game)                              -> { names in order with status "in" }
Rules.IsLive(game)                             -> boolean  -- phase is lobby or rolling
```

### 5.4 `ns.Chat`

```lua
Chat.PREFIX           = "[DeathRoll]"
Chat.Prefix(text)     -> "[DeathRoll] " .. text          -- exists today
Chat.Render(event, game) -> { line, ... }                -- prefixed chat lines for one event; may be empty
```

### 5.5 `ns.Host`

```lua
Host.Start(opts)      -> true | nil, errorText   -- opts from Parse.StartArgs; fills defaults
Host.Cancel()         -> true | nil, errorText
Host.IsHosting()      -> boolean
Host.Game()           -> game | nil
```

## 6. Events returned by `Rules`

| `type` | Fields | When |
|--------|--------|------|
| `kickoff` | | `Rules.New` |
| `joined` | `name` | a new player joined (no chat text) |
| `countdown` | `secondsLeft`, `names` | a marker in `COUNTDOWN` was passed |
| `closed` | `joined` | close with enough players |
| `order` | `order` | right after `closed` |
| `call` | `name`, `range` | a player is called to roll |
| `wrongRange` | `name`, `range` | the called player rolled another range |
| `reminder` | `name`, `secondsLeft`, `range` | a marker in `REMINDERS` was passed |
| `forfeit` | `name`, `left` | turn timer ran out |
| `out` | `name`, `left` | rolled 1 |
| `winner` | `name`, `losers`, `wager`, `total` | one player left |
| `cancelled` | `reason` | `Cancel` (`"host"`), or close with too few (`"tooFew"`) |

The order inside one returned list is the order to post. Examples: a close
returns `closed, order, call`; rolling a 1 returns `out, call` or `out,
winner`; a forfeit returns `forfeit, call` or `forfeit, winner`.

## 7. Game API used by glue (v1)

Only `src/Host.lua` and `src/Init.lua` call these. Each must be in
`.luacheckrc` `read_globals`.

| API | Used for |
|-----|----------|
| `SendChatMessage(text, channel)` | posting every rendered line `[P0-POST]` |
| `CHAT_MSG_GUILD`, `CHAT_MSG_PARTY`, `CHAT_MSG_PARTY_LEADER`, `CHAT_MSG_RAID`, `CHAT_MSG_RAID_LEADER` | join words; only the game's channel is listened to |
| `CHAT_MSG_SYSTEM` | roll results `[P0-ROLL]` `[P0-DISTANCE]` |
| `Ambiguate(name, "short")` | stripping the realm from chat senders |
| `UnitName("player")` | the host's own name |
| `IsInGuild()`, `IsInGroup()`, `IsInRaid()` | refusing a start in a chat the host is not in |
| `GetTime()` | `now` |
| `C_Timer.NewTicker(1, fn)` | the 1-second tick while a game is live |
| `math.random` | the `rng` for the shuffle |

## 8. Later versions (sketch, not a contract)

Each later version adds modules and a section here. These notes exist so v1
decisions do not block them.

- **v2 window.** `ns.UI` with views registered per file. Needs a
  `GAME_UPDATED` style callback; v1's events list is the hook. The host-only
  window reads `Host.Game()`.
- **v3 sync.** AceComm prefix `DeathRollF`, a pure codec, SNAPSHOT of the
  whole `game` after every change plus a heartbeat. `game.id` exists for this.
- **v4 ledger and trades.** `ns.Ledger` built from a finished `game`:
  `winner`, `eliminated` and `wager` are all it needs. Trade window detection
  marks debts paid.
- **v5 settings, history, stats.** SavedVariables `DeathRollForeverDB` with a
  version number; `Rules.DEFAULTS` becomes the defaults table.

## 9. Glossary

| Term | Meaning |
|------|---------|
| Host | The player whose addon runs the game. Source of truth |
| Player | Anyone who joined. In v1 nobody but the host has the addon |
| Channel | The chat the game runs in: guild, party or raid |
| Join word | The text a player types in that chat to join; `1` in v1 |
| Start roll | The maximum of the first roll and of every fresh range; default 1000 |
| Range | The current maximum: "Type /roll 734" |
| Call | The line that tells a player it is their turn and what to type |
| Turn | One player being called to roll |
| Order | The shuffled player list fixed at close |
| Out | Eliminated by rolling 1. Resets the range |
| Forfeit | Eliminated by the turn timer. Range carries over |
| Wager | The amount each loser owes the winner, in copper |
| Pure module | Lua with no WoW API calls, tested with busted |
| Glue module | Lua that touches events, chat or the WoW API |
