local _, ns = ...

-- The whole game as a pure state machine (docs/prd/functional/03-rules-engine.md).
-- Every public function takes a game, mutates it and returns the list of
-- events that happened (contracts section 6). No text, no clock, no WoW API.

local Rules = {}
ns.Rules = Rules

Rules.DEFAULTS = { startRoll = 1000, joinTime = 60, turnTimer = 45, joinWord = "1" }
Rules.COUNTDOWN = { 30, 15, 5 } -- seconds left to join when a countdown line posts
Rules.REMINDERS = { 20, 10, 5 } -- seconds left in a turn when a reminder posts
Rules.MIN_PLAYERS = 2

local REQUIRED_OPTS = {
	host = "string",
	channel = "string",
	wager = "number",
	startRoll = "number",
	joinWord = "string",
	joinTime = "number",
	turnTimer = "number",
}

local function copy(list)
	local out = {}
	for i, v in ipairs(list) do
		out[i] = v
	end
	return out
end

local function checkType(value, expected, label)
	if type(value) ~= expected then
		error(("Rules: %s must be a %s, got %s"):format(label, expected, type(value)), 3)
	end
end

local function isRolling(game)
	return game.phase == "rolling"
end

-- Index into game.order of the next "in" player after position `from`,
-- wrapping. Only called while at least one player is "in".
local function nextIn(game, from)
	local n = #game.order
	for step = 1, n do
		local i = ((from - 1 + step) % n) + 1
		if game.status[game.order[i]] == "in" then
			return i
		end
	end
	return from
end

local function call(game, now)
	game.turnDeadline = now + game.turnTimer
	game.remindersSent = {}
	return { type = "call", name = game.order[game.turn], range = game.range }
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

local function eliminate(game, now, status)
	local name = game.order[game.turn]
	game.status[name] = status
	table.insert(game.eliminated, name)
	local alive = Rules.Alive(game)
	local event = { type = status, name = name, left = #alive }
	if #alive == 1 then
		game.phase = "finished"
		game.winner = alive[1]
		game.endedAt = now
		return {
			event,
			{
				type = "winner",
				name = alive[1],
				losers = copy(game.eliminated),
				wager = game.wager,
				total = game.wager * #game.eliminated,
			},
		}
	end
	if status == "out" then
		game.range = game.startRoll
	end
	game.turn = nextIn(game, game.turn)
	return { event, call(game, now) }
end

local function close(game, now, rng)
	if #game.joined < Rules.MIN_PLAYERS then
		game.phase = "cancelled"
		game.cancelReason = "tooFew"
		game.endedAt = now
		return { { type = "cancelled", reason = "tooFew" } }
	end
	checkType(rng, "function", "rng")
	local order = copy(game.joined)
	for i = #order, 2, -1 do
		local j = rng(i)
		order[i], order[j] = order[j], order[i]
	end
	game.order = order
	for _, name in ipairs(order) do
		game.status[name] = "in"
	end
	game.phase = "rolling"
	game.turn = 1
	game.range = game.startRoll
	return {
		{ type = "closed", joined = copy(game.joined) },
		{ type = "order", order = copy(order) },
		call(game, now),
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
		startRoll = opts.startRoll,
		joinWord = opts.joinWord,
		joinTime = opts.joinTime,
		turnTimer = opts.turnTimer,
		phase = "lobby",
		createdAt = now,

		joined = {},
		joinDeadline = now + opts.joinTime,
		countdownSent = {},

		order = {},
		status = {},
		eliminated = {},
		turn = nil,
		range = nil,
		turnDeadline = nil,
		remindersSent = {},
		rolls = {},

		winner = nil,
		endedAt = nil,
		cancelReason = nil,
	}
	return game, { { type = "kickoff" } }
end

function Rules.Join(game, name, now) -- luacheck: no unused args
	if game.phase ~= "lobby" then
		return {}
	end
	for _, joined in ipairs(game.joined) do
		if joined == name then
			return {}
		end
	end
	table.insert(game.joined, name)
	return { { type = "joined", name = name } }
end

function Rules.Tick(game, now, rng)
	checkType(now, "number", "now")
	if game.phase == "lobby" then
		if now >= game.joinDeadline then
			return close(game, now, rng)
		end
		local marker = passMarkers(Rules.COUNTDOWN, game.joinDeadline - now, game.countdownSent)
		if marker then
			return { { type = "countdown", secondsLeft = marker, names = copy(game.joined) } }
		end
		return {}
	elseif isRolling(game) then
		if now >= game.turnDeadline then
			return eliminate(game, now, "forfeit")
		end
		local marker = passMarkers(Rules.REMINDERS, game.turnDeadline - now, game.remindersSent)
		if marker then
			return {
				{ type = "reminder", name = game.order[game.turn], secondsLeft = marker, range = game.range },
			}
		end
		return {}
	end
	return {}
end

function Rules.Roll(game, name, roll, min, max, now)
	if not isRolling(game) or name ~= game.order[game.turn] then
		return {}
	end
	checkType(roll, "number", "roll")
	checkType(now, "number", "now")
	if min ~= 1 or max ~= game.range then
		return { { type = "wrongRange", name = name, range = game.range } }
	end
	table.insert(game.rolls, { name = name, roll = roll, max = max })
	if roll > 1 then
		game.range = roll
		game.turn = nextIn(game, game.turn)
		return { call(game, now) }
	end
	return eliminate(game, now, "out")
end

function Rules.Cancel(game, now)
	if not Rules.IsLive(game) then
		return {}
	end
	checkType(now, "number", "now")
	game.phase = "cancelled"
	game.cancelReason = "host"
	game.endedAt = now
	return { { type = "cancelled", reason = "host" } }
end

function Rules.Current(game)
	if not isRolling(game) then
		return nil
	end
	return game.order[game.turn], game.range
end

function Rules.Alive(game)
	local alive = {}
	for _, name in ipairs(game.order) do
		if game.status[name] == "in" then
			table.insert(alive, name)
		end
	end
	return alive
end

function Rules.IsLive(game)
	return game.phase == "lobby" or isRolling(game)
end
