# 04 Announcements: the exact chat text

Status: v1 implemented. Last verified against code: 2026-11-05. Owns `src/Chat.lua`, `spec/Chat_spec.lua`.

## Purpose and scope

Turn each event from the rules engine into the exact lines the host's addon
posts in chat. This document is the single source of that text. Pure Lua, no
WoW API.

Out of scope: local messages the host alone sees (05), posting (05).

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) sections 5.4 and 6; 01-money for
`Money.Format`; 03-rules-engine for event shapes.
Blocks: 05-host-controller.

`[P0-DISTANCE]`: answered 2026-11-05. Far-away guild members' rolls are not
seen unless grouped, so the kickoff line includes the sentence in the table
marked optional. It is always on in v1.

## Behaviour

`Chat.Render(event, game)` returns a list of prefixed lines for one event. One
line per event in v1; the list exists so a later version can return more.
Unknown event types return `{}`. `joined` returns `{}`.

Names lists are joined with `", "`. Money uses `Money.Format`. Seconds are
plain integers. "left" counts and "players" counts are plain integers.

## Exact user-facing text

Every line starts with `[DeathRoll] `. Examples use wager 1g, first roll 1000.

| Event | Line |
|-------|------|
| `kickoff` | `Death roll starting! 1g per person, first roll 1-1000. Type 1 here to join. 60 seconds! (45s per turn) Stay near the host so your rolls are seen.` |
| `kickoff`, last sentence `[P0-DISTANCE]` | `Stay near the host so your rolls are seen.` is always part of the kickoff line in v1 (Phase 0 showed far-away ungrouped rolls are not seen) |
| `countdown` | `30 seconds left to join! 4 in: Alice, Bob, Carl, Dan` |
| `countdown`, nobody yet | `30 seconds left to join! 0 in` |
| `closed` | `Joining closed! 5 players in: Alice, Bob, Carl, Dan, Eve` |
| `order` | `Roll order: Carl, Eve, Alice, Dan, Bob` |
| `call` | `Carl, you're up! Type /roll 1000` |
| `wrongRange` | `Carl, wrong range. Type /roll 1000` |
| `reminder` | `Carl, 10 seconds! Type /roll 1000` |
| `forfeit` | `Carl did not roll in time and is OUT. 4 left.` |
| `out` | `Carl rolled 1 and is OUT! 4 left. Range resets.` |
| `out`, one left | `Carl rolled 1 and is OUT! 1 left.` |
| `winner` | `WINNER: Eve! Alice, Bob, Carl, Dan each owe Eve 1g (4g total).` |
| `winner`, one loser | `WINNER: Eve! Alice owes Eve 1g.` |
| `cancelled`, reason `host` | `Game cancelled by the host.` |
| `cancelled`, reason `tooFew` | `Not enough players (need 2). Game cancelled.` |

The kickoff line reads `game.wager`, `game.startRoll`, `game.joinWord`,
`game.joinTime`, `game.turnTimer`. The `winner` line uses `event.losers` in
elimination order, `event.wager` and `event.total`; with exactly one loser it
uses the singular form and no total. `out` says "Range resets." when more
than one player is left; with one left the game is over, so the sentence is
dropped and the winner line follows. The "need 2" number is
`Rules.MIN_PLAYERS`.

## Interfaces

Implements [contracts.md section 5.4](../contracts.md#54-nschat). Uses
`ns.Money.Format` and `ns.Rules.MIN_PLAYERS`.

## Files

Edits `src/Chat.lua` (keeps `PREFIX` and `Prefix` as they are) and
`spec/Chat_spec.lua` (keeps the existing tests). The spec loads
`src/Money.lua` and `src/Rules.lua` into the same `ns` first.

## Acceptance criteria

### Automated (busted)

Fixture `game` as in 03's fixtures: wager 10000, startRoll 1000, joinWord "1",
joinTime 60, turnTimer 45.

| ID | Event | Expected single line (after the prefix) |
|----|-------|------------------------------------------|
| AC-04-01 | `kickoff` | `Death roll starting! 1g per person, first roll 1-1000. Type 1 here to join. 60 seconds! (45s per turn) Stay near the host so your rolls are seen.` |
| AC-04-02 | `kickoff` with wager 15045, startRoll 500, joinWord "roll" | `Death roll starting! 1g 50s 45c per person, first roll 1-500. Type roll here to join. 60 seconds! (45s per turn) Stay near the host so your rolls are seen.` |
| AC-04-03 | `countdown{secondsLeft=30, names={"Alice","Bob"}}` | `30 seconds left to join! 2 in: Alice, Bob` |
| AC-04-04 | `countdown{secondsLeft=5, names={}}` | `5 seconds left to join! 0 in` |
| AC-04-05 | `closed{joined={"Alice","Bob","Carl"}}` | `Joining closed! 3 players in: Alice, Bob, Carl` |
| AC-04-06 | `order{order={"Carl","Alice","Bob"}}` | `Roll order: Carl, Alice, Bob` |
| AC-04-07 | `call{name="Carl", range=734}` | `Carl, you're up! Type /roll 734` |
| AC-04-08 | `wrongRange{name="Carl", range=734}` | `Carl, wrong range. Type /roll 734` |
| AC-04-09 | `reminder{name="Carl", secondsLeft=10, range=734}` | `Carl, 10 seconds! Type /roll 734` |
| AC-04-10 | `forfeit{name="Carl", left=4}` | `Carl did not roll in time and is OUT. 4 left.` |
| AC-04-11 | `out{name="Carl", left=4}` | `Carl rolled 1 and is OUT! 4 left. Range resets.` |
| AC-04-11b | `out{name="Carl", left=1}` | `Carl rolled 1 and is OUT! 1 left.` |
| AC-04-12 | `winner{name="Eve", losers={"Alice","Bob","Carl","Dan"}, wager=10000, total=40000}` | `WINNER: Eve! Alice, Bob, Carl, Dan each owe Eve 1g (4g total).` |
| AC-04-13 | `winner{name="Eve", losers={"Alice"}, wager=5000, total=5000}` | `WINNER: Eve! Alice owes Eve 50s.` |
| AC-04-14 | `cancelled{reason="host"}` | `Game cancelled by the host.` |
| AC-04-15 | `cancelled{reason="tooFew"}` | `Not enough players (need 2). Game cancelled.` |
| AC-04-16 | `joined{name="Bob"}`, `{type="nope"}` | `{}` |
| AC-04-17 | Every line above | starts with `[DeathRoll] ` and is at most 255 characters for 5 names |
| AC-04-18 | existing `Prefix` tests | unchanged and passing |

### In-game (manual)

Read every line in guild chat during the 05 checks and confirm nothing wraps
oddly or is cut off (chat lines are limited to 255 characters; a raid of 25
long names may exceed it on the `closed` and `order` lines; note what happens).

## Mockup references

None in v1.

## Open questions

None. The `[P0-DISTANCE]` sentence was decided on 2026-11-05: always on.
