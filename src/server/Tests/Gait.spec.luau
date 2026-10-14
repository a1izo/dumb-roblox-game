-- The movement controller's arithmetic (Shared/Anim/Gait): directions, the legs' phases, landing strengths,
-- the order fidgets come in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gait = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anim"):WaitForChild("Gait"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Gait", function()
		it("splits a direction between the two cycles either side of it, summing to one", function()
			local cases = {
				{ Vector3.new(0, 0, -16), "F", 1 },
				{ Vector3.new(0, 0, 16), "B", 1 },
				{ Vector3.new(-16, 0, 0), "L", 1 },
				{ Vector3.new(16, 0, 0), "R", 1 },
				{ Vector3.new(-8, 0, -8), "F", 0.5 },
				{ Vector3.new(-8, 0, -8), "L", 0.5 },
				{ Vector3.new(8, 0, 8), "B", 0.5 },
				{ Vector3.new(8, 0, 8), "R", 0.5 },
			}
			for _, case in ipairs(cases) do
				local w = Gait.directions(case[1])
				expect(w[case[2]]).to.be.near(case[3], 1e-6)
				expect(w.F + w.B + w.L + w.R).to.be.near(1, 1e-6)
			end
			for i = 0, 35 do
				local a = math.rad(i * 10)
				local w = Gait.directions(Vector3.new(math.sin(a), 0, math.cos(a)) * 7)
				expect(w.F + w.B + w.L + w.R).to.be.near(1, 1e-6)
			end
			local still = Gait.directions(Vector3.zero)
			expect(still.F).to.equal(1)
		end)
		it("warps a leg's phase so its stance fills the shared stance, keeping the landings in place", function()
			for _, pair in ipairs({ { 0.4, 0.6 }, { 0.3, 0.234 }, { 0.6, 0.234 }, { 0.234, 0.6 } }) do
				local shared, stance = pair[1], pair[2]
				expect(Gait.warp(0, shared, stance)).to.be.near(0, 1e-9)
				expect(Gait.warp(shared, shared, stance)).to.be.near(stance, 1e-9)
				expect(Gait.warp(0.999999, shared, stance)).to.be.near(1, 1e-4)
				local last = -1
				for i = 0, 100 do
					local q = Gait.warp(i / 100.0001, shared, stance)
					expect(q >= last).to.equal(true)
					last = q
				end
				-- the left leg lands at half a cycle in every clip
				expect(Gait.leftWarp(0.5, shared, stance)).to.be.near(0.5, 1e-9)
				expect(Gait.leftWarp((0.5 + shared) % 1, shared, stance)).to.be.near((0.5 + stance) % 1, 1e-9)
			end
		end)
		it("picks the landing by the height it is like falling from", function()
			local g = 196.2
			local function from(height)
				return math.sqrt(2 * g * height)
			end
			expect(Gait.landing(from(0.3), g)).to.equal(nil)
			expect(Gait.landing(from(1.5), g)).to.equal("landLight")
			expect(Gait.landing(from(7.2), g)).to.equal("landNormal") -- a full jump, back to the ground
			expect(Gait.landing(from(20), g)).to.equal("landHeavy")
			expect(Gait.landing(0, g)).to.equal(nil)
		end)
		it("deals fidgets from a shuffled bag, never the same twice running", function()
			local pool = { "a", "b", "c", "d", "e", "f" }
			local bag = Gait.bag()
			local random = Random.new(7)
			local last = nil
			for _ = 1, 20 do
				local seen = {}
				for _ = 1, #pool do
					local id = Gait.draw(bag, pool, random) :: string
					expect(id ~= last).to.equal(true)
					expect(seen[id]).to.equal(nil)
					seen[id] = true
					last = id
				end
			end
			-- another pool (the mood changed) is dealt from at once
			local other = { "x", "y" }
			local id = Gait.draw(bag, other, random)
			expect(id == "x" or id == "y").to.equal(true)
			expect(Gait.draw(Gait.bag(), {}, random)).to.equal(nil)
		end)
	end)
end
