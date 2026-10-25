-- The FX kit (after the owner's tutorial, 2026-10-22: stylised effects are plain shapes grown and faded on a
-- curve): now a thin layer over the VFX kit (Presentation/Vfx, 2026-10-24), so everything that calls it wears the
-- new look: a ring is a textured shockwave rolling out over a glow on the floor, a dome a shell of light with a hot
-- heart, a crescent a blade of light, spikes a burst of light with spikes flung off it; a puff is real smoke. Made
-- on this client only, in the camera, and gone when done. Nothing under Reduce motion or on low graphics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Governor = require(script.Parent.Parent.World.Governor)
local Vfx = require(script.Parent.Vfx)

local FxKit = {}

export type Kind = "dome" | "ring" | "crescent" | "spikes"
export type Options = {
	size: number, -- studs across at its full size
	seconds: number?, -- to grow (0.45 by default)
	hold: number?, -- at full size before it fades (0 by default)
	fade: number?, -- to fade out (as long as it grows by default)
	color: Color3?,
	material: Enum.Material?, -- Neon (by default) or ForceField
	transparency: number?, -- how see-through at its strongest (0.25 by default)
	from: number?, -- the part of its size it starts at (0.1 by default)
	ease: Enum.EasingStyle?, -- the curve it grows on (Quint by default: fast, then settling)
	spin: number?, -- degrees it turns about its up while it grows
}

local EASES: { [string]: (number) -> number } = {
	Quint = Vfx.Ease.outQuint,
	Quart = Vfx.Ease.outQuart,
	Cubic = Vfx.Ease.outCubic,
	Quad = Vfx.Ease.outQuad,
	Expo = Vfx.Ease.outExpo,
	Back = Vfx.Ease.outBack,
	Elastic = Vfx.Ease.outElastic,
	Sine = Vfx.Ease.inOutSine,
	Linear = Vfx.Ease.linear,
}

local function quiet(): boolean
	return Motion.isReduced() or Governor.low("emoteFx")
end

local WHITE = Color3.new(1, 1, 1)

-- Grows a shape at `at` (its up the shape's up) on its curve, holds it and fades it. Returns how long it takes.
function FxKit.shape(kind: Kind, at: CFrame, options: Options): number
	if quiet() then
		return 0
	end
	local color = options.color or Color3.fromRGB(240, 240, 236)
	local seconds = options.seconds or 0.45
	local hold = options.hold or 0
	local fade = options.fade or seconds
	local ease = EASES[if options.ease then options.ease.Name else "Quint"] or Vfx.Ease.outQuint
	local size = options.size
	if kind == "ring" then
		-- a shockwave rolling out over the floor, a glow spreading under it
		Vfx.Beams.wave(at * CFrame.new(0, 0.06, 0), size * 0.08, size / 2, seconds + hold + fade * 0.5, {
			tex = "VfxRingBand",
			color = color:Lerp(WHITE, 0.2),
			width = math.max(0.4, size * 0.09),
			light = 0.55,
			bright = 1.1,
		})
		Vfx.Emit.burst(at * CFrame.new(0, 0.05, 0), {
			tex = "VfxRing",
			color = color,
			size = { { 0, size * 0.15 }, { 1, size * 1.1 } },
			alpha = { { 0, 0.1 + (options.transparency or 0.25) * 0.5 }, { 0.6, 0.6 }, { 1, 1 } },
			life = seconds + hold + fade,
			speed = 0.001,
			face = "flat",
			light = 0.5,
			bright = 0.9,
		}, 1)
	else
		Vfx.Shape.grow(kind, at, {
			size = size,
			from = options.from or 0.1,
			seconds = seconds,
			hold = hold,
			fade = fade,
			ease = ease,
			color = color,
			material = options.material or Enum.Material.Neon,
			transparency = math.max(options.transparency or 0.25, 0.3),
			spin = options.spin,
		})
		-- a hot heart where it opens
		Vfx.Emit.burst(at, {
			tex = "VfxGlow",
			color = color:Lerp(WHITE, 0.5),
			size = { { 0, size * 0.3 }, { 0.3, size * 0.75 }, { 1, size * 0.5 } },
			alpha = { { 0, 0.2 }, { 1, 1 } },
			life = seconds + hold * 0.5,
			bright = 1,
			light = 0.8,
		}, 1)
		if kind == "spikes" then
			Vfx.Emit.burst(at, {
				tex = "VfxSpike",
				color = { { 0, color:Lerp(WHITE, 0.6) }, { 1, color } },
				size = { { 0, size * 0.35 }, { 1, size * 0.05 } },
				squash = -1.4,
				life = { 0.16, 0.28 },
				speed = { size * 9, size * 15 },
				drag = 12,
				spread = 180,
				face = "along",
				light = 0.45,
				bright = 1.1,
			}, 10)
		end
	end
	return hold + seconds + fade
end

-- A puff (or `count` of them) at a point: smoke billowing out and thinning (or, with `glow`, a puff of light).
function FxKit.puff(at: Vector3, size: number, color: Color3?, count: number?, glow: number?)
	if quiet() then
		return
	end
	Vfx.Emit.burst(at, {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = color or Color3.fromRGB(150, 146, 142),
		light = glow or 0,
		lit = if glow then 0 else 0.6,
		size = { { 0, size * 0.55 }, { 1, size * 1.25 } },
		alpha = { { 0, 0.1 }, { 0.7, 0.35 }, { 1, 1 } },
		life = { 0.8, 1.2 },
		speed = { size * 0.6, size * 1.4 },
		spread = 70,
		drag = 3,
		rot = { 0, 360 },
		spin = { -30, 30 },
	}, count or 6)
end

-- A crater of rocks round an impact (the tutorials' rock module): `count` stones in a ring `radius` studs out,
-- popping up tipped outwards, then sinking back and gone.
function FxKit.rocks(at: Vector3, radius: number, count: number?, color: Color3?)
	if quiet() then
		return
	end
	local n = count or 10
	local random = Random.new()
	for k = 1, n do
		local a = (k + random:NextNumber(-0.3, 0.3)) / n * math.pi * 2
		local size = radius * random:NextNumber(0.18, 0.3)
		local spot = at + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local out = CFrame.lookAt(spot, spot + Vector3.new(math.cos(a), 0, math.sin(a)))
		local up = out
			* CFrame.new(0, size * 0.3, 0)
			* CFrame.Angles(math.rad(random:NextNumber(25, 45)), 0, math.rad(random:NextNumber(-15, 15)))
		local stone = Create("Part", {
			Name = "FxKit_rock",
			Size = Vector3.new(size, size * 0.8, size * 1.1),
			CFrame = up * CFrame.new(0, -size, 0),
			Color = color or Color3.fromRGB(96, 92, 88),
			Material = Enum.Material.Slate,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = workspace.CurrentCamera,
		}) :: BasePart
		TweenService
			:Create(stone, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = up })
			:Play()
		task.delay(1.1 + random:NextNumber(0, 0.3), function()
			TweenService:Create(stone, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = up * CFrame.new(0, -size * 1.2, 0),
				Transparency = 1,
			}):Play()
		end)
		task.delay(2.2, function()
			stone:Destroy()
		end)
	end
end

-- A flash of light at an impact, out again over `seconds`.
function FxKit.light(at: Vector3, color: Color3, range: number, brightness: number, seconds: number?)
	if quiet() then
		return
	end
	Vfx.Light.flash(at, color, range, brightness, seconds or 0.5)
end

return FxKit
