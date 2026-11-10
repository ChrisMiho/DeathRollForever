# 03 Rules engine

Status: draft v3.1 (v3 plus solo games, see 06-solo). Last verified against code: not yet. Owns `src/Rules.lua`, `spec/Rules_spec.lua`.

## Purpose and scope

The whole game as a pure state machine: a `game` table (contracts section 4)
and functions that move it from lobby to rolling to finished or cancelled.
Every function returns the list of events that happened (contracts section 6)
so the host can post them; the engine itself never produces text, never
reads a clock and never rolls anything. Pure Lua, no WoW API.

v3 is one round: everyone rolls once, the highest roll wins, the lowest
roll pays the difference. Ties for highest or lowest are settled by
tie-break rounds among the tied players only.

Out of scope: text (04), posting and timing (05), kick, extend, settings.

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) sections 3, 4, 5.3, 6.
Blocks: 04-announcements (needs the event shapes), 05-host-controller,
the visual packages (read `game`).

## Behaviour

### `Rules.New(opts, now)`

All of `host, channel, wager, rollMax, joinWord, joinTime, rollTime` are
required; a missing or wrongly typed field raises. Returns a `game` in phase
`lobby` with `id = host .. "-" .. math.floor(now)`, `createdAt = now`,
`joinDeadline = now + joinTime`, `round = 1`, empty `joined`,
`countdownSent`, `rollers`, `rolls`, `tieRolls`, `history`, `satOut`,
`remindersSent`, and `tie = nil`. The `kickoff` event is returned as a
second value: `game, events`.

**With `opts.players`** (a solo game, 06-solo): `players` is a list of at
least `Rules.MIN_PLAYERS` names, all different, each a non-empty string;
anything else raises. The game skips the lobby: `joined = copy(players)`,
`phase = "rolling"`, `rollers = copy(players)`, then start the round
(below, `round = 1`) and return `game, { call{names = copy(rollers), max =
rollMax, seconds = rollTime} }`. No `kickoff`, no `joined`, no `closed`.
`joinWord` and `joinTime` are still required and kept on the game, but
nothing reads them: `joinDeadline` is `now + joinTime` and the lobby never
runs. From here on the game is an ordinary game in phase `rolling`.

### `Rules.Join(game, name, now)`

Phase `lobby` only. A name already in `joined` returns `{}`. Otherwise appends
and returns `{ {type="joined", name=name} }`.

### `Rules.Tick(game, now)`

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
- Otherwise `phase = "rolling"`, `rollers = copy(joined)`, `tie = nil`,
  then start the round (below) and return `{ closed{joined}, call{names,
  max, seconds} }`.

Start a round (internal): `rollDeadline = now + rollTime`,
`remindersSent = {}`, `tieRolls = {}`. The first round keeps `round = 1`;
every later start does `round = round + 1`. The caller produces the event:
`call{names = copy(rollers), max = rollMax, seconds = rollTime}` for a main
round, `tieBreak{high, low, max = rollMax, seconds = rollTime}` for a
tie-break.

In phase `rolling`:

1. If `now >= rollDeadline`: settle the round (below). Reminder markers
   passed in the same tick are not posted.
2. Else let `secondsLeft = rollDeadline - now`. Same marker logic as the
   countdown with `Rules.REMINDERS` and `remindersSent`, returning one
   `reminder{names = Waiting(game), secondsLeft, max = rollMax}`.

### `Rules.Roll(game, name, roll, min, max, now)`

Phase `rolling` only, else `{}`. `name` must be in `rollers` and must not
have rolled this round (no `rolls[name]` in a main round, no
`tieRolls[name]` in a tie-break), else `{}`: a second `/roll` from the same
player is ignored, the first one stands.

If `min ~= 1 or max ~= rollMax`: return `{ wrongRange{name, max = rollMax}
}`, nothing changes. Otherwise record the roll in `rolls` (main round) or
`tieRolls` (tie-break), append `{ name, roll, max, round }` to `history`,
and return `{ rolled{name, roll, waiting = #Waiting(game)} }`. When
`waiting` is 0 the round settles at once and its events follow `rolled` in
the same list.

### Settle (internal)

Runs when every roller has rolled or the deadline passed.

**Main round** (`tie == nil`):

1. `missing` = rollers with no `rolls` entry, in join order. Append them to
   `satOut`. If `missing` is not empty, produce `satOut{names = missing}`
   first.
2. `pool` = rollers with a `rolls` entry, in join order. If `#pool <
   MIN_PLAYERS`: `phase = "cancelled"`, `cancelReason = "tooFew"`,
   `endedAt = now`, add `cancelled{reason = "tooFew"}` and stop.
