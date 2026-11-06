# 04 Announcements: the exact chat text

Status: draft v3. Last verified against code: not yet. Owns `src/Chat.lua`, `spec/Chat_spec.lua`.

## Purpose and scope

Turn each event from the rules engine into the exact lines the host's addon
posts in chat. This document is the single source of that text. Pure Lua, no
WoW API.

Out of scope: local messages the host alone sees (05), posting (05).

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) sections 5.4 and 6; 01-money for
`Money.Format`; 03-rules-engine for event shapes.
Blocks: 05-host-controller.

`[P0-DISTANCE]`: far-away guild members' rolls are not seen unless grouped,
so the kickoff line ends with the sentence in the table. It is always on.

## Behaviour

`Chat.Render(event, game)` returns a list of prefixed lines for one event. One
line per event; the list exists so a later version can return more. Unknown
event types return `{}`. `joined` and `rolled` return `{}`: a roll is
already on screen as the system message, and the window shows the count.

Names lists are joined with `", "`. Money uses `Money.Format`. Seconds,
rolls and counts are plain integers.

## Exact user-facing text

Every line starts with `[DeathRoll] `. Examples use wager 100g, roll max
100, roll time 45.

| Event | Line |
|-------|------|
| `kickoff` | `Death roll starting! 100g per person. Everyone rolls 1-100 once: highest wins, lowest pays the difference. Type 1 here to join. 60 seconds! Stay near the host so your rolls are seen.` |
| `countdown` | `30 seconds left to join! 4 in: Alice, Bob, Carl, Dan` |
| `countdown`, nobody yet | `30 seconds left to join! 0 in` |
| `closed` | `Joining closed! 5 players in: Alice, Bob, Carl, Dan, Eve` |
| `call` | `Everyone, type /roll 100 now! 45 seconds.` |
| `wrongRange` | `Carl, wrong range. Type /roll 100` |
| `reminder` | `10 seconds! Still to roll: Carl, Dan. Type /roll 100` |
| `satOut`, one name | `Carl did not roll in time and sits out.` |
| `satOut`, several | `Carl, Dan did not roll in time and sit out.` |
| `allTied` | `Everyone rolled 50! Roll again.` (the `call` line follows) |
| `tieBreak`, high only | `Tie for highest: Alice, Eve. Tied players, type /roll 100 again! 45 seconds.` |
| `tieBreak`, low only | `Tie for lowest: Bob, Carl. Tied players, type /roll 100 again! 45 seconds.` |
| `tieBreak`, both | `Tie for highest: Alice, Eve. Tie for lowest: Bob, Carl. Tied players, type /roll 100 again! 45 seconds.` |
| `winner` | `WINNER: Alice with 97! Dan rolled 8 and owes Alice 89g.` |
| `cancelled`, reason `host` | `Game cancelled by the host.` |
| `cancelled`, reason `tooFew` | `Not enough players (need 2). Game cancelled.` |
| `cancelled`, reason `noRolls` | `Nobody rolled the tie-break. Game cancelled.` |

The kickoff line reads `game.wager`, `game.rollMax`, `game.joinWord` and
`game.joinTime`. `call` and `tieBreak` read `event.max` and
`event.seconds`. `wrongRange` and `reminder` read `event.max`. The `winner`
line uses `event.name`, `event.high`, `event.loser`, `event.low` and
`event.owed`. The "need 2" number is `Rules.MIN_PLAYERS`. The `tooFew` line
is the same whether the lobby closed with too few or a round ended with too
few rolls; the `satOut` line before it says who did not roll.

## Interfaces

