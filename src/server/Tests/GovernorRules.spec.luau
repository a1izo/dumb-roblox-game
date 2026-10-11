-- The governor: when slow frames earn a cut, in what order, and that a round never gets its cuts back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GovernorRules = require(Shared:WaitForChild("GovernorRules"))
local LightingPresets = require(Shared:WaitForChild("LightingPresets"))

-- Runs `seconds` of frames at `rate` frames a second; returns how many cuts were made.
local function run(state: GovernorRules.State, rate: number, seconds: number): number
	local cuts = 0
	for _ = 1, math.floor(seconds * rate) do
		if GovernorRules.advance(state, 1 / rate) then
			cuts += 1
		end
	end
	return cuts
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("GovernorRules.advance", function()
		it("leaves a game that runs well alone", function()
			local state = GovernorRules.new()
			expect(run(state, 60, 120)).to.equal(0)
			expect(state.step).to.equal(0)
		end)
		it("does not judge the first seconds, nor a short stutter", function()
			local state = GovernorRules.new()
			expect(run(state, 12, GovernorRules.WARMUP - 1)).to.equal(0)
			run(state, 60, 20)
			expect(run(state, 12, GovernorRules.HOLD - 2)).to.equal(0)
			expect(run(state, 60, 5)).to.equal(0)
			expect(state.step).to.equal(0)
		end)
		it("cuts once after slow frames that last, then waits for the cut to show", function()
			local state = GovernorRules.new()
			run(state, 60, 20)
			expect(run(state, 20, GovernorRules.HOLD + 2)).to.equal(1)
			expect(state.step).to.equal(1)
			expect(run(state, 20, GovernorRules.SETTLE - 1)).to.equal(0)
		end)
		it("keeps cutting while it stays slow, and stops at the last cut", function()
			local state = GovernorRules.new()
			run(state, 60, 20)
			run(state, 15, 200)
			expect(state.step).to.equal(#GovernorRules.CUTS)
		end)
		it("never takes a cut back by itself", function()
			local state = GovernorRules.new()
			run(state, 60, 20)
			run(state, 20, 30)
			local step = state.step
			expect(step > 0).to.equal(true)
			run(state, 60, 120)
			expect(state.step).to.equal(step)
		end)
		it("does not call a device slow for running at its own cap", function()
			-- A phone that tops out at 30 frames a second is not slow at 28.
			local state = GovernorRules.new()
			run(state, 30, 30)
			expect(run(state, 28, 60)).to.equal(0)
			expect(run(state, 16, 20) > 0).to.equal(true)
		end)
		it("ignores a frame as long as a window left in the background", function()
			local state = GovernorRules.new()
			run(state, 60, 20)
			for _ = 1, 20 do
				expect(GovernorRules.advance(state, 3)).to.equal(false)
			end
			expect(state.step).to.equal(0)
		end)
	end)

	describe("GovernorRules.reset", function()
		it("gives a new round every effect back", function()
			local state = GovernorRules.new()
			run(state, 60, 20)
			run(state, 15, 60)
			expect(state.step > 0).to.equal(true)
			GovernorRules.reset(state)
			expect(state.step).to.equal(0)
			expect(run(state, 15, GovernorRules.WARMUP - 1)).to.equal(0)
		end)
	end)

	describe("GovernorRules.cut", function()
		it("cuts distant particles first and footprints last", function()
			expect(GovernorRules.CUTS[1]).to.equal("particles")
			expect(GovernorRules.CUTS[#GovernorRules.CUTS]).to.equal("prints")
			expect(GovernorRules.cut(0, "particles")).to.equal(false)
			expect(GovernorRules.cut(1, "particles")).to.equal(true)
			expect(GovernorRules.cut(1, "glow")).to.equal(false)
			expect(GovernorRules.cut(3, "shadows")).to.equal(true)
			expect(GovernorRules.cut(4, "prints")).to.equal(false)
			expect(GovernorRules.cut(5, "prints")).to.equal(true)
			expect(GovernorRules.cut(5, "signs")).to.equal(false)
		end)
	end)

	describe("LightingPresets.resolve under the governor", function()
		local agency = LightingPresets.pick("map", "TaskForceHQ")
		local full = LightingPresets.resolve(agency, LightingPresets.NEUTRAL)
		it("drops the glow and the haze without touching the shadows", function()
			local look = LightingPresets.resolve(agency, LightingPresets.NEUTRAL, { noGlow = true })
			expect(look.bloom).to.equal(0)
			expect(look.haze).to.equal(0)
			expect(look.keyLights).to.equal(full.keyLights)
			expect(look.rangeScale).to.be.near(full.rangeScale)
		end)
		it("drops shadow lamps without touching the glow", function()
			local look = LightingPresets.resolve(agency, LightingPresets.NEUTRAL, { fewShadows = true })
			expect(look.keyLights <= 2).to.equal(true)
			expect(look.bloom).to.be.near(full.bloom)
			expect(look.haze).to.be.near(full.haze)
		end)
		it("leaves the phase moods and the exposure alone", function()
			local grim = LightingPresets.resolve(agency, LightingPresets.moodFor("DeathNote"))
			local cut = LightingPresets.resolve(
				agency,
				LightingPresets.moodFor("DeathNote"),
				{ noGlow = true, fewShadows = true }
			)
			expect(cut.exposure).to.be.near(grim.exposure)
			expect(cut.tint).to.equal(grim.tint)
			expect(cut.vignette).to.be.near(grim.vignette)
		end)
	end)
end
