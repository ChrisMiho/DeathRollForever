# One-round rules (v3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the turn-based death roll with one round where everyone rolls once, the highest roll wins and the lowest pays `(highest - lowest) x wager / roll max`, and redraw the host's window around it.

**Architecture:** The pure modules (`Rules`, `Parse`, `Chat`, `View`) change shape and are rewritten test-first against the acceptance tables in their spec documents; the glue (`Host`, `Init`, `UI`) is edited to match. Seven packages, each in its own worktree and branch, merged into `main` in dependency order by the orchestrator; the window packages run one at a time because they share three files.

**Tech Stack:** Lua 5.1 (WoW Forever, Interface 16001), busted, luacheck, BigWigs packager.

**Spec:** `docs/prd/README.md` (the map), `docs/prd/contracts.md`, `docs/prd/functional.md` and `docs/prd/functional/02..05`, `docs/prd/visual.md` and `docs/prd/visual/01..04`, `docs/prd/orchestration.md` (phases, briefs, definition of done). Mockups: `docs/mockups/window-v3.html` (rolling, tie-break, result), `docs/mockups/window-v2.html` (form, lobby).

## Global Constraints

- Every `src/` file starts with `local addonName, ns = ...` (or `local _, ns = ...`); nothing shared through globals.
- Pure modules call no WoW API; glue files are the only ones that touch frames, events or chat.
- Money is an integer number of copper. `Rules.Owed = math.floor((high - low) * wager / rollMax)`.
- `Rules.DEFAULTS = { rollMax = 100, joinTime = 60, rollTime = 45, joinWord = "1" }`; `COUNTDOWN = { 30, 15, 5 }`; `REMINDERS = { 20, 10, 5 }`; `MIN_PLAYERS = 2`.
- Every WoW API used is in `.luacheckrc` `read_globals`, sorted. v3 adds `GameTooltip`; `math.random` is no longer used.
- Each busted test description carries its criterion ID (`AC-03-19`), so `grep AC-03 spec/` shows coverage.
- Tabs for Lua indentation. `luacheck .` clean. Each package adds one line under `## [Unreleased]` in `CHANGELOG.md`.
- A sub-agent edits only the files its document's "Files" section names, plus `.luacheckrc` and `CHANGELOG.md`. Contract changes go through the orchestrator.
- No tag, no push. `scripts/build.sh` runs on `main` only, after the last merge.

## Review Focus

Inputs the spec implies but the acceptance tables do not all pin; each line names the test added to the owning package.

1. A `/roll` that arrives after the deadline settled the round, from a player who is a roller in the new tie-break: it must count for the tie-break, not the old round. Package 10 adds a test: main round settled by `Tick` into a high tie between Alice and Dan; `Roll(Alice, 30)` at `t + 46` gives `rolled` with `tieRolls.Alice == 30`.
2. A player who sat out of the main round rolling during a tie-break or rerun: ignored. Package 10 adds: Alice 97, Bob 97, Carl 8, Dan none, settled by `Tick` into a high tie; `Roll(Dan, 50)` during the tie-break gives `{}`.
3. Reminder lines when nobody is waiting cannot happen (the round settles first), but a reminder marker passed in the same tick as a roll that settles the round must not post. Package 10 adds: Alice, Bob rolled; `Tick(t + 25)` gives `{reminder names={Carl}}`; `Roll(Carl, 8, t + 26)` gives `{rolled, winner}` with no reminder.
4. Rounding of the debt with awkward wagers: `Owed(3, 1, 15045, 100) == 300` (floor of 300.9), and `Money.Format` of it. Package 10 adds the `Owed` case; package 12 renders `winner{owed=300}` as `3s`.
5. The Roll button after a tie-break starts: the host was gray (already rolled in the main round) and must turn tinted again when they are in `tie.high` or `tie.low`, and the pending guard from a main-round click must not keep it gray. Package 15 adds AC-15-20 (already in the spec) and a UI note; in-game IG-15-09 checks it.

---

## Tasks

Each task is one package of `docs/prd/orchestration.md` section 4. The brief there, plus `CLAUDE.md`, `docs/prd/contracts.md` and the package's document, is the whole task description; the acceptance table in the document is the test list. The orchestrator creates the worktree, dispatches the brief, merges on the definition of done (orchestration.md section 3), and runs `luacheck .` and `busted` on `main` after each merge.

### Task 1: Package 10, rules engine

**Files:** rewrite `src/Rules.lua`, `spec/Rules_spec.lua`. **Spec:** `docs/prd/functional/03-rules-engine.md`.
**Produces:** `Rules.New/Join/Tick/Roll/Cancel/Waiting/Owed/IsLive` and the `game` table of contracts section 4; the events of section 6.

