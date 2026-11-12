describe("View", function()
	local View
	local Money, Parse, Rules

	before_each(function()
		local ns = LoadAddonFile("src/Money.lua")
		LoadAddonFile("src/Parse.lua", ns)
		LoadAddonFile("src/Rules.lua", ns)
		LoadAddonFile("src/Solo.lua", ns)
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

			it("AC-06-07 a solo game is solo", function()
				assert.are.equal("solo", View.ChatName("SOLO"))
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

			it("AC-14-06 a solo game has no chat", function()
				assert.are.equal(
					"Solo, 1g per person, roll 1-100",
					View.Subtitle({ channel = "SOLO", wager = 10000, rollMax = 100 })
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

			it("AC-07-08 solo with an empty or missing bot count gets 10 bots", function()
				local expected = { channel = "SOLO", wager = 10000, bots = 10 }
				assert.are.same(expected, View.StartOpts("SOLO", "1g", "", ""))
				assert.are.same(expected, View.StartOpts("SOLO", "1g", "", nil))
			end)

			it("AC-07-09 solo takes 1 to 40 bots, trimmed", function()
				assert.are.same(
					{ channel = "SOLO", wager = 10000, rollMax = 1000, bots = 40 },
					View.StartOpts("SOLO", "1g", "1000", " 40 ")
				)
				assert.are.equal(1, View.StartOpts("SOLO", "1g", "", "1").bots)
			end)

			it("AC-07-10 a bad bot count gives Solo.BOTS_ERROR", function()
				for _, text in ipairs({ "0", "41", "2.5", "abc" }) do
					local opts, err = View.StartOpts("SOLO", "1g", "", text)
					assert.is_nil(opts)
					assert.are.equal("Bots must be a whole number from 1 to 40", err)
				end
			end)

			it("AC-07-11 the wager is checked before the bot count", function()
				local opts, err = View.StartOpts("SOLO", "abc", "", "10")
				assert.is_nil(opts)
				assert.are.equal(Money.ERROR, err)
			end)

			it("AC-07-12 other chats ignore the bot count", function()
				assert.are.same({ channel = "GUILD", wager = 10000 }, View.StartOpts("GUILD", "1g", "", "99"))
			end)
		end)
	end)

	-- 03-in-progress (package 15): Lobby, Game.
	describe("in progress (03-in-progress)", function()
		local lobby, rolling, tie

		local OPTS = {
			host = "Eve",
			channel = "RAID",
			wager = 1000000,
			rollMax = 100,
			joinWord = "1",
			joinTime = 60,
			rollTime = 45,
		}

		-- A game from Rules with `names` joined in order: created at `now`,
		-- one join per second after it. The lobby closes at now + 60.
		local function newGame(names, now)
			local game = Rules.New(OPTS, now)
			for i, name in ipairs(names) do
				Rules.Join(game, name, now + i)
			end
			return game
		end

		-- Rolls `/roll 100` for every { name, roll } pair, in order, at `now`.
		local function rollAll(game, rolls, now)
			for _, pair in ipairs(rolls) do
				Rules.Roll(game, pair[1], pair[2], 1, 100, now)
			end
		end

		-- A game from Rules closed at t = 1000 (created at 940) with `rolls`
		-- made at 1001, as the document's fixture paragraph says.
		local function newRound(names, rolls)
			local game = newGame(names, 940)
			Rules.Tick(game, 1000)
			rollAll(game, rolls, 1001)
			return game
		end

		local SEVEN = { "Alice", "Bob", "Carl", "Dan", "Eve", "Frank", "Gina" }
		local SEVEN_ROLLS = {
			{ "Alice", 97 }, { "Bob", 61 }, { "Eve", 55 }, { "Frank", 40 }, { "Carl", 23 }, { "Dan", 8 },
		}

		-- The lobby fixture: created at 1000 with Alice, Bob and Eve joined.
		-- rolling: seven players, six rolled, Gina has not. tie: five players,
		-- Alice and Eve both rolled 97, so a high tie-break started at 1001.
		before_each(function()
			lobby = newGame({ "Alice", "Bob", "Eve" }, 1000)
			rolling = newRound(SEVEN, SEVEN_ROLLS)
			tie = newRound({ "Alice", "Bob", "Carl", "Dan", "Eve" }, {
				{ "Alice", 97 }, { "Bob", 61 }, { "Carl", 40 }, { "Dan", 8 }, { "Eve", 97 },
			})
		end)

		-- One field of every row, in order.
		local function field(rows, key)
			local out = {}
			for i, row in ipairs(rows) do
				out[i] = row[key]
			end
			return out
		end

		describe("Lobby", function()
			it("AC-15-01 counts the seconds left, the fraction and the joined", function()
				local model = View.Lobby(lobby, "Eve", 1018)
				assert.are.equal(42, model.secondsLeft)
				assert.is_near(0.7, model.fraction, 0.001)
				assert.are.equal(3, model.count)
			end)

			it("AC-15-02 one row per joined player in join order, (you) on the host", function()
				assert.are.same({
					{ n = 1, name = "Alice", you = false },
					{ n = 2, name = "Bob", you = false },
					{ n = 3, name = "Eve", you = true },
				}, View.Lobby(lobby, "Eve", 1018).rows)
			end)

			it("AC-15-03 the status line names the join word and the chat", function()
				assert.are.equal("Type 1 in raid chat to join", View.Lobby(lobby, "Eve", 1018).status)
			end)

			it("AC-15-04 past the deadline the seconds left and the fraction are 0", function()
				local model = View.Lobby(lobby, "Eve", 1070)
				assert.are.equal(0, model.secondsLeft)
				assert.are.equal(0, model.fraction)
			end)

			it("AC-15-05 the subtitle is View.Subtitle", function()
				assert.are.equal("Raid chat, 100g per person, roll 1-100", View.Lobby(lobby, "Eve", 1018).subtitle)
			end)
		end)

		describe("Game", function()
			it("AC-15-06 the header reads Rolled and how many of the rollers have", function()
				assert.are.same({ label = "Rolled", count = "6 of 7" }, View.Game(rolling, "Eve", 1014).header)
			end)

			it("AC-15-07 rows: waiting, highest, lowest, then the rest fanned from both ends", function()
				local rows = View.Game(rolling, "Eve", 1014).rows
				assert.are.same({ "Gina", "Alice", "Dan", "Bob", "Carl", "Eve", "Frank" }, field(rows, "name"))
				assert.are.same({ "waiting", "high", "low", "", "", "", "" }, field(rows, "mark"))
			end)

			it("AC-15-08 row values are waiting or the roll", function()
				local rows = View.Game(rolling, "Eve", 1014).rows
				assert.are.same({ "waiting", "97", "8", "61", "23", "55", "40" }, field(rows, "value"))
			end)

			it("AC-15-09 row tags are highest, lowest or empty, and (you) is on the host", function()
				local rows = View.Game(rolling, "Eve", 1014).rows
				assert.are.same({ "", "highest", "lowest", "", "", "", "" }, field(rows, "tag"))
				assert.are.same({ false, false, false, false, false, true, false }, field(rows, "you"))
			end)

			it("AC-15-10 the status line tells everyone what to roll", function()
				assert.are.equal("Everyone: /roll 100", View.Game(rolling, "Eve", 1014).status)
			end)

			it("AC-15-11 counts the seconds left in the round and the fraction", function()
				local model = View.Game(rolling, "Eve", 1014)
				assert.are.equal(31, model.secondsLeft)
				assert.is_near(31 / 45, model.fraction, 0.001)
			end)

			it("AC-15-12 the button reads the range and is disabled once the host rolled", function()
				assert.are.same({ label = "Roll 1-100", enabled = false, max = 100 }, View.Game(rolling, "Eve", 1014).button)
			end)

			it("AC-15-13 before the host rolled the button is enabled and the waiting rows are in rollers order", function()
				local game = newRound(SEVEN, {
					{ "Alice", 97 }, { "Bob", 61 }, { "Frank", 40 }, { "Carl", 23 }, { "Dan", 8 },
				})
				local model = View.Game(game, "Eve", 1014)
				assert.is_true(model.button.enabled)
				assert.are.same({ "Eve", "Gina" }, { model.rows[1].name, model.rows[2].name })
				assert.are.same({ "waiting", "waiting" }, { model.rows[1].mark, model.rows[2].mark })
				assert.are.equal("high", model.rows[3].mark)
			end)

			it("AC-15-14 a fresh round shows every row waiting in joined order", function()
				local game = newRound(SEVEN, {})
				local model = View.Game(game, "Eve", 1001)
				assert.are.same(SEVEN, field(model.rows, "name"))
				for _, row in ipairs(model.rows) do
					assert.are.equal("waiting", row.mark)
					assert.are.equal("waiting", row.value)
					assert.are.equal("", row.tag)
				end
				assert.are.equal("0 of 7", model.header.count)
			end)

			it("AC-15-15 one roll makes a highest row and no lowest row", function()
				local game = newRound(SEVEN, { { "Alice", 97 } })
				local rows = View.Game(game, "Eve", 1014).rows
				assert.are.same({ "Bob", "Carl", "Dan", "Eve", "Frank", "Gina", "Alice" }, field(rows, "name"))
				assert.are.same(
					{ "waiting", "waiting", "waiting", "waiting", "waiting", "waiting", "high" },
					field(rows, "mark")
				)
				assert.are.equal("highest", rows[7].tag)
			end)

			it("AC-15-16 two equal rolls are both highest and make no lowest row", function()
				local game = newRound(SEVEN, { { "Alice", 50 }, { "Bob", 50 } })
				local rows = View.Game(game, "Eve", 1014).rows
				assert.are.same({ "Carl", "Dan", "Eve", "Frank", "Gina", "Alice", "Bob" }, field(rows, "name"))
				assert.are.same(
					{ "waiting", "waiting", "waiting", "waiting", "waiting", "high", "high" },
					field(rows, "mark")
				)
				assert.are.same({ "highest", "highest" }, { rows[6].tag, rows[7].tag })
			end)

			it("AC-15-17 a high tie-break's header names the tie and counts the tied", function()
				assert.are.same({ label = "Tie for highest", count = "0 of 2" }, View.Game(tie, "Eve", 1002).header)
			end)

			it("AC-15-18 a tie-break keeps the tied on top with re-roll and no waiting group", function()
				local rows = View.Game(tie, "Eve", 1002).rows
				assert.are.same({ "Alice", "Eve", "Dan", "Bob", "Carl" }, field(rows, "name"))
				assert.are.same({ "high", "high", "low", "", "" }, field(rows, "mark"))
				assert.are.same({ "re-roll", "re-roll", "lowest", "", "" }, field(rows, "tag"))
			end)

			it("AC-15-19 a tie-break's status names the tied players", function()
				assert.are.equal("Alice, Eve: /roll 100 again", View.Game(tie, "Eve", 1002).status)
			end)

			it("AC-15-28 a tie-break shows full names in the rows and the status; the tags still follow the player", function()
				tie.fullNames.Alice = "Alice Vale"
				Rules.Roll(tie, "Alice", 40, 1, 100, 1003)
				local model = View.Game(tie, "Eve", 1004)
				assert.are.equal("Alice Vale, Eve: /roll 100 again", model.status)
				assert.are.equal("Alice Vale", model.rows[1].name)
				assert.are.equal("re-rolled 40", model.rows[1].tag)
				assert.is_nil(model.rows[1].key)
			end)

			it("AC-15-20 the button is enabled while the tied host has not re-rolled", function()
				assert.is_true(View.Game(tie, "Eve", 1002).button.enabled)
			end)

			it("AC-15-21 a tie-break roll shows as re-rolled next to the main-round roll", function()
				Rules.Roll(tie, "Alice", 40, 1, 100, 1003)
				local model = View.Game(tie, "Eve", 1004)
				assert.are.equal("Alice", model.rows[1].name)
				assert.are.equal("re-rolled 40", model.rows[1].tag)
				assert.are.equal("97", model.rows[1].value)
				assert.are.equal("1 of 2", model.header.count)
			end)

			it("AC-15-22 a tie-break at both ends names both and tags every tied row re-roll", function()
				local game = newRound({ "Alice", "Bob", "Carl", "Dan" }, {
					{ "Alice", 97 }, { "Bob", 97 }, { "Carl", 8 }, { "Dan", 8 },
				})
				local model = View.Game(game, "Eve", 1002)
				assert.are.equal("Tie for highest and lowest", model.header.label)
				assert.are.equal("Alice, Bob, Carl, Dan: /roll 100 again", model.status)
				assert.are.same({ "Alice", "Bob", "Carl", "Dan" }, field(model.rows, "name"))
				assert.are.same({ "high", "high", "low", "low" }, field(model.rows, "mark"))
				assert.are.same({ "re-roll", "re-roll", "re-roll", "re-roll" }, field(model.rows, "tag"))
			end)

			it("AC-15-23 a rerun main round reads Rolled again with every row waiting", function()
				local rolls = {}
				for i, name in ipairs(SEVEN) do
					rolls[i] = { name, 50 }
				end
				local game = newRound(SEVEN, rolls)
				assert.are.equal(2, game.round)
				local model = View.Game(game, "Eve", 1002)
				assert.are.equal("Rolled again", model.header.label)
				assert.are.equal("Everyone: /roll 100 again", model.status)
				assert.are.same(
					{ "waiting", "waiting", "waiting", "waiting", "waiting", "waiting", "waiting" },
					field(model.rows, "mark")
				)
			end)

			it("AC-15-24 past the roll deadline the seconds left and the fraction are 0", function()
				local model = View.Game(rolling, "Eve", 1100)
				assert.are.equal(0, model.secondsLeft)
				assert.are.equal(0, model.fraction)
			end)

			it("AC-15-25 Lobby on a rolling game and Game on a lobby game raise", function()
				assert.has_error(function()
					View.Lobby(rolling, "Eve", 1014)
				end)
				assert.has_error(function()
					View.Game(lobby, "Eve", 1018)
				end)
			end)

			it("AC-15-26 a player who missed the main round sits out, last, under a tie-break", function()
				local game = newRound({ "Alice", "Bob", "Carl", "Dan" }, {
					{ "Alice", 97 }, { "Bob", 97 }, { "Carl", 8 },
				})
				Rules.Tick(game, 1045)
				local model = View.Game(game, "Eve", 1046)
				assert.are.same({ "Alice", "Bob", "Carl", "Dan" }, field(model.rows, "name"))
				assert.are.same({ "high", "high", "low", "out" }, field(model.rows, "mark"))
				assert.are.same({ "re-roll", "re-roll", "lowest", "" }, field(model.rows, "tag"))
				assert.are.equal("sat out", model.rows[4].value)
				assert.are.equal("0 of 2", model.header.count)
			end)

			it("AC-15-27 a tied player who dropped out of a second tie-break is a plain row with their roll", function()
				local game = newRound({ "Alice", "Bob", "Carl", "Dan" }, {
					{ "Alice", 97 }, { "Bob", 97 }, { "Carl", 8 }, { "Dan", 97 },
				})
				rollAll(game, { { "Alice", 50 }, { "Dan", 50 } }, 1002)
				Rules.Tick(game, 1046)
				assert.are.equal(3, game.round)
				local model = View.Game(game, "Eve", 1047)
				assert.are.same({ "Alice", "Dan", "Carl", "Bob" }, field(model.rows, "name"))
				assert.are.same({ "high", "high", "low", "" }, field(model.rows, "mark"))
				assert.are.same({ "re-roll", "re-roll", "lowest", "" }, field(model.rows, "tag"))
				assert.are.equal("97", model.rows[4].value)
			end)

			it("AC-15-28 a low roll-off with the winner decided keeps the winner highest", function()
				local game = newRound({ "Alice", "Bob", "Carl", "Dan", "Eve" }, {
					{ "Alice", 97 }, { "Bob", 8 }, { "Carl", 8 }, { "Dan", 8 }, { "Eve", 50 },
				})
				rollAll(game, { { "Bob", 40 } }, 1002)
				Rules.Tick(game, 1046)
				local model = View.Game(game, "Eve", 1047)
				assert.are.same({ "Alice", "Carl", "Dan", "Eve", "Bob" }, field(model.rows, "name"))
				assert.are.same({ "high", "low", "low", "", "" }, field(model.rows, "mark"))
				assert.are.same({ "highest", "re-roll", "re-roll", "", "" }, field(model.rows, "tag"))
				assert.are.same({ "50", "8" }, { model.rows[4].value, model.rows[5].value })
			end)
		end)
	end)

	-- 04-winner (package 16): Result.
	describe("winner (04-winner)", function()
		local finished

		-- The fixture's game options (04-winner.md, Automated).
		local OPTS = {
			host = "Eve",
			channel = "RAID",
			wager = 1000000,
			rollMax = 100,
			joinWord = "1",
			joinTime = 60,
			rollTime = 45,
		}

		-- A game from Rules: created at 940 with `names` joined one per second
		-- after it, closed by Tick at 1000, `rolls` (pairs { name, roll }, the
		-- range 1 to rollMax) made at 1001.
		local function newRound(opts, names, rolls)
			local game = Rules.New(opts, 940)
			for i, name in ipairs(names) do
				Rules.Join(game, name, 940 + i)
			end
			Rules.Tick(game, 1000)
			for _, pair in ipairs(rolls) do
				Rules.Roll(game, pair[1], pair[2], 1, opts.rollMax, 1001)
			end
			return game
		end

		-- The finished fixture: seven players, six rolled, Gina did not, and
		-- the round settled on its deadline at 1045.
		before_each(function()
			finished = newRound(OPTS, { "Alice", "Bob", "Carl", "Dan", "Eve", "Frank", "Gina" }, {
				{ "Alice", 97 }, { "Bob", 61 }, { "Eve", 55 }, { "Frank", 40 }, { "Carl", 23 }, { "Dan", 8 },
			})
			Rules.Tick(finished, 1045)
			assert.are.equal("finished", finished.phase)
		end)

		-- One field of every row, in order.
		local function field(rows, key)
			local out = {}
			for i, row in ipairs(rows) do
				out[i] = row[key]
			end
			return out
		end

		describe("Result", function()
			it("AC-16-01 names the winner and their roll as text", function()
				local model = View.Result(finished, "Eve")
				assert.are.equal("Alice", model.winner)
				assert.are.equal("97", model.winningRoll)
			end)

			it("AC-16-02 rows: the winner, the loser, the rest fanned from both ends, the sat out", function()
				local rows = View.Result(finished, "Eve").rows
				assert.are.same({ "Alice", "Dan", "Bob", "Carl", "Eve", "Frank", "Gina" }, field(rows, "name"))
				assert.are.same({ "high", "low", "", "", "", "", "out" }, field(rows, "mark"))
			end)

			it("AC-16-03 row values are the roll or sat out, and (you) is on the host", function()
				local rows = View.Result(finished, "Eve").rows
				assert.are.same({ "97", "8", "61", "23", "55", "40", "sat out" }, field(rows, "value"))
				assert.are.same({ false, false, false, false, true, false, false }, field(rows, "you"))
			end)

			it("AC-16-04 the one debt names the loser and the winner with the amount owed", function()
				assert.are.same(
					{ { text = "Dan owes Alice", you = false, amount = "89g" } },
					View.Result(finished, "Eve").debts
				)
			end)

			it("AC-16-09 everyone tied for lowest skipped the tie-break: both are lowest and each owes", function()
				local game = newRound(OPTS, { "Alice", "Bob", "Carl", "Dan" }, {
					{ "Alice", 97 }, { "Bob", 61 }, { "Carl", 8 }, { "Dan", 8 },
				})
				Rules.Tick(game, 1100)
				local model = View.Result(game, "Dan")
				assert.are.same({ "Alice", "Carl", "Dan", "Bob" }, field(model.rows, "name"))
				assert.are.same({ "high", "low", "low", "" }, field(model.rows, "mark"))
				assert.are.same({
					{ text = "Carl owes Alice", you = false, amount = "89g" },
					{ text = "Dan owes Alice", you = true, amount = "89g" },
				}, model.debts)
			end)

			it("AC-16-05 two players: the winner, the loser and the host's own debt", function()
				local opts = {
					host = "Bob", channel = "RAID", wager = 10000, rollMax = 1000, joinWord = "1", joinTime = 60, rollTime = 45,
				}
				local game = newRound(opts, { "Alice", "Bob" }, { { "Alice", 5 }, { "Bob", 2 } })
				local model = View.Result(game, "Bob")
				assert.are.same({
					{ name = "Alice", you = false, value = "5", mark = "high" },
					{ name = "Bob", you = true, value = "2", mark = "low" },
				}, model.rows)
				assert.are.same({ { text = "Bob owes Alice", you = true, amount = "30c" } }, model.debts)
			end)

			it("AC-16-06 a game won through a high tie-break keeps the tied loser of it among the rest", function()
				local game = newRound(OPTS, { "Alice", "Bob", "Carl", "Dan", "Eve" }, {
					{ "Alice", 97 }, { "Bob", 61 }, { "Carl", 40 }, { "Dan", 8 }, { "Eve", 97 },
				})
				Rules.Roll(game, "Alice", 50, 1, 100, 1002)
				Rules.Roll(game, "Eve", 30, 1, 100, 1002)
				local rows = View.Result(game, "Eve").rows
				assert.are.same({ name = "Alice", you = false, value = "97", mark = "high" }, rows[1])
				assert.are.equal("low", rows[2].mark)
				assert.are.equal("Dan", rows[2].name)
				assert.are.same({ "Eve", "Carl", "Bob" }, { rows[3].name, rows[4].name, rows[5].name })
				assert.are.same({ name = "Eve", you = true, value = "97", mark = "" }, rows[3])
			end)

			it("AC-16-07 Result on a rolling game raises", function()
				assert.has_error(function()
					View.Result({ phase = "rolling" }, "Eve")
				end)
			end)

			it("AC-16-08 the subtitle is View.Subtitle", function()
				assert.are.equal("Raid chat, 100g per person, roll 1-100", View.Result(finished, "Eve").subtitle)
			end)

			it("AC-16-10 shows full names, surname included; (you) still matches the character name", function()
				finished.fullNames.Alice = "Alice Vale"
				finished.fullNames.Dan = "Dan Shards"
				finished.fullNames.Eve = "Eve Moon"
				local model = View.Result(finished, "Eve")
				assert.are.equal("Alice Vale", model.winner)
				assert.are.same({ name = "Alice Vale", you = false, value = "97", mark = "high" }, model.rows[1])
				assert.are.same({ name = "Eve Moon", you = true, value = "55", mark = "" }, model.rows[5])
				assert.are.same({ { text = "Dan Shards owes Alice Vale", you = false, amount = "89g" } }, model.debts)
			end)
		end)
	end)
end)
