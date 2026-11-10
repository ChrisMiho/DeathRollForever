# 06 Solo: practise alone against bots

Status: draft v3.1. Last verified against code: not yet. Owns `src/Solo.lua`, `spec/Solo_spec.lua`. Package 17.

## Purpose and scope

A solo game is a normal one-round death roll in which every other player is
a bot. Anyone can play one, alone, without a guild or a group: to learn the
game, or to test a release without a teammate. Nothing is posted to any chat
and nothing is printed to the chat frame; the game lives in the window only.

How it plays:

- No join phase. The game starts with the host and the bots already in and
  the roll called at once.
- The bots get random names from a list of 50 Horde and 50 Alliance names
  (below), from the host's own faction. Default 10 bots, 1 to 40.
- When the round starts, every bot rolls at its own random moment within
  the first 5 seconds. There is no call per bot and no order: the addon
  rolls for all of them on their own timers. The same goes for the tied
  bots in a tie-break and for everyone in an all-equal rerun. The host
  rolls themself, with `/roll <max>` or the window's Roll button.
- Everything else is a normal game (03-rules-engine): 15 seconds to roll
  instead of 45, a tie for highest or lowest re-rolls among the tied (bots
  re-roll on their own), an all-equal round is rerun, a host who does not
  roll sits out, the result shows who owes whom. No money changes hands:
  nobody else is there.

This module is the pure part: the names, picking the players and planning
the bots' rolls. The glue is in 05-host-controller (starting, not posting,
scheduling the rolls) and the window in visual/02-form (the `Solo` button
and the `Bots` box).

Out of scope: forcing an outcome (a tie, a bot that does not roll),
choosing bot names, solo games in chat, saving the bot count across
`/reload`.

## Depends on / blocks

Depends on: [contracts.md](../contracts.md) sections 2, 3, 5.3, 5.8;
03-rules-engine (`Rules.New` with `players`, `Rules.Waiting`).
Blocks: 05-host-controller and visual/02-form (both call `ns.Solo`).

## Behaviour

`rng(lo, hi)` is a function that returns a whole number from `lo` to `hi`
inclusive. The host passes `math.random`; tests pass a fake. `ns.Solo` is
the only module that uses randomness, and only through `rng`.

### Constants

```lua
Solo.BOTS = 10          -- bots when none are given (the slash command, an empty box)
Solo.MAX_BOTS = 40
Solo.ROLL_TIME = 15     -- seconds per round in a solo game; replaces Rules.DEFAULTS.rollTime
Solo.BOTS_ERROR = "Bots must be a whole number from 1 to 40"
Solo.NAMES = { Horde = { ... }, Alliance = { ... } }   -- the lists below, in that order
```

### `Solo.Players(host, faction, count, rng)`

1. `host` is a non-empty string; `count` is a whole number from 1 to
   `MAX_BOTS`. Anything else raises (programmer mistake: the box and the
   command are checked before this).
2. `pool` = `NAMES[faction]` for `"Horde"` or `"Alliance"`; for any other
   faction (`"Neutral"`, nil) the Horde list followed by the Alliance list.
   Leave out any name equal to `host`.
3. Pick `count` names from `pool` without repeats: a partial Fisher-Yates
   shuffle of a copy of `pool`, for `i = 1, count`: `j = rng(i, #pool)`,
   swap `i` and `j`, take `pool[i]`.
4. Return `{ host, <bot 1>, ..., <bot count> }`: the host first, then the
   bots in the order picked. This is the `players` list `Rules.New` takes
   and the join order of the game.

### `Solo.Plan(game, host, rng)`

The bots' rolls for the round that has just started.

1. `bots` = `Rules.Waiting(game)` without `host`, in that order.
2. For each bot: `delay = rng(1, 50) / 10` seconds (0.1 to 5.0) and `roll =
   rng(1, game.rollMax)`, drawn in that order, delay first.
3. Return `{ { name, delay, roll }, ... }` in the order of `bots`. Empty when
   nobody but the host is waiting (or the game is not rolling).

`Plan` changes nothing in `game`. The host calls it after every event list
that starts a round: `call` (the first round and an all-equal rerun) and
`tieBreak` (only the tied bots are waiting, so only they re-roll).

### Bot names

Every name is 3 to 12 letters, `A-Z` and `a-z` only, capital first, like a
character name. All 100 are different. They are made up for this addon.

Horde:

```
Gruntsalot   Axetastic    Zugzugson    Lokmotive    Moocifer
Hoofhearted  Steakholder  Udderchaos   Boneappetit  Ghoulfriend
Rotisserie   Deadpanned   Skelebrate   Mojoko       Voodoodle
Tuskany      Jinxalot     Trollercoast Hexpert      Gorechestra
Smashley     Grumpstump   Snortimer    Ridewolfie   Spikeasy
Orcward      Orcestra     Grubnub      Coinflipz    Profitbolt
Kaboomer     Fizzlefuse   Bloodelfie   Manaddict    Sunbeamz
Glitterbolt  Plaguey      Rotmuch      Grimgrin     Bonejangles
Totemtom     Earthquaker  Windfurry    Shamrockin   Drumthunder
Bigtusk      Tuskaloosa   Moosebumps   Hornswoggle  Lootandscoot
```

