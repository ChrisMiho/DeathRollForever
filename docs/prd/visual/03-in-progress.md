# 03 In progress: the lobby and the rolling round

Status: draft v3. Last verified against code: not yet. Owns the `lobby` and `rolling` sections of `src/UI.lua` and `src/View.lua` (`View.Lobby`, `View.Game`) and their tests in `spec/View_spec.lua`. Package 15.

## Purpose and scope

The window while a game is live. During the lobby: the countdown, the join
bar and who joined (unchanged from v2). During a round: who has rolled and
who is still to, the highest and lowest so far, the roll bar, and the Roll
button that rolls the right range until the host has rolled.

Out of scope: kick, extend, reminders in the window, anything for players
other than the host.

## Depends on / blocks

Depends on: 01-window (v3) merged; [contracts.md](../contracts.md) section
4 (`game`), 5.3 (`Rules.Waiting`), 5.6, 5.7, 7 (`RandomRoll`);
[visual.md](../visual.md) section 4. Phase 0: `[P0-CLICKROLL]`.
Blocks: nothing.

## Behaviour

### Pure: `View.Lobby(game, host, now)`

Unchanged from v2.

| Field | Value |
|-------|-------|
| `subtitle` | `View.Subtitle(game)` |
| `secondsLeft` | `math.max(0, math.ceil(game.joinDeadline - now))` |
| `fraction` | `(game.joinDeadline - now) / game.joinTime`, clamped to 0..1 |
| `count` | `#game.joined` |
| `rows` | one per `game.joined` in order: `{ n = i, name = name, you = (name == host) }` |
| `status` | `"Type <joinWord> in <chat> chat to join"` |

### Pure: `View.Game(game, host, now)`

`waiting = Rules.Waiting(game)`; `rolled` = `#game.rollers - #waiting`.

| Field | Value |
|-------|-------|
| `subtitle` | `View.Subtitle(game)` |
| `header` | `{ label, count }`, see below |
| `rows` | see below |
| `status` | main round 1: `"Everyone: /roll <max>"`; a later main round: `"Everyone: /roll <max> again"`; tie-break: `"<rollers' full names joined by ', '>: /roll <max> again"` |
| `secondsLeft` | `math.max(0, math.ceil(game.rollDeadline - now))` |
| `fraction` | `(game.rollDeadline - now) / game.rollTime`, clamped to 0..1 |
| `button` | `{ label = "Roll 1-<max>", enabled = (host is in waiting), max = game.rollMax }` |

Header: `count` is always `"<rolled> of <#rollers>"`. `label` is `Rolled`
in the first main round, `Rolled again` in a later main round, and in a
tie-break `Tie for highest`, `Tie for lowest` or `Tie for highest and
lowest` by which of `tie.high` and `tie.low` are set.

Rows, one per name in `game.joined`, each `{ name, you = (name == host),
value, tag, mark }`, in five groups, in this order:

1. **Waiting**: in a main round (`game.tie == nil`), the names in
   `waiting`, in that order. `mark = "waiting"`, `value = "waiting"`,
   `tag = ""`. Empty in a tie-break round: the tied players stay in their
   groups below.
2. **Highest**: `game.tie.high` when a tie-break has a high side; else
   `{ game.winner }` when the winner is decided; else every name in
   `game.rolls` with the largest roll, in `joined` order. `mark = "high"`,
   `value` = the name's main-round roll as text.
3. **Lowest**: `game.tie.low` when a tie-break has a low side; else
   `game.losers` when the losers are decided; else every name in
   `game.rolls` with the smallest roll that is not already in the highest
   group (so a single roll, or all-equal rolls, make only highest rows).
   `mark = "low"`, `value` = the roll.
4. **The rest**: every other name in `game.rolls`, sorted by roll, highest
   first (ties in `joined` order), then interleaved from both ends: the
   first, the last, the second, the second last, and so on, until the list
   is used up. `mark = ""`, `value` = the roll. A player who shared the top
   or bottom roll but lost or dropped out of a tie-break is here, with that
   roll.
5. **Sat out**: `game.satOut`, in that order. `mark = "out"`, `value =
   "sat out"`, `tag = ""`. Empty in the first main round.

