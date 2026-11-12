std = "lua51"
max_line_length = 120
codes = true

exclude_files = {
	"Libs/",
	".release/",
	".lua/",      -- Lua installed by CI (leafo/gh-actions-lua)
	".luarocks/", -- LuaRocks installed by CI (leafo/gh-actions-luarocks)
	".luacheckrc",
	".worktrees/",   -- package worktrees made by the orchestrator
	".superpowers/", -- local tooling state
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
	"C_AddOns",
	"C_Timer",
	"CreateFrame",
	"GameFontDisable",
	"GameFontHighlight",
	"GameFontNormalHuge",
	"GameFontNormalLarge",
	"GameTooltip",
	"GetTime",
	"GetUnitName",
	"IsInGroup",
	"IsInGuild",
	"IsInRaid",
	"LibStub",
	"NumberFontNormalHuge",
	"RANDOM_ROLL_RESULT",
	"RandomRoll",
	"SendChatMessage",
	"UIParent",
	"UnitFactionGroup",
}

files["spec/"] = {
	std = "+busted",
	read_globals = { "LoadAddonFile" },
}

files["spec/helper.lua"] = {
	globals = { "LoadAddonFile" },
}
