local _, ns = ...

-- The whole game as a pure state machine (docs/prd/functional/03-rules-engine.md).
-- Every public function takes a game, mutates it and returns the list of
-- events that happened (contracts section 6). No text, no clock, no WoW API.
--
-- v3 is one round: everyone rolls once, the highest roll wins and the lowest
-- roll pays the difference. Ties for highest or lowest are settled by
-- tie-break rounds among the tied players only.

local Rules = {}
ns.Rules = Rules

Rules.DEFAULTS = { rollMax = 100, joinTime = 60, rollTime = 45, joinWord = "1" }
Rules.COUNTDOWN = { 30, 15, 5 } -- seconds left to join when a countdown line posts
Rules.REMINDERS = { 20, 10, 5 } -- seconds left to roll when a reminder posts
Rules.MIN_PLAYERS = 2 -- joined to close the lobby; rolled to settle a round

local REQUIRED_OPTS = {
	host = "string",
	channel = "string",
	wager = "number",
	rollMax = "number",
	joinWord = "string",
	joinTime = "number",
	rollTime = "number",
}

local function copy(list)
	local out = {}
	for i, v in ipairs(list) do
		out[i] = v
	end
	return out
end

-- A copy of `list`, or nil when `list` is nil (tie sides are optional).
local function copyOrNil(list)
	if list == nil then
		return nil
	end
	return copy(list)
end

local function contains(list, name)
	for _, v in ipairs(list) do
		if v == name then
			return true
		end
	end
	return false
end

local function checkType(value, expected, label)
	if type(value) ~= expected then
		error(("Rules: %s must be a %s, got %s"):format(label, expected, type(value)), 3)
	end
end

local function isRolling(game)
	return game.phase == "rolling"
end

-- The table this round's rolls are counted into.
local function currentRolls(game)
	if game.tie then
		return game.tieRolls
	end
	return game.rolls
end

-- Marks every marker that is >= secondsLeft and not yet sent, and returns
-- the smallest one passed, or nil when none was.
local function passMarkers(markers, secondsLeft, sent)
	local smallest
	for _, marker in ipairs(markers) do
		if marker >= secondsLeft and not sent[marker] then
			sent[marker] = true
			if not smallest or marker < smallest then
				smallest = marker
			end
		end
	end
	return smallest
end

-- Starts a round: the first keeps round = 1, every later one adds one.
local function startRound(game, now, first)
	if not first then
		game.round = game.round + 1
	end
	game.rollDeadline = now + game.rollTime
	game.remindersSent = {}
	game.tieRolls = {}
end

local function callEvent(game)
	return { type = "call", names = copy(game.rollers), max = game.rollMax, seconds = game.rollTime }
end

local function tieBreakEvent(game)
	return {
		type = "tieBreak",
		high = copyOrNil(game.tie.high),
		low = copyOrNil(game.tie.low),
		max = game.rollMax,
		seconds = game.rollTime,
	}
end

local function cancel(game, now, reason)
	game.phase = "cancelled"
	game.cancelReason = reason
	game.endedAt = now
	return { type = "cancelled", reason = reason }
end

-- Both ends decided: finish. Otherwise start a tie-break round among the
-- tied names. Appends the resulting event to `events`.
local function decide(game, now, tieHigh, tieLow, events)
	if game.winner and game.loser then
		game.phase = "finished"
		game.endedAt = now
		game.owed = Rules.Owed(game.high, game.low, game.wager, game.rollMax)
		game.tie = nil
		game.rollers = {}
		table.insert(events, {
			type = "winner",
			name = game.winner,
			loser = game.loser,
			high = game.high,
			low = game.low,
			owed = game.owed,
		})
		return
	end
	game.tie = { high = tieHigh, low = tieLow }
	local rollers = copy(tieHigh or {})
	for _, name in ipairs(tieLow or {}) do
		table.insert(rollers, name)
	end
	game.rollers = rollers
	startRound(game, now)
	table.insert(events, tieBreakEvent(game))
end

-- Splits `names` into those with an entry in `rolls` and those without,
-- keeping their order.
local function splitRolled(names, rolls)
	local rolled, missing = {}, {}
	for _, name in ipairs(names) do
		if rolls[name] ~= nil then
			table.insert(rolled, name)
		else
			table.insert(missing, name)
		end
	end
	return rolled, missing
end

-- The largest and smallest of `rolls[name]` over `names`, and the names
-- holding each, in order.
local function extremes(names, rolls)
	local high, low
	for _, name in ipairs(names) do
		local roll = rolls[name]
		if not high or roll > high then
			high = roll
		end
		if not low or roll < low then
			low = roll
		end
	end
	local highs, lows = {}, {}
	for _, name in ipairs(names) do
		if rolls[name] == high then
			table.insert(highs, name)
		end
		if rolls[name] == low then
			table.insert(lows, name)
		end
	end
	return high, low, highs, lows
end

