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
local Mixer = require(script.Parent.Parent.Parent.Audio.Mixer)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local Materialize = require(script.Parent.Parent.Materialize)
local ShotSolver = require(script.Parent.Parent.ShotSolver)
local SpecterPose = require(script.Parent.Parent.SpecterPose)
local StageLight = require(script.Parent.Parent.StageLight)
local EyesDealFx = require(script.Parent.Parent.EyesDealFx)
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

-- Where its head looks, by seconds since it began to be drawn in: { t, pitch (+ down), yaw (+ to its left, towards you) }.
-- Turned away and tipped back while it forms (its head is the last of it in, about 1.2 s), round to the room as the head
-- fills in, bent down to look at you as it leans over you, and up again to stare at the lens as it comes apart.
local HEAD_KEYS = {
	{ 0, -4, -14 },
	{ 1.2, -3, -12 },
	{ 2, 3, 0 },
	{ 2.2, 3, 0 },
	{ 3.4, 13, 8 },
	{ 5.4, 13, 9 },
	{ 6, 4, 1 },
	{ 7.2, 3, 1 },
}

local function headAt(t: number): (number, number)
	local keys = HEAD_KEYS
	local pitch, yaw = keys[#keys][2], keys[#keys][3]
	for k = 2, #keys do
		local a, b = keys[k - 1], keys[k]
		if t <= b[1] then
			local u = math.clamp((t - a[1]) / math.max(1e-6, b[1] - a[1]), 0, 1)
			u = u * u * (3 - 2 * u)
			pitch = a[2] + (b[2] - a[2]) * u
			yaw = a[3] + (b[3] - a[3]) * u
			break
		end
	end
	-- (never quite still: a slow sway of the head)
	return pitch + 1.5 * math.sin(t * 0.8 + 1), yaw + 2.5 * math.sin(t * 1.1)
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
	-- (its head turns, and its mane and skirt trail it: SpecterPose, no new model)
	local pose = SpecterPose.new(specter)
	local stopHead = function() end
	if pose then
		local began = Vfx.Clock.now()
		stopHead = Vfx.Clock.every(function(_, now)
			if not specter.Parent then
				return false
			end
			local pitch, yaw = headAt(now - began)
			SpecterPose.apply(pose, pitch, yaw, 0)
			return true
		end)
	end
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
	EyesDealFx.eyesOf(specter)
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
	EyesDealFx.ignite(body)
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
		kicker = "Deal made",
		title = Terms.f("{EYES}"),
		subtitle = Terms.f(
			"You can read names from afar. {minutes} minutes left to live.",
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
	stopHead()
	if specter.Parent then
		specter:Destroy()
	end
end
