-- The lighting on this screen: the venue the camera is in (lobby, map or meeting room) sets
-- the base look, the match phase lays a mood over it, and the Low graphics setting trims it
-- (see LightingPresets). Everything is blended slowly and is local to this client.
--
-- It also tunes the venue's own lamps: the strongest few cast hard shadows (the "keys"), the
-- rest are fill, and a mood scales the two groups apart: a single cold key over the meeting
-- table, lamps dying in the Grimoire phase, a blackout around the verdict's spotlight.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local LightingPresets = require(Shared:WaitForChild("LightingPresets"))
local Signal = require(Shared:WaitForChild("Signal"))
local Venues = require(Shared:WaitForChild("Venues"))

local ClientState = require(script.Parent.Parent.ClientState)
local CueRouter = require(script.Parent.Parent.Presentation.CueRouter)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Screens = require(script.Parent.Parent.UI.Screens)
local Textures = require(script.Parent.Parent.UI.Kit.Textures)
local Governor = require(script.Parent.Governor)

local LightingController = {}

-- Fired as (venue, preset) when the venue or its preset changes.
LightingController.Changed = Signal.new()

local BLEND = 3.5 -- seconds for a change of venue or mood
local ZONE_BLEND = 1.2 -- seconds for stepping into or out of a part of a map with its own look
local LOOK_TAG = "LLookZone"
local RIFT_TAG = "LRift" -- the rift's marker in the lobby (its heights: CloudY, RoofY)
local CITY_NEAR = 220 -- studs over the landing roof from which a diver sees the city's own look
local CREEP_BLEND = 0.6 -- the vote's slow creep, applied in small steps

type Lamp = { brightness: number, range: number, shadows: boolean }

