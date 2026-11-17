-- The VFX kit's colour ramps (Presentation/Vfx/Palette): a ramp expands to three keypoints, white-hot first; the shop's ramps
-- are full colour (the edge a deeper shade of the same hue, never a grey); the world's keep to the greys. Pure data: no emitter
-- is made.

local StarterPlayer = game:GetService("StarterPlayer")

local function kitModule(name: string): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, part in ipairs({ "Client", "Presentation", "Vfx", name }) do
		node = if node then node:FindFirstChild(part) else nil
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

local TIERS = { "common", "rare", "epic", "legendary", "godhood" }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local module = kitModule("Palette")
	if not module then
		return
	end
	local ok, Palette = pcall(require, module)

	describe("Colour ramps", function()
		it("loads on the server", function()
			expect(ok).to.equal(true)
		end)
		if not ok then
			return
		end

		local function brightness(c: Color3): number
			return (c.R + c.G + c.B) / 3
		end

		it("expands to three keypoints: the core at birth, the body in the middle, the edge at death", function()
			local core, body, edge = Color3.new(1, 1, 1), Color3.new(1, 0.5, 0), Color3.new(0.3, 0.1, 0)
			local keys = Palette.sequence({ core, body, edge }).Keypoints
			expect(#keys).to.equal(3)
			expect(keys[1].Time).to.equal(0)
			expect(keys[1].Value).to.equal(core)
			expect(keys[2].Time).to.equal(0.5)
			expect(keys[2].Value).to.equal(body)
			expect(keys[3].Time).to.equal(1)
			expect(keys[3].Value).to.equal(edge)
		end)

		it(
			"makes a shop ramp white-hot at its core, the item's own colour as its body, and darker at the edge",
			function()
				local orange = Color3.fromRGB(230, 120, 30)
				local ramp = Palette.shop(orange)
				expect(ramp[2]).to.equal(orange)
				expect(brightness(ramp[1]) > 0.85).to.equal(true)
				expect(brightness(ramp[3]) < brightness(orange)).to.equal(true)
			end
		)

		it("keeps the edge of a coloured shop ramp the same hue and as saturated, never a grey", function()
			local blue = Color3.fromRGB(80, 140, 230)
			local h0, s0 = blue:ToHSV()
			local h1, s1 = Palette.shop(blue)[3]:ToHSV()
			expect(math.abs(h1 - h0) < 0.02).to.equal(true)
			expect(s1 >= s0).to.equal(true)
		end)

		it("gives every rarity tier a full-colour ramp, and an unknown id the first tier's", function()
			for _, id in ipairs(TIERS) do
				local ramp = Palette.rarity(id)
				expect(#ramp).to.equal(3)
				expect(brightness(ramp[1]) > brightness(ramp[2])).to.equal(true)
				expect(brightness(ramp[3]) < brightness(ramp[2])).to.equal(true)
			end
			for _, id in ipairs({ "epic", "legendary", "godhood" }) do
				local _, s = Palette.rarity(id)[3]:ToHSV()
				expect(s > 0.3).to.equal(true)
			end
			expect(Palette.rarity("nonsense")[2]).to.equal(Palette.rarity("common")[2])
		end)

		it("keeps the world's ramps to greys and the danger ramp to red", function()
			for _, ramp in pairs(Palette.WORLD) do
				expect(#ramp).to.equal(3)
				expect(brightness(ramp[1]) > brightness(ramp[3])).to.equal(true)
				for _, colour in ipairs(ramp) do
					local _, s = colour:ToHSV()
					expect(s < 0.2).to.equal(true)
				end
			end
			local danger = Palette.DANGER
			expect(danger[2].R > danger[2].G * 3).to.equal(true)
			expect(danger[3].R > danger[3].G).to.equal(true)
		end)

		it("gives an emote its own colour as the body and its accent as the core", function()
			local ramp = Palette.emote("menacingPose4")
			expect(ramp ~= nil).to.equal(true)
			if ramp then
				expect(ramp[2]).to.equal(Color3.fromRGB(196, 24, 44))
				expect(ramp[1]).to.equal(Color3.fromRGB(255, 170, 170))
				expect(brightness(ramp[3]) < brightness(ramp[2])).to.equal(true)
			end
			expect(Palette.emote("noSuchEmote")).to.equal(nil)
		end)
	end)
end
