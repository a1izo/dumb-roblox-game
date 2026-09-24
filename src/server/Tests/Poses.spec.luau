-- Poses name only real R15 joints, keep their frames in order, and sample sensibly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local Assets = require(Shared:WaitForChild("Assets"))
local Config = require(Shared:WaitForChild("Config"))
local Poses = require(Anim:WaitForChild("Poses"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Poses", function()
		it("uses only known joints with frames in order", function()
			expect(#Poses.validate()).to.equal(0)
		end)
		it("has a pose for every cause of death", function()
			for _, cause in ipairs(Config.DEATH_CAUSES) do
				local id = Poses.FOR_CAUSE[cause]
				expect(id ~= nil).to.equal(true)
				expect(Poses.LIST[id] ~= nil).to.equal(true)
			end
		end)
		it("has an animation slot for every pose", function()
			for id in pairs(Poses.LIST) do
				expect(Assets.anim[id] ~= nil).to.equal(true)
			end
		end)
		it("holds the last frame of a pose that does not loop", function()
			local pose = Poses.LIST.raiseHand
			local angles = Poses.sample(pose, 10)
			expect(angles.rShoulder[1]).to.be.near(168, 0.001)
		end)
		it("loops a looping pose", function()
			local pose = Poses.LIST.write
			local length = Poses.length(pose)
			local a = Poses.sample(pose, 0.1)
			local b = Poses.sample(pose, 0.1 + length)
			expect(a.rWrist[3]).to.be.near(b.rWrist[3], 0.001)
		end)
	end)
end
