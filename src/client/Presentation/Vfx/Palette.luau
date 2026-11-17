--!strict
-- The VFX kit's colour ramps. A ramp is { core, body, edge }, three colours: the core is white-hot at a particle's birth, the
-- body carries it through the middle of its life and the edge is what it fades to at its death (Palette.sequence turns one
-- into the ColorSequence an emitter wears; an Emit spec takes `ramp = ...` in place of `color`).
--
-- Two kinds of ramp, by the house rules in docs/vfx.md:
--   * the WORLD's (Palette.WORLD, Palette.DANGER): effects of the world and of play keep rule 1: grey, bone and soft white;
--     red means danger and nothing else.
--   * the SHOP's (Palette.rarity, Palette.shop, Palette.emote): anything bought wears its own colour or its tier's at full
--     strength (the owner, 2026-11-16: "Yes, full colour"). The body is the item's colour as it is and the edge is a
--     darker, deeper shade of the same hue, never a grey.
-- Pure data and arithmetic: no Instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = {}

export type Ramp = { Color3 }

local WHITE = Color3.new(1, 1, 1)

-- A ramp from its three colours.
function Palette.ramp(core: Color3, body: Color3, edge: Color3): Ramp
	return { core, body, edge }
end

-- The ColorSequence of a ramp: three keypoints, the core at birth, the body at half its life, the edge at its death.
function Palette.sequence(ramp: Ramp): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, ramp[1]),
		ColorSequenceKeypoint.new(0.5, ramp[2]),
		ColorSequenceKeypoint.new(1, ramp[3]),
	})
end

-- A darker, deeper shade of the same hue (saturation kept or raised, value cut to about two fifths).
function Palette.deeper(color: Color3): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.1 + 0.04), v * 0.4)
end

-- The white-hot core of a colour: the colour most of the way to white.
function Palette.hot(color: Color3): Color3
	return color:Lerp(WHITE, 0.82)
end

-- A full-colour ramp for something bought: its colour as the body, the same colour deeper as the edge, white-hot in the
-- middle of it.
function Palette.shop(color: Color3): Ramp
	return { Palette.hot(color), color, Palette.deeper(color) }
end

-- A full-colour ramp from a colour and its paler accent (an emote's two colours): the accent is the core.
function Palette.pair(colour: Color3, accent: Color3): Ramp
	return { accent, colour, Palette.deeper(colour) }
end

-- The world's greys: pale at birth, a grey body, a dark edge.
Palette.WORLD = {
	ash = { Color3.fromRGB(245, 245, 242), Color3.fromRGB(168, 166, 162), Color3.fromRGB(58, 57, 56) },
	bone = { Color3.fromRGB(250, 246, 235), Color3.fromRGB(222, 214, 194), Color3.fromRGB(96, 90, 80) },
	smoke = { Color3.fromRGB(200, 200, 202), Color3.fromRGB(110, 110, 112), Color3.fromRGB(24, 24, 26) },
	soot = { Color3.fromRGB(120, 120, 120), Color3.fromRGB(48, 48, 49), Color3.fromRGB(10, 10, 11) },
	dust = { Color3.fromRGB(235, 230, 220), Color3.fromRGB(165, 158, 146), Color3.fromRGB(70, 66, 60) },
	pale = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 220, 228), Color3.fromRGB(90, 96, 106) },
} :: { [string]: Ramp }

-- Danger red: the game's warning, pink-white to red to a dark red. (Godhood's crimson is the tier's own, below.)
Palette.DANGER = { Color3.fromRGB(255, 226, 220), Color3.fromRGB(214, 48, 48), Color3.fromRGB(80, 10, 14) } :: Ramp

local byTier: { [string]: Ramp } = {}

-- The ramp of a rarity tier ("common" .. "godhood", src/shared/Rarity.luau; an unknown id counts as Scrawl), full colour.
function Palette.rarity(id: string?): Ramp
	local Rarity = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarity")) :: any
	local tier: string = Rarity.ORDER[Rarity.rank(id)]
	local ramp = byTier[tier]
	if not ramp then
		ramp = Palette.shop(Rarity.COLORS[tier])
		byTier[tier] = ramp
	end
	return ramp
end

-- Each emote's own colours, as the aura gives them (colour, accent): copied from AURAS in Controllers/EmoteFx/init.luau
-- (the emotes' colours are not changed here, so keep the two in step), and The Long Climb's green (Strolls.luau).
local EMOTE_COLOURS: { [string]: { Color3 } } = {
	writeAir = { Color3.fromRGB(240, 226, 190), Color3.fromRGB(255, 250, 236) },
	menacingPose = { Color3.fromRGB(150, 92, 205), Color3.fromRGB(232, 206, 255) },
	menacingPose2 = { Color3.fromRGB(214, 190, 120), Color3.fromRGB(255, 244, 210) },
	menacingPose3 = { Color3.fromRGB(110, 120, 220), Color3.fromRGB(210, 216, 255) },
	menacingPose4 = { Color3.fromRGB(196, 24, 44), Color3.fromRGB(255, 170, 170) },
	menacingPose5 = { Color3.fromRGB(120, 170, 232), Color3.fromRGB(220, 236, 255) },
	menacingPose6 = { Color3.fromRGB(214, 180, 96), Color3.fromRGB(255, 236, 190) },
	blindfoldLift = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(220, 240, 255) },
	blindfoldLiftUp = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(220, 240, 255) },
	justAsPlanned = { Color3.fromRGB(210, 30, 40), Color3.fromRGB(255, 200, 200) },
	finalBreakdown = { Color3.fromRGB(230, 60, 40), Color3.fromRGB(255, 210, 170) },
	newWorld = { Color3.fromRGB(255, 236, 180), Color3.fromRGB(255, 255, 255) },
	reapersEyes = { Color3.fromRGB(255, 30, 50), Color3.fromRGB(255, 160, 160) },
	theLongClimb = { Color3.fromRGB(64, 255, 118), Color3.fromRGB(225, 255, 235) },
}

local byEmote: { [string]: Ramp } = {}

-- An emote's own ramp by its clip id (nil for an emote with no colours of its own).
function Palette.emote(clip: string): Ramp?
	local known = byEmote[clip]
	if known then
		return known
	end
	local colours = EMOTE_COLOURS[clip]
	if not colours then
		return nil
	end
	local ramp = Palette.pair(colours[1], colours[2])
	byEmote[clip] = ramp
	return ramp
end

return Palette
