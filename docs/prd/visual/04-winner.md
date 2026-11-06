# 04 Winner: the result until Reset

Status: v2 implemented. Last verified against code: 2026-11-06 (in-game by the host). Owns the `winner` section of `src/UI.lua` and `src/View.lua` (`View.Result`) and its tests in `spec/View_spec.lua`. Package 09.

## Purpose and scope

The window after a game finishes: the winner and who owes what, kept on
screen until the host clicks Reset, which returns to the form.

Out of scope: paid marks, the ledger surviving a `/reload`, the host's record
against the winner, `/dr owed` (v4).

## Depends on / blocks

Depends on: 01-window merged; [contracts.md](../contracts.md) section 4
(`game.winner`, `game.order`, `game.wager`), 5.6, 5.7;
[visual.md](../visual.md) section 4.
Blocks: nothing.

## Behaviour

### Pure: `View.Result(game, host)`

| Field | Value |
|-------|-------|
| `subtitle` | `View.Subtitle(game)` |
| `winner` | `game.winner` |
| `rows` | one per name in `game.order` that is not the winner, in that order: `{ text = "<name> owes <winner>", you = (name == host), amount = Money.Format(game.wager) }` |
| `total` | `Money.Format(game.wager * #rows)` |

Raises if `game.phase ~= "finished"`.

### The view (`build.winner`, `draw.winner`)

Top to bottom, 10 px gaps:

1. Subtitle, muted.
2. `WINNER` in muted, small, letter-spaced is not available so plain
   upper case; under it the winner's name in `GameFontNormalHuge`, tint
   text.
3. The list box, filling the room down to the main button: one row per
   debt, `text` at the left with `(you)` in muted after it when `you`,
   `amount` right-aligned in text colour. Then a last row `Total` in muted
   with `total` at the right, separated from the debts by a 1 px line in
   the border colour.

The main button reads `Reset`; 01 handles the click (forget the game,
redraw to the form). The corner shows the X; the window may be hidden here.

Host drops a finished game right after reporting it; `UI.lua` keeps its own
reference (01), so this view draws from that.

## Exact user-facing text

| Where | Text |
|-------|------|
| label | `WINNER` |
| debt row | `Bob owes Alice`, with `(you)` after it for the host |
| total row | `Total` |
| main button | `Reset` |

## Interfaces

Implements `View.Result` (contracts 5.6). Uses `Money.Format`,
`View.Subtitle`, the list box helper from 01.

## Files

Edits `src/UI.lua` (fills `build.winner`, `draw.winner`), `src/View.lua`
(adds `Result`), `spec/View_spec.lua`. One line in `CHANGELOG.md`.

## Acceptance criteria

### Automated (busted)

Fixture: `finished` is a game with `phase = "finished"`, `channel = "RAID"`,
`wager = 10000`, `startRoll = 1000`, `order = { "Alice", "Bob", "Carl",
"Dan", "Eve" }`, `winner = "Alice"`, host `Eve`.

| ID | Input | Expected |
|----|-------|----------|
| AC-09-01 | `Result(finished, "Eve").winner` | `"Alice"` |
| AC-09-02 | `Result(finished, "Eve").rows` | `{ {text="Bob owes Alice",you=false,amount="1g"}, {text="Carl owes Alice",you=false,amount="1g"}, {text="Dan owes Alice",you=false,amount="1g"}, {text="Eve owes Alice",you=true,amount="1g"} }` |
| AC-09-03 | `Result(finished, "Eve").total` | `"4g"` |
| AC-09-04 | two players, winner `Bob`, wager 15045 | one row `Alice owes Bob` with amount `1g 50s 45c`, total `1g 50s 45c` |
| AC-09-05 | `Result(finished, "Alice").rows` | no row has `you = true` (the host won) |
| AC-09-06 | `Result({ phase = "rolling" }, "Eve")` | raises |
| AC-09-07 | `Result(finished, "Eve").subtitle` | `"Raid chat, 1g per person, first roll 1-1000"` |

### In-game (manual)

| ID | Do | Expect |
|----|----|--------|
| IG-09-01 | play a three-player game to the end | the window shows `WINNER`, the name in the tint, one `X owes Y  1g` row per loser, `Total  2g`, `Reset` tinted, `×` in the corner |
| IG-09-02 | compare with chat | the winner line in chat names the same people and amounts |
| IG-09-03 | click `×` | the window hides; `/dr show` brings the winner view back |
| IG-09-04 | click `Reset` | the form, with the values from before the game |
| IG-09-05 | after `Reset`, `/dr show` | the form, not the old result |
| IG-09-06 | win a game yourself | your own name as the winner, no `(you)` on any row |

## Mockup references

[../../mockups/window-v2.html](../../mockups/window-v2.html), panel 3.

## Open questions

None.
