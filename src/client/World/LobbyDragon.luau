--!strict
-- The dragon over the castle (the user's picture 7, 2026-11-10): far off beyond the Grey Realm's north-west rim the
-- castle stands on its crag in the fog (art/scripts/maps/venues/lobby/plan.py CASTLE; the castle is the map's), and
-- a dragon circles it slowly, banking into the turn, rising and sinking a little, its wings beating now and then (the
-- model leans with each beat; it is one mesh). Only while the camera is in the lobby; this client's alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Venues = require(Shared:WaitForChild("Venues"))

local LightingController = require(script.Parent.LightingController)

local LobbyDragon = {}

-- The castle's crag (plan.CASTLE: x, z; the crag's top 42 over the plain, the castle 216 over that).
local CENTRE = Vector3.new(-150, 0, -720)
local HEIGHT = 230 -- over the plain: round the castle's spires
local RADIUS = 150
local PERIOD = 80 -- seconds a circle
local SCALE = 1.6
local BANK = math.rad(24)

local model: Model? = nil
local connection: RBXScriptConnection? = nil

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if model then
		model:Destroy()
		model = nil
	end
end

local function start()
	if model then
		return
	end
	local made = ModelLibrary.get("LobbyDragon")
	if not made then
		return
	end
	made:ScaleTo(made:GetScale() * SCALE)
	for _, part in ipairs(made:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	made.Name = "LobbyDragon"
	made.Parent = workspace
	model = made
	local origin = Venues.LOBBY + CENTRE
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local a = (t / PERIOD) * math.pi * 2
		-- (round the crag anticlockwise seen from above; the height wanders on two slow waves)
		local y = HEIGHT + math.sin(t * 0.21) * 14 + math.sin(t * 0.077) * 9
		local at = origin + Vector3.new(math.cos(a) * RADIUS, y, math.sin(a) * RADIUS)
		local ahead = origin + Vector3.new(math.cos(a + 0.05) * RADIUS, y, math.sin(a + 0.05) * RADIUS)
		-- a wingbeat every few seconds: a lift and a pitch, eased in and out
		local beat = math.max(0, math.sin(t * 1.6)) ^ 3
		local cf = CFrame.lookAt(at + Vector3.new(0, beat * 3, 0), ahead)
			* CFrame.Angles(math.rad(-6) + beat * math.rad(8), 0, BANK)
		if model then
			model:PivotTo(cf)
		end
	end)
end

function LobbyDragon.init()
	LightingController.Changed:Connect(function(venue)
		if venue == "lobby" then
			start()
		else
			stop()
		end
	end)
	if LightingController.venue() == "lobby" then
		task.defer(start)
	end
end

return LobbyDragon
