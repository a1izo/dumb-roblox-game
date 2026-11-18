--!strict
-- Sigil (the plan's V2.5, against art/refs/vfx/magic_circle.toml): a floor circle that is drawn in, held and burnt out.
--
--   gather   a small ring on the floor and specks drawn to the middle (the ref lights a disc before anything else)
--   hit      the circle snaps to full size, white-hot for a blink (the hot copy), then settles to the body colour over a dark
--            scorch laid under it (laid over, not added); the light comes up
--   body     rings lift off it and fade, the top ones first; embers rise from it while it is held
--   residue  it burns out at the end of the hold (embers, a thread of smoke) and leaves a scorch and one small glowing mark
--
-- The circle is a flat particle (the sigil picture, lit as light) so it can be brighter than a decal and turn slowly.

local Clock = require(script.Parent.Parent.Clock)
local Emit = require(script.Parent.Parent.Emit)
local Ground = require(script.Parent.Parent.Ground)
local Light = require(script.Parent.Parent.Light)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local Shape = require(script.Parent.Parent.Shape)
local C = require(script.Parent.Common)

local Floor = {}

export type SigilOptions = {
	ramp: Palette.Ramp?,
	size: number?, -- studs across (10)
	hold: number?, -- seconds it is held after it is drawn (2.6)
	spin: number?, -- degrees a second it turns (12; none under Reduce motion)
	lead: number?,
}

-- A circle on the floor at `at` (its up the floor's).
function Floor.sigil(at: CFrame, options: SigilOptions?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local size = o.size or 10
	local hold = o.hold or 2.6
	local lead = o.lead or 0.35
	local turn = if C.still() then 0 else (o.spin or 12)
	local pos = at.Position
	local up = at.UpVector
	local flat = { face = "flat", speed = 0.001 }
	return Moment.play(at, {
		lead = lead,
		residueAfter = hold + 0.1,
		gather = function()
			Emit.burst(at, {
				tex = "VfxShock",
				ramp = ramp,
				size = C.size("VfxShock", size * 0.4, { { 0, size * 0.1 }, { 1, size * 0.4 } }),
				alpha = { { 0, 0.2 }, { 0.6, 0.4 }, { 1, 1 } },
				life = 0.6,
				face = flat.face,
				speed = flat.speed,
				bright = 1.2,
			}, 1)
			C.gather(pos, ramp, size * 0.2, lead, 8, 0.4)
		end,
		hit = function()
			Emit.burst(at, {
				{
					{
						-- the circle itself, held: the body colour
						tex = "VfxSigil",
						ramp = ramp,
						size = { { 0, size * 0.55 }, { 0.15, size }, { 1, size * 1.03 } },
						alpha = { { 0, 1 }, { 0.06, 0.05 }, { 0.6, 0.1 }, { 0.85, 0.5 }, { 1, 1 } },
						life = hold + 1,
						face = flat.face,
						speed = flat.speed,
						rot = { 0, 360 },
						spin = { turn, turn },
						bright = 1.1,
						z = 1,
					},
					1,
				},
				{
					{
						-- the blink of white-hot as it snaps in: the brightest thing in it
						tex = "VfxSigil",
						ramp = hot,
						size = { { 0, size * 0.55 }, { 0.2, size }, { 1, size * 1.05 } },
						alpha = { { 0, 0 }, { 0.4, 0.15 }, { 1, 1 } },
						life = 0.55,
						face = flat.face,
						speed = flat.speed,
						rot = { 0, 360 },
						bright = 2.3,
						z = 2,
					},
					1,
				},
				{
					{
						-- the dark layer under it: a scorch, laid over the floor
						tex = "VfxScorch",
						ramp = shade,
						size = { { 0, size }, { 1, size * 1.15 } },
						alpha = { { 0, 1 }, { 0.1, 0.45 }, { 0.85, 0.55 }, { 1, 1 } },
						life = hold + 1.4,
						face = flat.face,
						speed = flat.speed,
						rot = { 0, 360 },
						light = 0,
						z = -1,
					},
					1,
				},
			})
			local holder = Emit.point(pos + up * 0.6)
			local _, release = Light.hold(holder, ramp[2], size * 1.3, 1.6, 0.2)
			Clock.after(hold + 0.2, function()
				release(0.6)
				Clock.after(0.9, function()
					holder:Destroy()
				end)
			end)
		end,
		body = function()
			-- rings lift off the circle and fade (the top one first)
			for k = 1, 2 do
				Clock.after((k - 1) * 0.2, function()
					Shape.grow("ring", at * CFrame.new(0, 0.3, 0), {
						size = size * 0.8,
						seconds = 0.25,
						hold = 0.4,
						fade = 0.7,
						rise = size * (0.35 + 0.2 * k),
						color = ramp[1],
						transparency = 0.5,
					})
				end)
			end
			-- embers rise from it while it is held
			local disc = Emit.point(at, Vector3.new(size * 0.9, 0.1, size * 0.9))
			local _, stop = Emit.hold(disc, {
				tex = "VfxSparks",
				ramp = hot,
				size = { { 0, 0.4 }, { 1, 0.1 } },
				alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
				life = { 0.9, 1.6 },
				speed = { 2, 6 },
				spread = 14,
				face = "along",
				rate = 14,
				bright = 1.3,
			})
			Clock.after(hold, function()
				stop()
				Clock.after(2, function()
					disc:Destroy()
				end)
			end)
		end,
		residue = function()
			-- burnt out: embers, a thread of smoke, a scorch and the one small mark that keeps glowing
			Emit.burst(at, {
				{
					{
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.5 }, { 1, 0.1 } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.6, 0.2 }, { 1, 1 } },
						life = { 0.8, 1.6 },
						speed = { 3, 9 },
						spread = 40,
						accel = Vector3.new(0, 2, 0),
						drag = 1,
						face = "along",
						bright = 1.5,
					},
					14,
				},
				{
					{
						tex = "VfxSmokePlume",
						ramp = shade,
						size = { { 0, size * 0.1 }, { 1, size * 0.25 } },
						alpha = { { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } },
						life = 2.6,
						speed = 0.6,
						accel = Vector3.new(0, 1.4, 0),
						light = 0,
						lit = 0.2,
					},
					2,
				},
				{
					{
						tex = "VfxShock",
						ramp = ramp,
						size = C.size("VfxShock", size * 0.25, { { 0, size * 0.1 }, { 1, size * 0.25 } }),
						alpha = { { 0, 1 }, { 0.3, 0.4 }, { 0.8, 0.5 }, { 1, 1 } },
						life = 2.4,
						face = flat.face,
						speed = flat.speed,
						bright = 1.2,
					},
					1,
				},
			}, nil, Vector3.new(size * 0.6, 0.1, size * 0.6))
			Ground.mark(pos, up, "VfxScorch", size * 0.9, Color3.fromRGB(150, 150, 155), 2.6, { fadeOut = 1.5 })
		end,
	})
end

return Floor