local function settleMain(game, now)
	local events = {}
	local pool, missing = splitRolled(game.rollers, game.rolls)
	for _, name in ipairs(missing) do
		table.insert(game.satOut, name)
	end
	if #missing > 0 then
		table.insert(events, { type = "satOut", names = missing })
	end
	if #pool < Rules.MIN_PLAYERS then
		table.insert(events, cancel(game, now, "tooFew"))
		return events
	end
	local high, low, highs, lows = extremes(pool, game.rolls)
	if high == low then
		game.rolls = {}
		game.rollers = pool
		startRound(game, now)
		table.insert(events, { type = "allTied", roll = high, names = copy(pool) })
		table.insert(events, callEvent(game))
		return events
	end
	game.high = high
	game.low = low
	if #highs == 1 then
		game.winner = highs[1]
	end
	if #lows == 1 then
		game.loser = lows[1]
	end
	decide(game, now, #highs > 1 and highs or nil, #lows > 1 and lows or nil, events)
	return events
end

local function settleTieBreak(game, now)
	local events = {}
	local tieHigh, tieLow
	if game.tie.high then
		local rolled = splitRolled(game.tie.high, game.tieRolls)
		if #rolled == 0 then
			table.insert(events, cancel(game, now, "noRolls"))
			return events
		end
		local _, _, top = extremes(rolled, game.tieRolls)
		if #top == 1 then
			game.winner = top[1]
		else
			tieHigh = top
		end
	end
	if game.tie.low then
		local rolled, noShows = splitRolled(game.tie.low, game.tieRolls)
		if #rolled == 0 then
			table.insert(events, cancel(game, now, "noRolls"))
			return events
		end
		if #noShows == 1 then
			game.loser = noShows[1]
		elseif #noShows > 1 then
			tieLow = noShows
		else
			local _, _, _, bottom = extremes(rolled, game.tieRolls)
			if #bottom == 1 then
				game.loser = bottom[1]
			else
				tieLow = bottom
			end
		end
	end
	decide(game, now, tieHigh, tieLow, events)
	return events
end

-- Runs when every roller has rolled or the deadline passed.
local function settle(game, now)
	if game.tie then
		return settleTieBreak(game, now)
	end
	return settleMain(game, now)
end

local function close(game, now)
	if #game.joined < Rules.MIN_PLAYERS then
		return { cancel(game, now, "tooFew") }
	end
	game.phase = "rolling"
	game.rollers = copy(game.joined)
	game.tie = nil
	startRound(game, now, true)
	return {
		{ type = "closed", joined = copy(game.joined) },
		callEvent(game),
	}
end

function Rules.New(opts, now)
	checkType(opts, "table", "opts")
	checkType(now, "number", "now")
	for field, expected in pairs(REQUIRED_OPTS) do
		checkType(opts[field], expected, "opts." .. field)
	end
	local game = {
		id = opts.host .. "-" .. math.floor(now),
		host = opts.host,
		channel = opts.channel,
		wager = opts.wager,
		rollMax = opts.rollMax,
		joinWord = opts.joinWord,
		joinTime = opts.joinTime,
		rollTime = opts.rollTime,
		phase = "lobby",
		createdAt = now,

		joined = {},
		joinDeadline = now + opts.joinTime,
		countdownSent = {},

		round = 1,
		rollers = {},
		rolls = {},
		tie = nil,
		tieRolls = {},
		rollDeadline = nil,
		remindersSent = {},
		history = {},

		high = nil,
		low = nil,
		winner = nil,
		loser = nil,
		owed = nil,
		satOut = {},
		endedAt = nil,
		cancelReason = nil,
	}
	return game, { { type = "kickoff" } }
end

function Rules.Join(game, name, now) -- luacheck: no unused args
	if game.phase ~= "lobby" then
		return {}
	end
	if contains(game.joined, name) then
		return {}
	end
	table.insert(game.joined, name)
	return { { type = "joined", name = name } }
end

function Rules.Tick(game, now)
	checkType(now, "number", "now")
	if game.phase == "lobby" then
		if now >= game.joinDeadline then
			return close(game, now)
		end
		local marker = passMarkers(Rules.COUNTDOWN, game.joinDeadline - now, game.countdownSent)
		if marker then
			return { { type = "countdown", secondsLeft = marker, names = copy(game.joined) } }
		end
		return {}
	elseif isRolling(game) then
		if now >= game.rollDeadline then
			return settle(game, now)
		end
		local marker = passMarkers(Rules.REMINDERS, game.rollDeadline - now, game.remindersSent)
		if marker then
			return { { type = "reminder", names = Rules.Waiting(game), secondsLeft = marker, max = game.rollMax } }
		end
		return {}
	end
	return {}
end

function Rules.Roll(game, name, roll, min, max, now)
	if not isRolling(game) or not contains(game.rollers, name) then
		return {}
	end
	local rolls = currentRolls(game)
	if rolls[name] ~= nil then
		return {}
	end
	checkType(roll, "number", "roll")
	checkType(now, "number", "now")
	if min ~= 1 or max ~= game.rollMax then
		return { { type = "wrongRange", name = name, max = game.rollMax } }
	end
	rolls[name] = roll
	table.insert(game.history, { name = name, roll = roll, max = max, round = game.round })
	local waiting = Rules.Waiting(game)
	local events = { { type = "rolled", name = name, roll = roll, waiting = #waiting } }
	if #waiting == 0 then
		for _, event in ipairs(settle(game, now)) do
			table.insert(events, event)
		end
	end
	return events
end

function Rules.Cancel(game, now)
	if not Rules.IsLive(game) then
		return {}
	end
	checkType(now, "number", "now")
	return { cancel(game, now, "host") }
end

function Rules.Waiting(game)
	if not isRolling(game) then
		return {}
	end
	local _, waiting = splitRolled(game.rollers, currentRolls(game))
	return waiting
end

function Rules.Owed(high, low, wager, rollMax)
	return math.floor((high - low) * wager / rollMax)
end

function Rules.IsLive(game)
	return game.phase == "lobby" or isRolling(game)
end
