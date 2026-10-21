-- Sitting at the war table (Shared/Seating, shop overhaul 2026-10-21): a chair stands behind each place on the line
-- out from the table's middle, a body sits a little behind the chair's middle facing the table, every seat item's
-- clip is a loop, and every chair skin is a Core prop in the catalog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Index = require(Shared:WaitForChild("Anim"):WaitForChild("Clips"):WaitForChild("Index")) :: any
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local ModelCatalog = require(Shared:WaitForChild("ModelCatalog")) :: any
local Seating = require(Shared:WaitForChild("Seating"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Seating", function()
		it("puts the chair behind a place, out from the table, and the body over it facing the table", function()
			-- the war room's place 2 (MeetingRoom: standing at radius 17, facing the middle)
			local place = CFrame.lookAt(Vector3.new(8.5, 0, 14.722), Vector3.new(0, 0, 0))
			local chair = Seating.chair(place)
			expect(Vector3.new(chair.X, 0, chair.Z).Magnitude).to.be.near(19.6, 1e-3)
			expect(chair.LookVector:Dot(place.LookVector)).to.be.near(1, 1e-6)
			local body = Seating.body(place)
			expect(Vector3.new(body.X, 0, body.Z).Magnitude).to.be.near(19.6 + Seating.ROOT_BEHIND, 1e-3)
			expect(body.Y).to.be.near(0, 1e-6)
		end)
		it("gives every seat a looping clip, and everyone the plain one", function()
			local free = 0
			for _, item in ipairs(Cosmetics.ofKind("seat")) do
				local entry = Index[item.clip]
				expect(entry ~= nil).to.equal(true)
				expect(entry and entry.loop).to.equal(true)
				if item.source == "free" then
					free += 1
					expect(item.clip).to.equal(Seating.DEFAULT)
				end
			end
			expect(free).to.equal(1)
			expect(#Cosmetics.ofKind("seat")).to.equal(6)
		end)
		it("makes every chair skin a Core prop in the catalog", function()
			expect(#Cosmetics.ofKind("chair")).to.equal(4)
			for _, item in ipairs(Cosmetics.ofKind("chair")) do
				local entry = ModelCatalog[item.model]
				expect(entry ~= nil).to.equal(true)
				expect(entry and entry.set).to.equal("Core")
				expect(type(item.core)).to.equal("number")
			end
		end)
	end)
end
