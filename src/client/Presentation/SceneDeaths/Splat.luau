-- Blood for the scene deaths (2026-11-14, the user on Walrider's: "make those on screen blood splatters way more high
-- quality"; on Let's dance: "a bit of blood splatter"). On the lens: drawn splats (art/scripts/ui/blood_splats.py: a
-- heavy core, arms thrown out that break into beads, a spray of droplets) that land with a jolt, creep, run down in
-- drips and fade. In the world: a spray of dark drops thrown from a wound, falling under gravity.

local TweenService = game:GetService("TweenService")

local Vfx = require(script.Parent.Parent.Vfx)

local Splat = {}

-- The drawn splats (A a full burst, B light with spray, C heavy, D flung sideways) and the drip.
Splat.IMAGES = {
	"rbxassetid://70565336311504",
	"rbxassetid://85681407750856",
	"rbxassetid://88815808426188",
	"rbxassetid://72010509883809",
}
Splat.DRIP = "rbxassetid://86768980486661"

export type Options = {
	at: Vector2, -- where on the screen (0..1)
	size: number, -- its width as a share of the screen's height
	image: number?, -- which splat (1..4; picked by `seed` when nil)
	seed: number?,
	turn: number?, -- degrees
	alpha: number?, -- how see-through it lands (0 solid; default 0.08)
	hold: number?, -- seconds before it starts to fade (default 2.5)
	fade: number?, -- seconds to fade (default 1.2)
	drips: number?, -- runs of blood down from it (default 2)
	z: number?,
}

