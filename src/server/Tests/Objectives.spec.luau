-- Every role gets at least one objective line in every playable phase, and none of the
-- lines leaves a {placeholder} unfilled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hints = require(Shared:WaitForChild("Hints"))
local Objectives = require(Shared:WaitForChild("Objectives"))
local RoleLogic = require(Shared:WaitForChild("RoleLogic"))

local PHASES = { "Briefing", "Investigation", "DeathNote", "Meeting", "Vote" }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Objectives.lines", function()
		it("gives every living role a line in every phase", function()
			for _, role in ipairs(RoleLogic.ALL) do
				for _, phase in ipairs(PHASES) do
					local private = { role = role, canWrite = true, tasksThisRound = 0 }
					local lines = Objectives.lines(role, phase, private, true)
					expect(#lines > 0).to.equal(true)
					for _, line in ipairs(lines) do
						expect(line.text).never.to.contain("{")
					end
				end
			end
		end)
		it("ticks the Grimoire line once a name is written", function()
			local lines = Objectives.lines("Kira", "DeathNote", { canWrite = false }, true)
			expect(lines[1].done).to.equal(true)
		end)
		it("gives eliminated players the Specter lines", function()
			local lines = Objectives.lines("TaskForce", "Investigation", {}, false)
			expect(#lines).to.equal(3)
			for _, line in ipairs(lines) do
				expect(line.done == true).to.equal(false)
			end
		end)
		it("shows the eyes reads left", function()
			local lines = Objectives.lines("Follower", "Investigation", { eyes = { readsLeft = 2 } }, true)
			local found = false
			for _, line in ipairs(lines) do
				if string.find(line.text, "2 left", 1, true) then
					found = true
				end
			end
			expect(found).to.equal(true)
		end)
	end)

	describe("Hints", function()
		it("has a hint for every role", function()
			for _, role in ipairs(RoleLogic.ALL) do
				expect(Hints.BY_ID["role_" .. role] ~= nil).to.equal(true)
			end
		end)
	end)
end
