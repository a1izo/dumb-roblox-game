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
--
-- Two of every three bodies wear marketplace clothes (CrowdLooks.MARKET, the user's ask of 2026-10-27: "give the
-- npcs more outfits with access to the marketplace"), the third one of the outfits built from parts below.

local CrowdLooks = {}

CrowdLooks.COUNT = 45

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

-- Marketplace outfits: a classic shirt and trousers (or a skirt) from the catalog, worn through the body's description,
-- and the kind (what it carries: a school uniform a backpack, some casual clothes a bag, some suits and coats an
-- umbrella). Picked 2026-10-29 from the catalog's best sellers and Roblox's own free clothes, each looked at: plain
-- city clothes, nothing branded, no costumes. An item the catalog takes down only drops that body back to clothes
-- built from parts (Looks.rigFor).
CrowdLooks.MARKET = {
	{ shirt = 6554200369, pants = 129459077, kind = "suit" }, -- Grey Suit w/ Black Vest; Black Slacks (Roblox)
	{ shirt = 12142438478, pants = 488531519, kind = "suit" }, -- suit (with a tie); Men's Dress Tuxedo Slacks
	{ shirt = 12116667358, pants = 2895512666, kind = "suit" }, -- black suit; Business Slacks
	{ shirt = 7285439133, pants = 7131176051, kind = "suit" }, -- Black Suit w Black Turtleneck; Black slacks
	{ shirt = 5549403612, pants = 129459077, kind = "suit" }, -- Suit vest w/ sleeves rolled up; Black Slacks
	{ shirt = 6553589977, pants = 6555794614, kind = "suit" }, -- White Suit w/ Black Vest, and its trousers
	{ shirt = 6937094487, pants = 488531519, kind = "suit" }, -- Black Tucked Turtleneck; Dress Tuxedo Slacks
	{ shirt = 6575384433, pants = 129459077, kind = "suit" }, -- brown v-neck vest; Black Slacks
	{ shirt = 7392097063, pants = 382537569, kind = "coat" }, -- coat; Black Jeans (Roblox)
	{ shirt = 14758728581, pants = 7189083561, kind = "coat" }, -- black vintage coat; all black pants
	{ shirt = 7722791678, pants = 129458426, kind = "coat" }, -- black Coat; Jeans (Roblox)
	{ shirt = 10287504307, pants = 7131176051, kind = "coat" }, -- open grey raincoat; Black slacks
	{ shirt = 98575693013073, pants = 144076760, kind = "coat" }, -- old raincoat; Dark Green Jeans (Roblox)
	{ shirt = 17460412787, pants = 12598481285, kind = "casual" }, -- grey jacket; grey cargo pants
	{ shirt = 398633584, pants = 398633812, kind = "casual" }, -- Denim Jacket with White Hoodie; Black Jeans with White Shoes (Roblox)
	{ shirt = 144076436, pants = 382538503, kind = "casual" }, -- Grey Striped Shirt with Denim Jacket; Black Jeans with Sneakers (Roblox)
	{ shirt = 382538295, pants = 382537569, kind = "casual" }, -- Guitar Tee with Black Jacket; Black Jeans (Roblox)
	{ shirt = 144076358, pants = 129458426, kind = "casual" }, -- Blue and Black Motorcycle Shirt; Jeans (Roblox)
	{ shirt = 4015873542, pants = 144076760, kind = "casual" }, -- beige plaid flannel over a white shirt; Dark Green Jeans
	{ shirt = 9069617976, pants = 129458426, kind = "casual" }, -- brown plaid flannel jacket; Jeans
	{ shirt = 5134719820, pants = 7189083561, kind = "casual" }, -- black flannel; all black pants
	{ shirt = 4380261167, pants = 2895512666, kind = "casual" }, -- black turtleneck; Business Slacks
	{ shirt = 10752453625, pants = 382538503, kind = "casual" }, -- grey and black striped sweater; Black Jeans with Sneakers
	{ shirt = 1175311558, pants = 6314613214, kind = "casual" }, -- white turtleneck sweater; black pleated skirt
	{ shirt = 6862266654, pants = 4899180116, kind = "casual" }, -- plaid sweater; white skirt
	{ shirt = 382537702, pants = 382537569, kind = "casual" }, -- Teal Shirt; Black Jeans (Roblox)
	{ shirt = 8468716504, pants = 7022487742, kind = "school" }, -- black school uniform (a gakuran's cut); school slacks
	{ shirt = 12642619432, pants = 6314613214, kind = "school" }, -- black school uniform; black pleated skirt
	{ shirt = 9689730981, pants = 6314613214, kind = "school" }, -- pale blue sailor uniform; black pleated skirt
	{ shirt = 8567427751, pants = 7022487742, kind = "school" }, -- high school shirt and tie; school slacks
}

export type Look = {
	skin: Color3,
	hair: Color3,
	style: string,
	kind: string, -- "coat", "hoodie", "office", "gakuran", "sailor", "tee"; a marketplace outfit's "suit", "coat", "casual", "school"
	top: Color3,
	trousers: Color3,
	bag: boolean,
	umbrella: Color3?,
	hairId: number?,
	faceId: number?,
	shirtId: number?, -- a marketplace outfit's (the top and trousers above stand in when the body is built from parts)
	pantsId: number?,
}

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

-- The look of body `index` (1 to COUNT): every third body one of the outfits built from parts, each in turn, so each
-- kind is in the crowd; the others the marketplace outfits, each once, in an order that mixes the kinds.
function CrowdLooks.make(index: number, rng: Random): Look
	local outfit = CrowdLooks.OUTFITS[(index - 1) % #CrowdLooks.OUTFITS + 1]
	if index % 3 == 0 then
		outfit = CrowdLooks.OUTFITS[(index // 3 - 1) % #CrowdLooks.OUTFITS + 1]
	end
	local market = if index % 3 ~= 0
		then CrowdLooks.MARKET[((index - index // 3) * 11) % #CrowdLooks.MARKET + 1]
		else nil
	local kind = if market then market.kind else outfit[1] :: string
	local look: Look = {
		skin = pick(CrowdLooks.SKIN, rng),
		hair = pick(CrowdLooks.HAIR, rng),
		style = pick(CrowdLooks.STYLES, rng),
		kind = kind,
		top = outfit[2] :: Color3,
		trousers = outfit[3] :: Color3,
		-- students and hoodies mostly carry a backpack, some T-shirts and casual clothes a tote
		bag = kind == "gakuran"
			or kind == "sailor"
			or kind == "school"
			or (kind == "hoodie" and index % 2 == 1)
			or (kind == "tee" and (index // 3) % 2 == 0)
			or (kind == "casual" and index % 4 == 1),
		hairId = if #CrowdLooks.hairIds > 0 then pick(CrowdLooks.hairIds, rng) else nil,
		faceId = if #CrowdLooks.faceIds > 0 then pick(CrowdLooks.faceIds, rng) else nil,
		shirtId = if market then market.shirt else nil,
		pantsId = if market then market.pants else nil,
	}
	-- Every other coat, suit and office shirt carries an umbrella.
	if (kind == "coat" or kind == "office" or kind == "suit") and index % 2 == 1 then
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
