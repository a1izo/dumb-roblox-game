-- Role counts and party handling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoleLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoleLogic"))

local function singles(n: number): { { number } }
	local groups = {}
	for i = 1, n do
		table.insert(groups, { i })
	end
	return groups
end

local function count(roles: { [number]: string }, role: string): number
	local n = 0
	for _, r in pairs(roles) do
		if r == role then
			n += 1
		end
	end
	return n
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("RoleLogic.assign", function()
		it("gives 6 players one Kira, one follower, L and Watari", function()
			local roles = RoleLogic.assign(singles(6), Random.new(1), nil)
			expect(count(roles, "Kira")).to.equal(1)
			expect(count(roles, "Follower")).to.equal(1)
			expect(count(roles, "L")).to.equal(1)
			expect(count(roles, "Watari")).to.equal(1)
			expect(count(roles, "TaskForce")).to.equal(2)
		end)
		it("gives 10 and 12 players two followers", function()
			expect(count(RoleLogic.assign(singles(10), Random.new(2), nil), "Follower")).to.equal(2)
			expect(count(RoleLogic.assign(singles(12), Random.new(3), nil), "Follower")).to.equal(2)
		end)
		it("gives 9 players one follower", function()
			expect(count(RoleLogic.assign(singles(9), Random.new(4), nil), "Follower")).to.equal(1)
		end)
		it("keeps party members on the same side", function()
			for seed = 1, 60 do
				local groups = { { 1, 2 }, { 3 }, { 4 }, { 5 }, { 6 }, { 7 }, { 8 } }
				local roles = RoleLogic.assign(groups, Random.new(seed), nil)
				expect(RoleLogic.isKiraSide(roles[1])).to.equal(RoleLogic.isKiraSide(roles[2]))
			end
		end)
		it("puts a large party on the investigation team", function()
			local groups = { { 1, 2, 3, 4 }, { 5 }, { 6 }, { 7 } }
			local roles = RoleLogic.assign(groups, Random.new(9), nil)
			for id = 1, 4 do
				expect(RoleLogic.isKiraSide(roles[id])).to.equal(false)
			end
		end)
		it("honours a forced Studio role", function()
			local roles = RoleLogic.assign(singles(6), Random.new(5), { [1] = "L" })
			expect(roles[1]).to.equal("L")
			expect(count(roles, "L")).to.equal(1)
		end)
	end)
end