Alliance:

```
Shieldwally  Holypoly     Lightweight  Bubblehearth Hammersmash
Beardsley    Gnomebody    Gnomad       Sprocketz    Sparkplugg
Alewright    Stoutheart   Mugsy        Brewster     Pintsize
Moonfluff    Treehugz     Nightowlet   Starmuffin   Wispy
Stormwindy   Goldshirt    Footlooser   Knightlight  Squirebert
Lancelittle  Smitey       Holysmokes   Priestly     Frostbyte
Sheepish     Blinkster    Arcanewbie   Draeneigh    Goatmeal
Tentaclese   Crystalyn    Worgenstein  Furrball     Howlbert
Barkley      Muttonchops  Dwarvelous   Stoneface    Pickaxel
Rumbleton    Critcrumb    Bandaid      Tankyou      Healsalot
```

### Edge cases

- The host's name is one of the bot names: it is left out of the pool, so
  the game never has two players with the same name. With 40 bots and 49
  names left there is still room.
- A real player near the host types `/roll`: ignored, like any roll from
  someone who is not a roller. A real player who happens to share a bot's
  name could roll for that bot; the names are made up to make that
  unlikely, and nobody owes anything in a solo game.
- The host's own `/roll` in a solo game is still a real `/roll`: players
  standing nearby see it in their chat. Nothing else is visible to anyone.
- With 1 bot and a host who does not roll, one roll is left: the game is
  cancelled `tooFew`, as in any game.

## Exact user-facing text

| Where | Text |
|-------|------|
| `Solo.BOTS_ERROR` | `Bots must be a whole number from 1 to 40` |
| bot names | the two lists above |

The form's `Solo` button, `Bots` label and note are 02-form's; the help
line for `/dr solo` is 05's.

## Interfaces

Implements [contracts.md section 5.8](../contracts.md#58-nssolo). Uses
`Rules.Waiting`.

## Files

New `src/Solo.lua` and `spec/Solo_spec.lua`. `DeathRollForever.toc` gets
`src\Solo.lua` after `src\Rules.lua` (orchestrator). One line in
`CHANGELOG.md`.

## Acceptance criteria

### Automated (busted)

`seq(...)` is a fake `rng` that returns its arguments in order and raises
when it runs out; `low` is an `rng` that always returns `lo`.

| ID | Input | Expected |
|----|-------|----------|
| AC-17-01 | `Solo.NAMES` | 50 Horde and 50 Alliance names; all 100 different; each matches `^[A-Z][a-z]+$` with length 3 to 12 |
| AC-17-02 | `Players("Alice", "Horde", 3, low)` | `{ "Alice", "Gruntsalot", "Axetastic", "Zugzugson" }` |
| AC-17-03 | `Players("Alice", "Alliance", 2, seq(50, 2))` | `{ "Alice", "Healsalot", "Holypoly" }` |
| AC-17-04 | `Players("Alice", "Horde", 40, math.random)` | 41 names, `Alice` first, the other 40 different and all from the Horde list |
| AC-17-05 | `Players("Axetastic", "Horde", 40, low)` | 41 names; `Axetastic` only once, first; the third is `Zugzugson` |
| AC-17-06 | `Players("Alice", "Neutral", 1, seq(51))` and `Players("Alice", nil, 1, seq(100))` | `{ "Alice", "Shieldwally" }` and `{ "Alice", "Healsalot" }`: the pool is Horde then Alliance |
| AC-17-07 | `Players("Alice", "Horde", 0, low)`, `41`, `1.5`, `"3"`, and `Players("", "Horde", 3, low)` | each raises |
| AC-17-08 | a solo game from `Rules.New` with players `{ "Alice", "Bot1", "Bot2" }`, rollMax 100; `Plan(game, "Alice", seq(1, 40, 50, 100))` | `{ { name="Bot1", delay=0.1, roll=40 }, { name="Bot2", delay=5.0, roll=100 } }` |
| AC-17-09 | the same game after `Bot1` rolled | `Plan` gives one entry, for `Bot2` |
| AC-17-10 | a tie-break between `Alice` and `Bot2` | `Plan` gives one entry, for `Bot2` |
| AC-17-11 | a finished or cancelled game | `Plan` gives `{}` |
| AC-17-12 | `Plan` on any game | `game` is unchanged (deep compare before and after) |

### In-game (manual)

In 05-host-controller (IG-05-28 to IG-05-33) and visual/02-form
(IG-07-11 to IG-07-15).

## Mockup references

None. The form is described in visual/02-form.

## Open questions

None.
