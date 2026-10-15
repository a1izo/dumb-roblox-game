-- The lobby's later games: the dive into the rift (Last breath) and Death's mark.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Games = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames")
local LastBreath = require(Games:WaitForChild("LastBreath"))
local Mark = require(Games:WaitForChild("Mark"))

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
	end)

	describe("Mark", function()
		local function first(_n: number): number
			return 1
		end
		local function last(n: number): number
			return n
		end

		it("waits for two players, then gives one of them the mark", function()
			local state = Mark.new()
			expect(Mark.join(state, "a", 0, first)).to.equal(true)
			expect(Mark.running(state)).to.equal(false)
			expect(state.carrier).to.equal(nil)
			expect(Mark.join(state, "a", 0, first)).to.equal(false)
			Mark.join(state, "b", 5, first)
			expect(Mark.running(state)).to.equal(true)
			expect(state.carrier).to.equal("a")
			expect(state.nextToll).to.equal(5 + Mark.TOLL)
		end)

		it("passes the mark to someone close, but not straight back", function()
			local state = Mark.new()
			Mark.join(state, "a", 0, first)
			Mark.join(state, "b", 0, first)
			Mark.join(state, "c", 0, first)
			expect(Mark.canPass(state, "a", "b", 10, Mark.RANGE + 1)).to.equal(false)
			expect(Mark.canPass(state, "b", "a", 10, 1)).to.equal(false)
			expect(Mark.canPass(state, "a", "a", 10, 0)).to.equal(false)
			expect(Mark.canPass(state, "a", "z", 10, 1)).to.equal(false)
			expect(Mark.canPass(state, "a", "b", 10, 1)).to.equal(true)
			Mark.pass(state, "b", 10)
			expect(state.carrier).to.equal("b")
			expect(Mark.canPass(state, "b", "a", 10.5, 1)).to.equal(false)
			expect(Mark.canPass(state, "b", "c", 10.5, 1)).to.equal(true)
			expect(Mark.canPass(state, "b", "a", 10 + Mark.NO_TAGBACK, 1)).to.equal(true)
		end)

		it("drops the carrier at the toll and counts everyone else's streak", function()
			local state = Mark.new()
			Mark.join(state, "a", 0, first)
			Mark.join(state, "b", 0, first)
			Mark.join(state, "c", 0, first)
			expect(Mark.due(state, Mark.TOLL - 1)).to.equal(false)
			expect(Mark.due(state, Mark.TOLL)).to.equal(true)
			local down, streaks = Mark.toll(state, Mark.TOLL, last)
			expect(down).to.equal("a")
			expect(streaks.a).to.equal(0)
			expect(streaks.b).to.equal(1)
			expect(streaks.c).to.equal(1)
			-- The mark jumps to someone else, and cannot go back to whoever is lying down.
			expect(state.carrier).to.equal("c")
			expect(Mark.canPass(state, "c", "a", Mark.TOLL + 1, 1)).to.equal(false)
			expect(Mark.canPass(state, "c", "b", Mark.TOLL + 1, 1)).to.equal(true)
			expect(Mark.due(state, Mark.TOLL + 1)).to.equal(false)
			Mark.toll(state, 2 * Mark.TOLL, first)
			expect(state.streaks.c).to.equal(0)
			expect(state.streaks.b).to.equal(2)
			expect(state.streaks.a).to.equal(1)
		end)

		it("keeps the mark in the game when its carrier leaves, and stops when too few are left", function()
			local state = Mark.new()
			Mark.join(state, "a", 0, first)
			Mark.join(state, "b", 0, first)
			Mark.join(state, "c", 0, first)
			expect(Mark.leave(state, "a", 3, first)).to.equal(true)
			expect(state.carrier).to.equal("b")
			expect(Mark.running(state)).to.equal(true)
			expect(Mark.leave(state, "z", 3, first)).to.equal(false)
			Mark.leave(state, "b", 4, first)
			expect(Mark.running(state)).to.equal(false)
			expect(state.carrier).to.equal(nil)
			expect(state.nextToll).to.equal(nil)
			expect(Mark.isMember(state, "c")).to.equal(true)
		end)

		it("counts more tolls survived as the better streak", function()
			expect(Mark.isBetter(0, 1)).to.equal(true)
			expect(Mark.isBetter(4, 4)).to.equal(false)
		end)
	end)
end