Tags: a name in `game.tie.high` or `game.tie.low` (the current tie-break)
has `"re-roll"` while it is in `waiting` and `"re-rolled <n>"` once
`game.tieRolls[name]` is set. Every other highest row has `"highest"`,
every other lowest row `"lowest"`, and the rest `""`.

Both functions raise if `game.phase` is not the phase they draw (programmer
mistake); `UI.lua` only calls them in the right state.

### The lobby (`build.lobby`, `draw.lobby`)

Unchanged from v2. Top to bottom, 10 px gaps:

1. Subtitle, muted.
2. The countdown number, `NumberFontNormalHuge`, tint text, centred; under
   it `SECONDS LEFT TO JOIN` in muted, centred.
3. The progress bar, `fraction`.
4. A header row: `Joined` at the left, `count` at the right, both muted.
5. The list box, filling the room down to the status line: rows `n.`
   muted, name, and `(you)` in muted after the host's name.
6. Status line, `GameFontHighlight` in text colour, anchored above the main
   button, with the join word in tint text.

The main button stays `Roll`, disabled (01 sets it on the state switch).

### Rolling (`build.rolling`, `draw.rolling`, `onMain.rolling`)

Top to bottom, 10 px gaps:

1. Subtitle, muted.
2. A header row like the lobby's: `header.label` at the left,
   `header.count` at the right, both muted.
3. The list box, filling the room down to the status line. Each row: name,
   then `tag` in muted after the name when not empty (white at reduced alpha
   on a tinted row), `(you)` after the host's, then `value` right-aligned
   in muted. No row numbers. Painting by `mark`:
   - `"high"`: background tint title, every text white.
   - `"low"`: background tint low, every text white.
   - `"waiting"` and `"out"`: no background; name and value in the disabled
     colour, no strike line.
   - `""`: no background; name in text colour, value in muted.
4. Status line, `GameFontHighlight` in tint text: `Everyone: /roll 100`.
5. The progress bar, `fraction`, 6 px, directly under the status line.

Rows move as rolls come in: a draw repaints every row from the model, so a
player who rolls leaves the top group and lands in their place.

Every `draw.rolling` sets the main button's label to `button.label` and
enables it only when `button.enabled`.

`onMain.rolling()`: `RandomRoll(1, max)` with the `max` from the last draw
`[P0-CLICKROLL]`, then disable the main button and keep it disabled,
whatever later draws say, until a draw finds the host is no longer waiting
(the roll result arrived, or the round ended) or a new round or game. A
second click before the roll result arrives does nothing.

Lists reuse row frames: build as many rows as needed on the first draw,
keep them, and hide the spares. Rows are never created inside `OnUpdate`
after the first draw.

## Exact user-facing text

| Where | Text |
|-------|------|
| lobby label | `SECONDS LEFT TO JOIN` |
| lobby header | `Joined` |
| lobby status | `Type 1 in raid chat to join` |
| rolling header labels | `Rolled`, `Rolled again`, `Tie for highest`, `Tie for lowest`, `Tie for highest and lowest` |
| rolling header count | `3 of 5` |
| row tags | `(you)`, `highest`, `lowest`, `re-roll`, `re-rolled 40` |
| row values | `97`, `waiting`, `sat out` |
| rolling status | `Everyone: /roll 100`, `Everyone: /roll 100 again`, `Alice, Eve: /roll 100 again` |
| main button | `Roll`, `Roll 1-100` |

## Interfaces

Implements `View.Lobby` and `View.Game` (contracts 5.6). Uses
`Rules.Waiting`, `View.Subtitle`, `View.ChatName`, `RandomRoll`, the list
box helper from 01, `View.TINT.<faction>.low`.

## Files

Edits `src/UI.lua` (`build.rolling`, `draw.rolling`, `onMain.rolling`, the
row painting), `src/View.lua` (`Game`), `spec/View_spec.lua` (the `Game`
tests). One line in `CHANGELOG.md`.

## Acceptance criteria

### Automated (busted)

