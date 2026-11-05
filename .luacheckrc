std = "lua51"
max_line_length = 120
codes = true

exclude_files = {
	"Libs/",
	".release/",
	".lua/",      -- Lua installed by CI (leafo/gh-actions-lua)
	".luarocks/", -- LuaRocks installed by CI (leafo/gh-actions-luarocks)
	".luacheckrc",
}

-- Globals this addon creates
globals = {
	"SlashCmdList",
	"SLASH_DEATHROLLFOREVER1",
	"SLASH_DEATHROLLFOREVER2",
}

-- WoW API this addon reads. Add each new API here as it is used,
-- so a typo in an API name fails lint instead of failing in game.
read_globals = {
	"Ambiguate",
	"C_AddOns",
	"C_Timer",
	"CreateFrame",
	"GameFontDisable",
	"GameFontHighlight",
	"GameFontNormalHuge",
	"GameFontNormalLarge",
	"GetTime",
	"IsInGroup",
	"IsInGuild",
	"IsInRaid",
	"LibStub",
	"NumberFontNormalHuge",
	"RandomRoll",
	"SendChatMessage",
	"UIParent",
	"UnitFactionGroup",
	"UnitName",
}

files["spec/"] = {
	std = "+busted",
	read_globals = { "LoadAddonFile" },
}

files["spec/helper.lua"] = {
	globals = { "LoadAddonFile" },
}
