# Orchestration: building v3

Status: draft v3. For the agent that runs the build. Sub-agents never read
this; they get a brief from section 4. The v1 and v2 versions of this
document are in git history (tags `v0.0.1`, `v0.1.0`).

## 1. Rules for the orchestrator

1. **Contract changes go through you.** A sub-agent that needs something not
   in [contracts.md](contracts.md) stops and reports. You decide, update
   contracts.md, and restart or re-brief the affected packages. A sub-agent
   never edits contracts.md, the `.toc`, `.pkgmeta` or `embeds.xml`.
2. **One writer per file.** The ownership table in
   [README.md](README.md#which-document-owns-which-file) is law. The three
   visual packages share `src/View.lua`, `src/UI.lua` and
   `spec/View_spec.lua`, so they run **one at a time**, in order 14, 15,
   16, each merged before the next starts. Each edits its own section and
   leaves the others alone.
3. **Each package runs in its own git worktree** on a branch named after it
   (`pkg/10-rules`). You merge into `main` after the definition of done is
   met. Merge conflicts are only ever in `.luacheckrc` and `CHANGELOG.md`;
   resolve them by keeping both sides.
4. **Stop and ask the human** at every point marked "human" below. Do not
   invent in-game results. Nothing needs the client until Phase 4.
5. **Specs stay true.** When a package changes behaviour from its document,
   the document is updated in the same branch, and the change is called out
   in the merge report.
6. **Never write feature code yourself.** The packages do the work; you
   brief, merge, verify and report.
7. **Between packages, `main` may fail `busted`** while a pure module and
   its callers are out of step (for example after 10 merges and before 15
   does). It must pass again after 16. `luacheck .` must pass after every
   merge.

## 2. Phases

```
Phase 1  10 rules engine, 11 chat parsing, 12 announcements   (in parallel; 12 may start before 10 merges, it only reads the event shapes)
Phase 2  13 host and init                                     (needs 10, 11, 12 merged)
Phase 3  14 window shell and form, then 15 in progress, then 16 winner   (each needs the one before merged; 14 needs 10 and 11)
Phase 4  human: in-game test of whole games from chat and from the window, fixes, release
```

Dependency graph:

```
10 rules ──────┬── 13 host ──┐
11 parse ──────┤             ├── Phase 4
12 announce ───┘             │
10, 11 ── 14 shell+form ── 15 in progress ── 16 winner ──┘
```

### Phase 1: the pure modules

Start 10, 11 and 12 in their worktrees at once. Merge each when its
definition of done is met. After all three: `luacheck .` green on `main`;
`busted` green for `spec/Rules_spec.lua`, `spec/Parse_spec.lua` and
`spec/Chat_spec.lua` (`spec/View_spec.lua` fails until Phase 3; expected).

### Phase 2: the glue

Start 13. It has no busted tests; its definition of done is `luacheck .`
and a careful read against 05-host-controller. Merge.

### Phase 3: the window, one package at a time

14, then 15, then 16, each started after the previous one merged. After
16 merges: `luacheck .` and `busted` fully green, every AC ID of every v3
document found by `grep` in `spec/`.

Then `scripts/build.sh` installs into the game.

### Phase 4: human in-game test

Hand the human, in this order, the IG tables from
[05-host-controller](functional/05-host-controller.md),
[01-window](visual/01-window.md), [02-form](visual/02-form.md),
[03-in-progress](visual/03-in-progress.md) and
[04-winner](visual/04-winner.md), and stop. Fix what comes back by the spec
loop (document first if the spec was wrong, then test, then code).

When the human says it is good, update every v3 document's status from
"draft v3" to "v3 implemented", set "Last verified against code" to that
date, move the README's v3 roadmap row to "implemented", and ask whether to
tag `v0.2.0`. Do not tag or push unless told to.

## 3. Definition of done for every package

- `luacheck .` passes with no warnings.
- `busted` passes for the package's own spec file, and every automated
  criterion ID from the package's document appears in a test description.
- One line under `## [Unreleased]` in `CHANGELOG.md`.
- The package's document agrees with the code. Anything changed is listed in
  the report back to the orchestrator.
- The report lists the in-game checks for the human verbatim from the
  document, plus any the builder thinks were missed.
- Nothing outside the package's owned files and sections changed, except
  additions to `.luacheckrc` and `CHANGELOG.md`.

## 4. Per-package briefs

Each brief is complete on its own with `CLAUDE.md`, `contracts.md` and the
package's document (plus `visual.md` for 14 to 16). Replace `<doc>` with
the path.

### Brief template

> You are building one package of the DeathRollForever WoW addon. Read
> `CLAUDE.md`, `docs/prd/contracts.md` and `<doc>` in full before writing
> anything. Build only what `<doc>` says, in the files and sections it says
> it owns. The game's rules changed in v3 (one round, highest wins, lowest
> pays the difference); the old turn-based code in your files is to be
> replaced, not kept. Work test-first: for each automated acceptance
> criterion in `<doc>`, write the busted test with the criterion ID in its
> description, see it fail, then make it pass. Glue code has no busted
> tests; verify it by `luacheck .` and a careful read against `<doc>`, and
> list every in-game check for the human. Do not edit any file outside the
> "Files" section of `<doc>`, except to add names to `.luacheckrc` and one
> line to `CHANGELOG.md`. If you need something that `contracts.md` does
> not provide, stop and report exactly what and why; do not work around it.
> When done, run `luacheck .` and `busted <your spec file>`, and report:
> what you built, every place the document and the code disagree, and the
> in-game checks the human should run.

