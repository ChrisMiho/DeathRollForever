describe("Rules", function()
	local Rules

	-- Fixtures from 03-rules-engine.md, Acceptance criteria.
	local opts = {
		host = "Alice",
		channel = "GUILD",
		wager = 1000000,
		rollMax = 100,
		joinWord = "1",
		joinTime = 60,
		rollTime = 45,
	}
	local t0 = 1000

	before_each(function()
		Rules = LoadAddonFile("src/Rules.lua").Rules
	end)

	local function copyOpts()
		local out = {}
		for k, v in pairs(opts) do out[k] = v end
		return out
	end

	-- R(game, name, roll, at) is Roll(game, name, roll, 1, 100, at).
	local function R(game, name, roll, at)
		return Rules.Roll(game, name, roll, 1, 100, at)
	end

	-- A closed game with the given players in join order.
	-- Returns the game and the close time t = t0 + 60.
	local function closedGame(names)
		local game = Rules.New(opts, t0)
		for i, name in ipairs(names) do
			Rules.Join(game, name, t0 + i)
		end
		local t = t0 + 60
		Rules.Tick(game, t)
		return game, t
	end

	local function threePlayerGame()
		return closedGame({ "Alice", "Bob", "Carl" })
	end

	local function fourPlayerGame()
		return closedGame({ "Alice", "Bob", "Carl", "Dan" })
	end

	local function fivePlayerGame()
		return closedGame({ "Alice", "Bob", "Carl", "Dan", "Eve" })
	end

	-- A finished 3-player game: Alice 97, Bob 61, Carl 8.
	local function finishedGame()
		local game, t = threePlayerGame()
		R(game, "Alice", 97, t + 1)
		R(game, "Bob", 61, t + 2)
		R(game, "Carl", 8, t + 3)
		return game, t + 3
	end

	-- As AC-03-29: a 4-player game in a high tie-break between Alice and Dan,
	-- Carl already the loser. The tie-break started at t + 4.
	local function highTieGame()
		local game, t = fourPlayerGame()
		R(game, "Alice", 97, t + 1)
		R(game, "Bob", 61, t + 2)
		R(game, "Carl", 8, t + 3)
		local events = R(game, "Dan", 97, t + 4)
		return game, t, events
	end

	-- As AC-03-32: a 4-player game in a low tie-break between Bob and Carl,
	-- Alice already the winner. The tie-break started at t + 4.
	local function lowTieGame()
		local game, t = fourPlayerGame()
		R(game, "Alice", 97, t + 1)
		R(game, "Bob", 8, t + 2)
		R(game, "Carl", 8, t + 3)
		local events = R(game, "Dan", 61, t + 4)
		return game, t, events
	end

	describe("constants", function()
		it("exposes DEFAULTS, COUNTDOWN, REMINDERS and MIN_PLAYERS from the contract", function()
			assert.are.same({ rollMax = 100, joinTime = 45, rollTime = 45, joinWord = "1" }, Rules.DEFAULTS)
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
			assert.are.equal(1, game.round)
			assert.is_nil(game.tie)
			assert.are.same({}, game.rollers)
			assert.are.same({}, game.rolls)
			assert.are.same({}, game.tieRolls)
			assert.are.same({}, game.history)
			assert.are.same({}, game.satOut)
			assert.are.same({}, game.joined)
			assert.are.same({}, game.countdownSent)
			assert.are.same({}, game.remindersSent)
			assert.are.equal(t0, game.createdAt)
			assert.are.equal("Alice", game.host)
			assert.are.equal("GUILD", game.channel)
			assert.are.equal(1000000, game.wager)
			assert.are.equal(100, game.rollMax)
			assert.are.equal("1", game.joinWord)
			assert.are.equal(60, game.joinTime)
			assert.are.equal(45, game.rollTime)
			assert.is_nil(game.high)
			assert.is_nil(game.low)
			assert.is_nil(game.winner)
			assert.is_nil(game.losers)
			assert.is_nil(game.owed)
			assert.is_nil(game.endedAt)
			assert.is_nil(game.cancelReason)
			assert.are.same({ { type = "kickoff" } }, events)
		end)

		it("AC-03-02 raises when rollMax is missing", function()
			local bad = copyOpts()
			bad.rollMax = nil
			assert.has_error(function() Rules.New(bad, t0) end)
		end)

		it("AC-03-02 raises when rollTime is a string", function()
			local bad = copyOpts()
			bad.rollTime = "45"
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
			assert.are.same({}, Rules.Join(game, "Dan", t + 1))
			assert.are.same({ "Alice", "Bob", "Carl" }, game.joined)
		end)
	end)

	describe("Tick in the lobby", function()
		it("AC-03-05 returns nothing before the first marker", function()
			local game = Rules.New(opts, t0)
			assert.are.same({}, Rules.Tick(game, t0 + 10))
		end)

		it("AC-03-06 posts the 30 second countdown once", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Bob", t0 + 1)
			assert.are.same(
				{ { type = "countdown", secondsLeft = 30, names = { "Bob" } } },
				Rules.Tick(game, t0 + 30)
			)
			assert.are.same({}, Rules.Tick(game, t0 + 30))
		end)

		it("AC-03-07 posts each marker as it is passed", function()
			local game = Rules.New(opts, t0)
			assert.are.same({ { type = "countdown", secondsLeft = 30, names = {} } }, Rules.Tick(game, t0 + 31))
			assert.are.same({ { type = "countdown", secondsLeft = 15, names = {} } }, Rules.Tick(game, t0 + 46))
		end)

		it("AC-03-08 posts only the smallest of several markers passed at once", function()
			local game = Rules.New(opts, t0)
			local events = Rules.Tick(game, t0 + 46)
			assert.are.same({ { type = "countdown", secondsLeft = 15, names = {} } }, events)
			assert.is_true(game.countdownSent[30])
			assert.is_true(game.countdownSent[15])
		end)

		it("AC-03-09 posts the 5 second countdown and then nothing", function()
			local game = Rules.New(opts, t0)
			assert.are.same({ { type = "countdown", secondsLeft = 5, names = {} } }, Rules.Tick(game, t0 + 55))
			assert.are.same({}, Rules.Tick(game, t0 + 59))
		end)

		it("AC-03-10 cancels at the deadline with one player", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Bob", t0 + 1)
			assert.are.same({ { type = "cancelled", reason = "tooFew" } }, Rules.Tick(game, t0 + 60))
			assert.are.equal("cancelled", game.phase)
			assert.are.equal("tooFew", game.cancelReason)
			assert.are.equal(t0 + 60, game.endedAt)
		end)

		it("AC-03-11 cancels at the deadline with nobody", function()
			local game = Rules.New(opts, t0)
			assert.are.same({ { type = "cancelled", reason = "tooFew" } }, Rules.Tick(game, t0 + 60))
			assert.are.equal("cancelled", game.phase)
		end)

		it("AC-03-12 closes with enough players and calls everyone", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Alice", t0 + 1)
			Rules.Join(game, "Bob", t0 + 2)
			Rules.Join(game, "Carl", t0 + 3)
			local events = Rules.Tick(game, t0 + 60)
			assert.are.same({
				{ type = "closed", joined = { "Alice", "Bob", "Carl" } },
				{ type = "call", names = { "Alice", "Bob", "Carl" }, max = 100, seconds = 45 },
			}, events)
			assert.are.equal("rolling", game.phase)
			assert.are.same({ "Alice", "Bob", "Carl" }, game.rollers)
			assert.are.equal(1105, game.rollDeadline)
			assert.are.equal(1, game.round)
			assert.is_nil(game.tie)
		end)

		it("AC-03-13 does not post a countdown in the tick that closes", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Alice", t0 + 1)
			Rules.Join(game, "Bob", t0 + 2)
			local events = Rules.Tick(game, t0 + 60)
			assert.are.same({
				{ type = "closed", joined = { "Alice", "Bob" } },
				{ type = "call", names = { "Alice", "Bob" }, max = 100, seconds = 45 },
			}, events)
		end)
	end)

	describe("Roll in a main round", function()
		it("AC-03-14 ignores a roll from someone who is not a roller", function()
			local game, t = threePlayerGame()
			assert.are.same({}, Rules.Roll(game, "Dan", 50, 1, 100, t))
			assert.are.same({}, game.rolls)
		end)

		it("AC-03-15 reports a wrong range and changes nothing", function()
			local game, t = threePlayerGame()
			assert.are.same({ { type = "wrongRange", name = "Alice", max = 100 } }, Rules.Roll(game, "Alice", 50, 1, 90, t))
			assert.are.same({ { type = "wrongRange", name = "Alice", max = 100 } }, Rules.Roll(game, "Alice", 3, 5, 100, t))
			assert.are.same({}, game.rolls)
			assert.are.same({}, game.history)
		end)

		it("AC-03-16 counts a valid roll", function()
			local game, t = threePlayerGame()
			assert.are.same({ { type = "rolled", name = "Alice", roll = 97, waiting = 2 } }, R(game, "Alice", 97, t + 1))
			assert.are.equal(97, game.rolls.Alice)
			assert.are.same({ { name = "Alice", roll = 97, max = 100, round = 1 } }, game.history)
		end)

		it("AC-03-17 ignores a second roll from the same player", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 97, t + 1)
			assert.are.same({}, R(game, "Alice", 40, t + 2))
			assert.are.equal(97, game.rolls.Alice)
			assert.are.equal(1, #game.history)
		end)

		it("AC-03-18 Waiting lists who has not rolled, in order", function()
			local lobby = Rules.New(opts, t0)
			Rules.Join(lobby, "Bob", t0 + 1)
			assert.are.same({}, Rules.Waiting(lobby))
			local game, t = threePlayerGame()
			assert.are.same({ "Alice", "Bob", "Carl" }, Rules.Waiting(game))
			R(game, "Alice", 97, t + 1)
			assert.are.same({ "Bob", "Carl" }, Rules.Waiting(game))
		end)

		it("AC-03-19 settles when the last roller rolls", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 97, t + 1)
			assert.are.same({ { type = "rolled", name = "Bob", roll = 61, waiting = 1 } }, R(game, "Bob", 61, t + 3))
			assert.are.same({
				{ type = "rolled", name = "Carl", roll = 8, waiting = 0 },
				{ type = "winner", name = "Alice", losers = { "Carl" }, high = 97, low = 8, owed = 890000 },
			}, R(game, "Carl", 8, t + 4))
			assert.are.equal("finished", game.phase)
			assert.are.equal(890000, game.owed)
			assert.are.equal("Alice", game.winner)
			assert.are.same({ "Carl" }, game.losers)
			assert.are.equal(97, game.high)
			assert.are.equal(8, game.low)
			assert.are.equal(t + 4, game.endedAt)
			assert.are.same({}, game.satOut)
			assert.are.same({}, game.rollers)
			assert.is_nil(game.tie)
		end)

		it("AC-03-20 does nothing after the game finished", function()
			local game, t = finishedGame()
			assert.are.same({}, R(game, "Alice", 50, t + 1))
			assert.are.same({}, Rules.Tick(game, t + 100))
			assert.are.same({}, Rules.Cancel(game, t + 1))
			assert.are.same({}, Rules.Join(game, "Dan", t + 1))
			assert.are.equal("finished", game.phase)
		end)
	end)

	describe("Tick in a main round", function()
		it("AC-03-21 posts each reminder once", function()
			local game, t = threePlayerGame()
			assert.are.same(
				{ { type = "reminder", names = { "Alice", "Bob", "Carl" }, secondsLeft = 20, max = 100 } },
				Rules.Tick(game, t + 25)
			)
			assert.are.same({}, Rules.Tick(game, t + 25))
			assert.are.same(
				{ { type = "reminder", names = { "Alice", "Bob", "Carl" }, secondsLeft = 10, max = 100 } },
				Rules.Tick(game, t + 35)
			)
			assert.are.same(
				{ { type = "reminder", names = { "Alice", "Bob", "Carl" }, secondsLeft = 5, max = 100 } },
				Rules.Tick(game, t + 40)
			)
		end)

		it("AC-03-22 reminds only those still to roll", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 97, t + 1)
			assert.are.same(
				{ { type = "reminder", names = { "Bob", "Carl" }, secondsLeft = 10, max = 100 } },
				Rules.Tick(game, t + 35)
			)
		end)

		it("AC-03-23 settles on the deadline with one sat out", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 61, t + 2)
			assert.are.same({
				{ type = "satOut", names = { "Carl" } },
				{ type = "winner", name = "Alice", losers = { "Bob" }, high = 97, low = 61, owed = 360000 },
			}, Rules.Tick(game, t + 45))
			assert.are.same({ "Carl" }, game.satOut)
			assert.are.equal("finished", game.phase)
		end)

		it("AC-03-24 cancels on the deadline with a single roll", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 97, t + 1)
			assert.are.same({
				{ type = "satOut", names = { "Bob", "Carl" } },
				{ type = "cancelled", reason = "tooFew" },
			}, Rules.Tick(game, t + 45))
			assert.are.equal("cancelled", game.phase)
			assert.are.equal("tooFew", game.cancelReason)
			assert.are.same({ "Bob", "Carl" }, game.satOut)
		end)

		it("AC-03-25 cancels on the deadline when nobody rolled", function()
			local game, t = threePlayerGame()
			assert.are.same({
				{ type = "satOut", names = { "Alice", "Bob", "Carl" } },
				{ type = "cancelled", reason = "tooFew" },
			}, Rules.Tick(game, t + 45))
			assert.are.equal("cancelled", game.phase)
		end)

		it("AC-03-26 does not post a reminder in the tick that settles", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 61, t + 2)
			local events = Rules.Tick(game, t + 45)
			for _, event in ipairs(events) do
				assert.are_not.equal("reminder", event.type)
			end
			assert.are.same({}, game.remindersSent)
		end)
	end)

	describe("All tied", function()
		it("AC-03-27 reruns the main round when every roll is the same", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 50, t + 3)
			R(game, "Bob", 50, t + 3)
			assert.are.same({
				{ type = "rolled", name = "Carl", roll = 50, waiting = 0 },
				{ type = "allTied", roll = 50, names = { "Alice", "Bob", "Carl" } },
				{ type = "call", names = { "Alice", "Bob", "Carl" }, max = 100, seconds = 45 },
			}, R(game, "Carl", 50, t + 3))
			assert.are.equal("rolling", game.phase)
			assert.are.equal(2, game.round)
			assert.are.same({}, game.rolls)
			assert.are.equal(t + 48, game.rollDeadline)
			assert.is_nil(game.tie)
			assert.is_nil(game.high)
			assert.is_nil(game.low)
			assert.are.same({ "Alice", "Bob", "Carl" }, game.rollers)
		end)

		it("AC-03-28 the rerun decides the game", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 50, t + 3)
			R(game, "Bob", 50, t + 3)
			R(game, "Carl", 50, t + 3)
			R(game, "Alice", 10, t + 5)
			R(game, "Bob", 20, t + 6)
			assert.are.same({
				{ type = "rolled", name = "Carl", roll = 30, waiting = 0 },
				{ type = "winner", name = "Carl", losers = { "Alice" }, high = 30, low = 10, owed = 200000 },
			}, R(game, "Carl", 30, t + 7))
			assert.are.equal("finished", game.phase)
			assert.are.equal("Carl", game.winner)
			assert.are.same({ "Alice" }, game.losers)
			assert.are.equal(30, game.high)
			assert.are.equal(10, game.low)
			assert.are.equal(200000, game.owed)
			assert.are.equal(6, #game.history)
			assert.are.equal(2, game.history[6].round)
		end)
	end)

	describe("Tie-breaks", function()
		it("AC-03-29 starts a high tie-break when two share the top roll", function()
			local game, t, events = highTieGame()
			assert.are.same({
				{ type = "rolled", name = "Dan", roll = 97, waiting = 0 },
				{ type = "tieBreak", high = { "Alice", "Dan" }, low = nil, max = 100, seconds = 45 },
			}, events)
			assert.are.equal("rolling", game.phase)
			assert.is_nil(game.winner)
			assert.are.same({ "Carl" }, game.losers)
			assert.are.equal(97, game.high)
			assert.are.equal(8, game.low)
			assert.are.same({ "Alice", "Dan" }, game.rollers)
			assert.are.equal(2, game.round)
			assert.are.same({ "Alice", "Dan" }, game.tie.high)
			assert.is_nil(game.tie.low)
			assert.are.same({}, game.tieRolls)
			assert.are.equal(t + 4 + 45, game.rollDeadline)
		end)

		it("AC-03-30 ignores a roll from a player who is not in the tie-break", function()
			local game, t = highTieGame()
			assert.are.same({}, R(game, "Bob", 50, t + 5))
			assert.are.same({}, game.tieRolls)
			assert.are.equal(61, game.rolls.Bob)
		end)

		it("AC-03-31 the tie-break decides the winner", function()
			local game, t = highTieGame()
			assert.are.same({ { type = "rolled", name = "Alice", roll = 30, waiting = 1 } }, R(game, "Alice", 30, t + 5))
			assert.are.same({
				{ type = "rolled", name = "Dan", roll = 70, waiting = 0 },
				{ type = "winner", name = "Dan", losers = { "Carl" }, high = 97, low = 8, owed = 890000 },
			}, R(game, "Dan", 70, t + 6))
			assert.are.equal("finished", game.phase)
			assert.are.equal(70, game.tieRolls.Dan)
			assert.are.equal(30, game.tieRolls.Alice)
			assert.are.equal(97, game.rolls.Alice)
			assert.are.equal(97, game.rolls.Dan)
			assert.are.equal(6, #game.history)
			assert.are.same({ name = "Dan", roll = 70, max = 100, round = 2 }, game.history[6])
		end)

		it("AC-03-32 starts a low tie-break with the winner set at once", function()
			local game, t, events = lowTieGame()
			assert.are.same({
				{ type = "rolled", name = "Dan", roll = 61, waiting = 0 },
				{ type = "tieBreak", high = nil, low = { "Bob", "Carl" }, max = 100, seconds = 45 },
			}, events)
			assert.are.equal("Alice", game.winner)
			assert.is_nil(game.losers)
			assert.is_nil(game.tie.high)
			assert.are.same({ "Bob", "Carl" }, game.tie.low)
			assert.are.same({ "Bob", "Carl" }, game.rollers)
			R(game, "Bob", 40, t + 5)
			assert.are.same({
				{ type = "rolled", name = "Carl", roll = 20, waiting = 0 },
				{ type = "winner", name = "Alice", losers = { "Carl" }, high = 97, low = 8, owed = 890000 },
			}, R(game, "Carl", 20, t + 6))
			assert.are.equal("finished", game.phase)
			assert.are.same({ "Carl" }, game.losers)
		end)

		it("AC-03-33 breaks a tie on both ends in one round", function()
			local game, t = fourPlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 97, t + 2)
			R(game, "Carl", 8, t + 3)
			assert.are.same({
				{ type = "rolled", name = "Dan", roll = 8, waiting = 0 },
				{ type = "tieBreak", high = { "Alice", "Bob" }, low = { "Carl", "Dan" }, max = 100, seconds = 45 },
			}, R(game, "Dan", 8, t + 4))
			assert.are.same({ "Alice", "Bob", "Carl", "Dan" }, game.rollers)
			assert.are.same({ "Alice", "Bob" }, game.tie.high)
			assert.are.same({ "Carl", "Dan" }, game.tie.low)
			assert.is_nil(game.winner)
			assert.is_nil(game.losers)
			R(game, "Alice", 10, t + 5)
			R(game, "Bob", 20, t + 6)
			R(game, "Carl", 30, t + 7)
			assert.are.same({
				{ type = "rolled", name = "Dan", roll = 5, waiting = 0 },
				{ type = "winner", name = "Bob", losers = { "Dan" }, high = 97, low = 8, owed = 890000 },
			}, R(game, "Dan", 5, t + 8))
			assert.are.equal("finished", game.phase)
			assert.are.equal("Bob", game.winner)
			assert.are.same({ "Dan" }, game.losers)
		end)

		it("AC-03-34 a tied player who does not roll drops out of the running", function()
			local game, t = highTieGame()
			R(game, "Alice", 30, t + 5)
			assert.are.same({
				{ type = "winner", name = "Alice", losers = { "Carl" }, high = 97, low = 8, owed = 890000 },
			}, Rules.Tick(game, t + 90))
			assert.are.equal("finished", game.phase)
			assert.are.equal("Alice", game.winner)
			assert.are.same({}, game.satOut)
		end)

		it("AC-03-35 cancels when nobody on the tied side rolls", function()
			local game, t = highTieGame()
			assert.are.same({ { type = "cancelled", reason = "noRolls" } }, Rules.Tick(game, t + 90))
			assert.are.equal("cancelled", game.phase)
			assert.are.equal("noRolls", game.cancelReason)
			assert.are.equal(t + 90, game.endedAt)
		end)

		it("AC-03-36 the no-show on the low side pays", function()
			local game, t = lowTieGame()
			R(game, "Bob", 40, t + 5)
			assert.are.same({
				{ type = "winner", name = "Alice", losers = { "Carl" }, high = 97, low = 8, owed = 890000 },
			}, Rules.Tick(game, t + 90))
			assert.are.equal("finished", game.phase)
			assert.are.same({ "Carl" }, game.losers)
		end)

		it("AC-03-48 when nobody tied for lowest rolls, they all pay", function()
			local game, t = lowTieGame()
			assert.are.same({
				{ type = "winner", name = "Alice", losers = { "Bob", "Carl" }, high = 97, low = 8, owed = 890000 },
			}, Rules.Tick(game, t + 90))
			assert.are.equal("finished", game.phase)
			assert.are.same({ "Bob", "Carl" }, game.losers)
			assert.are.equal(890000, game.owed)
		end)

		it("AC-03-49 a both-sides tie-break whose low side nobody rolls finishes once the high side does", function()
			local game, t = fourPlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 97, t + 2)
			R(game, "Carl", 8, t + 3)
			R(game, "Dan", 8, t + 4)
			R(game, "Alice", 60, t + 5)
			assert.are.same({
				{ type = "rolled", name = "Bob", roll = 40, waiting = 2 },
			}, R(game, "Bob", 40, t + 6))
			assert.are.same({
				{ type = "winner", name = "Alice", losers = { "Carl", "Dan" }, high = 97, low = 8, owed = 890000 },
			}, Rules.Tick(game, t + 90))
		end)

		it("AC-03-37 several no-shows on the low side roll off against each other", function()
			local game, t = fivePlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 8, t + 2)
			R(game, "Carl", 8, t + 3)
			R(game, "Dan", 8, t + 4)
			assert.are.same({
				{ type = "rolled", name = "Eve", roll = 50, waiting = 0 },
				{ type = "tieBreak", high = nil, low = { "Bob", "Carl", "Dan" }, max = 100, seconds = 45 },
			}, R(game, "Eve", 50, t + 5))
			R(game, "Bob", 40, t + 6)
			assert.are.same({
				{ type = "tieBreak", high = nil, low = { "Carl", "Dan" }, max = 100, seconds = 45 },
			}, Rules.Tick(game, t + 50))
			assert.are.equal(3, game.round)
			assert.are.equal("rolling", game.phase)
			assert.are.same({ "Carl", "Dan" }, game.rollers)
			assert.are.same({ "Carl", "Dan" }, game.tie.low)
			assert.is_nil(game.tie.high)
			assert.are.same({}, game.tieRolls)
			assert.are.equal(t + 50 + 45, game.rollDeadline)
			assert.is_nil(game.losers)
			assert.are.equal("Alice", game.winner)
		end)

		it("AC-03-38 a tied tie-break starts another tie-break", function()
			local game, t = highTieGame()
			R(game, "Alice", 50, t + 5)
			assert.are.same({
				{ type = "rolled", name = "Dan", roll = 50, waiting = 0 },
				{ type = "tieBreak", high = { "Alice", "Dan" }, low = nil, max = 100, seconds = 45 },
			}, R(game, "Dan", 50, t + 6))
			assert.are.equal(3, game.round)
			assert.are.same({}, game.tieRolls)
			assert.are.same({ "Alice", "Dan" }, game.rollers)
			assert.is_nil(game.winner)
			assert.are.equal(t + 6 + 45, game.rollDeadline)
		end)

		it("AC-03-39 one side resolves on the deadline while the other rolls off again", function()
			local game, t = fivePlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 97, t + 2)
			R(game, "Carl", 8, t + 3)
			R(game, "Dan", 8, t + 4)
			assert.are.same({
				{ type = "rolled", name = "Eve", roll = 8, waiting = 0 },
				{ type = "tieBreak", high = { "Alice", "Bob" }, low = { "Carl", "Dan", "Eve" }, max = 100, seconds = 45 },
			}, R(game, "Eve", 8, t + 5))
			R(game, "Alice", 60, t + 6)
			R(game, "Bob", 40, t + 7)
			R(game, "Carl", 30, t + 8)
			assert.are.same({
				{ type = "tieBreak", high = nil, low = { "Dan", "Eve" }, max = 100, seconds = 45 },
			}, Rules.Tick(game, t + 50))
			assert.are.equal("Alice", game.winner)
			assert.is_nil(game.losers)
			assert.are.equal(3, game.round)
			assert.are.same({ "Dan", "Eve" }, game.rollers)
			assert.is_nil(game.tie.high)
			assert.are.same({ "Dan", "Eve" }, game.tie.low)
		end)
	end)

	describe("Owed", function()
		it("AC-03-40 is the share of the wager that the gap makes, rounded down", function()
			assert.are.equal(890000, Rules.Owed(97, 8, 1000000, 100))
			assert.are.equal(100000, Rules.Owed(90, 80, 1000000, 100))
			assert.are.equal(30, Rules.Owed(5, 2, 10000, 1000))
			assert.are.equal(0, Rules.Owed(50, 50, 10000, 100))
		end)

		it("RF-4 rounds a fractional copper down", function()
			assert.are.equal(300, Rules.Owed(3, 1, 15045, 100))
		end)

		it("AC-03-50 stays exact when (high - low) * wager passes 2^53", function()
			-- The plain product rounds to a double and floors to 9648211512.
			assert.are.equal(9648211511, Rules.Owed(991923, 218, 9650332415, 991923))
			assert.are.equal(9999989999, Rules.Owed(1000000, 1, 9999999999, 1000000))
		end)
	end)

	describe("Cancel", function()
		it("AC-03-41 cancels in the lobby, while rolling and during a tie-break", function()
			local lobby = Rules.New(opts, t0)
			assert.are.same({ { type = "cancelled", reason = "host" } }, Rules.Cancel(lobby, t0 + 5))
			assert.are.equal("cancelled", lobby.phase)
			assert.are.equal("host", lobby.cancelReason)
			assert.are.equal(t0 + 5, lobby.endedAt)

			local rolling, t = threePlayerGame()
			assert.are.same({ { type = "cancelled", reason = "host" } }, Rules.Cancel(rolling, t + 5))
			assert.are.equal("cancelled", rolling.phase)
			assert.are.equal("host", rolling.cancelReason)

			local tieBreak, t2 = highTieGame()
			assert.are.same({ { type = "cancelled", reason = "host" } }, Rules.Cancel(tieBreak, t2 + 5))
			assert.are.equal("cancelled", tieBreak.phase)
			assert.are.equal("host", tieBreak.cancelReason)
		end)
	end)

	describe("FullName", function()
		it("AC-03-51 is the character name until a fuller one is seen", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Forgot", t0 + 1, "Forgot")
			assert.are.equal("Forgot", Rules.FullName(game, "Forgot"))
			assert.are.equal("Bob", Rules.FullName(game, "Bob"))
		end)

		it("AC-03-52 a roll line's surname is kept, and a bare name never replaces it", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Forgot", t0 + 1, "Forgot")
			Rules.Join(game, "Bob", t0 + 2)
			Rules.Tick(game, t0 + 60)
			Rules.Roll(game, "Forgot", 50, 1, 100, t0 + 61, "Forgot Shards")
			assert.are.equal("Forgot Shards", Rules.FullName(game, "Forgot"))
			Rules.Roll(game, "Forgot", 70, 1, 100, t0 + 62, "Forgot")
			assert.are.equal("Forgot Shards", Rules.FullName(game, "Forgot"))
		end)

		it("AC-03-53 joining with a surname keeps it; a stranger's roll is not remembered", function()
			local game = Rules.New(opts, t0)
			Rules.Join(game, "Forgot", t0 + 1, "Forgot Shards")
			Rules.Tick(game, t0 + 60)
			Rules.Roll(game, "Dan", 50, 1, 100, t0 + 61, "Dan Stranger")
			assert.are.equal("Forgot Shards", Rules.FullName(game, "Forgot"))
			assert.are.equal("Dan", Rules.FullName(game, "Dan"))
			assert.is_nil(game.fullNames.Dan)
		end)

		it("AC-03-54 opts.fullNames gives the host's full name from the start", function()
			local withHost = {}
			for k, v in pairs(opts) do
				withHost[k] = v
			end
			withHost.fullNames = { Alice = "Alice Vale" }
			local game = Rules.New(withHost, t0)
			assert.are.equal("Alice Vale", Rules.FullName(game, "Alice"))
			withHost.fullNames = "Alice Vale"
			assert.has_error(function() Rules.New(withHost, t0) end)
		end)
	end)

	describe("IsLive", function()
		it("AC-03-42 is true in the lobby and while rolling only", function()
			local lobby = Rules.New(opts, t0)
			assert.is_true(Rules.IsLive(lobby))
			local rolling = threePlayerGame()
			assert.is_true(Rules.IsLive(rolling))
			local finished = finishedGame()
			assert.is_false(Rules.IsLive(finished))
			local cancelled = Rules.New(opts, t0)
			Rules.Cancel(cancelled, t0 + 1)
			assert.is_false(Rules.IsLive(cancelled))
		end)
	end)

	describe("Rolls around a deadline", function()
		it("RF-1 a roll after the deadline settled the round counts for the new round", function()
			local game, t = fivePlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 61, t + 2)
			R(game, "Carl", 8, t + 3)
			R(game, "Dan", 97, t + 4)
			assert.are.same({
				{ type = "satOut", names = { "Eve" } },
				{ type = "tieBreak", high = { "Alice", "Dan" }, low = nil, max = 100, seconds = 45 },
			}, Rules.Tick(game, t + 45))
			assert.are.same(
				{ { type = "rolled", name = "Alice", roll = 30, waiting = 1 } },
				Rules.Roll(game, "Alice", 30, 1, 100, t + 46)
			)
			assert.are.equal(30, game.tieRolls.Alice)
			assert.are.equal(97, game.rolls.Alice)
		end)

		it("RF-2 a roll from a player who sat out is ignored in the tie-break", function()
			local game, t = fourPlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 97, t + 2)
			R(game, "Carl", 8, t + 3)
			assert.are.same({
				{ type = "satOut", names = { "Dan" } },
				{ type = "tieBreak", high = { "Alice", "Bob" }, low = nil, max = 100, seconds = 45 },
			}, Rules.Tick(game, t + 45))
			assert.are.same({}, Rules.Roll(game, "Dan", 50, 1, 100, t + 46))
			assert.are.same({}, game.tieRolls)
			assert.are.same({ "Dan" }, game.satOut)
		end)

		it("RF-3 a roll right after a reminder settles without another reminder", function()
			local game, t = threePlayerGame()
			R(game, "Alice", 97, t + 1)
			R(game, "Bob", 61, t + 2)
			assert.are.same(
				{ { type = "reminder", names = { "Carl" }, secondsLeft = 20, max = 100 } },
				Rules.Tick(game, t + 25)
			)
			assert.are.same({
				{ type = "rolled", name = "Carl", roll = 8, waiting = 0 },
				{ type = "winner", name = "Alice", losers = { "Carl" }, high = 97, low = 8, owed = 890000 },
			}, Rules.Roll(game, "Carl", 8, 1, 100, t + 26))
		end)
	end)

	describe("Full game", function()
		it("AC-03-43 walks a whole game and matches every event list", function()
			local names = { "Alice", "Bob", "Carl", "Dan", "Eve" }
			local game, events = Rules.New(opts, t0)
			assert.are.same({ { type = "kickoff" } }, events)

			-- Lobby: five join, one tries twice.
			for i, name in ipairs(names) do
				assert.are.same({ { type = "joined", name = name } }, Rules.Join(game, name, t0 + i))
			end
			assert.are.same({}, Rules.Join(game, "Bob", t0 + 6))
			assert.are.same({}, Rules.Tick(game, t0 + 10))
			assert.are.same({ { type = "countdown", secondsLeft = 30, names = names } }, Rules.Tick(game, t0 + 30))
			assert.are.same({ { type = "countdown", secondsLeft = 15, names = names } }, Rules.Tick(game, t0 + 45))
			assert.are.same({ { type = "countdown", secondsLeft = 5, names = names } }, Rules.Tick(game, t0 + 55))

			-- Close.
			local t = t0 + 60
			assert.are.same({
				{ type = "closed", joined = names },
				{ type = "call", names = names, max = 100, seconds = 45 },
			}, Rules.Tick(game, t))
			assert.are.equal("rolling", game.phase)
			assert.are.equal(1, game.round)

			-- Main round: a wrong range, a roll from a non-player, a second roll.
			assert.are.same({ { type = "wrongRange", name = "Alice", max = 100 } }, Rules.Roll(game, "Alice", 50, 1, 90, t + 1))
			assert.are.same({ { type = "rolled", name = "Alice", roll = 97, waiting = 4 } }, R(game, "Alice", 97, t + 2))
			assert.are.same({}, Rules.Roll(game, "Zed", 50, 1, 100, t + 3))
			assert.are.same({}, R(game, "Alice", 40, t + 4))
			assert.are.same({ { type = "rolled", name = "Bob", roll = 61, waiting = 3 } }, R(game, "Bob", 61, t + 5))
			assert.are.same({ { type = "rolled", name = "Carl", roll = 8, waiting = 2 } }, R(game, "Carl", 8, t + 6))
			assert.are.same({ { type = "rolled", name = "Dan", roll = 97, waiting = 1 } }, R(game, "Dan", 97, t + 7))
			assert.are.same({}, Rules.Tick(game, t + 10))
			assert.are.same(
				{ { type = "reminder", names = { "Eve" }, secondsLeft = 20, max = 100 } },
				Rules.Tick(game, t + 25)
			)
			assert.are.same(
				{ { type = "reminder", names = { "Eve" }, secondsLeft = 10, max = 100 } },
				Rules.Tick(game, t + 35)
			)
			assert.are.same(
				{ { type = "reminder", names = { "Eve" }, secondsLeft = 5, max = 100 } },
				Rules.Tick(game, t + 40)
			)

			-- Deadline: Eve sat out, Alice and Dan tie for highest, Carl is the loser.
			assert.are.same({
				{ type = "satOut", names = { "Eve" } },
				{ type = "tieBreak", high = { "Alice", "Dan" }, low = nil, max = 100, seconds = 45 },
			}, Rules.Tick(game, t + 45))
			assert.are.same({}, Rules.Tick(game, t + 45))
			assert.are.equal(2, game.round)
			assert.are.same({ "Eve" }, game.satOut)
			assert.are.same({ "Alice", "Dan" }, game.rollers)
			assert.is_nil(game.winner)
			assert.are.same({ "Carl" }, game.losers)
			assert.are.equal(97, game.high)
			assert.are.equal(8, game.low)
			assert.are.equal(t + 90, game.rollDeadline)

			-- Tie-break: Alice rolls, Dan does not, Eve and Bob are not rollers.
			assert.are.same({ { type = "rolled", name = "Alice", roll = 30, waiting = 1 } }, R(game, "Alice", 30, t + 50))
			assert.are.same({}, R(game, "Alice", 90, t + 51))
			assert.are.same({}, R(game, "Eve", 90, t + 52))
			assert.are.same({}, R(game, "Bob", 90, t + 53))
			assert.are.same(
				{ { type = "reminder", names = { "Dan" }, secondsLeft = 20, max = 100 } },
				Rules.Tick(game, t + 70)
			)
			assert.are.same(
				{ { type = "reminder", names = { "Dan" }, secondsLeft = 5, max = 100 } },
				Rules.Tick(game, t + 86)
			)
			assert.are.same({
				{ type = "winner", name = "Alice", losers = { "Carl" }, high = 97, low = 8, owed = 890000 },
			}, Rules.Tick(game, t + 90))

			-- Finished.
			assert.are.equal("finished", game.phase)
			assert.are.equal("Alice", game.winner)
			assert.are.same({ "Carl" }, game.losers)
			assert.are.equal(890000, game.owed)
			assert.are.equal(t + 90, game.endedAt)
			assert.is_nil(game.tie)
			assert.are.same({}, game.rollers)
			assert.are.same({ Alice = 97, Bob = 61, Carl = 8, Dan = 97 }, game.rolls)
			assert.are.same({ Alice = 30 }, game.tieRolls)
			assert.are.same({
				{ name = "Alice", roll = 97, max = 100, round = 1 },
				{ name = "Bob", roll = 61, max = 100, round = 1 },
				{ name = "Carl", roll = 8, max = 100, round = 1 },
				{ name = "Dan", roll = 97, max = 100, round = 1 },
				{ name = "Alice", roll = 30, max = 100, round = 2 },
			}, game.history)
			assert.are.same({}, Rules.Tick(game, t + 91))
			assert.are.same({}, R(game, "Dan", 50, t + 92))
			assert.are.same({}, Rules.Cancel(game, t + 93))
			assert.is_false(Rules.IsLive(game))
		end)
	end)

	describe("a solo game (New with players)", function()
		local function soloOpts(players)
			local o = copyOpts()
			o.rollTime = 15
			o.players = players
			return o
		end

		it("AC-03-44 starts straight in the round with the players in", function()
			local game, events = Rules.New(soloOpts({ "Alice", "Bob", "Carl" }), t0)
			assert.are.equal("rolling", game.phase)
			assert.are.same({ "Alice", "Bob", "Carl" }, game.joined)
			assert.are.same({ "Alice", "Bob", "Carl" }, game.rollers)
			assert.are.equal(1, game.round)
			assert.are.equal(t0 + 15, game.rollDeadline)
			assert.are.same({
				{ type = "call", names = { "Alice", "Bob", "Carl" }, max = 100, seconds = 15 },
			}, events)
		end)

		it("AC-03-44 copies the players list", function()
			local players = { "Alice", "Bob" }
			local game = Rules.New(soloOpts(players), t0)
			table.insert(players, "Carl")
			assert.are.same({ "Alice", "Bob" }, game.joined)
			assert.are.same({ "Alice", "Bob" }, game.rollers)
		end)

		it("AC-03-45 raises on a bad players list", function()
			for _, players in ipairs({ { "Alice" }, {}, { "Alice", "Alice" }, { "Alice", "" }, "Alice", { "Alice", 5 } }) do
				assert.has_error(function()
					Rules.New(soloOpts(players), t0)
				end)
			end
		end)

		it("AC-03-46 plays like any game: a no-show sits out", function()
			local game = Rules.New(soloOpts({ "Alice", "Bob", "Carl" }), t0)
			assert.are.same({ { type = "rolled", name = "Bob", roll = 90, waiting = 2 } }, R(game, "Bob", 90, t0 + 1))
			assert.are.same({ { type = "rolled", name = "Carl", roll = 10, waiting = 1 } }, R(game, "Carl", 10, t0 + 2))
			assert.are.same({
				{ type = "satOut", names = { "Alice" } },
				{ type = "winner", name = "Bob", losers = { "Carl" }, high = 90, low = 10, owed = 800000 },
			}, Rules.Tick(game, t0 + 15))
		end)

		it("AC-03-47 ignores joins", function()
			local game = Rules.New(soloOpts({ "Alice", "Bob", "Carl" }), t0)
			assert.are.same({}, Rules.Join(game, "Dan", t0))
			assert.are.same({ "Alice", "Bob", "Carl" }, game.joined)
		end)
	end)
end)
