describe("Rules", function()
	local Rules

	local opts = {
		host = "Alice",
		channel = "GUILD",
		wager = 10000,
		startRoll = 1000,
		joinWord = "1",
		joinTime = 60,
		turnTimer = 45,
	}
	local t0 = 1000
	local function rngSame(n) return n end
	local function rngOne() return 1 end

	before_each(function()
		Rules = LoadAddonFile("src/Rules.lua").Rules
	end)

	-- A closed game with the given players in join order (rngSame keeps it).
	-- Returns the game and the close time t.
	local function closedGame(names, rng)
		local game = Rules.New(opts, t0)
		for i, name in ipairs(names) do
			Rules.Join(game, name, t0 + i)
		end
		local t = t0 + 60
		Rules.Tick(game, t, rng or rngSame)
		return game, t
	end

	local function threePlayerGame()
		return closedGame({ "Alice", "Bob", "Carl" })
	end

	local function twoPlayerGame()
		return closedGame({ "Alice", "Bob" })
	end

	-- A finished game: Alice out, Bob 600, Carl out, Bob wins.
	local function finishedGame()
		local game, t = threePlayerGame()
		Rules.Roll(game, "Alice", 1, 1, 1000, t + 1)
		Rules.Roll(game, "Bob", 600, 1, 1000, t + 2)
		Rules.Roll(game, "Carl", 1, 1, 600, t + 3)
		return game, t + 3
	end

	describe("constants", function()
		it("exposes DEFAULTS, COUNTDOWN, REMINDERS and MIN_PLAYERS from the contract", function()
			assert.are.same({ startRoll = 1000, joinTime = 60, turnTimer = 45, joinWord = "1" }, Rules.DEFAULTS)
			assert.are.same({ 30, 15, 5 }, Rules.COUNTDOWN)
			assert.are.same({ 20, 10, 5 }, Rules.REMINDERS)
			assert.are.equal(2, Rules.MIN_PLAYERS)
		end)
	end)

	describe("New", function()
		it("AC-03-01 creates a lobby with the kickoff event", function()
			local game, events = Rules.New(opts, t0)
			assert.are.equal("lobby", game.phase)
			assert.are.equal(1060, game.joinDeadline)
			assert.are.equal("Alice-1000", game.id)
			assert.are.equal(t0, game.createdAt)
			assert.are.equal("Alice", game.host)
			assert.are.equal("GUILD", game.channel)
			assert.are.equal(10000, game.wager)
			assert.are.equal(1000, game.startRoll)
			assert.are.equal("1", game.joinWord)
			assert.are.equal(60, game.joinTime)
			assert.are.equal(45, game.turnTimer)
			assert.are.same({}, game.joined)
			assert.are.same({}, game.countdownSent)
			assert.are.same({}, game.order)
			assert.are.same({}, game.status)
			assert.are.same({}, game.eliminated)
			assert.are.same({}, game.rolls)
			assert.are.same({}, game.remindersSent)
			assert.are.same({ { type = "kickoff" } }, events)
		end)

		it("AC-03-02 raises when wager is missing", function()
			local bad = {}
			for k, v in pairs(opts) do bad[k] = v end
			bad.wager = nil
			assert.has_error(function() Rules.New(bad, t0) end)
		end)

		it("AC-03-02 raises when a field has the wrong type", function()
			local bad = {}
			for k, v in pairs(opts) do bad[k] = v end
			bad.turnTimer = "45"
			assert.has_error(function() Rules.New(bad, t0) end)
		end)
	end)

	describe("Join", function()
		it("AC-03-03 adds a player once", function()
			local game = Rules.New(opts, t0)
			assert.are.same({ { type = "joined", name = "Bob" } }, Rules.Join(game, "Bob", t0 + 1))
			assert.are.same({}, Rules.Join(game, "Bob", t0 + 2))
			assert.are.same({ "Bob" }, game.joined)
		end)

		it("AC-03-04 does nothing during rolling", function()
			local game, t = threePlayerGame()
			assert.are.same({}, Rules.Join(game, "Dave", t + 1))
			assert.are.same({ "Alice", "Bob", "Carl" }, game.joined)
		end)
	end)

	describe("Tick in the lobby", function()
		it("AC-03-05 returns nothing before the first marker", function()
			local game = Rules.New(opts, t0)
			assert.are.same({}, Rules.Tick(game, t0 + 10, rngSame))
		end)

		it("AC-03-06 posts the 30 second countdown once", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Bob", t0 + 1)
			assert.are.same(
				{ { type = "countdown", secondsLeft = 30, names = { "Bob" } } },
				Rules.Tick(game, t0 + 30, rngSame)
			)
			assert.are.same({}, Rules.Tick(game, t0 + 30, rngSame))
		end)

		it("AC-03-07 posts 30 then 15", function()
			local game = Rules.New(opts, t0)
			local first = Rules.Tick(game, t0 + 31, rngSame)
			local second = Rules.Tick(game, t0 + 46, rngSame)
			assert.are.same({ { type = "countdown", secondsLeft = 30, names = {} } }, first)
			assert.are.same({ { type = "countdown", secondsLeft = 15, names = {} } }, second)
		end)

		it("AC-03-08 posts only the smallest marker passed and marks all of them sent", function()
			local game = Rules.New(opts, t0)
			local events = Rules.Tick(game, t0 + 46, rngSame)
			assert.are.equal(1, #events)
			assert.are.same({ type = "countdown", secondsLeft = 15, names = {} }, events[1])
			assert.is_true(game.countdownSent[30])
			assert.is_true(game.countdownSent[15])
			assert.is_nil(game.countdownSent[5])
		end)

		it("AC-03-09 posts 5 and then nothing", function()
			local game = Rules.New(opts, t0)
			assert.are.same({ { type = "countdown", secondsLeft = 5, names = {} } }, Rules.Tick(game, t0 + 55, rngSame))
			assert.are.same({}, Rules.Tick(game, t0 + 59, rngSame))
		end)
	end)

	describe("close", function()
		it("AC-03-10 cancels with one player", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Bob", t0 + 1)
			assert.are.same({ { type = "cancelled", reason = "tooFew" } }, Rules.Tick(game, t0 + 60))
			assert.are.equal("cancelled", game.phase)
			assert.are.equal("tooFew", game.cancelReason)
			assert.are.equal(t0 + 60, game.endedAt)
		end)

		it("AC-03-11 cancels with nobody", function()
			local game = Rules.New(opts, t0)
			assert.are.same({ { type = "cancelled", reason = "tooFew" } }, Rules.Tick(game, t0 + 60))
			assert.are.equal("cancelled", game.phase)
		end)

		it("AC-03-12 closes, orders and calls the first player", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Alice", t0 + 1)
			Rules.Join(game, "Bob", t0 + 2)
			Rules.Join(game, "Carl", t0 + 3)
			local events = Rules.Tick(game, t0 + 60, rngSame)
			assert.are.same({
				{ type = "closed", joined = { "Alice", "Bob", "Carl" } },
				{ type = "order", order = { "Alice", "Bob", "Carl" } },
				{ type = "call", name = "Alice", range = 1000 },
			}, events)
			assert.are.equal("rolling", game.phase)
			assert.are.equal(1105, game.turnDeadline)
			assert.are.equal(1, game.turn)
			assert.are.equal(1000, game.range)
			assert.are.same({ "Alice", "Bob", "Carl" }, game.order)
			assert.are.same({ Alice = "in", Bob = "in", Carl = "in" }, game.status)
			assert.are.same({}, game.remindersSent)
		end)

		it("AC-03-13 shuffles with the injected rng", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Alice", t0 + 1)
			Rules.Join(game, "Bob", t0 + 2)
			Rules.Join(game, "Carl", t0 + 3)
			local events = Rules.Tick(game, t0 + 60, rngOne)
			assert.are.same({ "Bob", "Carl", "Alice" }, game.order)
			assert.are.same({ type = "call", name = "Bob", range = 1000 }, events[3])
			assert.are.same({ "Alice", "Bob", "Carl" }, game.joined)
		end)

		it("AC-03-14 does not post a countdown passed in the closing tick", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Alice", t0 + 1)
			Rules.Join(game, "Bob", t0 + 2)
			local events = Rules.Tick(game, t0 + 60, rngSame)
			assert.are.same({
				{ type = "closed", joined = { "Alice", "Bob" } },
				{ type = "order", order = { "Alice", "Bob" } },
				{ type = "call", name = "Alice", range = 1000 },
			}, events)
		end)
	end)

	describe("Roll", function()
		it("AC-03-15 ignores a roll out of turn", function()
			local game, t = threePlayerGame()
			assert.are.same({}, Rules.Roll(game, "Bob", 500, 1, 1000, t + 1))
			assert.are.same({}, game.rolls)
			assert.are.equal(1, game.turn)
		end)

		it("AC-03-16 reports a wrong range and changes nothing", function()
			local game, t = threePlayerGame()
			assert.are.same({ { type = "wrongRange", name = "Alice", range = 1000 } },
				Rules.Roll(game, "Alice", 500, 1, 900, t + 1))
			assert.are.same({ { type = "wrongRange", name = "Alice", range = 1000 } },
				Rules.Roll(game, "Alice", 3, 5, 1000, t + 2))
			assert.are.equal(1000, game.range)
			assert.are.same({}, game.rolls)
			assert.are.equal(1, game.turn)
			assert.are.equal(t + 45, game.turnDeadline)
		end)

		it("AC-03-17 records a valid roll and calls the next player", function()
			local game, t = threePlayerGame()
			local now = t + 7
			assert.are.same({ { type = "call", name = "Bob", range = 734 } },
				Rules.Roll(game, "Alice", 734, 1, 1000, now))
			assert.are.equal(734, game.range)
			assert.are.same({ { name = "Alice", roll = 734, max = 1000 } }, game.rolls)
			assert.are.equal(now + 45, game.turnDeadline)
			assert.are.same({}, game.remindersSent)
			assert.are.equal(2, game.turn)
		end)

		it("AC-03-18 accepts a roll of exactly the range", function()
			local game, t = threePlayerGame()
			Rules.Roll(game, "Alice", 734, 1, 1000, t + 1)
			assert.are.same({ { type = "call", name = "Carl", range = 734 } },
				Rules.Roll(game, "Bob", 734, 1, 734, t + 2))
			assert.are.equal(734, game.range)
		end)

		it("AC-03-19 wraps the turn back to the first player", function()
			local game, t = threePlayerGame()
			Rules.Roll(game, "Alice", 734, 1, 1000, t + 1)
			Rules.Roll(game, "Bob", 734, 1, 734, t + 2)
			assert.are.same({ { type = "call", name = "Alice", range = 2 } },
				Rules.Roll(game, "Carl", 2, 1, 734, t + 3))
			assert.are.same({ { type = "call", name = "Bob", range = 2 } },
				Rules.Roll(game, "Alice", 2, 1, 2, t + 4))
		end)

		it("AC-03-20 eliminates a player who rolls 1 and resets the range", function()
			local game, t = threePlayerGame()
			Rules.Roll(game, "Alice", 734, 1, 1000, t + 1)
			Rules.Roll(game, "Bob", 500, 1, 734, t + 2)
			Rules.Roll(game, "Carl", 300, 1, 500, t + 3)
			assert.are.same({
				{ type = "out", name = "Alice", left = 2 },
				{ type = "call", name = "Bob", range = 1000 },
			}, Rules.Roll(game, "Alice", 1, 1, 300, t + 4))
			assert.are.equal("out", game.status.Alice)
			assert.are.same({ "Alice" }, game.eliminated)
			assert.are.equal(1000, game.range)
			assert.are.equal("rolling", game.phase)
		end)

		it("AC-03-20 eliminates on a 1 as the very first roll", function()
			local game, t = threePlayerGame()
			assert.are.same({
				{ type = "out", name = "Alice", left = 2 },
				{ type = "call", name = "Bob", range = 1000 },
			}, Rules.Roll(game, "Alice", 1, 1, 1000, t + 1))
			assert.are.equal("out", game.status.Alice)
			assert.are.same({ "Alice" }, game.eliminated)
		end)

		it("AC-03-21 finishes with a winner when one player is left", function()
			local game, t = threePlayerGame()
			Rules.Roll(game, "Alice", 1, 1, 1000, t + 1)
			assert.are.same({ { type = "call", name = "Carl", range = 600 } },
				Rules.Roll(game, "Bob", 600, 1, 1000, t + 2))
			assert.are.same({
				{ type = "out", name = "Carl", left = 1 },
				{ type = "winner", name = "Bob", losers = { "Alice", "Carl" }, wager = 10000, total = 20000 },
			}, Rules.Roll(game, "Carl", 1, 1, 600, t + 3))
			assert.are.equal("finished", game.phase)
			assert.are.equal("Bob", game.winner)
			assert.are.equal(t + 3, game.endedAt)
			assert.are.same({ Alice = "out", Bob = "in", Carl = "out" }, game.status)
			assert.are.same({ "Alice", "Carl" }, game.eliminated)
		end)

		it("AC-03-22 ignores everything after a finish", function()
			local game, t = finishedGame()
			assert.are.same({}, Rules.Roll(game, "Bob", 5, 1, 1000, t + 1))
			assert.are.same({}, Rules.Tick(game, t + 100, rngSame))
			assert.are.same({}, Rules.Cancel(game, t + 1))
			assert.are.same({}, Rules.Join(game, "Dave", t + 1))
			assert.are.equal("finished", game.phase)
			assert.is_nil(game.cancelReason)
		end)
	end)

	describe("Tick while rolling", function()
		it("AC-03-23 posts each reminder once", function()
			local game, t = threePlayerGame()
			assert.are.same({ { type = "reminder", name = "Alice", secondsLeft = 20, range = 1000 } },
				Rules.Tick(game, t + 25, rngSame))
			assert.are.same({}, Rules.Tick(game, t + 25, rngSame))
			assert.are.same({ { type = "reminder", name = "Alice", secondsLeft = 10, range = 1000 } },
				Rules.Tick(game, t + 35, rngSame))
			assert.are.same({ { type = "reminder", name = "Alice", secondsLeft = 5, range = 1000 } },
				Rules.Tick(game, t + 40, rngSame))
			assert.are.same({ [20] = true, [10] = true, [5] = true }, game.remindersSent)
		end)

		it("AC-03-24 forfeits the called player when the timer runs out", function()
			local game, t = threePlayerGame()
			Rules.Tick(game, t + 25, rngSame)
			Rules.Tick(game, t + 35, rngSame)
			Rules.Tick(game, t + 40, rngSame)
			assert.are.same({
				{ type = "forfeit", name = "Alice", left = 2 },
				{ type = "call", name = "Bob", range = 1000 },
			}, Rules.Tick(game, t + 45, rngSame))
			assert.are.equal("forfeit", game.status.Alice)
			assert.are.same({ "Alice" }, game.eliminated)
			assert.are.equal(t + 90, game.turnDeadline)
			assert.are.same({}, game.remindersSent)
			assert.are.equal(2, game.turn)
			assert.are.same({}, Rules.Tick(game, t + 45, rngSame))
		end)

		it("AC-03-25 keeps the range after a forfeit", function()
			local game, t = threePlayerGame()
			Rules.Roll(game, "Alice", 734, 1, 1000, t)
			assert.are.same({
				{ type = "forfeit", name = "Bob", left = 2 },
				{ type = "call", name = "Carl", range = 734 },
			}, Rules.Tick(game, t + 45, rngSame))
			assert.are.equal(734, game.range)
			assert.are.equal("forfeit", game.status.Bob)
		end)

		it("AC-03-26 does not post reminders passed in the forfeiting tick", function()
			local game, t = threePlayerGame()
			assert.are.same({
				{ type = "forfeit", name = "Alice", left = 2 },
				{ type = "call", name = "Bob", range = 1000 },
			}, Rules.Tick(game, t + 45, rngSame))
		end)

		it("AC-03-27 finishes with a winner when the other player forfeits", function()
			local game, t = twoPlayerGame()
			assert.are.same({
				{ type = "forfeit", name = "Alice", left = 1 },
				{ type = "winner", name = "Bob", losers = { "Alice" }, wager = 10000, total = 10000 },
			}, Rules.Tick(game, t + 45, rngSame))
			assert.are.equal("finished", game.phase)
			assert.are.equal("Bob", game.winner)
			assert.are.equal(t + 45, game.endedAt)
		end)
	end)

	describe("Cancel", function()
		it("AC-03-28 cancels in the lobby", function()
			local game = Rules.New(opts, t0)
			assert.are.same({ { type = "cancelled", reason = "host" } }, Rules.Cancel(game, t0 + 5))
			assert.are.equal("cancelled", game.phase)
			assert.are.equal("host", game.cancelReason)
			assert.are.equal(t0 + 5, game.endedAt)
			assert.are.same({}, Rules.Cancel(game, t0 + 6))
		end)

		it("AC-03-28 cancels while rolling", function()
			local game, t = threePlayerGame()
			assert.are.same({ { type = "cancelled", reason = "host" } }, Rules.Cancel(game, t + 5))
			assert.are.equal("cancelled", game.phase)
			assert.are.equal("host", game.cancelReason)
			assert.are.same({}, Rules.Roll(game, "Alice", 500, 1, 1000, t + 6))
			assert.are.same({}, Rules.Tick(game, t + 45, rngSame))
		end)
	end)

	describe("queries", function()
		it("AC-03-29 answer for the lobby", function()
			local game = Rules.New(opts, t0)
			assert.is_nil(Rules.Current(game))
			assert.are.same({}, Rules.Alive(game))
			assert.is_true(Rules.IsLive(game))
		end)

		it("AC-03-29 answer while rolling after an out", function()
			local game, t = threePlayerGame()
			Rules.Roll(game, "Alice", 1, 1, 1000, t + 1)
			local name, range = Rules.Current(game)
			assert.are.equal("Bob", name)
			assert.are.equal(1000, range)
			assert.are.same({ "Bob", "Carl" }, Rules.Alive(game))
			assert.is_true(Rules.IsLive(game))
		end)

		it("AC-03-29 answer after a finish", function()
			local game = finishedGame()
			assert.is_nil(Rules.Current(game))
			assert.are.same({ "Bob" }, Rules.Alive(game))
			assert.is_false(Rules.IsLive(game))
		end)

		it("AC-03-29 IsLive is false after a cancel", function()
			local game = Rules.New(opts, t0)
			Rules.Cancel(game, t0 + 1)
			assert.is_false(Rules.IsLive(game))
		end)
	end)

	describe("full scripted game", function()
		-- Four players; "Natus Vincere" has a space in its name, as names on
		-- this server can. With rngOne the Fisher-Yates shuffle of
		-- { Alice, Bob, Carl, Natus Vincere } gives { Bob, Carl, Natus Vincere, Alice }.
		-- The script covers: countdowns, a repeat join, close, an out-of-turn
		-- roll, a wrong-range roll, reminders, a 1 (range resets), a forfeit
		-- (range carries over), a second 1 that ends the game, and that
		-- nothing happens afterwards.
		it("AC-03-30 produces the exact event sequence", function()
			local t = t0 + 60 -- close time
			local NV = "Natus Vincere"
			local game, newEvents = Rules.New(opts, t0)
			assert.are.same({ { type = "kickoff" } }, newEvents)

			local script = {
				{ "join Alice", function() return Rules.Join(game, "Alice", t0 + 1) end,
					{ { type = "joined", name = "Alice" } } },
				{ "join Bob", function() return Rules.Join(game, "Bob", t0 + 2) end,
					{ { type = "joined", name = "Bob" } } },
				{ "join Carl", function() return Rules.Join(game, "Carl", t0 + 3) end,
					{ { type = "joined", name = "Carl" } } },
				{ "tick 31: countdown 30", function() return Rules.Tick(game, t0 + 31, rngOne) end,
					{ { type = "countdown", secondsLeft = 30, names = { "Alice", "Bob", "Carl" } } } },
				{ "join Natus Vincere", function() return Rules.Join(game, NV, t0 + 32) end,
					{ { type = "joined", name = NV } } },
				{ "join Bob again", function() return Rules.Join(game, "Bob", t0 + 33) end,
					{} },
				{ "tick 46: countdown 15", function() return Rules.Tick(game, t0 + 46, rngOne) end,
					{ { type = "countdown", secondsLeft = 15, names = { "Alice", "Bob", "Carl", NV } } } },
				{ "tick 50: nothing", function() return Rules.Tick(game, t0 + 50, rngOne) end,
					{} },
				{ "tick 55: countdown 5", function() return Rules.Tick(game, t0 + 55, rngOne) end,
					{ { type = "countdown", secondsLeft = 5, names = { "Alice", "Bob", "Carl", NV } } } },
				{ "tick 60: close", function() return Rules.Tick(game, t, rngOne) end,
					{
						{ type = "closed", joined = { "Alice", "Bob", "Carl", NV } },
						{ type = "order", order = { "Bob", "Carl", NV, "Alice" } },
						{ type = "call", name = "Bob", range = 1000 },
					} },
				{ "Alice rolls out of turn", function() return Rules.Roll(game, "Alice", 500, 1, 1000, t + 5) end,
					{} },
				{ "Bob rolls the wrong range", function() return Rules.Roll(game, "Bob", 500, 1, 500, t + 6) end,
					{ { type = "wrongRange", name = "Bob", range = 1000 } } },
				{ "Bob rolls 800", function() return Rules.Roll(game, "Bob", 800, 1, 1000, t + 7) end,
					{ { type = "call", name = "Carl", range = 800 } } },
				{ "tick +30: nothing (22 s left)", function() return Rules.Tick(game, t + 30, rngOne) end,
					{} },
				{ "tick +32: reminder 20", function() return Rules.Tick(game, t + 32, rngOne) end,
					{ { type = "reminder", name = "Carl", secondsLeft = 20, range = 800 } } },
				{ "Carl rolls 300", function() return Rules.Roll(game, "Carl", 300, 1, 800, t + 33) end,
					{ { type = "call", name = NV, range = 300 } } },
				{ "Natus Vincere rolls 1", function() return Rules.Roll(game, NV, 1, 1, 300, t + 40) end,
					{
						{ type = "out", name = NV, left = 3 },
						{ type = "call", name = "Alice", range = 1000 },
					} },
				{ "Alice rolls 50", function() return Rules.Roll(game, "Alice", 50, 1, 1000, t + 45) end,
					{ { type = "call", name = "Bob", range = 50 } } },
				{ "tick +80: reminder 10", function() return Rules.Tick(game, t + 80, rngOne) end,
					{ { type = "reminder", name = "Bob", secondsLeft = 10, range = 50 } } },
				{ "tick +90: Bob forfeits", function() return Rules.Tick(game, t + 90, rngOne) end,
					{
						{ type = "forfeit", name = "Bob", left = 2 },
						{ type = "call", name = "Carl", range = 50 },
					} },
				{ "tick +90 again: nothing", function() return Rules.Tick(game, t + 90, rngOne) end,
					{} },
				{ "Carl rolls 7", function() return Rules.Roll(game, "Carl", 7, 1, 50, t + 100) end,
					{ { type = "call", name = "Alice", range = 7 } } },
				{ "Alice rolls 1: Carl wins", function() return Rules.Roll(game, "Alice", 1, 1, 7, t + 110) end,
					{
						{ type = "out", name = "Alice", left = 1 },
						{ type = "winner", name = "Carl", losers = { NV, "Bob", "Alice" }, wager = 10000, total = 30000 },
					} },
				{ "roll after finish", function() return Rules.Roll(game, "Carl", 5, 1, 1000, t + 120) end,
					{} },
				{ "tick after finish", function() return Rules.Tick(game, t + 200, rngOne) end,
					{} },
				{ "cancel after finish", function() return Rules.Cancel(game, t + 200) end,
					{} },
				{ "join after finish", function() return Rules.Join(game, "Dave", t + 200) end,
					{} },
			}

			for _, step in ipairs(script) do
				local label, act, expected = step[1], step[2], step[3]
				assert.are.same(expected, act(), label)
			end

			assert.are.equal("finished", game.phase)
			assert.are.equal("Carl", game.winner)
			assert.are.equal(t + 110, game.endedAt)
			assert.is_nil(game.cancelReason)
			assert.are.same({ "Alice", "Bob", "Carl", NV }, game.joined)
			assert.are.same({ "Bob", "Carl", NV, "Alice" }, game.order)
			assert.are.same({ Alice = "out", Bob = "forfeit", Carl = "in", [NV] = "out" }, game.status)
			assert.are.same({ NV, "Bob", "Alice" }, game.eliminated)
			assert.are.same({
				{ name = "Bob", roll = 800, max = 1000 },
				{ name = "Carl", roll = 300, max = 800 },
				{ name = NV, roll = 1, max = 300 },
				{ name = "Alice", roll = 50, max = 1000 },
				{ name = "Carl", roll = 7, max = 50 },
				{ name = "Alice", roll = 1, max = 7 },
			}, game.rolls)
			assert.are.same({ [30] = true, [15] = true, [5] = true }, game.countdownSent)
		end)
	end)
end)