Fixtures: `lobby` is a game from `Rules.New` with host `Eve`, channel
`RAID`, wager 1000000, rollMax 100, created at `now = 1000`, with `Alice`,
`Bob`, `Eve` joined in that order. `rolling` is a game built with `Rules`:
host `Eve`, channel `RAID`, wager 1000000, rollMax 100, rollTime 45, joined
`Alice, Bob, Carl, Dan, Eve, Frank, Gina` in that order, closed at `t =
1000`, then `Roll`s at `t + 1`: Alice 97, Bob 61, Eve 55, Frank 40, Carl
23, Dan 8 (Gina has not rolled). `tie` is a game built the same way with
joined `Alice, Bob, Carl, Dan, Eve`, rolls Alice 97, Bob 61, Carl 40, Dan 8,
Eve 97, so a high tie-break between Alice and Eve started at `t + 1`.

| ID | Input | Expected |
|----|-------|----------|
| AC-15-01 | `Lobby(lobby, "Eve", 1018)` | `secondsLeft = 42`, `fraction = 0.7` (within 0.001), `count = 3` |
| AC-15-02 | `Lobby(lobby, "Eve", 1018).rows` | `{ {n=1,name="Alice",you=false}, {n=2,name="Bob",you=false}, {n=3,name="Eve",you=true} }` |
| AC-15-03 | `Lobby(lobby, "Eve", 1018).status` | `"Type 1 in raid chat to join"` |
| AC-15-04 | `Lobby(lobby, "Eve", 1070)` | `secondsLeft = 0`, `fraction = 0` |
| AC-15-05 | `Lobby(lobby, "Eve", 1018).subtitle` | `"Raid chat, 100g per person, roll 1-100"` |
| AC-15-06 | `Game(rolling, "Eve", 1014).header` | `{ label = "Rolled", count = "6 of 7" }` |
| AC-15-07 | `Game(rolling, "Eve", 1014).rows`, names and marks in order | `Gina waiting`, `Alice high`, `Dan low`, `Bob ""`, `Carl ""`, `Eve ""`, `Frank ""` |
| AC-15-08 | the same rows, values | `waiting`, `97`, `8`, `61`, `23`, `55`, `40` |
| AC-15-09 | the same rows, tags | `""`, `highest`, `lowest`, `""`, `""`, `""`, `""`; `rows[6].you == true` |
| AC-15-10 | `Game(rolling, "Eve", 1014).status` | `"Everyone: /roll 100"` |
| AC-15-11 | `Game(rolling, "Eve", 1014)` | `secondsLeft = 31`, `fraction` within 0.001 of `31/45` (the round started at 1000) |
| AC-15-12 | `Game(rolling, "Eve", 1014).button` | `{ label = "Roll 1-100", enabled = false, max = 100 }` (Eve has rolled) |
| AC-15-13 | the same game before Eve rolled | `button.enabled = true`; the waiting rows are `Eve` then `Gina` (`rollers` order) |
| AC-15-14 | a fresh round, nobody rolled | every row `waiting` in joined order; `header.count = "0 of 7"` |
| AC-15-15 | one roll only (Alice 97) | Alice `high` with tag `highest`; no `low` row; the rest waiting |
| AC-15-16 | two rolls, both 50 | both `high`, tag `highest`; no `low` row |
| AC-15-17 | `Game(tie, "Eve", 1002).header` | `{ label = "Tie for highest", count = "0 of 2" }` |
| AC-15-18 | `Game(tie, "Eve", 1002).rows`, names, marks, tags | `Alice high re-roll`, `Eve high re-roll`, `Dan low lowest`, `Bob "" ""`, `Carl "" ""` |
| AC-15-19 | `Game(tie, "Eve", 1002).status` | `"Alice, Eve: /roll 100 again"` |
| AC-15-20 | `Game(tie, "Eve", 1002).button.enabled` | `true` (Eve is tied and has not re-rolled) |
| AC-15-21 | after `Roll(tie, "Alice", 40, 1, 100, 1003)` | Alice's tag `re-rolled 40`, value still `97`; `header.count = "1 of 2"` |
| AC-15-22 | a tie-break with both ends (rolls 97, 97, 8, 8 for Alice, Bob, Carl, Dan) | `header.label = "Tie for highest and lowest"`, status `"Alice, Bob, Carl, Dan: /roll 100 again"`, rows Alice high, Bob high, Carl low, Dan low, all tagged `re-roll` |
| AC-15-23 | a rerun main round (all rolled 50, then `allTied`) | `header.label = "Rolled again"`, status `"Everyone: /roll 100 again"`, every row waiting |
| AC-15-24 | `Game(rolling, "Eve", 1100)` | `secondsLeft = 0`, `fraction = 0` |
| AC-15-25 | `Lobby(rolling, ...)`, `Game(lobby, ...)` | raises |
| AC-15-26 | 4 players Alice, Bob, Carl, Dan; rolls Alice 97, Bob 97, Carl 8, Dan none; `Tick` past the deadline | a high tie-break with Dan sat out: rows `Alice high re-roll`, `Bob high re-roll`, `Carl low lowest`, `Dan out ""` with value `sat out`; `header.count = "0 of 2"` |
| AC-15-28 | the tie fixture with `fullNames.Alice = "Alice Vale"`; Alice re-rolls 40 | status `Alice Vale, Eve: /roll 100 again`; row 1 `name == "Alice Vale"`, tag `re-rolled 40`; no other fields on the row |
| AC-15-27 | 4 players; rolls Alice 97, Bob 97, Carl 8, Dan 97; tie rolls Alice 50, Dan 50, Bob none; `Tick` past the deadline | a second high tie-break (`round == 3`): rows `Alice high re-roll`, `Dan high re-roll`, `Carl low lowest`, `Bob "" ""` with value `97` |
| AC-15-28 | 5 players; rolls Alice 97, Bob 8, Carl 8, Dan 8, Eve 50; tie rolls Bob 40, Carl none, Dan none; deadline | a low roll-off between Carl and Dan with the winner decided: rows `Alice high highest`, `Carl low re-roll`, `Dan low re-roll`, then `Eve "" ""` 50 and `Bob "" ""` 8 |

