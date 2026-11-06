# 01 Window: the frame, the corner, the hover box, moving, resizing, states

Status: draft v3 (v2 shell plus the `?` hover box and the new subtitle). Last verified against code: not yet. Owns `src/UI.lua` (the shell), `src/View.lua` (`TINT`, `State`, `ChatName`, `Subtitle`, `Help`) and `spec/View_spec.lua` (their tests). Package 14, together with 02-form.

## Purpose and scope

The one window the host sees: its frame, title bar, the `?` that explains
the game on hover, corner control, main button, footer and resize grip;
moving and resizing; showing and hiding; the switch between the four
states; and the redraw after every change the Host reports. It draws
nothing inside a state itself: 02, 03 and 04 fill the stubs.

Out of scope: the contents of any state (02, 03, 04), saving position or
size, Escape to close, a settings gear.

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) sections 3, 5.5 (`Host.OnChange`,
`Host.Game`), 5.6, 5.7 and 7; [visual.md](../visual.md) section 4 for every
colour, size and font. Phase 0: `[P0-TEMPLATES]`, `[P0-FACTION]`.
Blocks: 02, 03, 04. They edit the same two files, so they start after this
package merges.

## Behaviour

### Pure (`src/View.lua`)

- `View.TINT`: the table in contracts section 5.6, keyed `Alliance` and
  `Horde`, each with `title`, `button`, `text` and `low`.
- `View.State(game)`: `"form"` when `game` is nil or `game.phase` is
  `"cancelled"`; `"lobby"`, `"rolling"` and `"winner"` for phases `lobby`,
  `rolling` and `finished`.
- `View.ChatName(channel)`: `"guild"`, `"party"`, `"raid"` for `"GUILD"`,
  `"PARTY"`, `"RAID"`.
- `View.Subtitle(game)`: `"<Chat> chat, <wager> per person, roll
  1-<rollMax>"`, with `<Chat>` capitalised (`Raid`) and `<wager>` from
  `Money.Format`.
- `View.Help(joinWord, rollMax)`: the six lines of the hover box, in order,
  as plain strings with the join word and roll max filled in (the text
  table below).

### The frame (`src/UI.lua`)

