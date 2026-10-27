-- The exploit guards (2026-10-27): a body moving faster than anyone could, or through a wall, is caught
-- (Services/MovementGuard); a case file answered quicker than anyone could solve it is refused (Shared/Tasks/PuzzleSet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PuzzleSet = require(Shared:WaitForChild("Tasks"):WaitForChild("PuzzleSet"))
local MovementGuard = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("MovementGuard"))

local FAR = Vector3.new(0, 900, 4000) -- (empty sky, nothing to hit)

local function open(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {}
	return params
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("MovementGuard", function()
		it("lets a body walk and run, and catches a speed hack or a teleport", function()
			local track = { at = FAR, cframe = CFrame.new(FAR), time = 0, air = 0 }
			expect(MovementGuard.problem(track, FAR + Vector3.new(8, 0, 0), 16, 0.5, open())).to.equal(nil)
			expect(MovementGuard.problem(track, FAR + Vector3.new(0, 0, 18), 16, 0.5, open())).to.equal(nil)
			expect(MovementGuard.problem(track, FAR + Vector3.new(40, 0, 0), 16, 0.5, open())).to.equal("speed")
			expect(MovementGuard.problem(track, FAR + Vector3.new(300, 0, 0), 16, 0.5, open())).to.equal("speed")
			-- (a client that froze for two seconds catches up without being put back)
			expect(MovementGuard.problem(track, FAR + Vector3.new(30, 0, 0), 16, 2, open())).to.equal(nil)
		end)

		it("catches a body passing through a wall", function()
			local wall = Instance.new("Part")
			wall.Anchored = true
			wall.CanCollide = true
			wall.Size = Vector3.new(1, 10, 10)
			wall.Position = FAR + Vector3.new(3, 0, 0)
			wall.Parent = workspace
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { wall }
			local track = { at = FAR, cframe = CFrame.new(FAR), time = 0, air = 0 }
			expect(MovementGuard.problem(track, FAR + Vector3.new(6, 0, 0), 16, 0.5, params)).to.equal("noclip")
			expect(MovementGuard.problem(track, FAR + Vector3.new(0, 0, 6), 16, 0.5, params)).to.equal(nil)
			wall:Destroy()
		end)
	end)

	describe("Case file answers", function()
		it("take a person's time at least", function()
			for _, id in ipairs(PuzzleSet.ids()) do
				expect(PuzzleSet.minSeconds(id) >= 1).to.equal(true)
			end
			expect(PuzzleSet.minSeconds("no such puzzle")).to.equal(PuzzleSet.MIN_SECONDS)
		end)
	end)
end
