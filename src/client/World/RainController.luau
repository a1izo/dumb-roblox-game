-- Rain and snow built from small cells round the camera, not one big box that follows it. Each
-- cell looks at its own patch of ground (Weather/Probe): where the ground really is (a street, a
-- bridge, the river's surface, a floor) and how much of it is under a roof, an awning or a tree.
-- A cell's drops start high enough, and live exactly long enough, to land on that ground, with
-- a splash where they do; under cover the cell stops, so the rain ends at a roof's edge and
-- over the river it falls to the water, not to the street beside it.
--
-- The rain is heavy and slanted (a storm) with gusts, in near cells of long bright streaks and a
-- few coarse far cells for the veil of it behind; now and then the sky flashes and thunder rolls
-- in. The snow falls in two sizes of flake, drifts with the wind and gusts, and stops under cover
-- the same way. The loops and the thunder are outdoor sounds: they are muffled when you go in
-- (Audio/Muffle), and quieter then.
--
-- Every number you might want to turn lives in TUNING.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local Probe = require(Shared:WaitForChild("Weather"):WaitForChild("Probe"))

local Responsive = require(script.Parent.Parent.UI.Core.Responsive)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local LightingController = require(script.Parent.LightingController)
local Shelter = require(script.Parent.Shelter)

local RainController = {}

local TUNING = {
	cell = 9, -- studs across of a near cell: the patch of ground it looks at and rains on
	radius = 4, -- near cells each way from the camera (81 studs across)
	farCell = 36, -- the coarse cells of the rain's far veil
	farRadius = 2,
	rain = {
		-- Streaks a second at full rain, all the near cells together (Low graphics x0.6, Reduce
		-- motion x0.5 on top).
		rate = { phone = 650, tablet = 1200, console = 1900, desktop = 3200 },
		farShare = 0.1, -- the far veil, as a share of the near rate
		splashShare = 0.3, -- splashes a second, as a share of the near rate
		height = 34, -- studs over the ground a near drop starts
		farHeight = 72,
		speed = 92, -- studs a second along its path
		slant = { pitch = 10, roll = -11 }, -- degrees: the wind from the north-east
		gust = 34, -- studs/s^2 of extra sideways push at the height of a gust
		size = 0.2, -- how wide a streak is, and how many times as long
		squash = 9,
		-- The streak's see-through-ness at birth, mid-fall and landing (0 solid, 1 invisible).
		transparency = { 0.14, 0.3 },
		colour = Color3.fromRGB(214, 222, 242),
	},
	snow = {
		rate = { phone = 150, tablet = 260, console = 380, desktop = 520 },
		height = 15,
		bigShare = 0.35, -- the big soft flakes, as a share of the rate (the rest are fine ones)
		bigSpeed = 2.6,
		fineSpeed = 3.8,
		bigSize = 0.42,
		fineSize = 0.17,
		sway = Vector3.new(0.5, 0, 0.3), -- the steady drift (studs/s^2)
		gust = 6,
	},
	gustEvery = { 20, 40 }, -- seconds between gusts (a gust builds, holds and fades over ~9 s)
	probesPerFrame = 8, -- cells looked at a frame when new ground comes into range
	refreshPerFrame = 0.5, -- and cells looked at again a frame, in turn (the world seldom changes)
	updateEvery = 0.25, -- seconds between rate and wind updates
}

local FALLBACK_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local RING_FALLBACK = FALLBACK_TEXTURE
local SLANT = CFrame.Angles(math.rad(TUNING.rain.slant.pitch), 0, math.rad(TUNING.rain.slant.roll))
local FALL = -SLANT.UpVector -- the way a drop falls (a unit vector, going down)
local WIND = Vector3.new(FALL.X, 0, FALL.Z).Unit -- the way the wind blows, across the ground

type Layer = { part: Part, emitter: ParticleEmitter }
type Cell = {
	gx: number,
	gz: number,
	x: number,
	z: number,
	size: number,
	landing: number?,
	cover: number,
	weight: number,
	probed: boolean,
	rain: Layer?,
	splash: Layer?,
	flakes: { Layer }?,
}

local container: Folder
local nearCells: { Cell } = {}
local farCells: { Cell } = {}
local assignedNear: { [string]: Cell } = {}
local assignedFar: { [string]: Cell } = {}
local cameraCell = Vector2.new(math.huge, math.huge)
local farCameraCell = Vector2.new(math.huge, math.huge)
local dirty: { Cell } = {}
local refreshCursor = 0
local refreshDebt = 0
local lastUpdate = 0
local gust = 0 -- 0 calm, 1 the height of a gust
local gustAt = 0
local nextGust = os.clock() + 12
local loop: Sound? = nil
local windLoop: Sound? = nil

-- Set from the debug panel (setDebug): rain and snow from 0 to 1 whatever the preset says
-- (nil = the preset).
RainController.debugRain = nil :: number?
RainController.debugSnow = nil :: number?

local function rainAmount(): number
	return RainController.debugRain or LightingController.preset().rain
end

-- How hard it snows here (0 to 1): the preset's snow, or the debug panel's.
function RainController.snowAmount(): number
	return RainController.debugSnow or LightingController.preset().snow
end

-- The texture for the rain: Tokyo's own streak when its map brought it in, else the shared one.
local function texture(...: string): string
	for _, name in ipairs({ ... }) do
		local id = Assets.texture(name)
		if id ~= "" then
			return id
		end
	end
	return FALLBACK_TEXTURE
end

local function device(): string
	local class = Responsive.class()
	return if TUNING.rain.rate[class] then class else "desktop"
end

-- How much weather the device and the settings allow (1 = a desktop at full graphics).
local function budget(): number
	local scale = 1
	if Settings.get("reduceMotion") then
		scale *= 0.5
	end
	if Settings.get("lowGraphics") then
		scale *= 0.6
	end
	return scale
end

-- Emitters and their parts ------------------------------------------------------------------------

local function holder(name: string, size: Vector3): Part
	return Create("Part", {
		Name = name,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = size,
		Parent = container,
	}) :: Part
end

local function streakEmitter(part: Part, far: boolean): ParticleEmitter
	local rain = TUNING.rain
	local alpha = rain.transparency
	return Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(rain.speed * 0.99, rain.speed * 1.01),
		Lifetime = NumberRange.new(1, 1), -- set for each cell, from how far its drops fall
		Rate = 0,
		Enabled = false,
		Size = NumberSequence.new(if far then rain.size * 1.7 else rain.size),
		Squash = NumberSequence.new(if far then rain.squash * 1.2 else rain.squash),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.08, if far then alpha[2] + 0.28 else alpha[1]),
			NumberSequenceKeypoint.new(1, if far then alpha[2] + 0.34 else alpha[2]),
		}),
		Color = ColorSequence.new(rain.colour),
		LightInfluence = if far then 0.5 else 0.55,
		LightEmission = if far then 0.2 else 0.35,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(1.2, 1.2),
		Texture = texture("TokyoRain", "RainStreak"),
		Parent = part,
	}) :: ParticleEmitter
