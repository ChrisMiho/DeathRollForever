# Spec map

The specs for DeathRollForever live in this folder. This page is the only one
an agent loads by default. Find the document that owns what you are changing,
load it and [contracts.md](contracts.md), and nothing else.

Current version being built: **v1, the host runs a game from chat.**
Labels: `v1` is in scope now. `out of scope for v1` marks documents and
features that are planned but not written or built yet; the label comes off
when that version starts.

## Documents

| Document | What it covers | Scope |
|----------|----------------|-------|
| [contracts.md](contracts.md) | Module map, data structures, public function signatures, events, constants, file ownership, glossary. What every builder shares | v1 |
| [functional.md](functional.md) | Functional PRD: goals, roles, the game from start to winner, commands, decisions log. Links to the feature documents | v1 |
| [functional/01-money.md](functional/01-money.md) | Parsing and formatting wagers (`1g 50s`, `1.5g`, `5`) | v1 |
| [functional/02-chat-parsing.md](functional/02-chat-parsing.md) | Recognising join words, roll results and `/dr` arguments | v1 |
| [functional/03-rules-engine.md](functional/03-rules-engine.md) | The game as a pure state machine: lobby, shuffle, turns, timers, eliminations, winner | v1 |
| [functional/04-announcements.md](functional/04-announcements.md) | The exact text of every chat line | v1 |
| [functional/05-host-controller.md](functional/05-host-controller.md) | The glue: slash commands, chat events in, lines out, the ticker | v1 |
| visual.md | Visual PRD: the window, colours, faction tint, views, with mock images | out of scope for v1 |
| visual/ | One detailed document per piece of UI | out of scope for v1 |
| ../mockups/ | HTML mockups and their PNG exports | out of scope for v1 |
| [orchestration.md](orchestration.md) | For the agent that runs a build: phases, briefs, definition of done, when to stop for in-game testing | v1 |
| [../../PRD.md](../../PRD.md) | Product overview and roadmap. Intent, not behaviour | all |

## Which document owns which file

| File | Owner |
|------|-------|
| `src/Money.lua`, `spec/Money_spec.lua` | functional/01-money.md |
| `src/Parse.lua`, `spec/Parse_spec.lua` | functional/02-chat-parsing.md |
| `src/Rules.lua`, `spec/Rules_spec.lua` | functional/03-rules-engine.md |
| `src/Chat.lua`, `spec/Chat_spec.lua` | functional/04-announcements.md |
| `src/Host.lua`, `src/Init.lua` | functional/05-host-controller.md |
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
| v1 | Host runs a whole game from chat. Kickoff, join by chat, countdowns, shuffled order, calls, turn timer, forfeits, winner line with who owes what | being specified |
| v2 | The window: new game form, lobby, game and result views, settings view, faction tint | out of scope for v1 |
| v3 | Sync: addon players see the window live, ROLL button, auto-roll if allowed | out of scope for v1 |
| v4 | Ledger and trade detection: debts marked paid, `/dr owed` | out of scope for v1 |
| v5 | Settings, saved variables, history and stats, host reload resume | out of scope for v1 |
