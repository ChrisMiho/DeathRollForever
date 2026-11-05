# Orchestration: building v2

Status: draft v2. For the agent that runs the build. Sub-agents never read
this; they get a brief from section 4. The v1 version of this document is in
git history (tag `v0.0.1`).

## 1. Rules for the orchestrator

1. **Contract changes go through you.** A sub-agent that needs something not
   in [contracts.md](contracts.md) stops and reports. You decide, update
   contracts.md, and restart or re-brief the affected packages. A sub-agent
   never edits contracts.md, the `.toc`, `.pkgmeta` or `embeds.xml`.
2. **One writer per file.** The ownership table in
   [README.md](README.md#which-document-owns-which-file) is law. The four
   visual packages share `src/View.lua`, `src/UI.lua` and
   `spec/View_spec.lua`, so they run **one at a time**, in order 06, 07, 08,
   09, each merged before the next starts. Each adds its own section and
   leaves the others alone.
3. **Each package runs in its own git worktree** on a branch named after it
   (`pkg/06-window`). You merge into `main` after the definition of done is
   met. Merge conflicts are only ever in `.luacheckrc` and `CHANGELOG.md`;
   resolve them by keeping both sides.
4. **Stop and ask the human** at every point marked "human" below. Do not
   invent in-game results. Phase 0 is already answered; nothing else needs
   the client until Phase 4.
5. **Specs stay true.** When a package changes behaviour from its document,
   the document is updated in the same branch, and the change is called out
   in the merge report.
6. **Never write feature code yourself** beyond Phase 1 scaffolding. The
   packages do the work; you brief, merge, verify and report.

## 2. Phases

```
Phase 0  human: three in-game checks                 done 2026-11-05
Phase 1  orchestrator: scaffolding                   (one commit on main)
Phase 2  06 window shell                             (needs Phase 1)
Phase 3  07 form, then 08 in progress, then 09 winner (each needs the one before merged)
Phase 4  human: in-game test of a whole game from the window, fixes, release
```

Dependency graph:

```
v1 (01-05, on main) ─┬─ Phase 1 scaffolding ─ 06 window ─ 07 form ─ 08 in progress ─ 09 winner ─ Phase 4
Phase 0 ─────────────┘
```

### Phase 0: in-game checks

Human only. Results go into the table below, in this file, before anything
depending on them is built.

| Check | How | Result |
|-------|-----|--------|
| `[P0-TEMPLATES]` | `/run for _,p in ipairs({{"Frame","BackdropTemplate"},{"Button","UIPanelButtonTemplate"},{"EditBox","InputBoxTemplate"},{"ScrollFrame","UIPanelScrollFrameTemplate"},{"Button","UIPanelCloseButton"}})do print(p[2],(pcall(CreateFrame,p[1],nil,nil,p[2])))end` | 2026-11-05: all five print `true`. `BackdropTemplate`, `UIPanelButtonTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate` and `UIPanelCloseButton` exist on this client and may be used. Side effect seen: the parentless `InputBoxTemplate` box created by the test took keyboard focus and the keyboard stopped working until focus was cleared. Every edit box in the window is created with `SetAutoFocus(false)` |
| `[P0-FACTION]` | `/run local f=CreateFrame("Frame")print("faction",UnitFactionGroup("player"))print("bounds",f.SetResizeBounds~=nil,"minresize",f.SetMinResize~=nil,"sizing",f.StartSizing~=nil,"color",f:CreateTexture().SetColorTexture~=nil)` | 2026-11-05: `faction Horde Horde`, then `bounds true minresize false sizing true color true`. `UnitFactionGroup("player")` returns the English key (`"Alliance"` or `"Horde"`) first; the tint keys on it. Min and max size are set with `SetResizeBounds`, not `SetMinResize`/`SetMaxResize`. `StartSizing` exists for the corner grip. `SetColorTexture` exists for flat panels |
| `[P0-CLICKROLL]` | `/run local b=CreateFrame("Button","DRTest",UIParent,"UIPanelButtonTemplate")b:SetPoint("CENTER")b:SetSize(100,30)b:SetText("Roll 1-100")b:SetScript("OnClick",function(s)RandomRoll(1,100)s:Hide()end)` then click the button | 2026-11-05: works. The stock button appeared, the click produced `Forgot Shards rolls 43 (1-100)` in chat, no error. `RandomRoll(1, range)` from the ROLL button's `OnClick` is the whole roll path; the host never types `/roll` |

### Phase 1: scaffolding

One commit on `main` by the orchestrator, before any package starts:

- `DeathRollForever.toc`: the v2 load order from contracts section 1
  (`src\View.lua` after `Chat.lua`, `src\UI.lua` after `Host.lua`).
- Stub files: `src/View.lua` with the header line and `ns.View = {}`;
  `src/UI.lua` with the header line and `ns.UI = { Show = function() end,
  Hide = function() end }`.
- `src/Host.lua`: `Host.OnChange` exactly as
  [05-host-controller.md, v2 additions](functional/05-host-controller.md#v2-additions)
  says (a local `listener`, called at the end of `Start`, of `post` before
  `stop()`, and of `tick`).
- `src/Init.lua`: the `show` command dispatching to `ns.UI.Show()` and the
  new help line, from the same section.
- `CHANGELOG.md`: nothing yet; packages add their lines.
- Run `luacheck .`, `busted`, `scripts/build.sh --no-install`. All green.
  The addon must still load and play a v1 game: the stubs do nothing.

### Phase 2: the window shell

Start 06 in its worktree. When its definition of done is met, merge. On
`main`: `luacheck .` and `busted` green, `grep -c "AC-06" spec/View_spec.lua`
shows every AC-06 ID.

### Phase 3: the states, one at a time

07, then 08, then 09, each started after the previous one merged. 07 and 09
are small (a day each at most for an agent); 08 is the largest. After each
merge, the AC grep for that package's IDs, lint and tests green.

After 09 merges: `scripts/build.sh` installs into the game.

### Phase 4: human in-game test

Hand the human, in this order, the IG tables from
[01-window](visual/01-window.md), [02-form](visual/02-form.md),
[03-in-progress](visual/03-in-progress.md), [04-winner](visual/04-winner.md)
and the two new rows in [05-host-controller](functional/05-host-controller.md#v2-additions),
and stop. Fix what comes back by the spec loop (document first if the spec
was wrong, then test, then code). Two outcomes are expected and already
planned for: IG-06-12 (grip texture) and IG-06-13 (faction icon texture)
may report a missing texture; the fix is the fallback each row names.

When the human says it is good, update every v2 document's status from
"draft v2" to "v2 implemented", set "Last verified against code" to that
date, move the README's v2 roadmap row to "implemented", and ask whether to
tag `v0.1.0`. Do not tag or push unless told to.

## 3. Definition of done for every package

- `luacheck .` passes with no warnings.
- `busted` passes, and every automated criterion ID from the package's
  document appears in a test description.
- One line under `## [Unreleased]` in `CHANGELOG.md`.
- The package's document agrees with the code. Anything changed is listed in
  the report back to the orchestrator.
- The report lists the in-game checks for the human verbatim from the
  document, plus any the builder thinks were missed.
- Nothing outside the package's owned sections changed, except additions to
  `.luacheckrc` and `CHANGELOG.md`. For 07 to 09: the sections of
  `src/UI.lua`, `src/View.lua` and `spec/View_spec.lua` that belong to other
  packages are untouched (`git diff` shows additions only, plus the stub
  bodies the package was told to fill).
- `scripts/build.sh --no-install` succeeds (the builder may skip this inside
  a worktree, where the packager cannot run; the orchestrator runs it on
  `main` after the merge).

## 4. Per-package briefs

Each brief is complete on its own with `CLAUDE.md`, `contracts.md`,
`visual.md` and the one state document. Replace `<doc>` with the path.

### Brief template

> You are building one package of the DeathRollForever WoW addon. Read
> `CLAUDE.md`, `docs/prd/contracts.md`, `docs/prd/visual.md` and `<doc>` in
> full before writing anything. Build only what `<doc>` says, in the files
> and sections it says it owns. Work test-first: for each automated
> acceptance criterion in `<doc>`, write the busted test with the criterion
> ID in its description, see it fail, then make it pass. Glue code in
> `src/UI.lua` has no busted tests; verify it by `luacheck .` and a careful
> read against `<doc>` and `visual.md` section 4, and list every in-game
> check for the human. Do not edit any file outside the "Files" section of
> `<doc>`, except to add names to `.luacheckrc` and one line to
> `CHANGELOG.md`. Do not touch sections of `src/UI.lua`, `src/View.lua` or
> `spec/View_spec.lua` that belong to another package. If you need something
> that `contracts.md` does not provide, stop and report exactly what and
> why; do not work around it. When done, run `luacheck .` and `busted`, and
> report: what you built, every place the document and the code disagree,
> and the in-game checks the human should run.

### 06 window shell

`<doc>` = `docs/prd/visual/01-window.md`. Needs Phase 1 merged. Add to the
brief: "You replace the two stub files. Leave `build`, `draw` and `onMain`
tables with an empty function for every state that is not yours, with a
comment naming the package that fills each (07 form, 08 lobby and rolling,
09 winner). Make the list-box helper (a scroll frame of reusable rows)
because 08 and 09 call it; describe its signature in a comment at the top of
`src/UI.lua`." Expect about 9 tests.

### 07 form

`<doc>` = `docs/prd/visual/02-form.md`. Needs 06 merged. Add to the brief:
"`src/UI.lua` already has the shell; fill only `build.form`, `draw.form`
and `onMain.form`, and add `View.StartOpts` to `src/View.lua`. Read the
existing files first." Expect about 7 tests.

### 08 in progress

`<doc>` = `docs/prd/visual/03-in-progress.md`. Needs 07 merged. The largest
package. Add to the brief: "Fill `build.lobby`, `draw.lobby`,
`build.rolling`, `draw.rolling`, `onMain.rolling`; add `View.Lobby` and
`View.Game`. Build the busted fixtures with `ns.Rules` where the document
allows, so the view models are tested against real game tables. Rows are
reused frames, never created in `OnUpdate`." Expect about 18 tests.

### 09 winner

`<doc>` = `docs/prd/visual/04-winner.md`. Needs 08 merged. Add to the
brief: "Fill `build.winner` and `draw.winner`; add `View.Result`. The Reset
click is already handled by the shell." Expect about 7 tests.

## 5. Reporting to the human

After each phase, one short message: what merged, what the tests cover, what
is waiting on them (in-game checks), and nothing else. Never claim an
in-game behaviour works; say what the human should see. At the end of Phase
3 give the human the build command (`scripts/build.sh`) and the Phase 4
tables.
