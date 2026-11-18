--!strict
-- Things that come into being or leave it (the owner, 2026-10-25: "right now he just appears out of the ground ...
-- make them make sense (like materializing slowly)"): a model drawn together out of smoke and specks pulled in from
-- round it, filling in from its feet up with its edges lit, a flash as it is whole; and the same backwards, coming
-- apart from the top down into smoke that drifts away. Client only (a death god in a cutscene, the realm's figures).
--
--   Materialize.appear(model, { seconds = 1.6, color = Color3 })
--   Materialize.vanish(model, { seconds = 1.2, destroy = true })

local Vfx = require(script.Parent.Vfx)
local Pilot = require(script.Parent.Vfx.Pilot)
local Palette = require(script.Parent.Vfx.Palette)
local Common = require(script.Parent.Vfx.Fresh.Common)

local Materialize = {}

-- quiet: no smoke, no lit edge, no flash (a prop drawn into a hand)
export type Options = { seconds: number?, color: Color3?, destroy: boolean?, quiet: boolean? }

type Piece = { item: Instance, solid: number, height: number }

-- Every visible part and decal of the model, with how solid it is meant to be and how high it stands (0 feet .. 1
-- top).
local function pieces(model: Model): ({ Piece }, CFrame, Vector3)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local list: { Piece } = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			local solid = item:GetAttribute("DGMaterializeSolid")
			if type(solid) ~= "number" then
				solid = item.Transparency
				item:SetAttribute("DGMaterializeSolid", solid)
			end
			if (solid :: number) < 1 then
				local h = math.clamp((item.Position.Y - bottom) / math.max(size.Y, 0.1), 0, 1)
				table.insert(list, { item = item, solid = solid :: number, height = h })
			end
		elseif item:IsA("Decal") or item:IsA("Texture") then
			local solid = item:GetAttribute("DGMaterializeSolid")
			if type(solid) ~= "number" then
				solid = (item :: Decal).Transparency
				item:SetAttribute("DGMaterializeSolid", solid)
			end
			local parent = item.Parent
			local h = if parent and parent:IsA("BasePart")
				then math.clamp((parent.Position.Y - bottom) / math.max(size.Y, 0.1), 0, 1)
				else 0.5
			table.insert(list, { item = item, solid = solid :: number, height = h })
		end
	end
	return list, cf, size
end

local function setSeen(piece: Piece, seen: number)
	local t = 1 - (1 - piece.solid) * math.clamp(seen, 0, 1)
	if piece.item:IsA("BasePart") then
		(piece.item :: BasePart).Transparency = t
	else
		(piece.item :: any).Transparency = t
	end
end

-- The smoke and specks round the model: pulled in toward it (appearing) or let out from it (vanishing).
local function haze(cf: CFrame, size: Vector3, color: Color3, inward: boolean, seconds: number)
	local box = Vfx.Emit.point(cf, size + Vector3.new(3, 1, 3))
	local style = if inward then Enum.ParticleEmitterShapeInOut.Inward else Enum.ParticleEmitterShapeInOut.Outward
	local smoke = Vfx.Emit.make(box, {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = color:Lerp(Color3.new(0, 0, 0), 0.65),
		light = 0.05,
		lit = 0.3,
		size = if inward then { { 0, 3 }, { 1, 1 } } else { { 0, 1.2 }, { 1, 3.4 } },
		alpha = { { 0, 1 }, { 0.2, 0.45 }, { 0.75, 0.55 }, { 1, 1 } },
		life = { 0.7, 1.1 },
		speed = { 2, 5 },
		rot = { 0, 360 },
		spin = { -40, 40 },
		rate = 34,
		shape = Enum.ParticleEmitterShape.Box,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		shapeInOut = style,
	})
	local specks = Vfx.Emit.make(box, {
		tex = "VfxEmber",
		color = color,
		size = { { 0, 0.16 }, { 1, 0 } },
		life = { 0.5, 0.9 },
		speed = { 4, 8 },
		bright = 1.5,
		rate = 50,
		shape = Enum.ParticleEmitterShape.Box,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		shapeInOut = style,
	})
	Vfx.Clock.after(seconds, function()
		smoke.Enabled = false
		specks.Enabled = false
	end)
	Vfx.Clock.after(seconds + 1.3, function()
		box:Destroy()
	end)
end

-- THE SMOKE AND SPECKS ON THE NEW KIT (the VFX rework, stage 4a; Pilot.on.materialize = false brings the old haze back).
-- One sentence: a figure is drawn out of a bank of its own colour's mist and cold specks, and leaves the same way; its
-- motif is smoke and ash. Five moments:
--   gather    0.0 s   specks pulled in from round the model (appear) or the model's own edge let go (vanish)
--   hit       the end of the fill: a white-hot four-point glint at its middle and a light that falls three times slower
--             (appear only; the lit edge of Vfx/Rim runs under the whole fill)
--   body      the bank: mist of the colour, a darker bank laid behind it (never added), the specks, all fed by hand
--   break-up  the emitters stop together at 0.8 of the time, so the bank thins out by its own lives
--   residue   a few flakes of ash left drifting for 2 to 3 s
local function hazeFresh(cf: CFrame, size: Vector3, color: Color3, inward: boolean, seconds: number)
	local ramp = Palette.pair(color, color:Lerp(Color3.new(1, 1, 1), 0.55))
	local hot, shade = Common.hotter(ramp), Common.shadow(ramp)
	local box = Vfx.Emit.point(cf, size + Vector3.new(3, 1, 3))
	local style = if inward then Enum.ParticleEmitterShapeInOut.Inward else Enum.ParticleEmitterShapeInOut.Outward
	local function common(spec: { [string]: any }): { [string]: any }
		spec.shape = Enum.ParticleEmitterShape.Box
		spec.shapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		spec.shapeInOut = style
		return spec
	end
	local feeds: { { e: ParticleEmitter, per: number, owed: number } } = {}
	local function layer(spec: { [string]: any })
		local per = spec.rate :: number
		spec.rate = nil
		table.insert(feeds, { e = Vfx.Emit.make(box, common(spec)), per = per, owed = 0 })
	end
	layer({
		tex = "VfxMist",
		ramp = ramp,
		size = if inward then { { 0, 3.2 }, { 1, 1.4 } } else { { 0, 1.6 }, { 1, 3.6 } },
		alpha = { { 0, 1 }, { 0.2, 0.25 }, { 0.75, 0.35 }, { 1, 1 } },
		life = { 0.8, 1.2 },
		speed = { 1.5, 4 },
		rot = { 0, 360 },
		spin = if Vfx.still() then 0 else { -30, 30 },
		rate = 26,
		light = 0.7,
		lit = 0.15,
		bright = 1.1,
	})
	layer({
		tex = "VfxMist",
		ramp = shade,
		size = if inward then { { 0, 3.6 }, { 1, 1.6 } } else { { 0, 1.8 }, { 1, 3.8 } },
		alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.75, 0.32 }, { 1, 1 } },
		life = { 0.9, 1.3 },
		speed = { 1, 3 },
		rot = { 0, 360 },
		rate = 16,
		light = 0,
		lit = 0.25,
		z = -1,
	})
	layer({
		tex = "VfxSparks",
		ramp = hot,
		size = { { 0, 0.4 }, { 1, 0.1 } },
		alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
		life = { 0.5, 0.9 },
		speed = { 4, 8 },
		face = "along",
		rate = 40,
		bright = 1.5,
	})
	local over = Vfx.Clock.now() + seconds
	local stop = Vfx.Clock.every(function(dt, now)
		if now >= over then
			return false
		end
		for _, one in ipairs(feeds) do
			one.owed += one.per * dt * Vfx.Emit.share()
			local n = math.floor(one.owed)
			if n > 0 then
				one.owed -= n
				one.e:Emit(n)
			end
		end
		return true
	end)
	-- (the residue: a few flakes of ash drifting)
	Vfx.Clock.after(seconds, function()
		stop()
		Vfx.Emit.burst(cf.Position, {
			tex = "VfxAshFlakes",
			ramp = hot,
			size = { { 0, 0.5 }, { 1, 0.35 } },
			alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.35 }, { 1, 1 } },
			life = { 2, 3 },
			speed = { 0.3, 1.2 },
			accel = Vector3.new(0, 0.6, 0),
			rot = { 0, 360 },
			light = 0.5,
			lit = 0.2,
		}, 8, size)
	end)
	Vfx.Clock.after(seconds + 3.4, function()
		box:Destroy()
	end)
