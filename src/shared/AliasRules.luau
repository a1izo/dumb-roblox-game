--!strict
-- Rules for a custom public alias (Custom Alias pass). The alias is only the public name in
-- matches; the secret real name is still drawn from the pools. An alias may not:
--   * be shorter than 3 or longer than 12 letters, or contain anything but letters
--   * be a first or last name from the real-name pools, or any pair of them run together
--     (the meeting chat blocks full real names, so such an alias would break chat)
--   * be a reserved word (game names, staff words)
--   * equal or contain a player's username or display name (checked at match start)
-- The text filter runs separately on the server.

local NamePools = require(script.Parent.NamePools)
local Terms = require(script.Parent.Terms)

local AliasRules = {}

AliasRules.MIN = 3
AliasRules.MAX = 12

local RESERVED = {
	"deathsgambit",
	"gambit",
	"inkbound", -- terms:ok (the retired name stays reserved)
	"admin",
	"administrator",
	"moderator",
	"mod",
	"roblox",
	"staff",
	"developer",
	"owner",
	"system",
}

local lowerFirst: { [string]: boolean } = {}
local lowerLast: { [string]: boolean } = {}
for _, name in ipairs(NamePools.FIRST_NAMES) do
	lowerFirst[string.lower(name)] = true
end
for _, name in ipairs(NamePools.LAST_NAMES) do
	lowerLast[string.lower(name)] = true
end

local reservedSet: { [string]: boolean } = {}
for _, word in ipairs(RESERVED) do
	reservedSet[word] = true
end
-- Every game term, both spaced and run together ("thehand", "zero", "specter"...).
for _, value in pairs(Terms.NAMES) do
	local lower = string.lower(value)
	reservedSet[lower] = true
	reservedSet[(string.gsub(lower, "[^a-z]", ""))] = true
end

local function isPoolPair(lower: string): boolean
	for first in pairs(lowerFirst) do
		if string.sub(lower, 1, #first) == first and lowerLast[string.sub(lower, #first + 1)] then
			return true
		end
	end
	for last in pairs(lowerLast) do
		if string.sub(lower, 1, #last) == last and lowerFirst[string.sub(lower, #last + 1)] then
			return true
		end
	end
	return false
end

-- Returns (ok, reason). Capitalises the alias ("raven" -> "Raven") when it is valid.
function AliasRules.check(alias: string): (boolean, string)
	if type(alias) ~= "string" then
		return false, "Type an alias."
	end
	if not string.match(alias, "^%a+$") then
		return false, "Use letters only, with no spaces."
	end
	if #alias < AliasRules.MIN or #alias > AliasRules.MAX then
		return false, string.format("Use %d to %d letters.", AliasRules.MIN, AliasRules.MAX)
	end
	local lower = string.lower(alias)
	if reservedSet[lower] then
		return false, "That word is reserved."
	end
	for word in pairs(reservedSet) do
		if #word >= 4 and string.find(lower, word, 1, true) then
			return false, "That word is reserved."
		end
	end
	if lowerFirst[lower] or lowerLast[lower] then
		return false, "That is one of the secret real names."
	end
	if isPoolPair(lower) then
		return false, "That reads as a full real name."
	end
	return true, ""
end

function AliasRules.normalize(alias: string): string
	return string.upper(string.sub(alias, 1, 1)) .. string.lower(string.sub(alias, 2))
end

-- False when the alias would point at a player (their username or display name).
function AliasRules.clearOf(alias: string, names: { string }): boolean
	local lower = string.lower(alias)
	for _, name in ipairs(names) do
		local other = string.lower((string.gsub(name, "[^%a]", "")))
		if
			#other >= 3 and (lower == other or string.find(lower, other, 1, true) or string.find(other, lower, 1, true))
		then
			return false
		end
	end
	return true
end

return AliasRules
