local _, ns = ...

-- Solo games: the host against bots, in the window only
-- (docs/prd/functional/06-solo.md). The pure part: the bot names, picking
-- the players and planning the bots' rolls. The only module that uses
-- randomness, and only through the rng(lo, hi) it is given.

local Solo = {}
ns.Solo = Solo

Solo.BOTS = 10
Solo.MAX_BOTS = 40
Solo.ROLL_TIME = 15
Solo.BOTS_ERROR = "Bots must be a whole number from 1 to 40"

Solo.NAMES = {
	Horde = {
		"Gruntsalot", "Axetastic", "Zugzugson", "Lokmotive", "Moocifer",
		"Hoofhearted", "Steakholder", "Udderchaos", "Boneappetit", "Ghoulfriend",
		"Rotisserie", "Deadpanned", "Skelebrate", "Mojoko", "Voodoodle",
		"Tuskany", "Jinxalot", "Trollercoast", "Hexpert", "Gorechestra",
		"Smashley", "Grumpstump", "Snortimer", "Ridewolfie", "Spikeasy",
		"Orcward", "Orcestra", "Grubnub", "Coinflipz", "Profitbolt",
		"Kaboomer", "Fizzlefuse", "Bloodelfie", "Manaddict", "Sunbeamz",
		"Glitterbolt", "Plaguey", "Rotmuch", "Grimgrin", "Bonejangles",
		"Totemtom", "Earthquaker", "Windfurry", "Shamrockin", "Drumthunder",
		"Bigtusk", "Tuskaloosa", "Moosebumps", "Hornswoggle", "Lootandscoot",
	},
	Alliance = {
		"Shieldwally", "Holypoly", "Lightweight", "Bubblehearth", "Hammersmash",
		"Beardsley", "Gnomebody", "Gnomad", "Sprocketz", "Sparkplugg",
		"Alewright", "Stoutheart", "Mugsy", "Brewster", "Pintsize",
		"Moonfluff", "Treehugz", "Nightowlet", "Starmuffin", "Wispy",
		"Stormwindy", "Goldshirt", "Footlooser", "Knightlight", "Squirebert",
		"Lancelittle", "Smitey", "Holysmokes", "Priestly", "Frostbyte",
		"Sheepish", "Blinkster", "Arcanewbie", "Draeneigh", "Goatmeal",
		"Tentaclese", "Crystalyn", "Worgenstein", "Furrball", "Howlbert",
		"Barkley", "Muttonchops", "Dwarvelous", "Stoneface", "Pickaxel",
		"Rumbleton", "Critcrumb", "Bandaid", "Tankyou", "Healsalot",
	},
}

-- The names a faction's bots come from, without the host's own name.
-- Any faction but Horde or Alliance (Neutral, nil) gets both lists.
local function pool(faction, host)
	local lists = Solo.NAMES[faction] and { Solo.NAMES[faction] } or { Solo.NAMES.Horde, Solo.NAMES.Alliance }
	local out = {}
	for _, list in ipairs(lists) do
		for _, name in ipairs(list) do
			if name ~= host then
				out[#out + 1] = name
			end
		end
	end
	return out
end

-- { host, bot, ... }: count bots picked without repeats, host first.
function Solo.Players(host, faction, count, rng)
	if type(host) ~= "string" or host == "" then
		error("Solo.Players: host must be a non-empty string", 2)
	end
	if type(count) ~= "number" or count % 1 ~= 0 or count < 1 or count > Solo.MAX_BOTS then
		error(("Solo.Players: count must be a whole number from 1 to %d"):format(Solo.MAX_BOTS), 2)
	end
	local names = pool(faction, host)
	local players = { host }
	-- Partial Fisher-Yates: the first count slots end up a random pick.
	for i = 1, count do
		local j = rng(i, #names)
		names[i], names[j] = names[j], names[i]
		players[#players + 1] = names[i]
	end
	return players
end

-- The waiting bots' rolls for the round that has just started.
function Solo.Plan(game, host, rng)
	local plan = {}
	for _, name in ipairs(ns.Rules.Waiting(game)) do
		if name ~= host then
			local delay = rng(1, 50) / 10
			local roll = rng(1, game.rollMax)
			plan[#plan + 1] = { name = name, delay = delay, roll = roll }
		end
	end
	return plan
end
