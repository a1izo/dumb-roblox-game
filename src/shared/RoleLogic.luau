--!strict
-- Secret role assignment. Party members always end up on the same side: either all on
-- Kira's side or all on the investigation team.

local Util = require(script.Parent.Util)

local RoleLogic = {}

RoleLogic.KIRA = "Kira"
RoleLogic.FOLLOWER = "Follower"
RoleLogic.L = "L"
RoleLogic.WATARI = "Watari"
RoleLogic.TASK_FORCE = "TaskForce"

RoleLogic.ALL = { "Kira", "Follower", "L", "Watari", "TaskForce" }

-- One follower on 6-9 players, two on 10-12. Smaller counts only happen in Studio tests.
function RoleLogic.followerCount(playerCount: number): number
	if playerCount >= 10 then
		return 2
	elseif playerCount >= 4 then
		return 1
	end
	return 0
end

function RoleLogic.isKiraSide(role: string): boolean
	return role == RoleLogic.KIRA or role == RoleLogic.FOLLOWER
end

-- Picks exactly `need` ids for Kira's side, using whole groups when possible.
local function pickKiraSide(groups: { { number } }, need: number, rng: Random): { number }
	for _ = 1, 40 do
		local order = table.clone(groups)
		Util.shuffle(order, rng)
		local chosen: { number } = {}
		for _, group in ipairs(order) do
			if #chosen + #group <= need then
				for _, id in ipairs(group) do
					table.insert(chosen, id)
				end
			end
			if #chosen == need then
				return chosen
			end
		end
	end
	-- No combination of whole groups fits; split a party as a last resort.
	local flat: { number } = {}
	for _, group in ipairs(groups) do
		for _, id in ipairs(group) do
			table.insert(flat, id)
		end
	end
	Util.shuffle(flat, rng)
	local chosen: { number } = {}
	for i = 1, math.min(need, #flat) do
		table.insert(chosen, flat[i])
	end
	return chosen
end

-- groups: every player id exactly once; players in the same party share a group.
-- forced (Studio only): id -> role to force for testing.
function RoleLogic.assign(groups: { { number } }, rng: Random, forced: { [number]: string }?): { [number]: string }
	local all: { number } = {}
	for _, group in ipairs(groups) do
		for _, id in ipairs(group) do
			table.insert(all, id)
		end
	end
	local roles: { [number]: string } = {}
	local count = #all
	if count == 0 then
		return roles
	end

	local kiraSide = pickKiraSide(groups, 1 + RoleLogic.followerCount(count), rng)
	Util.shuffle(kiraSide, rng)
	local onKiraSide: { [number]: boolean } = {}
	for index, id in ipairs(kiraSide) do
		roles[id] = if index == 1 then RoleLogic.KIRA else RoleLogic.FOLLOWER
		onKiraSide[id] = true
	end

	local team: { number } = {}
	for _, id in ipairs(all) do
		if not onKiraSide[id] then
			table.insert(team, id)
		end
	end
	Util.shuffle(team, rng)
	for index, id in ipairs(team) do
		if index == 1 then
			roles[id] = RoleLogic.L
		elseif index == 2 then
			roles[id] = RoleLogic.WATARI
		else
			roles[id] = RoleLogic.TASK_FORCE
		end
	end

	if forced then
		for id, role in pairs(forced) do
			if roles[id] ~= nil and roles[id] ~= role then
				local holder: number? = nil
				for otherId, otherRole in pairs(roles) do
					if otherRole == role then
						holder = otherId
						break
					end
				end
				if holder ~= nil then
					roles[holder] = roles[id]
				end
				roles[id] = role
			end
		end
	end
	return roles
end

return RoleLogic
