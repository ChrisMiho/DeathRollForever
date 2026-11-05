local _, ns = ...

-- Host: the only glue in v1. Feeds chat into the rules engine, posts every
-- rendered line, and ticks the engine once a second while a game is live.
-- No rules and no chat text of its own: those live in Rules and Chat.
-- Spec: docs/prd/functional/05-host-controller.md.

local Host = {}
ns.Host = Host

-- Local, host-only messages (returned as errorText; Init prints them).
local ALREADY_RUNNING = "A game is already running. Type /dr cancel first."
local NOT_RUNNING = "No game is running."
local NOT_IN = {
	GUILD = "You are not in a guild.",
	PARTY = "You are not in a party.",
	RAID = "You are not in a raid.",
}

-- Chat events that carry the join word for each channel (contracts section 7).
-- The party and raid leader's lines arrive on their own events.
local CHAT_EVENTS = {
	GUILD = { "CHAT_MSG_GUILD" },
	PARTY = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
	RAID = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" },
}

local game -- the running game, or nil
local ticker -- the C_Timer ticker while a game is live, or nil
local listener -- the one Host.OnChange listener, or nil
local frame = CreateFrame("Frame")

local function isMember(channel)
	if channel == "GUILD" then
		return IsInGuild()
	elseif channel == "PARTY" then
		return IsInGroup()
	elseif channel == "RAID" then
		return IsInRaid()
	end
	return false
end

local function stop()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	frame:UnregisterAllEvents()
	game = nil
end

-- Post every rendered line of every event, in order, to the game's channel,
-- then tell the listener. Once the game is no longer live, tear everything
-- down; the listener has already seen the finished or cancelled game.
-- post ends Start, tick and every chat or cancel path, so the listener runs
-- at the end of each of them, even when a tick posted nothing (v2 section).
local function post(events)
	if not game then
		return
	end
	for _, event in ipairs(events) do
		for _, line in ipairs(ns.Chat.Render(event, game)) do
			SendChatMessage(line, game.channel) -- [P0-POST]
		end
	end
	if listener then
		listener(game)
	end
	if not ns.Rules.IsLive(game) then
		stop()
	end
end

local function tick()
	if not game then
		return
	end
	post(ns.Rules.Tick(game, GetTime(), math.random))
end

local function onChannelMessage(text, sender)
	local name = Ambiguate(sender, "short")
	if ns.Parse.JoinWord(text, game.joinWord) then
		post(ns.Rules.Join(game, name, GetTime()))
	end
end

-- [P0-ROLL] answered 2026-11-05: the host's own roll shows with the host's
-- name like everyone else's, never as "You", so no mapping is needed.
local function onSystemMessage(text)
	local name, roll, min, max = ns.Parse.Roll(text)
	if not name then
		return
	end
	name = Ambiguate(name, "short")
	post(ns.Rules.Roll(game, name, roll, min, max, GetTime()))
end

frame:SetScript("OnEvent", function(_, event, text, sender)
	if not game then
		return
	end
	if event == "CHAT_MSG_SYSTEM" then
		onSystemMessage(text)
	else
		onChannelMessage(text, sender)
	end
end)

function Host.IsHosting()
	return game ~= nil
end

function Host.Game()
	return game
end

function Host.Start(opts)
	if Host.IsHosting() then
		return nil, ALREADY_RUNNING
	end
	if not isMember(opts.channel) then
		return nil, NOT_IN[opts.channel]
	end
	local defaults = ns.Rules.DEFAULTS
	if opts.startRoll == nil then
		opts.startRoll = defaults.startRoll
	end
	opts.host = Ambiguate(UnitName("player"), "short")
	opts.joinWord = defaults.joinWord
	opts.joinTime = defaults.joinTime
	opts.turnTimer = defaults.turnTimer

	local events
	game, events = ns.Rules.New(opts, GetTime())
	for _, chatEvent in ipairs(CHAT_EVENTS[game.channel]) do
		frame:RegisterEvent(chatEvent)
	end
	frame:RegisterEvent("CHAT_MSG_SYSTEM")
	ticker = C_Timer.NewTicker(1, tick)
	post(events) -- kickoff, then the listener sees the new game last
	return true
end

function Host.Cancel()
	if not Host.IsHosting() then
		return nil, NOT_RUNNING
	end
	post(ns.Rules.Cancel(game, GetTime()))
	return true
end

-- v2: register the one change listener; a second call replaces the first.
-- fn(game) runs at the end of Start, of every tick and of every post, with
-- a finished or cancelled game before it is dropped. Never with nil.
function Host.OnChange(fn)
	listener = fn
end
