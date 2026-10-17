-- The Blender clips cover every animation the game asks for, and their keys are well formed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Clips = require(Anim:WaitForChild("Clips"))
local Index = require(Anim:WaitForChild("Clips"):WaitForChild("Index")) :: any
local Joints = require(Anim:WaitForChild("Joints"))
local Causes = require(Anim:WaitForChild("Causes"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))
local RagdollService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("RagdollService"))

-- The movement set (art/scripts/locomotion.py): the eight cycles, standing, the air and the landings, starting
-- and stopping, flying, sitting, and the fidgets.
local CYCLES = {
	"walk",
	"walkBack",
	"walkLeft",
	"walkRight",
	"run",
	"runBack",
	"runLeft",
	"runRight",
}
local ADDITIVE = { "landLight", "landNormal", "landHeavy", "startStep" }
local REQUIRED = {
	"idle",
	"idleGuarded",
	"jump",
	"jumpApex",
	"fall",
	"fallLong",
	"stopRight",
	"stopLeft",
	"flyHover",
	"flyGlide",
	"flyRise",
	"flyDive",
	"sit",
	"idleLook",
	"idleWatch",
	"idleTie",
	"idleNeck",
	"idleSleeve",
	"idleHandsBack",
	"idleGlance",
	"idleArmsCross",
	"idleHand",
	"idleRoom",
	"write",
	"workCamera",
	"workFingerprint",
	"workPhone",
	"workForensics",
	"raiseHand",
	"cuffed",
	"slump",
	"specterFloat",
}

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Clips", function()
		it("has every clip the game plays", function()
			for _, list in ipairs({ REQUIRED, CYCLES, ADDITIVE }) do
				for _, id in ipairs(list) do
					expect(ClipPlayer.exists(id)).to.equal(true)
				end
			end
			for _, id in pairs(Causes.CLIP) do
				expect(ClipPlayer.exists(id)).to.equal(true)
			end
			for _, emote in ipairs(QuickChat.EMOTES) do
				expect(ClipPlayer.exists(emote.id)).to.equal(true)
			end
		end)
		it("indexes every clip with its part, length and loop", function()
			-- (the parts load lazily: the index is how the server and the menus know a clip)
			local count = 0
			for id, entry in pairs(Index) do
				count += 1
				local clip = Clips[id]
				expect(clip ~= nil).to.equal(true)
				expect(entry.length).to.be.near(clip.length, 1e-3)
				expect(entry.loop).to.equal(clip.loop == true)
			end
			expect(count > 100).to.equal(true)
		end)
		it("uses known joints, rising times and unit quaternions", function()
			for id in pairs(Index) do
				local clip = Clips[id]
				for joint, track in pairs(clip.joints) do
					expect(Joints.R6[joint] ~= nil).to.equal(true)
					expect(#track.q).to.equal(#track.t * 4)
					if track.p then
						expect(#track.p).to.equal(#track.t * 3)
					end
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
		it("gives every movement cycle the same ground travel, and each family one rhythm", function()
			-- Blended at one phase (LocomotionController), cycles keep their feet planted only if a body moves
			-- the same distance over each planted foot in all of them, and a family shares its length.
			local travel = nil
			local lengths: { [string]: number } = {}
			for _, id in ipairs(CYCLES) do
				local clip = ClipPlayer.get(id) :: any
				expect(clip.loop).to.equal(true)
				expect(type(clip.stride) == "number" and clip.stride > 0).to.equal(true)
				expect(type(clip.stance) == "number" and clip.stance > 0 and clip.stance < 1).to.equal(true)
				local t = clip.stride * clip.stance
				travel = travel or t
				expect(t).to.be.near(travel :: number, 0.02)
				local family = if string.sub(id, 1, 3) == "run" then "run" else "walk"
				lengths[family] = lengths[family] or clip.length
				expect(clip.length).to.be.near(lengths[family], 1e-3)
			end
			-- the run is the game's full speed
			local run = ClipPlayer.get("run") :: any
			expect(run.stride / run.length).to.be.near(16, 0.05)
		end)
		it("marks the landings and the first step as played on top of the pose", function()
			for _, id in ipairs(ADDITIVE) do
				expect((ClipPlayer.get(id) :: any).additive).to.equal(true)
			end
			expect((ClipPlayer.get("idle") :: any).additive).to.equal(false)
		end)
		it("lets every collapse play to its last frame before the body goes limp", function()
			-- The server locks the clip's last frame into the joints: earlier, every client would jump to it.
			for _, id in pairs(Causes.CLIP) do
				local limp = RagdollService.collapseTime(id)
				expect(limp >= ClipPlayer.length(id)).to.equal(true)
				expect(limp >= RagdollService.COLLAPSE_DELAY).to.equal(true)
			end
		end)
	end)
end
