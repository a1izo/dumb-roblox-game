-- Every map keeps the gameplay contract (stations, spawns, sheets, drop points, hoods,
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
		it("TokyoDistrict's spare spots are usable too", function()
			local map = require(Maps:WaitForChild("TokyoDistrict"))
			local problems = MapContract.validateSpare(map.layout())
			expect(table.concat(problems, "; ")).to.equal("")
		end)
		it("reports a map with too few stations", function()
			local problems = MapContract.validateLayout({ stations = {}, spawns = {}, sheets = {}, dropPoints = {} })
			expect(#problems > 0).to.equal(true)
		end)
	end)
end
