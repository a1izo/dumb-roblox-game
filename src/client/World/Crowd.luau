-- The Tokyo crowd, drawn on this client. The server only sends where each walker is, five times a
-- second (the MapSync snapshots, Maps/Mechanics/TokyoDistrict); here every walker gets a body cloned
-- from the ones the server built (ReplicatedStorage.LCrowd), glides between snapshots BEHIND seconds
-- late, and walks with the same clips as the players (LocomotionController.adopt). A body is in the
-- way like anyone would be (the Crowd collision group: only characters bump into it) until its walker
-- has been held up long enough to step through whoever blocks it. Nobody in the crowd has a name tag,
-- and nothing here can be clicked, touched or seen by a ray.
-- Fewer are drawn on slower devices: everyone within NEAR studs, then the nearest up to the device's
-- cap; bodies far off are posed less often, and cast no shadow on phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local CrowdLooks = require(Shared:WaitForChild("CrowdLooks"))
local MapSync = require(Shared:WaitForChild("MapSync"))
local Net = require(Shared:WaitForChild("Net"))
local Venues = require(Shared:WaitForChild("Venues"))

local LocomotionController = require(script.Parent.Parent.Anim.LocomotionController)
local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Responsive = require(script.Parent.Parent.UI.Core.Responsive)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local Crowd = {}

local BEHIND = 0.3 -- seconds late the crowd is drawn (the server tests sight lines against the same)
local KEEP = 8 -- snapshots kept
local STALE = 3 -- seconds without a snapshot before the street is cleared
local NEAR = 40 -- studs from the camera within which everyone is drawn
local CAP = { phone = 18, tablet = 26, console = 32, desktop = 40 } -- bodies drawn at most beyond that
local FAR = 70 -- studs from the camera beyond which a body is posed every third frame
local GROUND_EVERY = 0.4 -- seconds between looks at the ground under a body
local INSIDE = 0.8 -- studs: a body this deep in this player lets them through (nobody gets stuck)
local LEAP = 10 -- studs between two snapshots that no walk covers: the walker was put somewhere new
local FOLDER = "LCrowd"

type Rig = {
	model: Model,
	root: BasePart,
	torso: BasePart?,
	standing: boolean,
	drawn: boolean,
	passing: boolean,
	ground: number,
	groundAt: number,
	far: boolean,
}

local folder: Folder
local rigs: { [number]: Rig } = {}
local snapshots: { MapSync.Snapshot } = {}
local heardAt = 0
local chosenAt = 0
local wanted: { [number]: boolean } = {} -- which walkers this device draws
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function map(): Instance?
	return workspace:FindFirstChild("LGameMap")
end

-- The bodies the server built, in order, once they are all there.
local function bodies(): { Model }?
	local store = ReplicatedStorage:FindFirstChild(FOLDER)
	if not store or store:GetAttribute("Ready") ~= true then
		return nil
	end
	local list = {}
	for _, item in ipairs(store:GetChildren()) do
		if item:IsA("Model") then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return if #list > 0 then list else nil
end

local function clear()
	for number, rig in pairs(rigs) do
		rig.model:Destroy()
		rigs[number] = nil
	end
	table.clear(snapshots)
	table.clear(wanted)
end

