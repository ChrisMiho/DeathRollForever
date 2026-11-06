describe("Chat", function()
	local Chat

	before_each(function()
		local ns = LoadAddonFile("src/Money.lua")
		LoadAddonFile("src/Rules.lua", ns)
		LoadAddonFile("src/Chat.lua", ns)
		Chat = ns.Chat
	end)

	describe("Prefix (AC-04-22: existing tests kept)", function()
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
		local game

		before_each(function()
			-- The v3 game fixture (03-rules-engine): only the fields Chat reads.
			game = { wager = 1000000, rollMax = 100, joinWord = "1", joinTime = 60, rollTime = 45 }
		end)

		-- Renders one event and asserts it gives exactly one prefixed line
		-- with the given body.
		local function assertLine(expectedBody, event)
			local lines = Chat.Render(event, game)
			assert.are.same({ PREFIX .. expectedBody }, lines)
		end

		it("AC-04-01 kickoff with the fixture game", function()
			assertLine(
				"Death roll starting! 100g per person. Everyone rolls 1-100 once: highest wins, "
					.. "lowest pays the difference. Type 1 here to join. 60 seconds!" .. STAY_NEAR,
				{ type = "kickoff" }
			)
		end)

		it("AC-04-02 kickoff reads wager, roll max and join word from the game", function()
			game = { wager = 15045, rollMax = 1000, joinWord = "roll", joinTime = 60, rollTime = 45 }
			assertLine(
				"Death roll starting! 1g 50s 45c per person. Everyone rolls 1-1000 once: highest wins, "
					.. "lowest pays the difference. Type roll here to join. 60 seconds!" .. STAY_NEAR,
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

		it("AC-04-06 call tells everyone the range and the seconds", function()
			assertLine("Everyone, type /roll 100 now! 45 seconds.",
				{ type = "call", names = { "Alice", "Bob" }, max = 100, seconds = 45 })
		end)

		it("AC-04-07 wrongRange repeats the range", function()
			assertLine("Carl, wrong range. Type /roll 100",
				{ type = "wrongRange", name = "Carl", max = 100 })
		end)

		it("AC-04-08 reminder gives seconds left, who is still to roll and the range", function()
			assertLine("10 seconds! Still to roll: Carl, Dan. Type /roll 100",
				{ type = "reminder", names = { "Carl", "Dan" }, secondsLeft = 10, max = 100 })
		end)

		it("AC-04-09 satOut with one name uses the singular form", function()
			assertLine("Carl did not roll in time and sits out.",
				{ type = "satOut", names = { "Carl" } })
		end)

		it("AC-04-10 satOut with several names uses the plural form", function()
			assertLine("Carl, Dan did not roll in time and sit out.",
				{ type = "satOut", names = { "Carl", "Dan" } })
		end)

		it("AC-04-11 allTied names the roll and asks for another", function()
			assertLine("Everyone rolled 50! Roll again.",
				{ type = "allTied", roll = 50, names = { "Alice", "Bob" } })
		end)

		it("AC-04-12 tieBreak for the highest only", function()
			assertLine("Tie for highest: Alice, Eve. Tied players, type /roll 100 again! 45 seconds.",
				{ type = "tieBreak", high = { "Alice", "Eve" }, low = nil, max = 100, seconds = 45 })
		end)

		it("AC-04-13 tieBreak for the lowest only", function()
			assertLine("Tie for lowest: Bob, Carl. Tied players, type /roll 100 again! 45 seconds.",
				{ type = "tieBreak", high = nil, low = { "Bob", "Carl" }, max = 100, seconds = 45 })
		end)

		it("AC-04-14 tieBreak for both ends", function()
			assertLine(
				"Tie for highest: Alice, Eve. Tie for lowest: Bob, Carl. "
					.. "Tied players, type /roll 100 again! 45 seconds.",
				{ type = "tieBreak", high = { "Alice", "Eve" }, low = { "Bob", "Carl" }, max = 100, seconds = 45 }
			)
		end)

		it("AC-04-15 winner names both ends, their rolls and what is owed", function()
			assertLine("WINNER: Alice with 97! Dan rolled 8 and owes Alice 89g.",
				{ type = "winner", name = "Alice", loser = "Dan", high = 97, low = 8, owed = 890000 })
		end)

		it("AC-04-16 winner formats a small debt in copper", function()
			assertLine("WINNER: Bob with 5! Alice rolled 2 and owes Bob 30c.",
				{ type = "winner", name = "Bob", loser = "Alice", high = 5, low = 2, owed = 30 })
		end)

		it("RF-4 winner formats a debt in silver", function()
			assertLine("WINNER: Bob with 3! Alice rolled 1 and owes Bob 3s.",
				{ type = "winner", name = "Bob", loser = "Alice", high = 3, low = 1, owed = 300 })
		end)

		it("AC-04-17 cancelled by the host", function()
			assertLine("Game cancelled by the host.", { type = "cancelled", reason = "host" })
		end)

		it("AC-04-18 cancelled with too few players quotes MIN_PLAYERS", function()
			assertLine("Not enough players (need 2). Game cancelled.",
				{ type = "cancelled", reason = "tooFew" })
		end)

		it("AC-04-19 cancelled because nobody rolled the tie-break", function()
			assertLine("Nobody rolled the tie-break. Game cancelled.",
				{ type = "cancelled", reason = "noRolls" })
		end)

		it("AC-04-20 joined, rolled and unknown events render nothing", function()
			assert.are.same({}, Chat.Render({ type = "joined", name = "Bob" }, game))
			assert.are.same({}, Chat.Render({ type = "rolled", name = "Bob", roll = 5, waiting = 2 }, game))
			assert.are.same({}, Chat.Render({ type = "nope" }, game))
		end)

		it("AC-04-21 every line is prefixed and at most 255 characters for 5 names", function()
			local five = { "Natus Vincere", "Bob", "Carl", "Dan", "Eve" }
			local events = {
				{ type = "kickoff" },
				{ type = "countdown", secondsLeft = 30, names = five },
				{ type = "closed", joined = five },
				{ type = "call", names = five, max = 100, seconds = 45 },
				{ type = "wrongRange", name = "Natus Vincere", max = 100 },
				{ type = "reminder", names = five, secondsLeft = 20, max = 100 },
				{ type = "satOut", names = five },
				{ type = "allTied", roll = 50, names = five },
				{ type = "tieBreak", high = { "Natus Vincere", "Bob", "Carl" }, low = { "Dan", "Eve" },
					max = 100, seconds = 45 },
				{ type = "winner", name = "Natus Vincere", loser = "Eve", high = 97, low = 8, owed = 890000 },
				{ type = "cancelled", reason = "host" },
				{ type = "cancelled", reason = "tooFew" },
				{ type = "cancelled", reason = "noRolls" },
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
			assertLine("Natus Vincere, wrong range. Type /roll 100",
				{ type = "wrongRange", name = "Natus Vincere", max = 100 })
		end)

		it("rejects a non-table event or game", function()
			assert.has_error(function() Chat.Render(nil, game) end)
			assert.has_error(function() Chat.Render({ type = "kickoff" }, nil) end)
		end)
	end)
end)
