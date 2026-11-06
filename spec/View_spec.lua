describe("View", function()
	local View
	local Money, Parse, Rules

	before_each(function()
		local ns = LoadAddonFile("src/Money.lua")
		LoadAddonFile("src/Parse.lua", ns)
		LoadAddonFile("src/Rules.lua", ns)
		LoadAddonFile("src/View.lua", ns)
		View = ns.View
		Money = ns.Money
		Parse = ns.Parse
		Rules = ns.Rules
	end)

	-- 01-window (package 14): TINT, State, ChatName, Subtitle, Help.
	describe("window (01-window)", function()
		describe("State", function()
			it("AC-06-01 State(nil) is form", function()
				assert.are.equal("form", View.State(nil))
			end)

			it("AC-06-02 a cancelled game is form", function()
				assert.are.equal("form", View.State({ phase = "cancelled" }))
			end)

			it("AC-06-03 a lobby game is lobby", function()
				assert.are.equal("lobby", View.State({ phase = "lobby" }))
			end)

			it("AC-06-04 a rolling game is rolling", function()
				assert.are.equal("rolling", View.State({ phase = "rolling" }))
			end)

			it("AC-06-05 a finished game is winner", function()
				assert.are.equal("winner", View.State({ phase = "finished" }))
			end)
		end)

		describe("ChatName", function()
			it("AC-06-06 maps every channel to its lower-case chat name", function()
				assert.are.equal("guild", View.ChatName("GUILD"))
				assert.are.equal("party", View.ChatName("PARTY"))
				assert.are.equal("raid", View.ChatName("RAID"))
			end)
		end)

		describe("Subtitle", function()
			it("AC-14-01 capitalises the chat and formats a round wager and the roll max", function()
				assert.are.equal(
					"Raid chat, 100g per person, roll 1-100",
					View.Subtitle({ channel = "RAID", wager = 1000000, rollMax = 100 })
				)
			end)

			it("AC-14-02 shows every non-zero part of the wager and the roll max", function()
				assert.are.equal(
					"Guild chat, 1g 50s 45c per person, roll 1-500",
					View.Subtitle({ channel = "GUILD", wager = 15045, rollMax = 500 })
				)
			end)
		end)

		describe("TINT", function()
			it("AC-14-03 both factions have title, button, text and low as rgb triples in 0..1", function()
				for _, faction in ipairs({ "Alliance", "Horde" }) do
					local tint = View.TINT[faction]
					assert.is_table(tint, faction)
					for _, role in ipairs({ "title", "button", "text", "low" }) do
						local colour = tint[role]
						assert.is_table(colour, faction .. "." .. role)
						assert.are.equal(3, #colour, faction .. "." .. role)
						for i = 1, 3 do
							assert.is_number(colour[i], faction .. "." .. role .. "[" .. i .. "]")
							assert.is_true(colour[i] >= 0 and colour[i] <= 1, faction .. "." .. role .. "[" .. i .. "]")
						end
					end
				end
			end)
		end)

		describe("Help", function()
			it("AC-14-04 gives the six lines of the hover box in order", function()
				assert.are.same({
					"Type 1 in chat to join.",
					"When called, everyone types /roll 100 once.",
					"Highest roll wins, lowest roll pays.",
					"Owed: (highest - lowest) x wager / 100.",
					"A tie for highest or lowest re-rolls.",
					"No roll in time: you sit out.",
				}, View.Help("1", 100))
			end)

			it("AC-14-05 fills in another join word and roll max", function()
				local lines = View.Help("roll", 1000)
				assert.are.equal(6, #lines)
				assert.are.equal("Type roll in chat to join.", lines[1])
				assert.are.equal("When called, everyone types /roll 1000 once.", lines[2])
				assert.are.equal("Owed: (highest - lowest) x wager / 1000.", lines[4])
			end)
		end)
	end)

	-- 02-form (package 14): StartOpts.
	describe("form (02-form)", function()
		describe("StartOpts", function()
			it("AC-07-01 guild, 1g and 100 give the full opts", function()
				assert.are.same(
					{ channel = "GUILD", wager = 10000, rollMax = 100 },
					View.StartOpts("GUILD", "1g", "100")
				)
			end)

			it("AC-07-02 an empty roll max leaves rollMax nil", function()
				local opts, err = View.StartOpts("PARTY", "50s", "")
				assert.is_nil(err)
				assert.are.same({ channel = "PARTY", wager = 5000 }, opts)
				assert.is_nil(opts.rollMax)
			end)

			it("AC-07-03 the wager is passed whole and the roll max is trimmed", function()
				assert.are.same(
					{ channel = "RAID", wager = 15000, rollMax = 500 },
					View.StartOpts("RAID", "1g 50s", "  500 ")
				)
			end)

			it("AC-07-04 a bad wager gives Money.ERROR", function()
				local opts, err = View.StartOpts("GUILD", "abc", "100")
				assert.is_nil(opts)
				assert.are.equal(Money.ERROR, err)
			end)

			it("AC-07-05 a roll max of 1 gives Parse.ROLL_MAX_ERROR", function()
				local opts, err = View.StartOpts("GUILD", "1g", "1")
				assert.is_nil(opts)
				assert.are.equal(Parse.ROLL_MAX_ERROR, err)
			end)

			it("AC-07-06 an empty wager gives Money.ERROR", function()
				local opts, err = View.StartOpts("GUILD", "", "")
				assert.is_nil(opts)
				assert.are.equal(Money.ERROR, err)
			end)

			it("AC-07-07 an unknown channel raises", function()
				assert.has_error(function()
					View.StartOpts("WHISPER", "1g", "")
				end)
			end)
		end)
	end)

	-- 03-in-progress (package 08): Lobby, Game.
	describe("in progress (03-in-progress)", function()
		local lobby, rolling

		-- The lobby fixture comes from Rules: host Eve, raid, 1g, first roll
		-- 1000, created at 1000, with Alice, Bob and Eve joined in that order.
		local function newLobby()
			local game = Rules.New({
				host = "Eve",
				channel = "RAID",
				wager = 10000,
				startRoll = 1000,
				joinWord = "1",
				joinTime = 60,
				turnTimer = 45,
			}, 1000)
			Rules.Join(game, "Alice", 1001)
			Rules.Join(game, "Bob", 1002)
			Rules.Join(game, "Eve", 1003)
			return game
		end

		-- The rolling fixture is built by hand as the document lists it.
		local function newRolling()
			return {
				host = "Eve",
				channel = "RAID",
				wager = 10000,
				startRoll = 1000,
				joinWord = "1",
				joinTime = 60,
				turnTimer = 45,
				phase = "rolling",
				joined = { "Alice", "Bob", "Carl", "Dan", "Eve" },
				order = { "Alice", "Bob", "Carl", "Dan", "Eve" },
				status = { Alice = "in", Bob = "in", Carl = "out", Dan = "in", Eve = "in" },
				eliminated = { "Carl" },
				turn = 2,
				range = 734,
				turnDeadline = 1045,
				remindersSent = {},
				rolls = { { name = "Alice", roll = 734, max = 1000 } },
			}
		end

		before_each(function()
			lobby = newLobby()
			rolling = newRolling()
		end)

		describe("Lobby", function()
			it("AC-08-01 counts the seconds left, the fraction and the joined", function()
				local model = View.Lobby(lobby, "Eve", 1018)
				assert.are.equal(42, model.secondsLeft)
				assert.is_near(0.7, model.fraction, 0.001)
				assert.are.equal(3, model.count)
			end)

			it("AC-08-02 one row per joined player in join order, (you) on the host", function()
				assert.are.same({
					{ n = 1, name = "Alice", you = false },
					{ n = 2, name = "Bob", you = false },
					{ n = 3, name = "Eve", you = true },
				}, View.Lobby(lobby, "Eve", 1018).rows)
			end)

			it("AC-08-03 the status line names the join word and the chat", function()
				assert.are.equal("Type 1 in raid chat to join", View.Lobby(lobby, "Eve", 1018).status)
			end)

			it("AC-08-04 the seconds left round up", function()
				assert.are.equal(60, View.Lobby(lobby, "Eve", 1000.2).secondsLeft)
			end)

			it("AC-08-05 past the deadline the seconds left and the fraction are 0", function()
				local model = View.Lobby(lobby, "Eve", 1070)
				assert.are.equal(0, model.secondsLeft)
				assert.are.equal(0, model.fraction)
			end)

			it("AC-08-06 the subtitle is View.Subtitle", function()
				assert.are.equal(
					"Raid chat, 1g per person, first roll 1-1000",
					View.Lobby(lobby, "Eve", 1018).subtitle
				)
			end)
		end)

		describe("Game", function()
			it("AC-08-07 a player who rolled shows their last roll", function()
				assert.are.same(
					{ n = 1, name = "Alice", you = false, current = false, out = false, value = "734" },
					View.Game(rolling, "Eve", 1014).rows[1]
				)
			end)

			it("AC-08-08 the current player shows the range to roll", function()
				assert.are.same(
					{ n = 2, name = "Bob", you = false, current = true, out = false, value = "1-734" },
					View.Game(rolling, "Eve", 1014).rows[2]
				)
			end)

			it("AC-08-09 a player who rolled 1 is out", function()
				assert.are.same(
					{ n = 3, name = "Carl", you = false, current = false, out = true, value = "out" },
					View.Game(rolling, "Eve", 1014).rows[3]
				)
			end)

			it("AC-08-10 the host who has not rolled shows an empty value and (you)", function()
				assert.are.same(
					{ n = 5, name = "Eve", you = true, current = false, out = false, value = "" },
					View.Game(rolling, "Eve", 1014).rows[5]
				)
			end)

			it("AC-08-11 the status line names the current player and the range", function()
				assert.are.equal("Bob is up: /roll 734", View.Game(rolling, "Eve", 1014).status)
			end)

			it("AC-08-12 counts the seconds left in the turn and the fraction", function()
				local model = View.Game(rolling, "Eve", 1014)
				assert.are.equal(31, model.secondsLeft)
				assert.is_near(31 / 45, model.fraction, 0.001)
			end)

			it("AC-08-13 the button reads the range and is disabled on another player's turn", function()
				assert.are.same({ label = "Roll 1-734", enabled = false, range = 734 }, View.Game(rolling, "Eve", 1014).button)
			end)

			it("AC-08-14 on the host's turn the status says You, the button is enabled and the row is current", function()
				rolling.turn = 5
				local model = View.Game(rolling, "Eve", 1014)
				assert.are.equal("You are up: /roll 734", model.status)
				assert.is_true(model.button.enabled)
				assert.is_true(model.rows[5].current)
				assert.are.equal("1-734", model.rows[5].value)
			end)

			it("AC-08-15 a player with two rolls shows the later one", function()
				table.insert(rolling.rolls, { name = "Bob", roll = 500, max = 734 })
				table.insert(rolling.rolls, { name = "Alice", roll = 120, max = 500 })
				rolling.range = 120
				rolling.turn = 4
				assert.are.equal("120", View.Game(rolling, "Eve", 1014).rows[1].value)
			end)

			it("AC-08-16 a forfeited player is out", function()
				rolling.status.Dan = "forfeit"
				local row = View.Game(rolling, "Eve", 1014).rows[4]
				assert.is_true(row.out)
				assert.are.equal("out", row.value)
			end)

			it("AC-08-17 past the turn deadline the seconds left and the fraction are 0", function()
				local model = View.Game(rolling, "Eve", 1100)
				assert.are.equal(0, model.secondsLeft)
				assert.are.equal(0, model.fraction)
			end)
		end)

		it("AC-08-18 Lobby on a rolling game and Game on a lobby game raise", function()
			assert.has_error(function()
				View.Lobby(rolling, "Eve", 1014)
			end)
			assert.has_error(function()
				View.Game(lobby, "Eve", 1018)
			end)
		end)
	end)

	-- 04-winner (package 09): Result.
	describe("winner (04-winner)", function()
		local finished

		-- The finished fixture is built by hand as the document lists it:
		-- raid, 1g, first roll 1000, five players, Alice won, host Eve.
		before_each(function()
			finished = {
				host = "Eve",
				channel = "RAID",
				wager = 10000,
				startRoll = 1000,
				phase = "finished",
				order = { "Alice", "Bob", "Carl", "Dan", "Eve" },
				winner = "Alice",
			}
		end)

		describe("Result", function()
			it("AC-09-01 names the winner", function()
				assert.are.equal("Alice", View.Result(finished, "Eve").winner)
			end)

			it("AC-09-02 one row per loser in order, (you) on the host, the wager as the amount", function()
				assert.are.same({
					{ text = "Bob owes Alice", you = false, amount = "1g" },
					{ text = "Carl owes Alice", you = false, amount = "1g" },
					{ text = "Dan owes Alice", you = false, amount = "1g" },
					{ text = "Eve owes Alice", you = true, amount = "1g" },
				}, View.Result(finished, "Eve").rows)
			end)

			it("AC-09-03 the total is the wager times the number of losers", function()
				assert.are.equal("4g", View.Result(finished, "Eve").total)
			end)

			it("AC-09-04 two players show one row and a total with every part of the wager", function()
				finished.order = { "Alice", "Bob" }
				finished.winner = "Bob"
				finished.wager = 15045
				local model = View.Result(finished, "Eve")
				assert.are.same({ { text = "Alice owes Bob", you = false, amount = "1g 50s 45c" } }, model.rows)
				assert.are.equal("1g 50s 45c", model.total)
			end)

			it("AC-09-05 no row is (you) when the host won", function()
				for _, row in ipairs(View.Result(finished, "Alice").rows) do
					assert.is_false(row.you, row.text)
				end
			end)

			it("AC-09-06 Result on a rolling game raises", function()
				assert.has_error(function()
					View.Result({ phase = "rolling" }, "Eve")
				end)
			end)

			it("AC-09-07 the subtitle is View.Subtitle", function()
				assert.are.equal("Raid chat, 1g per person, first roll 1-1000", View.Result(finished, "Eve").subtitle)
			end)
		end)
	end)
end)
