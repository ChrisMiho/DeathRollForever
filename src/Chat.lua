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
-- roll is not seen by the host, so this sentence is always on in v1.
local STAY_NEAR = " Stay near the host so your rolls are seen."

local function names(list)
	return table.concat(list, ", ")
end

-- One function per event type. Each returns the body of the line (no prefix).
-- The exact wording is specified in docs/prd/functional/04-announcements.md.
local renderers = {}

function renderers.kickoff(_, game)
	return string.format(
		"Death roll starting! %s per person, first roll 1-%d. Type %s here to join. %d seconds! (%ds per turn)",
		ns.Money.Format(game.wager), game.startRoll, game.joinWord, game.joinTime, game.turnTimer
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

function renderers.order(event)
	return "Roll order: " .. names(event.order)
end

function renderers.call(event)
	return string.format("%s, you're up! Type /roll %d", event.name, event.range)
end

function renderers.wrongRange(event)
	return string.format("%s, wrong range. Type /roll %d", event.name, event.range)
end

function renderers.reminder(event)
	return string.format("%s, %d seconds! Type /roll %d", event.name, event.secondsLeft, event.range)
end

function renderers.forfeit(event)
	return string.format("%s did not roll in time and is OUT. %d left.", event.name, event.left)
end

function renderers.out(event)
	local line = string.format("%s rolled 1 and is OUT! %d left.", event.name, event.left)
	if event.left > 1 then
		line = line .. " Range resets."
	end
	return line
end

function renderers.winner(event)
	local wager = ns.Money.Format(event.wager)
	if #event.losers == 1 then
		return string.format("WINNER: %s! %s owes %s %s.", event.name, event.losers[1], event.name, wager)
	end
	return string.format("WINNER: %s! %s each owe %s %s (%s total).",
		event.name, names(event.losers), event.name, wager, ns.Money.Format(event.total))
end

function renderers.cancelled(event)
	if event.reason == "tooFew" then
		return string.format("Not enough players (need %d). Game cancelled.", ns.Rules.MIN_PLAYERS)
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
