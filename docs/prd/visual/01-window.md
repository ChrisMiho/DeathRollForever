# 01 Window: the frame, the corner, moving, resizing, states

Status: draft v2. Owns `src/UI.lua` (the shell), `src/View.lua` (`TINT`, `State`, `ChatName`, `Subtitle`) and `spec/View_spec.lua` (their tests). Package 06.

## Purpose and scope

The one window the host sees: its frame, title bar, corner control, main
button, footer and resize grip; moving and resizing; showing and hiding; the
switch between the four states; and the redraw after every change the Host
reports. It draws nothing inside a state itself: packages 07 to 09 fill the
stubs this package leaves.

Out of scope: the contents of any state (02, 03, 04), saving position or
size (v5), Escape to close, a settings gear.

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) sections 5.5 (`Host.OnChange`,
`Host.Game`), 5.6, 5.7 and 7; [visual.md](../visual.md) section 4 for every
colour, size and font. Phase 0: `[P0-TEMPLATES]`, `[P0-FACTION]`. Phase 1
scaffolding must be merged (it adds `Host.OnChange`, `/dr show` and the stub
files).
Blocks: 02, 03, 04. They edit the same two files, so they start after this
package merges.

## Behaviour

### Pure (`src/View.lua`)

- `View.TINT`: the table in contracts section 5.6, keyed `Alliance` and
  `Horde`.
- `View.State(game)`: `"form"` when `game` is nil or `game.phase` is
  `"cancelled"`; `"lobby"`, `"rolling"` and `"winner"` for phases `lobby`,
  `rolling` and `finished`.
- `View.ChatName(channel)`: `"guild"`, `"party"`, `"raid"` for `"GUILD"`,
  `"PARTY"`, `"RAID"`.
- `View.Subtitle(game)`: `"<Chat> chat, <wager> per person, first roll
  1-<startRoll>"`, with `<Chat>` capitalised (`Raid`) and `<wager>` from
  `Money.Format`.

### The frame (`src/UI.lua`)