end

local function splashEmitter(part: Part): ParticleEmitter
	local ring = Assets.texture("TokyoSplash")
	return Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.2, 0.4),
		Lifetime = NumberRange.new(0.22, 0.34),
		Rate = 0,
		Enabled = false,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, if ring ~= "" then 1.5 else 0.7),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(Color3.fromRGB(208, 216, 236)),
		LightInfluence = 0.7,
		LightEmission = 0.3,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Texture = if ring ~= "" then ring else RING_FALLBACK,
		Parent = part,
	}) :: ParticleEmitter
end

local function flakeEmitter(part: Part, big: boolean): ParticleEmitter
	local snow = TUNING.snow
	local size = if big then snow.bigSize else snow.fineSize
	local speed = if big then snow.bigSpeed else snow.fineSpeed
	local flake = texture("CampusFlake", "Snowflake")
	return Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(speed * 0.97, speed * 1.03),
		Lifetime = NumberRange.new(1, 1), -- set for each cell
		Rate = 0,
		Enabled = false,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size, size * 0.3),
			NumberSequenceKeypoint.new(1, size, size * 0.3),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.08, if big then 0.05 else 0.12),
			NumberSequenceKeypoint.new(0.8, if big then 0.1 else 0.16),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(Color3.fromRGB(246, 248, 255)),
		LightInfluence = 0.35,
		LightEmission = if big then 0.3 else 0.2,
		Acceleration = snow.sway,
		SpreadAngle = Vector2.new(if big then 18 else 26, if big then 18 else 26),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-70, 70),
		Texture = if flake ~= "" then flake else FALLBACK_TEXTURE,
		Parent = part,
	}) :: ParticleEmitter
end

