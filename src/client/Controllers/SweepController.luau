--!strict
-- The Reaper's Sweep on this client (rules: Shared/LobbyGames/Sweep; the round is the server's, Services/LobbySweep).
--
-- The scythe is drawn here, on every screen, turning on the dais' pivot (tag LSweepPivot): while a round runs (its
-- attribute SweepAt) by the rules' angle for the time since then, between rounds resting where it stopped. While this
-- player is in the round (their character's attribute Sweeping), their own body is judged against it every frame: a
-- blade that passes under feet still on the stones throws the body off the dais, and the server is told. The round's
-- card is Controllers/LobbyGamesController's.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))
local Sweep = require(Shared:WaitForChild("LobbyGames"):WaitForChild("Sweep"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)

local SweepController = {}

local request = Net.event("LobbyGame")
local LocalPlayer = Players.LocalPlayer

local TAG = "LSweepPivot"
local SCYTHE = "SweepScythe" -- the Lobby set's scythe (art/scripts/props_realmjunk.py): two blades on one shaft
local ROOT_UP = 3 -- the root's middle above the soles
local THROW_OUT = 55 -- studs a second a struck body is thrown out from the middle...
local THROW_UP = 38 -- ...and up
local IRON = Color3.fromRGB(26, 26, 30)
local EDGE = Color3.fromRGB(176, 182, 190)

type Arena = { pivot: BasePart, model: Model, radius: number, angle: number, wasRunning: boolean }

local arenas: { [BasePart]: Arena } = {}
local struckAt = 0

-- The scythe as plain parts, for a place without the Lobby models imported: a long dark shaft through a collar, a
-- blade standing at each end.
local function standIn(radius: number): Model
	local model = Instance.new("Model")
	model.Name = "Scythe"
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		return p
	end
	local hub = piece("Collar", Vector3.new(5.6, 0.8, 5.6), CFrame.new(0, 0.6, 0), IRON)
	model.PrimaryPart = hub
	piece("Shaft", Vector3.new(radius * 2, 0.35, 0.35), CFrame.new(0, 0.8, 0), IRON)
	for _, side in ipairs({ -1, 1 }) do
		piece("Blade", Vector3.new(0.3, 2.8, 2.2), CFrame.new(side * (radius - 0.6), 1.9, 0), EDGE)
	end
	return model
end

local function place(arena: Arena)
	local at = arena.pivot.Position
	arena.model:PivotTo(CFrame.new(at) * CFrame.Angles(0, -arena.angle, 0))
end

local function add(object: Instance)
	if not object:IsA("BasePart") or arenas[object] then
		return
	end
	local radius = tonumber(object:GetAttribute("Radius")) or 17
	local model = ModelLibrary.get(SCYTHE) or standIn(radius)
	model.Name = "Scythe"
	model.Parent = object
	local arena: Arena = { pivot = object, model = model, radius = radius, angle = 0, wasRunning = false }
	arenas[object] = arena
	place(arena)
end

local function remove(object: Instance)
	local arena = arenas[object :: BasePart]
	if arena then
		arena.model:Destroy()
		arenas[object :: BasePart] = nil
	end
end

-- This player's body against the blades: thrown off when one passes under feet still on the stones.
local function judge(arena: Arena, a0: number, a1: number)
	local character = LocalPlayer.Character
	if not character or character:GetAttribute("Sweeping") ~= true or os.clock() - struckAt < 2 then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local centre = arena.pivot.Position
	local offset = Vector2.new(root.Position.X - centre.X, root.Position.Z - centre.Z)
	local feet = root.Position.Y - ROOT_UP - centre.Y
	if not Sweep.struck(a0, a1, offset, feet, arena.radius) then
		return
	end
	struckAt = os.clock()
	local out = if offset.Magnitude > 0.1 then offset.Unit else Vector2.new(1, 0)
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	root.AssemblyLinearVelocity = Vector3.new(out.X * THROW_OUT, THROW_UP, out.Y * THROW_OUT)
	root.AssemblyAngularVelocity = Vector3.new(out.Y * 8, 0, -out.X * 8)
	Sfx.play("gameFall")
	request:FireServer({ game = "sweep", action = "struck" })
end

local function step()
	local now = workspace:GetServerTimeNow()
	for _, arena in pairs(arenas) do
		local at = arena.pivot:GetAttribute("SweepAt")
		if type(at) == "number" then
			local t = math.max(0, now - at)
			local a0 = if arena.wasRunning then arena.angle else Sweep.angle(t)
			local a1 = Sweep.angle(t)
			arena.angle = a1
			arena.wasRunning = true
			place(arena)
			judge(arena, a0, a1)
		elseif arena.wasRunning then
			-- (the round is over: the scythe rests where it stopped)
			arena.wasRunning = false
		end
	end
end

function SweepController.init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, object in ipairs(CollectionService:GetTagged(TAG)) do
		add(object)
	end
	RunService.RenderStepped:Connect(step)
end

return SweepController
