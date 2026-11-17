-- The fresh VFX recipes (Presentation/Vfx/Fresh, ticket V2.5): data only, nothing is drawn. Every recipe the ticket names has a
-- declaration, every texture it draws from is one the kit knows (Vfx/Sheets, or a single image or an old support sprite), the
-- moments it has run in the order gather, hit, body, residue round its lead (Vfx/Moment), the variants the debug booth lists are
-- sound (known recipe, known parameters of the right kind, known place and budget), and the catalogue has an entry for each.
-- The recipes themselves reach the client's modules (the camera, the screen), so a server spec cannot play them: that is the
-- booth's job (DebugPanel.fx.report("recipe_new_impact_sharp") and the rest) once the place has the scripts.

local StarterPlayer = game:GetService("StarterPlayer")

-- A module of the client's VFX kit by path (nil where the place has none: a bundle of server specs only).
local function kitModule(...: string): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, part in ipairs({ "Client", "Presentation", "Vfx", ... }) do
		node = if node then node:FindFirstChild(part) else nil
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

-- The recipes the ticket names (V2.5), by their function name.
local NAMED = {
	"impact",
	"slam",
	"slash",
	"glint",
	"pillar",
	"flame",
	"fireBurst",
	"smokePuff",
	"dustKick",
	"dissolve",
	"arc",
	"charge",
	"sigil",
	"scatter",
	"mist",
}

-- Textures that are not flipbook sheets but are still the kit's: the single images of V1.6 and the old support sprites.
local SINGLES = {
	VfxCrackA = true,
	VfxCrackB = true,
	VfxScorch = true,
	VfxSigil = true,
	VfxStreak = true,
	VfxEmber = true,
	VfxGlow = true,
	VfxRingBand = true,
}

local PLACES = {
	chest = true,
	floor = true,
	glint = true,
	pillar = true,
	flame = true,
	arc = true,
	charge = true,
	body = true,
	mist = true,
}

local BUDGETS = { world = true, accent = true, showpiece = true, scene = true }

