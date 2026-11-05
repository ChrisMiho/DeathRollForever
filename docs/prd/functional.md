# Functional PRD

Status: draft v1. The product overview is [PRD.md](../../PRD.md); this
document is the behaviour. Each feature's detail, text and acceptance
criteria is in a sub-document under [functional/](functional/).

## 1. v1 in one paragraph

One player, the host, has the addon. They type `/dr g 1g` in a guild (or
`/dr p`, `/dr r` for party or raid). The addon posts a kickoff line. Anyone who
types `1` in that chat within 60 seconds is in. The addon counts down, shuffles
the players once, posts the order, and calls the first player with exactly what
to type. Each player rolls in turn with `/roll <range>`; the next range is the
previous roll. Rolling a 1 knocks you out and the range resets. Not rolling
within 45 seconds knocks you out and the range carries on. The last player
standing wins, and the addon posts who owes the winner how much. Nothing is
stored, and nobody but the host needs anything installed.

## 2. Goals and non-goals for v1

Goals
- A whole game runs from chat with only the host's addon.
- The chat lines alone are enough to follow and play.
- Every rule is testable without the game client.

Non-goals for v1 (planned for later versions, see the
[roadmap](README.md#roadmap))
- A window of any kind.
- Other addons seeing the game (sync).
- Tracking who has paid, trade detection, `/dr owed`.
- Settings, saved variables, history, stats, resuming after `/reload`.
- Auto-roll, kick, extend, `/dr join`.

## 3. Roles

| Role | Needs addon | What they do |
|------|-------------|--------------|
| Host | Yes | Starts the game with `/dr g 1g`, can cancel. May also play by typing the join word |
| Player | No | Types the join word in chat, then `/roll N` when called |

## 4. The game

### 4.1 Start

The host types `/dr g <wager> [first roll]` (or `p`, `r`, or the full words
`guild`, `party`, `raid`). The wager is per person and accepts the forms in
[01-money](functional/01-money.md). The first roll defaults to 1000. If the
host is not in that chat, a game is already running, or the arguments are
bad, the host sees a local message and nothing is posted.

The addon posts the kickoff line in that chat and starts a 60-second join
window.

### 4.2 Lobby

Anyone whose whole message in that chat is the join word `1` (spaces trimmed,
case ignored) is added in the order they typed it. The host joins the same
way, or does not join and only runs the game. Duplicate join words do nothing.
Countdown lines post at 30, 15 and 5 seconds left, each with the count and
names so far.

At 0, joining closes. Join words after that are ignored silently. With fewer
than 2 players the game is cancelled with a line saying so.

### 4.3 Close and order

With 2 or more players the addon posts one line listing everyone in join
order, shuffles them once, posts the roll order, and calls the first player.
The order never changes after this.

### 4.4 Turns

A call tells the player what to type: `Carl, you're up! Type /roll 1000`.
Only a roll from the called player with exactly the range `1-<range>` counts.
A roll from anyone else is ignored. A roll from the called player with any
other range gets a nudge repeating what to type, every time.

After a valid roll above 1, the next player in order (wrapping, skipping
eliminated players) is called with that roll as the new range. Rolling 1
eliminates the roller; the range resets to the first roll and the next player
is called.

Each turn has 45 seconds. Reminders post at 20, 10 and 5 seconds left, each
repeating what to type. At 0 the player forfeits and is out; the range stays
where it was and the next player is called with it.

### 4.5 Winner

When one player is left, the addon posts the winner and the ledger: every
eliminated player owes the winner the wager, with the total. The game is over.
v1 remembers nothing.

### 4.6 Cancel

`/dr cancel` ends the game at any point before the winner with one line in
chat. With no game running, the host sees a local message.

### 4.7 Rules summary

- First roll: the start number (default 1000). Each next roll: 1 to the
  previous result.
- Order: shuffled once at close, then fixed. Round robin: everyone alive rolls
  once before anyone rolls again.
- Out by rolling 1: the range resets. Out by timer: the range carries over.
- One game per host at a time.
- Minimum 2 players. The host does not have to play.

## 5. Commands (`/dr` or `/deathroll`)

```
/dr g 1g           start in guild chat, 1g per person, first roll 1-1000
/dr p 50s          start in party chat, 50 silver per person
/dr r 1g50s 500    start in raid chat, 1g 50s per person, first roll 1-500
/dr guild 1g       same as /dr g; party and raid likewise
/dr cancel         host: cancel the game
/dr help           list these; a bare /dr does the same
```

Detail and local messages: [05-host-controller](functional/05-host-controller.md).

## 6. Defaults (constants in v1)

| Setting | Value |
|---------|-------|
| Join time | 60 s, countdown lines at 30, 15, 5 |
| Turn timer | 45 s, reminders at 20, 10, 5, forfeit at 0 |
| First roll | 1000 |
| Join word | `1` |
| Minimum players | 2 |
| Prefix | `[DeathRoll]` |

## 7. Phase 0 dependencies

Four in-game checks must be answered before some of v1 can be finished. They
are listed in [orchestration.md](orchestration.md#phase-0-in-game-checks) and
every decision that depends on one is tagged `[P0-ROLL]`, `[P0-POST]`,
`[P0-DISTANCE]` or `[P0-AUTOROLL]` in the feature documents.

## 8. Decisions log

| Date | Decision | Why |
|------|----------|-----|
| 2026-11-05 | Turn timer defaults to 45 s with forfeit at 0 | Keeps the game moving without the host babysitting |
| 2026-11-05 | Order is shuffled once at close, then fixed; round robin | Fair first-roll risk; everyone rolls once per round |
| 2026-11-05 | Prefix is `[DeathRoll]` | Easy to scan for in busy chat |
| 2026-11-05 | Join words after close are ignored silently | They missed the boat; no whisper, no noise |
| 2026-11-05 | Paid notices (v4) post to chat by default, behind a setting | Non-addon players only have chat |
| 2026-11-05 | Forfeit and kick carry the range over; rolling 1 resets it | Players would not appreciate a reset handed to the next person |
| 2026-11-05 | v1 is chat only: no window, no sync, no ledger, no settings | Get a whole game running first, then add features one by one |
| 2026-11-05 | Countdown at 30, 15, 5; reminders at 20, 10, 5 | Enough warning without spam |
| 2026-11-05 | Every call, reminder and nudge says what to type | Easy to follow as the numbers change |
| 2026-11-05 | Close posts who joined and then the roll order as two lines | Players can check they got in and see the shuffle |
| 2026-11-05 | No extend, no kick in v1 | The timer removes absent players; cancel is the one control a host cannot do without |
| 2026-11-05 | Specs live in docs/prd with a single map; CLAUDE.md links only the map | Keep agent context small |
