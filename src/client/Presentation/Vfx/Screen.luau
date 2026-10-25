--!strict
-- The VFX kit's screen moments, on this player's own screen only and never under Reduce motion: a camera shake laid
-- over whatever drives the camera (a decaying noise, not a buzz), a colour flash, a punch of the field of view, and an
-- anime impact frame (two or three frames where the world blows out to white and the bodies at its heart go black).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local Clock = require(script.Parent.Clock)
local Ease = require(script.Parent.Ease)

local Screen = {}

local BIND = "DeathsGambit_VfxShake"
local shakes: { { began: number, seconds: number, amount: number, speed: number, seed: number } } = {}
local bound = false

local function bind()
	if bound then
		return
	end
	bound = true
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, function()
		local camera = workspace.CurrentCamera
		if not camera or #shakes == 0 then
			return
		end
		local now = Clock.now()
		local rx, ry, rz = 0, 0, 0
		local k = 1
		while k <= #shakes do
			local s = shakes[k]
			local u = (now - s.began) / s.seconds
			if u >= 1 then
				table.remove(shakes, k)
			else
				local fall = (1 - u) * (1 - u)
				local t = (now - s.began) * s.speed
				rx += math.noise(t, s.seed) * s.amount * fall
				ry += math.noise(t, s.seed + 31) * s.amount * fall
				rz += math.noise(t, s.seed + 67) * s.amount * 0.6 * fall
				k += 1
			end
		end
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
	end)
end

-- A shake of up to `amount` degrees dying away over `seconds` (speed: how fast it wanders, 18 by default).
function Screen.shake(amount: number, seconds: number, speed: number?)
	if Motion.isReduced() then
		return
	end
	bind()
	table.insert(shakes, {
		began = Clock.now(),
		seconds = seconds,
		amount = amount,
		speed = speed or 18,
		seed = math.random() * 1000,
	})
end

-- The shake for a hit at `at` (lighter the further it is from the camera; none past `reach` studs).
function Screen.shakeAt(at: Vector3, amount: number, seconds: number, reach: number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local d = (camera.CFrame.Position - at).Magnitude
	local r = reach or 60
	if d < r then
		Screen.shake(amount * (1 - d / r), seconds)
	end
end

-- A colour flash over the scene: tinted toward `color`, `brightness` brighter at once, back over `seconds`.
function Screen.flash(color: Color3, brightness: number, seconds: number)
	if Motion.isReduced() then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DGVfxFlash"
	cc.TintColor = color
	cc.Brightness = brightness
	cc.Parent = Lighting
	Clock.tween(seconds, Ease.outQuad, function(u)
		cc.Brightness = brightness * (1 - u)
		cc.TintColor = color:Lerp(Color3.new(1, 1, 1), u)
	end, function()
		cc:Destroy()
	end)
end

-- A punch of the field of view: `degrees` wider (or narrower, negative) at once and back over `seconds`.
function Screen.punch(degrees: number, seconds: number)
	if Motion.isReduced() then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local base = camera.FieldOfView
	Clock.tween(seconds, Ease.outQuint, function(u)
		if camera.Parent then
			camera.FieldOfView = base + degrees * (1 - u)
		end
	end)
end

-- An impact frame (`seconds`, about three frames): the world blown out pale and colourless, `bodies` black against it.
function Screen.impact(bodies: { Model }, seconds: number?)
	if Motion.isReduced() then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DGVfxImpact"
	cc.Saturation = -1
	cc.Contrast = 1.6
	cc.Brightness = 0.55
	cc.Parent = Lighting
	local marks = {}
	for _, body in ipairs(bodies) do
		local h = Instance.new("Highlight")
		h.Name = "DGVfxImpact"
		h.FillColor = Color3.new(0, 0, 0)
		h.FillTransparency = 0
		h.OutlineColor = Color3.new(0, 0, 0)
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = body
		h.Parent = body
		table.insert(marks, h)
	end
	Clock.after(seconds or 0.07, function()
		cc:Destroy()
		for _, h in ipairs(marks) do
			h:Destroy()
		end
	end)
end

return Screen
