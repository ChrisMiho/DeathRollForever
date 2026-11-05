-- Addon entry point: wires the addon into the game (events, slash commands).
local addonName, ns = ...

local UNPACKAGED_VERSION = "@project-version@"

local function GetVersion()
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	if not version or version == UNPACKAGED_VERSION then
		return "dev"
	end
	return version
end

local function Print(text)
	print("|cffffd100" .. addonName .. "|r " .. text)
end

ns.version = GetVersion()
ns.Print = Print

local HELP = {
	"/dr g <wager> [first roll]   start in guild chat (1g, 50s, 1g50s, 1.5g)",
	"/dr p <wager> [first roll]   start in party chat",
	"/dr r <wager> [first roll]   start in raid chat",
	"/dr cancel                   cancel the running game",
	"/dr help                     this list",
}

local function PrintHelp()
	for _, line in ipairs(HELP) do
		Print(line)
	end
end

local function Start(name, args)
	local opts, parseError = ns.Parse.StartArgs(name, args)
	if not opts then
		Print(parseError)
		return
	end
	local ok, startError = ns.Host.Start(opts)
	if not ok then
		Print(startError)
	end
end

local function Cancel()
	local ok, cancelError = ns.Host.Cancel()
	if not ok then
		Print(cancelError)
	end
end

SLASH_DEATHROLLFOREVER1 = "/dr"
SLASH_DEATHROLLFOREVER2 = "/deathroll"
SlashCmdList.DEATHROLLFOREVER = function(text)
	local command = ns.Parse.Command(text)
	local name = command.name
	if ns.Parse.CHANNELS[name] then
		Start(name, command.args)
	elseif name == "cancel" then
		Cancel()
	elseif name == "help" or name == "" then
		PrintHelp()
	else
		Print("Unknown command.")
		PrintHelp()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	if not LibStub or not LibStub("AceComm-3.0", true) then
		Print("|cffff4040AceComm-3.0 is missing. Install a build from scripts/build.sh.|r")
		return
	end
	Print(ns.version .. " loaded. Type /dr.")
end)
