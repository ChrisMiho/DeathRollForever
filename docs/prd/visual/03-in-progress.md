# 03 In progress: the lobby and the rolling game

Status: draft v2. Owns the `lobby` and `rolling` sections of `src/UI.lua` and `src/View.lua` (`View.Lobby`, `View.Game`) and their tests in `spec/View_spec.lua`. Package 08.

## Purpose and scope

The window while a game is live. During the lobby: the countdown, the join
bar and who joined. During rolling: the order with each player's last roll,
who is up and what to type, the turn bar, and the Roll button that rolls the
right range on the host's turn.

Out of scope: kick, extend, a separate list of recent rolls, reminders in
the window, anything for players other than the host.

## Depends on / blocks

Depends on: 01-window merged; [contracts.md](../contracts.md) section 4
(`game`), 5.3 (`Rules.Current`), 5.6, 5.7, 7 (`RandomRoll`);
[visual.md](../visual.md) section 4. Phase 0: `[P0-CLICKROLL]`.
Blocks: nothing.

## Behaviour

### Pure: `View.Lobby(game, host, now)`

| Field | Value |
|-------|-------|
| `subtitle` | `View.Subtitle(game)` |
| `secondsLeft` | `math.max(0, math.ceil(game.joinDeadline - now))` |
| `fraction` | `(game.joinDeadline - now) / game.joinTime`, clamped to 0..1 |
| `count` | `#game.joined` |
| `rows` | one per `game.joined` in order: `{ n = i, name = name, you = (name == host) }` |
| `status` | `"Type <joinWord> in <chat> chat to join"` |

### Pure: `View.Game(game, host, now)`

`current, range = Rules.Current(game)`.

| Field | Value |
|-------|-------|
| `subtitle` | `View.Subtitle(game)` |
| `rows` | one per `game.order` in order: `{ n = i, name = name, you = (name == host), current = (name == current), out = (game.status[name] ~= "in"), value = see below }` |
| `status` | `"You are up: /roll <range>"` when `current == host`, else `"<current> is up: /roll <range>"` |
| `secondsLeft` | `math.max(0, math.ceil(game.turnDeadline - now))` |
| `fraction` | `(game.turnDeadline - now) / game.turnTimer`, clamped to 0..1 |
| `button` | `{ label = "Roll 1-<range>", enabled = (current == host), range = range }` |

Row `value`: `"1-<range>"` for the current player; `"out"` for a player
whose status is `"out"` or `"forfeit"`; otherwise that player's most recent
entry in `game.rolls` as a plain number (`"734"`), or `""` if they have not
rolled yet.

Both functions raise if `game.phase` is not the phase they draw (programmer
mistake); `UI.lua` only calls them in the right state.

### The lobby (`build.lobby`, `draw.lobby`)

Top to bottom, 10 px gaps:

1. Subtitle, muted.
2. The countdown number, `NumberFontNormalHuge`, tint text, centred; under
   it `SECONDS LEFT TO JOIN` in muted, centred.
3. The progress bar, `fraction`.
4. A header row: `Joined` at the left, `count` at the right, both muted.
5. The list box, filling the room down to the status line: rows `n.`
   muted, name, and `(you)` in muted after the host's name.
6. Status line, `GameFontHighlight` in text colour, anchored above the main
   button, with the join word in tint text: `Type ` + `1` + ` in raid chat
   to join`. Build it as three font strings, or one string with the join
   word wrapped in the tint's colour code; either is fine.

The main button stays `Roll`, disabled (01 sets it on the state switch).

### Rolling (`build.rolling`, `draw.rolling`, `onMain.rolling`)

