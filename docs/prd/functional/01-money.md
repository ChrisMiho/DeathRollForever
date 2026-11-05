# 01 Money: parsing and formatting wagers

Status: draft v1. Owns `src/Money.lua`, `spec/Money_spec.lua`.

## Purpose and scope

Turn what the host types as a wager into an integer number of copper, and
turn copper back into the plain text that chat lines show. Pure Lua, no WoW
API.

Out of scope: coin icons for a window (v2), totals for a ledger beyond simple
multiplication (v4).

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) section 5.1 only.
Blocks: 02-chat-parsing (`Parse.StartArgs` calls `Money.Parse`),
04-announcements (`Chat.Render` calls `Money.Format`).

## Behaviour

### `Money.Parse(text)`

1. If `text` is not a string, treat it as `""`.
2. Trim spaces at both ends, lower-case.
3. Try the forms below in order. The first that matches wins.
   - **Plain gold:** `^(%d+)$` or `^(%d+)%.(%d%d?)$`. Gold, with up to two
     decimals meaning silver (`1.5` = 1g 50s, `1.05` = 1g 5s). Three or more
     decimals is rejected.
   - **Decimal gold with suffix:** `^(%d+)%.(%d%d?)g$`. Same meaning. Only
     valid when it is the whole entry.
   - **Suffixed parts:** one or more of `<digits>g`, `<digits>s`, `<digits>c`,
     in any order, separated by zero or more spaces, nothing else between or
     around them. Each suffix at most once. Silver and copper may exceed 99
     and are normalised (`150s` = 1g 50s).
4. Anything else returns `nil, Money.ERROR`.
5. The result must be within `Money.MIN .. Money.MAX` (1c to 999,999g 99s
   99c), otherwise `nil, Money.ERROR`.

### `Money.Format(copper)`

Non-integer or negative input raises an error (programmer mistake). Zero gives
`"0c"`. Otherwise the non-zero parts in order gold, silver, copper, separated
by one space: `1g`, `50s`, `1g 50s 45c`, `1g 45c`. No thousands separators.

### `Money.Split(copper)`

Returns gold, silver, copper as three integers.

## Exact user-facing text

| Where | Text |
|-------|------|
| `Money.ERROR` | `Enter an amount like 5, 1g 50s or 1.5g` |

## Interfaces

Implements [contracts.md section 5.1](../contracts.md#51-nsmoney). Uses
nothing.

## Files

Creates `src/Money.lua` and `spec/Money_spec.lua`. Adds nothing to
`.luacheckrc`.

## Acceptance criteria

### Automated (busted)

| ID | Input | Expected |
|----|-------|----------|
| AC-01-01 | `Parse("5")` | `50000` |
| AC-01-02 | `Parse("1.5")` | `15000` |
| AC-01-03 | `Parse("1.05")` | `10500` |
| AC-01-04 | `Parse("1.5g")` | `15000` |
| AC-01-05 | `Parse("1g")` | `10000` |
| AC-01-06 | `Parse("50s")` | `5000` |
| AC-01-07 | `Parse("1g50s")` | `15000` |
| AC-01-08 | `Parse("1g 50s 45c")` | `15045` |
| AC-01-09 | `Parse("45c 1g")` | `10045` (any order) |
| AC-01-10 | `Parse("  2G ")` | `20000` (trimmed, case ignored) |
| AC-01-11 | `Parse("150s")` | `15000` (normalised) |
| AC-01-12 | `Parse("1.555")` | `nil, Money.ERROR` |
| AC-01-13 | `Parse("1.5s")` | `nil, Money.ERROR` |
| AC-01-14 | `Parse("1.5g 20s")` | `nil, Money.ERROR` |
| AC-01-15 | `Parse("1g 1g")` | `nil, Money.ERROR` |
| AC-01-16 | `Parse("0")`, `Parse("0c")` | `nil, Money.ERROR` |
| AC-01-17 | `Parse("")`, `Parse(nil)`, `Parse("abc")`, `Parse("1g abc")` | `nil, Money.ERROR` |
| AC-01-18 | `Parse("1000000g")` | `nil, Money.ERROR` (over MAX) |
| AC-01-19 | `Parse("999999g 99s 99c")` | `9999999999` |
| AC-01-20 | `Format(10000)` | `"1g"` |
| AC-01-21 | `Format(5000)` | `"50s"` |
| AC-01-22 | `Format(15045)` | `"1g 50s 45c"` |
| AC-01-23 | `Format(10045)` | `"1g 45c"` |
| AC-01-24 | `Format(0)` | `"0c"` |
| AC-01-25 | `Format(40000)` | `"4g"` |
| AC-01-26 | `Format(1.5)`, `Format(-1)`, `Format("1")` | raises |
| AC-01-27 | `Split(15045)` | `1, 50, 45` |
| AC-01-28 | `Parse(Format(n)) == n` for n in `{1, 99, 100, 10000, 15045, 9999999999}` | true |

### In-game (manual)

None. Everything here is pure; 05-host-controller's checks cover the
end-to-end path.

## Mockup references

None in v1.

## Open questions

None.
