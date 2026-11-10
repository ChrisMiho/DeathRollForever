local _, ns = ...

-- Parse: recognise the three kinds of text the host's addon reads. A join
-- word in the game's chat, a /roll result in the system channel, and the
-- arguments the host typed after /dr.
-- Pure Lua, no WoW API. Spec: docs/prd/functional/02-chat-parsing.md.

local Parse = {}
ns.Parse = Parse

-- [P0-ROLL] confirmed 2026-11-05: "Name rolls 734 (1-1000)" for everyone,
-- the host included; names may contain a space, so the name is (.-).
Parse.ROLL_PATTERN = "^(.-) rolls (%d+) %((%d+)%-(%d+)%)$"

Parse.CHANNELS = {
	g = "GUILD", guild = "GUILD",
	p = "PARTY", party = "PARTY",
	r = "RAID", raid = "RAID",
	solo = "SOLO", -- a solo game against bots (06-solo); no short form
}

Parse.USAGE = "Usage: /dr g|p|r|solo <wager> [roll max]"
Parse.ROLL_MAX_ERROR = "Roll max must be a whole number from 2 to 1000000"

local ROLL_MAX_MIN = 2
local ROLL_MAX_MAX = 1000000

local function trim(text)
	return text:match("^%s*(.-)%s*$")
end

function Parse.JoinWord(message, joinWord)
	if type(message) ~= "string" then
		return false
	end
	return trim(message):lower() == joinWord:lower()
end

function Parse.Roll(systemMessage, pattern)
	if type(systemMessage) ~= "string" then
		return nil
	end
	local name, roll, min, max = systemMessage:match(pattern or Parse.ROLL_PATTERN)
	if not name then
		return nil
	end
	return name, tonumber(roll), tonumber(min), tonumber(max)
end

function Parse.Command(text)
	local command = { name = "", args = {} }
	if type(text) ~= "string" then
		return command
	end
	for word in text:gmatch("%S+") do
		if command.name == "" then
			command.name = word:lower()
		else
			command.args[#command.args + 1] = word
		end
	end
	return command
end

-- A whole number from ROLL_MAX_MIN to ROLL_MAX_MAX, digits only.
local function parseRollMax(text)
	local digits = text:match("^(%d+)$")
	if not digits then
		return nil
	end
	local value = tonumber(digits)
	if value < ROLL_MAX_MIN or value > ROLL_MAX_MAX then
		return nil
	end
	return value
end

-- Steps follow the spec's numbered list, so the first problem found is the
-- one reported: channel, wager, roll max, then extra arguments.
function Parse.StartArgs(name, args)
	local channel = Parse.CHANNELS[name]
	if not channel then
		return nil, Parse.USAGE
	end
	if args[1] == nil then
		return nil, Parse.USAGE
	end
	local wager, wagerError = ns.Money.Parse(args[1])
	if not wager then
		return nil, wagerError
	end
	local rollMax
	if args[2] ~= nil then
		rollMax = parseRollMax(args[2])
		if not rollMax then
			return nil, Parse.ROLL_MAX_ERROR
		end
	end
	if args[3] ~= nil then
		return nil, Parse.USAGE
	end
	return { channel = channel, wager = wager, rollMax = rollMax }
end
