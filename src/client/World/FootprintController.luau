--!strict
-- Tracks in the snow (the campus's mechanic). The server records where every living player walks on
-- untrodden snow (Maps/Mechanics/UniversityCampus) and sends the prints to everyone; this draws them.
-- A print lasts a minute, fading over its last FADE seconds, so a trail can be followed; the prints
-- are anonymous. Never on the shovelled paths or indoors, never for Specters, spectators or bodies (the
-- server decides). Fewer at once on phones and with Low graphics: the oldest go first. A print is a
-- decal when Assets.textures.Footprint is set (or imported), a flat oval otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Tracks = require(Shared:WaitForChild("Tracks"))
local Venues = require(Shared:WaitForChild("Venues"))

local Responsive = require(script.Parent.Parent.UI.Core.Responsive)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local FootprintController = {}

local LIFE = Tracks.LIFE -- seconds a print lasts...
local FADE = 20 -- ...fading out over the last of them
-- The most prints drawn at once for each device class; Low graphics keeps a quarter.
local CAP = { phone = 120, tablet = 200, console = 300, desktop = 400 }
local SIZE = Vector3.new(0.55, 0.04, 1.05)
local COLOUR = Color3.fromRGB(150, 160, 186)
local FRESH = 0.45 -- a new print's transparency

type Print = { part: BasePart, decal: Decal?, born: number, fade: Tween? }

local folder: Folder
local live: { Print } = {} -- oldest first
local spare: { Print } = {}
local texture = ""

local function cap(): number
	local most = CAP[Responsive.class()] or CAP.desktop
	if Settings.get("lowGraphics") then
		most = math.floor(most / 4)
	end
	return most
end

local function makePrint(): Print
	if texture == "" then
		-- (The import can arrive after the game starts.)
		texture = Assets.texture("Footprint")
	end
	local part = Create("Part", {
		Name = "Footprint",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = COLOUR,
		Size = SIZE,
	}) :: BasePart
	local decal: Decal? = nil
	if texture ~= "" then
		part.Transparency = 1
		decal = Create("Decal", {
			Face = Enum.NormalId.Top,
			Texture = texture,
			Color3 = COLOUR,
			Parent = part,
		}) :: Decal
	else
		-- A flat oval pressed into the snow.
		Create("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = part })
	end
	return { part = part, decal = decal, born = 0, fade = nil }
end

local function release(print_: Print)
	if print_.fade then
		print_.fade:Cancel()
		print_.fade = nil
	end
	print_.part.Parent = nil
	table.insert(spare, print_)
end

local function clearAll()
	for _, print_ in ipairs(live) do
		release(print_)
	end
	table.clear(live)
end

local function press(at: CFrame, age: number)
	local print_ = table.remove(spare)
	if not print_ then
		if #live >= cap() and #live > 0 then
			print_ = table.remove(live, 1)
			if print_ and print_.fade then
				print_.fade:Cancel()
				print_.fade = nil
			end
		else
			print_ = makePrint()
		end
	end
	local chosen = print_ :: Print
	chosen.born = os.clock() - age
	chosen.part.CFrame = at
	-- A print that arrives already old (made before this client was there) starts part-way faded.
	local wait = math.max(0, LIFE - FADE - age)
	local left = math.max(0.1, math.min(FADE, LIFE - age))
	local start = FRESH + (1 - FRESH) * math.clamp((age - (LIFE - FADE)) / FADE, 0, 1)
	local info = TweenInfo.new(left, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, wait)
	local decal = chosen.decal
	if decal then
		decal.Transparency = start
		chosen.fade = TweenService:Create(decal, info, { Transparency = 1 })
	else
		chosen.part.Transparency = start
		chosen.fade = TweenService:Create(chosen.part, info, { Transparency = 1 })
	end
	chosen.part.Parent = folder;
	(chosen.fade :: Tween):Play()
	table.insert(live, chosen)
	-- Over the cap (Low graphics just turned on): the oldest go first.
	while #live > cap() do
		release(table.remove(live, 1) :: Print)
	end
end

-- The map's origin (prints come relative to it) and a downward ray to lay them on the surface.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function solids(): Instance?
	local map = workspace:FindFirstChild("LGameMap")
	local scene = if map then map:FindFirstChild("Scene") else nil
	return if scene then scene:FindFirstChild("Solids") else nil
end

local function onTracks(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "clear" then
		clearAll()
		return
	end
	if payload.kind ~= "add" or typeof(payload.data) ~= "buffer" then
		return
	end
	local origin = Venues.MAP
	local ground = solids()
	if ground then
		rayParams.FilterDescendantsInstances = { ground }
	end
	local late = math.max(0, workspace:GetServerTimeNow() - (tonumber(payload.at) or workspace:GetServerTimeNow()))
	for _, p in ipairs(Tracks.decode(payload.data)) do
		local age = p.age + late
		if age < LIFE then
			local at = origin + Vector3.new(p.x, p.y, p.z)
			local up = Vector3.yAxis
			if ground then
				local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -2.5, 0), rayParams)
				if hit then
					at, up = hit.Position, hit.Normal
				end
			end
			local forward = Vector3.new(math.sin(p.heading), 0, math.cos(p.heading))
			forward = (forward - up * forward:Dot(up)).Unit
			press(CFrame.fromMatrix(at + up * 0.03, forward:Cross(up), up, -forward), age)
		end
	end
end

function FootprintController.init()
	folder = Create("Folder", { Name = "DeathsGambitFootprints", Parent = workspace }) :: Folder
	local remote = Net.event("Tracks")
	remote.OnClientEvent:Connect(onTracks)
	-- Joining (or reloading) mid-round: ask for the prints already on the snow.
	remote:FireServer({ action = "sync" })
	-- Prints that have faded go back to the pool; all of them when the map is torn down.
	local lastSweep = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastSweep < 0.5 then
			return
		end
		lastSweep = now
		while live[1] and now - live[1].born >= LIFE do
			release(table.remove(live, 1) :: Print)
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "LGameMap" then
			clearAll()
		end
	end)
	Settings.Changed:Connect(function(key)
		if key == "lowGraphics" then
			while #live > cap() do
				release(table.remove(live, 1) :: Print)
			end
		end
	end)
end

return FootprintController
