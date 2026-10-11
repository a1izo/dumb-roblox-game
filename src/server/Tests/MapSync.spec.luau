-- The scramble's snapshots: what goes in comes out (to the wire's precision), a full street fits
-- an unreliable event, and anything else is refused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapSync = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapSync"))

local function walker(x: number, z: number, heading: number, flags: { [string]: boolean }?)
	local options = flags or {}
	return {
		x = x,
		z = z,
		heading = heading,
		shown = options.shown ~= false,
		passing = options.passing == true,
		standing = options.standing == true,
	}
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("MapSync", function()
		it("brings walkers back where they were", function()
			local walkers = {
				walker(-71.98, -79.1, 1.25),
				walker(199.97, 149.03, 6.1, { passing = true }),
				walker(0, 0, 0, { standing = true }),
				walker(12.5, -3.25, 3, { shown = false }),
			}
			local snapshot = MapSync.decode(MapSync.encode(123.456, walkers, {}))
			expect(snapshot ~= nil).to.equal(true)
			expect(snapshot.time).to.be.near(123.456, 0.001)
			expect(#snapshot.walkers).to.equal(4)
			expect(#snapshot.cars).to.equal(0)
			for index, sent in ipairs(walkers) do
				local got = snapshot.walkers[index]
				expect(got.x).to.be.near(sent.x, 1 / 32)
				expect(got.z).to.be.near(sent.z, 1 / 32)
				expect(math.abs(MapSync.turnBetween(got.heading, sent.heading)) < 2 * math.pi / 256).to.equal(true)
				expect(got.shown).to.equal(sent.shown)
				expect(got.passing).to.equal(sent.passing)
				expect(got.standing).to.equal(sent.standing)
			end
		end)
		it("brings cars back with their kind, their brakes and their honks", function()
			local cars = {
				{ x = -95.09, z = -141.04, heading = 0.6, shown = true, braking = true, kind = 2, honks = 7 },
				{ x = 18.12, z = 16.86, heading = 3.7, shown = false, braking = false, kind = 0, honks = 0 },
			}
			local snapshot = MapSync.decode(MapSync.encode(1, { walker(1, 2, 3) }, cars))
			expect(#snapshot.walkers).to.equal(1)
			expect(#snapshot.cars).to.equal(2)
			expect(snapshot.cars[1].x).to.be.near(-95.09, 1 / 32)
			expect(snapshot.cars[1].shown).to.equal(true)
			expect(snapshot.cars[1].braking).to.equal(true)
			expect(snapshot.cars[1].kind).to.equal(2)
			-- (Honks count round in fours: only a change matters.)
			expect(snapshot.cars[1].honks).to.equal(3)
			expect(snapshot.cars[2].shown).to.equal(false)
			expect(snapshot.cars[2].kind).to.equal(0)
		end)
		it("fits a full street in one unreliable event", function()
			local walkers = {}
			for index = 1, 44 do
				walkers[index] = walker(index * 3.1, -index * 2.7, index)
			end
			local cars = {}
			for index = 1, 4 do
				cars[index] = { x = index, z = index, heading = 0, shown = true, braking = false, kind = 1, honks = 1 }
			end
			local data = MapSync.encode(600, walkers, cars)
			expect(buffer.len(data) < MapSync.LIMIT).to.equal(true)
			expect(buffer.len(data)).to.equal(6 + 48 * 6)
		end)
		it("keeps places off the edge of the map on the wire", function()
			local snapshot = MapSync.decode(MapSync.encode(0, { walker(5000, -5000, 0) }, {}))
			expect(snapshot.walkers[1].x).to.be.near(32767 / 32, 0.001)
			expect(snapshot.walkers[1].z).to.be.near(-1024, 0.001)
		end)
		it("refuses what is not a whole snapshot", function()
			expect(MapSync.decode("hello")).to.equal(nil)
			expect(MapSync.decode(nil)).to.equal(nil)
			expect(MapSync.decode(buffer.create(3))).to.equal(nil)
			local data = MapSync.encode(1, { walker(1, 2, 3), walker(4, 5, 6) }, {})
			local short = buffer.create(buffer.len(data) - 2)
			buffer.copy(short, 0, data, 0, buffer.len(short))
			expect(MapSync.decode(short)).to.equal(nil)
		end)
		it("an empty snapshot says the street is empty", function()
			local snapshot = MapSync.decode(MapSync.encode(0, {}, {}))
			expect(#snapshot.walkers).to.equal(0)
			expect(#snapshot.cars).to.equal(0)
		end)
		it("turns the short way round", function()
			expect(MapSync.turnBetween(0.1, 6.2)).to.be.near(6.2 - 0.1 - 2 * math.pi, 1e-6)
			expect(MapSync.turnBetween(6.2, 0.1)).to.be.near(0.1 - 6.2 + 2 * math.pi, 1e-6)
			expect(MapSync.turnBetween(1, 2)).to.be.near(1, 1e-6)
		end)
		it("names a model for every kind of car", function()
			expect(#MapSync.CARS).to.equal(3)
		end)
	end)
end
