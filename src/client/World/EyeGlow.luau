--!strict
-- The red eyes of a stare, an Oculus read or the deal (the server's LEyesGlow on the character: two neon slivers and a
-- light, Services/CharacterService.glowEyes), lit properly on every screen (the owner, 2026-10-25: "make them glow
-- red"): a red glow round each eye drawn forward of the face, a hard star in it that flickers, and now and then a
-- spark of red drifting up off them. Gone with the slivers.

local Vfx = require(script.Parent.Parent.Presentation.Vfx)
local Characters = require(script.Parent.Parent.Characters)

local EyeGlow = {}

local RED = Color3.fromRGB(255, 40, 40)

local function light(holder: Instance)
	if not holder:IsA("Model") or holder.Name ~= "LEyesGlow" then
		return
	end
	task.defer(function()
		for _, eye in ipairs(holder:GetChildren()) do
			if eye:IsA("BasePart") then
				Vfx.Emit.make(eye, {
					tex = "VfxGlow",
					color = RED,
					size = { { 0, 1.1 }, { 0.5, 1.4 }, { 1, 1.1 } },
					alpha = { { 0, 1 }, { 0.1, 0.3 }, { 0.9, 0.3 }, { 1, 1 } },
					life = 0.8,
					rate = 3,
					locked = true,
					light = 1,
					bright = 1.6,
					z = 1,
				})
				Vfx.Emit.make(eye, {
					tex = "VfxFlare",
					color = Color3.fromRGB(255, 120, 110),
					size = { { 0, 0.55 }, { 0.5, 0.75 }, { 1, 0.55 } },
					alpha = { { 0, 1 }, { 0.1, 0.1 }, { 0.5, 0.35 }, { 0.6, 0.05 }, { 0.9, 0.2 }, { 1, 1 } },
					life = 0.45,
					rate = 5,
					rot = { 0, 45 },
					locked = true,
					light = 1,
					bright = 1.8,
					z = 1.1,
				})
				Vfx.Emit.make(eye, {
					tex = "VfxEmber",
					color = RED,
					size = { { 0, 0.08 }, { 1, 0 } },
					life = { 0.5, 0.9 },
					speed = { 0.6, 1.4 },
					spread = 30,
					accel = Vector3.new(0, 1.5, 0),
					bright = 1.6,
					rate = 4,
				})
			end
		end
	end)
end

function EyeGlow.init()
	Characters.each(function(character: Model)
		for _, child in ipairs(character:GetChildren()) do
			light(child)
		end
		character.ChildAdded:Connect(light)
	end)
end

return EyeGlow