### In-game (manual)

Run with two other characters in a party or raid.

| ID | Do | Expect |
|----|----|--------|
| IG-15-01 | `Start` with `Raid`, `100g`, `100` | lobby: subtitle `Raid chat, 100g per person, roll 1-100`, a big `45` counting down, the bar shrinking, `Joined 0`, the status line with `1` tinted |
| IG-15-02 | three players type `1`, you among them | the list fills in join order with `(you)` after your name, `Joined 3` |
| IG-15-03 | watch the countdown reach 0 | the window switches to rolling: header `Rolled 0 of 3`, every row dimmed `waiting`, status `Everyone: /roll 100`, the bar full and shrinking, the button tinted `Roll 1-100` |
| IG-15-04 | a player rolls | their row leaves the waiting group, shows the number, and is tinted as highest; `Rolled 1 of 3` |
| IG-15-05 | a second player rolls lower | their row is tinted as lowest under the highest; the waiting player stays on top |
| IG-15-06 | click `Roll 1-100` | `<you> rolls <r> (1-100)` appears in chat once, your row lands in its place, the button is gray `[P0-CLICKROLL]` |
| IG-15-07 | double-click `Roll` fast | one roll only |
| IG-15-08 | a player lets the timer run out | their row stays `waiting` until the round ends; then the result shows them last as `sat out`, or, if a tie-break follows, the tie-break list shows them last as `sat out` |
| IG-15-09 | force a tie with `Roll max` 2 and three players | the header reads `Tie for highest` or `Tie for lowest`, the tied rows keep their tint and say `re-roll`, the status names them, the bar refills; a tied player who rolls shows `re-rolled <n>`; a tied player who drops out of a second tie-break moves to the plain rows with their original roll |
| IG-15-10 | run a game with 8 or more players at the default size | the list scrolls; making the window taller shows more rows |
| IG-15-11 | click `Cancel` during rolling | the cancel line once; the form |

## Mockup references

[../../mockups/window-v3.html](../../mockups/window-v3.html), panels 1 and
2.

## Open questions

None.
