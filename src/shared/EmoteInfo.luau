--!strict
-- What an emote clip is and what it needs, in one place: its shop item (Shared/Cosmetics: its name, lobby-only,
-- stroll, duo, stance, rarity) and its clip's description (Anim/EmoteMeta: props set on the floor, an emote that
-- is mostly legs, a private cutscene, how strong its effects are, a loud sound, a press-to-do moment). The rules
-- (Shared/EmotePolicy), the server, the wheel and the checks all read it from here.

local Cosmetics = require(script.Parent.Cosmetics)
local EmoteMeta = require(script.Parent.Anim.EmoteMeta) :: any

local EmoteInfo = {}

export type Context = {
	label: string, -- the button's word ("LOOK UP")
	from: number, -- seconds into the clip the button shows
	to: number,
	branch: string, -- the clip pressing it plays (from where the emote is)
	-- or, `altChance` of the time, this one instead (push your luck: ADD ONE's tower falls), picked by the server
	alt: string?,
	altChance: number?,
}

export type Info = {
	clip: string,
	item: Cosmetics.Item?,
	name: string,
	rarity: string,
	lobbyOnly: boolean,
	duo: boolean,
	stroll: boolean,
	stance: boolean,
	floorProps: boolean, -- sets something down on the floor (a chair, a tower): nothing for a seated body
	lowBody: boolean, -- its legs are the point (a collapse, a crouch, a leap): not while seated
	cinematic: boolean, -- has a private cutscene for its owner (lobby only)
	fx: number, -- how strong its effects are: 0 none .. 4 the cutscene emotes (EmotePolicy caps it in a case)
	loud: boolean, -- its sound would carry over a case (kept quiet there)
	context: Context?,
	-- a group dance's places for those who join in, round the one they join: { x, z } studs in that dancer's
	-- frame (x to their right, z behind them), at most 5 (6 dancing with the first)
	formation: { { number } }?,
	-- others near may Join in: the dances and the group celebrations only (the user's call of 2026-10-27), never a
	-- pose, an emote with props, a stroll, a stance or a duo (the server and the prompt both read it)
	joinable: boolean,
}

-- Effects by rarity, when the clip's description does not say (the VFX ladder: Scrawl motion accents only,
-- Penned one small accent, Sealed a tailored effect with light, Condemned layered, Godhood the cutscene).
-- (Scrawl and everyone's emotes a small accent each: the owner's Q21, 2026-10-21)
local FX_BY_RARITY: { [string]: number } = { common = 1, rare = 1, epic = 2, legendary = 3, godhood = 4 }

local cache: { [string]: Info } = {}

function EmoteInfo.of(clip: string): Info
	local cached = cache[clip]
	if cached then
		return cached
	end
	local item = Cosmetics.emote(clip)
	local meta = EmoteMeta[clip] or {}
	local floorProps = false
	for _, prop in ipairs(meta.props or {}) do
		if prop.mount == "floor" then
			floorProps = true
		end
	end
	local rarity = if item then item.rarity else "common"
	local info: Info = {
		clip = clip,
		item = item,
		name = if item then item.name else clip,
		rarity = rarity,
		lobbyOnly = (item ~= nil and item.lobbyOnly == true) or meta.lobbyOnly == true,
		-- (a free duo has no shop item: its meta says so)
		duo = (item ~= nil and item.duo == true) or meta.duo == true,
		stroll = item ~= nil and item.stroll == true,
		stance = item ~= nil and item.stance == true,
		floorProps = floorProps,
		lowBody = meta.lowBody == true,
		cinematic = meta.cinematic == true,
		fx = if type(meta.fx) == "number" then meta.fx else (FX_BY_RARITY[rarity] or 0),
		loud = meta.loud == true,
		context = meta.context,
		formation = meta.formation,
		joinable = false,
	}
	local dance = meta.joinable == true or (item ~= nil and item.category == "dance")
	info.joinable = (dance or meta.formation ~= nil) and not info.stroll and not info.stance and not info.duo
	cache[clip] = info
	return info
end

return EmoteInfo
