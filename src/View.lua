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

-- 04-winner (package 09): Result.
