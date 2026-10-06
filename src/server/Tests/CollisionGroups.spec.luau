-- Who collides with whom: a Specter waiting in the lobby (Away) stands on the world but passes through
-- everyone's bodies, and bodies still bump into each other and stand on the world.

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("CollisionGroups"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local function collide(a: string, b: string): boolean
		return PhysicsService:CollisionGroupsAreCollidable(a, b)
	end

	describe("CollisionGroups", function()
		CollisionGroups.init()
		local CHARS, AWAY = CollisionGroups.CHARACTERS, CollisionGroups.AWAY

		it("keeps bodies on the world and bumping into each other", function()
			expect(collide(CHARS, "Default")).to.equal(true)
			expect(collide(CHARS, CHARS)).to.equal(true)
		end)
		it("lets an away body stand on the world but pass through bodies", function()
			expect(collide(AWAY, "Default")).to.equal(true)
			expect(collide(AWAY, CHARS)).to.equal(false)
			expect(collide(AWAY, AWAY)).to.equal(false)
		end)
		it("keeps ghosts out of everyone's way", function()
			expect(collide(CollisionGroups.SPECTERS, CHARS)).to.equal(false)
			expect(collide(CollisionGroups.SPECTERS, AWAY)).to.equal(false)
		end)
		it("moves a body's parts but leaves a ghost's parts alone", function()
			local model = Instance.new("Model")
			local plain = Instance.new("Part")
			plain.Parent = model
			local ghostly = Instance.new("Part")
			ghostly.CollisionGroup = CollisionGroups.SPECTERS
			ghostly.Parent = model
			local connection = CollisionGroups.body(model, CHARS)
			expect(plain.CollisionGroup).to.equal(CHARS)
			expect(ghostly.CollisionGroup).to.equal(CollisionGroups.SPECTERS)
			local added = Instance.new("Part")
			added.Parent = model
			expect(added.CollisionGroup).to.equal(CHARS)
			connection:Disconnect()
			model:Destroy()
		end)
	end)
end
