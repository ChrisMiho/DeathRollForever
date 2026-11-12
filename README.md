# DeathRollForever

A World of Warcraft: Forever addon for running multiplayer death roll events
in party, raid or guild chat. Only the host needs the addon; everyone else
plays by typing in chat and using `/roll`.

Status: v0.4.0, one round where everyone rolls once and the lowest pays the difference, run from chat or the host's window, plus solo games against bots (`/dr solo 1g`). See [PRD.md](PRD.md) for the full design and roadmap.

Guild games: the host only sees `/roll` results from players in the same area
or in the same group. For a guild game, invite the players to a raid so rolls
from anywhere are seen.

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

### Build

In VS Code press `Ctrl+Shift+B` (task "Build and install"), or from Git Bash:

```bash
scripts/build.sh
```

Each build runs the same packager as a release. It fetches the libraries
listed in `.pkgmeta`, then:

1. writes `.release/DeathRollForever-<version>.zip`, which holds one
   `DeathRollForever` folder that teammates unzip into `Interface\AddOns`, and
2. replaces `Interface\AddOns\DeathRollForever` in your game with the build.
   Type `/reload` in game to load it.

`scripts/build.sh --no-install` (task "Build zip only") skips step 2. If your
game is not in the default folder, set `WOW_ADDONS_DIR` to your `AddOns` path.

The version is the git tag on a tagged commit, or the short commit hash
otherwise. New files must be `git add`ed before they appear in a build; the
script warns about any that are not.

### Everyday checks

```bash
luacheck .
busted
```

In VS Code these are the "Lint and test" task. CI runs the same two commands on
every push and pull request.

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
`scripts/build.sh`, and test in game before releasing.

## Credits

Uses [Ace3](https://github.com/WoWUIDev/Ace3) libraries (LibStub,
CallbackHandler-1.0, AceComm-3.0 with ChatThrottleLib) under their own licence.

## Licence

MIT. See [LICENSE](LICENSE).
