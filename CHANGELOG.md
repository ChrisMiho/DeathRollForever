# Changelog

All notable changes to this addon are listed here.
Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-11-10

Practise alone: `/dr solo 1g` (or `Solo` on the form) plays you against
bots, right in the window, with no guild or group needed. This release also
fixes the result view, which never showed the standings and made Reset
misbehave, and makes the host's own roll count for characters with a
surname.

### Added
- Solo games: play alone against bots, no guild or group needed. Type `/dr solo <wager> [roll max]` (10 bots) or pick `Solo` on the form and set `Bots` from 1 to 40. There is no join phase: you and the bots are in at once, every bot rolls within 5 seconds, you have 15 seconds to roll, and ties re-roll like a normal game. Bots get fun names from your faction (50 Horde, 50 Alliance). Nothing is posted to any chat; it all happens in the window.

### Fixed
- Rolls: the host's own roll now counts for characters with a surname. The addon read the host's name without the surname (`Forgot`) while the roll line has it (`Forgot Shards`), so the host's roll was ignored and the host sat out; the window now also shows the full name.
- Window: the result view is built again. Its winner name and roll were anchored to each other, which the client refuses, so building the window stopped there: the result had no standings or debt row, the window had no resize grip and the bars did not move smoothly, and every result printed `attempt to index field 'list'`.
- Host: an error inside the window no longer leaves the host holding a finished game, which made Reset flip back to the winner view every second; the error is now printed to the host's chat frame as `Window error (the game goes on in chat): ...` and the chat game carries on.

### Changed
- Rules: the join window is 45 seconds instead of 60 (the kickoff line, the form note and the lobby countdown say so); the countdown lines at 30, 15 and 5 are unchanged.

## [0.2.0] - 2026-11-06

One round instead of turns. Everyone rolls `/roll 100` once, the highest
roll wins and the lowest pays the difference: `(highest - lowest)` percent of
the wager with the default roll max of 100. Type `/dr` to open the window,
`/dr g 1g` to start from chat, `/dr help` for the commands and hover the `?`
in the window for the rules. This replaces the turn-based game of 0.1.0,
which played too slowly.

### Changed
- Rules: a game is now one round. Everyone rolls `/roll 100` once within 45 seconds; the highest roll wins, the lowest pays `(highest - lowest) x wager / roll max` (with the default roll max of 100, the gap as a percentage of the wager), anyone who does not roll sits out, an all-equal round is rerun, and ties for highest or lowest go to a tie-break roll among the tied only (a tied player who does not roll drops out, or pays if tied for lowest).
- Announcements: the `[DeathRoll]` chat lines now follow the one-round rules: the kickoff explains that everyone rolls once and the lowest pays the difference, one call tells everyone to roll with the seconds allowed, reminders list who is still to roll, players who miss the roll sit out, tie-breaks name the tied players, the winner line gives both rolls and the amount owed, and a tie-break nobody rolled cancels the game.
- Commands: `/dr g <wager> [roll max]` (and `/dr p`, `/dr r`) replaces the first-roll argument; the roll max is the top of the range everyone rolls, from 2 to 1000000, and the usage and error lines say so.
- Commands: `/dr` on its own now opens the window, `/dr help` lists the commands and `/dr show` is gone (it prints `Unknown command.` and the list).
- Window: a `?` in the title bar shows a `How it works` hover box with the one-round rules and the current join word and roll max; the form's `First roll` box is now `Roll max` (default `100`) with a hint under it, and the note says `45 s to roll`; the subtitle reads `roll 1-<max>`.
- Window: during a round the list shows who is still to roll dimmed at the top, the highest roll tinted with `highest` after the name, the lowest in its own colour under it with `lowest`, the rest fanned out from both ends and anyone who sat out last, with a `Rolled 3 of 5` header (or `Rolled again`, `Tie for highest`, `Tie for lowest`, `Tie for highest and lowest`), the tied players tagged `re-roll` or `re-rolled <n>`, an `Everyone: /roll 100` status line over the roll bar, and a `Roll 1-100` button that rolls once and stays gray until your roll arrives.
- Window: after a game the result view shows `WINNER` with the winner's name and their roll in the faction tint, the final standings (the winner tinted on top, the loser in the low colour under it, the rest fanned out, anyone who sat out dimmed and last) and one `<loser> owes <winner>` row with the amount under a line, in place of the `X owes Y` rows and the `Total`.

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
