# Functional PRD

Status: draft v3 (one-round rules), replacing the v1 turn-based game. Last verified against code: not yet. The product overview is [PRD.md](../../PRD.md); this
document is the behaviour. Each feature's detail, text and acceptance
criteria is in a sub-document under [functional/](functional/).

## 1. The game in one paragraph

One player, the host, has the addon. They type `/dr g 100g` in a guild (or
`/dr p`, `/dr r` for party or raid), or fill in the window and click Start.
The addon posts a kickoff line. Anyone who types `1` in that chat within 45
seconds is in. The addon counts down, closes the lobby and tells everyone to
`/roll 100`. Each player rolls once within 45 seconds, with reminders naming
whoever has not rolled. Then the addon posts the result: the highest roll
wins, the lowest roll pays the winner the difference between the two rolls
as a share of the wager: 97 against 8 on 100g owes 89g. Anyone who did not
roll sat out and owes nothing. Two or more sharing the highest or the lowest
roll re-roll among themselves to decide who, never how much. Nothing is
stored, and nobody but the host needs anything installed.

## 2. Goals and non-goals

Goals
- A whole game runs from chat with only the host's addon.
- The chat lines alone are enough to follow and play.
- Every rule is testable without the game client.
- One round is quick: a game of ten takes about two minutes.