local function setOf(list: { string }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, name in ipairs(list) do
		set[name] = true
	end
	return set
end

-- Whether a value is of the kind a parameter declares.
local function kindOf(value: any, kind: string): boolean
	if kind == "number" or kind == "boolean" or kind == "string" then
		return type(value) == kind
	elseif kind == "vector3" then
		return typeof(value) == "Vector3"
	elseif kind == "cframe" then
		return typeof(value) == "CFrame"
	elseif kind == "instance" then
		return typeof(value) == "Instance"
	elseif kind == "ramp" or kind == "list" then
		return type(value) == "table"
	end
	return false
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local defsModule = kitModule("Fresh", "Defs")
	local sheetsModule = kitModule("Sheets")
	local momentModule = kitModule("Moment")
	if not defsModule or not sheetsModule or not momentModule then
		-- (nothing to read here: the spec runs in a place that carries the client's scripts)
		return
	end
	local okDefs, Defs = pcall(require, defsModule)
	local okSheets, Sheets = pcall(require, sheetsModule)
	local okMoment, Moment = pcall(require, momentModule)

	describe("Fresh recipes' declarations", function()
		it("load on the server", function()
			expect(okDefs).to.equal(true)
			expect(okSheets).to.equal(true)
			expect(okMoment).to.equal(true)
		end)
		if not (okDefs and okSheets and okMoment) then
			return
		end

		local moments = setOf(Defs.MOMENTS)
		local types = setOf(Defs.TYPES)

		it("have every recipe the ticket names", function()
			for _, name in ipairs(NAMED) do
				expect(Defs.RECIPES[name] ~= nil).to.equal(true)
			end
		end)

		it("have the three impact styles", function()
			for _, style in ipairs({ "sharp", "heavy", "soft" }) do
				expect(type(Defs.STYLE_LEAD[style])).to.equal("number")
			end
		end)

		it("draw only from textures the kit knows, and name at least one", function()
			for name, recipe in pairs(Defs.RECIPES) do
				expect(#recipe.textures > 0).to.equal(true)
				for _, texture in ipairs(recipe.textures) do
					local known = Sheets.NEW[texture] ~= nil or SINGLES[texture] == true
					if not known then
						error(name .. " draws from the unknown texture " .. tostring(texture))
					end
				end
			end
		end)

		it("have moments in the order gather, hit, body, residue, and a sound lead", function()
			local order: { [string]: number } = {}
			for index, name in ipairs(Defs.MOMENTS) do
				order[name] = index
			end
			for name, recipe in pairs(Defs.RECIPES) do
				expect(type(recipe.lead)).to.equal("number")
				expect(recipe.lead >= 0).to.equal(true)
				expect(#recipe.moments > 0).to.equal(true)
				local last = 0
				for _, moment in ipairs(recipe.moments) do
					if not moments[moment] then
						error(name .. " has the unknown moment " .. tostring(moment))
					end
					expect(order[moment] > last).to.equal(true)
					last = order[moment]
				end
				-- (every recipe has the hit; only a loop may lack a gather)
				expect(table.find(recipe.moments, "hit") ~= nil).to.equal(true)
				if not recipe.loop then
					expect(table.find(recipe.moments, "gather") ~= nil).to.equal(true)
					expect(table.find(recipe.moments, "residue") ~= nil).to.equal(true)
				end
			end
		end)

		it("run through Moment in the declared order, the hit at the lead", function()
			local function noop() end
			for name, recipe in pairs(Defs.RECIPES) do
				local parts: { [string]: any } = { lead = recipe.lead }
				for _, moment in ipairs(recipe.moments) do
					parts[moment] = noop
				end
				local list = Moment.timeline(parts)
				expect(#list).to.equal(#recipe.moments)
				for index, entry in ipairs(list) do
					if entry.name ~= recipe.moments[index] then
						error(name .. "'s moments run in the wrong order")
					end
					if entry.name == "hit" then
						expect(math.abs(entry.at - recipe.lead) < 1e-6).to.equal(true)
					end
				end
			end
		end)

		it("declare parameters of known kinds, every recipe taking a ramp", function()
			for name, recipe in pairs(Defs.RECIPES) do
				for param, kind in pairs(recipe.params) do
					if not types[kind] then
						error(name .. "'s parameter " .. param .. " has the unknown kind " .. tostring(kind))
					end
				end
				expect(recipe.params.ramp).to.equal("ramp")
			end
		end)
	end)

	describe("Fresh recipes' booth variants", function()
		if not (okDefs and okSheets and okMoment) then
			return
		end

		it("have a unique id each, a known recipe, place and budget", function()
			local seen: { [string]: boolean } = {}
			for _, variant in ipairs(Defs.VARIANTS) do
				local id = Defs.idOf(variant)
				expect(string.sub(id, 1, 11)).to.equal("recipe_new_")
				if seen[id] then
					error(id .. " is used twice")
				end
				seen[id] = true
				expect(Defs.RECIPES[variant.call] ~= nil).to.equal(true)
				expect(PLACES[variant.place] == true).to.equal(true)
				expect(BUDGETS[variant.budget] == true).to.equal(true)
				expect(variant.length > 0).to.equal(true)
				expect(Defs.hitOf(variant) >= 0).to.equal(true)
			end
		end)

		it("pass only parameters the recipe declares, of the right kind", function()
			for _, variant in ipairs(Defs.VARIANTS) do
				local params = Defs.RECIPES[variant.call].params
				for key, value in pairs(variant.args) do
					local kind = params[key]
					if kind == nil then
						error(variant.id .. " passes the undeclared " .. tostring(key))
					end
					if not kindOf(value, kind) then
						error(variant.id .. " passes " .. tostring(key) .. " of the wrong kind")
					end
				end
			end
		end)

		it("cover every recipe, and every impact style", function()
			local called: { [string]: boolean } = {}
			local styles: { [string]: boolean } = {}
			for _, variant in ipairs(Defs.VARIANTS) do
				called[variant.call] = true
				if variant.call == "impact" then
					styles[variant.args.style] = true
				end
			end
			for _, name in ipairs(NAMED) do
				expect(called[name] == true).to.equal(true)
			end
			expect(styles.sharp and styles.heavy and styles.soft).to.equal(true)
		end)

		it("take the impact style's own lead", function()
			for _, variant in ipairs(Defs.VARIANTS) do
				if variant.call == "impact" then
					expect(Defs.hitOf(variant)).to.equal(Defs.STYLE_LEAD[variant.args.style])
				end
			end
		end)
	end)

	describe("Fresh recipes in the effects catalogue", function()
		local catalogModule = kitModule("Catalog")
		if not catalogModule or not okDefs then
			return
		end
		local ok, Catalog = pcall(require, catalogModule)
		if not ok then
			return
		end
		local built, list = pcall(function()
			return Catalog.build({ emotes = {} })
		end)
		if not built then
			return
		end

		it("has an entry for every variant, in the recipe family, and none is unsound", function()
			local byId: { [string]: any } = {}
			for _, entry in ipairs(list) do
				byId[entry.id] = entry
			end
			for _, variant in ipairs(Defs.VARIANTS) do
				local entry = byId[Defs.idOf(variant)]
				if not entry then
					error(Defs.idOf(variant) .. " is not in the catalogue")
				end
				expect(entry.family).to.equal("recipe")
				expect(entry.budget).to.equal(variant.budget)
			end
			for _, problem in ipairs(Catalog.check(list, {})) do
				if string.find(problem, "recipe_new_", 1, true) then
					error(problem)
				end
			end
		end)

		it("keeps the old recipes' entries", function()
			local ids: { [string]: boolean } = {}
			for _, entry in ipairs(list) do
				ids[entry.id] = true
			end
			for _, old in ipairs({
				"recipe_impact",
				"recipe_slam",
				"recipe_twinkle",
				"recipe_pillar",
				"recipe_dissolve",
			}) do
				expect(ids[old] == true).to.equal(true)
			end
		end)
	end)
end
