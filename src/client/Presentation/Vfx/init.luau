--!strict
-- The VFX kit (the owner, 2026-10-24: "redo them and make ALL of them extremely high quality ... look at Ink Game's
-- vfx"; the bar set against Ink Game's emotes and Jujutsu Shenanigans' bursts): every effect in the game is layered
-- from these parts, never a single plain particle:
--
--   Tex     the textures by name (art/scripts/vfx/textures.py; the Fx props import carries them)
--   Clock   one clock for everything that moves (holdable for pictures)
--   Ease    the curves things move on
--   Emit    particles: bursts, held emitters
--   Shape   solid shapes grown and faded (Neon light, or textured)
--   Beams   ribbons, flat rings, lightning
--   Light   flashes and flicker
--   Screen  shake, flash, field-of-view punch, impact frames (this player's own screen; none under Reduce motion)
--   Ground  the floor under a point, marks on it, debris thrown from it
--   Rim     a body lit at its edges
--   Recipes the effects built from them (an impact, a flame, a pillar of light...), which the game's effects use
--
-- Everything lives in the camera (this client only), and nothing is made on Low graphics when the caller asks
-- Vfx.quiet() first.

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Governor = require(script.Parent.Parent.World.Governor)

local Vfx = {}

Vfx.Tex = require(script.Tex)
Vfx.Clock = require(script.Clock)
Vfx.Ease = require(script.Ease)
Vfx.Emit = require(script.Emit)
Vfx.Shape = require(script.Shape)
Vfx.Beams = require(script.Beams)
Vfx.Light = require(script.Light)
Vfx.Screen = require(script.Screen)
Vfx.Ground = require(script.Ground)
Vfx.Rim = require(script.Rim)
Vfx.Recipes = require(script.Recipes)

-- True when effects should be cut back (Low graphics, or the governor's cut of effects).
function Vfx.quiet(): boolean
	return Governor.low("emoteFx")
end

-- True under Reduce motion (no shakes, flashes or spins).
function Vfx.still(): boolean
	return Motion.isReduced()
end

return Vfx