3. `high` = the largest roll in `pool`, `low` = the smallest. If `high ==
   low`: every roll was the same. Clear `rolls`, set `rollers = pool`, start
   a new main round, and add `allTied{roll = high, names = pool}` then
   `call{...}`.
4. Otherwise set `game.high`, `game.low`. `highs` = pool names with roll
   `high`, `lows` = those with roll `low`, both in join order. If `#highs
   == 1`, `winner = highs[1]`; if `#lows == 1`, `loser = lows[1]`. Then
   decide (below) with `tieHigh = highs` when `#highs > 1` else nil, and
   `tieLow = lows` when `#lows > 1` else nil.

**Tie-break round** (`tie ~= nil`):

1. High side, when `tie.high` is set: `rolled` = names in `tie.high` with a
   `tieRolls` entry. If none: cancel for no rolls (below) and stop. Else
   `best` = their largest tie roll and `top` = those with it. If `#top ==
   1`, `winner = top[1]` and `tieHigh = nil`; else `tieHigh = top`. A tied
   player who did not roll drops out of the running.
2. Low side, when `tie.low` is set: `noShows` = names in `tie.low` without
   a `tieRolls` entry, `rolled` = the rest. If `rolled` is empty: cancel for
   no rolls and stop. If `#noShows == 1`, `loser = noShows[1]` (not rolling
   is the worse outcome) and `tieLow = nil`. If `#noShows > 1`, `tieLow =
   noShows`: they roll off against each other. Otherwise `worst` = the
   smallest tie roll and `bottom` = those with it; if `#bottom == 1`,
   `loser = bottom[1]` and `tieLow = nil`, else `tieLow = bottom`.
3. Decide (below).

Cancel for no rolls: `phase = "cancelled"`, `cancelReason = "noRolls"`,
`endedAt = now`, event `cancelled{reason = "noRolls"}`.

**Decide** (internal), with `tieHigh` and `tieLow` each a list or nil:

- Both `winner` and `loser` set: `phase = "finished"`, `endedAt = now`,
  `owed = Rules.Owed(high, low, wager, rollMax)`, `tie = nil`,
  `rollers = {}`. Event `winner{name = winner, loser, high, low, owed}`.
- Otherwise `tie = { high = tieHigh, low = tieLow }`, `rollers = tieHigh
  followed by tieLow` (each in join order), start a round, event
  `tieBreak{high = tieHigh, low = tieLow, max = rollMax, seconds =
  rollTime}`.

`high` and `low` never change once set: a tie-break decides who among the
tied wins or pays, never how much.

### `Rules.Cancel(game, now)`

Phase `lobby` or `rolling`: `phase = "cancelled"`, `cancelReason = "host"`,
`endedAt = now`, return `{ {type="cancelled", reason="host"} }`. Else `{}`.

### Queries

`Waiting(game)` returns, in `rollers` order, the names that have not rolled
this round; `{}` outside phase `rolling`. `Owed(high, low, wager, rollMax)`
returns `math.floor((high - low) * wager / rollMax)`. `IsLive(game)` is true
in `lobby` and `rolling`.

### Edge cases

- Two players, one does not roll: `satOut` then `cancelled tooFew`.
- A single roll in a main round (everyone else sat out): `tooFew` as well;
  one roll decides nothing.
- `Owed` with the lowest and highest equal is 0; it never happens in a
  finished game because an all-equal round is rerun.
- Rounding: 1g wager, rollMax 100, rolls 97 and 8 owe 8900c, which
  `Money.Format` shows as `89s`. 1g wager, rollMax 1000, rolls 5 and 2 owe
  `math.floor(3 * 10000 / 1000) = 30c`.
- `Tick` called with a `now` earlier than the previous one is not supported;
  the host only moves forward.
- A roll that arrives after the deadline settled the round is a roll in the
  next round if that player is a roller there, else ignored.

## Exact user-facing text

None. The engine produces events only.

## Interfaces

