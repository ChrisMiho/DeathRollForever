# Contracts

Status: draft v3 (one-round rules), on top of v1 and v2. Last verified against code: not yet.

Everything that parallel builders share. A builder reads this, their own
feature document and `CLAUDE.md`, and nothing else. If a feature needs
something that is not here, the builder stops and asks the orchestrator.
Nobody changes this document on their own
([orchestration.md](orchestration.md), rule 1).

This document covers **v3: the one-round death roll** played in the chat
(v1) and the host's window (v2). v3 replaces the turn-based rules of v1:
everyone rolls once, the highest roll wins and the lowest roll pays the
difference. The module map, the glue and the window shell are unchanged;
the `game` table, the `Rules` events and the rolling and winner views are
new. Later versions add modules; section 8 sketches them so v3 does not
paint them into a corner, but nothing there is a contract yet.

## 0. Phase 0 dependencies

Decisions that depend on in-game checks are tagged in every document. All of
them were answered during v1 and v2:

| Tag | Check | Answer |
|-----|-------|--------|
| `[P0-ROLL]` | Exact text of the system message for `/roll` | `Name rolls N (1-M)` for everyone, never "You"; character names can contain a space, so the name capture is `(.-)`, not `(%S+)` |
| `[P0-POST]` | Addon code can post to guild, party and raid chat from a slash command and from a timer | Works in guild and party, direct and from a timer |
| `[P0-DISTANCE]` | The host sees the roll of a far-away, ungrouped guild member | Not seen ungrouped, seen when grouped; the kickoff line tells players to stay near the host |
| `[P0-AUTOROLL]` | Addon code can call `RandomRoll` from a timer | Works |
| `[P0-TEMPLATES]` | `BackdropTemplate`, `UIPanelButtonTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate`, `UIPanelCloseButton` exist | All five exist. Every edit box is created with `SetAutoFocus(false)` |
| `[P0-FACTION]` | `UnitFactionGroup("player")` returns the English key; `SetResizeBounds`, `StartSizing`, `SetColorTexture` exist | `Horde` (key first); `SetResizeBounds` yes, `SetMinResize` no, `StartSizing` yes, `SetColorTexture` yes |
| `[P0-CLICKROLL]` | `RandomRoll(1, 100)` from a button's `OnClick` rolls | Works, no error |

v3 needs no new in-game check. `GameTooltip` (the hover box) is a stock
frame on every client.

## 1. Module map

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
| `ns.View` | `src/View.lua` | pure | [visual/](visual/): 01 to 04, one section each |
| `ns.UI` | `src/UI.lua` | glue | [visual/](visual/): 01 to 04, one section each |

`ns.Print(text)` prints one line to the host's own chat frame, prefixed with
the addon name. It is never seen by other players.

### Load order (`DeathRollForever.toc`)

```
embeds.xml
src\Money.lua
src\Parse.lua
src\Rules.lua
src\Chat.lua
src\View.lua
src\Host.lua
src\UI.lua
src\Init.lua
```

Unchanged in v3. A module may call another module only at run time (inside
functions), never at file load, so load order only matters for `Init.lua`.

### Shared files and how to touch them

| File | Rule |
|------|------|
| `DeathRollForever.toc` | Orchestrator only. Unchanged in v3 |
| `src/Init.lua` | Owned by 05 |
| `src/Host.lua` | Owned by 05 |
| `src/View.lua`, `src/UI.lua`, `spec/View_spec.lua` | Shared by the four visual packages, which run one at a time. Each edits its own section and touches no other section |
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
- **No randomness** in the addon. v3 has no shuffle; every roll comes from
  the players' `/roll`. `Rules` takes no `rng`.
- **Errors.** Pure functions that validate input return `nil, errorText`,
  where `errorText` is user-facing text without any prefix. They raise with
  `error` only for programmer mistakes (wrong types).
- **Events** returned by `Rules` are plain tables with a `type` field. The
  caller never mutates them.
