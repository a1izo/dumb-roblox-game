-- The Blender clips cover every animation the game asks for, and their keys are well formed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Clips = require(Anim:WaitForChild("Clips"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Joints = require(Anim:WaitForChild("Joints"))
local Poses = require(Anim:WaitForChild("Poses"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local REQUIRED = {
	"idle",
	"walk",
	"run",
	"jump",
	"fall",
	"land",
	"write",
	"taskWork",
	"raiseHand",
	"cuffed",
	"slump",
	"kneel",
	"laugh",
	"victory",
	"defeat",
	"specterFloat",
}

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Clips", function()
		it("has every clip the game plays", function()
			for _, id in ipairs(REQUIRED) do
				expect(ClipPlayer.exists(id)).to.equal(true)
			end
			for _, id in pairs(Poses.FOR_CAUSE) do
				expect(ClipPlayer.exists(id)).to.equal(true)
			end
			for _, emote in ipairs(QuickChat.EMOTES) do
				expect(ClipPlayer.exists(emote.id)).to.equal(true)
			end
			for _, item in ipairs(Cosmetics.ofKind("victory")) do
				expect(ClipPlayer.exists(item.pose)).to.equal(true)
			end
		end)
		it("uses known joints, rising times and unit quaternions", function()
			for id, clip in pairs(Clips) do
				for joint, track in pairs(clip.joints) do
					expect(Joints.R15[joint] ~= nil).to.equal(true)
					expect(#track.q).to.equal(#track.t * 4)
					for i = 2, #track.t do
						expect(track.t[i] > track.t[i - 1]).to.equal(true)
					end
					for i = 1, #track.t do
						local b = (i - 1) * 4
						local len =
							math.sqrt(track.q[b + 1] ^ 2 + track.q[b + 2] ^ 2 + track.q[b + 3] ^ 2 + track.q[b + 4] ^ 2)
						expect(len).to.be.near(1, 0.01)
					end
				end
				expect(clip.length > 0).to.equal(true)
				local sample = ClipPlayer.sample(ClipPlayer.get(id) :: any, clip.length * 0.5)
				expect(next(sample) ~= nil).to.equal(true)
			end
		end)
	end)
end
