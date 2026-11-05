# Orchestration: building v1

Status: v1 implemented. Last verified against code: 2026-11-05. For the agent that runs the build. Sub-agents never read
this; they get a brief from section 4.

## 1. Rules for the orchestrator

1. **Contract changes go through you.** A sub-agent that needs something not
   in [contracts.md](contracts.md) stops and reports. You decide, update
   contracts.md, and restart or re-brief the affected packages. A sub-agent
   never edits contracts.md, the `.toc`, `.pkgmeta` or `embeds.xml`.
2. **One writer per file.** The ownership table in
   [README.md](README.md#which-document-owns-which-file) is law. Two packages
   never run at once if they share a file.
3. **Each package runs in its own git worktree** on a branch named after it
   (`pkg/01-money`). You merge into `main` in dependency order after the
   definition of done is met. Merge conflicts are only ever in `.luacheckrc`
   and `CHANGELOG.md`; resolve them by keeping both sides.
4. **Stop and ask the human** at every point marked "human" below. Do not
   invent in-game results.
5. **Specs stay true.** When a package changes behaviour from its document,
   the document is updated in the same branch, and the change is called out
   in the merge report.

## 2. Phases

```
Phase 0  human: four in-game checks                 (blocks 02, 04, 05)
Phase 1  orchestrator: scaffolding                  (one commit)
Phase 2  01 money first (small), then parallel: 02 chat parsing | 03 rules engine
         then 04 announcements (needs 01 and 03 merged)
Phase 3  05 host controller                         (needs 01-04 merged)
Phase 4  human: in-game test of a whole game, fixes, release
```

Dependency graph:

```
contracts ─┬─ 01 money ─┬─ 02 chat parsing ──┬──────────────────────┐
           │            └────────────────────┼─ 04 announcements ─┼─ 05 host controller
           └─ 03 rules engine ───────────────┘                    │
                                                                  ┘
Phase 0 ───── 02, 04 (text), 05
```

### Phase 0: in-game checks

Human only. Results go into the table below, in this file, before anything
depending on them is built. 01 and 03 can start before Phase 0 is done.

| Check | How | Result |
|-------|-----|--------|
| `[P0-ROLL]` | In any chat, type `/roll 1000`. Copy the system line exactly. Have another player roll; copy that line too | 2026-11-05: `Badass Bull rolls 282 (1-1000)` and `Natus Vincere rolls 818 (1-1000)`. Own roll and other players' rolls use the same form; the game never says "You roll". Character names on this server can contain a space |
| `[P0-POST]` | With the hello build, run from chat: `/run SendChatMessage("test", "GUILD")`. Then `/run C_Timer.After(2, function() SendChatMessage("test2", "GUILD") end)`. Both must appear in guild chat. Repeat with `"PARTY"` in a party | 2026-11-05 GUILD: works. Chat showed `[Guild] [Forgot Shards]: test` at once and `[Guild] [Forgot Shards]: test2` from the timer, no errors. PARTY: works. Chat showed `[Party] [Forgot Shards]: test` at once and `[Party] [Forgot Shards]: test2` from the timer, no errors. The party leader's own lines show as `[Party Leader] [Tohora Greytusk]: ...` |
| `[P0-DISTANCE]` | A guild member in another zone, not grouped with you, types `/roll 1000`. Do you see the system line? Then the same while grouped in a raid, far apart | 2026-11-05: ungrouped guild member far away: roll line NOT seen. Grouped in a party far away: roll line seen. Raid not tested separately; IG-05-20 covers it in Phase 4. Consequence: 04's optional kickoff sentence is on, README recommends grouping for guild games |
| `[P0-AUTOROLL]` | `/run C_Timer.After(2, function() RandomRoll(1, 100) end)`. Does a roll happen, or an error about a protected function? Not needed for v1; record it for v3 | 2026-11-05: works. `Forgot Shards rolls 99 (1-100)` appeared from the timer, no error. Auto-roll from addon code is possible on this server |

If `[P0-POST]` fails there is no v1 as designed: stop and talk to the human.
If `[P0-DISTANCE]` fails for ungrouped guild members, 04's optional kickoff
sentence is switched on and the README gains a note recommending a raid for
guild games.

### Phase 1: scaffolding

One commit on `main` by the orchestrator, before any package starts:

- `DeathRollForever.toc`: the load order from contracts section 1.
- Stub files `src/Money.lua`, `src/Parse.lua`, `src/Rules.lua`, `src/Host.lua`,
  each containing only the header line and `ns.<Name> = {}` so the addon
  still loads.
- `.luacheckrc`: nothing yet; packages add their own names.
- Run `luacheck .`, `busted`, `scripts/build.sh --no-install`. All green.

### Phase 2: pure modules in parallel

Start 01 and 03 at once in separate worktrees. 01 is small; merge it as soon
as it is done, then start 02 (its `StartArgs` tests need `src/Money.lua` on
`main`). 02 waits for `[P0-ROLL]` only for its roll tests; it may start on
everything else and leave `AC-02-06` to `AC-02-10` for last. When 01 and 03
are merged, start 04.

Integration after Phase 2: on `main`, `luacheck .` and `busted` green, and
`grep -c "AC-0" spec/*.lua` shows every automated criterion ID from 01 to 04
present at least once.

### Phase 3: host controller

Start 05 once 01 to 04 are merged and `[P0-POST]` is recorded as working.
After merge: `scripts/build.sh` installs into the game.

### Phase 4: human in-game test

Hand the human the IG-05 table from
[05-host-controller.md](functional/05-host-controller.md) and stop. Fix what
comes back by the spec loop (document first if the spec was wrong, then test,
then code). When the human says it is good, update every document's status
from "draft v1" to "v1 implemented", set "Last verified against code" to that
date, and ask whether to tag `v0.1.0`. Do not tag or push unless told to.

## 3. Definition of done for every package

- `luacheck .` passes with no warnings.
- `busted` passes, and every automated criterion ID from the package's
  document appears in a test description.
- One line under `## [Unreleased]` in `CHANGELOG.md`.
- The package's document agrees with the code. Anything changed is listed in
  the report back to the orchestrator.
- The report lists the in-game checks for the human verbatim from the
  document, plus any the builder thinks were missed.
- Nothing outside the package's owned files changed, except additions to
  `.luacheckrc` and `CHANGELOG.md`.

## 4. Per-package briefs

Each brief is complete on its own with `CLAUDE.md`, `contracts.md` and the
one feature document. Replace `<doc>` with the path.

### Brief template

> You are building one package of the DeathRollForever WoW addon. Read
> `CLAUDE.md`, `docs/prd/contracts.md` and `<doc>` in full before writing
> anything. Build only what `<doc>` says, in the files it says it owns. Work
> test-first: for each automated acceptance criterion in `<doc>`, write the
> busted test with the criterion ID in its description, see it fail, then make
> it pass. Do not edit any file outside the "Files" section of `<doc>`, except
> to add names to `.luacheckrc` and one line to `CHANGELOG.md`. If you need
> something that `contracts.md` does not provide, stop and report exactly what
> and why; do not work around it. When done, run `luacheck .` and `busted`,
> and report: what you built, every place the document and the code disagree,
> and the in-game checks the human should run.

### 01 money

`<doc>` = `docs/prd/functional/01-money.md`. No dependencies. Expect about 30
tests.

### 02 chat parsing

`<doc>` = `docs/prd/functional/02-chat-parsing.md`. Needs `src/Money.lua`
merged (or the builder loads it from `main`). Add to the brief: the Phase 0
roll text from this file, section 2, as the ground truth for `ROLL_PATTERN`.

### 03 rules engine

`<doc>` = `docs/prd/functional/03-rules-engine.md`. No dependencies. The
largest package. Add to the brief: "AC-03-30 is a full scripted game; write
the expected event list out in full in the spec, it is the regression test
every later version relies on."

### 04 announcements

`<doc>` = `docs/prd/functional/04-announcements.md`. Needs 01 and 03 merged.
Add to the brief: the `[P0-DISTANCE]` result, so the builder knows whether
the optional kickoff sentence is on.

### 05 host controller

`<doc>` = `docs/prd/functional/05-host-controller.md`. Needs 01 to 04 merged.
Add to the brief: the full Phase 0 results table, and "there are no busted
tests for this package; your verification is `luacheck .`, a clean
`scripts/build.sh --no-install`, and a careful read of every event handler
against the document."

## 5. Reporting to the human

After each phase, one short message: what merged, what the tests cover, what
is waiting on them (Phase 0 results, in-game checks), and nothing else. Never
claim an in-game behaviour works; say what the human should see.
