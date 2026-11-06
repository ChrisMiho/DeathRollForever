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

-- 03-in-progress (package 08): Lobby, Game.

-- Exact user-facing text of the lobby and rolling states (03-in-progress.md).
local LOBBY_STATUS = "Type %s in %s chat to join"
local STATUS_YOU = "You are up: /roll %d"
local STATUS_OTHER = "%s is up: /roll %d"
local ROLL_LABEL = "Roll 1-%d"
local VALUE_OUT = "out"
local VALUE_RANGE = "1-%d"

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

-- The rolling game: the order with each player's last roll, who is up, the
-- turn bar and the Roll button.
function View.Game(game, host, now)
	checkPhase(game, "rolling", "Game")
	local current, range = ns.Rules.Current(game)
	local secondsLeft, fraction = timeLeft(game.turnDeadline, now, game.turnTimer)

	local lastRoll = {} -- name -> their most recent roll
	for _, entry in ipairs(game.rolls) do
		lastRoll[entry.name] = entry.roll
	end

	local rows = {}
	for i, name in ipairs(game.order) do
		local out = game.status[name] ~= "in"
		local value
		if name == current then
			value = VALUE_RANGE:format(range)
		elseif out then
			value = VALUE_OUT
		elseif lastRoll[name] then
			value = tostring(lastRoll[name])
		else
			value = ""
		end
		rows[i] = {
			n = i,
			name = name,
			you = (name == host),
			current = (name == current),
			out = out,
			value = value,
		}
	end

	local status
	if current == host then
		status = STATUS_YOU:format(range)
	else
		status = STATUS_OTHER:format(current, range)
	end

	return {
		subtitle = View.Subtitle(game),
		rows = rows,
		status = status,
		secondsLeft = secondsLeft,
		fraction = fraction,
		button = { label = ROLL_LABEL:format(range), enabled = (current == host), range = range },
	}
end

-- 04-winner (package 09): Result.

-- Exact user-facing text of the winner state (04-winner.md).
local DEBT_TEXT = "%s owes %s"

-- The result: the winner and who owes what. One row per name in the order
-- that is not the winner; the host's row is marked (you).
function View.Result(game, host)
	checkPhase(game, "finished", "Result")
	local winner = game.winner
	local amount = ns.Money.Format(game.wager)
	local rows = {}
	for _, name in ipairs(game.order) do
		if name ~= winner then
			rows[#rows + 1] = { text = DEBT_TEXT:format(name, winner), you = (name == host), amount = amount }
		end
	end
	return {
		subtitle = View.Subtitle(game),
		winner = winner,
		rows = rows,
		total = ns.Money.Format(game.wager * #rows),
	}
end
