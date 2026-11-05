# 03 Rules engine

Status: draft v1. Owns `src/Rules.lua`, `spec/Rules_spec.lua`.

## Purpose and scope

The whole game as a pure state machine: a `game` table (contracts section 4)
and functions that move it from lobby to rolling to finished or cancelled.
Every function returns the list of events that happened (contracts section 6)
so the host can post them; the engine itself never produces text and never
reads a clock. Pure Lua, no WoW API.

Out of scope: text (04), posting and timing (05), kick, extend, settings.

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) sections 3, 4, 5.3, 6.
Blocks: 04-announcements (needs the event shapes), 05-host-controller.

## Behaviour

### `Rules.New(opts, now)`

All of `host, channel, wager, startRoll, joinWord, joinTime, turnTimer` are
required; a missing or wrongly typed field raises. Returns a `game` in phase
`lobby` with `id = host .. "-" .. math.floor(now)`, `createdAt = now`,
`joinDeadline = now + joinTime`, empty `joined`, `countdownSent`, `order`,
`status`, `eliminated`, `rolls`, `remindersSent`. The `kickoff` event is
returned by a second value: `game, events`.

### `Rules.Join(game, name, now)`

Phase `lobby` only. A name already in `joined` returns `{}`. Otherwise appends
and returns `{ {type="joined", name=name} }`.

### `Rules.Tick(game, now, rng)`

Returns `{}` in phase `finished` or `cancelled`. Idempotent: calling twice with
the same `now` returns `{}` the second time.

In phase `lobby`:

1. If `now >= joinDeadline`: close (below). Countdown markers passed in the
   same tick are not posted.
2. Else let `secondsLeft = joinDeadline - now`. Among the markers in
   `Rules.COUNTDOWN` that are `>= secondsLeft` and not in `countdownSent`,
   mark all of them sent and return one `countdown` event for the smallest,
   with `secondsLeft` equal to that marker and `names` a copy of `joined`.
   Nothing passed: `{}`.

Close:

- Fewer than `Rules.MIN_PLAYERS` in `joined`: `phase = "cancelled"`,
  `cancelReason = "tooFew"`, `endedAt = now`, return
  `{ {type="cancelled", reason="tooFew"} }`.
- Otherwise copy `joined` into `order` and shuffle with Fisher-Yates:
  `for i = #order, 2, -1 do local j = rng(i); swap order[i], order[j] end`.
  Set every status to `"in"`, `phase = "rolling"`, `turn = 1`,
  `range = startRoll`, then call (below). Return
  `{ closed{joined}, order{order}, call{name, range} }`.

Call (internal): `turnDeadline = now + turnTimer`, `remindersSent = {}`,
produce `{ type="call", name=order[turn], range=range }`.

In phase `rolling`:

1. If `now >= turnDeadline`: forfeit the current player (below). Reminder
   markers passed in the same tick are not posted.
2. Else let `secondsLeft = turnDeadline - now`. Same marker logic as the
   countdown with `Rules.REMINDERS` and `remindersSent`, returning one
   `reminder{name, secondsLeft, range}`.

### `Rules.Roll(game, name, roll, min, max, now)`

Phase `rolling` only, else `{}`. `name` must equal `order[turn]`, else `{}`.
If `min ~= 1 or max ~= range`: return `{ wrongRange{name, range} }`, nothing
changes. Otherwise append `{ name = name, roll = roll, max = max }` to `rolls` (keyed
fields, as in contracts section 4) and:

- `roll > 1`: `range = roll`, advance `turn` to the next `"in"` player
  (wrapping), call. Return `{ call }`.
- `roll == 1`: eliminate (below) with status `"out"` and event `out`.

### Eliminate (internal)

Set `status[name]` to `"out"` or `"forfeit"`, append `name` to `eliminated`,
let `left` be the count of `"in"` players, and produce the `out` or `forfeit`
event with `left`.

- If `left == 1`: `phase = "finished"`, `winner` is the remaining player,
  `endedAt = now`. Return `{ out|forfeit, winner{name, losers=eliminated, wager, total=wager*#eliminated} }`.
- Else: for `out`, `range = startRoll`; for `forfeit`, `range` unchanged.
  Advance `turn` to the next `"in"` player after the eliminated one's
  position, wrapping, and call. Return `{ out|forfeit, call }`.

### `Rules.Cancel(game, now)`

Phase `lobby` or `rolling`: `phase = "cancelled"`, `cancelReason = "host"`,
`endedAt = now`, return `{ {type="cancelled", reason="host"} }`. Else `{}`.

### Queries

`Current(game)` returns `order[turn], range` in phase `rolling`, else `nil`.
`Alive(game)` returns the `"in"` names in `order` order. `IsLive(game)` is
true in `lobby` and `rolling`.

### Edge cases

- Two players, one rolls 1 on the first roll: `out` then `winner`.
- A valid roll of exactly `range` (for example `/roll 734` gives 734) is
  valid and sets `range = 734` again.
- `rng` is only ever called during close. With `rng = function(n) return n end`
  the order equals the join order.
- `Tick` called with a `now` earlier than the previous one is not supported;
  the host only moves forward.

## Exact user-facing text

None. The engine produces events only.

## Interfaces

