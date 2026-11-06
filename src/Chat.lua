-- Chat text helpers. Pure Lua: no WoW API calls, so it runs under busted.
local _, ns = ...

local Chat = {}
ns.Chat = Chat

Chat.PREFIX = "[DeathRoll]"

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

local function names(list)
	return table.concat(list, ", ")
end

-- One function per event type. Each returns the body of the line (no prefix).
-- The exact wording is specified in docs/prd/functional/04-announcements.md.
local renderers = {}

function renderers.kickoff(_, game)
	return string.format(
		"Death roll starting! %s per person. Everyone rolls 1-%d once: highest wins, lowest pays the difference. "
			.. "Type %s here to join. %d seconds!",
		ns.Money.Format(game.wager), game.rollMax, game.joinWord, game.joinTime
	) .. STAY_NEAR
end

function renderers.countdown(event)
	local line = string.format("%d seconds left to join! %d in", event.secondsLeft, #event.names)
	if #event.names > 0 then
		line = line .. ": " .. names(event.names)
	end
	return line
end

function renderers.closed(event)
	return string.format("Joining closed! %d players in: %s", #event.joined, names(event.joined))
end

function renderers.call(event)
	return string.format("Everyone, type /roll %d now! %d seconds.", event.max, event.seconds)
end

function renderers.wrongRange(event)
	return string.format("%s, wrong range. Type /roll %d", event.name, event.max)
end

function renderers.reminder(event)
	return string.format("%d seconds! Still to roll: %s. Type /roll %d",
		event.secondsLeft, names(event.names), event.max)
end

function renderers.satOut(event)
	local verb = #event.names == 1 and "sits" or "sit"
	return string.format("%s did not roll in time and %s out.", names(event.names), verb)
end

function renderers.allTied(event)
	return string.format("Everyone rolled %d! Roll again.", event.roll)
end

function renderers.tieBreak(event)
	local line = ""
	if event.high then
		line = line .. "Tie for highest: " .. names(event.high) .. ". "
	end
	if event.low then
		line = line .. "Tie for lowest: " .. names(event.low) .. ". "
	end
	return line .. string.format("Tied players, type /roll %d again! %d seconds.", event.max, event.seconds)
end

function renderers.winner(event)
	return string.format("WINNER: %s with %d! %s rolled %d and owes %s %s.",
		event.name, event.high, event.loser, event.low, event.name, ns.Money.Format(event.owed))
end

function renderers.cancelled(event)
	if event.reason == "tooFew" then
		return string.format("Not enough players (need %d). Game cancelled.", ns.Rules.MIN_PLAYERS)
	elseif event.reason == "noRolls" then
		return "Nobody rolled the tie-break. Game cancelled."
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
	return { Chat.Prefix(render(event, game)) }
end
