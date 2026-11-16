-- The effects catalogue (Presentation/Vfx/Catalog, the debug booth's list of every effect in the game): data only, nothing
-- is played. Ids are unique, each entry is in a known family and tier, every emote clip given has its entry, and every
-- shop win cutscene, scene death, writing style, cover and Deathsinger form has one. The server cannot load the client's
-- EmoteFx, so the real list of clips with an effect is checked in a play test by FxBooth.verify(); here the clips are the
-- shop's own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

-- The catalogue module, from the client's scripts (nil where the place has none: a bundle of server specs only).
local function catalogModule(): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, name in ipairs({ "Client", "Presentation", "Vfx", "Catalog" }) do
		node = if node then node:FindFirstChild(name) else nil
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

-- The emote clips the shop names, and the free ones' (what Catalog.build is given where the game gives EmoteFx.clips()).
local FREE =
	{ "wave", "point", "cheer", "laugh", "dance", "salute", "bow", "shrug", "facepalm", "highFive", "handshake" }

local function emoteClips(): { string }
	local seen: { [string]: boolean } = {}
	local list: { string } = {}
	local function add(clip: any)
		if type(clip) == "string" and not seen[clip] then
			seen[clip] = true
			table.insert(list, clip)
		end
	end
	for _, clip in ipairs(FREE) do
		add(clip)
	end
	for _, raw in ipairs(Cosmetics.ITEMS) do
		local item = raw :: any
		if item.kind == "emote" then
			add(item.emote)
			add(item.alt)
		end
	end
	table.sort(list)
	return list
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local module = catalogModule()
	if not module then
		-- (nothing to read here: the spec runs in a place that carries the client's scripts)
		return
	end
	local ok, Catalog = pcall(require, module)

	describe("Effects catalogue", function()
		it("loads on the server with no client module required", function()
			expect(ok).to.equal(true)
		end)
		if not ok then
			return
		end

		local clips = emoteClips()
		local entries = Catalog.build({ emotes = clips, customDeaths = { "specCustom" } })
		local byId: { [string]: any } = {}
		for _, entry in ipairs(entries) do
			byId[entry.id] = entry
		end

		it("lists every family the plan names, in order", function()
			expect(table.concat(Catalog.FAMILIES, ",")).to.equal(
				"recipe,aura,emote,death,scenedeath,win,verdict,writing,cover,form,moment,world"
			)
		end)

		it("has unique ids, known families and tiers, sound numbers and a play function each", function()
			expect(#entries > 40).to.equal(true)
			expect(table.concat(Catalog.check(entries, clips), "; ")).to.equal("")
		end)

		it("names each id after its family", function()
			local prefix = { scenedeath = "scene" }
			for _, entry in ipairs(entries) do
				local expected = (prefix[entry.family] or entry.family) .. "_"
				expect(string.sub(entry.id, 1, #expected)).to.equal(expected)
			end
		end)

		it("has an entry for every emote clip given", function()
			expect(#clips > 20).to.equal(true)
			for _, clip in ipairs(clips) do
				expect(byId["emote_" .. clip] ~= nil).to.equal(true)
			end
		end)

		it("has no verdict entries (the verdict styles were taken out of the game 2026-11-16)", function()
			for _, entry in ipairs(entries) do
				expect(entry.family ~= "verdict").to.equal(true)
			end
		end)

		it("has an entry for every shop win cutscene, scene death, writing style, cover and form", function()
			for _, raw in ipairs(Cosmetics.ITEMS) do
				local item = raw :: any
				if item.kind == "win" and type(item.cut) == "string" then
					expect(byId["win_" .. item.cut] ~= nil).to.equal(true)
				elseif item.kind == "reason" and type(item.scene) == "number" and type(item.style) == "string" then
					expect(byId["scene_" .. item.style] ~= nil).to.equal(true)
				elseif item.kind == "writing" and type(item.style) == "string" then
					expect(byId["writing_" .. item.style] ~= nil).to.equal(true)
				elseif item.kind == "grimoire" and type(item.style) == "string" then
					expect(byId["cover_" .. item.style] ~= nil).to.equal(true)
				elseif item.kind == "specter" and type(item.form) == "string" then
					expect(byId["form_" .. item.form] ~= nil).to.equal(true)
				end
			end
		end)

		it("has every recipe and an aura at each level", function()
			for _, id in ipairs({
				"recipe_impact",
				"recipe_slam",
				"recipe_twinkle",
				"recipe_pillar",
				"recipe_flame_candle",
				"recipe_flame_fire",
				"recipe_dissolve",
				"aura_level1",
				"aura_level2",
				"aura_level3",
			}) do
				expect(byId[id] ~= nil).to.equal(true)
			end
		end)

		it("takes a whole scene's camera only for the entries marked whole", function()
			for _, entry in ipairs(entries) do
				if entry.family == "win" or entry.family == "scenedeath" or entry.family == "writing" then
					expect(entry.whole).to.equal(true)
				else
					expect(entry.whole == true).to.equal(false)
				end
			end
		end)

		-- (the check itself: it must catch what it is there to catch)
		it("catches a repeated id, an unknown family, a missing emote and a broken entry", function()
			local broken = table.clone(entries)
			table.insert(broken, entries[1])
			expect(table.concat(Catalog.check(broken, clips), "; ")).to.contain("used twice")

			local stray = table.clone(entries[1])
			stray.id = "recipe_stray"
			stray.family = "nonsense"
			expect(table.concat(Catalog.check({ stray }, nil), "; ")).to.contain("unknown family")

			local alone = Catalog.build({ emotes = {} })
			expect(table.concat(Catalog.check(alone, { "wave" }), "; ")).to.contain("emote clip wave has no entry")

			local lame = table.clone(entries[1])
			lame.id = "recipe_lame"
			lame.hit = -1
			lame.length = 0
			lame.play = nil
			local text = table.concat(Catalog.check({ lame }, nil), "; ")
			expect(text).to.contain("hit")
			expect(text).to.contain("length")
			expect(text).to.contain("cannot be played")
		end)
	end)
end