Implements [contracts.md section 5.4](../contracts.md#54-nschat). Uses
`ns.Money.Format` and `ns.Rules.MIN_PLAYERS`.

## Files

Rewrites `src/Chat.lua` (keeps `PREFIX` and `Prefix` as they are) and
`spec/Chat_spec.lua` (keeps the existing `Prefix` tests). The spec loads
`src/Money.lua` and `src/Rules.lua` into the same `ns` first.

## Acceptance criteria

### Automated (busted)

Fixture `game` as in 03's fixtures: wager 1000000, rollMax 100, joinWord
"1", joinTime 60, rollTime 45.

| ID | Event | Expected single line (after the prefix) |
|----|-------|------------------------------------------|
| AC-04-01 | `kickoff` | `Death roll starting! 100g per person. Everyone rolls 1-100 once: highest wins, lowest pays the difference. Type 1 here to join. 60 seconds! Stay near the host so your rolls are seen.` |
| AC-04-02 | `kickoff` with wager 15045, rollMax 1000, joinWord "roll" | `Death roll starting! 1g 50s 45c per person. Everyone rolls 1-1000 once: highest wins, lowest pays the difference. Type roll here to join. 60 seconds! Stay near the host so your rolls are seen.` |
| AC-04-03 | `countdown{secondsLeft=30, names={"Alice","Bob"}}` | `30 seconds left to join! 2 in: Alice, Bob` |
| AC-04-04 | `countdown{secondsLeft=5, names={}}` | `5 seconds left to join! 0 in` |
| AC-04-05 | `closed{joined={"Alice","Bob","Carl"}}` | `Joining closed! 3 players in: Alice, Bob, Carl` |
| AC-04-06 | `call{names={"Alice","Bob"}, max=100, seconds=45}` | `Everyone, type /roll 100 now! 45 seconds.` |
| AC-04-07 | `wrongRange{name="Carl", max=100}` | `Carl, wrong range. Type /roll 100` |
| AC-04-08 | `reminder{names={"Carl","Dan"}, secondsLeft=10, max=100}` | `10 seconds! Still to roll: Carl, Dan. Type /roll 100` |
| AC-04-09 | `satOut{names={"Carl"}}` | `Carl did not roll in time and sits out.` |
| AC-04-10 | `satOut{names={"Carl","Dan"}}` | `Carl, Dan did not roll in time and sit out.` |
| AC-04-11 | `allTied{roll=50, names={"Alice","Bob"}}` | `Everyone rolled 50! Roll again.` |
| AC-04-12 | `tieBreak{high={"Alice","Eve"}, low=nil, max=100, seconds=45}` | `Tie for highest: Alice, Eve. Tied players, type /roll 100 again! 45 seconds.` |
| AC-04-13 | `tieBreak{high=nil, low={"Bob","Carl"}, max=100, seconds=45}` | `Tie for lowest: Bob, Carl. Tied players, type /roll 100 again! 45 seconds.` |
| AC-04-14 | `tieBreak{high={"Alice","Eve"}, low={"Bob","Carl"}, max=100, seconds=45}` | `Tie for highest: Alice, Eve. Tie for lowest: Bob, Carl. Tied players, type /roll 100 again! 45 seconds.` |
| AC-04-15 | `winner{name="Alice", loser="Dan", high=97, low=8, owed=890000}` | `WINNER: Alice with 97! Dan rolled 8 and owes Alice 89g.` |
| AC-04-16 | `winner{name="Bob", loser="Alice", high=5, low=2, owed=30}` | `WINNER: Bob with 5! Alice rolled 2 and owes Bob 30c.` |
| AC-04-17 | `cancelled{reason="host"}` | `Game cancelled by the host.` |
| AC-04-18 | `cancelled{reason="tooFew"}` | `Not enough players (need 2). Game cancelled.` |
| AC-04-19 | `cancelled{reason="noRolls"}` | `Nobody rolled the tie-break. Game cancelled.` |
| AC-04-20 | `joined{name="Bob"}`, `rolled{name="Bob", roll=5, waiting=2}`, `{type="nope"}` | `{}` |
| AC-04-21 | Every line above | starts with `[DeathRoll] ` and is at most 255 characters for 5 names |
| AC-04-22 | existing `Prefix` tests | unchanged and passing |

### In-game (manual)

Read every line in chat during the 05 checks and confirm nothing wraps
oddly or is cut off (chat lines are limited to 255 characters; a raid of 25
long names may exceed it on the `closed` and `reminder` lines; note what
happens).

## Mockup references

None.

## Open questions

None.
