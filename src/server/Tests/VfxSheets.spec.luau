-- The VFX kit's flipbook rules (Presentation/Vfx/Sheets): a one-shot sheet's rate comes from the life, a random sheet holds one
-- cell, a new name plays by its declared mode only once its picture is in the place (before that it plays as the old texture
-- it wears), and the old names play exactly as they always have. Pure data: no emitter is made.

local StarterPlayer = game:GetService("StarterPlayer")

local function kitModule(name: string): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, part in ipairs({ "Client", "Presentation", "Vfx", name }) do
		node = if node then node:FindFirstChild(part) else nil
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local module = kitModule("Sheets")
	if not module then
		return
	end
	local ok, Sheets = pcall(require, module)
	local fallback =
		{ VfxSmokePuff = "VfxSmoke", VfxShards = "VfxChunk", VfxSparks = "VfxStreak", VfxImpactA = "VfxBurst" }

	describe("Flipbook sheets", function()
		it("loads on the server", function()
			expect(ok).to.equal(true)
		end)
		if not ok then
			return
		end

		it("plays a real one-shot at the rate that lands its last frame at the death", function()
			local plan = Sheets.plan({ tex = "VfxSmokePuff", life = 2 }, true, fallback)
			expect(plan.grid).to.equal(8)
			expect(plan.mode).to.equal("OneShot")
			expect(plan.fps).to.equal(32)
			expect(plan.startRandom).to.equal(false)
		end)

		it("takes the shortest life of a range", function()
			local plan = Sheets.plan({ tex = "VfxImpactA", life = { 0.5, 1 } }, true, fallback)
			expect(plan.grid).to.equal(4)
			expect(plan.fps).to.equal(32)
		end)

		it("lets a spec's own rate stand", function()
			local plan = Sheets.plan({ tex = "VfxSmokePuff", life = 2, fps = 10 }, true, fallback)
			expect(plan.fps).to.equal(10)
		end)

		it("loops a loop sheet from a random frame", function()
			local plan = Sheets.plan({ tex = "VfxFire" }, true, fallback)
			expect(plan.mode).to.equal("Loop")
			expect(plan.grid).to.equal(8)
			expect(plan.fps).to.equal(30)
			expect(plan.startRandom).to.equal(true)
		end)

		it("holds one random cell for a random sheet, and for variants = true", function()
			local sparks = Sheets.plan({ tex = "VfxSparks" }, true, fallback)
			expect(sparks.grid).to.equal(2)
			expect(sparks.fps).to.equal(0)
			expect(sparks.startRandom).to.equal(true)
			local fire = Sheets.plan({ tex = "VfxFire", variants = true }, true, fallback)
			expect(fire.fps).to.equal(0)
			expect(fire.startRandom).to.equal(true)
		end)

		it("plays a new name as the old texture's own sheet while its picture is missing", function()
			local plan = Sheets.plan({ tex = "VfxSmokePuff", life = 2, grid = 4 }, false, fallback)
			expect(plan.grid).to.equal(8) -- VfxSmoke's
			expect(plan.mode).to.equal("Loop")
			expect(plan.fps).to.equal(24)
			local chunk = Sheets.plan({ tex = "VfxShards" }, false, fallback)
			expect(chunk.grid).to.equal(2) -- VfxChunk's
		end)

		it("gives no flipbook to a missing new name whose stand-in is a single picture", function()
			expect(Sheets.plan({ tex = "VfxImpactA" }, false, fallback)).to.equal(nil)
			expect(Sheets.plan({ tex = "VfxSparks" }, false, fallback)).to.equal(nil)
		end)

		it("keeps the old names as they were", function()
			local smoke = Sheets.plan({ tex = "VfxSmoke" }, true, fallback)
			expect(smoke.grid).to.equal(8)
			expect(smoke.mode).to.equal("Loop")
			expect(smoke.fps).to.equal(24)
			expect(smoke.startRandom).to.equal(true)
			local explicit = Sheets.plan({ tex = "VfxSmoke", grid = 4, mode = "OneShot", fps = 8 }, true, fallback)
			expect(explicit.grid).to.equal(4)
			expect(explicit.mode).to.equal("OneShot")
			expect(explicit.fps).to.equal(8)
			expect(explicit.startRandom).to.equal(false)
			expect(Sheets.plan({ tex = "VfxBurst" }, true, fallback)).to.equal(nil)
		end)
	end)
end
