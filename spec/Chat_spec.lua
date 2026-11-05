describe("Chat", function()
	local Chat, Rules

	before_each(function()
		local ns = LoadAddonFile("src/Money.lua")
		LoadAddonFile("src/Rules.lua", ns)
		LoadAddonFile("src/Chat.lua", ns)
		Chat = ns.Chat
		Rules = ns.Rules
	end)

	describe("Prefix (AC-04-18: existing tests kept)", function()
		it("puts the addon prefix and a space before the text", function()
			assert.are.equal("[DeathRoll] Alice, /roll 1000", Chat.Prefix("Alice, /roll 1000"))
		end)

		it("rejects an empty string", function()
			assert.has_error(function() Chat.Prefix("") end)
		end)

		it("rejects a non-string", function()
			assert.has_error(function() Chat.Prefix(nil) end)
		end)
	end)

	describe("Render", function()
		local PREFIX = "[DeathRoll] "
		local STAY_NEAR = " Stay near the host so your rolls are seen."
		local opts = {
			host = "Alice", channel = "GUILD", wager = 10000, startRoll = 1000,
			joinWord = "1", joinTime = 60, turnTimer = 45,
		}
		local game

		before_each(function()
			game = Rules.New(opts, 1000)
		end)

		-- Renders one event and asserts it gives exactly one prefixed line
		-- with the given body.
		local function assertLine(expectedBody, event)
			local lines = Chat.Render(event, game)
			assert.are.same({ PREFIX .. expectedBody }, lines)
		end

		it("AC-04-01 kickoff with the fixture game", function()
			assertLine(
				"Death roll starting! 1g per person, first roll 1-1000. Type 1 here to join. 60 seconds! (45s per turn)"
					.. STAY_NEAR,
				{ type = "kickoff" }
			)
		end)

		it("AC-04-02 kickoff reads wager, start roll and join word from the game", function()
			game = Rules.New({
				host = "Alice", channel = "GUILD", wager = 15045, startRoll = 500,
				joinWord = "roll", joinTime = 60, turnTimer = 45,
			}, 1000)
			assertLine(
				"Death roll starting! 1g 50s 45c per person, first roll 1-500. Type roll here to join. 60 seconds! "
					.. "(45s per turn)" .. STAY_NEAR,
				{ type = "kickoff" }
			)
		end)

		it("AC-04-03 countdown lists who is in", function()
			assertLine("30 seconds left to join! 2 in: Alice, Bob",
				{ type = "countdown", secondsLeft = 30, names = { "Alice", "Bob" } })
		end)

		it("AC-04-04 countdown with nobody in has no colon or list", function()
			assertLine("5 seconds left to join! 0 in",
				{ type = "countdown", secondsLeft = 5, names = {} })
		end)

		it("AC-04-05 closed counts and lists the players", function()
			assertLine("Joining closed! 3 players in: Alice, Bob, Carl",
				{ type = "closed", joined = { "Alice", "Bob", "Carl" } })
		end)

		it("AC-04-06 order lists the shuffled order", function()
			assertLine("Roll order: Carl, Alice, Bob",
				{ type = "order", order = { "Carl", "Alice", "Bob" } })
		end)

		it("AC-04-07 call names the player and the range", function()
			assertLine("Carl, you're up! Type /roll 734",
				{ type = "call", name = "Carl", range = 734 })
		end)

		it("AC-04-08 wrongRange repeats the range", function()
			assertLine("Carl, wrong range. Type /roll 734",
				{ type = "wrongRange", name = "Carl", range = 734 })
		end)

		it("AC-04-09 reminder gives seconds left and the range", function()
			assertLine("Carl, 10 seconds! Type /roll 734",
				{ type = "reminder", name = "Carl", secondsLeft = 10, range = 734 })
		end)

		it("AC-04-10 forfeit says who is out and how many are left", function()
			assertLine("Carl did not roll in time and is OUT. 4 left.",
				{ type = "forfeit", name = "Carl", left = 4 })
		end)

		it("AC-04-11 out says the range resets", function()
			assertLine("Carl rolled 1 and is OUT! 4 left. Range resets.",
				{ type = "out", name = "Carl", left = 4 })
		end)

		it("AC-04-11b out with one left drops the range sentence", function()
			assertLine("Carl rolled 1 and is OUT! 1 left.",
				{ type = "out", name = "Carl", left = 1 })
		end)

		it("AC-04-12 winner with several losers uses the plural form and the total", function()
			assertLine("WINNER: Eve! Alice, Bob, Carl, Dan each owe Eve 1g (4g total).",
				{ type = "winner", name = "Eve", losers = { "Alice", "Bob", "Carl", "Dan" },
					wager = 10000, total = 40000 })
		end)

		it("AC-04-13 winner with one loser uses the singular form and no total", function()
			assertLine("WINNER: Eve! Alice owes Eve 50s.",
				{ type = "winner", name = "Eve", losers = { "Alice" }, wager = 5000, total = 5000 })
		end)

		it("AC-04-14 cancelled by the host", function()
			assertLine("Game cancelled by the host.", { type = "cancelled", reason = "host" })
		end)

		it("AC-04-15 cancelled with too few players quotes MIN_PLAYERS", function()
			assertLine("Not enough players (need 2). Game cancelled.",
				{ type = "cancelled", reason = "tooFew" })
		end)

		it("AC-04-16 joined and unknown events render nothing", function()
			assert.are.same({}, Chat.Render({ type = "joined", name = "Bob" }, game))
			assert.are.same({}, Chat.Render({ type = "nope" }, game))
		end)

		it("AC-04-17 every line is prefixed and at most 255 characters for 5 names", function()
			local five = { "Natus Vincere", "Bob", "Carl", "Dan", "Eve" }
			local losers = { "Natus Vincere", "Bob", "Carl", "Dan" }
			local events = {
				{ type = "kickoff" },
				{ type = "countdown", secondsLeft = 30, names = five },
				{ type = "closed", joined = five },
				{ type = "order", order = five },
				{ type = "call", name = "Natus Vincere", range = 1000 },
				{ type = "wrongRange", name = "Natus Vincere", range = 1000 },
				{ type = "reminder", name = "Natus Vincere", secondsLeft = 20, range = 1000 },
				{ type = "forfeit", name = "Natus Vincere", left = 4 },
				{ type = "out", name = "Natus Vincere", left = 4 },
				{ type = "winner", name = "Eve", losers = losers, wager = 10000, total = 40000 },
				{ type = "winner", name = "Eve", losers = { "Natus Vincere" }, wager = 10000, total = 10000 },
				{ type = "cancelled", reason = "host" },
				{ type = "cancelled", reason = "tooFew" },
			}
			for _, event in ipairs(events) do
				local lines = Chat.Render(event, game)
				assert.are.equal(1, #lines, event.type)
				local line = lines[1]
				assert.are.equal(PREFIX, line:sub(1, #PREFIX), event.type)
				assert.is_true(#line <= 255, event.type .. " is " .. #line .. " characters")
			end
		end)

		it("keeps a name with a space as a plain string", function()
			assertLine("Natus Vincere, you're up! Type /roll 1000",
				{ type = "call", name = "Natus Vincere", range = 1000 })
		end)
	end)
end)
