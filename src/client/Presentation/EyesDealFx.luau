-- The Oculus deal's two effect moments (split out of Presenters/EyesDeal so the booth can play them alone): the
-- Deathsinger's eyes lit in the dark before the rest of it, and your own eyes taking fire. The old builds are below;
-- with Pilot.on.eyesDealEyes / eyesDealIgnite on, the glints and the ring come from the new kit (Vfx/Fresh/Gameplay).

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Vfx = require(script.Parent.Vfx)
local Fresh = require(script.Parent.Vfx.Fresh)
local Pilot = require(script.Parent.Vfx.Pilot)

local RED = Color3.fromRGB(230, 30, 45)

local EyesDealFx = {}

-- Its eyes, lit before the rest of it: two red glints high in the dark.
function EyesDealFx.eyesOf(specter: Model)
	local cf, size = specter:GetBoundingBox()
	local head = cf.Position + Vector3.new(0, size.Y * 0.38, 0) + cf.LookVector * size.Z * 0.35
	if Pilot.on.eyesDealEyes then
		-- (stage 4d: a hard glint in each eye on the new kit; Pilot.on.eyesDealEyes = false brings the old flares back)
		Fresh.Gameplay.eyesOf({ head + cf.RightVector * -0.35, head + cf.RightVector * 0.35 })
		return
	end
	for _, side in ipairs({ -0.35, 0.35 }) do
		Vfx.Emit.burst(head + cf.RightVector * side, {
			tex = "VfxFlare",
			color = RED,
			size = { { 0, 0.2 }, { 0.3, 1.6 }, { 1, 0 } },
			life = 0.9,
			rot = { 0, 45 },
			bright = 1.8,
			z = 2,
		}, 1)
	end
end

-- Your eyes taking fire: a red star in each, a ring of red out from your face, arcs crawling round your head.
function EyesDealFx.ignite(body: Model)
	local head = body:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local still = Motion.isReduced()
	if Pilot.on.eyesDealIgnite then
		-- (stage 4d: a glint in each eye and the ring with sparks on the new kit; the arcs, flash and light below stay)
		local eyes = {}
		for _, side in ipairs({ -0.2, 0.2 }) do
			table.insert(eyes, (head.CFrame * CFrame.new(side, 0.12, -0.6)).Position)
		end
		Fresh.Gameplay.eyesIgnite(eyes, head.Position)
	else
		for _, side in ipairs({ -0.2, 0.2 }) do
			Vfx.Emit.burst((head.CFrame * CFrame.new(side, 0.12, -0.6)).Position, {
				{
					{
						tex = "VfxFlare",
						color = Color3.fromRGB(255, 120, 110),
						size = { { 0, 0.3 }, { 0.2, 2.6 }, { 1, 0.6 } },
						life = 0.8,
						rot = { 0, 45 },
						spin = 60,
						bright = 2,
						z = 1.5,
					},
					1,
				},
				{
					{
						tex = "VfxEmber",
						color = RED,
						size = { { 0, 0.12 }, { 1, 0 } },
						life = { 0.5, 1 },
						speed = { 1, 3 },
						spread = 60,
						bright = 1.6,
					},
					8,
				},
			})
		end
		Vfx.Emit.burst(head.Position, {
			tex = "VfxRing",
			color = RED,
			size = { { 0, 0.5 }, { 1, 9 } },
			alpha = { { 0, 0.1 }, { 0.6, 0.5 }, { 1, 1 } },
			life = 0.5,
			light = 0.8,
			bright = 1.3,
		}, 1)
	end
	if not still then
		for k = 1, 4 do
			Vfx.Clock.after(k * 0.12, function()
				local a = math.random() * math.pi * 2
				local from = head.Position
					+ Vector3.new(math.cos(a) * 1.2, math.random() * 1.2 - 0.3, math.sin(a) * 1.2)
				local to = head.Position
					+ Vector3.new(math.cos(a + 2) * 1.4, math.random() * 1.6 - 0.6, math.sin(a + 2) * 1.4)
				Vfx.Beams.bolt(from, to, 0.16, {
					color = Color3.fromRGB(255, 70, 80),
					width = 0.3,
					bright = 1.8,
					light = 1,
					pieces = 6,
					jag = 0.35,
					rate = 30,
				})
			end)
		end
		Vfx.Screen.flash(RED, 0.35, 0.4)
	end
	Vfx.Light.flash(head.Position, RED, 14, 5, 0.8)
end

return EyesDealFx