local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local bloom: BloomEffect
local sky: Sky
local defaultFaces: { [string]: string } = {} -- Roblox's own sky, for venues without a sky of their own
local skyShown = "" -- what the Sky shows now ("" = Roblox's night sky, "realm", or a map's sky name)
local pendingApply = false -- a change of look came during a lightning flash
local vignetteHolder: Frame
local currentKey = ""
local currentPreset: LightingPresets.Preset = LightingPresets.lobby
local currentVenue = "lobby"
local currentZone: string? = nil -- the part of a map (or the lobby's depths) the camera is in, with a look of its own
local currentLook: LightingPresets.Look? = nil
local flashing = false
local debugKey: string? = nil -- "lobby", "meeting" or "map:<mapId>", set from the debug panel
local debugMood: string? = nil -- a phase id (or "OutroHand" / "OutroAgency"), from the debug panel
local winner: string? = nil -- the winning side once the ending starts
local phaseStartedAt = 0
local blendEndsAt = 0 -- os.clock() when the blend in progress finishes

-- The lamps of the venue being lit, with their values as built.
local lamps: { [Light]: Lamp } = setmetatable({}, { __mode = "k" }) :: any
local keys: { [Light]: boolean } = {}
local lampModel: Instance? = nil
local lampVenue = ""
local lampKeyCount = -1

local function focus(): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return Venues.LOBBY
	end
	local subject = camera.CameraSubject
	if subject and subject:IsA("Humanoid") and subject.RootPart then
		return subject.RootPart.Position
	elseif subject and subject:IsA("BasePart") then
		return subject.Position
	end
	return camera.Focus.Position
end

-- Lamps --------------------------------------------------------------------------------------

local function lampPosition(light: Light): Vector3?
	local parent = light.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

-- The venue's lamps, and where the shadow-casting keys were last picked from.
local venueLamps: { Light } = {}
local keysPickedAt: Vector3? = nil
-- The keys are re-picked round the camera when it has moved this far (the maps are big).
local KEY_REPICK = 40

-- Picks the keys: the lamps built to cast shadows nearest the camera first, then the strongest
-- nearest. Returns the lamps whose key state changed.
local function pickKeys(keyCount: number): { Light }
	local here = focus()
	keysPickedAt = here
	local scored = {}
	for _, light in ipairs(venueLamps) do
		local lamp = lamps[light]
		local at = lampPosition(light)
		if lamp and at and light.Parent then
			local distance = (at - here).Magnitude
			-- Lamps made for shadows win within reach; beyond that the nearest strong ones.
			local score = distance - (if lamp.shadows then 60 else 0) - math.min(20, lamp.brightness * lamp.range * 0.2)
			table.insert(scored, { light = light, score = score })
		end
	end
	table.sort(scored, function(a, b)
		return a.score < b.score
	end)
	local fresh: { [Light]: boolean } = {}
	for index = 1, math.min(keyCount, #scored) do
		fresh[scored[index].light] = true
	end
	local changed = {}
	for light in pairs(keys) do
		if not fresh[light] then
			table.insert(changed, light)
		end
	end
	for light in pairs(fresh) do
		if not keys[light] then
			table.insert(changed, light)
		end
	end
	keys = fresh
	return changed
end

-- Finds the venue's lamps (once per venue and build) and picks the ones that cast shadows.
local function gatherLamps(venue: string, keyCount: number)
	local model = workspace:FindFirstChild(if venue == "lobby" then "LGameLobby" else "LGameMap")
	if model == lampModel and venue == lampVenue and keyCount == lampKeyCount then
		return
	end
	lampModel = model
	lampVenue = venue
	lampKeyCount = keyCount
	table.clear(venueLamps)
	if model then
		for _, item in ipairs(model:GetDescendants()) do
			-- (Emergency lamps are World/Blackout's: they stay off, then on, whatever the look.)
			if item:IsA("Light") and not (item.Parent and item.Parent:HasTag("LMapEmergency")) then
				local at = lampPosition(item)
				if at and Venues.at(at) == venue then
					if not lamps[item] then
						lamps[item] = { brightness = item.Brightness, range = item.Range, shadows = item.Shadows }
					end
					table.insert(venueLamps, item)
				end
			end
		end
	end
	pickKeys(keyCount)
end

-- The brightness a lamp should have right now (the flicker returns lamps to this).
function LightingController.lampBrightness(light: Light): number?
	local lamp = lamps[light]
	local look = currentLook
	if not lamp or not look then
		return nil
	end
	return lamp.brightness * (if keys[light] then look.keyScale else look.fillScale)
end

local function applyLamps(look: LightingPresets.Look, time: number)
	gatherLamps(currentVenue, look.keyLights)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	for light, lamp in pairs(lamps) do
		if light.Parent and lampVenue == currentVenue then
			local at = lampPosition(light)
			if at and Venues.at(at) ~= currentVenue then
				-- A key of the venue the camera has left: it would go on drawing its shadows for nobody.
				light.Shadows = false
			elseif at then
				local key = keys[light] == true
				local target = lamp.brightness * (if key then look.keyScale else look.fillScale)
				light.Range = lamp.range * look.rangeScale
				light.Shadows = key
				if time > 0 then
					TweenService:Create(light, info, { Brightness = target }):Play()
				else
					light.Brightness = target
				end
			end
		end
	end
end

-- The look ---------------------------------------------------------------------------------------

local function moodName(): string
	if debugMood then
		return debugMood
	end
	local public = ClientState.public
	if not public.active or currentVenue == "lobby" then
		return "Lobby"
	end
	if public.phase == "Outro" then
		return if winner == "Team" then "OutroAgency" else "OutroHand"
	end
	-- A map's blackout (Bureau HQ's breaker): the map sets BlackoutUntil (server time).
	local map = workspace:FindFirstChild("LGameMap")
	local blackout = if map then map:GetAttribute("BlackoutUntil") else nil
	if public.phase == "Investigation" and type(blackout) == "number" and workspace:GetServerTimeNow() < blackout then
		return "Blackout"
	end
	return public.phase
end

local function moodOf(name: string): LightingPresets.Mood
	return LightingPresets.moods[name] or LightingPresets.NEUTRAL
end

-- How far through the current phase (0 to 1).
local function progress(): number
	local endsAt = tonumber(ClientState.public.endsAt) or 0
	local span = endsAt - phaseStartedAt
	if span <= 0 then
		return 0
	end
	return math.clamp((workspace:GetServerTimeNow() - phaseStartedAt) / span, 0, 1)
end

local function setVignette(strength: number, time: number)
	local image = vignetteHolder:FindFirstChildOfClass("ImageLabel")
	if image then
		local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
		TweenService:Create(image, info, { ImageTransparency = 1 - strength }):Play()
	end
end

local SKY_FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }

-- The sky a look asks for: a map's own overcast faces (no stars, no moon's disc), the Grey Realm's
-- (nothing at all: World/RealmSky lays its clouds over it), or Roblox's night sky (the meeting room's
-- windowless war room never shows it). A map whose sky textures are not imported yet keeps Roblox's
-- faces but loses the stars and the moon all the same: it is raining or snowing there.
local function applySky(look: LightingPresets.Look)
	local want = if look.realmSky then "realm" else (look.sky or "")
	if want == skyShown then
		return
	end
	local faces: { [string]: string }? = nil
	if look.sky then
		local found = {}
		for _, face in ipairs(SKY_FACES) do
			local id = Assets.texture("Sky" .. look.sky .. face)
			if id == "" then
				found = nil
				break
			end
			found[face] = id
		end
		faces = found
	end
	for _, face in ipairs(SKY_FACES) do
		(sky :: any)["Skybox" .. face] = if faces then faces[face] else defaultFaces[face]
	end
	local open = want == ""
	sky.StarCount = if open then 2500 else 0
	sky.CelestialBodiesShown = open
	sky.MoonAngularSize = if open then 14 else 0
	sky.SunAngularSize = if open then 8 else 0
	-- (A sky still waiting for its textures is asked for again on the next change of look.)
	skyShown = if look.sky and not faces then "" else want
