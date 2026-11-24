-- The duos' contact beats: Cuffed Together and Match Point (EmoteFx.pock, the racket's pock, is in init.luau).
-- Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local Fresh = require(script.Parent.Parent.Parent.Presentation.Vfx.Fresh)
local Palette = require(script.Parent.Parent.Parent.Presentation.Vfx.Palette)
local Pilot = require(script.Parent.Parent.Parent.Presentation.Vfx.Pilot)

local Common = require(script.Parent.Shared)
local nothing = Common.nothing
local burst = Common.burst
local accent = Common.accent
local hand = Common.hand

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

local STEEL = ColorSequence.new(Color3.fromRGB(230, 232, 238), Color3.fromRGB(150, 156, 166))

-- The duos and the strolls (Sealed and up) -----------------------------------------------------------------------

-- Cuffed Together: the chain clinks taut with a spark of steel at the cuff.
local cuffOld = accent(2.0, { 0.3 }, function(character)
	local at = hand(character, "Left")
	if at then
		burst(at, {
			color = STEEL,
			count = 5,
			size = 0.2,
			speed = NumberRange.new(2, 4),
			life = NumberRange.new(0.15, 0.3),
			spread = 120,
			gravity = 10,
			light = 1,
		})
	end
end)
-- On the new kit (stage 4b second batch, Pilot.on.cuffedLead; false = the old build above). One sentence: the chain snapping
-- taut, a cold blow of steel on the cuff (motif: chains, cold light). The five moments, by the clip (the chain comes taut at 0.3 s):
--   gather    0.14 to 0.3 s  specks of steel drawn in to the cuff
--   hit       0.3 s          a white-hot steel blow on the cuff (Fresh.impact, sharp, small) with its star, ring and sparks, a cold light
--   body      0.35 s on      the dark puff laid over it, links' chips thrown and falling
--   break-up  0.4 to 1.2 s   the sparks and chips fall and go out
--   residue   0.7 s on       a few flakes of steel dust hanging and one thread of smoke
-- (the accent fires CUFF_LEAD before the beat so the hit itself lands on it)
local CUFF_LEAD = 0.16
local STEEL_RAMP = Palette.pair(Color3.fromRGB(196, 206, 224), Color3.fromRGB(238, 244, 255))
local cuffFresh = accent(2.0, { 0.3 - CUFF_LEAD }, function(character)
	local at = hand(character, "Left")
	if at then
		Fresh.impact(CFrame.new(at), {
			style = "sharp",
			ramp = STEEL_RAMP,
			dust = STEEL_RAMP,
			scale = 0.5,
			lead = CUFF_LEAD,
		})
	end
end)
FX.cuffedLead = function(character, preview, phase)
	return (if Pilot.on.cuffedLead then cuffFresh else cuffOld)(character, preview, phase)
end

FX.matchPointServe = function()
	return nothing
end

return FX