- [ ] Worktree `pkg/10-rules` from `main`.
- [ ] For AC-03-01 to AC-03-43 plus Review Focus 1 to 4: write the test, see it fail, make it pass.
- [ ] `luacheck .`, `busted spec/Rules_spec.lua` green; changelog line; commit on the branch.
- [ ] Orchestrator: merge into `main`.

### Task 2: Package 11, chat parsing

**Files:** edit `src/Parse.lua`, `spec/Parse_spec.lua`. **Spec:** `docs/prd/functional/02-chat-parsing.md`.
**Produces:** `Parse.StartArgs` returning `rollMax`; `Parse.USAGE`, `Parse.ROLL_MAX_ERROR`.

- [ ] Worktree `pkg/11-parse` from `main` (parallel with Task 1 and 3).
- [ ] Update AC-02-15, AC-02-17, AC-02-21 and the constants; all 22 tests green.
- [ ] `luacheck .`; changelog line; commit. Orchestrator merges.

### Task 3: Package 12, announcements

**Files:** rewrite `src/Chat.lua` renderers, `spec/Chat_spec.lua`. **Spec:** `docs/prd/functional/04-announcements.md`.
**Produces:** `Chat.Render` for every v3 event type.

- [ ] Worktree `pkg/12-announce` from `main` (parallel with Tasks 1 and 2).
- [ ] For AC-04-01 to AC-04-22 plus Review Focus 4: write the test, see it fail, make it pass.
- [ ] `luacheck .`, `busted spec/Chat_spec.lua` green; changelog line; commit. Orchestrator merges.

### Task 4: Package 13, host and init

**Files:** edit `src/Host.lua`, `src/Init.lua`. **Spec:** `docs/prd/functional/05-host-controller.md`. Needs Tasks 1 to 3 merged.
**Produces:** `Host.Start` filling `rollMax` and `rollTime`; the tick without `rng`; `/dr` opening the window; the six help lines.

- [ ] Worktree `pkg/13-host` from `main`.
- [ ] Edit per the document; `luacheck .` clean; read against the document; changelog line; commit. Orchestrator merges.

### Task 5: Package 14, window shell and form

**Files:** edit `src/View.lua` (`TINT.low`, `Subtitle`, `Help`, `StartOpts`), `src/UI.lua` (help button and tooltip, form label, default, hint, note), `spec/View_spec.lua` (those sections), `.luacheckrc` (`GameTooltip`). **Spec:** `docs/prd/visual/01-window.md`, `docs/prd/visual/02-form.md`, `docs/prd/visual.md`. Needs Tasks 1 and 2 merged.
**Produces:** `View.Help(joinWord, rollMax)`, `View.TINT.<faction>.low`, `View.StartOpts` returning `rollMax`.

- [ ] Worktree `pkg/14-shell` from `main`.
- [ ] AC-06-01 to 06, AC-14-01 to 05, AC-07-01 to 07: tests first; the lobby, rolling and winner tests may fail until Tasks 6 and 7.
- [ ] `luacheck .`; changelog line; commit. Orchestrator merges.

### Task 6: Package 15, in progress

**Files:** edit `src/View.lua` (`Game`), `src/UI.lua` (rolling section, `paintRow` by `mark` and `tag`), `spec/View_spec.lua` (`Lobby`, `Game`). **Spec:** `docs/prd/visual/03-in-progress.md`, `docs/prd/visual.md`. Needs Task 5 merged.
**Produces:** `View.Game` rows with `mark` and `tag`; a `paintRow(row, model)` that 16 reuses.

- [ ] Worktree `pkg/15-progress` from `main`.
- [ ] AC-15-01 to AC-15-28: fixtures built with `ns.Rules`; tests first.
- [ ] `luacheck .`, `busted spec/View_spec.lua` green except the winner section; changelog line; commit. Orchestrator merges.

### Task 7: Package 16, winner

**Files:** edit `src/View.lua` (`Result`), `src/UI.lua` (winner section), `spec/View_spec.lua` (`Result`). **Spec:** `docs/prd/visual/04-winner.md`, `docs/prd/visual.md`. Needs Task 6 merged.

- [ ] Worktree `pkg/16-winner` from `main`.
- [ ] AC-16-01 to AC-16-08: tests first.
- [ ] `luacheck .`, `busted` fully green; changelog line; commit. Orchestrator merges.

### Task 8: Orchestrator wrap-up

- [ ] On `main`: `luacheck .`, `busted`, `grep` every AC ID of every v3 document in `spec/`.
- [ ] `scripts/build.sh` to install into the game.
- [ ] Hand the human the in-game tables of 05, 01, 02, 03 and 04 (orchestration.md Phase 4). Stop; nothing tagged or pushed.
