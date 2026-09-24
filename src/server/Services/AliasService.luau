-- Custom public aliases (Custom Alias pass). Players set one in the lobby; it is checked
-- against AliasRules and the text filter, then saved. At the start of each match every
-- saved alias is checked again (rules, filter, and the usernames and display names of the
-- players in that match) and handed out first come, first served. Anyone whose alias
-- cannot be used gets a normal one from the pool. Real names are never affected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AliasRules = require(Shared:WaitForChild("AliasRules"))

local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)
local ProfileService = require(script.Parent.ProfileService)
local TextFilter = require(script.Parent.TextFilter)

local AliasService = {}

local function setAlias(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.alias) ~= "string" then
		return
	end
	if not PassService.owns(player, "alias") then
		Match.notify(player, "A custom alias needs the Custom Alias pass.", "bad")
		return
	end
	if Match.get(player) then
		Match.notify(player, "Change your alias in the lobby.", "bad")
		return
	end
	local text = string.gsub(payload.alias, "%s", "")
	if text == "" then
		data.alias = ""
		Match.notify(player, "Custom alias cleared.", "info")
		DataService.push(player)
		DataService.saveSoon(player)
		return
	end
	local ok, reason = AliasRules.check(text)
	if not ok then
		Match.notify(player, reason, "bad")
		return
	end
	local alias = AliasRules.normalize(text)
	if not AliasRules.clearOf(alias, { player.Name, player.DisplayName }) then
		Match.notify(player, "Your alias cannot contain your username or display name.", "bad")
		return
	end
	local filtered = TextFilter.broadcast(alias, player.UserId)
	if filtered ~= alias then
		Match.notify(player, "That alias did not pass the text filter.", "bad")
		return
	end
	data.alias = alias
	Match.notify(player, "Your alias is now " .. alias .. ".", "good")
	DataService.push(player)
	DataService.saveSoon(player)
end

-- [playerState] = alias for everyone whose custom alias can be used in this match.
function AliasService.resolve(list): { [any]: string }
	local names = {}
	for _, ps in ipairs(list) do
		table.insert(names, ps.player.Name)
		table.insert(names, ps.player.DisplayName)
	end
	local candidates = {}
	for index, ps in ipairs(list) do
		local data = DataService.get(ps.player)
		local alias = if data and type(data.alias) == "string" then data.alias else ""
		if alias ~= "" and PassService.owns(ps.player, "alias") and AliasRules.check(alias) then
			-- Nobody's alias may point at a player in this match (their own names included).
			if AliasRules.clearOf(alias, names) then
				candidates[index] = alias
			end
		end
	end
	-- Filter again (the filter can change over time), all at once.
	local pending = 0
	local filtered: { [number]: boolean } = {}
	for index, alias in pairs(candidates) do
		pending += 1
		task.spawn(function()
			filtered[index] = TextFilter.broadcast(alias, list[index].userId) == alias
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 5 do
		task.wait(0.05)
	end
	local result = {}
	local taken = {}
	for index, ps in ipairs(list) do
		local alias = candidates[index]
		if alias and filtered[index] and not taken[string.lower(alias)] then
			taken[string.lower(alias)] = true
			result[ps] = alias
		end
	end
	return result
end

function AliasService.init()
	ProfileService.register("alias", 2, setAlias)
end

return AliasService
