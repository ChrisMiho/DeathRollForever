# 02 Form: chat, wager, roll max, Start

Status: draft v3 (v2 form with the first-roll box renamed). Last verified against code: not yet. Owns the `form` sections of `src/UI.lua` and `src/View.lua` (`View.StartOpts`) and their tests in `spec/View_spec.lua`. Package 14, together with 01-window.

## Purpose and scope

The window with no game: the three inputs the slash command takes and a
Start button that does exactly what `/dr g <wager> [roll max]` does. The
fields keep their values for the next game.

Out of scope: join time, join word, coin icons, disabling chats the host is
not in, saving the values across `/reload`.

## Depends on / blocks

Depends on: 01-window; [contracts.md](../contracts.md) 5.2
(`Parse.StartArgs`), 5.5 (`Host.Start`), 5.6, 5.7; [visual.md](../visual.md)
section 4.
Blocks: nothing.

## Behaviour

### Pure: `View.StartOpts(channel, wagerText, rollMaxText)`

1. `key` = `"g"`, `"p"` or `"r"` for `channel` `"GUILD"`, `"PARTY"`,
   `"RAID"`. Any other channel raises (programmer mistake).
2. `args = { wagerText }`. Trim `rollMaxText`; if not empty, append it.
   `wagerText` is passed whole, spaces included: `Money.Parse` accepts
   `1g 50s`.
3. Return `Parse.StartArgs(key, args)`: `{ channel, wager, rollMax }` or
   `nil, errorText` with the text 01 and 02 define.

### The form (`src/UI.lua`, `build.form` and `draw.form`)

Laid out top to bottom with 10 px gaps, labels in muted above each input:

1. `Chat`: three flat buttons in one row, `Guild`, `Party`, `Raid`, equal
   width, in a box-coloured strip. The selected one has the tint-title
   background and white text; the others muted text. Clicking selects.
2. `Wager per person`: an `InputBoxTemplate` edit box, full width,
   `SetAutoFocus(false)`, `SetMaxLetters(20)`. Under it a hint in muted:
   `1g, 50s, 1g50s or 1.5g`.
3. `Roll max`: the same kind of box, `SetMaxLetters(7)`, numeric text
   (`SetNumeric(true)`). Under it a hint in muted: `Everyone rolls 1 to
   this. 100 makes the gap a percentage.`
4. A note in muted anchored above the main button:
   `Players join by typing 1 in <chat> chat. 60 s to join, 45 s to roll.`
   `<chat>` is `View.ChatName` of the selected channel; `1`, `60` and `45`
   come from `Rules.DEFAULTS`.

Defaults on first build: `Guild` selected, wager `1g`, roll max `100`
(`Rules.DEFAULTS.rollMax` as text). Nothing ever clears the fields; after a
game, Reset shows them as they were.

Pressing Enter in either box does what Start does. Pressing Escape in a box
clears its focus (the template does this).

### Start (`onMain.form`)

```
opts, err = View.StartOpts(selectedChannel, wagerBox:GetText(), rollMaxBox:GetText())
if not opts then ns.Print(err) return end
ok, err = Host.Start(opts)
if not ok then ns.Print(err) end
```

Nothing else. `Host.Start` reports the new game through `Host.OnChange`,
which switches the window to the lobby.

## Exact user-facing text

| Where | Text |
|-------|------|
| labels | `Chat`, `Wager per person`, `Roll max` |
| chat buttons | `Guild`, `Party`, `Raid` |
| hints | `1g, 50s, 1g50s or 1.5g`, `Everyone rolls 1 to this. 100 makes the gap a percentage.` |
| note | `Players join by typing 1 in guild chat. 60 s to join, 45 s to roll.` |
| defaults | `1g`, `100` |
| errors | none of its own: `Money.ERROR`, `Parse.ROLL_MAX_ERROR`, `Parse.USAGE` and the Host messages, via `ns.Print` |

## Interfaces

Implements `View.StartOpts` (contracts 5.6). Uses `Parse.StartArgs`,
`Rules.DEFAULTS`, `Host.Start`, `ns.Print`, `View.ChatName`, the template
`InputBoxTemplate` `[P0-TEMPLATES]`.

## Files

Edits `src/UI.lua` (`build.form`, `draw.form`, `onMain.form`), `src/View.lua`
(`StartOpts`), `spec/View_spec.lua`. One line in `CHANGELOG.md` (shared with
01-window's).

## Acceptance criteria

### Automated (busted)

| ID | Input | Expected |
|----|-------|----------|
| AC-07-01 | `StartOpts("GUILD", "1g", "100")` | `{ channel = "GUILD", wager = 10000, rollMax = 100 }` |
| AC-07-02 | `StartOpts("PARTY", "50s", "")` | `{ channel = "PARTY", wager = 5000, rollMax = nil }` |
| AC-07-03 | `StartOpts("RAID", "1g 50s", "  500 ")` | `{ channel = "RAID", wager = 15000, rollMax = 500 }` |
| AC-07-04 | `StartOpts("GUILD", "abc", "100")` | `nil, Money.ERROR` |
| AC-07-05 | `StartOpts("GUILD", "1g", "1")` | `nil, Parse.ROLL_MAX_ERROR` |
| AC-07-06 | `StartOpts("GUILD", "", "")` | `nil, Money.ERROR` |
| AC-07-07 | `StartOpts("WHISPER", "1g", "")` | raises |

### In-game (manual)

| ID | Do | Expect |
|----|----|--------|
| IG-07-01 | `/dr` on a fresh login | `Guild` selected, `1g`, `100`, both hints and the note with `guild chat` and `45 s to roll` |
| IG-07-02 | click `Raid` | `Raid` turns tinted, the note says `raid chat` |
| IG-07-03 | click into the wager box, type, press Escape | typing works, Escape leaves the box; the keyboard still works afterwards |
| IG-07-04 | wager `abc`, click `Start` | `Enter an amount like 5, 1g 50s or 1.5g` in your chat frame, window unchanged |
| IG-07-05 | roll max `1`, click `Start` | `Roll max must be a whole number from 2 to 1000000` locally |
| IG-07-06 | `Party` selected while not in a party, `Start` | `You are not in a party.` locally |
| IG-07-07 | `Guild`, `1g 50s`, `500`, `Start` | the kickoff line says `1g 50s per person. Everyone rolls 1-500 once`; the window is in the lobby |
| IG-07-08 | press Enter in the roll max box | same as clicking `Start` |
| IG-07-09 | play or cancel a game, then `Reset` or the cancel | the form shows `Guild`, `1g 50s`, `500` still |
| IG-07-10 | `/dr g 1g` from chat while the form shows `Raid` | the lobby shows `Guild chat`; after it ends the form still shows `Raid` |

## Mockup references

[../../mockups/window-v2.html](../../mockups/window-v2.html), panel 1,
with `First roll` read as `Roll max` and `1000` as `100`.

## Open questions

None.
