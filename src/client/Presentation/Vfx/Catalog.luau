--!strict
-- The effects catalogue (the VFX rework, ticket V0.1, docs/handoff/vfx-rework-plan-2026-11-16.md): every effect in the
-- game as one entry, so any of them can be played alone, by name, in the debug booth (Debug/FxBooth) and held at a
-- chosen moment. An entry never copies an effect's code: its play() calls what the game itself calls (a recipe, an
-- aura, EmoteFx.play for an emote, the cutscene gallery's WinCinema.preview for a whole scene).
--
--   { id, family, source, tier, hit, length, play }
--     id      "<family>_<name>", unique
--     family  one of Catalog.FAMILIES
--     source  where it comes from, in words (the call it makes)
--     tier    free (no shop tier), scrawl, penned, sealed, condemned or godhood (Shared/Rarity)
--     hit     the second its main beat lands, counted from the start of play()
--     length  the seconds worth watching
--     play    play(stage) starts it on the stage's dummy and returns a stop function
--   and, where it applies: label (the button's words), budget (docs plan Part 9: world, accent, showpiece or scene),
--   whole (a whole scene that takes the player's own camera, so the booth hands the camera over), loop (it burns
--   until stopped), estimated (its `hit` is a guess: the emote's first accent beat is known, a showpiece's is not).
--
-- The stage the booth gives play(): { body: an R6 dummy, root, floor: the point on the floor under it, at: a CFrame
-- there (up is the world's; the body faces its look vector), props: a folder for anything an entry makes that is not
-- the effect's own, preview: whether an emote plays as the shop's preview does, done: a whole scene calls it when it
-- ends on its own }.
--
-- This module reads shared data only when it is required (so a server spec can load it); the client's own modules are
-- required when an effect plays. Catalog.get() builds the list from the game; Catalog.build(sources) builds it from the
-- lists given (the spec's).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clips = require(Shared:WaitForChild("Anim"):WaitForChild("Clips"):WaitForChild("Index")) :: any
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local DeathCuts = require(Shared:WaitForChild("Cinema"):WaitForChild("DeathCuts")) :: any
local Rarity = require(Shared:WaitForChild("Rarity"))
local WinCuts = require(Shared:WaitForChild("Cinema"):WaitForChild("WinCuts")) :: any

local Catalog = {}

Catalog.FAMILIES = {
	"recipe",
	"aura",
	"emote",
	"death",
	"scenedeath",
	"win",
	"verdict", -- (the verdict styles were taken out of the game 2026-11-16: no entries)
	"writing",
	"cover",
	"form",
	"moment",
	"world",
}

Catalog.TIERS = { "free", "scrawl", "penned", "sealed", "condemned", "godhood" }

-- What each family is called on the booth's buttons.
Catalog.FAMILY_NAMES = {
	recipe = "Recipes",
	aura = "Auras",
	emote = "Emotes",
	death = "Deaths",
	scenedeath = "Scene deaths",
	win = "Win cutscenes",
	verdict = "Verdicts",
	writing = "Writing styles",
	cover = "Manual covers",
	form = "Deathsinger forms",
	moment = "Moments",
	world = "World",
} :: { [string]: string }

export type Stage = {
	body: Model,
	root: BasePart,
	floor: Vector3,
	at: CFrame,
	props: Instance,
	preview: boolean,
	done: () -> (),
}

export type Entry = {
	id: string,
	family: string,
	source: string,
	tier: string,
	hit: number,
	length: number,
	play: (stage: Stage) -> () -> (),
	label: string,
	budget: string,
	whole: boolean?,
	loop: boolean?,
	estimated: boolean?,
}

export type Sources = {
	emotes: { string }?, -- the clip ids that have an effect (EmoteFx.clips())
	customDeaths: { string }?, -- the custom deaths' own effects (CustomDeaths.styles())
}

-- Reaching the client's modules ---------------------------------------------------------------------------------------

local client = script.Parent.Parent.Parent :: Instance

-- Requires a client module when an effect plays (never when this one loads: a server spec loads it too).
local function need(...: string): any
	local node: Instance = client
	for _, name in ipairs({ ... }) do
		node = node:WaitForChild(name)
	end
	return require(node :: ModuleScript)
end

local function vfx(): any
	return need("Presentation", "Vfx")
end

local function noop() end

-- How long a recipe waits before it fires, so the pictures can show the moment before it (the kit's clock, so holding
-- the clock holds it).
local LEAD = 0.3

-- Runs `fire` after the lead. Returns the stop.
local function later(seconds: number, fire: () -> ()): () -> ()
	return vfx().Clock.after(seconds, fire)
end

-- Small helpers -------------------------------------------------------------------------------------------------------

local function tierOf(rarity: string?): string
	if not rarity then
		return "free"
	end
	return string.lower(Rarity.NAMES[rarity] or "free")
end

local BUDGET_OF = {
	free = "accent",
	scrawl = "accent",
	penned = "accent",
	sealed = "showpiece",
	condemned = "showpiece",
	godhood = "scene",
} :: { [string]: string }

local function make(spec: { [string]: any }): Entry
	local tier = spec.tier or "free"
	local entry: Entry = {
		id = spec.id,
		family = spec.family,
		source = spec.source,
		tier = tier,
		hit = spec.hit or 0,
		length = spec.length or 4,
		play = spec.play,
		label = spec.label or spec.id,
		budget = spec.budget or BUDGET_OF[tier] or "accent",
		whole = spec.whole,
		loop = spec.loop,
		estimated = spec.estimated,
	}
	return entry
end

-- The point in front of the dummy's chest, `ahead` studs forward and `up` studs higher.
local function chest(stage: Stage, ahead: number, up: number?): Vector3
	return stage.root.Position + stage.at.LookVector * ahead + Vector3.new(0, up or 0, 0)
end

-- Recipes -------------------------------------------------------------------------------------------------------------

local function recipes(into: { Entry })
	local function once(id: string, label: string, source: string, length: number, fire: (Stage) -> ())
		table.insert(
			into,
			make({
				id = "recipe_" .. id,
				family = "recipe",
				source = source,
				label = label,
				hit = LEAD,
				length = length,
				play = function(stage: Stage)
					return later(LEAD, function()
						fire(stage)
					end)
				end,
			})
		)
	end
	once("impact", "Impact", "Recipes.impact", 2.5, function(stage)
		vfx().Recipes.impact(CFrame.new(chest(stage, 2.4)), { ground = false, shake = false, flash = false })
	end)
	once("slam", "Slam", "Recipes.slam", 3, function(stage)
		vfx().Recipes.slam(CFrame.new(stage.floor + Vector3.new(0, 0.05, 0) + stage.at.LookVector * 2.4), {})
	end)
	once("twinkle", "Twinkle", "Recipes.twinkle", 2, function(stage)
		vfx().Recipes.twinkle(chest(stage, 1.2, 1.4), {})
	end)
	once("pillar", "Pillar", "Recipes.pillar", 4, function(stage)
		vfx().Recipes.pillar(CFrame.new(stage.floor + stage.at.LookVector * 4), { seconds = 1.6 })
	end)
	once("dissolve", "Dissolve", "Recipes.dissolve", 5, function(stage)
		local parts = {}
		for _, item in ipairs(stage.body:GetDescendants()) do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
				table.insert(parts, item)
			end
		end
		vfx().Recipes.dissolve(parts, 1.6, {})
	end)
end

-- A flame on a small stand: a candle, or a brazier's fire, as the maps stand them (World/Flames).
local function flameEntry(into: { Entry }, spec: { [string]: any })
	table.insert(
		into,
		make({
			id = spec.id,
			family = spec.family,
			source = spec.source,
			label = spec.label,
			hit = spec.hit or 0.3,
			length = 6,
			loop = true,
			budget = spec.budget or "world",
			play = function(stage: Stage)
				local candle = spec.kind == "candle"
				local stand = Instance.new("Part")
				stand.Name = "FlameStand"
				stand.Anchored = true
				stand.CanCollide = false
				stand.CanQuery = false
				stand.CanTouch = false
				stand.CastShadow = false
				stand.Material = Enum.Material.SmoothPlastic
				stand.Color = if candle then Color3.fromRGB(226, 218, 200) else Color3.fromRGB(46, 44, 48)
				stand.Size = if candle then Vector3.new(0.3, 0.8, 0.3) else Vector3.new(1.6, 1.2, 1.6)
				local base = stage.floor + stage.at.LookVector * 2.2 + stage.at.RightVector * 2
				stand.CFrame = CFrame.new(base + Vector3.new(0, stand.Size.Y / 2, 0))
				stand.Parent = stage.props
				local wick = Instance.new("Part")
				wick.Name = "FlameWick"
				wick.Anchored = true
				wick.CanCollide = false
				wick.CanQuery = false
				wick.CanTouch = false
				wick.CastShadow = false
				wick.Transparency = 1
				wick.Size = Vector3.new(0.1, 0.1, 0.1)
				wick.CFrame = CFrame.new(base + Vector3.new(0, stand.Size.Y, 0))
				wick.Parent = stage.props
				local flame = (if spec.fresh then need("Presentation", "Vfx", "Fresh").flame else vfx().Recipes.flame)(
					wick,
					{
						kind = spec.kind,
						scale = spec.scale,
						color = spec.color,
						ramp = spec.ramp,
						plain = spec.plain,
						light = spec.light,
					}
				)
				return function()
					flame.destroy()
					wick:Destroy()
					stand:Destroy()
				end
			end,
		})
	)
end

-- The fresh recipes (Vfx/Fresh, ticket V2.5) -------------------------------------------------------------------------

-- Plays one variant of Fresh/Defs where the booth stands it (the dummy's front); returns the stop.
local function playFresh(variant: any, stage: Stage): () -> ()
	local fn = need("Presentation", "Vfx", "Fresh")[variant.call]
	local args = table.clone(variant.args)
	local place = variant.place
	local look = stage.at.LookVector
	if place == "chest" then
		return fn(CFrame.new(chest(stage, 2.4)), args)
	elseif place == "floor" then
		return fn(CFrame.new(stage.floor + Vector3.new(0, 0.05, 0) + look * 3.2), args)
	elseif place == "glint" then
		return fn(chest(stage, 1.2, 1.4), args)
	elseif place == "pillar" then
		return fn(CFrame.new(stage.floor + look * 4), args)
	elseif place == "arc" then
		local to = stage.floor + look * 3 + Vector3.new(0, 0.2, 0)
		return fn(to + Vector3.new(3, 14, -2), to, args)
	elseif place == "charge" then
		-- (it gathers and holds, then the booth releases it: the hit lands at CHARGE_HOLD)
		local handle = fn(chest(stage, 1.4, 0.4), args)
		local cancelRelease = vfx().Clock.after(1.6, function()
			handle.release()
		end)
		return function()
			cancelRelease()
			handle.cancel()
		end
	elseif place == "mist" then
		local handle = fn(CFrame.new(stage.floor + look * 3), args)
		return function()
			handle.destroy()
		end
	elseif place == "body" then
		local parts = {}
		for _, item in ipairs(stage.body:GetDescendants()) do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
				table.insert(parts, item)
			end
		end
		return fn(parts, 1.6, args)
	end
	return noop
end

-- One entry per variant of Fresh/Defs, id "recipe_new_<name>": the new recipes beside the old ones (the game does not use
-- them yet; the pilot moves callers one at a time after the owner's verdict).
local function fresh(into: { Entry })
	local Defs = require(script.Parent:WaitForChild("Fresh"):WaitForChild("Defs")) :: any
	for _, variant in ipairs(Defs.VARIANTS) do
		local id = Defs.idOf(variant)
		local source = "Fresh." .. variant.call
		if variant.place == "flame" then
			flameEntry(into, {
				id = id,
				family = "recipe",
				source = source .. ", a " .. tostring(variant.args.kind),
				label = variant.label,
				kind = variant.args.kind,
				light = true,
				fresh = true,
				hit = Defs.hitOf(variant),
				budget = variant.budget,
			})
		else
			table.insert(
				into,
				make({
					id = id,
					family = "recipe",
					source = source,
					label = variant.label,
					-- (a charge is let go 1.6 s after it starts: that is its hit)
					hit = if variant.place == "charge" then 1.6 else Defs.hitOf(variant),
					length = variant.length,
					loop = variant.loop,
					budget = variant.budget,
					play = function(stage: Stage)
						return playFresh(variant, stage)
					end,
				})
			)
		end
	end
end

-- Auras ---------------------------------------------------------------------------------------------------------------

local function auras(into: { Entry })
	local colour, accent = Color3.fromRGB(150, 92, 205), Color3.fromRGB(232, 206, 255)
	for level, tier in ipairs({ "sealed", "condemned", "godhood" }) do
		table.insert(
			into,
			make({
				id = "aura_level" .. level,
				family = "aura",
				source = "Aura.start, level " .. level,
				label = "Aura level " .. level,
				tier = tier,
				hit = 0.2,
				length = 6,
				loop = true,
				play = function(stage: Stage)
					return need("Presentation", "Aura").start(stage.body, {
						colour = colour,
						accent = accent,
						level = level,
						own = false,
					})
				end,
			})
		)
	end
end

-- Emotes --------------------------------------------------------------------------------------------------------------

-- When each emote's first accent beat lands, in seconds into the clip (read from EmoteFx's own accent() calls and the
-- towers' beats on 2026-11-16; the showpieces' effects are made by hand and have no table here, so their hit is a
-- guess until V0.2 watches them). A start of 0 means the effect begins with the clip.
local FIRST_BEAT: { [string]: number } = {
	twoLeggedBop = 0.3,
	ratDance = 0,
	bunnyEars = 0,
	boatAura = 0,
	officeParty = 3.9,
	glitchStep = 0.6,
	goalCelebration = 1.26,
	smilingLord = 0.3,
	excuseMeSirUp = 0.75,
	impossibleLean = 0.95,
	deducing = 1.1,
	reapersCackle = 0,
	sugarTower = 1.1, -- (the first cube's star lands 0.1 s after its time, as the dice's does)
	sugarTowerAdd = 1.4,
	sugarTowerTopple = 1.4,
	diceTower = 0.9,
	diceTowerAdd = 1.3,
	diceTowerTopple = 1.3,
	strawberryOnTop = 1,
	appleTossThrow = 1.15,
	chocolateSnap = 0.75,
	wave = 0.63,
	point = 0.55,
	cheer = 0.73,
	laugh = 0.37,
	dance = 0.13,
	salute = 0.77,
	bow = 1.33,
	shrug = 1,
	facepalm = 0.73,
	highFive = 0.73,
	handshake = 1,
	bouncePump = 0,
	chip = 1.4,
	coinFlip = 0.95,
	dance2 = 0.7,
	dance3 = 0.4,
	footScratch = 0.5,
	hairTwirl = 0.93,
	jawlineCheck = 1.8,
	takeTheL = 0.33,
	theClassic = 0.5,
	theEyebrow = 0.8,
	think = 0.63,
	twoWeeksNotice = 2.23,
	appleToss = 0.5,
	excuseMeSir = 0.4,
	cuffedLead = 0.3,
	-- (stage 4b third batch: read from the clip's own beats in EmoteFx so the report judges the real moment, not a guess)
	chipAndPen = 7.05, -- the bite
	writeAir = 2.3, -- the full stop
	blindfoldLiftUp = 0.9, -- the blindfold goes up
	-- (stage 4b fourth batch: the same, read from the effect's own timers)
	itsYou = 0.24, -- the point lands
	appleBite = 0.93, -- the crunch
	fortySeconds = 3.45, -- the heartbeat
	furiousScribbling = 0.3, -- the first scratch
	furiousScribblingSlash = 1.2, -- the red slash
	lowBattery = 3.75, -- the first fizzle when it is empty
	lowBatteryCharge = 0.15, -- the first jolt
	twoFingerGrip = 0,
	puppetDance = 0,
	puppetPop = 0,
	jackpotShuffle = 0,
	animatronicWelcome = 0,
}

-- The emote's own effect, and its aura, on the dummy, as a player sees it (the clip plays on the body too, so the effect
-- lands on the body's beat; stage.preview plays it as the shop's preview instead).
local function playEmote(stage: Stage, clip: string, loop: boolean, length: number): () -> ()
	local EmoteFx = need("Controllers", "EmoteFx")
	local PoseController = need("Anim", "PoseController")
	local alive = true
	local handle: any = nil
	task.spawn(function()
		PoseController.bindWhenReady(stage.body, 2)
		if alive then
			handle = PoseController.play(stage.body, clip, {
				emote = true,
				fadeIn = 0.2,
				fadeOut = 0.35,
				duration = if loop then nil else length + 0.4,
			})
		end
	end)
	local stopFx = EmoteFx.play(stage.body, clip, stage.preview, nil)
	-- (a one-shot's effect ends with its clip, as the emote's session ends it; a loop burns until stopped)
	local cancel: (() -> ())? = nil
	if not loop then
		cancel = vfx().Clock.after(length + 0.4, stopFx)
	end
	return function()
		alive = false
		if cancel then
			cancel()
		end
		stopFx()
		if handle then
			handle.stop(0.1, "booth")
		end
	end
end

local function emotes(into: { Entry }, clips: { string })
	for _, clip in ipairs(clips) do
		local item = Cosmetics.emote(clip)
		local info = Clips[clip]
		local clipLength = if info and type(info.length) == "number" then info.length else 3
		local loop = info ~= nil and info.loop == true
		local beat = FIRST_BEAT[clip]
		table.insert(
			into,
			make({
				id = "emote_" .. clip,
				family = "emote",
				source = "EmoteFx.play",
				label = if item then item.name else clip,
				tier = tierOf(if item then item.rarity else nil),
				hit = beat or 1,
				estimated = beat == nil,
				length = if loop then math.clamp(clipLength, 3, 8) else math.max(clipLength, 1.5),
				loop = loop,
				play = function(stage: Stage)
					return playEmote(stage, clip, loop, if loop then 8 else math.max(clipLength, 1.5))
				end,
			})
		)
	end
end

-- Deaths --------------------------------------------------------------------------------------------------------------

local function deaths(into: { Entry }, customDeaths: { string })
	-- (what Presenters/Death does where the body hits the floor: a burst and a chalk outline)
	table.insert(
		into,
		make({
			id = "death_floor",
			family = "death",
			source = "DeathFx.burst + DeathFx.chalk (Presenters/Death)",
			label = "Body hits the floor",
			hit = LEAD,
			length = 4,
			play = function(stage: Stage)
				return later(LEAD, function()
					local DeathFx = need("Presentation", "DeathFx")
					local at = stage.floor + Vector3.new(0, 1, 0)
					DeathFx.burst(at, DeathFx.DARK, 40)
					DeathFx.chalk(at, 7, DeathFx.CHALK, 14)
				end)
			end,
		})
	)
	-- (the one voted out: static and wisps lifting off the body as it goes, Anim/ActingController)
	table.insert(
		into,
		make({
			id = "death_voted_out",
			family = "death",
			source = "DeathFx.dissolve (Anim/ActingController)",
			label = "Voted out",
			hit = LEAD,
			length = 3.5,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("Presentation", "DeathFx").dissolve(stage.body, 1.4)
				end)
			end,
		})
	)
	-- (the beats of the three collapses at the table, Presentation/DeathVfx: the clip's own times; the booth dummy stands in)
	for _, collapse in ipairs({
		{ "collapseHeart", "Heart attack", 0.14, 3 },
		{ "collapseDisease", "Disease", 0.14, 4 },
		{ "collapseAccident", "Accident", 0.7, 2 },
	}) do
		local clipName = collapse[1] :: string
		table.insert(
			into,
			make({
				id = "death_" .. clipName,
				family = "death",
				source = "DeathVfx.play " .. clipName,
				label = collapse[2],
				budget = "showpiece",
				hit = collapse[3],
				estimated = true,
				length = collapse[4],
				play = function(stage: Stage)
					need("Presentation", "DeathVfx").play(clipName, stage.body, os.clock())
					return noop
				end,
			})
		)
	end
	-- (a custom death's own effect at the table: none is left, every one is a scene death now)
	for _, style in ipairs(customDeaths) do
		local item = Cosmetics.reason(style)
		table.insert(
			into,
			make({
				id = "death_" .. style,
				family = "death",
				source = "CustomDeaths.play",
				label = if item then item.name else style,
				tier = tierOf(if item then item.rarity else nil),
				hit = 0.8,
				estimated = true,
				length = 4,
				play = function(stage: Stage)
					need("Presentation", "CustomDeaths").play(style, stage.body, { hit = 0.8 })
					return noop
				end,
			})
		)
	end
end

-- Whole scenes (the cutscene gallery's) ---------------------------------------------------------------------------------

-- A scene played as the shop's Preview plays it (Presentation/WinCinema): on the player's own camera, in its own set.
local function scenePlay(cut: string): (Stage) -> () -> ()
	return function(stage: Stage)
		local WinCinema = need("Presentation", "WinCinema")
		if not WinCinema.preview(cut, stage.done) then
			error("the scene " .. cut .. " did not start (another holds the camera, or it is not here)")
		end
		return function()
			WinCinema.stopPreview()
		end
	end
end

local function scenes(into: { Entry })
	local seenWin: { [string]: boolean } = {}
	local seenScene: { [string]: boolean } = {}
	for _, raw in ipairs(Cosmetics.ITEMS) do
		local item = raw :: any
		if item.kind == "win" and type(item.cut) == "string" and WinCuts[item.cut] and not seenWin[item.cut] then
			seenWin[item.cut] = true
			local cut = WinCuts[item.cut]
			local length = tonumber(cut.length) or 8
			table.insert(
				into,
				make({
					id = "win_" .. item.cut,
					family = "win",
					source = "WinCinema.preview",
					label = item.name,
					tier = tierOf(item.rarity),
					budget = "scene",
					whole = true,
					hit = length * 0.5,
					estimated = true,
					length = length,
					play = scenePlay(item.cut),
				})
			)
		elseif
			item.kind == "reason"
			and type(item.scene) == "number"
			and type(item.style) == "string"
			and not seenScene[item.style]
		then
			seenScene[item.style] = true
			table.insert(
				into,
				make({
					id = "scene_" .. item.style,
					family = "scenedeath",
					source = "WinCinema.preview (SceneDeaths)",
					label = item.name,
					tier = tierOf(item.rarity),
					budget = "scene",
					whole = true,
					hit = item.scene * 0.5,
					estimated = true,
					length = item.scene,
					play = scenePlay("scene:" .. item.style),
				})
			)
		end
	end
	-- (the cuts no shop item names: the other side's version of a win, the grave after "A true patriot")
	local rest: { string } = {}
	for _, source in ipairs({ WinCuts, DeathCuts }) do
		for name in pairs(source) do
			if not seenWin[name] then
				seenWin[name] = true
				table.insert(rest, name)
			end
		end
	end
	table.sort(rest)
	for _, name in ipairs(rest) do
		local cut = WinCuts[name] or DeathCuts[name]
		local length = tonumber(cut.length) or 8
		table.insert(
			into,
			make({
				id = "win_" .. name,
				family = "win",
				source = "WinCinema.preview",
				label = name,
				budget = "scene",
				whole = true,
				hit = length * 0.5,
				estimated = true,
				length = length,
				play = scenePlay(name),
			})
		)
	end
end

-- Cosmetics -----------------------------------------------------------------------------------------------------------

-- The writing styles: the Manual's page with a name written on it in the style (Presentation/BookStage, which writes
-- every line through Styles.write), on the player's own camera.
local function writing(into: { Entry })
	for _, raw in ipairs(Cosmetics.ofKind("writing")) do
		local item = raw :: any
		if type(item.style) == "string" then
			local style = item.style
			table.insert(
				into,
				make({
					id = "writing_" .. style,
					family = "writing",
					source = "BookStage.play + Styles.write",
					label = item.name,
					tier = tierOf(item.rarity),
					budget = "showpiece",
					whole = true,
					hit = 2.5,
					estimated = true,
					length = 5.5,
					play = function(stage: Stage)
						local CameraDirector = need("Presentation", "CameraDirector")
						local token = CameraDirector.take(10)
						local removeSet = need("Presentation", "BookStage").play(
							token,
							{ { text = "Kenji Mori" }, { text = "Heart attack", small = true } },
							4,
							style
						)
						-- (the book scene has no end of its own: it is taken away at its length, or on Stop)
						local closed = false
						local function close()
							if not closed then
								closed = true
								removeSet()
								CameraDirector.release(token)
							end
						end
						local over = task.delay(5.5, function()
							close()
							stage.done()
						end)
						return function()
							pcall(task.cancel, over)
							close()
						end
					end,
				})
			)
		end
	end
end

-- The Manual covers: the cover's tell on a book held out in front of the dummy, first as it is held, then as a name is
-- written in it (World/CoverTells.STYLES holds the tells; the booth stands a plain slab in for the book).
local function covers(into: { Entry })
	for _, raw in ipairs(Cosmetics.ofKind("grimoire")) do
		local item = raw :: any
		if type(item.style) == "string" then
			local style = item.style
			table.insert(
				into,
				make({
					id = "cover_" .. style,
					family = "cover",
					source = "CoverTells.STYLES",
					label = item.name,
					tier = tierOf(item.rarity),
					hit = 2,
					estimated = true,
					length = 5,
					loop = true,
					play = function(stage: Stage)
						local tell = need("World", "CoverTells").STYLES[style]
						if not tell then
							error("no tell for the cover " .. style)
						end
						local carrier = Instance.new("Part")
						carrier.Name = "CoverTell"
						carrier.Anchored = true
						carrier.CanCollide = false
						carrier.CanQuery = false
						carrier.CanTouch = false
						carrier.CastShadow = false
						carrier.Material = Enum.Material.SmoothPlastic
						-- (the booth only: the slab is lightened and held in front of the dummy, facing the camera, because a
						-- black book on the black dummy cannot be judged; the game's own book is not touched)
						carrier.Color = (if typeof(item.color) == "Color3"
							then item.color
							else Color3.fromRGB(60, 40, 40)):Lerp(Color3.fromRGB(176, 182, 196), 0.6)
						carrier.Size = Vector3.new(1.3, 1.8, 0.3)
						local front = chest(stage, -1.7, 0.3)
						carrier.CFrame = CFrame.lookAt(front, front + Vector3.new(0, 0, 5))
						carrier.Parent = stage.props
						local made = {}
						for _, entry in ipairs(tell.emitters) do
							local emitter = vfx().Emit.make(carrier, entry.spec)
							emitter.Rate = 0
							table.insert(made, { emitter = emitter, entry = entry, owed = 0 })
						end
						-- (the booth feeds the emitters by hand at the tell's rates: a rate does not show in the booth's
						-- stills, and by hand it also holds with the kit's clock)
						local writing = false
						local stopFeed = vfx().Clock.every(function(dt: number): boolean?
							for _, one in ipairs(made) do
								local rate = if writing then one.entry.writing else one.entry.held
								one.owed += rate * dt
								local n = math.floor(one.owed)
								if n > 0 then
									one.owed -= n
									one.emitter:Emit(n)
								end
							end
							return true
						end)
						local light: PointLight? = nil
						if tell.light then
							local lamp = Instance.new("PointLight")
							lamp.Color = tell.light.color
							lamp.Range = 8
							lamp.Shadows = false
							lamp.Brightness = tell.light.held
							lamp.Parent = carrier
							light = lamp
						end
						if tell.appear then
							tell.appear(carrier, carrier.Size)
						end
						-- (the book is held, then a name goes in)
						local switch = later(2, function()
							writing = true
							if light and tell.light then
								light.Brightness = tell.light.writing
							end
						end)
						return function()
							switch()
							stopFeed()
							carrier:Destroy()
						end
					end,
				})
			)
		end
	end
end

-- The win cuts' "fx" act kinds, one entry each (stage 4c): the act of WinCinema.ACTS.fx played alone on a floor frame in front of
-- the dummy, with the data a cut gives it (`light` is a plain lamp flash and has no entry). The cut's own `refs` are stood in by
-- the few the act reads: the frame, empty part and prop lists, and the cleanups.
local WIN_FX: { { any } } = {
	{ "impact", { place = { 0, 0, -3 }, ground = true } },
	{ "glint", { place = { 0, 4, -3 } } },
	{ "pillar", { place = { 0, 0, -3 }, height = 12, seconds = 1.2 } },
	{ "wave", { place = { 0, 0.1, -3 }, face = { 0, 1, 0 } } },
	{ "bolt", { place = { 0, 9, -3 }, to = { 0, 0, -3 } } },
	{ "sparks", { place = { 0, 3, -3 } } },
	{ "bloom", { place = { 0, 3, -3 } } },
	{ "ring", { place = { 0, 3, -3 } } },
	{ "dust", { place = { 0, 0.2, -3 } } },
	{ "embers", { place = { 0, 0.5, -3 }, box = { 1, 0.2, 1 }, seconds = 2 } },
	{ "motes", { place = { 0, 3, -3 }, box = { 3, 3, 3 }, seconds = 2 } },
	{ "ash", { place = { 0, 5, -3 }, box = { 3, 0.2, 3 }, seconds = 2 } },
	{ "drizzle", { place = { 0, 4, -3 }, box = { 2, 0.2, 0.2 }, seconds = 2 } },
}

-- (the recipes hit a moment after they are called: the act fires on the beat and the recipe lands this much later)
local WIN_FX_LATE: { [string]: number } = { impact = 0.06, glint = 0.06, pillar = 0.06, bolt = 0.04, dust = 0.06 }

local function winFx(into: { Entry })
	for _, row in ipairs(WIN_FX) do
		local kind: string = row[1]
		local event = row[2] :: { [string]: any }
		table.insert(
			into,
			make({
				id = "moment_winfx_" .. kind,
				family = "moment",
				source = "WinCinema.ACTS.fx, kind " .. kind,
				label = "Win cut effect: " .. kind,
				budget = "showpiece",
				hit = LEAD + (WIN_FX_LATE[kind] or 0),
				length = (event.seconds or 1) + 2,
				play = function(stage: Stage)
					local refs = { origin = stage.at, parts = {}, props = {}, cleanups = {}, rows = {} }
					local stop = later(LEAD, function()
						local act = table.clone(event)
						act.act = "fx"
						act.kind = kind
						need("Presentation", "WinCinema").ACTS.fx(refs, act)
					end)
					return function()
						stop()
						for _, clean in ipairs(refs.cleanups :: { () -> () }) do
							pcall(clean)
						end
					end
				end,
			})
		)
	end
end

-- The Deathsinger forms (Styles.form dresses the body; the folder it returns is what it wears).
local function forms(into: { Entry })
	for _, raw in ipairs(Cosmetics.ofKind("specter")) do
		local item = raw :: any
		if type(item.form) == "string" then
			local form = item.form
			table.insert(
				into,
				make({
					id = "form_" .. form,
					family = "form",
					source = "Styles.form",
					label = item.name,
					tier = tierOf(item.rarity),
					hit = 0.5,
					estimated = true,
					length = 6,
					loop = true,
					play = function(stage: Stage)
						local worn = need("Presentation", "Styles").form(
							stage.body,
							form,
							if typeof(item.color) == "Color3" then item.color else nil
						)
						return function()
							if worn then
								worn:Destroy()
							end
						end
					end,
				})
			)
		end
	end
end

-- Moments and the world ------------------------------------------------------------------------------------------------

local function moments(into: { Entry })
	-- (handcuffs clicking shut, the Manual landing: Presenters/Arrest, Presenters/Intro)
	table.insert(
		into,
		make({
			id = "moment_sparks",
			family = "moment",
			source = "DeathFx.sparks",
			label = "Sparks",
			hit = LEAD,
			length = 2,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("Presentation", "DeathFx").sparks(chest(stage, 1.6))
				end)
			end,
		})
	)
	-- (something dropped from above lands: EmoteFx.thud, from the emote props)
	table.insert(
		into,
		make({
			id = "moment_thud",
			family = "moment",
			source = "EmoteFx.thud",
			label = "Thud",
			hit = LEAD,
			length = 2.5,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("Controllers", "EmoteFx").thud(CFrame.new(stage.floor + stage.at.LookVector * 2), 2.6)
				end)
			end,
		})
	)
	-- (a Specter's Mist haunt, UI/HauntBar)
	table.insert(
		into,
		make({
			id = "moment_haunt_mist",
			family = "moment",
			source = "HauntBar.mist",
			label = "Haunt, mist",
			hit = LEAD,
			length = 4,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("UI", "HauntBar").mist(chest(stage, 3, 1.5))
				end)
			end,
		})
	)
	-- (the dive's crash into the roof, Controllers/DiveController)
	table.insert(
		into,
		make({
			id = "moment_dive_crash",
			family = "moment",
			source = "DiveController.crashFx",
			label = "Dive, crash",
			budget = "showpiece",
			hit = LEAD + 0.06,
			length = 3,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("Controllers", "DiveController").crashFx(
						stage.floor + stage.at.LookVector * 2.4,
						Vector3.yAxis,
						48
					)
				end)
			end,
		})
	)
	-- (the Oculus deal: the Deathsinger's eyes lit, then your own taking fire, Presentation/EyesDealFx)
	table.insert(
		into,
		make({
			id = "moment_eyes_deal_ignite",
			family = "moment",
			source = "EyesDealFx.ignite",
			label = "Deal, your eyes take fire",
			budget = "showpiece",
			hit = LEAD,
			length = 3,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("Presentation", "EyesDealFx").ignite(stage.body)
				end)
			end,
		})
	)
	table.insert(
		into,
		make({
			id = "moment_eyes_deal_eyes",
			family = "moment",
			source = "EyesDealFx.eyesOf",
			label = "Deal, its eyes lit",
			hit = LEAD,
			length = 2,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("Presentation", "EyesDealFx").eyesOf(stage.body)
				end)
			end,
		})
	)
	-- (a stare's red eyes: the slivers the server puts on the character, lit by World/EyeGlow)
	table.insert(
		into,
		make({
			id = "moment_eye_glow",
			family = "moment",
			source = "EyeGlow.light",
			label = "Red eyes",
			hit = LEAD,
			length = 4,
			loop = true,
			play = function(stage: Stage)
				local head = stage.body:FindFirstChild("Head")
				local holder = Instance.new("Model")
				holder.Name = "LEyesGlow"
				if head and head:IsA("BasePart") then
					for _, side in ipairs({ -0.2, 0.2 }) do
						local eye = Instance.new("Part")
						eye.Size = Vector3.new(0.2, 0.08, 0.05)
						eye.Anchored = true
						eye.CanCollide = false
						eye.CanQuery = false
						eye.Transparency = 1
						eye.CFrame = head.CFrame * CFrame.new(side, 0.12, -0.6)
						eye.Parent = holder
					end
				end
				local cancel = later(LEAD, function()
					holder.Parent = stage.props
					need("World", "EyeGlow").light(holder)
				end)
				return function()
					cancel()
					holder:Destroy()
				end
			end,
		})
	)
	-- (every emote begins and ends in a breath of dust round the feet)
	table.insert(
		into,
		make({
			id = "moment_wisp",
			family = "moment",
			source = "EmoteFx.wisp",
			label = "Wisp of dust",
			hit = LEAD,
			length = 2.5,
			play = function(stage: Stage)
				return later(LEAD, function()
					need("Controllers", "EmoteFx").wisp(stage.body)
				end)
			end,
		})
	)
end

-- Building ------------------------------------------------------------------------------------------------------------

-- Every entry, from the lists given (the game's own, or a spec's).
function Catalog.build(sources: Sources?): { Entry }
	local given = sources or {}
	local list: { Entry } = {}
	recipes(list)
	flameEntry(list, {
		id = "recipe_flame_candle",
		family = "recipe",
		source = "Recipes.flame, a candle",
		label = "Flame, candle",
		kind = "candle",
		light = true,
	})
	flameEntry(list, {
		id = "recipe_flame_fire",
		family = "recipe",
		source = "Recipes.flame, a fire",
		label = "Flame, fire",
		kind = "fire",
		light = true,
	})
	fresh(list)
	auras(list)
	emotes(list, given.emotes or {})
	deaths(list, given.customDeaths or {})
	scenes(list)
	winFx(list)
	writing(list)
	covers(list)
	forms(list)
	moments(list)
	-- (as World/Flames stands them on the maps' wicks: no light of its own, the prop carries the lamp)
	flameEntry(list, {
		id = "world_candle",
		family = "world",
		source = "Recipes.flame as World/Flames makes it, a candle",
		label = "Candle",
		kind = "candle",
		light = false,
	})
	flameEntry(list, {
		id = "world_brazier",
		family = "world",
		source = "Recipes.flame as World/Flames makes it, a fire",
		label = "Brazier",
		kind = "fire",
		scale = 3,
		color = Color3.fromRGB(205, 222, 245),
		light = false,
	})
	-- (stage 4e: the same two as the kit's flame builds them, the plain world build World/Flames stands behind Pilot.on.worldCandle
	-- and worldBrazier; the report puts each beside the old one's row)
	flameEntry(list, {
		id = "world_candle_fresh",
		family = "world",
		source = "Fresh.flame as World/Flames makes it (plain), a candle",
		label = "Candle, new",
		kind = "candle",
		plain = true,
		fresh = true,
		light = false,
	})
	flameEntry(list, {
		id = "world_brazier_fresh",
		family = "world",
		source = "Fresh.flame as World/Flames makes it (plain), a fire",
		label = "Brazier, new",
		kind = "fire",
		scale = 3,
		plain = true,
		fresh = true,
		light = false,
	})
	-- (the families in their order, each family's entries in the order built)
	local rank: { [string]: number } = {}
	for index, family in ipairs(Catalog.FAMILIES) do
		rank[family] = index
	end
	local keyed: { { entry: Entry, at: number } } = {}
	for at, entry in ipairs(list) do
		table.insert(keyed, { entry = entry, at = at })
	end
	table.sort(keyed, function(a, b)
		local ra, rb = rank[a.entry.family] or 99, rank[b.entry.family] or 99
		if ra ~= rb then
			return ra < rb
		end
		return a.at < b.at
	end)
	local sorted: { Entry } = {}
	for _, one in ipairs(keyed) do
		table.insert(sorted, one.entry)
	end
	return sorted
end

-- Problems with a list of entries (an empty list when it is sound): ids unique, each family and tier a known one, the
-- numbers sane, every entry playable, and every emote clip given has its entry.
function Catalog.check(entries: { Entry }, emoteClips: { string }?): { string }
	local problems: { string } = {}
	local families: { [string]: boolean } = {}
	for _, family in ipairs(Catalog.FAMILIES) do
		families[family] = true
	end
	local tiers: { [string]: boolean } = {}
	for _, tier in ipairs(Catalog.TIERS) do
		tiers[tier] = true
	end
	local seen: { [string]: boolean } = {}
	for _, entry in ipairs(entries) do
		local id = entry.id
		if type(id) ~= "string" or id == "" then
			table.insert(problems, "an entry has no id")
			continue
		end
		if seen[id] then
			table.insert(problems, "the id " .. id .. " is used twice")
		end
		seen[id] = true
		if not families[entry.family] then
			table.insert(problems, id .. " is in the unknown family " .. tostring(entry.family))
		end
		if not tiers[entry.tier] then
			table.insert(problems, id .. " has the unknown tier " .. tostring(entry.tier))
		end
		if type(entry.hit) ~= "number" or entry.hit < 0 then
			table.insert(problems, id .. " has no sound hit time")
		end
		if type(entry.length) ~= "number" or entry.length <= 0 then
			table.insert(problems, id .. " has no sound length")
		end
		if type(entry.play) ~= "function" then
			table.insert(problems, id .. " cannot be played")
		end
		if type(entry.source) ~= "string" or entry.source == "" then
			table.insert(problems, id .. " does not say where it comes from")
		end
	end
	for _, clip in ipairs(emoteClips or {}) do
		if not seen["emote_" .. clip] then
			table.insert(problems, "the emote clip " .. clip .. " has no entry")
		end
	end
	return problems
end

-- The game's catalogue, built once from the client's own lists.
local built: { Entry }? = nil

function Catalog.get(): { Entry }
	if built then
		return built
	end
	local sources: Sources = {}
	local ok, result = pcall(function()
		return need("Controllers", "EmoteFx").clips()
	end)
	if ok then
		sources.emotes = result
	else
		warn("[DeathsGambit] the effects catalogue could not list the emotes: " .. tostring(result))
	end
	local okDeaths, styles = pcall(function()
		return need("Presentation", "CustomDeaths").styles()
	end)
	if okDeaths then
		sources.customDeaths = styles
	end
	built = Catalog.build(sources)
	return built :: { Entry }
end

function Catalog.byId(id: string): Entry?
	for _, entry in ipairs(Catalog.get()) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

return Catalog
