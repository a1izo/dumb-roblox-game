--!strict
-- The fresh recipes (the VFX rework, ticket V2.5, docs/handoff/vfx-rework-plan-2026-11-16.md): the effects remade on the new
-- kit, each built on Vfx/Moment (gather, hit, body, residue), each with a dark layer, a white-hot core and a light on the
-- beat, each from the new textures (Vfx/Sheets), each against its reference file in art/refs/vfx. They sit BESIDE the old
-- Vfx/Recipes and FxKit, which are not touched: no caller uses these yet, the pilot (V3.1 to V3.3) moves callers one at a
-- time after the owner's verdict. Require it as
--
--   local Fresh = require(Presentation.Vfx.Fresh)        -- (it is not in Vfx/init yet: that is the pilot's one line)
--   Fresh.impact(CFrame.new(point), { style = "heavy", ramp = Palette.rarity("sealed") })
--
-- Every recipe takes `ramp` (Vfx/Palette): shop callers pass a full-colour ramp, world callers a grey one (the world's pale
-- by default). A recipe returns a cancel (stops the moments not yet run); a loop or a held effect returns a handle.
--
--   impact(at: CFrame, { style = "sharp" | "heavy" | "soft", ramp, dust, scale, ground, shake, flash, lead })
--   slam(at: CFrame, { ramp, dust, scale, shake, flash, lead })
--   slash(at: CFrame, { ramp, scale, angle, floor, shake, lead })
--   glint(at: CFrame | Vector3, { ramp, scale, lead })
--   pillar(at: CFrame, { ramp, height, radius, seconds, lead })
--   flame(parent: Instance, { kind = "candle" | "fire" | "aura", scale, ramp, light, lit }) -> { set, flare, out, destroy }
--   fireBurst(at: CFrame, { ramp, scale, ground, lead })
--   smokePuff(at: CFrame | Vector3, { ramp, scale, rise, lead })
--   dustKick(at: CFrame, { ramp, scale, dir, lead })
--   dissolve(parts: { BasePart }, seconds, { ramp, wind, rise, scale, fade, order, light, lead })
--   arc(from: Vector3, to: Vector3, { ramp, seconds, jag, shake, lead })
--   charge(at: CFrame | Vector3, { ramp, scale, radius }) -> { release, cancel }
--   sigil(at: CFrame, { ramp, size, hold, spin, lead })
--   scatter(at: CFrame, { kind = "paper" | "feathers" | "shards", ramp, scale, count, wind, flash, lead })
--   mist(at: CFrame | Vector3, { ramp, size, density }) -> { stop, destroy }
--   menace(chest: Vector3, { ramp, floor, size }) -> { stop, destroy }
--   tap(at, { ramp, scale, flat, sparks, gather, light, lead }), stepDust(at: CFrame, { ramp, scale, dir, lead }), spores(at, { ramp, scale, lead })
--   breath(at: Vector3, { ramp, scale, dir, lead })  (a thin blown mist for a cough or a sigh)
--   flecks(at: CFrame, { ramp, scale, tex, count, fall, lead })  (a few loose pieces thrown up and falling: shavings, crumbs, chips)
--   scuff(at: CFrame, { ramp, scale, lead })  (a quick puff and a few sparks, gone inside 0.6 s, for a dance that steps every third of a second)
--     (the small accents of Fresh/Small, for emotes that fire on every beat or step)
--
-- Fresh.Defs is the pure declaration of all of them (textures, moments, parameters, booth variants).

local Charge = require(script.Charge)
local Fire = require(script.Fire)
local Floor = require(script.Floor)
local Gameplay = require(script.Gameplay)
local Impact = require(script.Impact)
local Menace = require(script.Menace)
local Scatter = require(script.Scatter)
local Shine = require(script.Shine)
local Slash = require(script.Slash)
local Small = require(script.Small)
local Smoke = require(script.Smoke)
local Win = require(script.Win)

local Fresh = {}

Fresh.Defs = require(script.Defs)

Fresh.impact = Impact.impact
Fresh.slam = Impact.slam
Fresh.slash = Slash.slash
Fresh.glint = Shine.glint
Fresh.pillar = Shine.pillar
Fresh.arc = Shine.arc
Fresh.charge = Charge.charge
Fresh.flame = Fire.flame
Fresh.fireBurst = Fire.fireBurst
Fresh.smokePuff = Smoke.smokePuff
Fresh.dustKick = Smoke.dustKick
Fresh.mist = Smoke.mist
Fresh.menace = Menace.menace
Fresh.dissolve = Scatter.dissolve
Fresh.scatter = Scatter.scatter
Fresh.sigil = Floor.sigil
Fresh.Small = Small
Fresh.Gameplay = Gameplay -- (stage 4d: dissolve, sparks, dust, haunt mist, dive crash, the eyes)
Fresh.Win = Win -- (the win cuts' fx kinds: wave, sparks, bloom, ring, dust and the held ones)
Fresh.tap = Small.tap
Fresh.stepDust = Small.stepDust
Fresh.spores = Small.spores
Fresh.scuff = Small.scuff
Fresh.breath = Small.breath
Fresh.flecks = Small.flecks

return Fresh