end

local function smoke(cf: CFrame, size: Vector3, color: Color3, inward: boolean, seconds: number)
	if Pilot.on.materialize then
		hazeFresh(cf, size, color, inward, seconds)
	else
		haze(cf, size, color, inward, seconds)
	end
end

-- Draws `model` into being over `seconds`: it starts unseen, smoke and specks pull in round it, it fills in from the
-- feet up behind a lit edge, and a flash marks it whole.
function Materialize.appear(model: Model, options: Options?)
	local o = options or {}
	local seconds = o.seconds or 1.6
	local color = o.color or Color3.fromRGB(200, 40, 50)
	local list, cf, size = pieces(model)
	for _, piece in ipairs(list) do
		setSeen(piece, 0)
	end
	if not o.quiet then
		smoke(cf, size, color, true, seconds * 0.8)
	end
	-- (the lit edge only for a real appearance: a prop drawn into a hand comes in quietly)
	if not o.quiet then
		Vfx.Rim.glow(model, color, seconds, { fill = 0.25, fadeIn = seconds * 0.4, fadeOut = 0.6 })
	end
	Vfx.Clock.tween(seconds, Vfx.Ease.inOutSine, function(u)
		-- (a band of 0.35 of the height filling in as the front climbs from below the feet to over the head)
		local front = -0.35 + 1.7 * u
		for _, piece in ipairs(list) do
			setSeen(piece, (front - piece.height) / 0.35)
		end
	end, function()
		for _, piece in ipairs(list) do
			setSeen(piece, 1)
		end
		if not o.quiet then
			if Pilot.on.materialize then
				-- the hit: a white-hot four-point glint, and a light that falls three times slower than it rose
				Vfx.Emit.burst(cf.Position, {
					tex = "VfxGlint",
					ramp = Common.hotter(Palette.pair(color, color:Lerp(Color3.new(1, 1, 1), 0.55))),
					size = Common.size("VfxGlint", size.Y * 0.9, { { 0, 1 }, { 0.25, size.Y * 0.9 }, { 1, 0 } }),
					alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
					life = 0.4,
					rot = { 0, 360 },
					bright = 2.1,
					z = 3,
				}, 1)
				Common.beat(cf.Position, color, size.Y * 3, 3, 0.05)
			else
				Vfx.Emit.burst(cf.Position, {
					tex = "VfxFlare",
					color = color:Lerp(Color3.new(1, 1, 1), 0.5),
					size = { { 0, 1 }, { 0.25, size.Y * 0.9 }, { 1, 0 } },
					life = 0.3,
					rot = { 0, 360 },
					bright = 1.5,
				}, 1)
				Vfx.Light.flash(cf.Position, color, size.Y * 3, 3, 0.4)
			end
		end
	end)
end

-- Takes `model` out of being over `seconds`: it comes apart from the top down into smoke that drifts off (and is
-- destroyed after, when `destroy`).
function Materialize.vanish(model: Model, options: Options?)
	local o = options or {}
	local seconds = o.seconds or 1.2
	local color = o.color or Color3.fromRGB(200, 40, 50)
	local list, cf, size = pieces(model)
	if not o.quiet then
		smoke(cf, size, color, false, seconds)
	end
	if not o.quiet then
		Vfx.Rim.glow(model, color, seconds * 0.5, { fill = 0.3, fadeIn = 0.15, fadeOut = seconds * 0.5 })
	end
	Vfx.Clock.tween(seconds, Vfx.Ease.inOutSine, function(u)
		local front = 1.35 - 1.7 * u
		for _, piece in ipairs(list) do
			setSeen(piece, (piece.height - front) / -0.35)
		end
	end, function()
		for _, piece in ipairs(list) do
			setSeen(piece, 0)
		end
		if o.destroy then
			model:Destroy()
		end
	end)
end

return Materialize
