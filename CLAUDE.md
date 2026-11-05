# DeathRollForever

World of Warcraft: Forever addon (Lua 5.1, Interface 16001) that runs death
roll events in party, raid or guild chat. `PRD.md` is the product overview.

## Specs

Behaviour is specified under `docs/prd/`. Start at `docs/prd/README.md`: it
maps every `src/` file to the document that owns it. Load that document and
`docs/prd/contracts.md`, and nothing else from the folder. A change to
behaviour is not done until the owning document agrees with the code, and a
change to `contracts.md` needs the human's approval.

## Commands

Run from the repo root. On Windows, `.sh` scripts need Git Bash.

| Task | Command |
|------|---------|
| Lint | `luacheck .` |
| Unit tests | `busted` |
| Build, zip and install into the game | `scripts/build.sh` |
| Build and zip only (no game install) | `scripts/build.sh --no-install` |

Lint and tests must pass before you call work done; CI runs both on every push.
The build output goes to `.release/` (git-ignored).

## Layout

| Path | Purpose |
|------|---------|
| `DeathRollForever.toc` | Load order. Every new `src/` file must be listed here |
| `embeds.xml` | Loads libraries from `Libs/` |
| `src/` | Addon code |
| `spec/` | busted tests, one `<Module>_spec.lua` per module |
| `scripts/` | Developer scripts (not shipped) |
| `.pkgmeta` | Libraries (externals) and files left out of the package |

## Code rules

- **Every file starts with `local addonName, ns = ...`** (or `local _, ns = ...`).
  Share code through `ns`, never through new globals.
- **Keep pure logic separate from game code.** Rules, parsing, formatting and
  ledger maths go in modules that call no WoW API (like `src/Chat.lua`) and get
  busted tests. Code that touches frames, events, chat or the WoW API stays in
  thin glue files (like `src/Init.lua`).
- **Test pure modules through `LoadAddonFile`** (from `spec/helper.lua`), which
  loads a file the way the game does: `LoadAddonFile("src/Chat.lua").Chat`.
- **Declare every WoW API you use** in `read_globals` in `.luacheckrc`, and every
  global you create in `globals`. That way lint catches typos in API names.
- **Money is stored as an integer number of copper** (PRD section 4, Wager
  amounts).
- Tabs for Lua indentation; see `.editorconfig`.

## Dependencies

- Libraries (LibStub, CallbackHandler-1.0, AceComm-3.0) come from `.pkgmeta`,
  pinned to an Ace3 release tag. Never commit `Libs/`, and never copy library
  code into `src/`.
- A new library goes in `.pkgmeta` (pinned to a tag) and `embeds.xml`.
- Newly created files are left out of builds until they are `git add`ed.

## Things only a human can check

Anything that needs the game client: how frames look, chat output, rolls, trade
detection, addon messages between players. When a task depends on one of these,
finish the parts you can test, then list exactly what the user should try in
game and what they should expect to see.

## Changes and releases

- Add a line under `## [Unreleased]` in `CHANGELOG.md` for each user-facing change.
- Releases are made by pushing a `v*` tag (see README). Do not tag or push
  unless asked.