end

local function apply(look: LightingPresets.Look, time: number)
	local previous = currentLook
	currentLook = look
	blendEndsAt = os.clock() + time
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	-- The hour is never blended: from the Grey Realm's afternoon to a map's midnight the sun would
	-- sweep back across the sky. It changes at once, with the venue.
	if not previous or previous.clockTime ~= look.clockTime then
		Lighting.ClockTime = look.clockTime
	end
	applySky(look)
	TweenService:Create(Lighting, info, {
		Brightness = look.brightness,
		ExposureCompensation = look.exposure,
		Ambient = look.ambient,
		OutdoorAmbient = look.outdoorAmbient,
		EnvironmentDiffuseScale = look.envDiffuse,
		EnvironmentSpecularScale = look.envSpecular,
	}):Play()
	TweenService:Create(atmosphere, info, {
		Density = look.density,
		Haze = look.haze,
		Glare = look.glare,
		Color = look.atmosphereColor,
		Decay = look.decay,
	}):Play()
	TweenService:Create(grade, info, {
		Saturation = look.saturation,
		Contrast = look.contrast,
		TintColor = look.tint,
	}):Play()
	TweenService:Create(bloom, info, {
		Intensity = look.bloom,
		Size = look.bloomSize,
		Threshold = look.bloomThreshold,
	}):Play()
	bloom.Enabled = look.bloom > 0
	setVignette(look.vignette, time)
	applyLamps(look, time)
end

local function resolve(): LightingPresets.Look
	return LightingPresets.resolve(currentPreset, moodOf(moodName()), {
		low = Settings.get("lowGraphics") == true,
		noGlow = Governor.cut("glow"),
		fewShadows = Governor.cut("shadows"),
		progress = progress(),
	})
end

