-- Secret role assignment on the server. Only the owner of a role ever learns it
-- (plus the allies the rules allow: Kira <-> followers, L -> Watari).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoleLogic = require(Shared:WaitForChild("RoleLogic"))

local Match = require(script.Parent.Match)
local PartyService = require(script.Parent.PartyService)

local RoleService = {}

function RoleService.assign()
	local players = {}
	for _, ps in ipairs(Match.list) do
		table.insert(players, ps.player)
	end
	local groups = PartyService.groupsFor(players)

	local forced = nil
	local forcedRole = Config.STUDIO_FORCE_ROLE
	if RunService:IsStudio() and forcedRole ~= "" and #Match.list > 0 then
		if table.find(RoleLogic.ALL, forcedRole) then
			forced = { [Match.list[1].userId] = forcedRole }
		else
			warn("[L game] Config.STUDIO_FORCE_ROLE is not a role: " .. forcedRole)
		end
	end

	local roles = RoleLogic.assign(groups, Match.rng, forced)
	for _, ps in ipairs(Match.list) do
		ps.role = roles[ps.userId] or RoleLogic.TASK_FORCE
	end
end

function RoleService.count(role: string): number
	local n = 0
	for _, ps in ipairs(Match.list) do
		if ps.role == role then
			n += 1
		end
	end
	return n
end

return RoleService
