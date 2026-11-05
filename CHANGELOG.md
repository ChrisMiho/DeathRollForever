# Changelog

All notable changes to this addon are listed here.
Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Project setup: packaging, libraries from Ace3, lint, unit tests and CI.
- Hello build: the addon loads, checks its libraries and answers `/dr`.
- Build script: one command makes a shareable zip and installs into the game.
- Wager amounts: `5`, `1.5g`, `1g 50s 45c` and the like are read as copper and shown back as `1g 50s 45c`.
- Chat parsing: join words, `/roll` results (names with spaces included) and `/dr g|p|r <wager> [first roll]` arguments are recognised.
- Game rules: lobby with join countdowns, shuffled turn order, turn reminders, forfeits on the turn timer, eliminations on a 1 and the winner's payout, as a pure state machine (no chat output yet).
- Announcements: the exact `[DeathRoll]` chat line for every game event (kickoff, countdowns, roll order, calls, reminders, eliminations, winner and cancellations).
