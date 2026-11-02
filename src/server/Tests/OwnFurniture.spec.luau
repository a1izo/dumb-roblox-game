-- Each case map's own furniture (art/scripts/maps/ownprops.py): a model stands for a shared prop, which a map shows
-- until the model's set is imported, so it names a shared prop and keeps to that prop's footprint: the maps' walk checks
-- and the cutscenes were measured against it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModelCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelCatalog")) :: any

local OVER = 0.1 -- (how far a model may stand past the shared prop's box, across and in depth)

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Own furniture", function()
		it("stands for a shared prop, with its pivot, its collision and within its footprint", function()
			local count = 0
			for _, info in pairs(ModelCatalog) do
				if info.base then
					count += 1
					local base = ModelCatalog[info.base]
					expect(base ~= nil).to.equal(true)
					expect(info.set ~= base.set).to.equal(true)
					expect(info.pivot).to.equal(base.pivot)
					expect(info.collide).to.equal(base.collide)
					expect(info.size[1] <= base.size[1] + OVER).to.equal(true)
					expect(info.size[3] <= base.size[3] + OVER).to.equal(true)
				end
			end
			expect(count > 0).to.equal(true)
		end)
	end)
end