local function newCell(size: number): Cell
	return {
		gx = 0,
		gz = 0,
		x = 0,
		z = 0,
		size = size,
		landing = nil,
		cover = 1,
		weight = 1,
		probed = false,
		rain = nil,
		splash = nil,
		flakes = nil,
	}
end

-- A cell's layers are made the first time its weather is needed (a map with no snow never makes
-- the flakes).
local function ensureRain(cell: Cell, far: boolean)
	if cell.rain then
		return
	end
	local part = holder(if far then "FarRain" else "Rain", Vector3.new(cell.size, 1, cell.size))
	cell.rain = { part = part, emitter = streakEmitter(part, far) }
	if not far then
		local ground = holder("Splash", Vector3.new(cell.size, 0.1, cell.size))
		cell.splash = { part = ground, emitter = splashEmitter(ground) }
	end
end

local function ensureSnow(cell: Cell)
	if cell.flakes then
		return
	end
	local part = holder("Snow", Vector3.new(cell.size, 1, cell.size))
	cell.flakes =
		{ { part = part, emitter = flakeEmitter(part, true) }, { part = part, emitter = flakeEmitter(part, false) } }
end

-- Puts a cell's emitters over the ground it has found: drops start where they will land.
local function place(cell: Cell, far: boolean)
	local landing = cell.landing
	if not landing then
		return
	end
	local rain = TUNING.rain
	if cell.rain then
		local height = if far then rain.farHeight else rain.height
		local start, length = Probe.dropStart(cell.x, cell.z, landing, height, FALL)
		cell.rain.part.CFrame = CFrame.new(start) * SLANT
		local life = length / rain.speed
		cell.rain.emitter.Lifetime = NumberRange.new(life, life)
	end
	if cell.splash then
		cell.splash.part.CFrame = CFrame.new(cell.x, landing + 0.07, cell.z)
	end
	if cell.flakes then
		local snow = TUNING.snow
		cell.flakes[1].part.CFrame = CFrame.new(cell.x, landing + snow.height, cell.z)
		local big = snow.height / snow.bigSpeed
		local fine = snow.height / snow.fineSpeed
		cell.flakes[1].emitter.Lifetime = NumberRange.new(big, big)
		cell.flakes[2].emitter.Lifetime = NumberRange.new(fine, fine)
	end
end

-- Looking at the ground ---------------------------------------------------------------------------

local function probe(cell: Cell, far: boolean, originY: number)
	local landing, cover = Probe.patch(cell.x, cell.z, cell.size, originY, Shelter.rayParams(), Shelter.index())
	cell.landing = landing
	cell.cover = cover
	cell.probed = true
	if landing then
		if far then
			ensureRain(cell, true)
		else
			if rainAmount() > 0 then
				ensureRain(cell, false)
			end
			if RainController.snowAmount() > 0 then
				ensureSnow(cell)
			end
		end
		place(cell, far)
	end
end

local function cameraOrigin(): (Vector3?, number)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, 0
	end
	local subject = camera.CameraSubject
	local at = if subject
			and subject:IsA("Humanoid")
			and subject.RootPart
		then subject.RootPart.Position
		else camera.Focus.Position
	return at, at.Y + 3
end

local function keyOf(gx: number, gz: number): string
	return gx .. "," .. gz
end

-- Hands every cell its place round the camera's cell (the cells that fell out of range are reused
-- for the ones coming into it).
local function assign(
	cells: { Cell },
	assigned: { [string]: Cell },
	size: number,
	radius: number,
	cx: number,
	cz: number
)
	local wanted: { [string]: { number } } = {}
	for gx = cx - radius, cx + radius do
		for gz = cz - radius, cz + radius do
			wanted[keyOf(gx, gz)] = { gx, gz }
		end
	end
	local free: { Cell } = {}
	for key, cell in pairs(assigned) do
		if not wanted[key] then
			assigned[key] = nil
			table.insert(free, cell)
		end
	end
	for key, spot in pairs(wanted) do
		if not assigned[key] then
			local cell = table.remove(free)
			if not cell then
				cell = newCell(size)
				table.insert(cells, cell)
			end
			cell.gx, cell.gz = spot[1], spot[2]
			cell.x, cell.z = spot[1] * size, spot[2] * size
			cell.landing = nil
			cell.cover = 1
			cell.probed = false
			assigned[key] = cell
			table.insert(dirty, cell)
			if cell.rain then
				cell.rain.emitter.Enabled = false
				cell.rain.emitter.Rate = 0
			end
			if cell.splash then
				cell.splash.emitter.Enabled = false
			end
			if cell.flakes then
				for _, layer in ipairs(cell.flakes) do
					layer.emitter.Enabled = false
				end
			end
		end
	end
	-- Weights fall off towards the edge of the area, so its border does not show.
	local reach = (radius + 0.5) * size
	for _, cell in pairs(assigned) do
		local dx, dz = cell.x - cx * size, cell.z - cz * size
		local dist = math.sqrt(dx * dx + dz * dz)
		cell.weight = math.clamp(1.4 - dist / reach, 0.2, 1)
	end
