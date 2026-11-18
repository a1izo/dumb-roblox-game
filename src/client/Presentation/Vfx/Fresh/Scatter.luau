--!strict
-- Scatter and dissolve (the plan's V2.5, against art/refs/vfx/paper_feathers.toml and dissolve_ash.toml): matter, lit by the
-- scene, each piece its own size, speed and turn; they leave by falling or by being carried off, not by fading.
--
--   scatter   paper, feathers or shards thrown and settling: a first few drift in, the burst (a spark at the throw), a second
--             thinner throw and a dark puff, and a few pieces lying flat on the floor after
--   dissolve  a body turning to ash from its feet up: a quiet beat (it dims), the first grains, the rest part by part with
--             the wind carrying them, then a few specks hanging after. Parts go in the order given, or by height.

local Clock = require(script.Parent.Parent.Clock)
local Ease = require(script.Parent.Parent.Ease)
local Emit = require(script.Parent.Parent.Emit)
local Ground = require(script.Parent.Parent.Ground)
local Light = require(script.Parent.Parent.Light)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)

local Scatter = {}

local KINDS = {
	paper = {
		tex = "VfxPaper",
		size = 1.0,
		life = { 2.4, 3.4 },
		speed = { 6, 20 },
		drag = 1.6,
		fall = -5,
		turn = 140,
		count = 14,
	},
	feathers = {
		tex = "VfxFeatherTumble",
		size = 0.9,
		life = { 3, 4.4 },
		speed = { 4, 14 },
		drag = 2,
		fall = -3,
		turn = 90,
		count = 12,
	},
	shards = {
		tex = "VfxShards",
		size = 0.55,
		life = { 0.9, 1.5 },
		speed = { 14, 30 },
		drag = 0.4,
		fall = -46,
		turn = 300,
		count = 12,
	},
} :: {
	[string]: {
		tex: string,
		size: number,
		life: { number },
		speed: { number },
		drag: number,
		fall: number,
		turn: number,
		count: number,
	},
}

local RAMPS = {
	paper = Palette.WORLD.bone,
	feathers = Palette.WORLD.pale,
	shards = Palette.WORLD.dust,
} :: { [string]: Palette.Ramp }

export type ScatterOptions = {
	kind: string?, -- "paper" (default), "feathers" or "shards"
	ramp: Palette.Ramp?,
	scale: number?,
	count: number?, -- pieces in the first throw
	wind: Vector3?, -- a push on them all (studs a second, sideways)
	flash: boolean?, -- a spark at the throw (true)
	lead: number?,
}

