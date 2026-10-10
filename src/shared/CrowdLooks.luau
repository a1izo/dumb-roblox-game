--!strict
-- How the Tokyo crowd looks. The server builds a few bodies once (Maps/Mechanics/TokyoDistrict/Looks)
-- and every client clones them for its walkers; which body a walker wears is worked out from its
-- number and the match's seed, the same on every client. Four in five wear the players' own dark suit
-- (so a player among them is one more suit), the rest are other commuters: coats, a few with umbrellas
-- (suits never carry one, as no player does). Faces, hair and skin vary.
--
-- Hair and faces are Roblox's own free catalog items (CrowdLooks.hairIds and faceIds: change the lists
-- to change the crowd). A body Roblox could not dress (no web access in a test) gets hair built from
-- a few parts and the default face instead; so does every body when a list is empty.

local CrowdLooks = {}

CrowdLooks.SUITS = 16
CrowdLooks.COMMUTERS = 4
CrowdLooks.COUNT = CrowdLooks.SUITS + CrowdLooks.COMMUTERS

CrowdLooks.hairIds = {
	63690008, -- Pal Hair
	63690008,
	62234425, -- Brown Hair
	62234425,
	376548738, -- Brown Charmer Hair
	376548738,
	62724852, -- Chestnut Bun
	62724852,
	376524487, -- Blonde Spiked Hair
	2956239660, -- Belle of Belfast Long Red Hair
} :: { number }
CrowdLooks.faceIds = {
	86487700, -- Man Face
	86487766, -- Woman Face
	144075659, -- Smile
} :: { number }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

CrowdLooks.SKIN = {
	rgb(241, 211, 186),
	rgb(234, 196, 166),
	rgb(222, 180, 146),
	rgb(204, 160, 124),
	rgb(182, 136, 100),
	rgb(150, 106, 76),
	rgb(116, 80, 58),
	rgb(86, 58, 44),
}
CrowdLooks.HAIR = {
	rgb(18, 16, 16),
	rgb(26, 22, 20),
	rgb(40, 30, 24),
	rgb(64, 44, 30),
	rgb(92, 88, 86),
	rgb(150, 146, 140),
}
CrowdLooks.STYLES = { "crop", "part", "bob", "bun", "crop", "part", "bald" }
-- Mostly the red tie every player starts with.
CrowdLooks.TIES =
	{ rgb(190, 22, 36), rgb(190, 22, 36), rgb(190, 22, 36), rgb(24, 40, 96), rgb(70, 72, 78), rgb(96, 18, 40) }
-- A commuter's coat and trousers.
CrowdLooks.COATS = {
	{ rgb(168, 148, 112), rgb(44, 42, 44) },
	{ rgb(62, 78, 66), rgb(34, 34, 38) },
	{ rgb(40, 52, 84), rgb(70, 66, 62) },
	{ rgb(112, 112, 116), rgb(28, 28, 32) },
}
CrowdLooks.UMBRELLAS = { rgb(16, 16, 20), rgb(22, 30, 60), rgb(200, 204, 208) }

export type Look = {
	suit: boolean,
	skin: Color3,
	hair: Color3,
	style: string,
	tie: Color3?,
	coat: Color3?,
	trousers: Color3?,
	umbrella: Color3?,
	hairId: number?,
	faceId: number?,
}

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

-- The look of body `index` (1 to COUNT: the suits first, then the commuters).
function CrowdLooks.make(index: number, rng: Random): Look
	local suit = index <= CrowdLooks.SUITS
	local look: Look = {
		suit = suit,
		skin = pick(CrowdLooks.SKIN, rng),
		hair = pick(CrowdLooks.HAIR, rng),
		style = pick(CrowdLooks.STYLES, rng),
		hairId = if #CrowdLooks.hairIds > 0 then pick(CrowdLooks.hairIds, rng) else nil,
		faceId = if #CrowdLooks.faceIds > 0 then pick(CrowdLooks.faceIds, rng) else nil,
	}
	if suit then
		look.tie = pick(CrowdLooks.TIES, rng)
	else
		local coat = CrowdLooks.COATS[(index - CrowdLooks.SUITS - 1) % #CrowdLooks.COATS + 1]
		look.coat, look.trousers = coat[1], coat[2]
		-- Every other commuter carries an umbrella.
		if (index - CrowdLooks.SUITS) % 2 == 1 then
			look.umbrella = pick(CrowdLooks.UMBRELLAS, rng)
		end
	end
	return look
end

-- Which body walker `number` wears, of `count` built: someone standing at a post (a clerk) is never in
-- a suit; everyone else is spread over all of them.
function CrowdLooks.bodyFor(number: number, seed: number, standing: boolean, count: number): number
	if count <= 0 then
		return 0
	end
	local commuters = math.min(CrowdLooks.COMMUTERS, count)
	if standing then
		return count - commuters + (number + seed) % commuters + 1
	end
	return (number * 7 + seed) % count + 1
end

return CrowdLooks