end

-- Rates and wind ---------------------------------------------------------------------------------

-- The preset changed: ground already looked at needs the right layers made.
local function refreshLayers()
	for _, cell in pairs(assignedNear) do
		if cell.landing then
			if rainAmount() > 0 then
				ensureRain(cell, false)
			end
			if RainController.snowAmount() > 0 then
				ensureSnow(cell)
			end
			place(cell, false)
		end
	end
end

local function setLayer(layer: Layer?, rate: number)
	if not layer then
		return
	end
	local emitter = layer.emitter
	if rate < 0.4 then
		if emitter.Enabled then
			emitter.Enabled = false
			emitter.Rate = 0
		end
	else
		emitter.Rate = rate
		if not emitter.Enabled then
			emitter.Enabled = true
		end
	end
end

local function applyRates()
	local class = device()
	local scale = budget()
	local rain = TUNING.rain
	local snow = TUNING.snow
	local rainTotal = rain.rate[class] * scale * rainAmount()
	local snowTotal = snow.rate[class] * scale * RainController.snowAmount()
	local nearWeight, farWeight = 0, 0
	for _, cell in pairs(assignedNear) do
		nearWeight += cell.weight
	end
	for _, cell in pairs(assignedFar) do
		farWeight += cell.weight
	end
	for _, cell in pairs(assignedNear) do
		local open = if cell.landing then 1 - cell.cover else 0
		local rate = if nearWeight > 0 then cell.weight / nearWeight else 0
		setLayer(cell.rain, rainTotal * rate * open)
		setLayer(cell.splash, rainTotal * rain.splashShare * rate * open)
		if cell.flakes then
			setLayer(cell.flakes[1], snowTotal * snow.bigShare * rate * open)
			setLayer(cell.flakes[2], snowTotal * (1 - snow.bigShare) * rate * open)
		end
	end
	for _, cell in pairs(assignedFar) do
		-- The veil only stands where the near cells do not reach, and never under cover.
		local open = if cell.landing then 1 - cell.cover else 0
		local rate = if farWeight > 0 then cell.weight / farWeight else 0
		setLayer(cell.rain, rainTotal * rain.farShare * rate * open)
	end
	local shelter = Shelter.level()
	if loop then
		-- Outside at full volume; indoors a little under it, and muffled besides (Audio/Muffle).
		loop.Volume = rainAmount() * RainController.loopVolume * (1 - 0.45 * shelter)
	end
	if windLoop then
		windLoop.Volume = RainController.snowAmount() * RainController.windVolume * (1 - 0.45 * shelter)
	end
end

