-- Aliases and secret real names. Pools are fixed; no two players in a match share a
-- first name or a last name, so a correct name always points to one player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NamePools = require(Shared:WaitForChild("NamePools"))
local Util = require(Shared:WaitForChild("Util"))

local AliasService = require(script.Parent.AliasService)
local CharacterService = require(script.Parent.CharacterService)
local Match = require(script.Parent.Match)

local NameService = {}

function NameService.assign()
	local firsts = Util.shuffle(table.clone(NamePools.FIRST_NAMES), Match.rng)
	local lasts = Util.shuffle(table.clone(NamePools.LAST_NAMES), Match.rng)
	local custom = AliasService.resolve(Match.list)
	local taken = {}
	for _, alias in pairs(custom) do
		taken[string.lower(alias)] = true
	end
	-- Pool aliases that match a custom one are left out.
	local aliases = {}
	for _, alias in ipairs(Util.shuffle(table.clone(NamePools.ALIASES), Match.rng)) do
		if not taken[string.lower(alias)] then
			table.insert(aliases, alias)
		end
	end
	local nextPool = 0
	for i, ps in ipairs(Match.list) do
		ps.first = firsts[i]
		ps.last = lasts[i]
		ps.realName = ps.first .. " " .. ps.last
		if custom[ps] then
			ps.alias = custom[ps]
		else
			nextPool += 1
			ps.alias = aliases[nextPool]
		end
		ps.player:SetAttribute("Alias", ps.alias)
		CharacterService.setDisplayName(ps.player, ps.alias)
	end
end

return NameService
