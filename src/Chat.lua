-- Chat text helpers. Pure Lua: no WoW API calls, so it runs under busted.
local _, ns = ...

local Chat = {}
ns.Chat = Chat

Chat.PREFIX = "[DeathRoll]"

--- Prefix a line for posting to party, raid or guild chat.
-- @param text string The message body.
-- @return string The message with the addon prefix.
function Chat.Prefix(text)
	if type(text) ~= "string" or text == "" then
		error("Chat.Prefix: text must be a non-empty string", 2)
	end
	return Chat.PREFIX .. " " .. text
end
