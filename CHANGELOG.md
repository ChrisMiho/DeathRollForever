# Changelog

All notable changes to this addon are listed here.
Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Window: `/dr show` opens a movable, resizable window with a faction-tinted title bar, an `×` (or `Cancel` while a game runs) in the corner, one main button and the faction name under it; it follows every game and cannot be hidden mid-game.

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
