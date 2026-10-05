-- The lobby mini-games' rules: the Spire Ascent, the rune courtyard, the bone dice and the stone-toss.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Games = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames")
local Dice = require(Games:WaitForChild("Dice"))
local Parkour = require(Games:WaitForChild("Parkour"))
local Runes = require(Games:WaitForChild("Runes"))
local Toss = require(Games:WaitForChild("Toss"))

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

	describe("Runes", function()
		it("gives the same prefix for the same seed however long the sequence grows", function()
			local short = Runes.sequence(7, 3)
			local long = Runes.sequence(7, 9)
			expect(#short).to.equal(3)
			for i = 1, 3 do
				expect(short[i]).to.equal(long[i])
			end
		end)

		it("never repeats a tile running and stays on the grid", function()
			for seed = 1, 40 do
				local seq = Runes.sequence(seed, 20)
				for i, tile in ipairs(seq) do
					expect(tile >= 1 and tile <= Runes.TILES).to.equal(true)
					if i > 1 then
						expect(tile).never.to.equal(seq[i - 1])
					end
				end
			end
		end)

		it("plays a round, then a longer one, and ends on a wrong tile", function()
			local state = Runes.start(11)
			expect(#state.seq).to.equal(3)
			local first = Runes.sequence(11, 3)
			expect(Runes.step(state, first[1])).to.equal("ok")
			expect(Runes.step(state, first[2])).to.equal("ok")
			expect(Runes.step(state, first[3])).to.equal("round")
			expect(Runes.rounds(state)).to.equal(1)
			expect(#state.seq).to.equal(4)
			local wrong = if state.seq[1] == 1 then 2 else 1
			expect(Runes.step(state, wrong)).to.equal("wrong")
			expect(Runes.rounds(state)).to.equal(1)
		end)

		it("finds the tile under a point", function()
			-- tiles of 7 with 1.8 between: pitch 8.8, the middle tile at the origin
			expect(Runes.tileAt(0, 0, 7, 1.8)).to.equal(5)
			expect(Runes.tileAt(-8.8, -8.8, 7, 1.8)).to.equal(1)
			expect(Runes.tileAt(8.8, -8.8, 7, 1.8)).to.equal(3)
			expect(Runes.tileAt(-8.8, 8.8, 7, 1.8)).to.equal(7)
			expect(Runes.tileAt(8.8, 8.8, 7, 1.8)).to.equal(9)
			expect(Runes.tileAt(4.4, 0, 7, 1.8)).to.equal(nil) -- the gap between two tiles
			expect(Runes.tileAt(30, 0, 7, 1.8)).to.equal(nil)
		end)

		it("takes longer to show a longer sequence", function()
			expect(Runes.showTime(6) > Runes.showTime(3)).to.equal(true)
		end)
	end)

	describe("Dice", function()
		it("rolls two dice from one to six", function()
			local rng = Random.new(5)
			for _ = 1, 200 do
				local a, b = Dice.roll(rng)
				expect(a >= 1 and a <= 6 and b >= 1 and b <= 6).to.equal(true)
			end
		end)

		it("beats the house alone, pushes on a tie", function()
			expect(#Dice.settle({ a = 9 }, 7).winners).to.equal(1)
			expect(#Dice.settle({ a = 5 }, 7).losers).to.equal(1)
			expect(Dice.settle({ a = 7 }, 7).push).to.equal(true)
		end)

		it("gives the round to the highest of several, sharing a tie", function()
			local o = Dice.settle({ a = 6, b = 11, c = 11 })
			expect(#o.winners).to.equal(2)
			expect(#o.losers).to.equal(1)
			expect(o.push).to.equal(false)
			expect(Dice.settle({ a = 8, b = 8 }).push).to.equal(true)
		end)

		it("counts a streak of wins and resets it on a loss", function()
			expect(Dice.streak(2, "win")).to.equal(3)
			expect(Dice.streak(2, "push")).to.equal(2)
			expect(Dice.streak(2, "lose")).to.equal(0)
		end)
	end)

	describe("Toss", function()
		local rift = { cx = 0, cz = 0, rx = 23, rz = 15, turn = 0 }

		it("throws farther the higher you look", function()
			expect(Toss.distance(40) > Toss.distance(10)).to.equal(true)
			expect(Toss.distance(10) > Toss.distance(-10)).to.equal(true)
			expect(Toss.distance(-90)).to.equal(Toss.MIN_DISTANCE)
			expect(Toss.distance(90)).to.equal(Toss.MAX_DISTANCE)
		end)

		it("measures how deep in the rift a point is", function()
			expect(Toss.depth(Vector2.new(0, 0), rift)).to.be.near(0)
			expect(Toss.depth(Vector2.new(23, 0), rift)).to.be.near(1, 1e-6)
			expect(Toss.depth(Vector2.new(0, 30), rift) > 1).to.equal(true)
		end)

		it("misses a rift that is out of reach and rings when it lands in", function()
			local rng = Random.new(3)
			local miss = Toss.result(Vector2.new(-200, 0), Vector2.new(1, 0), 0, rift, rng)
			expect(miss.hit).to.equal(false)
			expect(miss.echo).to.equal(0)
			-- aim from far enough away that the farthest throw reaches the middle of the rift
			local origin = Vector2.new(-Toss.distance(25), 0)
			local hit = Toss.result(origin, Vector2.new(1, 0), 25, rift, rng)
			expect(hit.hit).to.equal(true)
			expect(hit.echo >= Toss.FREE_FALL).to.equal(true)
		end)

		it("knows a better echo", function()
			expect(Toss.isBetter(0, 2.1)).to.equal(true)
			expect(Toss.isBetter(3.2, 2.1)).to.equal(false)
		end)
	end)
end