Built once, on the first `UI.Show()` or the first Host change, whichever
comes first (so `UnitFactionGroup` and `UnitName` are available, and a game
started from `/dr g` can show the window before any `/dr`), parented to
`UIParent`, `DIALOG` strata, centred, clamped to the screen, sized and
bounded as [visual.md 4.1](../visual.md#41-dimensions). `SetMovable(true)`
and `SetResizable(true)`.

Children, top to bottom:

1. **Title bar**, 36 high, full width: tint-title texture, faction icon,
   title text `Death roll`, the help button, then the corner control at the
   right edge with 8 px inset. Dragging the title bar moves the window
   (`StartMoving` on `OnDragStart`, `StopMovingOrSizing` on `OnDragStop`).
2. **Content area**: four child frames, one per state, each filling the area
   between the title bar and the main button with 12 px padding; exactly one
   is shown.
3. **Main button**, 44 high, 12 px from the sides, 12 px above the footer.
4. **Footer**: the faction name, muted, centred, 12 px from the bottom.
5. **Resize grip**: 16 x 16 at the bottom-right. `OnMouseDown` calls
   `StartSizing("BOTTOMRIGHT")`, `OnMouseUp` calls `StopMovingOrSizing`.
   Drawn as the size-grabber texture, or three short diagonal lines in the
   muted colour when the client lacks it.

Resizing changes the frame's width and height; everything is anchored so
the lists get the extra height and every full-width part the extra width.

### The help button and hover box

A 20 x 20 flat Button in the title bar, 8 px left of the corner control,
vertically centred: a 1 px circle is not available, so draw a translucent
white pill like Cancel's (alpha 0.16, 0.28 on hover) with a `?` in
`GameFontHighlight`, white. On `OnEnter`:

```
GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
GameTooltip:AddLine("How it works")                    -- default title colour
for each line of View.Help(joinWord, rollMax): GameTooltip:AddLine(line, 1, 1, 1, true)   -- white, wrapped
GameTooltip:Show()
```

`OnLeave` hides it. `joinWord` and `rollMax` are the current game's when
`UI.lua` holds a game (live or finished), else `Rules.DEFAULTS`. The button
is present in every state and never changes the state.

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
  draw[state](game, now)                           -- the state's own drawing, 02 to 04
```

| State | Label | Enabled | OnClick |
|-------|-------|---------|---------|
| form | `Start` | yes | `onMain.form()` (02) |
| lobby | `Roll` | no | nothing |
| rolling | `Roll 1-<max>` (set by 03's draw) | while the host is still to roll (03) | `onMain.rolling()` (03) |
| winner | `Reset` | yes | `game = nil; redraw()` |

Hooks for the state packages, all local tables in `UI.lua`:
`build[state](parent)` called once at build, `draw[state](game, now)`
called by every redraw, and `onMain[state]()`.

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
| help button | `?` |
| hover box title | `How it works` |
| hover box lines (`View.Help("1", 100)`) | `Type 1 in chat to join.` / `When called, everyone types /roll 100 once.` / `Highest roll wins, lowest roll pays.` / `Owed: (highest - lowest) x wager / 100.` / `A tie for highest or lowest re-rolls.` / `No roll in time: you sit out.` |
| corner, no game | `×` |
| corner, live game | `Cancel` |
| footer | `Alliance`, `Horde` or `Neutral` |
| main button | `Start`, `Roll`, `Roll 1-<max>`, `Reset` |
| `View.Subtitle` | `Raid chat, 100g per person, roll 1-100` |

## Interfaces

Implements contracts 5.6 (`TINT`, `State`, `ChatName`, `Subtitle`, `Help`)
and 5.7. Uses `Host.OnChange`, `Host.Game`, `Host.Cancel`, `Money.Format`,
`Rules.DEFAULTS`, `ns.Print`, and from section 7: `UIParent`,
`CreateFrame`, `UnitFactionGroup`, `UnitName`, `Ambiguate`, `GetTime`,
`GameTooltip`, the font objects, and the templates `BackdropTemplate` and
`UIPanelScrollFrameTemplate` (the latter is set up here as a helper the
state packages call to make a list box).

## Files

Edits `src/UI.lua` (the shell: the help button and hover box), `src/View.lua`
(`TINT.low`, `Subtitle`, `Help`), `spec/View_spec.lua`. Adds `GameTooltip`
to `.luacheckrc` `read_globals`. One line in `CHANGELOG.md`.

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
| AC-14-01 | `Subtitle({ channel = "RAID", wager = 1000000, rollMax = 100 })` | `"Raid chat, 100g per person, roll 1-100"` |
| AC-14-02 | `Subtitle({ channel = "GUILD", wager = 15045, rollMax = 500 })` | `"Guild chat, 1g 50s 45c per person, roll 1-500"` |
| AC-14-03 | `TINT.Alliance` and `TINT.Horde` | each has `title`, `button`, `text`, `low`, every one a table of three numbers in 0..1 |
| AC-14-04 | `Help("1", 100)` | the six lines of the text table, in order |
| AC-14-05 | `Help("roll", 1000)` | line 1 `Type roll in chat to join.`, line 2 `When called, everyone types /roll 1000 once.`, line 4 `Owed: (highest - lowest) x wager / 1000.` |

### In-game (manual)

| ID | Do | Expect |
|----|----|--------|
| IG-14-01 | `/dr` | the window appears centred, 300 x 420, dark with a tinted title bar, `Death roll`, the faction icon, a `?` and an `×` in the corner, a tinted `Start` button, the faction name under it |
| IG-14-02 | `/dr` again | nothing changes |
| IG-14-03 | hover the `?` | a tooltip under it titled `How it works` with the six lines, `/roll 100`; after starting a game with roll max 1000, the lines say `/roll 1000` and `/ 1000` |
| IG-14-04 | drag the title bar | the window moves and cannot leave the screen |
| IG-14-05 | drag the bottom-right grip | the window resizes; it stops at 240 x 320 and at 600 x 800 |
| IG-14-06 | click `×` | the window hides; `/dr` brings it back at the same place and size |
| IG-14-07 | hide the window, then `/dr g 1g` in a guild | the window shows itself in the lobby state with `Cancel` in the corner |
| IG-14-08 | during the lobby, try to hide it | there is no `×`; the window stays |
| IG-14-09 | click `Cancel` | `[DeathRoll] Game cancelled by the host.` once in chat; the window is on the form |
| IG-14-10 | `/dr g 1g`, wait with nobody joining | at 0 the too-few line posts and the window is on the form |
| IG-14-11 | on a Horde character | title bar, button and bar are red, the lowest row amber; on Alliance, blue and dark red; footer says the faction |
| IG-14-12 | `/reload` with the window open | the window is hidden until `/dr`; the form shows defaults again |

## Mockup references

[../../mockups/window-v3.html](../../mockups/window-v3.html): the title
bar with the `?` (click it there to see the box), corner, footer and grip
of every panel.

## Open questions

None.
