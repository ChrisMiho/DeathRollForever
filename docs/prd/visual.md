# Visual PRD: the host's window

Status: v2 implemented. Last verified against code: 2026-11-06 (in-game by the host). The product overview is [PRD.md](../../PRD.md) section 5;
this document is the behaviour of the window and the look every state
shares. Each state's detail, exact text and acceptance criteria is in a
sub-document under [visual/](visual/).

## 1. v2 in one paragraph

The host gets one movable, resizable window on top of the v1 commands, which
keep working. With no game running it shows a form: chat, wager, first roll
and a Start button that does what `/dr g <wager> [first roll]` does. When a
game starts (from the button or from chat) the window tracks it: the join
countdown and who joined, then the roll order with each player's last roll,
who is up and what to type, and a turn timer. The Start button has become a
Roll button, gray until it is the host's turn, which rolls the right range so
the host never types `/roll`. A Cancel button in the corner does what `/dr
cancel` does. When the game ends the winner and who owes what stay on screen
until Reset returns the window to the form with the last values filled in.
`/dr show` opens the window. The title bar, bars, current row and main button
are tinted by the host's own faction.

## 2. Goals and non-goals for v2

Goals
- The host runs a whole game without typing a command.
- The window shows the same facts as the chat lines, never different ones.
- Everything the window computes (rows, status text, timer maths, button
  state) is a pure function of the `game` table and is tested without the
  client.

