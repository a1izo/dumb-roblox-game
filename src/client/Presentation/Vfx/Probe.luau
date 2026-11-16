--!strict
-- The effect probe (the VFX rework, ticket V0.5, docs/handoff/vfx-rework-plan-2026-11-16.md): the bar of Part 3 as numbers,
-- read from the kit itself while an effect plays in the debug booth (Debug/FxBooth.report).
--
-- Off by default. While `Probe.on` is true, the kit's own makers each add a row for what they make (Emit.make and
-- Emit.burst, Beams.make, Shape.grow, Light.flash and Light.hold, Screen.*); each is one `if Probe.on then` line, so
-- nothing costs anything while it is off. FxBooth.report also hands in the emitters, beams and lights an effect made
-- outside the kit (Probe.raw), read from the instances themselves.
--
--   row  { t, kind, name, tex, count, want, rate, size, size0, size1, life, lifeMin, bright, light, a0, a1, ... }
--     t       seconds after the effect began (the booth's play)
--     kind    emit (a rate), burst (a count, or a manual emit whose count is not seen), beam, shape, light, screen
--     tex     the texture's name, or "shape:ring" for a solid shape
--     size    the biggest the layer gets, in studs; size0 and size1 where it is born and where it dies
--     life    the longest a particle lives (a shape's whole life; a light's seconds, 0 when it holds until let go)
--     bright  Brightness; light  LightEmission (1 adds as light, 0 is laid over)
--     a0, a1  transparency when born and when it dies (0 solid, 1 gone)
--
-- Probe.judge(rows, meta) is pure (no instances): it reads recorded rows and says PASS or FAIL with reasons (the checks of
-- Part 3 and the budgets of Part 9), so the spec can test it on made-up rows of known answers.
--
-- The report is a floor, not a judge: passing it does not make an effect good.

local Probe = {}

export type Row = { [string]: any }

Probe.on = false
Probe.rows = {} :: { Row }
Probe.clock = os.clock :: () -> number
Probe.origin = 0
Probe.center = nil :: Vector3?
Probe.radius = 0

local byInstance: { [Instance]: Row } = setmetatable({}, { __mode = "k" }) :: any
local connections: { RBXScriptConnection } = {}

-- Part 9's budgets: particles alive at peak, sprites of 8 studs or more alive, emitters, lights.
Probe.BUDGETS = {
	world = { particles = 12, big = 1, emitters = 4, lights = 0 },
	accent = { particles = 60, big = 2, emitters = 6, lights = 1 },
	showpiece = { particles = 250, big = 6, emitters = 12, lights = 2 },
	scene = { particles = 600, big = 10, emitters = 20, lights = 3 },
} :: { [string]: { particles: number, big: number, emitters: number, lights: number } }

-- The plain sprites that may only support a layer (Part 3, rule 2), and their Aura twins.
Probe.DOTS = {
	VfxGlow = true,
	VfxEmber = true,
	VfxFlare = true,
	AuraGlow = true,
	AuraSpecks = true,
	AuraTwinkle = true,
} :: { [string]: boolean }

local BIG = 8 -- studs: a sprite this size or more is a big one
local STEP = 0.05 -- seconds between the moments the peaks are read at

-- Recording -----------------------------------------------------------------------------------------------------------

-- Starts recording: the clock to read time from, and (optionally) a centre and radius; what is made further from it is
-- another system's and is left out.
function Probe.begin(clock: () -> number, center: Vector3?, radius: number?)
	Probe.clock = clock
	Probe.origin = clock()
	Probe.center = center
	Probe.radius = radius or 0
	Probe.rows = {}
	table.clear(byInstance)
	Probe.on = true
end

-- Starts the time again from now and forgets what was recorded (the booth calls it as the effect begins).
function Probe.restart(now: number)
	Probe.origin = now
	Probe.rows = {}
	table.clear(byInstance)
end

-- Stops recording (what was recorded stays in Probe.rows).
function Probe.finish()
	Probe.on = false
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
end

function Probe.now(): number
	return Probe.clock() - Probe.origin
end

-- A sequence as its first, last and biggest values: a number, a { {t, v}, ... } list or a NumberSequence.
local function digest(value: any, default: number): (number, number, number)
	if value == nil then
		return default, default, default
	elseif type(value) == "number" then
		return value, value, value
	end
	local list: { number } = {}
	if typeof(value) == "NumberSequence" then
		for _, key in ipairs(value.Keypoints) do
			table.insert(list, key.Value)
		end
	else
		for _, point in ipairs(value) do
			table.insert(list, point[2])
		end
	end
	if #list == 0 then
		return default, default, default
	end
	local biggest = list[1]
	for _, v in ipairs(list) do
		biggest = math.max(biggest, v)
	end
	return list[1], list[#list], biggest
end

local function lifeOf(life: any, default: number): (number, number)
	if life == nil then
		return default, default
	elseif type(life) == "number" then
		return life, life
	elseif typeof(life) == "NumberRange" then
		return life.Min, life.Max
	end
	return life[1], life[2] or life[1]
end

-- Where something is: its part's or attachment's place (nil when unknown).
local function placeOf(parent: Instance?): Vector3?
	if parent == nil then
		return nil
	elseif parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return nil
end

-- False when `at` is out of the centre's reach (another system's effect).
local function near(at: Vector3?): boolean
	local center = Probe.center
	if center == nil or at == nil or Probe.radius <= 0 then
		return true
	end
	return (at - center).Magnitude <= Probe.radius
end

-- Ties a row to its instance: a rate stops when it is turned off, a thing ends when it is destroyed.
local function follow(row: Row, inst: Instance)
	byInstance[inst] = row
	table.insert(
		connections,
		inst.Destroying:Connect(function()
			row.cut = row.cut or Probe.now()
		end)
	)
	if inst:IsA("ParticleEmitter") then
		local e = inst :: ParticleEmitter
		table.insert(
			connections,
			e:GetPropertyChangedSignal("Enabled"):Connect(function()
				if e.Enabled then
					if row.kind == "emit" or row.manual then
						row.tEnd = nil
						row.tOn = Probe.now()
					end
				elseif row.kind == "emit" then
					row.tEnd = row.tEnd or Probe.now()
				end
			end)
		)
		table.insert(
			connections,
			e:GetPropertyChangedSignal("Rate"):Connect(function()
				if e.Rate > 0 and row.manual then
					row.kind, row.manual = "emit", false
					row.rate = e.Rate
					row.tOn = Probe.now()
				elseif e.Rate > 0 and row.kind == "emit" then
					row.rate = math.max(row.rate, e.Rate)
				end
			end)
		)
	elseif inst:IsA("Light") then
		local l = inst :: Light
		table.insert(
			connections,
			l:GetPropertyChangedSignal("Enabled"):Connect(function()
				if not l.Enabled then
					row.cut = row.cut or Probe.now()
				end
			end)
		)
	end
end

local function add(row: Row, inst: Instance?): Row
	row.t = Probe.now()
	table.insert(Probe.rows, row)
	if inst then
		follow(row, inst)
	end
	return row
end

-- A particle emitter the kit made from `spec` (Emit.make). Its rate is the spec's own (100%, before the share).
function Probe.emit(e: ParticleEmitter, spec: { [string]: any })
	if not near(placeOf(e.Parent)) then
		return
	end
	local s0, s1, smax = digest(spec.size, 1)
	local a0, a1 = digest(spec.alpha, 0)
	local lmin, lmax = lifeOf(spec.life, 1)
	local rate = spec.rate or 0
	local row = byInstance[e] or {} :: Row
	local fresh = byInstance[e] == nil
	row.kind = if rate > 0 then "emit" else "burst"
	row.manual = rate <= 0
	row.name = spec.name or ""
	row.tex = spec.tex or "VfxGlow"
	row.rate = rate
	row.size, row.size0, row.size1 = smax, s0, s1
	row.life, row.lifeMin = lmax, lmin
	row.bright = spec.bright or 1
	row.light = spec.light or 1
	row.a0, row.a1 = a0, a1
	row.particle = true
	row.raw = nil
	if fresh then
		add(row, e)
	end
end

-- Emit.burst emitted `made` particles (it was asked for `want`) from `e`.
function Probe.burst(e: ParticleEmitter, want: number, made: number)
	local row = byInstance[e]
	if row then
		row.count, row.want, row.manual = made, want, false
	end
end

-- A beam the kit made (Beams.make).
function Probe.beam(b: Beam, options: { [string]: any })
	local at = if b.Attachment0 then b.Attachment0.WorldPosition else nil
	if not near(at) then
		return
	end
	local a0, a1 = digest(options.alpha, 0)
	local row = byInstance[b] or {} :: Row
	local fresh = byInstance[b] == nil
	row.kind = "beam"
	row.manual = false
	row.name = ""
	row.tex = options.tex or "VfxStreak"
	row.rate = 0
	row.size = math.max(options.width or 1, options.width1 or options.width or 1)
	row.size0, row.size1 = row.size, row.size
	row.life, row.lifeMin = 0, 0
	row.bright = options.bright or 1
	row.light = options.light or 1
	row.a0, row.a1 = a0, a1
	row.particle = false
	row.raw = nil
	if fresh then
		add(row, b)
	end
end

-- A solid shape grown (Shape.grow): `total` seconds of life; `hidden` when only a stand-in is drawn (not imported).
function Probe.shape(kind: string, options: { [string]: any }, at: CFrame, total: number, hidden: boolean)
	if not near(at.Position) then
		return
	end
	local neon = options.texture == nil and (options.material == nil or options.material == Enum.Material.Neon)
	add({
		kind = "shape",
		manual = false,
		name = kind,
		tex = "shape:" .. kind,
		rate = 0,
		size = options.size,
		size0 = options.size * (options.from or 0.15),
		size1 = options.size * (options.grow or 1),
		life = total,
		lifeMin = total,
		bright = 1,
		light = if neon then 1 else 0,
		a0 = options.transparency or 0.15,
		a1 = 1,
		particle = false,
		hidden = hidden,
	})
end

-- A light the kit made (Light.flash: `seconds` of life; Light.hold: none, it holds until let go).
function Probe.light(name: string, light: Light, seconds: number?, brightness: number?)
	if not near(placeOf(light.Parent)) then
		return
	end
	local row = byInstance[light] or {} :: Row
	local fresh = byInstance[light] == nil
	row.kind = "light"
	row.manual = false
	row.name = name
	row.tex = ""
	row.rate = 0
	row.size = (light :: any).Range
	row.size0, row.size1 = row.size, row.size
	row.life, row.lifeMin = seconds or 0, seconds or 0
	row.bright = brightness or (light :: any).Brightness
	row.light = 1
	row.a0, row.a1 = 0, 1
	row.particle = false
	row.raw = nil
	if fresh then
		add(row, light)
	end
end

-- A screen moment (Screen.shake, flash, punch, impact): `seconds` long.
function Probe.screen(name: string, seconds: number, amount: number?)
	add({
		kind = "screen",
		manual = false,
		name = name,
		tex = "",
		rate = 0,
		size = amount or 0,
		size0 = 0,
		size1 = 0,
		life = seconds,
		lifeMin = seconds,
		bright = 1,
		light = 1,
		a0 = 0,
		a1 = 1,
		particle = false,
	})
end

-- An emitter, beam or light some effect made on its own (not through the kit): read from the instance. `texName` turns a
-- texture string back into the kit's name.
function Probe.raw(inst: Instance, texName: (string) -> string)
	if byInstance[inst] then
		return
	end
	if inst:IsA("ParticleEmitter") then
		local e = inst :: ParticleEmitter
		if not near(placeOf(e.Parent)) then
			return
		end
		local s0, s1, smax = digest(e.Size, 1)
		local a0, a1 = digest(e.Transparency, 0)
		local row: Row = {
			kind = if e.Rate > 0 then "emit" else "burst",
			manual = e.Rate <= 0,
			name = e.Name,
			tex = texName(e.Texture),
			rate = e.Rate,
			size = smax,
			size0 = s0,
			size1 = s1,
			life = e.Lifetime.Max,
			lifeMin = e.Lifetime.Min,
			bright = e.Brightness,
			light = e.LightEmission,
			a0 = a0,
			a1 = a1,
			particle = true,
			raw = true,
		}
		add(row, e)
		if not e.Enabled then
			row.tOn = nil
			row.tEnd = row.t
		end
	elseif inst:IsA("Beam") then
		local b = inst :: Beam
		local at = if b.Attachment0 then b.Attachment0.WorldPosition else nil
		if not near(at) then
			return
		end
		local a0, a1 = digest(b.Transparency, 0)
		local width = math.max(b.Width0, b.Width1)
		add({
			kind = "beam",
			manual = false,
			name = b.Name,
			tex = texName(b.Texture),
			rate = 0,
			size = width,
			size0 = width,
			size1 = width,
			life = 0,
			lifeMin = 0,
			bright = b.Brightness,
			light = b.LightEmission,
			a0 = a0,
			a1 = a1,
			particle = false,
			raw = true,
		}, b)
	elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		local l = inst :: Light
		if not near(placeOf(l.Parent)) then
			return
		end
		Probe.light(l.ClassName, l, nil, nil)
		local row = byInstance[l]
		if row then
			row.raw = true
		end
	end
end

-- Judging (pure) --------------------------------------------------------------------------------------------------------

export type Meta = {
	hit: number, -- the second the main beat lands
	length: number, -- the seconds worth watching
	tier: string?, -- free, scrawl, penned, sealed, condemned, godhood
	budget: string?, -- world, accent, showpiece or scene
	loop: boolean?,
	estimated: boolean?, -- the hit is a guess
	endT: number?, -- how long the effect was watched (seconds from its start)
}

export type Verdict = {
	pass: boolean,
	fails: { string },
	notes: { string },
	stats: { [string]: any },
}

local function isLayer(row: Row): boolean
	local kind = row.kind
	return (kind == "emit" or kind == "burst" or kind == "beam" or kind == "shape") and row.hidden ~= true
end

-- The second a row's last piece is gone.
local function aliveTo(row: Row, endT: number): number
	local to: number
	local kind = row.kind
	if kind == "emit" then
		to = (row.tEnd or endT) + row.life
	elseif kind == "beam" then
		to = endT
	elseif kind == "light" then
		to = if row.life > 0 then row.t + row.life else endT
	else
		to = row.t + row.life
	end
	if row.cut then
		to = math.min(to, row.cut)
	end
	return to
end

local function aliveFrom(row: Row): number
	return if row.kind == "emit" then row.tOn or row.t else row.t
end

-- How many particles of a row are alive at second `tau` (at 100%: the count asked for, the rate as designed).
local function particlesAt(row: Row, tau: number): number
	if row.kind == "burst" then
		local n = row.want or row.count
		if n == nil or row.manual then
			return 0
		end
		local to = row.t + row.life
		if row.cut then
			to = math.min(to, row.cut)
		end
		return if tau >= row.t and tau < to then n else 0
	elseif row.kind == "emit" then
		if row.cut and tau >= row.cut then
			return 0
		end
		local avg = (row.life + row.lifeMin) / 2
		local off = row.tEnd or math.huge
		local span = math.min(tau, off) - math.max(row.tOn or row.t, tau - avg)
		return if span > 0 then row.rate * span else 0
	end
	return 0
end

-- The peaks over time: particles alive, big sprites, emitters, lights (the most at any one moment).
local function peaks(rows: { Row }, endT: number): (number, number, number, number)
	local peakParticles, peakBig, peakEmitters, peakLights = 0, 0, 0, 0
	local last = 0
	local to: { [Row]: number } = {}
	for _, row in ipairs(rows) do
		to[row] = aliveTo(row, endT)
		last = math.max(last, to[row])
	end
	local tau = 0
	while tau <= last + STEP do
		local particles, big, emitters, lights = 0, 0, 0, 0
		for _, row in ipairs(rows) do
			if row.hidden ~= true and tau >= aliveFrom(row) and tau < to[row] then
				local kind = row.kind
				if kind == "light" then
					lights += 1
				elseif kind ~= "screen" then
					if kind ~= "shape" then
						emitters += 1
					end
					local n = particlesAt(row, tau)
					particles += n
					if row.size >= BIG then
						big += if kind == "emit" or kind == "burst" then n else 1
					end
				end
			end
		end
		peakParticles = math.max(peakParticles, particles)
		peakBig = math.max(peakBig, big)
		peakEmitters = math.max(peakEmitters, emitters)
		peakLights = math.max(peakLights, lights)
		tau += STEP
	end
	return peakParticles, peakBig, peakEmitters, peakLights
end

-- The distinct looks among the rows: rows that repeat one look (a burst fired again, the four arcs of a ring) are one
-- layer, which starts when its first row does.
local function layersOf(rows: { Row }): { Row }
	local seen: { [string]: Row } = {}
	local list: { Row } = {}
	for _, row in ipairs(rows) do
		if isLayer(row) then
			local key = string.format(
				"%s|%s|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f",
				row.kind,
				row.tex,
				row.size,
				row.bright,
				row.light,
				row.a0,
				row.a1,
				row.life,
				row.size0
			)
			local layer: Row? = seen[key]
			if layer then
				table.insert(layer.rows, row)
				layer.first = math.min(layer.first, row.t)
			else
				layer = { tex = row.tex, kind = row.kind, size = row.size, bright = row.bright, light = row.light }
				layer.first = row.t
				layer.rows = { row }
				seen[key] = layer
				table.insert(list, layer)
			end
		end
	end
	return list
end

local function pct(x: number): string
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end

local function nearestTo(layer: Row, second: number): number
	local best = math.huge
	for _, row in ipairs(layer.rows) do
		best = math.min(best, math.abs(row.t - second))
	end
	return best
end

-- Reads the recorded rows against the bar of Part 3 and the budgets of Part 9. Pure.
function Probe.judge(rows: { Row }, meta: Meta): Verdict
	local hit = meta.hit
	local endT = meta.endT or math.max(meta.length, hit + 1.5)
	local fails: { string } = {}
	local notes: { string } = {}
	local layers = layersOf(rows)
	local lights: { Row } = {}
	local screens: { string } = {}
	local manual = 0
	for _, row in ipairs(rows) do
		if row.kind == "light" then
			table.insert(lights, row)
		elseif row.kind == "screen" then
			table.insert(screens, row.name)
		end
		if row.manual and row.hidden ~= true then
			manual += 1
		end
	end

	local stats: { [string]: any } = { layers = #layers, screens = #screens, unseen = manual, lights = #lights }
	local dots, shaped, maxSize, maxBright, minLight = 0, 0, 0, 0, 1
	for _, layer in ipairs(layers) do
		if Probe.DOTS[layer.tex] then
			dots += 1
		else
			shaped += 1
		end
		maxSize = math.max(maxSize, layer.size)
		maxBright = math.max(maxBright, layer.bright)
		minLight = math.min(minLight, layer.light)
	end
	stats.dots, stats.shaped, stats.maxSize, stats.maxBright = dots, shaped, maxSize, maxBright
	stats.dotShare = if #layers > 0 then dots / #layers else 0

	if #layers == 0 then
		table.insert(fails, "nothing recorded (no layer made through the kit or on its own)")
	else
		-- dots: a layer of plain sprites only (Part 3, rule 2)
		if stats.dotShare > 0.5 then
			table.insert(fails, string.format("dots %d of %d layers (%s)", dots, #layers, pct(stats.dotShare)))
		end
		if shaped == 0 then
			table.insert(fails, "no layer with a shaped texture or mesh")
		end

		-- moments (Part 3, rule 1)
		if meta.loop then
			local ignition = false
			for _, row in ipairs(rows) do
				if row.kind == "burst" and row.hidden ~= true and row.t <= 0.6 then
					ignition = true
				end
			end
			if not ignition then
				table.insert(fails, "no ignition burst")
			end
			if #layers < 4 then
				table.insert(fails, string.format("%d layers (a loop needs 4)", #layers))
			end
		else
			local gather = false
			for _, row in ipairs(rows) do
				if isLayer(row) and row.t < hit - 0.05 then
					gather = true
				end
			end
			if not gather then
				table.insert(fails, "no gather (nothing starts before the hit)")
			end
			-- (the largest and the brightest layer: the one that scores best on both, each as a share of the most)
			local peak: Row? = nil
			local best = -1
			for _, layer in ipairs(layers) do
				local score = (if maxSize > 0 then layer.size / maxSize else 0)
					+ (if maxBright > 0 then layer.bright / maxBright else 0)
				if score > best then
					best, peak = score, layer
				end
			end
			if peak then
				local off = nearestTo(peak, hit)
				stats.peakTex, stats.peakOff = peak.tex, off
				if off > 0.05 then
					table.insert(fails, string.format("biggest layer (%s) starts %.2f s off the hit", peak.tex, off))
				end
			end
			local residue = false
			for _, row in ipairs(rows) do
				if isLayer(row) and aliveTo(row, endT) > hit + 1.0 then
					residue = true
				end
			end
			if not residue then
				table.insert(fails, "no residue (nothing alive 1 s after the hit)")
			end
		end

		-- pops: a particle that arrives or leaves all at once
		local popIn, popOut = {}, {}
		for _, layer in ipairs(layers) do
			for _, row in ipairs(layer.rows) do
				if row.particle and row.size > 0 then
					if row.life > 0.6 and row.a0 < 0.5 and row.size0 > row.size / 3 then
						if not table.find(popIn, row.tex) then
							table.insert(popIn, row.tex)
						end
					end
					if row.a1 < 0.9 and row.size1 > math.max(row.size * 0.05, 0.05) then
						if not table.find(popOut, row.tex) then
							table.insert(popOut, row.tex)
						end
					end
				end
			end
		end
		if #popIn > 0 then
			table.insert(fails, "pops in: " .. table.concat(popIn, ", "))
		end
		if #popOut > 0 then
			table.insert(fails, "pops out: " .. table.concat(popOut, ", "))
		end
		stats.popIn, stats.popOut = #popIn, #popOut

		-- values (Part 3, rules 3 and 4)
		if maxSize > 3 and minLight >= 0.5 then
			table.insert(fails, "no dark layer (every layer adds light)")
		end
		if maxBright < 2 then
			table.insert(fails, string.format("no core (brightest layer %.1f, needs 2)", maxBright))
		end
	end

	-- light: on the beat for tier sealed and up (Part 3, rule 5)
	local tier = meta.tier or "free"
	local onBeat = false
	for _, row in ipairs(lights) do
		if row.t <= hit + 0.1 and aliveTo(row, endT) >= hit then
			onBeat = true
		end
	end
	stats.lightOnBeat = onBeat
	if (tier == "sealed" or tier == "condemned" or tier == "godhood") and not onBeat then
		table.insert(fails, "no light on the beat")
	end

	-- cost, against Part 9's budget
	local budget = Probe.BUDGETS[meta.budget or "accent"] or Probe.BUDGETS.accent
	local peakParticles, peakBig, peakEmitters, peakLights = peaks(rows, endT)
	peakParticles, peakBig = math.floor(peakParticles + 0.5), math.floor(peakBig + 0.5)
	stats.peakParticles, stats.peakBig, stats.peakEmitters, stats.peakLights =
		peakParticles, peakBig, peakEmitters, peakLights
	stats.budget = meta.budget or "accent"
	if peakParticles > budget.particles then
		table.insert(fails, string.format("%d particles alive (budget %d)", peakParticles, budget.particles))
	end
	if peakBig > budget.big then
		table.insert(fails, string.format("%d big sprites alive (budget %d)", peakBig, budget.big))
	end
	if peakEmitters > budget.emitters then
		table.insert(fails, string.format("%d emitters alive (budget %d)", peakEmitters, budget.emitters))
	end
	if peakLights > budget.lights then
		table.insert(fails, string.format("%d lights alive (budget %d)", peakLights, budget.lights))
	end

	if manual > 0 then
		table.insert(notes, string.format("%d layer(s) emitted by hand: their counts are not seen", manual))
	end
	if meta.estimated then
		table.insert(notes, "the hit is a guess")
	end

	return { pass = #fails == 0, fails = fails, notes = notes, stats = stats }
end

-- One line for the log: PASS or FAIL with the reasons, then the numbers.
function Probe.line(id: string, verdict: Verdict): string
	local s = verdict.stats
	local head = if verdict.pass then "PASS" else "FAIL"
	local reasons = if #verdict.fails > 0 then " <- " .. table.concat(verdict.fails, "; ") else ""
	return string.format(
		"[FxReport] %s %s%s | layers %d, dots %s | peak %d particles%s, %d big, %d emitters, %d lights (%s budget)",
		head,
		id,
		reasons,
		s.layers,
		pct(s.dotShare),
		s.peakParticles,
		if s.unseen > 0 then " (+" .. s.unseen .. " by hand)" else "",
		s.peakBig,
		s.peakEmitters,
		s.peakLights,
		s.budget
	)
end

return Probe
