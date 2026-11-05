local _, ns = ...

-- View: pure view models for the host's window. No WoW API here.
-- Spec: docs/prd/visual/01-window.md to 04-winner.md, one section each.
-- Other modules (ns.Money) are called only inside functions, never at load.

local View = {}
ns.View = View

-- 01-window (package 06): TINT, State, ChatName, Subtitle.

-- Faction tints, 0..1 rgb (contracts 5.6, visual.md 4.2).
-- title: title bar, current row; button: main button, bar fill;
-- text: big numbers, status line.
View.TINT = {
	Alliance = {
		title = { 0.114, 0.302, 0.690 },
		button = { 0.165, 0.388, 0.847 },
		text = { 0.553, 0.706, 1.000 },
	},
	Horde = {
		title = { 0.490, 0.110, 0.110 },
		button = { 0.831, 0.231, 0.231 },
		text = { 1.000, 0.612, 0.612 },
	},
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

-- "Raid chat, 1g per person, first roll 1-1000"
function View.Subtitle(game)
	local chat = View.ChatName(game.channel)
	chat = chat:sub(1, 1):upper() .. chat:sub(2)
	return chat .. " chat, " .. ns.Money.Format(game.wager) .. " per person, first roll 1-" .. game.startRoll
end

-- 02-form (package 07): StartOpts.

local COMMAND_KEY = {
	GUILD = "g",
	PARTY = "p",
	RAID = "r",
}

-- The form's three inputs as the opts Parse.StartArgs returns:
-- { channel, wager, startRoll } or nil, errorText. The wager is passed whole
-- (Money.Parse accepts "1g 50s"); the first roll is trimmed and left out when
-- empty. Any other channel is a programmer mistake.
function View.StartOpts(channel, wagerText, startRollText)
	local key = COMMAND_KEY[channel]
	if not key then
		error("StartOpts: unknown channel " .. tostring(channel), 2)
	end
	local args = { wagerText }
	local startRoll = (startRollText or ""):match("^%s*(.-)%s*$")
	if startRoll ~= "" then
		args[2] = startRoll
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
