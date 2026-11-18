--!strict
-- Impact and slam (the plan's V2.5, against art/refs/vfx/hit_slam.toml): a blow is a cut, not a growth.
--
--   gather   specks drawn in to the point just before the blow (the ref's hard cut: the beat before it is still)
--   hit      one blown-out frame: the impact sheet (white-hot core), a star on it, the shock ring, sparks thrown
--   body     the dark puff laid over (light 0), chips of the floor thrown and falling, dust rolling on the floor
--   residue  a few flakes of ash hanging and one thin thread of smoke, 2 to 3 s
--
-- The three styles are three sheets: sharp (VfxImpactA), heavy (VfxImpactB), soft (VfxImpactC). A one-shot sheet of 16
-- frames lives at least a 16th of 30 s per frame (Flipbook rates cap at 30), so the impact particles live 0.55 s or more.

local Defs = require(script.Parent.Defs)
local Ease = require(script.Parent.Parent.Ease)
local Emit = require(script.Parent.Parent.Emit)
local Ground = require(script.Parent.Parent.Ground)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local Screen = require(script.Parent.Parent.Screen)
local Shape = require(script.Parent.Parent.Shape)
local C = require(script.Parent.Common)

local Impact = {}

export type Options = {
	style: string?, -- "sharp" (default), "heavy" or "soft"
	ramp: Palette.Ramp?, -- shop callers pass a full-colour ramp; the default is the world's pale grey
	dust: Palette.Ramp?, -- the floor dust's ramp (the world's dust by default)
	scale: number?,
	ground: boolean?, -- on the floor: the ring lies flat, dust rolls, the floor cracks
	shake: boolean?, -- the camera feels it (this player's own screen; none under Reduce motion)
	flash: boolean?, -- the scene flashes (big blows only)
	lead: number?, -- seconds from the call to the hit
}

local STYLES = {
	sharp = { tex = "VfxImpactA", life = 0.55, size = 4.4, sparks = 16, chips = 6, dark = 4, ring = 3.2, shake = 0.8 },
	heavy = { tex = "VfxImpactB", life = 0.6, size = 5.4, sparks = 12, chips = 9, dark = 5, ring = 4, shake = 1.8 },
	soft = { tex = "VfxImpactC", life = 0.6, size = 5, sparks = 5, chips = 0, dark = 5, ring = 3.4, shake = 0.5 },
} :: {
	[string]: {
		tex: string,
		life: number,
		size: number,
		sparks: number,
		chips: number,
		dark: number,
		ring: number,
		shake: number,
	},
}

local function build(at: CFrame, o: Options, name: string, onFloor: boolean): () -> ()
	local st = STYLES[name] or STYLES.sharp
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local dust = o.dust or Palette.WORLD.dust
	local s = o.scale or 1
	local lead = o.lead or Defs.STYLE_LEAD[name] or 0.2
	local pos = at.Position
	local heavy = name == "heavy"
	return Moment.play(at, {
		lead = lead,
		residueAfter = 0.8, -- (after the hit layers have gone: at most six emitters alive together)
		gather = function()
			C.gather(pos, ramp, 2.2 * s, lead, 8, 0.45 * s)
		end,
		hit = function()
			local size = st.size * s
			local lay: { face: string?, speed: number? } = if onFloor then { face = "flat", speed = 0.001 } else {}
			Emit.burst(at, {
				{
					{
						tex = st.tex,
						ramp = hot,
						size = C.size(st.tex, size, { { 0, size * 0.5 }, { 0.16, size }, { 1, size * 1.12 } }),
						alpha = { { 0, 0 }, { 0.55, 0.1 }, { 1, 1 } },
						life = st.life,
						rot = { 0, 360 },
						bright = 1.25, -- (hot ramp already starts white: more only blows the sheet's shading out)
						z = 2,
					},
					1,
				},
				{
					{
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", size * 0.4, { { 0, 0 }, { 0.3, size * 0.4 }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.3,
						rot = { -14, 14 },
						bright = 1.6,
						z = 3,
					},
					1,
				},
				{
					{
						tex = "VfxShock",
						ramp = ramp,
						size = C.size(
							"VfxShock",
							st.ring * s,
							{ { 0, st.ring * s * 0.3 }, { 0.5, st.ring * s * 0.9 }, { 1, st.ring * s } }
						),
						alpha = { { 0, 0.5 }, { 0.5, 0.6 }, { 1, 1 } },
						life = 0.45,
						face = lay.face,
						speed = lay.speed,
						bright = 0.9,
						z = 1,
					},
					1,
				},
				{
					{
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.7 * s }, { 1, 0.15 * s } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
						life = { 0.35, 0.75 },
						speed = { 26 * s, 56 * s },
						drag = 3,
						accel = Vector3.new(0, -48 * s, 0),
						spread = if onFloor then 70 else 170,
						face = "along",
						bright = 1.5,
					},
					st.sparks,
				},
			})
			C.beat(pos + at.UpVector * 0.5, ramp[1], 18 * s, 3.2 * s)
			if o.shake then
				Screen.shakeAt(pos, st.shake * s, 0.35)
			end
			if o.flash then
				Screen.flash(ramp[1], 0.22, 0.25)
			end
			if onFloor and heavy then
				-- a dome of light snapping out of the floor and gone
				Shape.grow("dome", at, {
					size = 7 * s,
					from = 0.2,
					seconds = 0.14,
					fade = 0.16,
					ease = Ease.outExpo,
					color = ramp[1],
					transparency = 0.6,
					grow = 1.2,
				})
			end
		end,
		body = function()
			local list: { any } = {
				{
					{
						-- (the dark layer: laid over the scene, never added)
						tex = "VfxSmokePuff",
						ramp = shade,
						size = C.size(
							"VfxSmokePuff",
							st.dark * s,
							{ { 0, st.dark * s * 0.4 }, { 1, st.dark * s * 1.2 } }
						),
						alpha = { { 0, 1 }, { 0.1, 0.3 }, { 0.6, 0.5 }, { 1, 1 } },
						life = { 2, 2.3 },
						accel = Vector3.new(0, 1.2, 0),
						light = 0,
						lit = 0.2,
						z = -1,
					},
					1,
				},
			}
			if st.chips > 0 then
				table.insert(list, {
					{
						tex = "VfxShards",
						ramp = ramp,
						size = { { 0, 0.7 * s, 0.35 * s }, { 1, 0.55 * s, 0.28 * s } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0 }, { 1, 1 } },
						life = { 0.6, 1 },
						speed = { 10 * s, 24 * s },
						accel = Vector3.new(0, -60 * s, 0),
						spread = if onFloor then 55 else 120,
						spin = { -300, 300 },
						rot = { 0, 360 },
						light = 0.35,
						lit = 0.6,
					},
					st.chips,
				})
			end
			if onFloor then
				table.insert(list, {
					{
						tex = "VfxDustRoll",
						ramp = dust,
						size = C.size("VfxDustRoll", 6 * s, { { 0, 3 * s }, { 1, 7 * s } }),
						alpha = { { 0, 1 }, { 0.1, 0.35 }, { 0.7, 0.55 }, { 1, 1 } },
						life = { 2.1, 2.4 },
						speed = { 2, 4 },
						drag = 1.5,
						face = "up",
						light = 0,
						lit = 0.5,
					},
					1,
				})
				Ground.mark(pos, at.UpVector, "VfxScorch", 6 * s, Color3.fromRGB(150, 150, 155), 2.2, { fadeOut = 1.2 })
				Ground.mark(pos, at.UpVector, "VfxCrackA", 8 * s, Color3.fromRGB(170, 170, 175), 2.6, { fadeOut = 1.2 })
				if heavy then
					Ground.debris(pos, math.floor(5 * s + 0.5), { size = 0.6 * s, speed = 22 * s, life = 1.6 })
				end
			end
			Emit.burst(at, list)
		end,
		residue = function()
			Emit.burst(at, {
				{
					{
						tex = "VfxAshFlakes",
						ramp = dust,
						size = { { 0, 0.75 * s }, { 1, 0.55 * s } },
						alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.7, 0.3 }, { 1, 1 } },
						life = { 2, 3 },
						speed = { 1 * s, 3 * s },
						spread = 160,
						accel = Vector3.new(0.5, 0.6, 0),
						drag = 1.5,
						rot = { 0, 360 },
						spin = if C.still() then 0 else { -120, 120 },
						light = 0.45,
						lit = 0.6,
					},
					8,
				},
				{
					{
						-- (one thin thread of smoke standing up from the middle: the ref's leftover)
						tex = "VfxSmokePlume",
						ramp = {
							Color3.fromRGB(190, 190, 196),
							Color3.fromRGB(140, 140, 146),
							Color3.fromRGB(90, 90, 96),
						},
						size = { { 0, 1 * s }, { 1, 2.4 * s } },
						alpha = { { 0, 1 }, { 0.2, 0.45 }, { 0.8, 0.6 }, { 1, 1 } },
						life = 2.5,
						speed = 0.6,
						accel = Vector3.new(0, 1.4, 0),
						light = 0.3,
						lit = 0.6,
					},
					1,
				},
			})
		end,
	})
end

-- A blow at `at` (its up the surface's; the world's up for a blow in the air).
function Impact.impact(at: CFrame, options: Options?): () -> ()
	local o = options or {}
	local name = o.style
	return build(at, o, if name ~= nil and STYLES[name] ~= nil then name else "sharp", o.ground == true)
end

-- A landing on the floor: the heavy impact laid flat, the floor cracked and scorched, a dome, dust and debris. The camera
-- feels it unless told not to.
function Impact.slam(at: CFrame, options: Options?): () -> ()
	local o = table.clone(options or {}) :: Options
	o.scale = o.scale or 1.15
	o.lead = o.lead or 0.26
	if o.shake == nil then
		o.shake = true
	end
	return build(at, o, "heavy", true)
end

-- (what the styles are, for the spec)
Impact.STYLES = STYLES

return Impact
