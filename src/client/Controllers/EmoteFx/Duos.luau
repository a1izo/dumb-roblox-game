-- The duos' contact beats: Cuffed Together and Match Point (EmoteFx.pock, the racket's pock, is in init.luau).
-- Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

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
FX.cuffedLead = accent(2.0, { 0.3 }, function(character)
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

FX.matchPointServe = function()
	return nothing
end

return FX
