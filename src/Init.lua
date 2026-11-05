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

SLASH_DEATHROLLFOREVER1 = "/dr"
SLASH_DEATHROLLFOREVER2 = "/deathroll"
SlashCmdList.DEATHROLLFOREVER = function()
	Print(ns.version .. ". Nothing to do yet: this is the hello build.")
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