-- Pieces thrown from `at` (its up the way they fly).
function Scatter.scatter(at: CFrame, options: ScatterOptions?): () -> ()
	local o = options or {}
	local name = if o.kind ~= nil and KINDS[o.kind] ~= nil then o.kind else "paper"
	local k = KINDS[name]
	local ramp = o.ramp or RAMPS[name]
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local count = o.count or k.count
	local wind = o.wind or Vector3.new(2.5, 0, 1)
	local lead = o.lead or 0.2
	local pos = at.Position
	local still = C.still()
	-- one piece's spec: sizes uneven by the envelope, the fall as the kind has it, in and out soft so none pops
	local function piece(speedScale: number, life: { number }?): { [string]: any }
		return {
			tex = k.tex,
			ramp = ramp,
			size = { { 0, k.size * s, k.size * s * 0.5 }, { 1, k.size * s, k.size * s * 0.5 } },
			alpha = { { 0, 1 }, { 0.08, 0 }, { 0.8, 0 }, { 1, 1 } },
			life = life or k.life,
			speed = { k.speed[1] * s * speedScale, k.speed[2] * s * speedScale },
			spread = 75,
			drag = k.drag,
			accel = Vector3.new(0, k.fall, 0) + wind,
			rot = { 0, 360 },
			spin = if still then 0 else { -k.turn, k.turn },
			light = 0,
			lit = 0.65,
		}
	end
	return Moment.play(at, {
		lead = lead,
		gather = function()
			-- (no wind-up for paper: a first few ride in on the gust)
			local first = piece(0.3, nil)
			first.spread = 20
			Emit.burst(pos, first, 3)
		end,
		hit = function()
			local list: { any } = { { piece(1, nil), count } }
			if o.flash ~= false then
				table.insert(list, {
					{
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 1.8 * s, { { 0, 0 }, { 0.3, 1.8 * s }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.55,
						bright = 2.3,
						z = 2,
					},
					1,
				})
			end
			Emit.burst(at, list)
			C.beat(pos, ramp[1], 8 * s, 1.2 * s, 0.04)
		end,
		body = function()
			Emit.burst(at, {
				{ piece(0.6, nil), math.max(2, math.floor(count * 0.5)) },
				{
					{
						-- (the dark layer: a small puff under the throw, laid over)
						tex = "VfxSmokePuff",
						ramp = shade,
						size = C.size("VfxSmokePuff", 3.2 * s, { { 0, 1.2 * s }, { 1, 3.6 * s } }),
						alpha = { { 0, 1 }, { 0.15, 0.5 }, { 0.7, 0.65 }, { 1, 1 } },
						life = { 2.1, 2.4 },
						accel = Vector3.new(0, 0.8, 0),
						light = 0,
						lit = 0.2,
						z = -1,
					},
					1,
				},
			})
		end,
		residue = function()
			-- what has landed: a few pieces lying flat where the throw fell
			local floorAt, normal = Ground.at(pos, nil, 10)
			local side = normal:Cross(if math.abs(normal.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis).Unit
			local spot = CFrame.fromMatrix(floorAt + normal * 0.04, side, normal)
			local flat = piece(0, { 3.2, 3.6 })
			flat.face = "flat"
			flat.speed = 0.001
			flat.spread = 0
			flat.accel = Vector3.zero
			flat.drag = 0
			flat.alpha = { { 0, 1 }, { 0.1, 0 }, { 0.8, 0 }, { 1, 1 } }
			flat.size = { { 0, k.size * s * 0.9, k.size * s * 0.3 }, { 1, k.size * s * 0.9, k.size * s * 0.3 } }
			Emit.burst(spot, flat, 5, Vector3.new(6 * s, 0.05, 6 * s))
		end,
	})
end

export type DissolveOptions = {
	ramp: Palette.Ramp?, -- the ash's colours (the world's ash by default; shop callers pass the item's own)
	wind: Vector3?, -- where the ash is carried (studs a second, sideways)
	rise: number?, -- how fast it lifts
	scale: number?,
	fade: number?, -- seconds each part takes to go (0.55)
	order: string?, -- "up" (feet first, the default), "down" or "given"
	light: boolean?, -- a faint ember light on the body while it goes (true)
	lead: number?,
}

-- A body turning to ash: `parts` go over `seconds`. Returns a cancel for the parts not yet started.
function Scatter.dissolve(parts: { BasePart }, seconds: number, options: DissolveOptions?): () -> ()
	local o = options or {}
	local ramp = o.ramp or Palette.WORLD.ash
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local wind = o.wind or Vector3.new(3.2, 0, 1.2)
	local rise = o.rise or 2.2
	local s = o.scale or 1
	local fade = o.fade or 0.55
	local lead = o.lead or 0.3
	local list: { BasePart } = {}
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			table.insert(list, part)
		end
	end
	if #list == 0 then
		return function() end
	end
	local order = o.order or "up"
	if order == "up" then
		table.sort(list, function(a, b)
			return a.Position.Y < b.Position.Y
		end)
	elseif order == "down" then
		table.sort(list, function(a, b)
			return a.Position.Y > b.Position.Y
		end)
	end
	local sum = Vector3.zero
	for _, part in ipairs(list) do
		sum += part.Position
	end
	local centre = sum / #list
	local cancels: { () -> () } = {}

	-- The three emitters every part is torn through: made once, on one holder that moves to each part (a body of fifteen
	-- parts used to make forty-five emitters, alive three seconds each).
	local pool: { holder: Part, emitters: { ParticleEmitter } }? = nil
	local function emitThrough(part: BasePart, entries: { any })
		local made = pool
		if made == nil then
			local holder = Emit.point(part.CFrame, part.Size)
			local emitters: { ParticleEmitter } = {}
			local longest = 0
			for _, entry in ipairs(entries) do
				table.insert(emitters, Emit.make(holder, entry[1]))
				longest = math.max(longest, Emit.longest(entry[1]))
			end
			made = { holder = holder, emitters = emitters }
			pool = made
			Clock.after(seconds + longest + 0.5, function()
				holder:Destroy()
			end)
		end
		made.holder.Size = part.Size
		made.holder.CFrame = part.CFrame
		for index, entry in ipairs(entries) do
			made.emitters[index]:Emit(math.max(1, math.floor(entry[2] * Emit.share() + 0.5)))
		end
	end

	-- One part goes: torn into flakes carried off, embers at its edge, a thread of soot; the part itself fades.
	local function eat(part: BasePart)
		if not part.Parent then
			return
		end
		local size = part.Size
		local volume = math.clamp(size.X * size.Y * size.Z, 0.05, 4)
		local n = math.min(24, math.floor(8 + volume * 10))
		emitThrough(part, {
			{
				{
					tex = "VfxAshFlakes",
					ramp = ramp,
					size = { { 0, 0.3 * s, 0.1 * s }, { 0.7, 0.25 * s, 0.08 * s }, { 1, 0.1 * s } },
					alpha = { { 0, 1 }, { 0.12, 0.1 }, { 0.75, 0.2 }, { 1, 1 } },
					life = { 1.8, 3 },
					speed = { 0.5, 1.8 },
					spread = 180,
					accel = wind + Vector3.new(0, rise, 0),
					drag = 0.9,
					rot = { 0, 360 },
					spin = if C.still() then 0 else { -160, 160 },
					light = 0,
					lit = 0.65,
				},
				n,
			},
			{
				{
					-- (the edge still smouldering: the brightest thing in it)
					tex = "VfxSparks",
					ramp = hot,
					size = { { 0, 0.2 * s }, { 1, 0.05 * s } },
					alpha = { { 0, 1 }, { 0.08, 0 }, { 0.6, 0.2 }, { 1, 1 } },
					life = { 0.8, 1.6 },
					speed = { 0.3, 1.2 },
					spread = 180,
					accel = wind * 0.6 + Vector3.new(0, rise * 1.3, 0),
					drag = 1.2,
					face = "along",
					bright = 2.3,
				},
				math.floor(n * 0.3),
			},
			{
				{
					tex = "VfxSmokePlume",
					ramp = shade,
					size = { { 0, 0.4 * s }, { 1, 1.6 * s } },
					alpha = { { 0, 1 }, { 0.3, 0.8 }, { 1, 1 } },
					life = { 1.6, 2.6 },
					speed = { 0.2, 0.6 },
					spread = 60,
					accel = wind * 0.8 + Vector3.new(0, rise * 0.7, 0),
					light = 0,
					lit = 0.3,
				},
				2,
			},
		})
		-- the part goes: it darkens toward the ash, then is gone
		local c0, t0 = part.Color, part.Transparency
		local marks: { { inst: Instance, start: number } } = {}
		for _, d in ipairs(part:GetDescendants()) do
			if d:IsA("Decal") or d:IsA("Texture") then
				table.insert(marks, { inst = d, start = (d :: any).Transparency })
			end
		end
		Clock.tween(fade, Ease.inQuad, function(u)
			if not part.Parent then
				return
			end
			part.Transparency = t0 + (1 - t0) * u
			part.Color = c0:Lerp(ramp[3], 0.5 * u)
			for _, m in ipairs(marks) do
				if m.inst.Parent then
					(m.inst :: any).Transparency = m.start + (1 - m.start) * math.min(1, u * 1.25)
				end
			end
		end)
	end

	local cancelMoment = Moment.play(centre, {
		lead = lead,
		gather = function()
			-- the quiet before the first grain: the body dims toward the ash, and a first glint at its start
			local began = Clock.now()
			local colours: { [BasePart]: Color3 } = {}
			for _, part in ipairs(list) do
				colours[part] = part.Color
			end
			table.insert(
				cancels,
				Clock.every(function(_, now)
					local u = math.clamp((now - began) / math.max(lead, 0.05), 0, 1)
					for part, colour in pairs(colours) do
						if part.Parent then
							part.Color = colour:Lerp(ramp[3], 0.2 * u)
						end
					end
					return u < 1
				end)
			)
			C.gather(list[1].Position, ramp, 1.2 * s, lead, 5, 0.3 * s)
		end,
		hit = function()
			eat(list[1])
			if o.light ~= false then
				local holder = Emit.point(centre)
				local _, release = Light.hold(holder, ramp[2], 12, 1.1, 0.3)
				table.insert(
					cancels,
					Clock.after(seconds, function()
						release(0.9)
						Clock.after(1.2, function()
							holder:Destroy()
						end)
					end)
				)
			end
		end,
		body = function()
			for index = 2, #list do
				local wait = (index - 1) / #list * seconds
				local part = list[index]
				table.insert(
					cancels,
					Clock.after(wait, function()
						eat(part)
					end)
				)
			end
		end,
		residue = function()
			-- a few hundred would be too many: a handful of specks hanging wide, carried off
			Emit.burst(centre, {
				tex = "VfxAshFlakes",
				ramp = ramp,
				size = { { 0, 0.25 * s }, { 1, 0.15 * s } },
				alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.35 }, { 1, 1 } },
				life = { 2.4, 3.2 },
				speed = { 1, 3 },
				spread = 180,
				accel = wind + Vector3.new(0, 0.5, 0),
				drag = 1,
				light = 0,
				lit = 0.6,
			}, 8, Vector3.new(4, 5, 4))
		end,
	})
	return function()
		cancelMoment()
		for _, cancel in ipairs(cancels) do
			cancel()
		end
	end
end

return Scatter
