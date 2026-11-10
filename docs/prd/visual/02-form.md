# 02 Form: chat, wager, roll max, Start

Status: draft v3.1 (v2 form with the first-roll box renamed; v3.1 adds `Solo` and the `Bots` box). Last verified against code: not yet. Owns the `form` sections of `src/UI.lua` and `src/View.lua` (`View.StartOpts`) and their tests in `spec/View_spec.lua`. Package 14, together with 01-window.

## Purpose and scope

The window with no game: the three inputs the slash command takes and a
Start button that does exactly what `/dr g <wager> [roll max]` does. The
fields keep their values for the next game. v3.1: a fourth chat button,
`Solo`, starts a solo game (06-solo) and shows a `Bots` box.

Out of scope: join time, join word, coin icons, disabling chats the host is
not in, saving the values across `/reload`.

## Depends on / blocks

Depends on: 01-window; [contracts.md](../contracts.md) 5.2
(`Parse.StartArgs`), 5.5 (`Host.Start`), 5.6, 5.7; [visual.md](../visual.md)
section 4.
Blocks: nothing.

## Behaviour

### Pure: `View.StartOpts(channel, wagerText, rollMaxText, botsText)`

1. `key` = `"g"`, `"p"`, `"r"` or `"solo"` for `channel` `"GUILD"`,
   `"PARTY"`, `"RAID"`, `"SOLO"`. Any other channel raises (programmer
   mistake).
2. `args = { wagerText }`. Trim `rollMaxText`; if not empty, append it.
   `wagerText` is passed whole, spaces included: `Money.Parse` accepts
   `1g 50s`.
3. `opts, err = Parse.StartArgs(key, args)`. On error return `nil, err`
   with the text 01 and 02 define.
4. For `SOLO` only: trim `botsText` (nil counts as empty). Empty gives
   `opts.bots = Solo.BOTS`. Otherwise it must be a whole number from 1 to
   `Solo.MAX_BOTS` written in digits only, else `nil, Solo.BOTS_ERROR`.
   Other channels ignore `botsText` and set no `bots`.
5. Return `opts`: `{ channel, wager, rollMax }`, plus `bots` for `SOLO`.

### The form (`src/UI.lua`, `build.form` and `draw.form`)

Laid out top to bottom with 10 px gaps, labels in muted above each input:

1. `Chat`: four flat buttons in one row, `Guild`, `Party`, `Raid`, `Solo`,
   equal width, in a box-coloured strip. The selected one has the tint-title
   background and white text; the others muted text. Clicking selects.
2. `Wager per person`: an `InputBoxTemplate` edit box, full width,
   `SetAutoFocus(false)`, `SetMaxLetters(20)`. Under it a hint in muted:
   `1g, 50s, 1g50s or 1.5g`.
3. `Roll max`: the same kind of box, `SetMaxLetters(7)`, numeric text
   (`SetNumeric(true)`). Under it a hint in muted: `Everyone rolls 1 to
   this. 100 makes the gap a percentage.`
4. `Bots`, shown only while `Solo` is selected (label, box and hint hide
   otherwise): the same kind of box as roll max, `SetMaxLetters(2)`,
   numeric. Under it a hint in muted: `1 to 40`.
5. A note in muted anchored above the main button:
   `Players join by typing 1 in <chat> chat. 45 s to join, 45 s to roll.`
   `<chat>` is `View.ChatName` of the selected channel; `1`, `45` and `45`
   come from `Rules.DEFAULTS`. While `Solo` is selected the note is
   `It's just you and the bots.`

Defaults on first build: `Guild` selected, wager `1g`, roll max `100`
(`Rules.DEFAULTS.rollMax` as text), bots `10` (`Solo.BOTS` as text). Nothing ever clears the fields; after a
game, Reset shows them as they were.

Pressing Enter in any box does what Start does. Pressing Escape in a box
clears its focus (the template does this).

### Start (`onMain.form`)

```
opts, err = View.StartOpts(selectedChannel, wagerBox:GetText(), rollMaxBox:GetText(), botsBox:GetText())
if not opts then ns.Print(err) return end
ok, err = Host.Start(opts)
if not ok then ns.Print(err) end
```

Nothing else. `Host.Start` reports the new game through `Host.OnChange`,
which switches the window to the lobby.

## Exact user-facing text

| Where | Text |
|-------|------|
| labels | `Chat`, `Wager per person`, `Roll max`, `Bots` |
| chat buttons | `Guild`, `Party`, `Raid`, `Solo` |
| hints | `1g, 50s, 1g50s or 1.5g`, `Everyone rolls 1 to this. 100 makes the gap a percentage.`, `1 to 40` |
| note | `Players join by typing 1 in guild chat. 45 s to join, 45 s to roll.`; solo: `It's just you and the bots.` |
| defaults | `1g`, `100`, `10` |
| errors | none of its own: `Money.ERROR`, `Parse.ROLL_MAX_ERROR`, `Parse.USAGE`, `Solo.BOTS_ERROR` and the Host messages, via `ns.Print` |

## Interfaces

Implements `View.StartOpts` (contracts 5.6). Uses `Parse.StartArgs`,
`Rules.DEFAULTS`, `Solo.BOTS`, `Solo.MAX_BOTS`, `Solo.BOTS_ERROR`, `Host.Start`, `ns.Print`, `View.ChatName`, the template
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
| AC-07-08 | `StartOpts("SOLO", "1g", "", "")`, and with `botsText` nil | `{ channel = "SOLO", wager = 10000, rollMax = nil, bots = 10 }` both times |
| AC-07-09 | `StartOpts("SOLO", "1g", "1000", " 40 ")`, `("SOLO", "1g", "", "1")` | `bots = 40` and `rollMax = 1000`; `bots = 1` |
| AC-07-10 | `StartOpts("SOLO", "1g", "", "0")`, `"41"`, `"2.5"`, `"abc"` | `nil, Solo.BOTS_ERROR` each |
| AC-07-11 | `StartOpts("SOLO", "abc", "", "10")` | `nil, Money.ERROR` (the wager is checked first) |
| AC-07-12 | `StartOpts("GUILD", "1g", "", "99")` | `{ channel = "GUILD", wager = 10000, rollMax = nil }`, no `bots` |

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
| IG-07-11 | click `Solo` | `Solo` turns tinted; a `Bots` box with `10` and the hint `1 to 40` appears under roll max; the note says `It's just you and the bots.`; nothing overlaps at the default window size |
| IG-07-12 | click `Guild` again | the `Bots` box hides and the guild note is back |
| IG-07-13 | `Solo`, bots `40`, `Start` | the round with you and 40 bots; the list scrolls |
| IG-07-14 | `Solo`, bots `0` (or `41`), `Start` | `Bots must be a whole number from 1 to 40` in your chat frame, window unchanged |
| IG-07-15 | finish a solo game, `Reset` | the form shows `Solo` with the bot count you used |

## Mockup references

[../../mockups/window-v2.html](../../mockups/window-v2.html), panel 1,
with `First roll` read as `Roll max` and `1000` as `100`.

## Open questions

None.
