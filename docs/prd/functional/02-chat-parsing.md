# 02 Chat parsing: join words, roll results, `/dr` arguments

Status: v1 implemented. Last verified against code: 2026-11-05. Owns `src/Parse.lua`, `spec/Parse_spec.lua`.

## Purpose and scope

Recognise the three kinds of text the host's addon reads: a join word in the
game's chat, a `/roll` result in the system channel, and the arguments the
host typed after `/dr`. Pure Lua, no WoW API. The glue (05) hands in strings
and gets back values or `nil, errorText`.

Out of scope: deciding what to do with the result (03, 05), realm stripping
(05 does it with `Ambiguate` before calling in).

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) section 5.2; 01-money for
`Money.Parse` inside `StartArgs`.
Blocks: 05-host-controller.

Phase 0: `[P0-ROLL]` was answered on 2026-11-05. The game shows every roll,
the host's own included, as `Name rolls 734 (1-1000)`; it never says "You".
Character names on this server can contain a space (`Natus Vincere rolls 818
(1-1000)` was seen), so `ROLL_PATTERN` captures the name as `(.-)`, everything
before the last ` rolls N (a-b)` on the line, not as a single word. The
builder uses the pattern in contracts.md and writes the tests against the
message text in orchestration.md Phase 0 results.

## Behaviour

### `Parse.JoinWord(message, joinWord)`

True when `message`, with leading and trailing spaces removed, equals
`joinWord` ignoring case. Non-string `message` is false.

### `Parse.Roll(systemMessage, pattern)`

`pattern` defaults to `Parse.ROLL_PATTERN`. Returns `name, roll, min, max`
with the three numbers as integers, or `nil` when the message does not match.
The name is returned as captured; it may contain a realm, which the caller
strips.

### `Parse.Command(text)`

Splits on runs of spaces after trimming. The first word, lower-cased, is
`name`; the rest, case kept, is `args`. Non-string or empty text gives
`{ name = "", args = {} }`. Never fails.

### `Parse.StartArgs(name, args)`

1. `name` must be a key of `Parse.CHANNELS`; otherwise `nil, Parse.USAGE`.
2. `args[1]` is required and goes through `Money.Parse`; a failure returns
   `nil, Money.ERROR`. Missing returns `nil, Parse.USAGE`.
3. `args[2]`, if present, must be an integer from 2 to 1,000,000; otherwise
   `nil, Parse.FIRST_ROLL_ERROR`. Absent gives `startRoll = nil`.
4. A third argument returns `nil, Parse.USAGE`.
5. Returns `{ channel = <"GUILD"|"PARTY"|"RAID">, wager = <copper>, startRoll = <n or nil> }`.

## Exact user-facing text

| Where | Text |
|-------|------|
| `Parse.USAGE` | `Usage: /dr g|p|r <wager> [first roll]` |
| `Parse.FIRST_ROLL_ERROR` | `First roll must be a whole number from 2 to 1000000` |
| Wager errors | `Money.ERROR` from 01-money |

## Interfaces

Implements [contracts.md section 5.2](../contracts.md#52-nsparse). Uses
`ns.Money.Parse`.

## Files

Creates `src/Parse.lua` and `spec/Parse_spec.lua`. The spec loads
`src/Money.lua` into the same `ns` before `src/Parse.lua`:
`local ns = LoadAddonFile("src/Money.lua"); LoadAddonFile("src/Parse.lua", ns)`.

## Acceptance criteria

### Automated (busted)

| ID | Input | Expected |
|----|-------|----------|
| AC-02-01 | `JoinWord("1", "1")` | `true` |
| AC-02-02 | `JoinWord("  1 ", "1")` | `true` |
| AC-02-03 | `JoinWord("ROLL", "roll")` | `true` |
| AC-02-04 | `JoinWord("1!", "1")`, `JoinWord("me 1", "1")`, `JoinWord("11", "1")` | `false` |
| AC-02-05 | `JoinWord("", "1")`, `JoinWord(nil, "1")` | `false` |
| AC-02-06 | `Roll("Alice rolls 734 (1-1000)")` | `"Alice", 734, 1, 1000` `[P0-ROLL]` |
| AC-02-07 | `Roll("Alice rolls 1 (1-1)")` | `"Alice", 1, 1, 1` |
| AC-02-08 | `Roll("Alice-Stormrage rolls 5 (1-10)")` | `"Alice-Stormrage", 5, 1, 10` |
| AC-02-08b | `Roll("Natus Vincere rolls 818 (1-1000)")` | `"Natus Vincere", 818, 1, 1000` `[P0-ROLL]` |
| AC-02-09 | `Roll("Alice has gone offline.")`, `Roll("")`, `Roll(nil)` | `nil` |
| AC-02-10 | `Roll("X wuerfelt 3 (1-9)", "^(%S+) wuerfelt (%d+) %((%d+)%-(%d+)%)$")` | `"X", 3, 1, 9` (custom pattern) |
| AC-02-11 | `Command("g 1g 500")` | `{ name="g", args={"1g","500"} }` |
| AC-02-12 | `Command("  G   1G ")` | `{ name="g", args={"1G"} }` |
| AC-02-13 | `Command("cancel")` | `{ name="cancel", args={} }` |
| AC-02-14 | `Command("")`, `Command(nil)` | `{ name="", args={} }` |
| AC-02-15 | `StartArgs("g", {"1g"})` | `{ channel="GUILD", wager=10000, startRoll=nil }` |
| AC-02-16 | `StartArgs("guild", {"1g"})`, `("p", {"50s"})`, `("party", ...)`, `("r", ...)`, `("raid", ...)` | channels `GUILD`, `PARTY`, `PARTY`, `RAID`, `RAID` |
| AC-02-17 | `StartArgs("g", {"1g", "500"})` | `startRoll = 500` |
| AC-02-18 | `StartArgs("x", {"1g"})` | `nil, Parse.USAGE` |
| AC-02-19 | `StartArgs("g", {})` | `nil, Parse.USAGE` |
| AC-02-20 | `StartArgs("g", {"abc"})` | `nil, Money.ERROR` |
| AC-02-21 | `StartArgs("g", {"1g", "1"})`, `("g", {"1g", "12.5"})`, `("g", {"1g", "abc"})`, `("g", {"1g", "1000001"})` | `nil, Parse.FIRST_ROLL_ERROR` |
| AC-02-22 | `StartArgs("g", {"1g", "500", "extra"})` | `nil, Parse.USAGE` |

### In-game (manual)

Covered by 05-host-controller once the Phase 0 roll text is known.

## Mockup references

None in v1.

## Open questions

None, once `[P0-ROLL]` is answered.
