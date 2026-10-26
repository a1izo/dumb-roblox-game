-- The Oculus deal, seen only by the Muerto who took it (2026-10-25, the owner: "make a cutscene for when you make a
-- deal to get the shinigami eyes"): the world drains to red and the camera comes round to your face; the Deathsinger
-- is drawn together out of smoke behind you, its eyes lit first; from low over its shoulder it leans down over you;
-- then close on your face as your eyes take fire, red arcs crawling round your head; it comes apart into smoke and
-- feathers as the terms of the deal are written up. Nobody else gets this cue, and the Deathsinger exists only on this
-- screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local Mixer = require(script.Parent.Parent.Parent.Audio.Mixer)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local Materialize = require(script.Parent.Parent.Materialize)
local ShotSolver = require(script.Parent.Parent.ShotSolver)
local StageLight = require(script.Parent.Parent.StageLight)
local Vfx = require(script.Parent.Parent.Vfx)

local C = Kit.color
local LocalPlayer = Players.LocalPlayer

local RED = Color3.fromRGB(230, 30, 45)
local LENGTH = 7.2

-- The Deathsinger standing behind `body`, looking down over it.
local function summon(body: Model): Model
	local specter = Models.specter()
	local root = body:GetPivot()
	local behind = root * CFrame.new(0.6, 0, 2.6)
	local ground = ShotSolver.floor(behind.Position + Vector3.new(0, 2, 0), { body })
	local _, size = specter:GetBoundingBox()
	-- (taller than any player: scaled to about one and a half heights)
	local scale = math.clamp(8.5 / math.max(size.Y, 0.1), 0.4, 3)
	specter:ScaleTo(specter:GetScale() * scale)
	specter:PivotTo(CFrame.lookAt(ground, ground + root.LookVector))
	-- (its feet on the floor whatever its pivot: by its box)
	local box, extent = specter:GetBoundingBox()
	specter:PivotTo(specter:GetPivot() + Vector3.new(0, ground.Y - (box.Position.Y - extent.Y / 2), 0))
	specter.Parent = workspace.CurrentCamera
	return specter
end

-- Its eyes, lit before the rest of it: two red glints high in the dark.
local function eyesOf(specter: Model)
	local cf, size = specter:GetBoundingBox()
	local head = cf.Position + Vector3.new(0, size.Y * 0.38, 0) + cf.LookVector * size.Z * 0.35
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
local function ignite(body: Model)
	local head = body:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local still = Motion.isReduced()
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

return function(cue)
	local data = cue.data
	Cinema.waitUntil(cue.at)
	local body = LocalPlayer.Character
	if not body or not body:FindFirstChild("Head") then
		return
	end
	Mixer.duck("eyes", true)
	Sfx.play("eyesOpen")
	local token = CameraDirector.take(LENGTH + 0.5)
	Cinema.letterbox(true)
	local untint = Cinema.tint({ TintColor = Color3.fromRGB(255, 165, 165), Saturation = -0.55, Contrast = 0.25 }, 0.6)
	local removeVignette = Cinema.vignette(C.red, 0.45)
	-- (the lamps round you falter and sink while the deal is made)
	local undip = StageLight.dip(body:GetPivot().Position, 45, 0.25, LENGTH)
	local ignore = { body }

	-- 1. Your face, the world draining red; behind you it is drawn together out of smoke, its eyes first.
	local specter = summon(body)
	-- (from in front, a little low, looking up past your face to where its head will be)
	local pivot = body:GetPivot()
	local headY = (body:FindFirstChild("Head") :: BasePart).Position.Y
	local _, godSize = specter:GetBoundingBox()
	local aim = pivot.Position + Vector3.new(0, (headY - pivot.Position.Y) + godSize.Y * 0.18, 0)
	local near =
		CFrame.lookAt(pivot.Position + pivot.LookVector * 9 + pivot.RightVector * 2 + Vector3.new(0, 0.6, 0), aim)
	local closer =
		CFrame.lookAt(pivot.Position + pivot.LookVector * 7 + pivot.RightVector * 1.4 + Vector3.new(0, 0.4, 0), aim)
	CameraDirector.cut(token, near, 52)
	CameraDirector.move(token, closer, 2.2, 48)
	Materialize.appear(specter, { seconds = 1.9, color = RED, quiet = false })
	-- (keep it unseen until the smoke has gathered: Materialize starts it unseen)
	task.wait(0.35)
	eyesOf(specter)
	task.wait(1.85)

	-- 2. Low over its shoulder: it leans down over you.
	local cf, size = specter:GetBoundingBox()
	local shoulder = cf.Position
		+ cf.RightVector * (size.X * 0.5 + 1.5)
		+ Vector3.new(0, size.Y * 0.3, 0)
		- cf.LookVector * (size.Z * 0.5 + 4)
	local overShoulder = CFrame.lookAt(shoulder, body:GetPivot().Position + Vector3.new(0, 1, 0))
	CameraDirector.cut(token, overShoulder, 55)
	local start = specter:GetPivot()
	Vfx.Clock.tween(1.4, Vfx.Ease.inOutSine, function(u)
		if specter.Parent then
			specter:PivotTo(start * CFrame.new(0, -0.2 * u, -0.9 * u) * CFrame.Angles(math.rad(-10 * u), 0, 0))
		end
	end)
	Sfx.play("hauntWhisper")
	task.wait(1.5)

	-- 3. Close on your face: your eyes take fire.
	local face = ShotSolver.frame(body, { distance = 2.4, height = 0.15, angle = 0 }, ignore)
	CameraDirector.cut(token, face, 40)
	task.wait(0.25)
	ignite(body)
	task.wait(1.5)

	-- 4. Wide again: it comes apart into smoke and feathers, and the terms are written.
	local wide = ShotSolver.frame(body, { distance = 9, height = 2.4, angle = 30 }, ignore)
	CameraDirector.cut(token, wide, 52)
	Materialize.vanish(specter, { seconds = 1.1, color = RED, destroy = true })
	local fcf = specter:GetBoundingBox()
	Vfx.Emit.burst(fcf.Position, {
		tex = "VfxFeather",
		color = Color3.fromRGB(16, 14, 18),
		light = 0,
		lit = 0.6,
		size = { { 0, 0.5 }, { 1, 0.4 } },
		alpha = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
		life = { 1.4, 2.2 },
		speed = { 3, 8 },
		spread = 180,
		accel = Vector3.new(0, -2, 0),
		drag = 2.5,
		rot = { 0, 360 },
		spin = { -200, 200 },
	}, 24, Vector3.new(2, 5, 2))
	local hide = Cinema.card({
		kicker = "The deal is struck",
		title = Terms.f("{EYES}"),
		subtitle = Terms.f(
			"Names come fast now, from far away. You have {minutes} minutes of investigation left to live.",
			{ minutes = math.floor((tonumber(data.lifespan) or 180) / 60 + 0.5) }
		),
		color = C.void,
		textColor = C.red,
		y = 0.66,
	})
	task.wait(LENGTH - 7.05 + 1.6)
	hide()
	untint()
	removeVignette()
	undip()
	Cinema.letterbox(false)
	CameraDirector.release(token)
	Mixer.duck("eyes", false)
	if specter.Parent then
		specter:Destroy()
	end
end
