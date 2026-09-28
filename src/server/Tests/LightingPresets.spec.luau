-- The look: venue presets under phase moods, the vote's creeping red, Low graphics, and the
-- bloom threshold that keeps lit avatars from glowing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightingPresets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LightingPresets"))

local function redness(color: Color3): number
	return color.R - (color.G + color.B) / 2
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local agency = LightingPresets.pick("map", "TaskForceHQ")

	describe("LightingPresets.pick", function()
		it("finds each venue and falls back to Agency HQ for unknown maps", function()
			expect(LightingPresets.pick("lobby")).to.equal(LightingPresets.lobby)
			expect(LightingPresets.pick("meeting")).to.equal(LightingPresets.meeting)
			expect(LightingPresets.pick("map", "Nowhere")).to.equal(agency)
		end)
	end)

	describe("LightingPresets.resolve", function()
		it("keeps the venue's look in the investigation", function()
			local look = LightingPresets.resolve(agency, LightingPresets.moodFor("Investigation"))
			expect(look.exposure).to.be.near(agency.exposure)
			expect(look.keyScale).to.be.near(agency.lamps)
		end)
		it("takes the Grimoire phase near-black and red", function()
			local base = LightingPresets.resolve(agency, LightingPresets.NEUTRAL)
			local grim = LightingPresets.resolve(agency, LightingPresets.moodFor("DeathNote"))
			expect(grim.exposure < base.exposure).to.equal(true)
			expect(grim.fillScale < base.fillScale).to.equal(true)
			expect(redness(grim.tint) > redness(base.tint)).to.equal(true)
		end)
		it("gives the meeting a strong key light and dark edges", function()
			local look = LightingPresets.resolve(LightingPresets.meeting, LightingPresets.moodFor("Meeting"))
			expect(look.keyScale > 1).to.equal(true)
			expect(look.fillScale < 0.5).to.equal(true)
		end)
		it("lets red creep in over the vote", function()
			local vote = LightingPresets.moodFor("Vote")
			local early = LightingPresets.resolve(LightingPresets.meeting, vote, { progress = 0 })
			local late = LightingPresets.resolve(LightingPresets.meeting, vote, { progress = 1 })
			expect(redness(late.tint) > redness(early.tint)).to.equal(true)
			expect(late.exposure < early.exposure).to.equal(true)
		end)
		it("picks the ending's grade from the winning side", function()
			expect(LightingPresets.moodFor("Outro", "Kira")).to.equal(LightingPresets.moods.OutroHand)
			expect(LightingPresets.moodFor("Outro", "Team")).to.equal(LightingPresets.moods.OutroAgency)
		end)
		it("drops bloom and haze and most shadows on Low graphics", function()
			local look = LightingPresets.resolve(agency, LightingPresets.NEUTRAL, { low = true })
			expect(look.bloom).to.equal(0)
			expect(look.haze).to.equal(0)
			expect(look.keyLights <= 2).to.equal(true)
		end)
		it("keeps the rebuilt maps readable at night", function()
			-- Maps rebuilt at full size get a night you can see in (the moods still darken them).
			for _, mapId in ipairs({ "TokyoDistrict", "TaskForceHQ" }) do
				local p = LightingPresets.maps[mapId]
				local brightest = math.max(p.ambient.R, p.ambient.G, p.ambient.B)
				expect(p.exposure >= 0).to.equal(true)
				expect(brightest >= 45 / 255).to.equal(true)
				expect(p.density <= 0.3).to.equal(true)
				local grim = LightingPresets.resolve(p, LightingPresets.moodFor("DeathNote"))
				expect(grim.exposure < p.exposure).to.equal(true)
			end
		end)
		it("never lets bloom catch lit skin", function()
			for _, venue in ipairs({ "lobby", "meeting" }) do
				expect(LightingPresets.pick(venue).bloomThreshold >= 1.8).to.equal(true)
			end
			for _, p in pairs(LightingPresets.maps) do
				expect(p.bloomThreshold >= 1.8).to.equal(true)
			end
		end)
	end)
end
