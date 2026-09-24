-- Aliases and secret real names. Pools are fixed; no two players in a match share a
-- first name or a last name, so a correct name always points to one player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NamePools = require(Shared:WaitForChild("NamePools"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent.CharacterService)
local Match = require(script.Parent.Match)

local NameService = {}

function NameService.assign()
	local firsts = Util.shuffle(table.clone(NamePools.FIRST_NAMES), Match.rng)
	local lasts = Util.shuffle(table.clone(NamePools.LAST_NAMES), Match.rng)
	local aliases = Util.shuffle(table.clone(NamePools.ALIASES), Match.rng)
	for i, ps in ipairs(Match.list) do
		ps.first = firsts[i]
		ps.last = lasts[i]
		ps.realName = ps.first .. " " .. ps.last
		ps.alias = aliases[i]
		ps.revealed = {}
		ps.player:SetAttribute("Alias", ps.alias)
		CharacterService.setDisplayName(ps.player, ps.alias)
	end
end

-- The Butler's (Watari's) hint: one letter of the Hand's (Kira's) real name and its position.
function NameService.watariHint(): string?
	local kira = Match.findRole("Kira")
	if not kira then
		return nil
	end
	local useFirst = Match.rng:NextNumber() < 0.5
	local word = if useFirst then kira.first else kira.last
	local position = Match.rng:NextInteger(1, #word)
	local letter = string.upper(string.sub(word, position, position))
	return Terms.f('The {nth} letter of {hand}\'s {which} name is "{letter}".', {
		nth = Util.ordinal(position),
		which = if useFirst then "first" else "last",
		letter = letter,
	})
end

return NameService
