-- The Spire Ascent's rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Games = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames")
local Parkour = require(Games:WaitForChild("Parkour"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Parkour", function()
		it("takes the checkpoints in order only", function()
			local s = Parkour.newSession(0)
			local ok = Parkour.reach(s, 2, 10, 10)
			expect(ok).to.equal(false)
			ok = Parkour.reach(s, 1, 10, 10)
			expect(ok).to.equal(true)
			expect(s.reached).to.equal(1)
		end)

		it("refuses a climb that no one could make that fast", function()
			local s = Parkour.newSession(0)
			local ok, why = Parkour.reach(s, 1, 0.5, 60)
			expect(ok).to.equal(false)
			expect(why).to.equal("too fast")
			expect(s.reached).to.equal(0)
		end)

		it("finishes only after the last stone and not before the minimum time", function()
			local s = Parkour.newSession(0)
			expect(Parkour.finish(s, 100)).to.equal(nil)
			local now = 0
			for i = 1, Parkour.CHECKPOINTS do
				now += 3
				Parkour.reach(s, i, now, 5)
			end
			expect(Parkour.finish(s, 30)).to.equal(nil)
			expect(Parkour.finish(s, 75)).to.equal(75)
		end)

		it("knows a better time and formats it", function()
			expect(Parkour.isBetter(0, 90)).to.equal(true)
			expect(Parkour.isBetter(80, 90)).to.equal(false)
			expect(Parkour.isBetter(80, 79.9)).to.equal(true)
			expect(Parkour.format(83.4)).to.equal("1:23.4")
			expect(Parkour.format(63.04)).to.equal("1:03.0")
			expect(Parkour.formatCentis(5000)).to.equal("0:50.0")
		end)

		it("tells standing on a stone from being below it", function()
			local mark = Vector3.new(10, 40, 10)
			expect(Parkour.near(Vector3.new(12, 41, 8), mark)).to.equal(true)
			expect(Parkour.near(Vector3.new(30, 41, 8), mark)).to.equal(false)
			expect(Parkour.near(Vector3.new(10, 10, 10), mark)).to.equal(false)
			expect(Parkour.fell(Vector3.new(10, 10, 10), mark)).to.equal(true)
			expect(Parkour.fell(Vector3.new(10, 38, 10), mark)).to.equal(false)
		end)
	end)
end
