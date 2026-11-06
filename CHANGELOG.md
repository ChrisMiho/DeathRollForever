# Changelog

All notable changes to this addon are listed here.
Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Commands: `/dr g <wager> [roll max]` (and `/dr p`, `/dr r`) replaces the first-roll argument; the roll max is the top of the range everyone rolls, from 2 to 1000000, and the usage and error lines say so.
- Announcements: the `[DeathRoll]` chat lines now follow the one-round rules: the kickoff explains that everyone rolls once and the lowest pays the difference, one call tells everyone to roll with the seconds allowed, reminders list who is still to roll, players who miss the roll sit out, tie-breaks name the tied players, the winner line gives both rolls and the amount owed, and a tie-break nobody rolled cancels the game.

## [0.1.0] - 2026-11-06

The host's window. Type `/dr show` to open it: fill in the chat, wager and
first roll and click `Start` instead of typing `/dr g 1g`, watch the lobby
countdown and who joined, follow the roll order with each player's last
roll, and click `Roll` on your turn to roll the right range. The window
turns blue or red for your faction. Every `/dr` command still works.

### Added
- Window: `/dr show` opens a movable, resizable window with a faction-tinted title bar, an `×` (or `Cancel` while a game runs) in the corner, one main button and the faction name under it; it follows every game and cannot be hidden mid-game.
- Form: with no game running the window shows `Chat` (Guild, Party, Raid), `Wager per person` and `First roll` with a `Start` button that does what `/dr g <wager> [first roll]` does; Enter in a box also starts, errors print to the chat frame and the values stay for the next game.
- In progress: during the lobby the window shows the join countdown, a shrinking bar and who joined; during rolling the shuffled order with each player's last roll (`out` struck through for the eliminated), who is up and what to type, a turn bar, and a `Roll 1-<range>` button that is gray until your turn and then rolls the right range for you.
- Winner: when a game ends the window shows `WINNER` with the name in the faction tint, one `X owes Y` row per loser with the wager (and `(you)` on your own debt) and a `Total` row, until `Reset` returns to the form with the values from before the game.

## [0.0.1] - 2026-11-05

First playable release. Only the host needs the addon; everyone else plays by
typing in chat and using `/roll`. Type `/dr g 1g` (or `/dr p`, `/dr r`) to run
a death roll in guild, party or raid chat: players type `1` to join during a
60-second lobby with countdowns, the addon shuffles the order, calls each
player in turn with the range to roll, reminds them, forfeits anyone who
waits too long, knocks out whoever rolls 1, and names the winner with who
owes what. `/dr cancel` stops a game, `/dr help` lists the commands. In a
guild game, group the players in a raid so rolls from far away are seen.

### Added
- Project setup: packaging, libraries from Ace3, lint, unit tests and CI.
- Hello build: the addon loads, checks its libraries and answers `/dr`.
- Build script: one command makes a shareable zip and installs into the game.
- Wager amounts: `5`, `1.5g`, `1g 50s 45c` and the like are read as copper and shown back as `1g 50s 45c`.
- Chat parsing: join words, `/roll` results (names with spaces included) and `/dr g|p|r <wager> [first roll]` arguments are recognised.
- Game rules: lobby with join countdowns, shuffled turn order, turn reminders, forfeits on the turn timer, eliminations on a 1 and the winner's payout, as a pure state machine (no chat output yet).
- Announcements: the exact `[DeathRoll]` chat line for every game event (kickoff, countdowns, roll order, calls, reminders, eliminations, winner and cancellations).
- Host controller: `/dr g|p|r <wager> [first roll]` runs a game in guild, party or raid chat (join words and `/roll` results are read from chat, every announcement is posted), `/dr cancel` stops it and `/dr help` lists the commands.
