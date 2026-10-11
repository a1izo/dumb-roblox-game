-- Every map keeps the gameplay contract (stations, spawns, sheets, hoods,
-- areas, tip box and board), whatever its dressing looks like.

local Maps = script.Parent.Parent:WaitForChild("Maps")
local MapContract = require(Maps:WaitForChild("MapContract"))

local MAP_MODULES = { "TaskForceHQ", "UniversityCampus", "TokyoDistrict" }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("MapContract.validateLayout", function()
		for _, name in ipairs(MAP_MODULES) do
			it(name .. " keeps the contract", function()
				local map = require(Maps:WaitForChild(name))
				local problems = MapContract.validateLayout(map.layout())
				expect(table.concat(problems, "; ")).to.equal("")
			end)
		end
		for _, name in ipairs({ "TokyoDistrict", "UniversityCampus" }) do
			it(name .. "'s spare spots are usable too", function()
				local map = require(Maps:WaitForChild(name))
				local problems = MapContract.validateSpare(map.layout())
				expect(table.concat(problems, "; ")).to.equal("")
			end)
		end
		for _, name in ipairs(MAP_MODULES) do
			it(name .. " has no drop points left (notes pass hand to hand)", function()
				local layout = require(Maps:WaitForChild(name)).layout()
				expect(layout.dropPoints).to.equal(nil)
				expect((layout.spare or {}).dropPoints).to.equal(nil)
			end)
		end
		it("Tokyo's crowd walks and car lanes hang together", function()
			local layout = require(Maps:WaitForChild("TokyoDistrict")).layout()
			expect(type(layout.crowd)).to.equal("table")
			expect(#layout.crowd.nodes > 20).to.equal(true)
			-- The avenue both ways, and the taxi rank's lane out along the east street.
			expect(#layout.traffic.lanes).to.equal(3)
			expect(layout.traffic.lanes[1].road).to.equal(1)
			expect(layout.traffic.lanes[3].road).to.equal(2)
			expect(layout.traffic.lanes[3].kinds[1]).to.equal("Taxi")
			expect(table.concat(MapContract.validateCrowd(layout), "; ")).to.equal("")
		end)
		it("a map without a crowd has nothing to keep", function()
			for _, name in ipairs({ "TaskForceHQ", "UniversityCampus" }) do
				local layout = require(Maps:WaitForChild(name)).layout()
				expect(#MapContract.validateCrowd(layout)).to.equal(0)
			end
		end)
		it("reports a crowd whose walks are broken", function()
			local crowd = {
				nodes = {
					{ x = 0, y = 0, z = 0, kind = "walk" },
					{ x = 10, y = 0, z = 0, kind = "kerb" },
					{ x = 10, y = 0, z = 20, kind = "walk" },
					{ x = 50, y = 0, z = 50, kind = "walk" },
				},
				links = {
					{ a = 1, b = 2, kind = "walk", width = 2 },
					{ a = 2, b = 3, kind = "crossing", width = 4 },
					{ a = 3, b = 9, kind = "walk", width = 2 },
				},
				posts = { { x = 1, z = 1 } },
			}
			local traffic = { lanes = { { points = { { 0, 0 }, { 10, 0 } }, stop = 40, kinds = { "Tank" } } } }
			local text = table.concat(MapContract.validateCrowd({ crowd = crowd, traffic = traffic }), "; ")
			expect(text).to.contain("crosses the road from somewhere that is not a kerb")
			expect(text).to.contain("crowd link 3 does not join two nodes")
			expect(text).to.contain("crowd node 4 cannot be reached")
			expect(text).to.contain("crowd post 1 needs x, z and rot")
			expect(text).to.contain("lane 1 has no stop line along it")
			expect(text).to.contain("lane 1 wants a car the game does not have: Tank")
		end)
		it("reports a crowd node on top of a station", function()
			local layout = {
				stations = { { name = "Desk", x = 3, z = 0 } },
				crowd = { nodes = { { x = 0, y = 0, z = 0, kind = "walk" } }, links = {}, posts = {} },
			}
			expect(table.concat(MapContract.validateCrowd(layout), "; ")).to.contain("within 10 studs of station Desk")
		end)
		it("reports a map with too few stations", function()
			local problems = MapContract.validateLayout({ stations = {}, spawns = {}, sheets = {} })
			expect(#problems > 0).to.equal(true)
		end)
	end)
end
