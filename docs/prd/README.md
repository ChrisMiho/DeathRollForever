# Spec map

The specs for DeathRollForever live in this folder. This page is the only one
an agent loads by default. Find the document that owns what you are changing,
load it and [contracts.md](contracts.md), and nothing else.

Current version: **v2, the host's window**, being built on top of v1 (the
host runs a game from chat, released as v0.0.1).
Labels: `v1` is implemented. `v2` is in scope now. `out of scope for v2`
marks documents and features that are planned but not written or built yet;
the label comes off when that version starts.

## Documents

| Document | What it covers | Scope |
|----------|----------------|-------|
| [contracts.md](contracts.md) | Module map, data structures, public function signatures, events, constants, file ownership, glossary. What every builder shares | v1, v2 |
| [functional.md](functional.md) | Functional PRD: goals, roles, the game from start to winner, commands, decisions log. Links to the feature documents | v1 |
| [functional/01-money.md](functional/01-money.md) | Parsing and formatting wagers (`1g 50s`, `1.5g`, `5`) | v1 |
| [functional/02-chat-parsing.md](functional/02-chat-parsing.md) | Recognising join words, roll results and `/dr` arguments | v1 |
| [functional/03-rules-engine.md](functional/03-rules-engine.md) | The game as a pure state machine: lobby, shuffle, turns, timers, eliminations, winner | v1 |
| [functional/04-announcements.md](functional/04-announcements.md) | The exact text of every chat line | v1 |
| [functional/05-host-controller.md](functional/05-host-controller.md) | The glue: slash commands, chat events in, lines out, the ticker | v1 |
| [visual.md](visual.md) | Visual PRD: the window, its states, dimensions, colours, faction tint, type, parts, decisions log. Links to the state documents | v2 |
| [visual/01-window.md](visual/01-window.md) | The frame: title bar, corner (X or Cancel), moving, resizing, show and hide, state switching, redraw | v2 |
| [visual/02-form.md](visual/02-form.md) | The form: chat, wager, first roll, Start | v2 |
| [visual/03-in-progress.md](visual/03-in-progress.md) | The lobby (countdown, joined) and rolling (order, status, turn bar, Roll button) | v2 |
| [visual/04-winner.md](visual/04-winner.md) | The result: winner, who owes what, Reset | v2 |
| [../mockups/](../mockups/) | `window-v2.html` and its PNG exports, one per faction | v2 |
| [orchestration.md](orchestration.md) | For the agent that runs a build: phases, briefs, definition of done, when to stop for in-game testing | v2 |
| [../../PRD.md](../../PRD.md) | Product overview and roadmap. Intent, not behaviour | all |

## Which document owns which file

| File | Owner |
|------|-------|
| `src/Money.lua`, `spec/Money_spec.lua` | functional/01-money.md |
| `src/Parse.lua`, `spec/Parse_spec.lua` | functional/02-chat-parsing.md |
| `src/Rules.lua`, `spec/Rules_spec.lua` | functional/03-rules-engine.md |
| `src/Chat.lua`, `spec/Chat_spec.lua` | functional/04-announcements.md |
| `src/Host.lua`, `src/Init.lua` | functional/05-host-controller.md (its v2 section covers `Host.OnChange` and `/dr show`) |
| `src/View.lua`, `src/UI.lua`, `spec/View_spec.lua` | visual/01-window.md (shell, `TINT`, `State`, `ChatName`, `Subtitle`), visual/02-form.md (`StartOpts`, the form), visual/03-in-progress.md (`Lobby`, `Game`, both views), visual/04-winner.md (`Result`, the view). One package at a time |
| `docs/mockups/*` | visual.md |
| `DeathRollForever.toc`, `.pkgmeta`, `embeds.xml` | orchestration.md (orchestrator only) |
| `.luacheckrc`, `CHANGELOG.md` | shared; see contracts.md section 1 |

## The spec loop

Every change to behaviour, whether a feature or a bug fix, goes like this:

1. Find the owning document in the table above.
2. Read what it says should happen. If the spec is wrong or silent, change
   the spec first and get it approved. A change that touches
   [contracts.md](contracts.md) goes through the orchestrator or the human,
   never a lone builder.
3. Write or update the busted test for the acceptance criterion. Test
   descriptions carry the criterion ID (`AC-03-07`), so `grep AC-03` shows
   which criteria have tests.
4. Write the code.
5. Done means: `luacheck .` passes, `busted` passes, `CHANGELOG.md` has a line,
   the owning document agrees with the code, and the in-game checks the
   document lists are written down for the human to run.

## Roadmap

| Version | Adds | Status |
|---------|------|--------|
| v1 | Host runs a whole game from chat. Kickoff, join by chat, countdowns, shuffled order, calls, turn timer, forfeits, winner line with who owes what | implemented, v0.0.1 |
| v2 | The host's window: form, lobby, rolling and winner states, Roll and Cancel buttons, `/dr show`, faction tint, movable and resizable | spec written, being built |
| v3 | Sync: addon players see the window live, Roll button for them, auto-roll if allowed | out of scope for v2 |
| v4 | Ledger and trade detection: debts marked paid, `/dr owed` | out of scope for v2 |
| v5 | Settings view and saved variables (window position and size, defaults), history and stats, host reload resume | out of scope for v2 |