Implements [contracts.md section 5.3](../contracts.md#53-nsrules). Uses
nothing.

## Files

Rewrites `src/Rules.lua` and `spec/Rules_spec.lua`.

## Acceptance criteria

### Automated (busted)

Fixtures: `opts = { host="Alice", channel="GUILD", wager=1000000,
rollMax=100, joinWord="1", joinTime=60, rollTime=45 }`, `t0 = 1000`.
"A 3-player game" means `New(opts, t0)`, joins Alice, Bob, Carl in that
order, then `Tick(game, t0 + 60)`; `t = t0 + 60` is the close time. `R(name,
roll, at)` is shorthand for `Roll(game, name, roll, 1, 100, at)`.

| ID | Steps | Expected |
|----|-------|----------|
| AC-03-01 | `New(opts, t0)` | phase `lobby`, `joinDeadline == 1060`, `id == "Alice-1000"`, `round == 1`, `tie == nil`, empty `rollers`, `rolls`, `tieRolls`, `history`, `satOut`, events `{kickoff}` |
| AC-03-02 | `New` with `rollMax` missing; with `rollTime` a string | each raises |
| AC-03-03 | `Join` Bob, then Bob again | first `{joined Bob}`, second `{}`, `joined == {"Bob"}` |
| AC-03-04 | `Join` during rolling | `{}` |
| AC-03-05 | `Tick(t0 + 10)` | `{}` |
| AC-03-06 | Join Bob; `Tick(t0 + 30)` | `{countdown secondsLeft=30 names={"Bob"}}`; `Tick(t0 + 30)` again gives `{}` |
| AC-03-07 | `Tick(t0 + 31)` then `Tick(t0 + 46)` | first `{countdown 30}`, second `{countdown 15}` |
| AC-03-08 | `Tick(t0 + 46)` with nothing sent before | one event, `countdown 15`; `countdownSent[30]` and `[15]` both true |
| AC-03-09 | `Tick(t0 + 55)`, `Tick(t0 + 59)` | `{countdown 5}`, `{}` |
| AC-03-10 | Join Bob only; `Tick(t0 + 60)` | `{cancelled tooFew}`, phase `cancelled` |
| AC-03-11 | Nobody joined; `Tick(t0 + 60)` | `{cancelled tooFew}` |
| AC-03-12 | Join Alice, Bob, Carl; `Tick(t0 + 60)` | `{closed joined={A,B,C}, call names={A,B,C} max=100 seconds=45}`; phase `rolling`; `rollers == {A,B,C}`; `rollDeadline == 1105`; `round == 1` |
| AC-03-13 | Join Alice, Bob; `Tick(t0 + 60)`: countdown 5 not sent before | only close events, no countdown |
| AC-03-14 | 3-player game; `Roll(game, "Dan", 50, 1, 100, t)` | `{}` (not a roller) |
| AC-03-15 | `Roll(Alice, 50, 1, 90, t)` and `Roll(Alice, 3, 5, 100, t)` | each `{wrongRange Alice max=100}`, `rolls` and `history` empty |
| AC-03-16 | `R(Alice, 97, t+1)` | `{rolled Alice 97 waiting=2}`, `rolls.Alice == 97`, `history == {{name="Alice", roll=97, max=100, round=1}}` |
| AC-03-17 | then `R(Alice, 40, t+2)` | `{}`; `rolls.Alice` still 97; `history` has one entry |
| AC-03-18 | `Waiting(game)` after Alice rolled | `{"Bob", "Carl"}`; in the lobby `{}` |
| AC-03-19 | then `R(Bob, 61, t+3)`, `R(Carl, 8, t+4)` | second gives `{rolled Carl 8 waiting=0, winner name=Alice loser=Carl high=97 low=8 owed=890000}`; phase `finished`; `game.owed == 890000`; `satOut == {}` |
| AC-03-20 | After finish: `Roll`, `Tick`, `Cancel`, `Join` | each `{}` |
| AC-03-21 | 3-player game; `Tick(t + 25)`, `Tick(t + 25)`, `Tick(t + 35)`, `Tick(t + 40)` | `{reminder names={A,B,C} secondsLeft=20 max=100}`, `{}`, `{reminder 10}`, `{reminder 5}` |
| AC-03-22 | `R(Alice, 97, t+1)`; `Tick(t + 35)` | `{reminder names={B,C} 10}` |
| AC-03-23 | `R(Alice, 97)`, `R(Bob, 61)`; `Tick(t + 45)` | `{satOut names={"Carl"}, winner Alice loser=Bob high=97 low=61 owed=360000}`; `satOut == {"Carl"}` |
| AC-03-24 | `R(Alice, 97)` only; `Tick(t + 45)` | `{satOut names={B,C}, cancelled tooFew}`; phase `cancelled` |
| AC-03-25 | nobody rolls; `Tick(t + 45)` | `{satOut names={A,B,C}, cancelled tooFew}` |
| AC-03-26 | `Tick(t + 45)` with no reminders sent | no reminder in the list |
| AC-03-27 | `R(Alice, 50)`, `R(Bob, 50)`, `R(Carl, 50)` at `t+3` | last gives `{rolled, allTied roll=50 names={A,B,C}, call names={A,B,C} max=100 seconds=45}`; `round == 2`; `rolls == {}`; `rollDeadline == t + 48`; `tie == nil` |
| AC-03-28 | then `R(Alice, 10)`, `R(Bob, 20)`, `R(Carl, 30)` | finishes: winner Carl, loser Alice, high 30, low 10, owed 200000 |
| AC-03-29 | 4-player game (Alice, Bob, Carl, Dan); `R(Alice, 97)`, `R(Bob, 61)`, `R(Carl, 8)`, `R(Dan, 97)` | last gives `{rolled, tieBreak high={"Alice","Dan"} low=nil max=100 seconds=45}`; `winner == nil`, `loser == "Carl"`, `high == 97`, `low == 8`; `rollers == {"Alice","Dan"}`; `round == 2`; `tie.high == {"Alice","Dan"}` |
| AC-03-30 | then `R(Bob, 50)` | `{}` (not a roller this round) |
| AC-03-31 | then `R(Alice, 30)`, `R(Dan, 70)` | last gives `{rolled Dan 70 waiting=0, winner name=Dan loser=Carl high=97 low=8 owed=890000}`; `tieRolls.Dan == 70`; `history[6].round == 2` |
| AC-03-32 | 4-player game; rolls Alice 97, Bob 8, Carl 8, Dan 61; then `R(Bob, 40)`, `R(Carl, 20)` | tie-break `low={"Bob","Carl"} high=nil`, winner Alice set at once; after the tie rolls `winner name=Alice loser=Carl owed=890000` |
| AC-03-33 | 4-player game; rolls 97, 97, 8, 8 (Alice, Bob, Carl, Dan) | `tieBreak high={A,B} low={C,D}`; `rollers == {A,B,C,D}`; then tie rolls Alice 10, Bob 20, Carl 30, Dan 5 give `winner name=Bob loser=Dan` |
| AC-03-34 | high tie Alice, Dan (as AC-03-29); `R(Alice, 30)`; `Tick(t + 90)` | `{winner name=Alice ...}` (Dan did not roll and drops out) |
| AC-03-35 | high tie; nobody rolls; `Tick(t + 90)` | `{cancelled noRolls}`, phase `cancelled`, `cancelReason == "noRolls"` |
| AC-03-36 | low tie Bob, Carl (as AC-03-32); `R(Bob, 40)`; `Tick` past the deadline | `{winner name=Alice loser=Carl}` (the no-show pays) |
| AC-03-37 | 5-player low tie Bob, Carl, Dan; only Bob rolls; deadline | `{tieBreak high=nil low={"Carl","Dan"}}`, `round == 3` |
| AC-03-38 | high tie Alice, Dan; both tie-roll 50 | `{rolled, tieBreak high={"Alice","Dan"} low=nil}`, `round == 3`, `tieRolls == {}` |
| AC-03-39 | tie-break with both sides; the high side resolves on the deadline and the low side has two no-shows | `{tieBreak high=nil low={the two}}` and `winner` set |
| AC-03-40 | `Owed(97, 8, 1000000, 100)`, `Owed(90, 80, 1000000, 100)`, `Owed(5, 2, 10000, 1000)`, `Owed(50, 50, 10000, 100)` | `890000`, `100000`, `30`, `0` |
| AC-03-41 | `Cancel` in lobby; `Cancel` in rolling; `Cancel` during a tie-break | each `{cancelled host}`, phase `cancelled` |
| AC-03-42 | `IsLive` in lobby, rolling, finished, cancelled | `true`, `true`, `false`, `false` |
| AC-03-44 | `New(opts with players={"Alice","Bob","Carl"}, rollTime=15, t0)` | phase `rolling`, `joined` and `rollers` `{"Alice","Bob","Carl"}`, `round == 1`, `rollDeadline == t0 + 15`, events `{ call{names={"Alice","Bob","Carl"}, max=100, seconds=15} }` |
| AC-03-45 | `New` with `players={"Alice"}`, `{}`, `{"Alice","Alice"}`, `{"Alice", ""}`, `"Alice"` | each raises |
| AC-03-46 | solo game of AC-03-44; `R(Bob, 90)`, `R(Carl, 10)`, then `Tick(t0 + 15)` | `{satOut{"Alice"}, winner{name=Bob, loser=Carl, high=90, low=10, owed=800000}}` |
| AC-03-47 | solo game of AC-03-44; `Join(game, "Dan", t0)` | `{}`, `joined` unchanged |
| AC-03-43 | Full scripted game: 5 players, a wrong range, a roll from a non-player, a second roll from the same player, one sat out, a high tie settled by a tie-break in which one of the tied does not roll | the exact event sequence, written out in the spec |

### In-game (manual)

None directly. 05-host-controller's checks exercise the engine end to end.

## Mockup references

None.

## Open questions

None.
