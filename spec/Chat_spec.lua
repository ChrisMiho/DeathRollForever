describe("Chat", function()
	local Chat

	before_each(function()
		Chat = LoadAddonFile("src/Chat.lua").Chat
	end)

	describe("Prefix", function()
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
end)