Implements [contracts.md section 5.3](../contracts.md#53-nsrules). Uses
nothing.

## Files

Creates `src/Rules.lua` and `spec/Rules_spec.lua`.

## Acceptance criteria

### Automated (busted)

Fixtures: `opts = { host="Alice", channel="GUILD", wager=10000,
startRoll=1000, joinWord="1", joinTime=60, turnTimer=45 }`, `t0 = 1000`,
`rngSame = function(n) return n end`, `rngOne = function() return 1 end`.
"A 3-player game" means `New(opts, t0)`, joins Alice, Bob, Carl, then
`Tick(game, t0 + 60, rngSame)` so the order is Alice, Bob, Carl.

| ID | Steps | Expected |
|----|-------|----------|
| AC-03-01 | `New(opts, t0)` | phase `lobby`, `joinDeadline == 1060`, `id == "Alice-1000"`, events `{kickoff}` |
| AC-03-02 | `New` with `wager` missing | raises |
| AC-03-03 | `Join` Bob, then Bob again | first `{joined Bob}`, second `{}`, `joined == {"Bob"}` |
| AC-03-04 | `Join` during rolling | `{}` |
| AC-03-05 | `Tick(t0 + 10)` | `{}` |
| AC-03-06 | Join Bob; `Tick(t0 + 30)` | `{countdown secondsLeft=30 names={"Bob"}}`; `Tick(t0 + 30)` again gives `{}` |
| AC-03-07 | `Tick(t0 + 31)` then `Tick(t0 + 46)` | first `{countdown 30}`, second `{countdown 15}` |
| AC-03-08 | `Tick(t0 + 46)` with nothing sent before | one event, `countdown 15`; `countdownSent[30]` and `[15]` both true |
| AC-03-09 | `Tick(t0 + 55)`, `Tick(t0 + 59)` | `{countdown 5}`, `{}` |
| AC-03-10 | Join Bob only; `Tick(t0 + 60)` | `{cancelled tooFew}`, phase `cancelled` |
| AC-03-11 | Nobody joined; `Tick(t0 + 60)` | `{cancelled tooFew}` |
| AC-03-12 | Join Alice, Bob, Carl; `Tick(t0 + 60, rngSame)` | `{closed joined={A,B,C}, order order={A,B,C}, call name=Alice range=1000}`; phase `rolling`; `turnDeadline == 1105` |
| AC-03-13 | Same with `rngOne` | `order == {"Bob","Carl","Alice"}`, call Bob |
| AC-03-14 | Join Alice, Bob; `Tick(t0 + 60)`: countdown 5 not sent before | only close events, no countdown |
| AC-03-15 | 3-player game; `Roll(Bob, 500, 1, 1000)` | `{}` (not Bob's turn) |
| AC-03-16 | `Roll(Alice, 500, 1, 900)` and `Roll(Alice, 3, 5, 1000)` | each `{wrongRange Alice 1000}`, `range == 1000`, `rolls` empty |
| AC-03-17 | `Roll(Alice, 734, 1, 1000, t)` | `{call Bob 734}`, `range == 734`, `rolls == {{name="Alice", roll=734, max=1000}}`, `turnDeadline == t + 45`, `remindersSent == {}` |
| AC-03-18 | Then `Roll(Bob, 734, 1, 734)` | `{call Carl 734}` |
| AC-03-19 | Then `Roll(Carl, 2, 1, 734)`, then `Roll(Alice, 2, 1, 2)` | `{call Alice 2}`, `{call Bob 2}` (wraps) |
| AC-03-20 | 3-player game; `Roll(Alice, 1, 1, 1000)` | `{out Alice left=2, call Bob 1000}`, `status.Alice == "out"`, `eliminated == {"Alice"}` |
| AC-03-21 | Then `Roll(Bob, 600, 1, 1000)`, `Roll(Carl, 1, 1, 600)` | second gives `{out Carl left=1, winner name=Bob losers={Alice,Carl} wager=10000 total=20000}`, phase `finished` |
| AC-03-22 | After finish: `Roll`, `Tick`, `Cancel`, `Join` | each `{}` |
| AC-03-23 | 3-player game closed at `t`; `Tick(t + 25)`, `Tick(t + 25)`, `Tick(t + 35)`, `Tick(t + 40)` | `{reminder Alice 20 range=1000}`, `{}`, `{reminder 10}`, `{reminder 5}` |
| AC-03-24 | `Tick(t + 45)` | `{forfeit Alice left=2, call Bob 1000}`, `status.Alice == "forfeit"`, `turnDeadline == t + 90` |
| AC-03-25 | Alice rolls 734 at `t`; `Tick(t + 45)` | `{forfeit Bob left=2, call Carl 734}` (range carries over) |
| AC-03-26 | `Tick(t + 45)` with no reminders sent | forfeit events only, no reminder |
| AC-03-27 | 2-player game; `Tick(t + 45)` | `{forfeit, winner}` |
| AC-03-28 | `Cancel` in lobby; `Cancel` in rolling | each `{cancelled host}`, phase `cancelled` |
| AC-03-29 | `Current`, `Alive`, `IsLive` in lobby, rolling after an out, finished | `nil`/`{}`/`true`; `"Bob", 1000`/`{Bob,Carl}`/`true`; `nil`/`{Bob}`/`false` |
| AC-03-30 | Full scripted game: 4 players with `rngOne`, a fixed list of rolls including wrong-range, out-of-turn, one 1 and one forfeit | the exact event sequence, written out in the spec |

### In-game (manual)

None directly. 05-host-controller's checks exercise the engine end to end.

## Mockup references

None in v1.

## Open questions

None.
