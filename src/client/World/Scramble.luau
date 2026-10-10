-- The Tokyo scramble on this client: its lamps and its cars.
--   The lamps turn by themselves: the cycle is worked out from the map's ScrambleEpoch
--   (Shared/ScrambleCycle), the same on every client and on the server. Each signal prop has one
--   glowing part per colour; the one the cycle shows is lit, the others go dark, and the lamp's light
--   takes its colour. The walk lamps blink before the cars go, and the crossing only chirps on WALK.
--   The cars come from the server's snapshots (MapSync, with the crowd's walkers): each glides
--   between snapshots BEHIND seconds late, honks when the server says so, and touches nobody (the
--   server stops it short of anyone in its lane).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("ModelCatalog")) :: any
local Create = require(Shared:WaitForChild("Create"))
local MapSync = require(Shared:WaitForChild("MapSync"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))
local ScrambleCycle = require(Shared:WaitForChild("ScrambleCycle"))
local Venues = require(Shared:WaitForChild("Venues"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local MapAmbient = require(script.Parent.MapAmbient)

local Scramble = {}

local LAMPS_EVERY = 0.25 -- seconds between looks at the lamps (the walk lamps blink at this pace)
local FIND_EVERY = 3 -- seconds between looks for signals (the map's props arrive over a while)
local DARK = 0.12 -- how much of its colour an unlit lamp keeps
local BEHIND = 0.3
local KEEP = 8
local STALE = 3
local CHIRP = "mapCrossingChirp"

-- Signals -------------------------------------------------------------------------------------------

type Lamp = { parts: { BasePart }, colour: Color3 }
type Signal = { walk: boolean, lamps: { Lamp }, light: Light?, shows: string }

local signals: { [Model]: Signal } = {}
local foundAt = 0
local lampsAt = 0

local function map(): Instance?
	return workspace:FindFirstChild("LGameMap")
end

-- A prop's glowing parts by colour: <key>_Glow, _Glow2, _Glow3 (ModelLibrary keeps their names).
local function lampsOf(model: Model): { Lamp }
	local lamps: { Lamp } = {}
	for _, child in ipairs(model:GetChildren()) do
		local number = string.match(child.Name, "_Glow(%d*)$")
		if number then
			local parts = {}
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
			for _, item in ipairs(child:GetDescendants()) do
				if item:IsA("BasePart") then
					table.insert(parts, item)
				end
			end
			if #parts > 0 then
				lamps[tonumber(number) or 1] = { parts = parts, colour = parts[1].Color }
			end
		end
	end
	return lamps
end

-- The light the map hung at the prop's lamp (an anchor part of the scene, beside the prop).
local function lightNear(scene: Instance, at: Vector3): Light?
	local best, bestDistance = nil, 4
	for _, item in ipairs(scene:GetChildren()) do
		if item.Name == "Light" and item:IsA("BasePart") then
			local distance = (item.Position - at).Magnitude
			if distance < bestDistance then
				local light = item:FindFirstChildWhichIsA("Light")
				if light then
					best, bestDistance = light, distance
				end
			end
		end
	end
	return best
end

local function findSignals(scene: Instance)
	for model in pairs(signals) do
		if not model:IsDescendantOf(workspace) then
			signals[model] = nil
		end
	end
	for _, item in ipairs(scene:GetChildren()) do
		local key = if item:IsA("Model") then item:GetAttribute("DeathsGambitProp") else nil
		if (key == "TrafficSignal" or key == "PedestrianSignal") and not signals[item :: Model] then
			local lamps = lampsOf(item :: Model)
			-- (Green, amber, red for the cars; a dim pane, the walking figure, the standing one.)
			if lamps[1] and lamps[2] and lamps[3] then
				local walk = key == "PedestrianSignal"
				local lit = lamps[if walk then 2 else 1].parts[1]
				signals[item :: Model] =
					{ walk = walk, lamps = lamps, light = lightNear(scene, lit.Position), shows = "" }
			end
		end
	end
end

local function setLamp(lamp: Lamp, lit: boolean)
	for _, part in ipairs(lamp.parts) do
		part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = if lit then lamp.colour else Color3.new():Lerp(lamp.colour, DARK)
	end
end

local function show(signal: Signal, shows: string)
	if signal.shows == shows then
		return
	end
	signal.shows = shows
	local lit: Lamp? = nil
	if signal.walk then
		-- "walk", "wait", or the blink's dark half ("off").
		setLamp(signal.lamps[2], shows == "walk")
		setLamp(signal.lamps[3], shows == "wait")
		lit = if shows == "walk" then signal.lamps[2] elseif shows == "wait" then signal.lamps[3] else nil
	else
		local index = if shows == "green" then 1 elseif shows == "amber" then 2 else 3
		for number = 1, 3 do
			setLamp(signal.lamps[number], number == index)
		end
		lit = signal.lamps[index]
	end
	local light = signal.light
	if light then
		light.Enabled = lit ~= nil
		if lit then
			light.Color = lit.colour
		end
	end
end

local function stepLamps(current: Instance, clock: number)
	local scene = current:FindFirstChild("Scene")
	local epoch = current:GetAttribute("ScrambleEpoch")
	if not scene or type(epoch) ~= "number" then
		MapAmbient.setAudible(CHIRP, true)
		return
	end
	-- (Twice a second until the first is found: a map's lamps should not all glow for long.)
	if clock - foundAt >= (if next(signals) == nil then 0.5 else FIND_EVERY) then
		foundAt = clock
		findSignals(scene)
	end
	local now = workspace:GetServerTimeNow()
	local phase, into = ScrambleCycle.at(epoch, now)
	local walk = ScrambleCycle.walkLamp(phase)
	if walk == "blink" then
		walk = if math.floor(into / LAMPS_EVERY) % 2 == 0 then "walk" else "off"
	end
	for model, signal in pairs(signals) do
		if signal.walk then
			show(signal, walk)
		else
			show(signal, ScrambleCycle.roadLamp(epoch, now, (model:GetAttribute("Road") :: number?) or 1))
		end
	end
	MapAmbient.setAudible(CHIRP, phase == "WALK")
end

-- Cars ----------------------------------------------------------------------------------------------

-- A car out on its lane: `faded` runs from 0 (there) to 1 (gone). Cars fade in where their lane
-- starts and out where it ends (by a street's barricade), over FADE seconds.
type Ride = {
	model: Model,
	parts: { BasePart },
	kind: number,
	honks: number,
	out: boolean,
	faded: number,
	leaving: boolean,
}

local FADE = 0.6

local folder: Folder
local rides: { [number]: Ride } = {}
local snapshots: { MapSync.Snapshot } = {}
local heardAt = 0
local steppedAt = 0

-- A car's model, ready to be moved by hand: nothing touches it, no ray finds it. A plain box stands
-- in when the prop is not imported.
local function carModel(kind: number): (Model, { BasePart })
	local key = MapSync.CARS[kind + 1] or MapSync.CARS[1]
	local model = ModelLibrary.get(key)
	if not model then
		local info = Catalog[key]
		local size = if info then Vector3.new(info.size[1], info.size[2], info.size[3]) else Vector3.new(5.5, 5, 12)
		model = Instance.new("Model")
		local box = Create("Part", {
			Size = size,
			Color = Color3.fromRGB(24, 28, 44),
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			Parent = model,
		})
		box.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
		model.PrimaryPart = box
	end
	local built = model :: Model
	built.Name = "Car_" .. key
	local parts = {}
	for _, item in ipairs(built:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CollisionGroup = "Vehicles"
			table.insert(parts, item)
		end
	end
	return built, parts
end

local function setFaded(ride: Ride, faded: number)
	if ride.faded ~= faded then
		ride.faded = faded
		for _, part in ipairs(ride.parts) do
			part.LocalTransparencyModifier = faded
		end
	end
end

local function clearCars()
	for number, ride in pairs(rides) do
		ride.model:Destroy()
		rides[number] = nil
	end
	table.clear(snapshots)
end

local function onSnapshot(data)
	local snapshot = MapSync.decode(data)
	if not snapshot then
		return
	end
	heardAt = os.clock()
	local newest = snapshots[#snapshots]
	if newest and snapshot.time <= newest.time then
		if newest.time - snapshot.time < 10 and (#snapshot.cars > 0 or #snapshot.walkers > 0) then
			return -- an old one arriving late
		end
		table.clear(snapshots) -- a new match's clock, or the street being cleared
	end
	table.insert(snapshots, snapshot)
	while #snapshots > KEEP do
		table.remove(snapshots, 1)
	end
end

local function honk(ride: Ride)
	local primary = ride.model.PrimaryPart
	local sound = Sfx.play("mapCarHorn", { group = "Outdoor", parent = primary, volume = 0.9 })
	if sound then
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 140
	end
end

local function stepCars(current: Instance?, clock: number)
	local dt = math.clamp(clock - steppedAt, 0, 0.1)
	steppedAt = clock
	local started = if current then current:GetAttribute("SyncEpoch") else nil
	if not current or type(started) ~= "number" or #snapshots == 0 or clock - heardAt > STALE then
		if next(rides) ~= nil then
			clearCars()
		end
		return
	end
	local t = workspace:GetServerTimeNow() - started - BEHIND
	local a, b = snapshots[1], nil
	for index, snapshot in ipairs(snapshots) do
		if snapshot.time <= t then
			a, b = snapshot, snapshots[index + 1]
		end
	end
	local w = if b and b.time > a.time then math.clamp((t - a.time) / (b.time - a.time), 0, 1) else 0
	for _, ride in pairs(rides) do
		ride.leaving = true
	end
	for number, car in ipairs(a.cars) do
		local ride = rides[number]
		if not car.shown then
			continue
		end
		if ride and ride.kind ~= car.kind then
			ride.model:Destroy()
			ride = nil
		end
		if not ride then
			local model, parts = carModel(car.kind)
			ride = {
				model = model,
				parts = parts,
				kind = car.kind,
				honks = car.honks,
				out = false,
				faded = 0,
				leaving = false,
			}
			rides[number] = ride
		end
		local known = ride :: Ride
		known.leaving = false
		local x, z, heading = car.x, car.z, car.heading
		local after = if b then b.cars[number] else nil
		if after and after.shown and after.kind == car.kind then
			x += (after.x - x) * w
			z += (after.z - z) * w
			heading += MapSync.turnBetween(heading, after.heading) * w
		end
		known.model:PivotTo(CFrame.new(Venues.MAP + Vector3.new(x, 0, z)) * CFrame.Angles(0, heading, 0))
		if not known.out then
			known.out = true
			known.honks = car.honks
			setFaded(known, 1)
			known.model.Parent = folder
			local pass = Sfx.play("mapCarPass", { group = "Outdoor", parent = known.model.PrimaryPart, volume = 0.6 })
			if pass then
				pass.RollOffMaxDistance = 110
			end
		elseif known.honks ~= car.honks then
			known.honks = car.honks
			honk(known)
		end
		setFaded(known, math.max(0, known.faded - dt / FADE))
	end
	-- A car the snapshots no longer show fades out where it was last seen.
	for _, ride in pairs(rides) do
		if ride.leaving and ride.out then
			setFaded(ride, math.min(1, ride.faded + dt / FADE))
			if ride.faded >= 1 then
				ride.out = false
				ride.model.Parent = nil
			end
		end
	end
end

function Scramble.init()
	folder = Create("Folder", { Name = "DeathsGambitCars", Parent = workspace }) :: Folder
	Net.unreliable("MapSync").OnClientEvent:Connect(onSnapshot)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "LGameMap" then
			clearCars()
			table.clear(signals)
			MapAmbient.setAudible(CHIRP, true)
		end
	end)
	RunService.PreSimulation:Connect(function()
		local clock = os.clock()
		local current = map()
		stepCars(current, clock)
		if current and clock - lampsAt >= LAMPS_EVERY then
			lampsAt = clock
			stepLamps(current, clock)
		end
	end)
end

return Scramble
