local _, ns = ...

-- View: pure view models for the host's window. No WoW API here.
-- Spec: docs/prd/visual/01-window.md to 04-winner.md, one section each.
-- Other modules (ns.Money) are called only inside functions, never at load.

local View = {}
ns.View = View

-- 01-window (package 14): TINT, State, ChatName, Subtitle, Help.

-- Faction tints, 0..1 rgb (contracts 5.6, visual.md 4.2).
-- title: title bar, highest row; button: main button, bar fill;
-- text: big numbers, status line; low: lowest row.
View.TINT = {
	Alliance = {
		title = { 0.114, 0.302, 0.690 },
		button = { 0.165, 0.388, 0.847 },
		text = { 0.553, 0.706, 1.000 },
		low = { 0.431, 0.133, 0.133 },
	},
	Horde = {
		title = { 0.490, 0.110, 0.110 },
		button = { 0.831, 0.231, 0.231 },
		text = { 1.000, 0.612, 0.612 },
		low = { 0.420, 0.290, 0.102 },
	},
}

-- The hover box under the title bar's `?` (01-window.md), one format per
-- line. %s is the join word, %d the roll max.
local HELP_LINES = {
	"Type %s in chat to join.",
	"When called, everyone types /roll %d once.",
	"Highest roll wins, lowest roll pays.",
	"Owed: (highest - lowest) x wager / %d.",
	"A tie for highest or lowest re-rolls.",
	"No roll in time: you sit out.",
}

local STATE_BY_PHASE = {
	lobby = "lobby",
	rolling = "rolling",
	finished = "winner",
}

local CHAT_NAME = {
	GUILD = "guild",
	PARTY = "party",
	RAID = "raid",
}

-- "form" | "lobby" | "rolling" | "winner". nil or a cancelled game is "form".
function View.State(game)
	if not game then
		return "form"
	end
	return STATE_BY_PHASE[game.phase] or "form"
end

function View.ChatName(channel)
	return CHAT_NAME[channel]
end

-- "Raid chat, 100g per person, roll 1-100"
function View.Subtitle(game)
	local chat = View.ChatName(game.channel)
	chat = chat:sub(1, 1):upper() .. chat:sub(2)
	return chat .. " chat, " .. ns.Money.Format(game.wager) .. " per person, roll 1-" .. game.rollMax
end

-- The six lines of the hover box, in order, with the join word and roll max
-- filled in.
function View.Help(joinWord, rollMax)
	return {
		HELP_LINES[1]:format(joinWord),
		HELP_LINES[2]:format(rollMax),
		HELP_LINES[3],
		HELP_LINES[4]:format(rollMax),
		HELP_LINES[5],
		HELP_LINES[6],
	}
end

-- 02-form (package 14): StartOpts.

local COMMAND_KEY = {
	GUILD = "g",
	PARTY = "p",
	RAID = "r",
}

-- The form's three inputs as the opts Parse.StartArgs returns:
-- { channel, wager, rollMax } or nil, errorText. The wager is passed whole
-- (Money.Parse accepts "1g 50s"); the roll max is trimmed and left out when
-- empty. Any other channel is a programmer mistake.
function View.StartOpts(channel, wagerText, rollMaxText)
	local key = COMMAND_KEY[channel]
	if not key then
		error("StartOpts: unknown channel " .. tostring(channel), 2)
	end
	local args = { wagerText }
	local rollMax = (rollMaxText or ""):match("^%s*(.-)%s*$")
	if rollMax ~= "" then
		args[2] = rollMax
	end
	return ns.Parse.StartArgs(key, args)
end

-- 03-in-progress (package 15): Lobby, Game.