-- (in the harness place the pictures are read from Studio's content folder, as the VFX textures are: Vfx/Tex)
local function picture(id: string, name: string): string
	if workspace:GetAttribute("DGVfxLocal") then
		return "rbxasset://textures/dg_vfx_harness/" .. name .. ".png"
	end
	return id
end
local NAMES = { "BloodSplatA", "BloodSplatB", "BloodSplatC", "BloodSplatD" }

-- A splat on `layer` (a full-screen frame). Returns its holder (gone when it has faded; destroy it sooner to cut it).
function Splat.screen(layer: GuiObject, options: Options): Frame
	local rng = Random.new(options.seed or math.random(1, 100000))
	local holder = Instance.new("Frame")
	holder.Name = "Splat"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(options.at.X, options.at.Y)
	holder.Size = UDim2.fromScale(options.size, options.size)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.ZIndex = options.z or 6
	holder.Parent = layer
	local alpha = options.alpha or 0.08
	local hold, fade = options.hold or 2.5, options.fade or 1.2

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(0.5, 0.5)
	local which = options.image or rng:NextInteger(1, #Splat.IMAGES)
	image.Image = picture(Splat.IMAGES[which], NAMES[which])
	image.Rotation = options.turn or rng:NextNumber(0, 360)
	image.ImageTransparency = 0.5
	image.ZIndex = holder.ZIndex + 1
	image.Parent = holder
	-- it lands: thrown on in two or three frames, a hair past its size, then it settles and creeps
	TweenService:Create(image, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1.06, 1.06),
		ImageTransparency = alpha,
	}):Play()
	task.delay(0.07, function()
		if image.Parent then
			TweenService:Create(image, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
		end
	end)
	-- the drips: each starts from somewhere under the core after its own wait, runs at its own pace, slows and stops
	local drips = {}
	for _ = 1, options.drips or 2 do
		local drip = Instance.new("ImageLabel")
		drip.BackgroundTransparency = 1
		drip.AnchorPoint = Vector2.new(0.5, 0)
		drip.Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.2, 0.2), 0.5 + rng:NextNumber(0.0, 0.12))
		local width = rng:NextNumber(0.045, 0.085)
		drip.Size = UDim2.fromScale(width, 0)
		drip.Image = picture(Splat.DRIP, "BloodDrip")
		drip.ScaleType = Enum.ScaleType.Stretch
		drip.ImageTransparency = alpha
		drip.ZIndex = holder.ZIndex
		drip.Parent = holder
		table.insert(drips, drip)
		local length = rng:NextNumber(0.35, 0.9)
		task.delay(rng:NextNumber(0.1, 0.5), function()
			if drip.Parent then
				TweenService:Create(
					drip,
					TweenInfo.new(rng:NextNumber(1.4, 2.8), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(width, length) }
				):Play()
			end
		end)
	end
	task.delay(hold, function()
		if not holder.Parent then
			return
		end
		local info = TweenInfo.new(fade, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		TweenService:Create(image, info, { ImageTransparency = 1 }):Play()
		for _, drip in ipairs(drips) do
			TweenService:Create(drip, info, { ImageTransparency = 1 }):Play()
		end
		task.delay(fade + 0.05, function()
			holder:Destroy()
		end)
	end)
	return holder
end

-- A splat landed on a surface in the world (2026-11-15, the user: "add more blood splatters to the cutscene that have
-- them"): the drawn splat as a decal lying on the floor or a wall at `at` (its face along `normal`), `size` studs
-- across, thrown on in a few frames a hair past its size, then spreading a little more as it soaks in; it stays
-- (in `parent`, the scene's folder, so it goes with the scene) unless `hold` says when to fade it.
function Splat.ground(
	parent: Instance,
	at: Vector3,
	normal: Vector3,
	size: number,
	options: {
		image: number?,
		seed: number?,
		turn: number?,
		alpha: number?,
		spread: number?,
		hold: number?,
	}?
): BasePart
	local o = options or {}
	local rng = Random.new(o.seed or math.random(1, 100000))
	local up = normal.Unit
	local side = up:Cross(if math.abs(up.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis).Unit
	local look = side:Cross(up)
	local pad = Instance.new("Part")
	pad.Name = "BloodSplat"
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CanTouch = false
	pad.CastShadow = false
	pad.Transparency = 1
	pad.Size = Vector3.new(size * 0.55, 0.02, size * 0.55)
	pad.CFrame = CFrame.fromMatrix(at + up * (0.02 + rng:NextNumber(0, 0.01)), side, up, -look)
		* CFrame.Angles(0, math.rad(o.turn or rng:NextNumber(0, 360)), 0)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	local which = o.image or rng:NextInteger(1, #Splat.IMAGES)
	decal.Texture = picture(Splat.IMAGES[which], NAMES[which])
	decal.Transparency = 0.6
	decal.Parent = pad
	pad.Parent = parent
	local solid = o.alpha or 0.05
	TweenService:Create(pad, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(size * 1.04, 0.02, size * 1.04),
	}):Play()
	TweenService:Create(decal, TweenInfo.new(0.08), { Transparency = solid }):Play()
	-- (soaking in: it creeps out a little further over the next seconds)
	task.delay(0.1, function()
		if pad.Parent then
			local grow = 1 + (o.spread or 0.12)
			TweenService:Create(pad, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = Vector3.new(size * grow, 0.02, size * grow),
			}):Play()
		end
	end)
	if o.hold then
		task.delay(o.hold, function()
			if pad.Parent then
				TweenService:Create(decal, TweenInfo.new(0.8), { Transparency = 1 }):Play()
				task.delay(0.85, function()
					pad:Destroy()
				end)
			end
		end)
	end
	return pad
end

-- Blood running off `part` (a hand, a wound) at its point `offset`: a drop every `every` seconds from t0 to t1 (scene
-- clock via `during`), each a dark bead falling under gravity (slowed by `slow` in a slow motion).
function Splat.drips(
	ctx: any,
	part: () -> BasePart?,
	offset: Vector3,
	t0: number,
	t1: number,
	every: number,
	slow: number?
)
	local next = t0
	ctx:during(t0, t1, function(t)
		if t < next then
			return
		end
		next = t + every * (0.7 + math.random() * 0.6)
		local p = part()
		if not p then
			return
		end
		local k = slow or 1
		Vfx.Emit.burst((p.CFrame * CFrame.new(offset)).Position, {
			tex = "VfxEmber",
			color = { { 0, Color3.fromRGB(140, 6, 14) }, { 1, Color3.fromRGB(70, 0, 6) } },
			size = { { 0, 0.07 }, { 0.3, 0.12 }, { 1, 0.09 } },
			squash = -1.4,
			face = "along",
			life = { 0.6 / k, 0.9 / k },
			speed = { 0.2 * k, 0.8 * k },
			spread = 15,
			dir = Enum.NormalId.Bottom,
			accel = Vector3.new(0, -40 * k * k, 0),
			light = 0,
			lit = 0.7,
		}, 1)
	end)
end

-- Drops thrown from a wound at `at` (world) the way `dir` points: dark, heavy, falling fast; a few hang in the air as
-- a fine mist. `amount` scales how many (1: a cut).
function Splat.spray(at: Vector3, dir: Vector3, amount: number?)
	local k = amount or 1
	local frame = CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(-90), 0, 0) -- (its up along dir)
	Vfx.Emit.burst(
		frame,
		{
			{
				{
					tex = "VfxEmber",
					color = { { 0, Color3.fromRGB(150, 6, 14) }, { 1, Color3.fromRGB(70, 0, 6) } },
					size = { { 0, 0.16 }, { 0.5, 0.11 }, { 1, 0.04 } },
					squash = -1.6,
					face = "along",
					life = { 0.45, 0.9 },
					speed = { 9, 24 },
					spread = 34,
					accel = Vector3.new(0, -46, 0),
					drag = 0.6,
					light = 0,
					lit = 0.7,
				},
				math.floor(22 * k),
			},
			{
				{
					tex = "VfxGlow",
					color = Color3.fromRGB(110, 4, 10),
					size = { { 0, 0.2 }, { 1, 0.9 } },
					alpha = { { 0, 0.55 }, { 1, 1 } },
					life = { 0.3, 0.6 },
					speed = { 2, 6 },
					spread = 50,
					drag = 3,
					light = 0,
					lit = 0.7,
				},
				math.floor(5 * k),
			},
		} :: any
	)
end

return Splat
