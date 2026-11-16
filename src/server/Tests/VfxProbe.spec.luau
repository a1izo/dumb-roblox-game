-- The effect probe's judging (Presentation/Vfx/Probe, the VFX rework's ticket V0.5): the bar of the plan's Part 3 and the
-- budgets of its Part 9, read from recorded rows. Pure data: rows made up here, with answers known, are judged; nothing is
-- played (the booth's report, FxBooth.report, plays real effects and needs Studio).

local StarterPlayer = game:GetService("StarterPlayer")

-- The probe module, from the client's scripts (nil where the place has none: a bundle of server specs only).
local function probeModule(): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, name in ipairs({ "Client", "Presentation", "Vfx", "Probe" }) do
		node = if node then node:FindFirstChild(name) else nil
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

-- A made-up row: a burst of a shaped texture that is born clear and leaves clear, unless the test says otherwise.
local function row(over: { [string]: any }?): { [string]: any }
	local made: { [string]: any } = {
		t = 0,
		kind = "burst",
		manual = false,
		name = "",
		tex = "VfxRing",
		rate = 0,
		count = 10,
		want = 10,
		size = 4,
		size0 = 1,
		size1 = 0,
		life = 1.2,
		lifeMin = 0.8,
		bright = 1,
		light = 0,
		a0 = 1,
		a1 = 1,
		particle = true,
	}
	for key, value in pairs(over or {}) do
		made[key] = value
	end
	return made
end

local function flash(at: number, seconds: number): { [string]: any }
	return row({
		t = at,
		kind = "light",
		tex = "",
		count = nil,
		want = nil,
		life = seconds,
		lifeMin = seconds,
		bright = 2,
		light = 1,
	})
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local module = probeModule()
	if not module then
		-- (nothing to read here: the spec runs in a place that carries the client's scripts)
		return
	end
	local ok, Probe = pcall(require, module)

	describe("Effect probe", function()
		it("loads on the server and is off by default", function()
			expect(ok).to.equal(true)
			if ok then
				expect(Probe.on).to.equal(false)
			end
		end)
		if not ok then
			return
		end

		local function judge(rows: { any }, meta: { [string]: any })
			local base = { hit = 1, length = 3, tier = "free", budget = "showpiece", endT = 3.5 }
			for key, value in pairs(meta) do
				base[key] = value
			end
			return Probe.judge(rows, base)
		end

		-- A well made effect: a gather, a hit that is the biggest and brightest, a dark layer behind it, residue, a light.
		local function good(): { any }
			return {
				row({ t = 0.7, tex = "VfxRing", size = 3 }),
				row({ t = 1, tex = "VfxBurst", size = 6, bright = 3, light = 1 }),
				row({ t = 1, tex = "VfxSmoke", size = 5, light = 0, life = 2.5, lifeMin = 2 }),
				row({ t = 1, tex = "VfxGlow", size = 2, light = 1 }),
				row({ t = 1, kind = "light", tex = "", count = nil, want = nil, life = 0.6, lifeMin = 0.6, bright = 2 }),
			}
		end

		it("passes an effect that meets the bar", function()
			local verdict = judge(good(), { tier = "sealed" })
			expect(table.concat(verdict.fails, "; ")).to.equal("")
			expect(verdict.pass).to.equal(true)
			expect(verdict.stats.layers).to.equal(4)
			expect(verdict.stats.lightOnBeat).to.equal(true)
		end)

		it("fails an effect with nothing recorded", function()
			local verdict = judge({}, {})
			expect(verdict.pass).to.equal(false)
			expect(table.concat(verdict.fails, "; ")).to.contain("nothing recorded")
		end)

		it("fails plain dots: over half the layers, and no shaped layer", function()
			local rows = {
				row({ t = 0.7, tex = "VfxGlow" }),
				row({ t = 1, tex = "VfxEmber", size = 6, bright = 3, light = 0, life = 2.5 }),
				row({ t = 1, tex = "AuraTwinkle", size = 2 }),
			}
			local text = table.concat(judge(rows, {}).fails, "; ")
			expect(text).to.contain("dots 3 of 3 layers")
			expect(text).to.contain("no layer with a shaped texture or mesh")
		end)

		it("lets plain sprites support when most of the layers are shaped", function()
			local verdict = judge(good(), {})
			expect(verdict.stats.dots).to.equal(1)
			expect(verdict.stats.shaped).to.equal(3)
			expect(table.concat(verdict.fails, "; ")).to.equal("")
		end)

		it("counts a solid shape as shaped", function()
			local rows = good()
			rows[2] =
				row({ t = 1, kind = "shape", tex = "shape:ring", size = 6, bright = 3, light = 1, particle = false })
			local verdict = judge(rows, {})
			expect(table.concat(verdict.fails, "; ")).to.equal("")
		end)

		it("fails an effect with no gather", function()
			local rows = good()
			table.remove(rows, 1)
			expect(table.concat(judge(rows, {}).fails, "; ")).to.contain("no gather")
		end)

		it("fails a biggest layer that starts off the hit", function()
			local rows = good()
			rows[2].t = 1.5
			expect(table.concat(judge(rows, {}).fails, "; ")).to.contain("starts 0.50 s off the hit")
		end)

		it("fails an effect with nothing left a second after the hit", function()
			local rows = good()
			for _, r in ipairs(rows) do
				r.life, r.lifeMin = 0.8, 0.5 -- (all gone by 1.8 s: the hit is at 1)
			end
			expect(table.concat(judge(rows, {}).fails, "; ")).to.contain("no residue")
		end)

		it("fails a particle that pops in", function()
			local rows = good()
			rows[3] = row({ t = 1, tex = "VfxSmoke", size = 5, size0 = 4, a0 = 0, light = 0, life = 2.5, lifeMin = 2 })
			expect(table.concat(judge(rows, {}).fails, "; ")).to.contain("pops in: VfxSmoke")
		end)

		it("lets a short particle start solid", function()
			local rows = good()
			rows[3] =
				row({ t = 1, tex = "VfxSmoke", size = 5, size0 = 4, a0 = 0, light = 0, life = 0.5, lifeMin = 0.4 })
			rows[4] = row({ t = 1, tex = "VfxGlow", size = 2, life = 2.5, lifeMin = 2 })
			expect(table.concat(judge(rows, {}).fails, "; ")).to.equal("")
		end)

		it("fails a particle that pops out: dies still visible and not shrunk", function()
			local rows = good()
			rows[3] =
				row({ t = 1, tex = "VfxSmoke", size = 5, size1 = 4, a1 = 0.3, light = 0, life = 2.5, lifeMin = 2 })
			expect(table.concat(judge(rows, {}).fails, "; ")).to.contain("pops out: VfxSmoke")
		end)

		it("lets a particle leave by shrinking to nothing, or by fading out", function()
			local rows = good()
			rows[3] = row({ t = 1, tex = "VfxSmoke", size = 5, size1 = 0, a1 = 0, light = 0, life = 2.5, lifeMin = 2 })
			rows[4] = row({ t = 1, tex = "VfxGlow", size = 2, size1 = 2, a1 = 0.95, life = 2.5, lifeMin = 2 })
			expect(table.concat(judge(rows, {}).fails, "; ")).to.equal("")
		end)

		it("fails an effect over 3 studs with no dark layer, and one with no core", function()
			local rows = good()
			for _, r in ipairs(rows) do
				r.light = 1
				r.bright = 1
			end
			local text = table.concat(judge(rows, {}).fails, "; ")
			expect(text).to.contain("no dark layer")
			expect(text).to.contain("no core")
		end)

		it("asks for no dark layer from a small effect", function()
			local rows = {
				row({ t = 0.7, tex = "VfxRing", size = 1 }),
				row({ t = 1, tex = "VfxBurst", size = 2, bright = 3, light = 1, life = 2.5, lifeMin = 2 }),
			}
			expect(table.concat(judge(rows, {}).fails, "; ")).to.equal("")
		end)

		it("wants a light on the beat from sealed up, and not from penned", function()
			local rows = good()
			table.remove(rows, 5)
			expect(table.concat(judge(rows, { tier = "sealed" }).fails, "; ")).to.contain("no light on the beat")
			expect(table.concat(judge(rows, { tier = "godhood" }).fails, "; ")).to.contain("no light on the beat")
			expect(table.concat(judge(rows, { tier = "penned" }).fails, "; ")).to.equal("")
			local late = good()
			late[5].t = 2
			expect(table.concat(judge(late, { tier = "sealed" }).fails, "; ")).to.contain("no light on the beat")
		end)

		it("counts a light that holds from before the beat as on it", function()
			local rows = good()
			rows[5] =
				row({ t = 0.2, kind = "light", tex = "", count = nil, want = nil, life = 0, lifeMin = 0, bright = 2 })
			expect(judge(rows, { tier = "sealed" }).stats.lightOnBeat).to.equal(true)
			rows[5].cut = 0.5 -- (gone before the hit)
			expect(judge(rows, { tier = "sealed" }).stats.lightOnBeat).to.equal(false)
		end)

		it("reads the particles alive at peak from a burst and from a rate", function()
			local rows = good()
			rows[2].want, rows[2].count = 40, 12 -- (designed at 100%: 40 were asked for)
			table.insert(
				rows,
				row({ t = 0, kind = "emit", tex = "VfxDust", rate = 30, life = 1, lifeMin = 1, size = 2 })
			)
			local verdict = judge(rows, { budget = "scene" })
			-- (the rate's steady 30 alive, the bursts' 10 + 40 + 10 + 10 while they last)
			expect(verdict.stats.peakParticles).to.equal(100)
			expect(verdict.stats.peakEmitters).to.equal(5)
		end)

		it("fails an effect over its budget: particles, big sprites, emitters and lights", function()
			local rows = good()
			rows[2].want = 400
			for _ = 1, 3 do
				table.insert(rows, row({ t = 1, tex = "VfxSmoke", size = 9, count = 1, want = 1, light = 0, life = 2 }))
			end
			local text = table.concat(judge(rows, { budget = "accent" }).fails, "; ")
			expect(text).to.contain("particles alive (budget 60)")
			expect(text).to.contain("big sprites alive (budget 2)")
			for k = 1, 9 do
				table.insert(rows, row({ t = 1, tex = "VfxChunk", size = 1, count = 1, want = 1 + k, life = 2 + k }))
			end
			table.insert(rows, flash(1, 1))
			table.insert(rows, flash(1, 1))
			local more = table.concat(judge(rows, { budget = "accent" }).fails, "; ")
			expect(more).to.contain("emitters alive (budget 6)")
			expect(more).to.contain("lights alive (budget 1)")
		end)

		it("folds a look that repeats into one layer", function()
			local rows = good()
			for k = 1, 4 do
				table.insert(rows, row({ t = 1 + k * 0.1, tex = "VfxChunk", size = 1 }))
			end
			expect(judge(rows, {}).stats.layers).to.equal(5)
		end)

		it("says how many layers were emitted by hand, and does not count their particles", function()
			local rows = good()
			table.insert(rows, row({ t = 1, tex = "VfxChunk", size = 1, count = nil, want = nil, manual = true }))
			local verdict = judge(rows, {})
			expect(verdict.stats.unseen).to.equal(1)
			expect(verdict.notes[1]).to.contain("emitted by hand")
		end)

		it("judges a loop by its ignition and its layers", function()
			local rows = {
				row({ t = 0, kind = "emit", tex = "VfxFlame", rate = 10, life = 1, lifeMin = 1, size = 2, bright = 2 }),
				row({ t = 0, kind = "emit", tex = "VfxSmoke", rate = 5, life = 2, lifeMin = 1, size = 4, light = 0 }),
				row({ t = 0, kind = "emit", tex = "VfxEmber", rate = 4, life = 2, lifeMin = 1, size = 0.5 }),
			}
			local text = table.concat(judge(rows, { loop = true, tier = "free" }).fails, "; ")
			expect(text).to.contain("no ignition burst")
			expect(text).to.contain("3 layers (a loop needs 4)")
			table.insert(rows, row({ t = 0.1, tex = "VfxBurst", size = 3 }))
			table.insert(
				rows,
				row({ t = 0, kind = "emit", tex = "VfxWisp", rate = 3, life = 2, lifeMin = 1, size = 2 })
			)
			local verdict = judge(rows, { loop = true, tier = "free" })
			expect(table.concat(verdict.fails, "; ")).to.equal("")
		end)

		it("makes a one-line report", function()
			local line = Probe.line("recipe_test", judge(good(), { tier = "sealed" }))
			expect(string.sub(line, 1, 21)).to.equal("[FxReport] PASS recip")
			local bad = Probe.line("recipe_test", judge({}, {}))
			expect(bad).to.contain("FAIL recipe_test")
			expect(bad).to.contain("nothing recorded")
		end)
	end)
end
