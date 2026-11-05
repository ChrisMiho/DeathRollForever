# DeathRollForever

A World of Warcraft: Forever addon for running multiplayer death roll events
in party, raid or guild chat. Only the host needs the addon; everyone else
plays by typing in chat and using `/roll`.

Status: early development. See [PRD.md](PRD.md) for the full design.

## Install (players)

1. Download the latest `DeathRollForever-<version>.zip` from the
   [Releases](../../releases) page.
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\`, so you end up
   with `...\AddOns\DeathRollForever\DeathRollForever.toc`.
3. Restart the game or type `/reload`.

Do not use GitHub's green "Code > Download ZIP" button: that copy has no
libraries in it and will not load.

## Development

### Tools

- Git and the GitHub CLI
- VS Code with the extensions in `.vscode/extensions.json`
- LuaJIT and LuaRocks (Lua 5.1, same as the game)
- `luarocks install luacheck` and `luarocks install busted`
- Git Bash (comes with Git for Windows) for the scripts in `scripts/`

### First-time setup

```bash
scripts/fetch-libs.sh
```

This fetches the libraries listed in `.pkgmeta` into `Libs/` (git-ignored).
Then link the project into the game's AddOns folder, from an admin PowerShell:

```powershell
New-Item -ItemType Junction -Path "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\DeathRollForever" -Target "C:\Coding\DeathRollForever"
```

### Everyday checks

```bash
luacheck .
busted
```

CI runs the same two commands on every push and pull request.

### Layout

| Path | What it is |
|------|------------|
| `DeathRollForever.toc` | Addon manifest: load order, version |
| `embeds.xml` | Loads the libraries from `Libs/` |
| `src/` | Addon code. Pure logic files have no WoW API calls and are unit tested |
| `spec/` | busted unit tests |
| `scripts/` | Developer scripts (not shipped) |
| `.pkgmeta` | Packager config: libraries and files to leave out of the zip |

### Releasing

1. Move the `Unreleased` notes in `CHANGELOG.md` under a new version heading.
2. Commit, then tag and push:

   ```bash
   git tag -a v0.1.0 -m "v0.1.0"
   git push origin main --follow-tags
   ```

3. The Release workflow builds the zip and attaches it to a GitHub release.

### Updating libraries

Libraries are pinned to an Ace3 release tag in `.pkgmeta`. To update, change
the tags to the newest one at <https://github.com/WoWUIDev/Ace3/tags>, run
`scripts/fetch-libs.sh`, and test in game before releasing.

## Credits

Uses [Ace3](https://github.com/WoWUIDev/Ace3) libraries (LibStub,
CallbackHandler-1.0, AceComm-3.0 with ChatThrottleLib) under their own licence.

## Licence

MIT. See [LICENSE](LICENSE).