-- Exact user-facing text of the lobby and rolling states (03-in-progress.md).
local LOBBY_STATUS = "Type %s in %s chat to join"
local ROLL_LABEL = "Roll 1-%d"
local HEADER_COUNT = "%d of %d"
local HEADER_ROLLED = "Rolled"
local HEADER_ROLLED_AGAIN = "Rolled again"
local HEADER_TIE_HIGH = "Tie for highest"
local HEADER_TIE_LOW = "Tie for lowest"
local HEADER_TIE_BOTH = "Tie for highest and lowest"
local STATUS_EVERYONE = "Everyone: /roll %d"
local STATUS_EVERYONE_AGAIN = "Everyone: /roll %d again"
local STATUS_TIE = "%s: /roll %d again"
local VALUE_WAITING = "waiting"
local VALUE_SAT_OUT = "sat out"
local TAG_HIGHEST = "highest"
local TAG_LOWEST = "lowest"
local TAG_REROLL = "re-roll"
local TAG_REROLLED = "re-rolled %d"

local function checkPhase(game, phase, fn)
	if type(game) ~= "table" or game.phase ~= phase then
		error(("View.%s: game must be in phase %s, got %s"):format(fn, phase, tostring(game and game.phase)), 3)
	end
end

-- Seconds left to a deadline, rounded up, never negative; and the fraction of
-- the whole span still left, clamped to 0..1.
local function timeLeft(deadline, now, span)
	local left = deadline - now
	local secondsLeft = math.max(0, math.ceil(left))
	local fraction = math.max(0, math.min(1, left / span))
	return secondsLeft, fraction
end

-- The lobby: countdown, join bar and who joined.
function View.Lobby(game, host, now)
	checkPhase(game, "lobby", "Lobby")
	local secondsLeft, fraction = timeLeft(game.joinDeadline, now, game.joinTime)
	local rows = {}
	for i, name in ipairs(game.joined) do
		rows[i] = { n = i, name = name, you = (name == host) }
	end
	return {
		subtitle = View.Subtitle(game),
		secondsLeft = secondsLeft,
		fraction = fraction,
		count = #game.joined,
		rows = rows,
		status = LOBBY_STATUS:format(game.joinWord, View.ChatName(game.channel)),
	}
end

local function contains(list, name)
	for _, v in ipairs(list or {}) do
		if v == name then
			return true
		end
	end
	return false
end

