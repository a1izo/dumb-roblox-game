--!strict
-- How the Tokyo crowd looks. The server builds a few bodies once (Maps/Mechanics/TokyoDistrict/Looks)
-- and every client clones them for its walkers; which body a walker wears is worked out from its
-- number and the match's seed, the same on every client. They are civilians, never in the players'
-- suit (the owner, 2026-10-28): coats, hoodies, office shirts, school uniforms, T-shirts; some carry a
-- bag or an umbrella. Faces, hair and skin vary.
--
-- Hair and faces are Roblox's own free catalog items (CrowdLooks.hairIds and faceIds: change the lists
-- to change the crowd). A body Roblox could not dress (no web access in a test) gets hair built from
-- a few parts and the default face instead; so does every body when a list is empty.

local CrowdLooks = {}

CrowdLooks.COUNT = 20

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
-- What a civilian wears: the kind (Maps/Mechanics/TokyoDistrict/Looks dresses each), the top's colour and the
-- trousers' (or skirt's). Muted, as a city's commuters are.
CrowdLooks.OUTFITS = {
	{ "coat", rgb(168, 148, 112), rgb(44, 42, 44) },
	{ "coat", rgb(62, 78, 66), rgb(34, 34, 38) },
	{ "coat", rgb(40, 52, 84), rgb(70, 66, 62) },
	{ "coat", rgb(112, 112, 116), rgb(28, 28, 32) },
	{ "hoodie", rgb(118, 120, 124), rgb(46, 60, 88) },
	{ "hoodie", rgb(30, 32, 36), rgb(52, 50, 48) },
	{ "hoodie", rgb(74, 82, 60), rgb(40, 44, 56) },
	{ "office", rgb(232, 234, 236), rgb(46, 48, 54) },
	{ "office", rgb(186, 206, 226), rgb(34, 40, 60) },
	{ "office", rgb(226, 222, 212), rgb(70, 66, 60) },
	{ "gakuran", rgb(22, 22, 28), rgb(22, 22, 28) },
	{ "sailor", rgb(236, 236, 238), rgb(30, 36, 70) },
	{ "tee", rgb(200, 196, 188), rgb(56, 72, 104) },
	{ "tee", rgb(120, 40, 44), rgb(44, 56, 84) },
	{ "tee", rgb(40, 40, 44), rgb(150, 140, 120) },
}
CrowdLooks.UMBRELLAS = { rgb(16, 16, 20), rgb(22, 30, 60), rgb(200, 204, 208) }

export type Look = {
	skin: Color3,
	hair: Color3,
	style: string,
	kind: string, -- "coat", "hoodie", "office", "gakuran", "sailor", "tee"
	top: Color3,
	trousers: Color3,
	bag: boolean,
	umbrella: Color3?,
	hairId: number?,
	faceId: number?,
}

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

-- The look of body `index` (1 to COUNT): every outfit in turn, so each kind is in the crowd.
function CrowdLooks.make(index: number, rng: Random): Look
	local outfit = CrowdLooks.OUTFITS[(index - 1) % #CrowdLooks.OUTFITS + 1]
	local kind = outfit[1] :: string
	local look: Look = {
		skin = pick(CrowdLooks.SKIN, rng),
		hair = pick(CrowdLooks.HAIR, rng),
		style = pick(CrowdLooks.STYLES, rng),
		kind = kind,
		top = outfit[2] :: Color3,
		trousers = outfit[3] :: Color3,
		-- students and hoodies mostly carry a backpack, some T-shirts a tote
		bag = kind == "gakuran"
			or kind == "sailor"
			or (kind == "hoodie" and index % 2 == 1)
			or (kind == "tee" and index % 3 == 0),
		hairId = if #CrowdLooks.hairIds > 0 then pick(CrowdLooks.hairIds, rng) else nil,
		faceId = if #CrowdLooks.faceIds > 0 then pick(CrowdLooks.faceIds, rng) else nil,
	}
	-- Every other coat and office shirt carries an umbrella.
	if (kind == "coat" or kind == "office") and index % 2 == 1 then
		look.umbrella = pick(CrowdLooks.UMBRELLAS, rng)
	end
	return look
end

-- Which body walker `number` wears, of `count` built: spread over all of them.
function CrowdLooks.bodyFor(number: number, seed: number, _standing: boolean, count: number): number
	if count <= 0 then
		return 0
	end
	return (number * 7 + seed) % count + 1
end

return CrowdLooks
