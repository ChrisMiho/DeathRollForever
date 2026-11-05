describe("Parse", function()
	local Parse, Money

	before_each(function()
		local ns = LoadAddonFile("src/Money.lua")
		LoadAddonFile("src/Parse.lua", ns)
		Parse = ns.Parse
		Money = ns.Money
	end)

	local function assertRoll(message, name, roll, min, max, pattern)
		local gotName, gotRoll, gotMin, gotMax = Parse.Roll(message, pattern)
		assert.are.equal(name, gotName)
		assert.are.equal(roll, gotRoll)
		assert.are.equal(min, gotMin)
		assert.are.equal(max, gotMax)
	end

	local function assertStartError(name, args, expectedError)
		local opts, err = Parse.StartArgs(name, args)
		assert.is_nil(opts)
		assert.are.equal(expectedError, err)
	end

	describe("constants", function()
		it("exposes the contract's pattern, channels and text", function()
			assert.are.equal("^(.-) rolls (%d+) %((%d+)%-(%d+)%)$", Parse.ROLL_PATTERN)
			assert.are.same({
				g = "GUILD", guild = "GUILD",
				p = "PARTY", party = "PARTY",
				r = "RAID", raid = "RAID",
			}, Parse.CHANNELS)
			assert.are.equal("Usage: /dr g|p|r <wager> [first roll]", Parse.USAGE)
			assert.are.equal("First roll must be a whole number from 2 to 1000000", Parse.FIRST_ROLL_ERROR)
		end)
	end)

	describe("JoinWord", function()
		it("AC-02-01 matches the join word exactly", function()
			assert.is_true(Parse.JoinWord("1", "1"))
		end)

		it("AC-02-02 ignores leading and trailing spaces", function()
			assert.is_true(Parse.JoinWord("  1 ", "1"))
		end)

		it("AC-02-03 ignores case", function()
			assert.is_true(Parse.JoinWord("ROLL", "roll"))
		end)

		it("AC-02-04 rejects text that only contains the join word", function()
			assert.is_false(Parse.JoinWord("1!", "1"))
			assert.is_false(Parse.JoinWord("me 1", "1"))
			assert.is_false(Parse.JoinWord("11", "1"))
		end)

		it("AC-02-05 rejects empty and nil messages", function()
			assert.is_false(Parse.JoinWord("", "1"))
			assert.is_false(Parse.JoinWord(nil, "1"))
		end)
	end)

	describe("Roll", function()
		it("AC-02-06 reads a roll result [P0-ROLL]", function()
			assertRoll("Alice rolls 734 (1-1000)", "Alice", 734, 1, 1000)
		end)

		it("AC-02-07 reads a roll of 1 in range 1-1", function()
			assertRoll("Alice rolls 1 (1-1)", "Alice", 1, 1, 1)
		end)

		it("AC-02-08 keeps a realm suffix in the name", function()
			assertRoll("Alice-Stormrage rolls 5 (1-10)", "Alice-Stormrage", 5, 1, 10)
		end)

		it("AC-02-08b reads a name containing a space [P0-ROLL]", function()
			assertRoll("Natus Vincere rolls 818 (1-1000)", "Natus Vincere", 818, 1, 1000)
		end)

		it("AC-02-09 returns nil for other system messages, empty and nil", function()
			assert.is_nil(Parse.Roll("Alice has gone offline."))
			assert.is_nil(Parse.Roll(""))
			assert.is_nil(Parse.Roll(nil))
		end)

		it("AC-02-10 accepts a custom pattern", function()
			assertRoll("X wuerfelt 3 (1-9)", "X", 3, 1, 9, "^(%S+) wuerfelt (%d+) %((%d+)%-(%d+)%)$")
		end)

		it("returns the three numbers as integers", function()
			local _, roll, min, max = Parse.Roll("Alice rolls 734 (1-1000)")
			assert.are.equal("number", type(roll))
			assert.are.equal("number", type(min))
			assert.are.equal("number", type(max))
		end)
	end)

	describe("Command", function()
		it("AC-02-11 splits the name from its arguments", function()
			assert.are.same({ name = "g", args = { "1g", "500" } }, Parse.Command("g 1g 500"))
		end)

		it("AC-02-12 trims, collapses spaces and lower-cases only the name", function()
			assert.are.same({ name = "g", args = { "1G" } }, Parse.Command("  G   1G "))
		end)

		it("AC-02-13 gives empty args for a bare name", function()
			assert.are.same({ name = "cancel", args = {} }, Parse.Command("cancel"))
		end)

		it("AC-02-14 gives an empty name for empty and nil text", function()
			assert.are.same({ name = "", args = {} }, Parse.Command(""))
			assert.are.same({ name = "", args = {} }, Parse.Command(nil))
		end)
	end)

	describe("StartArgs", function()
		it("AC-02-15 reads a channel and wager with no first roll", function()
			local opts, err = Parse.StartArgs("g", { "1g" })
			assert.is_nil(err)
			assert.are.same({ channel = "GUILD", wager = 10000 }, opts)
			assert.is_nil(opts.startRoll)
		end)

		it("AC-02-16 maps every channel key", function()
			assert.are.equal("GUILD", Parse.StartArgs("guild", { "1g" }).channel)
			assert.are.equal("PARTY", Parse.StartArgs("p", { "50s" }).channel)
			assert.are.equal("PARTY", Parse.StartArgs("party", { "50s" }).channel)
			assert.are.equal("RAID", Parse.StartArgs("r", { "50s" }).channel)
			assert.are.equal("RAID", Parse.StartArgs("raid", { "50s" }).channel)
		end)

		it("AC-02-17 reads the first roll", function()
			assert.are.equal(500, Parse.StartArgs("g", { "1g", "500" }).startRoll)
		end)

		it("AC-02-18 rejects an unknown channel with the usage line", function()
			assertStartError("x", { "1g" }, Parse.USAGE)
		end)

		it("AC-02-19 rejects a missing wager with the usage line", function()
			assertStartError("g", {}, Parse.USAGE)
		end)

		it("AC-02-20 rejects a bad wager with the Money error", function()
			assertStartError("g", { "abc" }, Money.ERROR)
		end)

		it("AC-02-21 rejects a first roll that is not a whole number from 2 to 1000000", function()
			assertStartError("g", { "1g", "1" }, Parse.FIRST_ROLL_ERROR)
			assertStartError("g", { "1g", "12.5" }, Parse.FIRST_ROLL_ERROR)
			assertStartError("g", { "1g", "abc" }, Parse.FIRST_ROLL_ERROR)
			assertStartError("g", { "1g", "1000001" }, Parse.FIRST_ROLL_ERROR)
		end)

		it("AC-02-22 rejects a third argument with the usage line", function()
			assertStartError("g", { "1g", "500", "extra" }, Parse.USAGE)
		end)

		it("accepts the first roll bounds 2 and 1000000", function()
			assert.are.equal(2, Parse.StartArgs("g", { "1g", "2" }).startRoll)
			assert.are.equal(1000000, Parse.StartArgs("g", { "1g", "1000000" }).startRoll)
		end)
	end)
end)