-- `names` reordered from both ends: the first, the last, the second, the
-- second last, and so on, until the list is used up.
local function fanOut(names)
	local out = {}
	local i, j = 1, #names
	while i <= j do
		out[#out + 1] = names[i]
		if i < j then
			out[#out + 1] = names[j]
		end
		i, j = i + 1, j - 1
	end
	return out
end

-- The standings of a game's main-round rolls as rows { name, you, value,
-- mark } without tags, in the order every list shows them (03-in-progress,
-- row groups 2 to 5, and 04-winner's Result as the final standings):
--   2. highest: the current tie-break's high side, else the winner once
--      decided, else everyone on the largest roll, in joined order;
--   3. lowest: the tie-break's low side, else the loser once decided, else
--      everyone on the smallest roll who is not already highest;
--   4. the rest: everyone else in game.rolls, sorted highest first (ties in
--      joined order) and fanned out from both ends;
--   5. sat out: game.satOut, dimmed, with "sat out" as the value.
-- The waiting group (1) is Game's own: it only exists in a main round.
local function standings(game, host)
	local rolls = game.rolls
	local tie = game.tie or {}

	local rolled = {} -- names in rolls, in joined order
	local high, low
	for _, name in ipairs(game.joined) do
		local roll = rolls[name]
		if roll ~= nil then
			rolled[#rolled + 1] = name
			high = (high == nil or roll > high) and roll or high
			low = (low == nil or roll < low) and roll or low
		end
	end

	local function onRoll(roll, except)
		local names = {}
		for _, name in ipairs(rolled) do
			if rolls[name] == roll and not contains(except, name) then
				names[#names + 1] = name
			end
		end
		return names
	end

	local highest
	if tie.high then
		highest = tie.high
	elseif game.winner then
		highest = { game.winner }
	else
		highest = onRoll(high)
	end
	local lowest
	if tie.low then
		lowest = tie.low
	elseif game.loser then
		lowest = { game.loser }
	else
		lowest = onRoll(low, highest)
	end

	local rest = {}
	for _, name in ipairs(rolled) do
		if not contains(highest, name) and not contains(lowest, name) then
			rest[#rest + 1] = name
		end
	end
	local joinedIndex = {}
	for i, name in ipairs(game.joined) do
		joinedIndex[name] = i
	end
	table.sort(rest, function(a, b)
		if rolls[a] ~= rolls[b] then
			return rolls[a] > rolls[b]
		end
		return joinedIndex[a] < joinedIndex[b]
	end)

	local rows = {}
	local function add(names, mark, value)
		for _, name in ipairs(names) do
			rows[#rows + 1] = {
				name = name,
				you = (name == host),
				value = value or tostring(rolls[name]),
				mark = mark,
			}
		end
	end
	add(highest, "high")
	add(lowest, "low")
	add(fanOut(rest), "")
	add(game.satOut, "out", VALUE_SAT_OUT)
	return rows
end

-- The tag of a standings row during a round: a tied player's re-roll state,
-- else highest / lowest for those rows, else nothing.
local function roundTag(game, row)
	if row.mark ~= "high" and row.mark ~= "low" then
		return ""
	end
	local tie = game.tie
	if tie and (contains(tie.high, row.name) or contains(tie.low, row.name)) then
		local reroll = game.tieRolls[row.name]
		if reroll ~= nil then
			return TAG_REROLLED:format(reroll)
		end
		return TAG_REROLL
	end
	if row.mark == "high" then
		return TAG_HIGHEST
	end
	return TAG_LOWEST
end

local function headerLabel(game)
	local tie = game.tie
	if tie then
		if tie.high and tie.low then
			return HEADER_TIE_BOTH
		elseif tie.high then
			return HEADER_TIE_HIGH
		end
		return HEADER_TIE_LOW
	end
	if game.round > 1 then
		return HEADER_ROLLED_AGAIN
	end
	return HEADER_ROLLED
end

local function roundStatus(game)
	if game.tie then
		return STATUS_TIE:format(table.concat(game.rollers, ", "), game.rollMax)
	end
	if game.round > 1 then
		return STATUS_EVERYONE_AGAIN:format(game.rollMax)
	end
	return STATUS_EVERYONE:format(game.rollMax)
end

-- The rolling round: who is still to roll, the standings so far, the roll
-- bar and the Roll button.
function View.Game(game, host, now)
	checkPhase(game, "rolling", "Game")
	local waiting = ns.Rules.Waiting(game)
	local secondsLeft, fraction = timeLeft(game.rollDeadline, now, game.rollTime)

	local rows = {}
	if not game.tie then
		for _, name in ipairs(waiting) do
			rows[#rows + 1] = { name = name, you = (name == host), value = VALUE_WAITING, tag = "", mark = "waiting" }
		end
	end
	for _, row in ipairs(standings(game, host)) do
		row.tag = roundTag(game, row)
		rows[#rows + 1] = row
	end

	return {
		subtitle = View.Subtitle(game),
		header = {
			label = headerLabel(game),
			count = HEADER_COUNT:format(#game.rollers - #waiting, #game.rollers),
		},
		rows = rows,
		status = roundStatus(game),
		secondsLeft = secondsLeft,
		fraction = fraction,
		button = {
			label = ROLL_LABEL:format(game.rollMax),
			enabled = contains(waiting, host),
			max = game.rollMax,
		},
	}
end

-- 04-winner (package 16): Result.

-- Exact user-facing text of the winner state (04-winner.md).
local DEBT_TEXT = "%s owes %s"

-- The result: the winner and their roll, the final standings and the one
-- debt. The rows are the standings above (the winner highest, the loser
-- lowest, the rest fanned out, the sat out last); the debt is what the loser
-- owes the winner, marked (you) when the host is the loser.
function View.Result(game, host)
	checkPhase(game, "finished", "Result")
	return {
		subtitle = View.Subtitle(game),
		winner = game.winner,
		winningRoll = tostring(game.high),
		rows = standings(game, host),
		debt = {
			text = DEBT_TEXT:format(game.loser, game.winner),
			you = (game.loser == host),
			amount = ns.Money.Format(game.owed),
		},
	}
end
