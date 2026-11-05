local _, ns = ...

-- Money: turn what the host types as a wager into an integer number of
-- copper, and turn copper back into the text chat lines show.
-- Pure Lua, no WoW API. Spec: docs/prd/functional/01-money.md.

local Money = {}
ns.Money = Money

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 100 * COPPER_PER_SILVER

Money.MIN = 1
Money.MAX = 9999999999 -- 999,999g 99s 99c
Money.ERROR = "Enter an amount like 5, 1g 50s or 1.5g"

local SUFFIX_VALUE = {
	g = COPPER_PER_GOLD,
	s = COPPER_PER_SILVER,
	c = 1,
}

-- Gold with up to two decimals meaning silver: "1.5" = 1g 50s, "1.05" = 1g 5s.
local function decimalGold(whole, fraction)
	if #fraction == 1 then
		fraction = fraction .. "0"
	end
	return tonumber(whole) * COPPER_PER_GOLD + tonumber(fraction) * COPPER_PER_SILVER
end

-- One or more of <digits>g, <digits>s, <digits>c in any order, separated by
-- zero or more spaces, nothing else. Each suffix at most once.
local function suffixedParts(text)
	local total = 0
	local seen = {}
	local position = 1
	while position <= #text do
		local digits, suffix, nextPosition = text:match("^(%d+)([gsc]) *()", position)
		if not digits or seen[suffix] then
			return nil
		end
		seen[suffix] = true
		total = total + tonumber(digits) * SUFFIX_VALUE[suffix]
		position = nextPosition
	end
	if position == 1 then
		return nil
	end
	return total
end

local function parseCopper(text)
	local whole = text:match("^(%d+)$")
	if whole then
		return tonumber(whole) * COPPER_PER_GOLD
	end
	local gold, fraction = text:match("^(%d+)%.(%d%d?)$")
	if gold then
		return decimalGold(gold, fraction)
	end
	gold, fraction = text:match("^(%d+)%.(%d%d?)g$")
	if gold then
		return decimalGold(gold, fraction)
	end
	return suffixedParts(text)
end

function Money.Parse(text)
	if type(text) ~= "string" then
		text = ""
	end
	text = text:match("^%s*(.-)%s*$"):lower()
	local copper = parseCopper(text)
	if not copper or copper < Money.MIN or copper > Money.MAX then
		return nil, Money.ERROR
	end
	return copper
end

local function checkCopper(copper)
	if type(copper) ~= "number" or copper < 0 or copper ~= math.floor(copper) then
		error("Money: expected a non-negative integer number of copper, got " .. tostring(copper), 3)
	end
end

function Money.Split(copper)
	checkCopper(copper)
	local gold = math.floor(copper / COPPER_PER_GOLD)
	local remainder = copper - gold * COPPER_PER_GOLD
	local silver = math.floor(remainder / COPPER_PER_SILVER)
	return gold, silver, remainder - silver * COPPER_PER_SILVER
end

function Money.Format(copper)
	checkCopper(copper)
	if copper == 0 then
		return "0c"
	end
	local gold, silver, rest = Money.Split(copper)
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = gold .. "g"
	end
	if silver > 0 then
		parts[#parts + 1] = silver .. "s"
	end
	if rest > 0 then
		parts[#parts + 1] = rest .. "c"
	end
	return table.concat(parts, " ")
end