-- The part of a map the camera is in that has a look of its own (the metro under Tokyo): the
-- name of its preset in LightingPresets.maps, from the invisible boxes the map builder tags
-- (SceneBuilder.LOOK_TAG, attribute Preset), or nil.
local function lookZone(position: Vector3): string?
	for _, zone in ipairs(CollectionService:GetTagged(LOOK_TAG)) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				local name = zone:GetAttribute("Preset")
				if type(name) == "string" and LightingPresets.maps[name] then
					return name
				end
			end
		end
	end
	return nil
end

-- Far under the lobby on a dive into the rift: under the cloud the realm floats on ("lobbyBelow"), and the
-- last stretch over the city ("lobbyCity"); nil above the cloud's underside.
local function depthZone(position: Vector3): string?
	for _, marker in ipairs(CollectionService:GetTagged(RIFT_TAG)) do
		local cloudY, roofY = marker:GetAttribute("CloudY"), marker:GetAttribute("RoofY")
		if type(cloudY) == "number" and type(roofY) == "number" and marker:IsDescendantOf(workspace) then
			if position.Y < roofY + CITY_NEAR then
				return "lobbyCity"
			elseif position.Y < cloudY then
				return "lobbyBelow"
			end
			return nil
		end
	end
	return nil
end

-- The map built in the world (outside a match, a debug preview has no map id in the state).
local function builtMapId(): string?
	local model = workspace:FindFirstChild("LGameMap")
	local id = if model then model:GetAttribute("MapId") else nil
	return if type(id) == "string" then id else nil
end

local function update(force: boolean?)
	local position = focus()
	local venue = Venues.at(position)
	local mapId = if type(ClientState.public.mapId) == "string" then ClientState.public.mapId else nil
	if (mapId == nil or mapId == "") and venue == "map" then
		mapId = builtMapId()
	end
	if debugKey then
		venue = string.match(debugKey, "^(%a+)") or venue
		mapId = string.match(debugKey, "^map:(.+)$") or mapId
	end
	local zone = if debugKey
		then nil
		elseif venue == "map" then lookZone(position)
		elseif venue == "lobby" then depthZone(position)
		else nil
	currentZone = zone
	local key = venue .. ":" .. (if venue == "map" then (zone or mapId or "") else (zone or "")) .. ":" .. moodName()
	if key == currentKey and not force then
		return
	end
	local instant = currentKey == ""
	local preset = if zone
		then (LightingPresets.maps[zone] or (LightingPresets :: any)[zone] or LightingPresets.pick(venue, mapId))
		else LightingPresets.pick(venue, mapId)
	local venueChanged = venue ~= currentVenue
	local presetChanged = preset ~= currentPreset
	currentKey = key
	currentVenue = venue
	currentPreset = preset
	if not flashing then
		-- Stepping into or out of a zone (down to the metro) changes quicker than a venue.
		apply(resolve(), if instant then 0 elseif presetChanged and not venueChanged then ZONE_BLEND else BLEND)
	else
		-- A lightning flash owns the exposure for a moment: the new look is applied when it ends.
		pendingApply = true
	end
	if venueChanged or presetChanged or instant then
		LightingController.Changed:Fire(venue, currentPreset)
	end
end

-- Debug panel: forces a lighting preset (nil to follow the camera again).
function LightingController.setDebugPreset(key: string?)
	debugKey = key
	update(true)
end

-- Debug panel: forces a mood (nil to follow the phase again).
function LightingController.setDebugMood(name: string?)
	debugMood = name
	update(true)
end

function LightingController.venue(): string
	return currentVenue
end

-- The look being applied (what a slow ambient motion breathes around), nil before the first apply.
function LightingController.look(): LightingPresets.Look?
	return currentLook
end

-- True when no blend or flash is moving the lighting (a module that nudges it by hand waits for this).
function LightingController.settled(): boolean
	return os.clock() >= blendEndsAt and not flashing
end

function LightingController.atmosphere(): Atmosphere
	return atmosphere
end

function LightingController.preset(): LightingPresets.Preset
	return currentPreset
end

-- The name of the look the camera's part of the map has ("TokyoDistrict_Inside", "..._Under"), or
-- nil in the open (the audio and the weather ask whether the player is in a building).
function LightingController.zone(): string?
	return currentZone
