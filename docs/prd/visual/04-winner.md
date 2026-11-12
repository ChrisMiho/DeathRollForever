# 04 Winner: the result until Reset

Status: draft v3. Last verified against code: not yet. Owns the `winner` section of `src/UI.lua` and `src/View.lua` (`View.Result`) and its tests in `spec/View_spec.lua`. Package 16.

## Purpose and scope

The window after a game finishes: the winner and their roll, the final
standings, and the debts (one per loser), kept on screen until the host clicks Reset,
which returns to the form.

Out of scope: paid marks, the ledger surviving a `/reload`, the host's record
against the winner, `/dr owed` (later).

## Depends on / blocks

Depends on: 03-in-progress (v3) merged, for the row painting by `mark`;
[contracts.md](../contracts.md) section 4 (`game.winner`, `losers`, `high`,
`low`, `owed`, `rolls`, `satOut`, `joined`), 5.6, 5.7;
[visual.md](../visual.md) section 4.
Blocks: nothing.

## Behaviour

### Pure: `View.Result(game, host)`

| Field | Value |
|-------|-------|
| `subtitle` | `View.Subtitle(game)` |
| `winner` | `Rules.FullName(game, game.winner)` |
| `winningRoll` | `game.high` as text |
| `rows` | the standings, see below |
| `debts` | one per name in `game.losers`, in that order: `{ text = "<loser> owes <winner>", you = (loser == host), amount = Money.Format(game.owed) }`. Usually one; several when everyone tied for lowest skipped the tie-break |

Rows, one per name in `game.joined`, each `{ name, you = (name == host),
value, mark }`, in this order. `name` shows `Rules.FullName` (surname
kept), as does every name in the debts; `you` compares character names.

1. The winner: `mark = "high"`, `value` = their main-round roll.
2. The losers, in `game.losers` order: `mark = "low"`, `value` = their roll.
3. The rest of the players who rolled, by the same interleaving as
   03-in-progress: sorted by roll highest first (ties in `joined` order),
   then the first, the last, the second, the second last, and so on.
   `mark = ""`. Players who shared the winner's or the loser's roll but lost
   the tie-break are here, with that roll.
4. Players in `game.satOut`, in that order: `mark = "out"`, `value = "sat
   out"`.

Raises if `game.phase ~= "finished"`.

### The view (`build.winner`, `draw.winner`)

Top to bottom, 10 px gaps:

1. Subtitle, muted.
2. `WINNER` in muted, small, plain upper case; under it the winner's name
   in `GameFontNormalHuge`, tint text, at the left; `winningRoll` in the
   same font and colour, right-aligned on the same line as the name.
3. The list box, filling the room down to the main button: one row per
   standing, painted by `mark` exactly as 03's rolling rows (`"out"` draws
   like `"waiting"`: name and value in the disabled colour, no background),
   with `(you)` in muted after the host's name and `value` right-aligned.
   Then one row per debt: `text` at the left in text colour with `(you)`
   in muted after it when `you`, `amount` right-aligned in text colour.
   A 1 px line in the border colour separates the first debt from the
   standings (where v2 drew `Total`).

The main button reads `Reset`; 01 handles the click (forget the game,
redraw to the form). The corner shows the X; the window may be hidden here.

Host drops a finished game right after reporting it; `UI.lua` keeps its own
reference (01), so this view draws from that.

## Exact user-facing text

| Where | Text |
|-------|------|
| label | `WINNER` |
| row values | `97`, `sat out` |
| debt row | `Dan owes Alice`, with `(you)` after it for the host |
| main button | `Reset` |

## Interfaces

Implements `View.Result` (contracts 5.6). Uses `Money.Format`,
`View.Subtitle`, the list box helper from 01, the row painting from 03.

## Files

Edits `src/UI.lua` (`build.winner`, `draw.winner`), `src/View.lua`
(`Result`), `spec/View_spec.lua` (the `Result` tests). One line in
`CHANGELOG.md`.

## Acceptance criteria

### Automated (busted)

Fixture: `finished` is a game built with `Rules`: host `Eve`, channel
`RAID`, wager 1000000, rollMax 100, joined `Alice, Bob, Carl, Dan, Eve,
Frank, Gina`, closed at 1000, rolls Alice 97, Bob 61, Eve 55, Frank 40,
Carl 23, Dan 8, Gina none, settled by `Tick` at 1045.

| ID | Input | Expected |
|----|-------|----------|
| AC-16-01 | `Result(finished, "Eve").winner`, `.winningRoll` | `"Alice"`, `"97"` |
| AC-16-02 | `Result(finished, "Eve").rows`, names and marks in order | `Alice high`, `Dan low`, `Bob ""`, `Carl ""`, `Eve ""`, `Frank ""`, `Gina out` |
| AC-16-03 | the same rows, values | `97`, `8`, `61`, `23`, `55`, `40`, `sat out`; `rows[5].you == true` |
| AC-16-04 | `Result(finished, "Eve").debts` | `{ { text = "Dan owes Alice", you = false, amount = "89g" } }` |
| AC-16-05 | two players, Alice 5 and Bob 2, wager 10000, rollMax 1000, host `Bob` | rows `Alice high 5`, `Bob low 2`; debts `{ { text = "Bob owes Alice", you = true, amount = "30c" } }` |
| AC-16-06 | a game won through a high tie-break (Alice and Eve 97, Alice re-rolls higher) | rows start `Alice high 97`, then the loser, then `Eve "" 97` among the rest |
| AC-16-07 | `Result({ phase = "rolling" }, "Eve")` | raises |
| AC-16-08 | `Result(finished, "Eve").subtitle` | `"Raid chat, 100g per person, roll 1-100"` |
| AC-16-10 | the finished fixture with full names Alice Vale, Dan Shards, Eve Moon | winner `Alice Vale`; row 1 `Alice Vale high 97`; row 5 `Eve Moon` with `you`; debt `Dan Shards owes Alice Vale` |
| AC-16-09 | Alice 97, Bob 61, Carl 8, Dan 8, host `Dan`; nobody rolls the low tie-break | rows `Alice high`, `Carl low`, `Dan low`, `Bob ""`; debts `Carl owes Alice` and `Dan owes Alice` (`you`), both `89g` |

### In-game (manual)

| ID | Do | Expect |
|----|----|--------|
| IG-16-01 | play a three-player game to the end | the window shows `WINNER`, the name in the tint with the winning roll at the right, the winner's row tinted on top, the loser's row in the low colour under it, the third player plain, and the last row `<loser> owes <winner>  <amount>` under a line; `Reset` tinted, `×` in the corner |
| IG-16-02 | compare with chat | the result line in chat names the same people, rolls and amount |
| IG-16-03 | a player sat out | their row is last, dimmed, `sat out` |
| IG-16-04 | click `×` | the window hides; `/dr` brings the winner view back |
| IG-16-05 | click `Reset` | the form, with the values from before the game |
| IG-16-06 | after `Reset`, `/dr` | the form, not the old result |
| IG-16-07 | lose a game yourself | `(you)` after your name in the standings and after the debt text |
| IG-16-08 | in a party game with a low roll max (`/dr p 1g 2`), two players tie for lowest and neither rolls the tie-break | both rows in the low colour, and two debt rows under the line, one per loser, each with the full amount |

## Mockup references

[../../mockups/window-v3.html](../../mockups/window-v3.html), panel 3.

## Open questions

None.
