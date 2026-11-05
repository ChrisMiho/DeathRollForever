describe("View", function()
	local View

	before_each(function()
		local ns = LoadAddonFile("src/Money.lua")
		LoadAddonFile("src/View.lua", ns)
		View = ns.View
	end)

	-- 01-window (package 06): TINT, State, ChatName, Subtitle.
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
			it("AC-06-07 capitalises the chat and formats a round wager", function()
				assert.are.equal(
					"Raid chat, 1g per person, first roll 1-1000",
					View.Subtitle({ channel = "RAID", wager = 10000, startRoll = 1000 })
				)
			end)

			it("AC-06-08 shows every non-zero part of the wager and the start roll", function()
				assert.are.equal(
					"Guild chat, 1g 50s 45c per person, first roll 1-500",
					View.Subtitle({ channel = "GUILD", wager = 15045, startRoll = 500 })
				)
			end)
		end)

		describe("TINT", function()
			it("AC-06-09 both factions have title, button and text as rgb triples in 0..1", function()
				for _, faction in ipairs({ "Alliance", "Horde" }) do
					local tint = View.TINT[faction]
					assert.is_table(tint, faction)
					for _, role in ipairs({ "title", "button", "text" }) do
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
	end)
end)