Non-goals (planned for later versions, see the
[roadmap](README.md#roadmap))
- Other addons seeing the game (sync).
- Tracking who has paid, trade detection, `/dr owed`.
- Settings, saved variables, history, stats, resuming after `/reload`.
- Auto-roll, kick, extend, `/dr join`.
- Several rounds per game, side bets.

## 3. Roles

| Role | Needs addon | What they do |
|------|-------------|--------------|
| Host | Yes | Starts the game with `/dr g 100g` or the window, can cancel. May also play by typing the join word |
| Player | No | Types the join word in chat, then `/roll 100` when called |

## 4. The game

### 4.1 Start

The host types `/dr g <wager> [roll max]` (or `p`, `r`, or the full words
`guild`, `party`, `raid`), or opens the window with `/dr` and clicks Start.
The wager is per person and accepts the forms in
[01-money](functional/01-money.md). The roll max defaults to 100. If the
host is not in that chat, a game is already running, or the arguments are
bad, the host sees a local message and nothing is posted.

The addon posts the kickoff line in that chat and starts a 45-second join
window.

### 4.2 Lobby

Anyone whose whole message in that chat is the join word `1` (spaces trimmed,
case ignored) is added in the order they typed it. The host joins the same
way, or does not join and only runs the game. Duplicate join words do nothing.
Countdown lines post at 30, 15 and 5 seconds left, each with the count and
names so far.

At 0, joining closes. Join words after that are ignored silently. With fewer
than 2 players the game is cancelled with a line saying so.

### 4.3 The round

With 2 or more players the addon posts one line listing everyone in join
order, then one line telling everyone to `/roll 100` within 45 seconds.
Every player rolls once. Only the first roll from each joined player with
exactly the range `1-100` counts; a roll from anyone else is ignored, and a
roll with another range gets a nudge repeating what to type. Reminders post
at 20, 10 and 5 seconds left, naming who has not rolled yet. The round ends
when the last player has rolled or the time runs out.

Players who did not roll sat out: a line names them, and they owe nothing
and win nothing. If fewer than 2 players rolled, the game is cancelled.

### 4.4 Result

The highest roll wins and the lowest roll pays. The loser owes the winner
`(highest - lowest) x wager / roll max`, rounded down to copper. With the
default roll max of 100 that is the gap in percent of the wager: 90 against
80 on 100g owes 10g; 99 against 2 owes 97g. The addon posts one line with
the winner, the loser, both rolls and the amount. The game is over; nothing
is remembered. There is more than one loser only when everyone tied for
lowest skipped the tie-break (4.5): each of them owes the full amount.

If every roll was the same, nobody won: the addon says so and everyone
rolls again.

### 4.5 Ties

Two or more players sharing the highest roll, or sharing the lowest, roll
again among themselves to decide who takes that spot; the original roll
still sets the amount. Both ends can be tied at once; the tied players on
both ends roll in the same 45-second tie-break. A tied player who does not
roll in time takes the worse outcome: in a tie for highest they drop out of
the running, in a tie for lowest they pay. Several no-shows on the low side
roll off against each other. If nobody tied for lowest rolls at all, they
all pay: each owes the winner the full amount. If nobody tied for highest
rolls at all, the game is cancelled with a line saying so.

A player who rolls the wrong range gets a whisper telling them the range
to roll; the game's chat sees nothing.

### 4.6 Cancel

`/dr cancel`, or the window's Cancel, ends the game at any point before the
result with one line in chat. With no game running, the host sees a local
message.

### 4.7 Rules summary

- Everyone rolls `1-<roll max>` once, within 45 seconds. Default roll max
  100.
- Highest wins, lowest pays `(highest - lowest) x wager / roll max`.
- No roll means sat out. Fewer than 2 rolls cancels.
- Ties at either end re-roll among the tied; the amount stays.
- One game per host at a time. Minimum 2 players. The host does not have
  to play.

### 4.8 Solo games (v3.1)

Anyone can play alone against bots: `/dr solo <wager> [roll max]`, or
`Solo` on the form with 1 to 40 bots (default 10). There is no join phase:
the game starts with you and the bots in and the roll called. The addon
rolls for every bot within 5 seconds of each round starting; you roll yourself. Rolls,
sat-outs, tie-breaks and the result follow the rules above, with 15 seconds
to roll. Nothing is posted to chat and nobody owes anything for real. Detail:
[06-solo](functional/06-solo.md).

## 5. Commands (`/dr` or `/deathroll`)

```
/dr                open the window
/dr g 100g         start in guild chat, 100g per person, everyone rolls 1-100
/dr p 50s          start in party chat, 50 silver per person
/dr r 1g50s 1000   start in raid chat, 1g 50s per person, everyone rolls 1-1000
/dr solo 1g        practise alone: you and 10 bots, in the window only
/dr guild 1g       same as /dr g; party and raid likewise
/dr cancel         host: cancel the game
/dr help           list these
```

Detail and local messages: [05-host-controller](functional/05-host-controller.md).

## 6. Defaults (constants in v3)

| Setting | Value |
|---------|-------|
| Join time | 45 s, countdown lines at 30, 15, 5 |
| Roll time | 45 s per round, reminders at 20, 10, 5, round ends at 0; 15 s in a solo game |
| Bots in a solo game | 10, from 1 to 40 |
| Roll max | 100 |
| Join word | `1` |
| Minimum players | 2 joined to start, 2 rolled to settle |
| Prefix | `[DeathRoll]` |

## 7. Phase 0 dependencies

The in-game checks were answered during v1 and v2; the answers are in
[contracts.md section 0](contracts.md#0-phase-0-dependencies). Every
decision that depends on one is tagged `[P0-ROLL]`, `[P0-POST]`,
`[P0-DISTANCE]` or `[P0-AUTOROLL]` in the feature documents. v3 needs no
new check.

## 8. Decisions log

| Date | Decision | Why |
|------|----------|-----|
| 2026-11-05 | Prefix is `[DeathRoll]` | Easy to scan for in busy chat |
| 2026-11-05 | Join words after close are ignored silently | They missed the boat; no whisper, no noise |
| 2026-11-05 | Paid notices (later) post to chat by default, behind a setting | Non-addon players only have chat |
| 2026-11-05 | Countdown at 30, 15, 5; reminders at 20, 10, 5 | Enough warning without spam |
| 2026-11-05 | Every call, reminder and nudge says what to type | Easy to follow as the numbers change |
| 2026-11-05 | No extend, no kick | The timer removes absent players; cancel is the one control a host cannot do without |
| 2026-11-05 | Specs live in docs/prd with a single map; CLAUDE.md links only the map | Keep agent context small |
| 2026-11-06 | One round replaces the turn-based death roll | The host played v2 and found turns too slow; one roll each keeps a group of ten under two minutes |
| 2026-11-06 | The loser owes `(highest - lowest) x wager / roll max` | The gap decides the stake: a close game costs little, a heartbreaker costs almost the whole wager |
| 2026-11-06 | Roll max is the old first-roll box, default 100 | With 100 the amount is a percentage; a host who wants finer odds sets 1000 |
| 2026-11-06 | Not rolling means sitting out, and fewer than 2 rolls cancels | Nobody pays for being away; one roll decides nothing |
| 2026-11-06 | Ties at the top or bottom re-roll among the tied; the amount stays | The host wanted forced re-rolls; the original roll is what everyone saw |
| 2026-11-06 | In a tie-break a no-show takes the worse outcome; a side nobody rolls cancels | No way to dodge a low tie by going quiet; no endless re-rolls among the absent |
| 2026-11-11 | When nobody tied for lowest rolls the tie-break, they all pay the full amount; only a high side nobody rolls still cancels | Two players tied for lowest could cancel the debt by both going quiet |
| 2026-11-11 | A wrong range is whispered to the player, not posted | Assumes an honest slip, keeps the chat clean, and someone who spams wrong rolls only spams themself |
| 2026-11-11 | A chat line that would pass 255 characters gives a count instead of the names | Big guild games would cut lines off; the window still shows every name |
| 2026-11-11 | Players are matched by character name, without the Forever surname or realm, and shown with the surname once seen | Joins come from the chat sender, rolls from the roll line; only the character name is in both. The host wanted surnames kept on screen |
| 2026-11-06 | An all-equal round is rerun | Nobody can win or lose on a gap of zero |
| 2026-11-06 | Roll time 45 s with reminders naming who has not rolled | Same pace as the old turn; the names make the call-out easy |
| 2026-11-06 | `/dr` opens the window; `/dr help` lists the commands | The host found `/dr show` awkward; the window is the common case |
| 2026-11-10 | Solo games against bots, for everyone, in the window only | Testing needed a teammate every time; players can practise too. Posting a solo game to chat would only be noise |
| 2026-11-10 | Solo has no join phase and 15 s to roll | Nobody to wait for; a test round takes seconds |
| 2026-11-10 | Bots get fun faction names from a fixed list of 50 Horde and 50 Alliance | Clearly fake, and fun to read |
| 2026-11-10 | Solo is a fourth chat button on the form, not a checkbox or a tab | It answers the same question as Guild, Party and Raid: where the game is played |
