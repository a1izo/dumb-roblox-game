-- Win conditions checked after every removal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WinConditions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WinConditions"))

local function entry(role: string, alive: boolean)
	return { role = role, alive = alive }
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("WinConditions.evaluate", function()
		it("lets the match go on while the team outnumbers Kira's side", function()
			local side = WinConditions.evaluate({
				entry("Kira", true),
				entry("Follower", true),
				entry("L", true),
				entry("Watari", true),
				entry("TaskForce", true),
				entry("TaskForce", false),
			})
			expect(side).to.equal(nil)
		end)
		it("gives the team the win when Kira is removed", function()
			local side, code = WinConditions.evaluate({
				entry("Kira", false),
				entry("Follower", true),
				entry("L", true),
				entry("TaskForce", true),
			})
			expect(side).to.equal("Team")
			expect(code).to.equal("KiraRemoved")
		end)
		it("keeps going when Ace dies (succession, not a Coven win)", function()
			local side = WinConditions.evaluate({
				entry("Kira", true),
				entry("L", false),
				entry("TaskForce", true),
				entry("TaskForce", true),
				entry("TaskForce", true),
			})
			expect(side).to.equal(nil)
		end)
		it("gives Kira the win at parity", function()
			local side, code = WinConditions.evaluate({
				entry("Kira", true),
				entry("Follower", true),
				entry("L", true),
				entry("TaskForce", true),
				entry("TaskForce", false),
			})
			expect(side).to.equal("Kira")
			expect(code).to.equal("Parity")
		end)
	end)

	describe("WinConditions.taskTotal", function()
		it("needs a few case files per Bureau player", function()
			expect(WinConditions.taskTotal(8, 4)).to.equal(32)
			expect(WinConditions.taskTotal(0, 4)).to.equal(1)
		end)
	end)
end