-- Debug panel: forces the rain and the snow (nil for the preset's), at once.
function RainController.setDebug(rain: number?, snow: number?)
	RainController.debugRain = rain
	RainController.debugSnow = snow
	refreshLayers()
	applyRates()
end

local function applyWind()
	local rain, snow = TUNING.rain, TUNING.snow
	local push = WIND * (rain.gust * gust)
	for _, cell in pairs(assignedNear) do
		if cell.rain then
			cell.rain.emitter.Acceleration = push
		end
		if cell.flakes then
			local sideways = snow.sway + WIND * (snow.gust * gust)
			cell.flakes[1].emitter.Acceleration = sideways
			cell.flakes[2].emitter.Acceleration = sideways
		end
	end
	for _, cell in pairs(assignedFar) do
		if cell.rain then
			cell.rain.emitter.Acceleration = push
		end
	end
end

local function stepGust(now: number)
	if now >= nextGust then
		gustAt = now
		nextGust = now + math.random(TUNING.gustEvery[1], TUNING.gustEvery[2])
	end
	local age = now - gustAt
	-- Builds over 3 s, holds 2, fades over 4.
	if age < 3 then
		gust = age / 3
	elseif age < 5 then
		gust = 1
	elseif age < 9 then
		gust = 1 - (age - 5) / 4
	else
		gust = 0
	end
	gust = gust * gust * (3 - 2 * gust)
end

local function step()
	local origin, originY = cameraOrigin()
	if not origin then
		return
	end
	local size, farSize = TUNING.cell, TUNING.farCell
	local gx, gz = math.floor(origin.X / size + 0.5), math.floor(origin.Z / size + 0.5)
	if cameraCell.X ~= gx or cameraCell.Y ~= gz then
		cameraCell = Vector2.new(gx, gz)
		assign(nearCells, assignedNear, size, TUNING.radius, gx, gz)
	end
	local fx, fz = math.floor(origin.X / farSize + 0.5), math.floor(origin.Z / farSize + 0.5)
	if farCameraCell.X ~= fx or farCameraCell.Y ~= fz then
		farCameraCell = Vector2.new(fx, fz)
		assign(farCells, assignedFar, farSize, TUNING.farRadius, fx, fz)
		-- The far veil is for what the near cells do not reach.
		local nearReach = (TUNING.radius + 0.5) * size
		for _, cell in pairs(assignedFar) do
			if math.max(math.abs(cell.x - origin.X), math.abs(cell.z - origin.Z)) + farSize / 2 < nearReach then
				cell.weight = 0
			end
		end
	end
	-- Look at the ground under the cells that are new, then every cell again now and then.
	local looked = 0
	while looked < TUNING.probesPerFrame and #dirty > 0 do
		local cell = table.remove(dirty, 1) :: Cell
		local far = assignedFar[keyOf(cell.gx, cell.gz)] == cell
		probe(cell, far, originY)
		looked += 1
	end
	if #dirty == 0 then
		refreshDebt += TUNING.refreshPerFrame
		while refreshDebt >= 1 do
			refreshDebt -= 1
			local list = nearCells
			if #list > 0 then
				refreshCursor = refreshCursor % #list + 1
				local cell = list[refreshCursor]
				if assignedNear[keyOf(cell.gx, cell.gz)] == cell then
					probe(cell, false, originY)
				end
			end
		end
	end
	local now = os.clock()
	stepGust(now)
	if now - lastUpdate >= TUNING.updateEvery then
		lastUpdate = now
		applyRates()
		applyWind()
	end
end

-- Thunder and lightning -----------------------------------------------------------------------------

local function lightningLoop()
	while true do
		task.wait(math.random(14, 32))
		local preset = LightingController.preset()
		if preset.lightning and preset.rain > 0 then
			if not Settings.get("reduceMotion") then
				LightingController.lightning()
			end
			task.delay(0.6 + math.random() * 1.6, function()
				Sfx.play("thunder", {
					group = "Outdoor",
					volume = RainController.thunderVolume * (1 - 0.45 * Shelter.level()),
				})
			end)
		end
	end
end

-- How loud the weather is, before the mixer and the muffling (about 75% over what it was).
RainController.loopVolume = 1.0
RainController.windVolume = 1.1
RainController.thunderVolume = 1.5

-- A map imported after the client started may bring the rain's textures: pick them up when the
-- venue's look changes (entering a match).
local function refreshTextures()
	local streak = texture("TokyoRain", "RainStreak")
	local ring = Assets.texture("TokyoSplash")
	local flake = texture("CampusFlake", "Snowflake")
	for _, cells in ipairs({ nearCells, farCells }) do
		for _, cell in ipairs(cells) do
			if cell.rain then
				cell.rain.emitter.Texture = streak
			end
			if cell.splash and ring ~= "" then
				cell.splash.emitter.Texture = ring
			end
			if cell.flakes and flake ~= "" then
				for _, layer in ipairs(cell.flakes) do
					layer.emitter.Texture = flake
				end
			end
		end
	end
end

function RainController.init()
	container = Create("Folder", { Name = "DeathsGambitWeather", Parent = workspace.CurrentCamera }) :: Folder
	loop = Sfx.play("rainLoop", { group = "Outdoor", looped = true, volume = 0 })
	windLoop = Sfx.play("mapWindSnow", { group = "Outdoor", looped = true, volume = 0 })
	RunService.RenderStepped:Connect(step)
	LightingController.Changed:Connect(function()
		refreshTextures()
		refreshLayers()
		applyRates()
	end)
	Responsive.Changed:Connect(applyRates)
	Settings.Changed:Connect(function(key)
		if key == "reduceMotion" or key == "lowGraphics" then
			applyRates()
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		container.Parent = workspace.CurrentCamera
	end)
	applyRates()
	task.spawn(lightningLoop)
end

return RainController
