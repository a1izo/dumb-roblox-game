-- Where players start (Shared/SpawnPicker): spread out over the whole pool, never within staring range while a spot
-- further off is left, out of each other's sight when they can be, a respawn away from everyone standing about, and a
-- fresh set each time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SpawnPicker = require(Shared:WaitForChild("SpawnPicker"))

-- A pool like a map's: twelve spawns in a tight block (6 studs apart) and twelve spares spread far around it.
local function pool(): { Vector3 }
	local spots = {}
	for row = 0, 3 do
		for col = 0, 2 do
			table.insert(spots, Vector3.new(col * 6, 0, row * 6))
		end
	end
	for k = 0, 11 do
		local a = 2 * math.pi * k / 12
		table.insert(spots, Vector3.new(math.cos(a) * 90, 0, math.sin(a) * 90))
	end
	return spots
end

local function nearest(points: { Vector3 }, picked: { number }): number
	local least = math.huge
	for i = 1, #picked do
		for j = i + 1, #picked do
			least = math.min(least, (points[picked[i]] - points[picked[j]]).Magnitude)
		end
	end
	return least
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("SpawnPicker", function()
		it("spreads a full case out of staring range of each other", function()
			local points = pool()
			local picked = SpawnPicker.pick(points, Config.MAX_PLAYERS, Random.new(4), { gap = Config.STARE_RANGE })
			expect(#picked).to.equal(Config.MAX_PLAYERS)
			local seen = {}
			for _, index in ipairs(picked) do
				expect(seen[index]).to.equal(nil)
				seen[index] = true
			end
			expect(nearest(points, picked) >= Config.STARE_RANGE).to.equal(true)
		end)

		it("keeps players out of each other's sight when it can", function()
			local points = pool()
			-- (the far spots see each other; the block's spots are behind walls from everything)
			local function visible(a: number, b: number): boolean
				return a > 12 and b > 12
			end
			local picked = SpawnPicker.pick(points, 4, Random.new(9), { gap = 1, visible = visible })
			local inSight = 0
			for i = 1, #picked do
				for j = i + 1, #picked do
					if visible(picked[i], picked[j]) then
						inSight += 1
					end
				end
			end
			expect(inSight <= 0).to.equal(true)
		end)

		it("puts a respawn far from everyone standing about", function()
			local points = pool()
			local standing = { Vector3.new(90, 0, 0), Vector3.new(0, 0, 0) }
			local picked = SpawnPicker.pick(points, 1, Random.new(1), { gap = Config.STARE_RANGE, occupied = standing })
			local at = points[picked[1]]
			for _, other in ipairs(standing) do
				expect((at - other).Magnitude >= 60).to.equal(true)
			end
		end)

		it("deals a fresh set each time, and deals again when there are more players than spots", function()
			local points = pool()
			local firsts = {}
			for seed = 1, 8 do
				firsts[SpawnPicker.pick(points, 3, Random.new(seed), { gap = 12 })[1]] = true
			end
			local kinds = 0
			for _ in pairs(firsts) do
				kinds += 1
			end
			expect(kinds >= 3).to.equal(true)
			local few = { Vector3.zero, Vector3.new(50, 0, 0) }
			expect(#SpawnPicker.pick(few, 5, Random.new(2), { gap = 12 })).to.equal(5)
		end)
	end)
end
