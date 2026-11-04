-- The lobby mini-games' rules: the Spire Ascent, the rune courtyard, the Lantern Run and the spirit trial.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Games = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames")
local Lanterns = require(Games:WaitForChild("Lanterns"))
local Parkour = require(Games:WaitForChild("Parkour"))
local Runes = require(Games:WaitForChild("Runes"))
local SpiritTrial = require(Games:WaitForChild("SpiritTrial"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Lanterns", function()
		it("lights each lantern once, and only the ones there are", function()
			local s = Lanterns.newSession(0)
			expect(Lanterns.light(s, 3)).to.equal(true)
			expect(Lanterns.light(s, 3)).to.equal(false)
			expect(Lanterns.light(s, 0)).to.equal(false)
			expect(Lanterns.light(s, Lanterns.COUNT + 1)).to.equal(false)
			expect(s.count).to.equal(1)
		end)

		it("finishes only with every lantern lit, and never faster than an honest run", function()
			local s = Lanterns.newSession(10)
			for index = 1, Lanterns.COUNT - 1 do
				Lanterns.light(s, index)
			end
			expect(Lanterns.finish(s, 100)).to.equal(nil)
			Lanterns.light(s, Lanterns.COUNT)
			expect(Lanterns.finish(s, 10 + Lanterns.MIN_TIME - 1)).to.equal(nil)
			expect(Lanterns.finish(s, 100)).to.equal(90)
		end)

		it("lets the flame die when the time is up, but not once the run is done", function()
			local s = Lanterns.newSession(0)
			expect(Lanterns.out(s, Lanterns.LIMIT - 1)).to.equal(false)
			expect(Lanterns.out(s, Lanterns.LIMIT + 1)).to.equal(true)
			for index = 1, Lanterns.COUNT do
				Lanterns.light(s, index)
			end
			expect(Lanterns.out(s, Lanterns.LIMIT + 1)).to.equal(false)
		end)

		it("knows a better time and a lantern within reach", function()
			expect(Lanterns.isBetter(0, 90)).to.equal(true)
			expect(Lanterns.isBetter(80, 90)).to.equal(false)
			expect(Lanterns.isBetter(95, 90)).to.equal(true)
			expect(Lanterns.near(Vector3.new(3, 2, 4), Vector3.new(0, 9, 0))).to.equal(true)
			expect(Lanterns.near(Vector3.new(30, 2, 0), Vector3.new(0, 9, 0))).to.equal(false)
		end)
	end)

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

	describe("SpiritTrial", function()
		it("lays out one ring per spot around the middle", function()
			local spots = SpiritTrial.layout(Vector3.new(10, 0, 20))
			expect(#spots).to.equal(SpiritTrial.RINGS)
			for _, spot in ipairs(spots) do
				local distance = (spot - Vector3.new(10, 0, 20)).Magnitude
				expect(distance > 30 and distance < 60).to.equal(true)
			end
		end)
		it("takes the rings in order and at a believable pace", function()
			local s = SpiritTrial.newSession(0)
			expect((SpiritTrial.reach(s, 2, 5, 10))).to.equal(false)
			expect((SpiritTrial.reach(s, 1, 0.1, 30))).to.equal(false) -- 300 studs a second
			expect((SpiritTrial.reach(s, 1, 2, 30))).to.equal(true)
		end)
		it("times only a full, honest lap", function()
			local s = SpiritTrial.newSession(0)
			for index = 1, SpiritTrial.RINGS - 1 do
				SpiritTrial.reach(s, index, index * 3, 20)
			end
			expect(SpiritTrial.finish(s, 30)).to.equal(nil)
			SpiritTrial.reach(s, SpiritTrial.RINGS, 30, 20)
			expect(SpiritTrial.finish(s, 30)).to.equal(30)
			local quick = SpiritTrial.newSession(0)
			quick.reached = SpiritTrial.RINGS
			expect(SpiritTrial.finish(quick, 5)).to.equal(nil)
		end)
		it("keeps the lower time", function()
			expect(SpiritTrial.isBetter(0, 20)).to.equal(true)
			expect(SpiritTrial.isBetter(18, 20)).to.equal(false)
			expect(SpiritTrial.isBetter(25, 20)).to.equal(true)
		end)
	end)
end
