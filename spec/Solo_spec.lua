describe("Solo", function()
	local Solo, Rules

	before_each(function()
		local ns = LoadAddonFile("src/Rules.lua")
		LoadAddonFile("src/Solo.lua", ns)
		Solo, Rules = ns.Solo, ns.Rules
	end)

	-- A fake rng that returns its arguments in order and raises when it runs out.
	local function seq(...)
		local values, i = { ... }, 0
		return function()
			i = i + 1
			assert(values[i] ~= nil, "seq ran out")
			return values[i]
		end
	end

	-- An rng that always returns lo.
	local function low(lo)
		return lo
	end

	local function soloGame(players)
		return Rules.New({
			host = "Alice", channel = "SOLO", wager = 10000, rollMax = 100,
			joinWord = "1", joinTime = 45, rollTime = 15, players = players,
		}, 1000)
	end

	local function deepCopy(t)
		if type(t) ~= "table" then return t end
		local out = {}
		for k, v in pairs(t) do out[k] = deepCopy(v) end
		return out
	end

	it("has the constants", function()
		assert.are.equal(10, Solo.BOTS)
		assert.are.equal(40, Solo.MAX_BOTS)
		assert.are.equal(15, Solo.ROLL_TIME)
		assert.are.equal("Bots must be a whole number from 1 to 40", Solo.BOTS_ERROR)
	end)

	it("AC-17-01 has 50 Horde and 50 Alliance names, all different and name-shaped", function()
		assert.are.equal(50, #Solo.NAMES.Horde)
		assert.are.equal(50, #Solo.NAMES.Alliance)
		local seen = {}
		for _, faction in ipairs({ "Horde", "Alliance" }) do
			for _, name in ipairs(Solo.NAMES[faction]) do
				assert.is_truthy(name:match("^[A-Z][a-z]+$"), name)
				assert.is_true(#name >= 3 and #name <= 12, name)
				assert.is_nil(seen[name], name)
				seen[name] = true
			end
		end
	end)

	it("AC-17-02 picks the host first, then bots", function()
		assert.are.same({ "Alice", "Gruntsalot", "Axetastic", "Zugzugson" }, Solo.Players("Alice", "Horde", 3, low))
	end)

	it("AC-17-03 picks without repeats through the shuffle", function()
		assert.are.same({ "Alice", "Healsalot", "Holypoly" }, Solo.Players("Alice", "Alliance", 2, seq(50, 2)))
	end)

	it("AC-17-04 picks 40 different Horde names", function()
		local players = Solo.Players("Alice", "Horde", 40, math.random)
		assert.are.equal(41, #players)
		assert.are.equal("Alice", players[1])
		local horde, seen = {}, {}
		for _, name in ipairs(Solo.NAMES.Horde) do horde[name] = true end
		for i = 2, 41 do
			assert.is_true(horde[players[i]], players[i])
			assert.is_nil(seen[players[i]])
			seen[players[i]] = true
		end
	end)

	it("AC-17-05 leaves out a name equal to the host's", function()
		local players = Solo.Players("Axetastic", "Horde", 40, low)
		assert.are.equal(41, #players)
		assert.are.equal("Zugzugson", players[3]) -- Axetastic's slot went to the next name
		local count = 0
		for _, name in ipairs(players) do
			if name == "Axetastic" then count = count + 1 end
		end
		assert.are.equal(1, count)
		assert.are.equal("Axetastic", players[1])
	end)

	it("AC-17-06 uses both lists, Horde first, for any other faction", function()
		assert.are.same({ "Alice", "Shieldwally" }, Solo.Players("Alice", "Neutral", 1, seq(51)))
		assert.are.same({ "Alice", "Healsalot" }, Solo.Players("Alice", nil, 1, seq(100)))
	end)

	it("AC-17-07 raises on a bad count or host", function()
		for _, count in ipairs({ 0, 41, 1.5, "3" }) do
			assert.has_error(function() Solo.Players("Alice", "Horde", count, low) end)
		end
		assert.has_error(function() Solo.Players("", "Horde", 3, low) end)
	end)

	it("AC-17-08 plans a delay and a roll for every waiting bot", function()
		local game = soloGame({ "Alice", "Bot1", "Bot2" })
		assert.are.same({
			{ name = "Bot1", delay = 0.1, roll = 40 },
			{ name = "Bot2", delay = 5.0, roll = 100 },
		}, Solo.Plan(game, "Alice", seq(1, 40, 50, 100)))
	end)

	it("AC-17-09 leaves out bots that have rolled", function()
		local game = soloGame({ "Alice", "Bot1", "Bot2" })
		Rules.Roll(game, "Bot1", 40, 1, 100, 1001)
		local plan = Solo.Plan(game, "Alice", low)
		assert.are.equal(1, #plan)
		assert.are.equal("Bot2", plan[1].name)
	end)

	it("AC-17-10 plans only the tied bots in a tie-break", function()
		local game = soloGame({ "Alice", "Bot1", "Bot2" })
		Rules.Roll(game, "Alice", 90, 1, 100, 1001)
		Rules.Roll(game, "Bot1", 10, 1, 100, 1001)
		Rules.Roll(game, "Bot2", 90, 1, 100, 1001)
		assert.are.same({ "Alice", "Bot2" }, game.tie.high)
		local plan = Solo.Plan(game, "Alice", low)
		assert.are.equal(1, #plan)
		assert.are.equal("Bot2", plan[1].name)
	end)

	it("AC-17-11 plans nothing for a finished or cancelled game", function()
		local game = soloGame({ "Alice", "Bot1" })
		Rules.Roll(game, "Alice", 90, 1, 100, 1001)
		Rules.Roll(game, "Bot1", 10, 1, 100, 1001)
		assert.are.equal("finished", game.phase)
		assert.are.same({}, Solo.Plan(game, "Alice", low))
		local cancelled = soloGame({ "Alice", "Bot1" })
		Rules.Cancel(cancelled, 1001)
		assert.are.same({}, Solo.Plan(cancelled, "Alice", low))
	end)

	it("AC-17-12 does not change the game", function()
		local game = soloGame({ "Alice", "Bot1", "Bot2" })
		local before = deepCopy(game)
		Solo.Plan(game, "Alice", math.random)
		assert.are.same(before, game)
	end)
end)