### 10 rules engine

`<doc>` = `docs/prd/functional/03-rules-engine.md`. Add: "Rewrite
`src/Rules.lua` and `spec/Rules_spec.lua`. Keep the lobby and countdown
code where it still matches. Write AC-03-43 as one long test that walks a
whole game and asserts the full event list after each call." Expect about
45 tests.

### 11 chat parsing

`<doc>` = `docs/prd/functional/02-chat-parsing.md`. Add: "A rename and a
reword: `startRoll` becomes `rollMax`, `FIRST_ROLL_ERROR` becomes
`ROLL_MAX_ERROR` with the new text, `USAGE` changes. Update the existing
tests; add none unless a criterion lacks one." Expect the existing 22
tests, three of them changed.

### 12 announcements

`<doc>` = `docs/prd/functional/04-announcements.md`. Add: "Rewrite the
renderers for the v3 events. `spec/Chat_spec.lua` loads `src/Rules.lua`
only for `MIN_PLAYERS`; if the new `Rules.lua` is not merged yet, the old
one still has it." Expect about 22 tests.

### 13 host and init

`<doc>` = `docs/prd/functional/05-host-controller.md`. Needs 10, 11, 12
merged. Add: "`src/Host.lua`: `rollMax` and `rollTime` in `Start`, the tick
without `math.random`. `src/Init.lua`: the dispatch table and help lines of
the document; `/dr` alone opens the window, `show` is gone." No tests;
`luacheck .` and the read.

### 14 window shell and form

`<doc>` = `docs/prd/visual/01-window.md` and
`docs/prd/visual/02-form.md`, plus `docs/prd/visual.md`. Needs 10 and 11
merged. Add: "Two small documents, one package. In `src/View.lua`:
`TINT.low`, the new `Subtitle`, `Help`, and `StartOpts` returning `rollMax`.
In `src/UI.lua`: the help button and its `GameTooltip`, the form's `Roll
max` label, default, hint and note. In `spec/View_spec.lua`: update the
`Subtitle`, `TINT` and `StartOpts` tests, add the `Help` tests. Do not
touch the lobby, rolling or winner sections; their tests fail until 15 and
16, which is expected." Expect about 16 tests.

### 15 in progress

`<doc>` = `docs/prd/visual/03-in-progress.md`, plus `docs/prd/visual.md`.
Needs 14 merged. The largest package. Add: "Rewrite `View.Game` and the
rolling section of `src/UI.lua`; the lobby is unchanged. Build the busted
fixtures with `ns.Rules` as the document says, so the view models are
tested against real game tables. The row painting by `mark` is shared with
16: make `paintRow` take the model's `mark` and `tag`, and say so in the
file comment. Rows are reused frames, never created in `OnUpdate`." Expect
about 25 tests.

### 16 winner

`<doc>` = `docs/prd/visual/04-winner.md`, plus `docs/prd/visual.md`. Needs
15 merged. Add: "Rewrite `View.Result` and the winner section of
`src/UI.lua`. Reuse 15's row painting for the standings; only the debt row
is yours." Expect about 8 tests.

## 5. Reporting to the human

After each phase, one short message: what merged, what the tests cover, what
is waiting on them (in-game checks), and nothing else. Never claim an
in-game behaviour works; say what the human should see. At the end of Phase
3 give the human the build command (`scripts/build.sh`) and the Phase 4
tables.