- **Text** that players see is defined in exactly one place: chat lines in
  04-announcements, local host messages in 05-host-controller, parse errors in
  01-money and 02-chat-parsing, window text in the visual document that owns
  the state (the hover box text is 01-window's). The window never defines an
  error message; it prints the ones above through `ns.Print`.
- **Faction** is `"Alliance"` or `"Horde"`, the first return of
  `UnitFactionGroup("player")` `[P0-FACTION]`. Glue reads it; pure modules
  take it as a key into `View.TINT`.
- **Colours** are `{ r, g, b }` tables of floats in 0..1.
- **View models** are plain tables built by `ns.View` from a `game`, the
  host's name and `now`. `ns.UI` only copies their fields into frames; it
  computes no text and no number of its own.
- **Name lists** inside `game` and in events are in join order unless a
  document says otherwise.
- **No new globals.** Everything goes through `ns`.

## 3. Constants

Defined on `ns.Rules`, used by Host, Chat and View. v3 has no settings; a
later version replaces these with saved settings.

```lua
Rules.DEFAULTS = { rollMax = 100, joinTime = 60, rollTime = 45, joinWord = "1" }
Rules.COUNTDOWN = { 30, 15, 5 }      -- seconds left to join when a countdown line posts
Rules.REMINDERS = { 20, 10, 5 }      -- seconds left to roll when a reminder posts
Rules.MIN_PLAYERS = 2                -- joined to close the lobby; rolled to settle a round
```

`rollMax` is the top of the range every player rolls (`/roll 100`).
`rollTime` is the seconds a round gives everyone to roll.

## 4. Data structure: `game`

The whole state of one game. Created by `Rules.New`, mutated only by `Rules`
functions. Kept in memory on the host and nowhere else.

```lua
game = {
	id          = "Alice-1762300000",   -- host .. "-" .. math.floor(now) at New
	host        = "Alice",
	channel     = "GUILD",              -- "GUILD" | "PARTY" | "RAID"
	wager       = 1000000,              -- copper per person (100g)
	rollMax     = 100,                  -- everyone types /roll 100
	joinWord    = "1",
	joinTime    = 60,
	rollTime    = 45,
	phase       = "lobby",              -- "lobby" | "rolling" | "finished" | "cancelled"
	createdAt   = 1762300000.5,         -- now at New

	-- Lobby
	joined      = { "Alice", "Bob", "Carl" },  -- join order; frozen at close
	joinDeadline = 1762300060.5,        -- createdAt + joinTime
	countdownSent = {},                 -- { [30]=true, ... } markers already posted

	-- Rolling. A game is one main round, then zero or more tie-break rounds.
	round       = 1,                    -- 1 is the main round; every further round adds one
	rollers     = { "Alice", "Bob", "Carl" },  -- who must roll this round, in join order
	rolls       = { Alice = 97, Bob = 61 },    -- main-round rolls, name -> roll; they stand for the whole game (cleared only when an all-equal round is rerun)
	tie         = nil,                  -- nil in a main round; { high = {names} | nil, low = {names} | nil } in a tie-break
	tieRolls    = {},                   -- this tie-break round's rolls, name -> roll; cleared when a round starts
	rollDeadline = 1762300105.5,        -- set when every round starts
	remindersSent = {},                 -- { [20]=true, ... } for the current round
	history     = {                     -- every valid roll of the game, oldest first
		{ name="Alice", roll=97, max=100, round=1 },
	},

	-- Finished
	high        = nil,                  -- the winning roll, set when the main round settles
	low         = nil,                  -- the losing roll, set with high
	winner      = nil,                  -- name; set as soon as the top is decided
	loser       = nil,                  -- name; set as soon as the bottom is decided
	owed        = nil,                  -- copper the loser owes the winner, set when phase == "finished"
	satOut      = {},                   -- names that did not roll in a main round, in join order
	endedAt     = nil,
	cancelReason = nil,                 -- "host" | "tooFew" | "noRolls", set when phase == "cancelled"
}
```

Invariants:

- In phase `rolling`, a **main round** has `tie == nil` and counts rolls
  into `rolls`; a **tie-break round** has `tie ~= nil`, `rollers` equal to
  `tie.high` followed by `tie.low`, and counts rolls into `tieRolls`.
- A roll counts only from a name in `rollers` that has not rolled this round
  (no entry in `rolls` for a main round, in `tieRolls` for a tie-break).
  Everything else is ignored.
- Every round start sets `rollDeadline = now + rollTime`, clears
  `remindersSent`, and increments `round` except for the first.
- A round settles when every roller has rolled or `now >= rollDeadline`.
- `high` and `low` are set when the main round settles with at least
  `MIN_PLAYERS` rolls and not all equal. They never change afterwards: a
  tie-break decides who among the tied wins or pays, not the amount.
- `winner` and `loser` are set as soon as their end is decided, which may be
  before the other end is. `phase == "finished"` exactly when both are set.
- `owed = Rules.Owed(high, low, wager, rollMax)` when finished.

## 5. Public interfaces

Only what is listed here is public. A builder may add private local functions
freely and adds public functions only through the orchestrator.

### 5.1 `ns.Money`

Unchanged from v1.

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
Parse.ROLL_PATTERN    = "^(.-) rolls (%d+) %((%d+)%-(%d+)%)$"   -- [P0-ROLL]; names may contain spaces
Parse.JoinWord(message, joinWord) -> boolean
Parse.Roll(systemMessage, pattern) -> name, roll, min, max | nil   -- pattern defaults to ROLL_PATTERN
Parse.Command(text)   -> { name = "g", args = { "1g", "500" } }     -- never fails; "" gives name ""
Parse.StartArgs(name, args) -> { channel = "GUILD", wager = 10000, rollMax = 500 or nil } | nil, errorText
                                               -- rollMax is nil when not given; Host fills the default
Parse.CHANNELS        = { g = "GUILD", guild = "GUILD", p = "PARTY", party = "PARTY", r = "RAID", raid = "RAID" }
Parse.USAGE           = "Usage: /dr g|p|r <wager> [roll max]"
Parse.ROLL_MAX_ERROR  = "Roll max must be a whole number from 2 to 1000000"
```

### 5.3 `ns.Rules`

Every function that takes a `game` mutates it and returns a list of events
(section 6). A call that does not apply (wrong phase, unknown or wrong player,
a second roll in the same round) returns an empty list and changes nothing.

```lua
Rules.New(opts, now)                           -> game, events   -- events is { kickoff }
   -- opts = { host, channel, wager, rollMax, joinWord, joinTime, rollTime }, all required
Rules.Join(game, name, now)                    -> events   -- lobby only
Rules.Tick(game, now)                          -> events   -- countdowns, close, reminders, a round settling on its deadline
Rules.Roll(game, name, roll, min, max, now)    -> events   -- rolling only
Rules.Cancel(game, now)                        -> events   -- lobby or rolling
Rules.Waiting(game)                            -> { names }   -- rollers who have not rolled this round, in order; {} outside rolling
Rules.Owed(high, low, wager, rollMax)          -> copper   -- math.floor((high - low) * wager / rollMax)
Rules.IsLive(game)                             -> boolean  -- phase is lobby or rolling
```

`Rules.Owed` is pure arithmetic on integers. With the default `rollMax` of
100 it is the percentage of the wager that the gap between the two rolls
makes: 97 against 8 on 100g owes 89g. Known limit: the product
`(high - low) * wager` exceeds 2^53 only for a wager near `Money.MAX` with a
`rollMax` near its maximum; nobody plays that.

### 5.4 `ns.Chat`

```lua
Chat.PREFIX           = "[DeathRoll]"
Chat.Prefix(text)     -> "[DeathRoll] " .. text
Chat.Render(event, game) -> { line, ... }                -- prefixed chat lines for one event; may be empty
```

### 5.5 `ns.Host`

```lua
Host.Start(opts)      -> true | nil, errorText   -- opts from Parse.StartArgs or View.StartOpts; fills defaults
Host.Cancel()         -> true | nil, errorText
Host.IsHosting()      -> boolean
Host.Game()           -> game | nil
Host.OnChange(fn)     -> nil   -- registers the one listener; a second call replaces it
```

`fn(game)` runs at the end of `Host.Start`, at the end of every tick (even
one that posted nothing) and after every post that followed a chat event or
`Host.Cancel`. When the game has just finished or been cancelled, `fn` runs
with that game before `Host` drops it, so a listener may keep its own
reference to a finished game. `fn` is never called with `nil`.

### 5.6 `ns.View` (pure)

```lua
View.TINT = {    -- 0..1 rgb. title: title bar, highest row; button: main button, bar fill; text: big numbers, status line; low: lowest row
	Alliance = { title = { 0.114, 0.302, 0.690 }, button = { 0.165, 0.388, 0.847 }, text = { 0.553, 0.706, 1.000 }, low = { 0.431, 0.133, 0.133 } },
	Horde    = { title = { 0.490, 0.110, 0.110 }, button = { 0.831, 0.231, 0.231 }, text = { 1.000, 0.612, 0.612 }, low = { 0.420, 0.290, 0.102 } },
}
View.State(game)        -> "form" | "lobby" | "rolling" | "winner"   -- nil or a cancelled game gives "form"
View.ChatName(channel)  -> "guild" | "party" | "raid"
View.Subtitle(game)     -> "Raid chat, 100g per person, roll 1-100"
View.Help(joinWord, rollMax) -> { line, ... }   -- the hover box, one string per line
View.StartOpts(channel, wagerText, rollMaxText) -> opts | nil, errorText   -- what Parse.StartArgs returns
View.Lobby(game, host, now)  -> { subtitle, secondsLeft, fraction, count, rows = { { n, name, you } }, status }
View.Game(game, host, now)   -> { subtitle, header = { label, count }, rows = { { name, you, value, tag, mark } },
                                  status, secondsLeft, fraction, button = { label, enabled, max } }
View.Result(game, host)      -> { subtitle, winner, winningRoll, rows = { { name, you, value, mark } },
                                  debt = { text, you, amount } }
```

Row `mark` is one of `""` (plain), `"high"` (tinted as the highest),
`"low"` (tinted as the lowest), `"waiting"` (dimmed, still to roll) or
`"out"` (dimmed, sat out). `Game` rows cover every name in `joined`: the
waiting, the highest, the lowest, the rest and the sat out, in that order;
`Result` rows the same without a waiting group. Row `tag` is a short text after the name, or
`""`. Every field's exact value is in the owning document.

Owners: `TINT`, `State`, `ChatName`, `Subtitle`, `Help` are 01-window;
`StartOpts` is 02-form; `Lobby` and `Game` are 03-in-progress; `Result` is
04-winner.

### 5.7 `ns.UI` (glue)

```lua
UI.Show()   -> nil   -- builds the window on first use, draws the state View.State(game) gives, shows it
UI.Hide()   -> nil   -- hides the window; does nothing while a game is live (lobby or rolling)
```

The window registers `Host.OnChange` on `PLAYER_LOGIN` and redraws on every
call. 01-window owns the rest of its behaviour, including the hover box.

## 6. Events returned by `Rules`

| `type` | Fields | When |
|--------|--------|------|
| `kickoff` | | `Rules.New` |
| `joined` | `name` | a new player joined (no chat text) |
| `countdown` | `secondsLeft`, `names` | a marker in `COUNTDOWN` was passed |
| `closed` | `joined` | close with enough players |
| `call` | `names`, `max`, `seconds` | a main round starts: everyone in `names` rolls `1-max` within `seconds` |
| `rolled` | `name`, `roll`, `waiting` | a valid roll was counted; `waiting` is how many rollers are still to roll (no chat text) |
| `wrongRange` | `name`, `max` | a roller rolled another range |
| `reminder` | `names`, `secondsLeft`, `max` | a marker in `REMINDERS` was passed; `names` are still to roll |
| `satOut` | `names` | a main round settled with players who did not roll |
| `allTied` | `roll`, `names` | every roll of a main round was the same; a new main round follows |
| `tieBreak` | `high`, `low`, `max`, `seconds` | a tie-break round starts; `high` and `low` are the tied names or nil |
| `winner` | `name`, `loser`, `high`, `low`, `owed` | both ends decided |
| `cancelled` | `reason` | `Cancel` (`"host"`), close or a main round with too few (`"tooFew"`), a tie-break side nobody rolled (`"noRolls"`) |

The order inside one returned list is the order to post. Examples: a close
returns `closed, call`; the last roll of a main round returns `rolled,
winner`, or `rolled, tieBreak`, or `rolled, allTied, call`; a main round
settling on its deadline returns `satOut` first, then `winner`, `tieBreak`,
`allTied, call` or `cancelled`; a tie-break round settling returns `winner`,
`tieBreak` or `cancelled`.

## 7. Game API used by glue

Only `src/Host.lua`, `src/Init.lua` and `src/UI.lua` call these. Each must
be in `.luacheckrc` `read_globals`.

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

Used by `src/UI.lua` only:

| API | Used for |
|-----|----------|
| `UIParent` | parent of the window |
| `CreateFrame` with the templates `BackdropTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate` (strings, not globals) | the window, edit boxes, list boxes `[P0-TEMPLATES]` |
| `UnitFactionGroup("player")` | the tint and the footer `[P0-FACTION]` |
| `UnitName("player")`, `Ambiguate` | the host's name, for `(you)` and the host's own roll |
| `RandomRoll(1, max)` | the Roll button `[P0-CLICKROLL]` |
| `GetTime()` | `now` for every draw |
| `PLAYER_LOGIN` | registering the `Host.OnChange` listener |
| `GameTooltip` | the hover box under the `?` in the title bar |
| `GameFontNormalLarge`, `GameFontHighlight`, `GameFontDisable`, `GameFontNormalHuge`, `NumberFontNormalHuge` | font objects (visual.md 4.3) |

`math.random` is no longer used anywhere. Frame methods (`SetResizeBounds`,
`StartSizing`, `SetColorTexture`, ...) are not globals and need no
`.luacheckrc` entry.

## 8. Later versions (sketch, not a contract)

Each later version adds modules and a section here. These notes exist so v3
decisions do not block them.

- **v4 sync.** AceComm prefix `DeathRollF`, a pure codec, SNAPSHOT of the
  whole `game` after every change plus a heartbeat. `game.id` exists for this.
- **v5 ledger and trades.** `ns.Ledger` built from a finished `game`:
  `winner`, `loser` and `owed` are all it needs. Trade window detection
  marks the debt paid.
- **v6 settings, history, stats.** SavedVariables `DeathRollForeverDB` with a
  version number; `Rules.DEFAULTS` becomes the defaults table.
  `game.history` is what a game record keeps.

## 9. Glossary

| Term | Meaning |
|------|---------|
| Host | The player whose addon runs the game. Source of truth |
| Player | Anyone who joined. Nobody but the host needs the addon |
| Channel | The chat the game runs in: guild, party or raid |
| Join word | The text a player types in that chat to join; `1` |
| Roll max | The top of the range everyone rolls: `/roll 100`. Default 100 |
| Round | One call to roll and the window that follows. The main round is everyone; a tie-break round is the tied players |
| Main round | A round with `tie == nil`: every roll counts for the game |
| Tie-break | A round only the players tied for highest or lowest roll in; it decides who, not how much |
| Call | The line that tells everyone to roll and what to type |
| Waiting | A roller who has not rolled yet this round |
| Sat out | A player who did not roll in a main round. Owes nothing, wins nothing |
| Highest, lowest | The top and bottom main-round rolls. The highest wins, the lowest pays |
| Owed | `(highest - lowest) * wager / rollMax`, rounded down to copper |
| Wager | The stake per person, in copper. The most the loser can owe |
| State | What the window shows: form, lobby, rolling or winner |
| Tint | The faction colours on the title bar, bars, highest row and main button; `low` is the lowest row's colour |
| View model | A plain table `ns.View` builds for `ns.UI` to draw |
| Pure module | Lua with no WoW API calls, tested with busted |
| Glue module | Lua that touches events, chat or the WoW API |
