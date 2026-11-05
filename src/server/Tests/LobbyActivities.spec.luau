-- The dive into the rift (Last breath).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Games = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames")
local LastBreath = require(Games:WaitForChild("LastBreath"))

local HEIGHT = 650 -- about the rift's depth (rim to the landing roof)

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("LastBreath", function()
		it("falls faster and faster, up to a limit", function()
			expect(LastBreath.speed(0)).to.equal(0)
			expect(LastBreath.speed(1)).to.equal(LastBreath.ACCEL)
			expect(LastBreath.speed(60)).to.equal(LastBreath.MAX_SPEED)
			expect(LastBreath.fallen(1)).to.be.near(LastBreath.ACCEL / 2)
			expect(LastBreath.fallen(2) > 2 * LastBreath.fallen(1)).to.equal(true)
		end)

		it("knows how long a fall takes, both ways round", function()
			for _, distance in ipairs({ 1, 40, 150, HEIGHT, 400 }) do
				expect(LastBreath.fallen(LastBreath.timeToFall(distance))).to.be.near(distance, 1e-6)
			end
			local impact = LastBreath.timeToFall(HEIGHT)
			expect(impact > 9 and impact < 12).to.equal(true)
		end)

		it("crashes a diver who never brakes, or brakes too late", function()
			local impact = LastBreath.timeToFall(HEIGHT)
			local never = LastBreath.outcome(HEIGHT, nil)
			expect(never.crashed).to.equal(true)
			expect(never.restAt).to.be.near(impact)
			local late = LastBreath.outcome(HEIGHT, impact - 0.1)
			expect(late.crashed).to.equal(true)
			expect(late.restAt > impact - 0.1).to.equal(true)
			expect(LastBreath.outcome(HEIGHT, impact + 1).crashed).to.equal(true)
		end)

		it("stops a diver who brakes in time, with the gap that is left", function()
			local early = LastBreath.outcome(HEIGHT, 2)
			expect(early.crashed).to.equal(false)
			local speed = LastBreath.speed(2)
			expect(early.gap).to.be.near(HEIGHT - LastBreath.fallen(2) - LastBreath.brakeDistance(speed), 1e-6)
			expect(early.restAt).to.be.near(2 + speed / LastBreath.BRAKE)
			-- The later the press, the smaller the gap, until it is too late.
			local last = math.huge
			local stopped, crashed = 0, 0
			for step = 0, 60 do
				local at = 9 + step * 0.05
				local outcome = LastBreath.outcome(HEIGHT, at)
				if outcome.crashed then
					crashed += 1
				else
					expect(crashed).to.equal(0)
					expect(outcome.gap < last).to.equal(true)
					last = outcome.gap
					stopped += 1
				end
			end
			expect(stopped > 5 and crashed > 5).to.equal(true)
		end)

		it("draws the dive the way it scores it", function()
			local outcome = LastBreath.outcome(HEIGHT, 4.2)
			expect(outcome.crashed).to.equal(false)
			local height, speed = LastBreath.at(HEIGHT, outcome.restAt + 1, 4.2)
			expect(height).to.be.near(outcome.gap, 1e-6)
			expect(speed).to.equal(0)
			local before = LastBreath.at(HEIGHT, 4.2, 4.2)
			local during = LastBreath.at(HEIGHT, 4.5, 4.2)
			expect(before > during and during > outcome.gap).to.equal(true)
			-- A crash ends on the roof, at rest.
			local onRoof, still = LastBreath.at(HEIGHT, 30, nil)
			expect(onRoof).to.equal(0)
			expect(still).to.equal(0)
			expect((LastBreath.at(HEIGHT, 0, nil))).to.equal(HEIGHT)
		end)

		it("ranks a wave: the smallest gap first, the fallen last", function()
			local rows = {
				{ id = "a", crashed = true, gap = 0 },
				{ id = "b", crashed = false, gap = 6.5 },
				{ id = "c", crashed = false, gap = 0.4 },
				{ id = "d", crashed = true, gap = 0 },
			}
			local order = {}
			for _, row in ipairs(LastBreath.rank(rows)) do
				table.insert(order, row.id)
			end
			expect(table.concat(order)).to.equal("cbad")
		end)

		it("keeps the smallest gap as the best, and gives a perfect stop a score", function()
			expect(LastBreath.isBetter(0, 3)).to.equal(true)
			expect(LastBreath.isBetter(3, 2.9)).to.equal(true)
			expect(LastBreath.isBetter(3, 3.1)).to.equal(false)
			expect(LastBreath.isBetter(3, 0)).to.equal(false)
			expect(LastBreath.score(0.004)).to.equal(1)
			expect(LastBreath.score(1.234)).to.equal(123)
			expect(LastBreath.formatScore(123)).to.equal("1.23")
		end)

		it("puts dives that begin close together in one wave", function()
			expect(LastBreath.sameWave(10, 10)).to.equal(true)
			expect(LastBreath.sameWave(10, 10 + LastBreath.WAVE)).to.equal(true)
			expect(LastBreath.sameWave(10, 10.1 + LastBreath.WAVE)).to.equal(false)
			expect(LastBreath.sameWave(10, 9)).to.equal(false)
		end)

		it("measures how deep in the rift a point is", function()
			local rift = { cx = 0, cz = 0, rx = 23, rz = 15, turn = 0 }
			expect(LastBreath.depth(Vector2.new(0, 0), rift)).to.be.near(0)
			expect(LastBreath.depth(Vector2.new(23, 0), rift)).to.be.near(1, 1e-6)
			expect(LastBreath.depth(Vector2.new(0, 30), rift) > 1).to.equal(true)
		end)
	end)
end