local function build(number: number, standing: boolean): Rig?
	local store = bodies()
	local current = map()
	if not store or not current then
		return nil
	end
	local seed = (current:GetAttribute("CrowdSeed") :: number?) or 0
	local model = store[CrowdLooks.bodyFor(number, seed, standing, #store)]:Clone()
	model.Name = "Walker" .. number
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- (No state machine: the body is moved from here, never by physics.)
		pcall(function()
			humanoid.EvaluateStateMachine = false
		end)
	end
	if Responsive.class() == "phone" then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				item.CastShadow = false
			end
		end
	end
	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		torso.CollisionGroup = "Crowd"
		torso.CanCollide = true
	end
	model.PrimaryPart = root
	return {
		model = model,
		root = root,
		torso = if torso and torso:IsA("BasePart") then torso else nil,
		standing = standing,
		drawn = false,
		passing = false,
		ground = Venues.MAP.Y,
		groundAt = 0,
		far = false,
	}
end

local function setDrawn(rig: Rig, drawn: boolean)
	if rig.drawn == drawn then
		return
	end
	rig.drawn = drawn
	rig.model.Parent = if drawn then folder else nil
	if drawn then
		LocomotionController.adopt(rig.model)
		rig.far = false
	end
end

local function setPassing(rig: Rig, passing: boolean)
	if rig.passing ~= passing then
		rig.passing = passing
		if rig.torso then
			rig.torso.CollisionGroup = if passing then "CrowdPass" else "Crowd"
		end
	end
end

-- The ground under a spot of the street (the map's solid parts), looked up now and then.
local function groundUnder(rig: Rig, x: number, z: number, now: number): number
	if now - rig.groundAt >= GROUND_EVERY then
		rig.groundAt = now + math.random() * 0.1
		local current = map()
		local scene = if current then current:FindFirstChild("Scene") else nil
		local solids = if scene then scene:FindFirstChild("Solids") else nil
		if solids then
			rayParams.FilterDescendantsInstances = { solids }
			local hit = workspace:Raycast(Vector3.new(x, Venues.MAP.Y + 4, z), Vector3.new(0, -8, 0), rayParams)
			rig.ground = if hit then hit.Position.Y else Venues.MAP.Y
		end
	end
	return rig.ground
end

-- Which walkers to draw: all of them near the camera, the nearest of the rest up to the cap.
local function choose(walkers: { MapSync.Walker }, camera: Vector3)
	table.clear(wanted)
	local most = CAP[Responsive.class()] or CAP.desktop
	if Settings.get("lowGraphics") then
		most = math.floor(most / 2)
	end
	local rest = {}
	local count = 0
	for number, walker in ipairs(walkers) do
		if walker.shown then
			local distance = (Vector3.new(walker.x, 0, walker.z) + Venues.MAP - camera).Magnitude
			if distance <= NEAR then
				wanted[number] = true
				count += 1
			else
				table.insert(rest, { number = number, distance = distance })
			end
		end
	end
	table.sort(rest, function(a, b)
		return a.distance < b.distance
	end)
	for _, entry in ipairs(rest) do
		if count >= most then
			break
		end
		wanted[entry.number] = true
		count += 1
	end
end

local function onSnapshot(data)
	local snapshot = MapSync.decode(data)
	if not snapshot then
		return
	end
	heardAt = os.clock()
	if #snapshot.walkers == 0 then
		-- Nobody about (the round is over, or the map is going).
		for _, rig in pairs(rigs) do
			setDrawn(rig, false)
		end
		table.clear(snapshots)
		return
	end
	local newest = snapshots[#snapshots]
	if newest and snapshot.time <= newest.time then
		if newest.time - snapshot.time < 10 then
			return -- an old one arriving late
		end
		table.clear(snapshots) -- a new match's clock
	end
	table.insert(snapshots, snapshot)
	while #snapshots > KEEP do
		table.remove(snapshots, 1)
	end
end

local moved: { BasePart } = {}
local places: { CFrame } = {}

local function draw()
	local current = map()
	local started = if current then current:GetAttribute("SyncEpoch") else nil
	if not current or type(started) ~= "number" then
		if next(rigs) ~= nil then
			clear()
		end
		return
	end
	local clock = os.clock()
	if #snapshots == 0 or clock - heardAt > STALE then
		for _, rig in pairs(rigs) do
			setDrawn(rig, false)
		end
		return
	end
	-- The two snapshots around the moment being drawn.
	local t = workspace:GetServerTimeNow() - started - BEHIND
	local a, b = snapshots[1], nil
	for index, snapshot in ipairs(snapshots) do
		if snapshot.time <= t then
			a, b = snapshot, snapshots[index + 1]
		end
	end
	local w = if b and b.time > a.time then math.clamp((t - a.time) / (b.time - a.time), 0, 1) else 0
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Venues.MAP
	if clock - chosenAt > 0.5 then
		chosenAt = clock
		choose(a.walkers, eye)
	end
	local character = Players.LocalPlayer.Character
	local own = if character then character:FindFirstChild("HumanoidRootPart") else nil
	table.clear(moved)
	table.clear(places)
	for number, walker in ipairs(a.walkers) do
		local rig = rigs[number]
		if not walker.shown or not wanted[number] then
			if rig then
				setDrawn(rig, false)
			end
			continue
		end
		if rig and rig.standing ~= walker.standing then
			rig.model:Destroy()
			rig = nil
		end
		if not rig then
			rig = build(number, walker.standing)
			if not rig then
				continue -- (the bodies are not built yet)
			end
			rigs[number] = rig
		end
		local known = rig :: Rig
		local x, z, heading, speed = walker.x, walker.z, walker.heading, 0
		local after = if b then b.walkers[number] else nil
		-- (A walker that is suddenly somewhere else, a fresh crowd at the start of a round, is
		-- shown there at once: nobody slides across the street.)
		local stride = if after then math.sqrt((after.x - walker.x) ^ 2 + (after.z - walker.z) ^ 2) else 0
		if after and after.shown and stride <= LEAP then
			x += (after.x - x) * w
			z += (after.z - z) * w
			heading += MapSync.turnBetween(heading, after.heading) * w
			speed = stride / math.max(b.time - a.time, 0.05)
		end
		local at = Vector3.new(x + Venues.MAP.X, 0, z + Venues.MAP.Z)
		local ground = groundUnder(known, at.X, at.Z, clock)
		setDrawn(known, true)
		LocomotionController.setSpeed(known.model, if walker.standing then 0 else speed)
		-- Stepping through someone, or already inside this player: no bump.
		local inside = own ~= nil
			and own:IsA("BasePart")
			and (Vector3.new(own.Position.X, 0, own.Position.Z) - at).Magnitude < INSIDE
		setPassing(known, walker.passing or inside)
		local far = (at - eye).Magnitude > FAR
		if far ~= known.far then
			known.far = far
			PoseController.setEvery(known.model, if far then 3 else 1)
		end
		table.insert(moved, known.root)
		-- (An R6 root is 3 studs above the soles.)
		table.insert(places, CFrame.new(at.X, ground + 3, at.Z) * CFrame.Angles(0, heading, 0))
	end
	-- Walkers the newest snapshots no longer list.
	for number, rig in pairs(rigs) do
		if number > #a.walkers then
			setDrawn(rig, false)
		end
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, places, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Crowd.init()
	folder = Create("Folder", { Name = "DeathsGambitCrowd", Parent = workspace }) :: Folder
	Net.unreliable("MapSync").OnClientEvent:Connect(onSnapshot)
	-- A new map starts with an empty street.
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "LGameMap" then
			clear()
		end
	end)
	RunService.PreSimulation:Connect(draw)
end

-- For the debug panel: how many bodies are out.
function Crowd.count(): number
	local drawn = 0
	for _, rig in pairs(rigs) do
		if rig.drawn then
			drawn += 1
		end
	end
	return drawn
end

return Crowd
