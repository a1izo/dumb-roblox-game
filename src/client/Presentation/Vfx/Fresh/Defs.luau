--!strict
-- The new recipes' declarations (VFX rework, ticket V2.5): which recipes there are, which textures each draws from, which of
-- the five moments it has, what it takes, and the variants the debug booth lists. Pure data and arithmetic (no Instances, no
-- other module), so a spec can read it and the catalogue can build its entries from it; the recipes themselves are in the
-- modules beside it (Fresh/init re-exports them).
--
-- Every recipe takes `ramp` (Vfx/Palette): shop callers pass a full-colour ramp, world callers a grey one (the default is
-- Palette.WORLD.pale). A recipe is built on Vfx/Moment, so its parts run gather, hit, body, residue round one hit time.

local Defs = {}

-- The moments, in the order they run (Vfx/Moment).
Defs.MOMENTS = { "gather", "hit", "body", "residue" }

-- The kinds of value a recipe's parameter can be.
Defs.TYPES = { "number", "boolean", "string", "ramp", "vector3", "cframe", "instance", "list" }

-- How the hit's lead (the seconds from the call to the hit) differs by impact style.
Defs.STYLE_LEAD = { sharp = 0.16, heavy = 0.26, soft = 0.2 } :: { [string]: number }

export type Recipe = {
	module: string, -- the module in Fresh/ that holds it
	lead: number, -- seconds from the call to the hit (a loop's ignition)
	textures: { string }, -- the VFX textures it draws from (Vfx/Sheets, Vfx/Tex)
	moments: { string }, -- the moments it has, in order
	params: { [string]: string }, -- parameter name -> kind (Defs.TYPES)
	loop: boolean?, -- burns until stopped (flame, mist), returns a handle
	handle: boolean?, -- returns a handle with more than a cancel (charge, flame, mist)
}

Defs.RECIPES = {
	impact = {
		module = "Impact",
		lead = 0.2,
		textures = {
			"VfxImpactA",
			"VfxImpactB",
			"VfxImpactC",
			"VfxGlint",
			"VfxShock",
			"VfxSparks",
			"VfxShards",
			"VfxSmokePuff",
			"VfxDustRoll",
			"VfxAshFlakes",
			"VfxSmokePlume",
			"VfxCrackA",
			"VfxScorch",
		},
		moments = { "gather", "hit", "body", "residue" },
		params = {
			style = "string", -- sharp, heavy or soft
			ramp = "ramp",
			dust = "ramp",
			scale = "number",
			ground = "boolean",
			shake = "boolean",
			flash = "boolean",
			lead = "number",
		},
	},
	slam = {
		module = "Impact",
		lead = 0.26,
		textures = {
			"VfxImpactB",
			"VfxGlint",
			"VfxShock",
			"VfxSparks",
			"VfxShards",
			"VfxSmokePuff",
			"VfxDustRoll",
			"VfxAshFlakes",
			"VfxSmokePlume",
			"VfxCrackA",
			"VfxScorch",
		},
		moments = { "gather", "hit", "body", "residue" },
		params = {
			ramp = "ramp",
			dust = "ramp",
			scale = "number",
			shake = "boolean",
			flash = "boolean",
			lead = "number",
		},
	},
	slash = {
		module = "Slash",
		lead = 0.18,
		textures = {
			"VfxSlashA",
			"VfxSlashB",
			"VfxShock",
			"VfxStreak",
			"VfxMist",
			"VfxSparks",
			"VfxAshFlakes",
		},
		moments = { "gather", "hit", "body", "residue" },
		params = {
			ramp = "ramp",
			scale = "number",
			angle = "number",
			floor = "boolean",
			shake = "boolean",
			lead = "number",
		},
	},
	glint = {
		module = "Shine",
		lead = 0.12,
		textures = { "VfxGlint", "VfxMist", "VfxSparks" },
		moments = { "gather", "hit", "body", "residue" },
		params = { ramp = "ramp", scale = "number", lead = "number" },
	},
	pillar = {
		module = "Shine",
		lead = 0.45,
		textures = { "VfxShock", "VfxStreak", "VfxSparks", "VfxScorch", "VfxSmokePuff" },
		moments = { "gather", "hit", "body", "residue" },
		params = { ramp = "ramp", height = "number", radius = "number", seconds = "number", lead = "number" },
	},
	arc = {
		module = "Shine",
		lead = 0.2,
		textures = { "VfxArc", "VfxGlint", "VfxSparks", "VfxSmokePuff", "VfxSmokePlume", "VfxScorch" },
		moments = { "gather", "hit", "body", "residue" },
		params = { ramp = "ramp", seconds = "number", jag = "number", shake = "boolean", lead = "number" },
	},
	charge = {
		module = "Shine",
		lead = 0,
		textures = {
			"VfxSparks",
			"VfxMist",
			"VfxEnergyWisp",
			"VfxGlint",
			"VfxImpactC",
			"VfxShock",
			"VfxSmokePuff",
			"VfxAshFlakes",
			"VfxSmokePlume",
		},
		moments = { "gather", "hit", "body", "residue" },
		handle = true,
		params = { ramp = "ramp", scale = "number", radius = "number" },
	},
	flame = {
		module = "Fire",
		lead = 0.3,
		textures = { "VfxCandle", "VfxFire", "VfxAuraFlame", "VfxSparks", "VfxSmokePlume", "VfxGlint", "VfxEmber" },
		moments = { "gather", "hit", "body", "residue" },
		loop = true,
		handle = true,
		params = {
			kind = "string",
			scale = "number",
			ramp = "ramp",
			light = "boolean",
			lit = "boolean",
			plain = "boolean",
			lightRange = "number",
			lightBrightness = "number",
			lightColor = "instance",
		},
	},
	fireBurst = {
		module = "Fire",
		lead = 0.22,
		textures = {
			"VfxFireBurst",
			"VfxGlint",
			"VfxSparks",
			"VfxSmokePuff",
			"VfxSmokePlume",
			"VfxAshFlakes",
			"VfxScorch",
		},
		moments = { "gather", "hit", "body", "residue" },
		params = { ramp = "ramp", scale = "number", ground = "boolean", lead = "number" },
	},
	smokePuff = {
		module = "Smoke",
		lead = 0.12,
		textures = { "VfxSmokePuff", "VfxSmokePlume", "VfxMist", "VfxGlint", "VfxSparks" },
		moments = { "gather", "hit", "body", "residue" },
		params = { ramp = "ramp", scale = "number", rise = "number", lead = "number" },
	},
	dustKick = {
		module = "Smoke",
		lead = 0.1,
		textures = { "VfxDustRoll", "VfxShards", "VfxMist", "VfxGlint", "VfxSparks" },
		moments = { "gather", "hit", "body", "residue" },
		params = { ramp = "ramp", scale = "number", dir = "vector3", lead = "number" },
	},
	mist = {
		module = "Smoke",
		lead = 0.3,
		textures = { "VfxMist", "VfxAshFlakes", "VfxSparks" },
		moments = { "hit", "body" },
		loop = true,
		handle = true,
		params = { ramp = "ramp", size = "number", density = "number" },
	},
	dissolve = {
		module = "Scatter",
		lead = 0.3,
		textures = { "VfxAshFlakes", "VfxSparks", "VfxSmokePlume", "VfxGlint" },
		moments = { "gather", "hit", "body", "residue" },
		params = {
			ramp = "ramp",
			wind = "vector3",
			rise = "number",
			scale = "number",
			fade = "number",
			order = "string", -- up (feet first), down or given
			light = "boolean",
			lead = "number",
		},
	},
	scatter = {
		module = "Scatter",
		lead = 0.2,
		textures = { "VfxPaper", "VfxFeatherTumble", "VfxShards", "VfxGlint", "VfxSmokePuff" },
		moments = { "gather", "hit", "body", "residue" },
		params = {
			kind = "string", -- paper, feathers or shards
			ramp = "ramp",
			scale = "number",
			count = "number",
			wind = "vector3",
			flash = "boolean",
			lead = "number",
		},
	},
	sigil = {
		module = "Floor",
		lead = 0.35,
		textures = { "VfxSigil", "VfxScorch", "VfxShock", "VfxSparks", "VfxSmokePlume" },
		moments = { "gather", "hit", "body", "residue" },
		params = { ramp = "ramp", size = "number", hold = "number", spin = "number", lead = "number" },
	},
} :: { [string]: Recipe }

-- What the debug booth lists: one entry per variant, id "recipe_new_<id>". `place` says where the booth puts it (chest,
-- floor, glint, pillar, flame, arc, charge, body, mist), `args` the options it passes, `length` the seconds worth watching,
-- `budget` the tier the effect report judges it by (Part 9 of the plan).
export type Variant = {
	id: string,
	label: string,
	call: string,
	args: { [string]: any },
	place: string,
	length: number,
	budget: string,
	loop: boolean?,
}

Defs.VARIANTS = {
	{
		id = "impact_sharp",
		label = "Impact, sharp",
		call = "impact",
		args = { style = "sharp" },
		place = "chest",
		length = 3,
		budget = "accent",
	},
	{
		id = "impact_heavy",
		label = "Impact, heavy",
		call = "impact",
		args = { style = "heavy" },
		place = "chest",
		length = 3,
		budget = "accent",
	},
	{
		id = "impact_soft",
		label = "Impact, soft",
		call = "impact",
		args = { style = "soft" },
		place = "chest",
		length = 3,
		budget = "accent",
	},
	{ id = "slam", label = "Slam", call = "slam", args = {}, place = "floor", length = 3.5, budget = "showpiece" },
	{ id = "slash", label = "Slash", call = "slash", args = {}, place = "chest", length = 2.5, budget = "showpiece" },
	{ id = "glint", label = "Glint", call = "glint", args = {}, place = "glint", length = 2.2, budget = "accent" },
	{
		id = "pillar",
		label = "Pillar",
		call = "pillar",
		args = { seconds = 1.6 },
		place = "pillar",
		length = 5,
		budget = "showpiece",
	},
	{
		id = "flame_candle",
		label = "Flame, candle",
		call = "flame",
		args = { kind = "candle" },
		place = "flame",
		length = 6,
		budget = "accent",
		loop = true,
	},
	{
		id = "flame_fire",
		label = "Flame, fire",
		call = "flame",
		args = { kind = "fire" },
		place = "flame",
		length = 6,
		budget = "accent",
		loop = true,
	},
	{
		id = "flame_aura",
		label = "Flame, aura",
		call = "flame",
		args = { kind = "aura" },
		place = "flame",
		length = 6,
		budget = "accent",
		loop = true,
	},
	{
		id = "fire_burst",
		label = "Fire burst",
		call = "fireBurst",
		args = {},
		place = "floor",
		length = 4,
		budget = "showpiece",
	},
	{
		id = "smoke_puff",
		label = "Smoke puff",
		call = "smokePuff",
		args = {},
		place = "chest",
		length = 4,
		budget = "accent",
	},
	{
		id = "dust_kick",
		label = "Dust kick",
		call = "dustKick",
		args = {},
		place = "floor",
		length = 4,
		budget = "accent",
	},
	{ id = "dissolve", label = "Dissolve", call = "dissolve", args = {}, place = "body", length = 6, budget = "scene" },
	{ id = "arc", label = "Arc (lightning)", call = "arc", args = {}, place = "arc", length = 3, budget = "showpiece" },
	{
		id = "charge",
		label = "Charge, then release",
		call = "charge",
		args = {},
		place = "charge",
		length = 4,
		budget = "accent",
	},
	{ id = "sigil", label = "Sigil", call = "sigil", args = {}, place = "floor", length = 6.5, budget = "showpiece" },
	{
		id = "scatter_paper",
		label = "Scatter, paper",
		call = "scatter",
		args = { kind = "paper" },
		place = "chest",
		length = 5,
		budget = "showpiece",
	},
	{
		id = "scatter_feathers",
		label = "Scatter, feathers",
		call = "scatter",
		args = { kind = "feathers" },
		place = "chest",
		length = 5,
		budget = "showpiece",
	},
	{
		id = "scatter_shards",
		label = "Scatter, shards",
		call = "scatter",
		args = { kind = "shards" },
		place = "chest",
		length = 4,
		budget = "showpiece",
	},
	{
		id = "mist",
		label = "Mist",
		call = "mist",
		args = {},
		place = "mist",
		length = 8,
		budget = "showpiece",
		loop = true,
	},
} :: { Variant }

-- The seconds from the start of a variant to its hit (a stated `lead` wins, then the impact style's, then the recipe's).
function Defs.hitOf(variant: Variant): number
	local given = variant.args.lead
	if type(given) == "number" then
		return given
	end
	if variant.call == "impact" then
		local style = variant.args.style
		return Defs.STYLE_LEAD[if type(style) == "string" then style else "sharp"] or Defs.RECIPES.impact.lead
	end
	return Defs.RECIPES[variant.call].lead
end

-- The booth id of a variant.
function Defs.idOf(variant: Variant): string
	return "recipe_new_" .. variant.id
end

return Defs
