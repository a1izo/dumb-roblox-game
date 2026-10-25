--!strict
-- The VFX kit's beams: textured ribbons of light between two points (Roblox Beams, unlit, added as light), a flat
-- ring of four curved beams on the ground (a shockwave's front, a glowing circle), and lightning: a jagged chain of
-- short beams that jumps to a new shape a few times a second. Width and brightness fade on the kit's clock.

local Clock = require(script.Parent.Clock)
local Ease = require(script.Parent.Ease)
local Emit = require(script.Parent.Emit)
local Tex = require(script.Parent.Tex)

local Beams = {}

export type Options = {
	tex: string?,
	color: Color3 | ColorSequence | nil,
	width: number?,
	width1: number?,
	bright: number?,
	light: number?,
	alpha: NumberSequence?,
	speed: number?, -- the texture's scroll (studs a second)
	repeats: number?, -- with Wrap: studs per repeat of the texture
	segments: number?,
	faceCamera: boolean?,
	z: number?,
}

local function holder(): Part
	return Emit.point(CFrame.new(), Vector3.new(0.05, 0.05, 0.05))
end

local function attachment(parent: Instance, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Parent = parent
	a.WorldCFrame = cf
	return a
end

-- One beam from a0 to a1 with these options.
function Beams.make(a0: Attachment, a1: Attachment, options: Options, parent: Instance): Beam
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Texture = Tex.id(options.tex or "VfxStreak")
	local color = options.color
	b.Color = if typeof(color) == "ColorSequence"
		then color
		elseif typeof(color) == "Color3" then ColorSequence.new(color)
		else ColorSequence.new(Color3.new(1, 1, 1))
	b.Width0 = options.width or 1
	b.Width1 = options.width1 or options.width or 1
	b.Brightness = options.bright or 1
	b.LightEmission = options.light or 1
	b.LightInfluence = 0
	b.Transparency = options.alpha or NumberSequence.new(0)
	b.TextureSpeed = options.speed or 0
	if options.repeats then
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = options.repeats
	else
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
	end
	b.Segments = options.segments or 16
	b.FaceCamera = options.faceCamera ~= false
	b.ZOffset = options.z or 0
	b.Parent = parent
	Clock.watch(b)
	return b
end

-- A straight beam from `from` to `to`; returns the beam and a function that ends it (now, or faded over `fade`).
function Beams.line(from: Vector3, to: Vector3, options: Options): (Beam, (fade: number?) -> ())
	local h = holder()
	local axis = (to - from)
	local a0 = attachment(h, CFrame.lookAt(from, to) * CFrame.Angles(0, math.rad(90), 0))
	local a1 = attachment(h, CFrame.lookAt(to, to + axis) * CFrame.Angles(0, math.rad(90), 0))
	local beam = Beams.make(a0, a1, options, h)
	local ended = false
	return beam,
		function(fade: number?)
			if ended then
				return
			end
			ended = true
			local w0, w1 = beam.Width0, beam.Width1
			Clock.tween(fade or 0, Ease.outQuad, function(u)
				beam.Width0, beam.Width1 = w0 * (1 - u), w1 * (1 - u)
			end, function()
				h:Destroy()
			end)
		end
end

-- A flat ring of light round `centre` (its up the ring's up) of `radius` studs, its band `options.width` wide, from
-- four quarter arcs. Returns a function that sets its radius and band width (a growing shockwave) and one that ends it.
function Beams.ring(
	centre: CFrame,
	radius: number,
	options: Options
): ((radius: number, width: number?) -> (), () -> ())
	local h = holder()
	local points = {}
	local beams = {}
	for k = 1, 4 do
		points[k] = { attachment(h, centre), attachment(h, centre) }
	end
	-- (a quarter circle from one cubic: its handles 0.5523 of the radius along the tangents)
	local width = options.width or 1
	local function set(r: number, w: number?)
		width = w or width
		for k = 1, 4 do
			local a = (k - 1) * math.pi / 2
			local b = k * math.pi / 2
			local function frame(angle: number): CFrame
				local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
				-- (the beam leaves along the attachment's x; its width lies along the attachment's y: here the radius,
				-- so the band lies flat)
				return centre * CFrame.fromMatrix(out * r, tangent, out)
			end
			points[k][1].WorldCFrame = frame(a)
			points[k][2].WorldCFrame = frame(b)
			local beam = beams[k]
			if beam then
				beam.CurveSize0 = 0.5523 * r
				beam.CurveSize1 = 0.5523 * r
				beam.Width0, beam.Width1 = width, width
			end
		end
	end
	for k = 1, 4 do
		local o = table.clone(options)
		o.faceCamera = false
		o.segments = options.segments or 20
		beams[k] = Beams.make(points[k][1], points[k][2], o, h)
	end
	set(radius)
	return set, function()
		h:Destroy()
	end
end

-- A shockwave ring on the ground: from radius `from` to `to` on an outQuint curve over `seconds`, its band thinning
-- and fading as it goes.
function Beams.wave(centre: CFrame, from: number, to: number, seconds: number, options: Options)
	local set, stop = Beams.ring(centre, from, options)
	local w = options.width or 1
	Clock.tween(seconds, Ease.outQuint, function(u)
		set(from + (to - from) * u, w * (1 - 0.65 * u))
	end, stop)
end

-- Lightning from `from` to `to`: a jagged chain of `pieces` beams, its bends thrown sideways up to `jag` studs, drawn
-- anew `rate` times a second for `seconds`, then gone; branches fork off it now and then.
function Beams.bolt(
	from: Vector3,
	to: Vector3,
	seconds: number,
	options: Options & { jag: number?, pieces: number?, rate: number? }
)
	local h = holder()
	local pieces = options.pieces or 8
	local jag = options.jag or (to - from).Magnitude * 0.12
	local rate = options.rate or 18
	local rng = Random.new()
	local nodes: { Attachment } = {}
	for k = 0, pieces do
		nodes[k] = attachment(h, CFrame.new(from:Lerp(to, k / pieces)))
	end
	local made: { Beam } = {}
	for k = 1, pieces do
		local o = table.clone(options)
		o.tex = options.tex or "VfxStreak"
		made[k] = Beams.make(nodes[k - 1], nodes[k], o, h)
	end
	local dir = (to - from).Unit
	local side = dir:Cross(if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
	local up = dir:Cross(side).Unit
	local function reshape()
		for k = 1, pieces - 1 do
			local along = from:Lerp(to, k / pieces)
			local taper = math.sin(math.pi * k / pieces)
			local off = side * rng:NextNumber(-1, 1) * jag * taper + up * rng:NextNumber(-1, 1) * jag * taper
			nodes[k].WorldPosition = along + off
		end
	end
	reshape()
	local began = Clock.now()
	local last = began
	Clock.every(function(_, now)
		if not h.Parent then
			return false
		end
		if now - began >= seconds then
			h:Destroy()
			return false
		end
		if now - last >= 1 / rate then
			last = now
			reshape()
		end
		return true
	end)
	return h
end

return Beams
