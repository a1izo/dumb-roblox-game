-- Every map keeps the gameplay contract (stations, spawns, sheets,
-- areas and the bell's spot), whatever its dressing looks like.

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
					{ x = 60, y = 0, z = 60, kind = "walk" },
					{ x = 70, y = 0, z = 60, kind = "walk" },
				},
				links = {
					{ a = 1, b = 2, kind = "walk", width = 2 },
					{ a = 2, b = 3, kind = "crossing", width = 4 },
					{ a = 3, b = 9, kind = "walk", width = 2 },
					{ a = 2, b = 1, kind = "walk", width = 2 },
					{ a = 1, b = 3, kind = "walk", width = 1 },
					{ a = 5, b = 6, kind = "walk", width = 1, single = true },
				},
				posts = { { x = 1, z = 1 } },
			}
			local traffic = { lanes = { { points = { { 0, 0 }, { 10, 0 } }, stop = 40, kinds = { "Tank" } } } }
			local text = table.concat(MapContract.validateCrowd({ crowd = crowd, traffic = traffic }), "; ")
			expect(text).to.contain("crosses the road from somewhere that is not a kerb")
			expect(text).to.contain("crowd link 3 does not join two nodes")
			expect(text).to.contain("crowd link 4 joins the same two nodes as link 1")
			expect(text).to.contain("crowd link 5 is 1.0 wide and not marked single file")
			-- (a narrow walk marked single is fine)
			expect(string.find(text, "crowd link 6", 1, true)).to.equal(nil)
			expect(text).to.contain("crowd node 4 cannot be reached")
			expect(text).to.contain("crowd post 1 needs x, z and rot")
			expect(text).to.contain("lane 1 has no stop line along it")
			expect(text).to.contain("lane 1 wants a car the game does not have: Tank")
		end)
		it("reports crowd ends that are not nodes, listed twice, of no kind, weightless or too few", function()
			local nodes = { { x = 0, y = 0, z = 0, kind = "walk" }, { x = 30, y = 0, z = 0, kind = "walk" } }
			local links = { { a = 1, b = 2, kind = "walk", width = 2 } }
			local text = table.concat(
				MapContract.validateCrowd({
					crowd = {
						nodes = nodes,
						links = links,
						posts = {},
						ends = {
							{ node = 1, kind = "door", weight = 1 },
							{ node = 1, kind = "wall", weight = 0 },
							{ node = 9, kind = "edge", weight = 1 },
						},
					},
				}),
				"; "
			)
			expect(text).to.contain("crowd end 2 lists node 1 twice")
			expect(text).to.contain("crowd end 2 has an unknown kind wall")
			expect(text).to.contain("crowd end 2 needs a weight")
			expect(text).to.contain("crowd end 3 is not a node")
			local few = MapContract.validateCrowd({
				crowd = { nodes = nodes, links = links, posts = {}, ends = { { node = 1, kind = "edge", weight = 1 } } },
			})
			expect(table.concat(few, "; ")).to.contain("fewer than two ends")
			local fine = MapContract.validateCrowd({
				crowd = {
					nodes = nodes,
					links = links,
					posts = {},
					ends = { { node = 1, kind = "edge", weight = 1 }, { node = 2, kind = "door", weight = 2 } },
				},
			})
			expect(table.concat(fine, "; ")).to.equal("")
		end)
		it(
			"reports pause spots that hang off nothing, a crossing or a single-file walk, or lie off their walk",
			function()
				local nodes = {
					{ x = 0, y = 0, z = 0, kind = "kerb" },
					{ x = 30, y = 0, z = 0, kind = "kerb" },
					{ x = 60, y = 0, z = 0, kind = "walk" },
					{ x = 90, y = 0, z = 0, kind = "walk" },
				}
				local links = {
					{ a = 1, b = 2, kind = "crossing", width = 4 },
					{ a = 2, b = 3, kind = "walk", width = 2 },
					{ a = 3, b = 4, kind = "walk", width = 1, single = true },
				}
				local function text(spots)
					return table.concat(
						MapContract.validateCrowd({
							crowd = { nodes = nodes, links = links, posts = {}, spots = spots },
						}),
						"; "
					)
				end
				local bad = text({
					{ x = 10, z = 3, rot = 0, s = 10, kind = "sign", link = 1 },
					{ x = 70, z = 3, rot = 0, s = 10, kind = "sign", link = 3 },
					{ x = 40, z = 3, rot = 0, s = 90, kind = "sign", link = 2 },
					{ x = 40, z = 3, rot = 0, s = 10, kind = "sign", link = 9 },
					{ x = 40, z = 3, s = 10, kind = "sign", link = 2 },
				})
				expect(bad).to.contain("crowd spot 1 hangs off a crossing or a single-file walk")
				expect(bad).to.contain("crowd spot 2 hangs off a crossing or a single-file walk")
				expect(bad).to.contain("crowd spot 3 is not along its walk")
				expect(bad).to.contain("crowd spot 4 hangs off a walk that is not there")
				expect(bad).to.contain("crowd spot 5 needs x, z, rot and s")
				expect(text({ { x = 40, z = 3, rot = 90, s = 10, kind = "sign", link = 2 } })).to.equal("")
			end
		)
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
