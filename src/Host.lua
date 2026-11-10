local _, ns = ...

-- Host: the only glue besides the window. Feeds chat into the rules engine,
-- posts every rendered line, and ticks the engine once a second while a game
-- is live. No rules and no chat text of its own: those live in Rules and Chat.
-- A solo game (06-solo) posts nothing and rolls for its bots on timers.
-- Spec: docs/prd/functional/05-host-controller.md.

local Host = {}
ns.Host = Host

-- Local, host-only messages (returned as errorText; Init prints them).
local ALREADY_RUNNING = "A game is already running. Type /dr cancel first."
local NOT_RUNNING = "No game is running."
local WINDOW_ERROR = "Window error (the game goes on in chat): %s"
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
	SOLO = {}, -- nobody to hear: only the host's own /roll comes in
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
	elseif channel == "SOLO" then
		return true
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

local post

-- A solo game: roll for every waiting bot at its own random moment. A timer
-- whose game was dropped or has moved on to another round does nothing.
local function scheduleBots()
	local forGame, forRound = game, game.round
	for _, bot in ipairs(ns.Solo.Plan(game, game.host, math.random)) do
		C_Timer.After(bot.delay, function()
			if game == forGame and game.round == forRound then
				post(ns.Rules.Roll(game, bot.name, bot.roll, 1, game.rollMax, GetTime()))
			end
		end)
	end
end

-- True when the list starts a round: the bots of a solo game must roll.
local function startsRound(events)
	for _, event in ipairs(events) do
		if event.type == "call" or event.type == "tieBreak" then
			return true
		end
	end
	return false
end

-- Post every rendered line of every event, in order, to the game's channel
-- (a solo game posts nothing but starts its bots' timers),
-- then tell the listener. Once the game is no longer live, tear everything
-- down; the listener has already seen the finished or cancelled game.
-- post ends Start, tick and every chat or cancel path, so the listener runs
-- at the end of each of them, even when a tick posted nothing (v2 section).
-- An error inside the listener is caught and printed to the host, so a
-- broken window can neither stall the chat game nor keep a dead game alive:
-- the drop below runs whatever the listener did.
function post(events)
	if not game then
		return
	end
	if game.channel == "SOLO" then
		if startsRound(events) then
			scheduleBots()
		end
	else
		for _, event in ipairs(events) do
			for _, line in ipairs(ns.Chat.Render(event, game)) do
				SendChatMessage(line, game.channel) -- [P0-POST]
			end
		end
	end
	if listener then
		local ok, err = pcall(listener, game)
		if not ok then
			ns.Print(WINDOW_ERROR:format(tostring(err)))
		end
	end
	if not ns.Rules.IsLive(game) then
		stop()
	end
end

-- Every second: countdowns, the lobby closing, reminders, a round settling on
-- its deadline. No rng: v3 has no shuffle.
local function tick()
	if not game then
		return
	end
	post(ns.Rules.Tick(game, GetTime()))
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
	-- opts comes from Parse.StartArgs or View.StartOpts with channel, wager
	-- and an optional rollMax; the rest is filled from the defaults.
	local defaults = ns.Rules.DEFAULTS
	if opts.rollMax == nil then
		opts.rollMax = defaults.rollMax
	end
	opts.host = Ambiguate(GetUnitName("player", true), "short") -- with the Forever surname, as rolls print it
	opts.joinWord = defaults.joinWord
	opts.joinTime = defaults.joinTime
	opts.rollTime = defaults.rollTime
	if opts.channel == "SOLO" then
		opts.rollTime = ns.Solo.ROLL_TIME
		opts.players = ns.Solo.Players(opts.host, UnitFactionGroup("player"), opts.bots or ns.Solo.BOTS, math.random)
	end
	opts.bots = nil

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