Built once, on the first `UI.Show()` (so `UnitFactionGroup` and `UnitName`
are available), parented to `UIParent`, `DIALOG` strata, centred, clamped to
the screen, sized and bounded as [visual.md 4.1](../visual.md#41-dimensions).
`SetMovable(true)` and `SetResizable(true)`.

Children, top to bottom:

1. **Title bar**, 36 high, full width: tint-title texture, faction icon,
   title text `Death roll`, corner control at the right edge with 8 px
   inset. Dragging the title bar moves the window (`StartMoving` on
   `OnDragStart`, `StopMovingOrSizing` on `OnDragStop`).
2. **Content area**: four child frames, one per state, each filling the area
   between the title bar and the main button with 12 px padding; exactly one
   is shown.
3. **Main button**, 44 high, 12 px from the sides, 12 px above the footer.
4. **Footer**: the faction name, muted, centred, 12 px from the bottom.
5. **Resize grip**: 16 x 16 at the bottom-right. `OnMouseDown` calls
   `StartSizing("BOTTOMRIGHT")`, `OnMouseUp` calls `StopMovingOrSizing`.
   Drawn as three short diagonal lines in the muted colour (colour textures),
   or `Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up` if that texture exists
   (IG-06-12).

Resizing changes the frame's width and height; everything is anchored so
the lists get the extra height and every full-width part the extra width.

### Faction

`faction = UnitFactionGroup("player")` once at build `[P0-FACTION]`. If it
is neither `"Alliance"` nor `"Horde"` (a neutral character), use the
Alliance tint and the word `Neutral` in the footer. The icon texture is
`Interface\FriendsFrame\PlusManz-<faction>`; for a neutral character no icon.

### Showing and hiding

- `UI.Show()`: build if needed, then `redraw()`, then `Show()`.
- `UI.Hide()`: if `View.State(current game) ~= "form"` and the state is not
  `"winner"`, do nothing. Otherwise `Hide()`.
- The X calls `UI.Hide()`. Cancel calls `Host.Cancel()` and prints any
  error with `ns.Print`.
- The window is not in `UISpecialFrames`; Escape does not close it.

### Redraw

`UI.lua` keeps `game`, the last game the Host reported (which may be
finished and dropped by Host), and `shown`, the state currently drawn.

```
redraw(now):
  state = View.State(game)
  if state == "form" then game = nil end          -- a cancelled game is forgotten
  if state ~= shown then
     hide every content frame, show content[state]
     corner: X when state is form or winner, Cancel otherwise
     main button: label and enabled from the table below
     shown = state
  end
  draw[state](game, now)                           -- the state's own drawing, 07 to 09
```

| State | Label | Enabled | OnClick |
|-------|-------|---------|---------|
| form | `Start` | yes | `onMain.form()` (02) |
| lobby | `Roll` | no | nothing |
| rolling | `Roll 1-<range>` (set by 03's draw) | only on the host's turn (03) | `onMain.rolling()` (03) |
| winner | `Reset` | yes | `game = nil; redraw()` |

Hooks for the later packages, all local tables in `UI.lua` created by this
package with empty functions: `build[state](parent)` called once at build,
`draw[state](game, now)` called by every redraw, and `onMain[state]()`.

Triggers:

- `Host.OnChange(function(g) game = g; redraw(GetTime()) end)`, registered on
  `PLAYER_LOGIN` (never at file load). Every Host change, including every
  tick, redraws.
- `OnUpdate` on the window, while shown and the state is lobby or rolling:
  accumulate elapsed time and call `redraw(GetTime())` at most every 0.1 s,
  so the bars move smoothly between ticks.
- `UI.Show()` redraws once.

A redraw while hidden is allowed and cheap; the window simply shows the
right state when opened. When a game starts (the Host reports a game whose
state is lobby) and the window is hidden, `redraw` calls `Show()`.

## Exact user-facing text

| Where | Text |
|-------|------|
| title | `Death roll` |
| corner, no game | `×` |
| corner, live game | `Cancel` |
| footer | `Alliance`, `Horde` or `Neutral` |
| main button | `Start`, `Roll`, `Roll 1-<range>`, `Reset` |
| `View.Subtitle` | `Raid chat, 1g per person, first roll 1-1000` |

## Interfaces

Implements contracts 5.6 (`TINT`, `State`, `ChatName`, `Subtitle`) and 5.7.
Uses `Host.OnChange`, `Host.Game`, `Host.Cancel`, `Money.Format`, `ns.Print`,
and from section 7: `UIParent`, `CreateFrame`, `UnitFactionGroup`,
`UnitName`, `Ambiguate`, `GetTime`, the font objects, and the templates
`BackdropTemplate` and `UIPanelScrollFrameTemplate` (the latter is set up
here as a helper the state packages call to make a list box).

## Files

Edits `src/UI.lua` and `src/View.lua` (replacing the Phase 1 stubs), creates
`spec/View_spec.lua`. Adds to `.luacheckrc` `read_globals` every API name it
uses. One line in `CHANGELOG.md`.

## Acceptance criteria

### Automated (busted)

| ID | Input | Expected |
|----|-------|----------|
| AC-06-01 | `State(nil)` | `"form"` |
| AC-06-02 | `State({ phase = "cancelled" })` | `"form"` |
| AC-06-03 | `State({ phase = "lobby" })` | `"lobby"` |
| AC-06-04 | `State({ phase = "rolling" })` | `"rolling"` |
| AC-06-05 | `State({ phase = "finished" })` | `"winner"` |
| AC-06-06 | `ChatName("GUILD")`, `("PARTY")`, `("RAID")` | `"guild"`, `"party"`, `"raid"` |
| AC-06-07 | `Subtitle({ channel = "RAID", wager = 10000, startRoll = 1000 })` | `"Raid chat, 1g per person, first roll 1-1000"` |
| AC-06-08 | `Subtitle({ channel = "GUILD", wager = 15045, startRoll = 500 })` | `"Guild chat, 1g 50s 45c per person, first roll 1-500"` |
| AC-06-09 | `TINT.Alliance` and `TINT.Horde` | each has `title`, `button`, `text`, every one a table of three numbers in 0..1 |

### In-game (manual)

| ID | Do | Expect |
|----|----|--------|
| IG-06-01 | `/dr show` | the window appears centred, 300 x 420, dark with a tinted title bar, `Death roll`, the faction icon, an `×` in the corner, a gray-free `Start` button, the faction name under it |
| IG-06-02 | `/dr show` again | nothing changes |
| IG-06-03 | drag the title bar | the window moves and cannot leave the screen |
| IG-06-04 | drag the bottom-right grip | the window resizes; it stops at 240 x 320 and at 600 x 800 |
| IG-06-05 | click `×` | the window hides; `/dr show` brings it back at the same place and size |
| IG-06-06 | hide the window, then `/dr g 1g` in a guild | the window shows itself in the lobby state with `Cancel` in the corner |
| IG-06-07 | during the lobby, try to hide it | there is no `×`; the window stays |
| IG-06-08 | click `Cancel` | `[DeathRoll] Game cancelled by the host.` once in chat; the window is on the form |
| IG-06-09 | `/dr g 1g`, wait with nobody joining | at 0 the too-few line posts and the window is on the form |
| IG-06-10 | on a Horde character | title bar, button and bar are red; footer says `Horde`; on Alliance, blue and `Alliance` |
| IG-06-11 | `/reload` with the window open | the window is hidden until `/dr show`; the form shows defaults again |
| IG-06-12 | look at the grip | the size-grabber texture shows, or the drawn lines if the client lacks it; note which |
| IG-06-13 | look at the title bar icon | the faction crest shows; if a green square shows instead, the texture path is wrong on this client: note it, and the builder removes the icon |

## Mockup references

[../../mockups/window-v2.html](../../mockups/window-v2.html): the title
bar, corner, footer and grip of every panel.

## Open questions

None.