Non-goals for v2 (see the [roadmap](README.md#roadmap))
- A settings view, saved settings, remembering the window's position or size.
- Anything shown to players other than the host; sync.
- Kick, extend, the ledger, paid marks, auto-open on another host's game.
- Coin icons in the wager box, a `?` tooltip, a join time or join word field.
  The form has the three inputs the slash command has.

## 3. States

One window, four looks. The main button at the bottom reads by state.

| State | Shown when | Main button | Corner | Document |
|-------|------------|-------------|--------|----------|
| form | no game, or after Reset, or after a cancel | `Start` | X (hides the window) | [visual/02-form.md](visual/02-form.md) |
| lobby | `game.phase == "lobby"` | `Roll`, gray | `Cancel` | [visual/03-in-progress.md](visual/03-in-progress.md) |
| rolling | `game.phase == "rolling"` | `Roll 1-<range>`, enabled only on the host's turn | `Cancel` | [visual/03-in-progress.md](visual/03-in-progress.md) |
| winner | `game.phase == "finished"`, until Reset | `Reset` | X | [visual/04-winner.md](visual/04-winner.md) |

The window itself, the title bar, the corner, moving, resizing, showing and
hiding and the switch between states are in
[visual/01-window.md](visual/01-window.md).

Rules that hold in every state:

- The window cannot be hidden while a game is live (lobby or rolling). The
  corner shows Cancel instead of the X.
- Starting a game, from the button or from `/dr g`, shows the window.
- A cancelled game (by the host or for too few players) returns to the form
  at once. The chat line already said why.
- Errors from Start (bad wager, not in that chat, a game already running)
  print to the host's chat frame through `ns.Print`, exactly as the slash
  command prints them. The window shows no error text of its own.
- Nothing is saved. Hiding keeps the form's values; `/reload` loses them.

## 4. Look

The mockup is [docs/mockups/window-v2.html](../mockups/window-v2.html)
(PNG exports beside it, one per faction). It is drawn with web fonts and
rounded corners the client cannot do; the rules below are what the client
shows. Where the mockup and this section differ, this section wins.

### 4.1 Dimensions

| Item | Value |
|------|-------|
| Default size | 300 x 420 |
| Minimum size | 240 x 320 (`SetResizeBounds`) |
| Maximum size | 600 x 800 |
| Title bar height | 36 |
| Content padding | 12 on every side |
| Row height in lists | 24 |
| Gap between stacked parts | 10 |
| Progress bar height | 6 |
| Main button height | 44, full content width |
| Resize grip | 16 x 16, bottom-right corner |
| Strata | `DIALOG`, so it sits above chat |

The window is the same size in every state. Lists take the room the fixed
height leaves and scroll beyond it; a taller window shows more rows.

### 4.2 Colours

Colours are `{ r, g, b }` with 0..1 floats. The neutral palette lives in
`src/UI.lua`; the tints live in `View.TINT` so tests cover the faction
mapping.

Neutral palette:

| Name | Hex | rgb | Used for |
|------|-----|-----|----------|
| window | `#1b1c23` | 0.106, 0.110, 0.137 | window background |
| border | `#2c2e38` | 0.173, 0.180, 0.220 | 1 px window border, list box border |
| box | `#24262f` | 0.141, 0.149, 0.184 | list boxes, bar track, edit box background |
| text | `#ecedf2` | 0.925, 0.929, 0.949 | names, values, labels in the title bar |
| muted | `#8b8d99` | 0.545, 0.553, 0.600 | subtitles, hints, row numbers, "(you)", footer |
| disabled | `#767884` | 0.463, 0.471, 0.518 | out rows and their strike line, gray button text |
| disabledButton | `#2e303a` | 0.180, 0.188, 0.227 | gray main button background |

Tint, from `UnitFactionGroup("player")` `[P0-FACTION]`:

| Name | Alliance | Horde | Used for |
|------|----------|-------|----------|
| title | `#1d4db0` 0.114, 0.302, 0.690 | `#7d1c1c` 0.490, 0.110, 0.110 | title bar, current row background, selected chat button |
| button | `#2a63d8` 0.165, 0.388, 0.847 | `#d43b3b` 0.831, 0.231, 0.231 | main button, bar fill |
| text | `#8db4ff` 0.553, 0.706, 1.000 | `#ff9c9c` 1.000, 0.612, 0.612 | countdown number, status line, winner's name, the join word in the lobby status |

Buttons in the window are flat: a colour texture, white text, a slightly
lighter texture on hover (add 0.08 to each channel). The stock
`UIPanelButtonTemplate` is not used; its red bevel clashes with the panels.

### 4.3 Type

Font objects that exist on the client; the builder sets colours with
`SetTextColor` after `SetFontObject`.

| Role | Font object | Colour |
|------|-------------|--------|
| title, main button | `GameFontNormalLarge` | text (white) |
| body: names, values, field labels, status line | `GameFontHighlight` | text, or muted, or tint text |
| hints, subtitle, footer | `GameFontDisable` | muted |
| countdown number | `NumberFontNormalHuge` | tint text |
| winner's name | `GameFontNormalHuge` | tint text |

The client has no strikethrough. An "out" row draws a 1 px texture in the
disabled colour across the name text, anchored at the text's vertical centre.

### 4.4 Parts

| Part | How it is built |
|------|-----------------|
| window | `Frame` with `BackdropTemplate` `[P0-TEMPLATES]`: background and edge from `Interface\Buttons\WHITE8x8`, 1 px edge, coloured window and border |
| title bar | a colour texture in tint title; faction icon 16 x 16 at the left (`Interface\FriendsFrame\PlusManz-Alliance` or `-Horde`, see IG-06-13); the title `Death roll`; the corner control at the right |
| corner control | a flat Button: `×` (X) when no game is live, `Cancel` in a translucent white pill (alpha 0.16, 0.28 on hover) while one is |
| list box | a `ScrollFrame` with `UIPanelScrollFrameTemplate` over a child frame of rows, in the box colour |
| row | number in muted, name in text, a right-aligned value in muted; the current row's background is tint title with every text white |
| progress bar | `StatusBar` 6 px high, track in box, fill in tint button, no text |
| edit box | `EditBox` with `InputBoxTemplate`, `SetAutoFocus(false)` always, see `[P0-TEMPLATES]` |
| main button | flat Button, 44 high, tint button; gray (disabledButton background, disabled text) when disabled |
| footer | the faction name in muted, centred under the main button |
| resize grip | a 16 x 16 Button at the bottom-right that starts and stops sizing |

## 5. Commands

```
/dr show           open the window on the form, or on the running game
```

`/dr show` while the window is already open does nothing. Everything else in
[functional.md section 5](functional.md#5-commands-dr-or-deathroll) keeps
working; the window follows a game started from chat.

## 6. Phase 0 dependencies

Three in-game checks were answered on 2026-11-05 before this spec was
written; results are in
[orchestration.md](orchestration.md#phase-0-in-game-checks). Decisions that
rest on them are tagged `[P0-TEMPLATES]`, `[P0-FACTION]` and
`[P0-CLICKROLL]`.

## 7. Mockups

| File | Shows |
|------|-------|
| [../mockups/window-v2.html](../mockups/window-v2.html) | all four states side by side, faction toggle, host's-turn toggle, working resize grip |
| [../mockups/window-v2-alliance.png](../mockups/window-v2-alliance.png) | Alliance tint, another player's turn |
| [../mockups/window-v2-horde.png](../mockups/window-v2-horde.png) | Horde tint, the host's turn |

## 8. Decisions log

| Date | Decision | Why |
|------|----------|-----|
| 2026-11-05 | Flat dark panels with a solid tinted title bar, not the stock gold-bordered frame | The host preferred that look in the mockups |
| 2026-11-05 | One fixed window size in every state, lists scroll, a corner grip resizes | The window must not change size as the game moves; the host wanted a grip |
| 2026-11-05 | Lists fit the window rather than a fixed row cap | A taller window should show more players |
| 2026-11-05 | Cancel lives in the title-bar corner, never next to Roll | A mis-click next to Roll must not cancel a game |
| 2026-11-05 | The corner is X with no game and Cancel during one; the window cannot hide mid-game | The host always sees a running game |
| 2026-11-05 | Each row shows that player's last roll; no separate "last rolls" list | Shorter, and the order is the thing to watch |
| 2026-11-05 | The main button is one button whose label changes: Start, Roll 1-N, Reset | One place to click, no layout shift |
| 2026-11-05 | Cancel posts only the existing `Game cancelled by the host.` line and returns to the form | No new chat text in v2 |
| 2026-11-05 | Two files, `View.lua` (pure) and `UI.lua` (glue), built by four packages one after another | Fewer files; the window will not grow much beyond v2 |
| 2026-11-05 | Every edit box has auto-focus off | A parentless `InputBoxTemplate` box took the keyboard during Phase 0 |
| 2026-11-05 | Start errors print to chat, no error text in the window | Same text as the slash command, defined once in 01, 02 and 05 |
