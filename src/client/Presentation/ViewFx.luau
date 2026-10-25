--!strict
-- Effects drawn over a 3D view (a ViewportFrame draws no particles, beams or lights): the VFX kit's textures as
-- images laid over the view at points of its world, the way an anime impact frame is drawn over the shot. Flares,
-- rings and dust where a gavel lands, sparks off a cuff, a lamp's shaft of light, a flash and a shake of the
-- view's camera. Used by the shop's cards and Your look, and by the verdicts over the arrest's shot
-- (Presentation/Styles).
--
--   local label = ViewFx.burst(view, Vector3.new(0, 0.5, 0), { tex = "VfxFlare", size = { 0.1, 0.6 }, life = 0.3 })
--   ViewFx.shake(view, 0.08, 0.25)   ViewFx.flash(view, Color3.new(1, 1, 1), 0.2)
--
-- Sizes are fractions of the view's height; a point is projected through the view's camera each frame it lives
-- (so it stays on its spot while the camera shakes).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Tex = require(script.Parent.Vfx.Tex)

local ViewFx = {}

export type Spec = {
	tex: string,
	color: Color3?,
	size: { number }?, -- from, to (fractions of the view's height)
	squash: number?, -- width over height
	alpha: { number }?, -- from, to (0 = solid)
	life: number?,
	rot: { number }?, -- from, to (degrees)
	grid: number?, -- a flipbook's cells across (and down)
	sheet: number?, -- the flipbook's side in px (1024)
	fps: number?,
	ease: Enum.EasingStyle?,
	z: number?,
	drift: Vector2?, -- how far it moves while it lives (fractions of the view)
	keep: boolean?, -- stays at its last look instead of being taken away
	still: number?, -- drawn once at this point of its life (0..1) and left there (a card's picture)
	anchor: Vector2?, -- the image's own point on the spot (its middle)
}

export type Point = Vector3 | Vector2 | () -> Vector3

-- Where a world point falls in the view, as a fraction across and down (nil when it is behind the camera).
function ViewFx.project(view: ViewportFrame, point: Vector3): Vector2?
	local camera = view.CurrentCamera
	if not camera then
		return nil
	end
	local size = view.AbsoluteSize
	local aspect = if size.Y > 0 then size.X / size.Y else 1
	local p = camera.CFrame:PointToObjectSpace(point)
	if p.Z >= -0.01 then
		return nil
	end
	local t = math.tan(math.rad(camera.FieldOfView / 2))
	local x = (p.X / -p.Z) / (t * aspect)
	local y = (p.Y / -p.Z) / t
	return Vector2.new((x + 1) / 2, (1 - y) / 2)
end

-- One image over the view at `point` (a world point, a fixed fraction of the view as a Vector2, or a function giving
-- a world point each frame: on something that moves), grown, turned and faded over its life as `spec` says; taken
-- away after it (unless `keep` or `still`). Returns the image.
function ViewFx.burst(view: ViewportFrame, point: Point, spec: Spec): ImageLabel
	local life = spec.life or 0.4
	local sizes = spec.size or { 0.2, 0.6 }
	local alphas = spec.alpha or { 0, 1 }
	local rots = spec.rot or { 0, 0 }
	local squash = spec.squash or 1
	local label = Instance.new("ImageLabel")
	label.Name = spec.tex
	label.BackgroundTransparency = 1
	label.Image = Tex.id(spec.tex)
	label.ImageColor3 = spec.color or Color3.new(1, 1, 1)
	label.ImageTransparency = alphas[1]
	label.AnchorPoint = spec.anchor or Vector2.new(0.5, 0.5)
	label.Rotation = rots[1]
	label.ZIndex = view.ZIndex + (spec.z or 1)
	label.Parent = view
	-- (a flipbook only once the kit's own sheet is in: a stand-in is one picture)
	local grid = if spec.grid and Tex.real(spec.tex) then spec.grid else 1
	local cell = (spec.sheet or 1024) / grid
	if grid > 1 then
		label.ImageRectSize = Vector2.new(cell, cell)
	end
	local reduced = Motion.isReduced()
	local start = os.clock()
	local function place(u: number)
		local at: Vector2?
		if typeof(point) == "Vector2" then
			at = point :: Vector2
		elseif typeof(point) == "Vector3" then
			at = ViewFx.project(view, point :: Vector3)
		else
			at = ViewFx.project(view, (point :: () -> Vector3)())
		end
		if not at then
			label.Visible = false
			return
		end
		label.Visible = true
		if spec.drift then
			at += spec.drift * u
		end
		local eased = TweenService:GetValue(u, spec.ease or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local h = sizes[1] + (sizes[#sizes] - sizes[1]) * eased
		local height = view.AbsoluteSize.Y
		label.Position = UDim2.fromScale(at.X, at.Y)
		label.Size = UDim2.fromOffset(height * h * squash, height * h)
		label.ImageTransparency = alphas[1] + (alphas[#alphas] - alphas[1]) * u
		label.Rotation = rots[1] + (rots[#rots] - rots[1]) * eased
		if grid > 1 then
			local frame = math.floor((os.clock() - start) * (spec.fps or 30)) % (grid * grid)
			label.ImageRectOffset = Vector2.new((frame % grid) * cell, math.floor(frame / grid) * cell)
		end
	end
	if spec.still then
		place(spec.still)
		-- (the view may not have its size yet: placed again once it has)
		local sized: RBXScriptConnection
		sized = view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if not label.Parent then
				sized:Disconnect()
				return
			end
			place(spec.still :: number)
		end)
		return label
	end
	if reduced then
		-- (under reduced motion: its middle look, briefly, with nothing moving)
		place(0.5)
		task.delay(math.min(life, 0.3), function()
			if not spec.keep then
				label:Destroy()
			end
		end)
		return label
	end
	place(0)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not label.Parent then
			connection:Disconnect()
			return
		end
		local u = math.clamp((os.clock() - start) / life, 0, 1)
		place(u)
		if u >= 1 then
			connection:Disconnect()
			if not spec.keep then
				label:Destroy()
			end
		end
	end)
	return label
end

-- A spray of small sparks out from `point`: `count` embers flung over the view, falling a little as they fade.
function ViewFx.sparks(view: ViewportFrame, point: Vector3, count: number, color: Color3, reach: number?)
	if Motion.isReduced() then
		return
	end
	local rng = Random.new()
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local far = (reach or 0.25) * rng:NextNumber(0.4, 1)
		ViewFx.burst(view, point, {
			tex = "VfxEmber",
			color = color,
			size = { rng:NextNumber(0.025, 0.045), 0.005 },
			alpha = { 0, 1 },
			life = rng:NextNumber(0.25, 0.5),
			drift = Vector2.new(math.cos(angle) * far, math.sin(angle) * far * 0.8 + far * 0.3),
			z = 3,
		})
	end
end

-- A flash over the whole view in `color`, fading over `seconds`.
function ViewFx.flash(view: ViewportFrame, color: Color3, seconds: number, strength: number?)
	if Motion.isReduced() or Motion.flashesOff() then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "Flash"
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - (strength or 0.5)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = view.ZIndex + 4
	frame.Parent = view
	TweenService:Create(frame, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	task.delay(seconds + 0.05, function()
		frame:Destroy()
	end)
end

-- Shakes the view's camera (studs) for `seconds`, settling back.
function ViewFx.shake(view: ViewportFrame, strength: number, seconds: number)
	local camera = view.CurrentCamera
	if not camera or Motion.isReduced() then
		return
	end
	local rest = camera.CFrame
	local start = os.clock()
	local rng = Random.new()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - start) / seconds
		if u >= 1 or not camera.Parent then
			connection:Disconnect()
			if camera.Parent then
				camera.CFrame = rest
			end
			return
		end
		local k = strength * (1 - u) ^ 2
		camera.CFrame = rest * CFrame.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0)
	end)
end

return ViewFx
