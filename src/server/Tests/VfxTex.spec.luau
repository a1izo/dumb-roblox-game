-- The VFX kit's texture names (Presentation/Vfx/Tex): every name of the new library has an old-name fallback, so the
-- live place shows an old texture, never a sparkle, while it has only the Fx props file ModelsFx 3. Data only: nothing is
-- drawn. The module is read from the client's scripts (nil where the place has none: a bundle of server specs only).

local StarterPlayer = game:GetService("StarterPlayer")

local function texModule(): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, name in ipairs({ "Client", "Presentation", "Vfx", "Tex" }) do
		node = if node then node:FindFirstChild(name) else nil
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

-- The 23 names ModelsFx 3 carries as Tex_<name> quads (art/scripts/vfx/meshes.py, before V1.7's closing half).
local OLD = {
	"VfxFlame",
	"VfxCandleFlame",
	"VfxGlow",
	"VfxFlare",
	"VfxEmber",
	"VfxStreak",
	"VfxSpike",
	"VfxBurst",
	"VfxRing",
	"VfxRingBand",
	"VfxColumn",
	"VfxSlash",
	"VfxSlashBand",
	"VfxWisp",
	"VfxDust",
	"VfxSmoke",
	"VfxCrack",
	"VfxCircle",
	"VfxPage",
	"VfxFeather",
	"VfxMoth",
	"VfxChunk",
	"VfxAsh",
}

-- The 22 names ModelsFx 4 adds (V1.1 to V1.6).
local NEW = {
	"VfxSmokePuff",
	"VfxSmokePlume",
	"VfxDustRoll",
	"VfxMist",
	"VfxImpactA",
	"VfxImpactB",
	"VfxImpactC",
	"VfxShock",
	"VfxGlint",
	"VfxSparks",
	"VfxSlashA",
	"VfxSlashB",
	"VfxArc",
	"VfxEnergyWisp",
	"VfxAshFlakes",
	"VfxShards",
	"VfxPaper",
	"VfxFeatherTumble",
	"VfxCrackA",
	"VfxCrackB",
	"VfxScorch",
	"VfxSigil",
}

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local module = texModule()
	if not module then
		return
	end
	local ok, Tex = pcall(require, module)

	describe("VFX texture names", function()
		it("loads on the server", function()
			expect(ok).to.equal(true)
		end)
		if not ok then
			return
		end

		local old: { [string]: boolean } = {}
		for _, name in ipairs(OLD) do
			old[name] = true
		end
		local fallback = Tex.FALLBACK

		it("gives every new name a fallback that is an old name", function()
			for _, name in ipairs(NEW) do
				local target = fallback[name]
				expect(type(target)).to.equal("string")
				expect(old[target] == true).to.equal(true)
			end
		end)

		it("has a fallback for no name but the new ones, and none for an old name", function()
			local isNew: { [string]: boolean } = {}
			for _, name in ipairs(NEW) do
				isNew[name] = true
			end
			for name in pairs(fallback) do
				expect(isNew[name] == true).to.equal(true)
				expect(old[name] == nil).to.equal(true)
			end
		end)

		it("answers a texture id for every old and new name", function()
			for _, name in ipairs(OLD) do
				expect(type(Tex.id(name))).to.equal("string")
				expect(Tex.id(name) ~= "").to.equal(true)
			end
			for _, name in ipairs(NEW) do
				expect(type(Tex.id(name))).to.equal("string")
				expect(Tex.id(name) ~= "").to.equal(true)
			end
		end)
	end)
end