1. Subtitle, muted.
2. The list box, filling the room down to the status line. Each row: `n.`
   muted, name, then `up now` in muted after the current player's name
   (white at reduced alpha on the tinted row), `(you)` after the host's,
   then `value` right-aligned in muted. The current row's background is
   tint title and its texts white. An out row's name and value are in the
   disabled colour with the strike line of
   [visual.md 4.3](../visual.md#43-type).
3. Status line, `GameFontHighlight`, bold is not available so use tint text
   colour: `Bob is up: /roll 734`.
4. The progress bar, `fraction`, 6 px, directly under the status line.

Every `draw.rolling` sets the main button's label to `button.label` and
enables it only when `button.enabled`.

`onMain.rolling()`: `RandomRoll(1, range)` with the `range` from the last
draw `[P0-CLICKROLL]`, then disable the main button and keep it disabled,
whatever later draws say, until a draw finds the host is no longer the
current player (the roll result arrived, or the turn timer forfeited the
host) or a new game. A second click before the roll result arrives does
nothing.

Lists reuse row frames: build as many rows as needed on the first draw,
keep them, and hide the spares. Rows are never created inside `OnUpdate`
after the first draw.

## Exact user-facing text

| Where | Text |
|-------|------|
| lobby label | `SECONDS LEFT TO JOIN` |
| lobby header | `Joined` |
| lobby status | `Type 1 in raid chat to join` |
| row tags | `(you)`, `up now` |
| row values | `734`, `1-734`, `out`, `` |
| rolling status | `Bob is up: /roll 734`, `You are up: /roll 734` |
| main button | `Roll`, `Roll 1-734` |

## Interfaces

Implements `View.Lobby` and `View.Game` (contracts 5.6). Uses
`Rules.Current`, `View.Subtitle`, `View.ChatName`, `RandomRoll`, the list
box helper from 01.

## Files

Edits `src/UI.lua` (fills `build.lobby`, `draw.lobby`, `build.rolling`,
`draw.rolling`, `onMain.rolling`), `src/View.lua` (adds `Lobby`, `Game`),
`spec/View_spec.lua`. Adds `RandomRoll` and any other name used to
`.luacheckrc`. One line in `CHANGELOG.md`.

## Acceptance criteria

### Automated (busted)

Fixtures: `lobby` is a game from `Rules.New` with host `Eve`, channel
`RAID`, wager 10000, startRoll 1000, created at `now = 1000`, with `Alice`,
`Bob`, `Eve` joined in that order. `rolling` is a game in phase `rolling`
with `order = { "Alice", "Bob", "Carl", "Dan", "Eve" }`, `status` all `in`
except `Carl = "out"`, `turn = 2`, `range = 734`, `turnTimer = 45`,
`turnDeadline = 1045`, `rolls = { {name="Alice", roll=734, max=1000} }`,
host `Eve`. Build them by calling `Rules` or by hand; the spec says which.

| ID | Input | Expected |
|----|-------|----------|
| AC-08-01 | `Lobby(lobby, "Eve", 1018)` | `secondsLeft = 42`, `fraction = 0.7` (within 0.001), `count = 3` |
| AC-08-02 | `Lobby(lobby, "Eve", 1018).rows` | `{ {n=1,name="Alice",you=false}, {n=2,name="Bob",you=false}, {n=3,name="Eve",you=true} }` |
| AC-08-03 | `Lobby(lobby, "Eve", 1018).status` | `"Type 1 in raid chat to join"` |
| AC-08-04 | `Lobby(lobby, "Eve", 1000.2).secondsLeft` | `60` (ceil) |
| AC-08-05 | `Lobby(lobby, "Eve", 1070)` | `secondsLeft = 0`, `fraction = 0` |
| AC-08-06 | `Lobby(lobby, "Eve", 1018).subtitle` | `"Raid chat, 1g per person, first roll 1-1000"` |
| AC-08-07 | `Game(rolling, "Eve", 1014).rows[1]` | `{ n=1, name="Alice", you=false, current=false, out=false, value="734" }` |
| AC-08-08 | `Game(rolling, "Eve", 1014).rows[2]` | `{ n=2, name="Bob", you=false, current=true, out=false, value="1-734" }` |
| AC-08-09 | `Game(rolling, "Eve", 1014).rows[3]` | `{ n=3, name="Carl", you=false, current=false, out=true, value="out" }` |
| AC-08-10 | `Game(rolling, "Eve", 1014).rows[5]` | `{ n=5, name="Eve", you=true, current=false, out=false, value="" }` |
| AC-08-11 | `Game(rolling, "Eve", 1014).status` | `"Bob is up: /roll 734"` |
| AC-08-12 | `Game(rolling, "Eve", 1014)` | `secondsLeft = 31`, `fraction` within 0.001 of `31/45` |
| AC-08-13 | `Game(rolling, "Eve", 1014).button` | `{ label = "Roll 1-734", enabled = false, range = 734 }` |
| AC-08-14 | the same game with `turn = 5` | `status = "You are up: /roll 734"`, `button.enabled = true`, `rows[5].current = true`, `rows[5].value = "1-734"` |
| AC-08-15 | a player with two rolls in `game.rolls` | `value` is the later one |
| AC-08-16 | a forfeited player (`status = "forfeit"`) | `out = true`, `value = "out"` |
| AC-08-17 | `Game(rolling, "Eve", 1100)` | `secondsLeft = 0`, `fraction = 0` |
| AC-08-18 | `Lobby(rolling, ...)`, `Game(lobby, ...)` | raises |

### In-game (manual)

Run with two other characters in a party or raid.

| ID | Do | Expect |
|----|----|--------|
| IG-08-01 | `Start` with `Raid`, `1g`, `1000` | lobby: subtitle `Raid chat, 1g per person, first roll 1-1000`, a big `60` counting down once a second, the bar shrinking smoothly, `Joined 0`, the status line with `1` tinted |
| IG-08-02 | three players type `1`, you among them | the list fills in join order with `(you)` after your name, `Joined 3` |
| IG-08-03 | watch the countdown reach 0 | the window switches to rolling: the shuffled order, the first row called with `up now` and `1-1000`, status `<name> is up: /roll 1000`, the bar full and shrinking |
| IG-08-04 | the called player rolls | their row shows the number, the next row is current, the status and the button label change, the bar refills |
| IG-08-05 | when it is your turn | status `You are up: /roll <n>`, the button turns tinted and reads `Roll 1-<n>` |
| IG-08-06 | click `Roll 1-<n>` | `<you> rolls <r> (1-<n>)` appears in chat once, the next player is called, the button is gray again `[P0-CLICKROLL]` |
| IG-08-07 | double-click `Roll` fast | one roll only |
| IG-08-08 | a player lets the timer run out | their row shows `out` struck through; the range carries over to the next row |
| IG-08-09 | a player rolls 1 | their row shows `out`; the next current row shows `1-1000` |
| IG-08-10 | run a game with 8 or more players at the default size | the list scrolls; making the window taller shows more rows |
| IG-08-11 | click `Cancel` during rolling | the cancel line once; the form |

## Mockup references

[../../mockups/window-v2.html](../../mockups/window-v2.html), panels 2a and
2b; tick "It is the host's turn" for the enabled button.

## Open questions

None.