end

-- A lightning flash: the scene blows out for a moment, twice.
function LightingController.lightning()
	if flashing then
		return
	end
	flashing = true
	task.spawn(function()
		local base = if currentLook then currentLook.exposure else currentPreset.exposure
		for _, pulse in ipairs({ { 1.6, 0.06 }, { 0.2, 0.08 }, { 1.1, 0.05 } }) do
			Lighting.ExposureCompensation = base + pulse[1]
			task.wait(pulse[2])
		end
		flashing = false
		if pendingApply then
			pendingApply = false
			apply(resolve(), ZONE_BLEND)
		else
			Lighting.ExposureCompensation = base
		end
	end)
end

function LightingController.init()
	for _, child in ipairs(Lighting:GetChildren()) do
		local ours = child.Name == "DeathsGambitAtmosphere"
			or child.Name == "DeathsGambitGrade"
			or child.Name == "DeathsGambitBloom"
			or child.Name == "DeathsGambitSky"
		if ours or child:IsA("Sky") then
			child:Destroy()
		end
	end
	atmosphere = Create("Atmosphere", { Name = "DeathsGambitAtmosphere", Parent = Lighting })
	grade = Create("ColorCorrectionEffect", { Name = "DeathsGambitGrade", Parent = Lighting })
	bloom = Create("BloomEffect", { Name = "DeathsGambitBloom", Parent = Lighting })
	-- Roblox's own night sky (stars and a small moon) until a look asks for another (applySky).
	sky = Create("Sky", {
		Name = "DeathsGambitSky",
		StarCount = 2500,
		CelestialBodiesShown = true,
		MoonAngularSize = 14,
		SunAngularSize = 8,
		Parent = Lighting,
	})
	for _, face in ipairs(SKY_FACES) do
		defaultFaces[face] = (sky :: any)["Skybox" .. face]
	end
	-- The mood's vignette, under the HUD.
	vignetteHolder = Create("Frame", {
		Name = "Vignette",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = Screens.world,
	})
	local function drawVignette()
		vignetteHolder:ClearAllChildren()
		local id = Textures.id("UiVignette")
		if id ~= "" then
			Create("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = Color3.new(0, 0, 0),
				ImageTransparency = 1 - (if currentLook then currentLook.vignette else 0.2),
				Size = UDim2.fromScale(1, 1),
				Parent = vignetteHolder,
			})
		end
	end
	drawVignette()
	Textures.whenReady(drawVignette)

	update(true)
	ClientState.PublicChanged:Connect(function()
		if not ClientState.public.active then
			winner = nil
		end
		update()
	end)
	ClientState.PhaseChanged:Connect(function()
		phaseStartedAt = workspace:GetServerTimeNow()
		update()
	end)
	CueRouter.register("outro", function(cue)
		winner = if type(cue.data) == "table" then cue.data.winner else nil
		update(true)
	end)
	Settings.Changed:Connect(function(key)
		if key == "lowGraphics" then
			update(true)
		end
	end)
	Governor.Changed:Connect(function()
		update(true)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			update()
			-- Move the shadow-casting keys along with the camera.
			local look = currentLook
			if
				look
				and lampVenue == currentVenue
				and keysPickedAt
				and (focus() - keysPickedAt).Magnitude > KEY_REPICK
			then
				local info = TweenInfo.new(1, Enum.EasingStyle.Sine)
				for _, light in ipairs(pickKeys(look.keyLights)) do
					local lamp = lamps[light]
					if lamp and light.Parent then
						local key = keys[light] == true
						light.Shadows = key
						TweenService:Create(light, info, {
							Brightness = lamp.brightness * (if key then look.keyScale else look.fillScale),
						}):Play()
					end
				end
			end
			-- The vote's red creeps in over the phase.
			if not flashing and moodOf(moodName()).creep then
				apply(resolve(), CREEP_BLEND)
			end
		end
	end)
end

return LightingController
