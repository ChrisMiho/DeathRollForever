-- Chat text helpers. Pure Lua: no WoW API calls, so it runs under busted.
local _, ns = ...

local Chat = {}
ns.Chat = Chat

Chat.PREFIX = "[DeathRoll]"
Chat.MAX_LINE = 255 -- the most bytes a chat line may hold, prefix included

--- Prefix a line for posting to party, raid or guild chat.
-- @param text string The message body.
-- @return string The message with the addon prefix.
function Chat.Prefix(text)
	if type(text) ~= "string" or text == "" then
		error("Chat.Prefix: text must be a non-empty string", 2)
	end
	return Chat.PREFIX .. " " .. text
end

-- [P0-DISTANCE] answered 2026-11-05: a far-away, ungrouped guild member's
-- roll is not seen by the host, so this sentence is always on.
local STAY_NEAR = " Stay near the host so your rolls are seen."

-- Names in events are character names; lines show each player's full name
-- (Rules.FullName), surname included.
local function shown(game, list)
	local out = {}
	for i, name in ipairs(list) do
		out[i] = ns.Rules.FullName(game, name)
	end
	return out
end

local function names(game, list)
	return table.concat(shown(game, list), ", ")
end

-- "Alice", "Alice and Bob", "Alice, Bob and Carl".
local function andList(game, list)
	local full = shown(game, list)
	if #full == 1 then
		return full[1]
	end
	return table.concat(full, ", ", 1, #full - 1) .. " and " .. full[#full]
end

-- One function per event type. Each returns the body of the line (no prefix).
-- `short` is true when the line with every name would not fit in
-- Chat.MAX_LINE: a renderer that lists names then gives a count instead.
-- The exact wording is specified in docs/prd/functional/04-announcements.md.
local renderers = {}

function renderers.kickoff(_, game)
	return string.format(
		"Death roll starting! %s per person. Everyone rolls 1-%d once: highest wins, lowest pays the difference. "
			.. "Type %s here to join. %d seconds!",
		ns.Money.Format(game.wager), game.rollMax, game.joinWord, game.joinTime
	) .. STAY_NEAR
end

function renderers.countdown(event, game, short)
	local line = string.format("%d seconds left to join! %d in", event.secondsLeft, #event.names)
	if #event.names > 0 and not short then
		line = line .. ": " .. names(game, event.names)
	end
	return line
end

function renderers.closed(event, game, short)
	if short then
		return string.format("Joining closed! %d players in.", #event.joined)
	end
	return string.format("Joining closed! %d players in: %s", #event.joined, names(game, event.joined))
end

function renderers.call(event)
	return string.format("Everyone, type /roll %d now! %d seconds.", event.max, event.seconds)
end

-- Whispered to the player (Chat.WhisperTo), never posted in the game's chat.
function renderers.wrongRange(event)
	return string.format("Wrong range, that roll does not count. Type /roll %d", event.max)
end

function renderers.reminder(event, game, short)
	if short then
		return string.format("%d seconds! %d still to roll. Type /roll %d",
			event.secondsLeft, #event.names, event.max)
	end
	return string.format("%d seconds! Still to roll: %s. Type /roll %d",
		event.secondsLeft, names(game, event.names), event.max)
end

function renderers.satOut(event, game, short)
	if short then
		return string.format("%d players did not roll in time and sit out.", #event.names)
	end
	local verb = #event.names == 1 and "sits" or "sit"
	return string.format("%s did not roll in time and %s out.", names(game, event.names), verb)
end

function renderers.allTied(event)
	return string.format("Everyone rolled %d! Roll again.", event.roll)
end

function renderers.tieBreak(event, game, short)
	local function side(list)
		if short then
			return #list .. " players"
		end
		return names(game, list)
	end
	local line = ""
	if event.high then
		line = line .. "Tie for highest: " .. side(event.high) .. ". "
	end
	if event.low then
		line = line .. "Tie for lowest: " .. side(event.low) .. ". "
	end
	return line .. string.format("Tied players, type /roll %d again! %d seconds.", event.max, event.seconds)
end

-- One loser owes; several losers (everyone tied for lowest skipped the
-- tie-break) each owe the same amount.
function renderers.winner(event, game, short)
	local owed = ns.Money.Format(event.owed)
	local winner = ns.Rules.FullName(game, event.name)
	local losers = event.losers
	if #losers == 1 then
		return string.format("WINNER: %s with %d! %s rolled %d and owes %s %s.",
			winner, event.high, ns.Rules.FullName(game, losers[1]), event.low, winner, owed)
	end
	local who = short and (#losers .. " players") or andList(game, losers)
	return string.format("WINNER: %s with %d! %s rolled %d, skipped the tie-break and each owe %s %s.",
		winner, event.high, who, event.low, winner, owed)
end

function renderers.cancelled(event)
	if event.reason == "tooFew" then
		return string.format("Not enough players (need %d). Game cancelled.", ns.Rules.MIN_PLAYERS)
	elseif event.reason == "noRolls" then
		return "Nobody rolled the tie for highest. Game cancelled."
	end
	return "Game cancelled by the host."
end

--- Render one rules-engine event as the chat lines the host posts.
-- @param event table An event from Rules (a table with a `type` field).
-- @param game table The game the event belongs to.
-- @return table A list of prefixed lines; empty for events with no chat text.
function Chat.Render(event, game)
	if type(event) ~= "table" or type(game) ~= "table" then
		error("Chat.Render: event and game must be tables", 2)
	end
	local render = renderers[event.type]
	if not render then
		return {}
	end
	local line = Chat.Prefix(render(event, game, false))
	if #line > Chat.MAX_LINE then
		line = Chat.Prefix(render(event, game, true))
	end
	return { line }
end

--- Who an event's lines go to.
-- @param event table An event from Rules.
-- @return string|nil The player to whisper (a wrong range goes to the one
-- who rolled it), or nil for the game's chat.
function Chat.WhisperTo(event)
	if type(event) == "table" and event.type == "wrongRange" then
		return event.name
	end
	return nil
end
