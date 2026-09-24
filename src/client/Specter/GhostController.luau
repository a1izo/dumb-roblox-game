-- Being a Specter on this client: flying (camera-relative, up and down, straight through
-- walls), the lost souls only you can see, and the real names of the living when the
-- server says you may see them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

local GhostRemote = Net.event("Ghost")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local GhostController = {}

-- Fired as (done, max) when the lost-soul count changes.
GhostController.DutiesChanged = Signal.new()

local SPEED = 26
local LIFT = 18
local COLLECT_RANGE = 7

local flight: { velocity: LinearVelocity, align: AlignOrientation, attachment: Attachment }? = nil
local touchLift = 0
local wisps: { [number]: BasePart } = {}
local collectAsked: { [number]: number } = {}
local nameTags: { [number]: BillboardGui } = {}
local names: { [string]: string } = {}
local duties = { done = 0, max = 8 }

-- Touch buttons in the Specter HUD hold these: 1 = up, -1 = down, 0 = neither.
function GhostController.setTouchLift(value: number)
	touchLift = value
end

function GhostController.duties(): (number, number)
	return duties.done, duties.max
end

function GhostController.jump(venue: string)
	GhostRemote:FireServer({ action = "jump", venue = venue })
end

local function ownHumanoid(): Humanoid?
	local character = LocalPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function stopFlight()
	if flight then
		flight.velocity:Destroy()
		flight.align:Destroy()
		flight.attachment:Destroy()
		flight = nil
	end
end

local function startFlight(character: Model)
	stopFlight()
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	local attachment = Create("Attachment", { Name = "SpecterFlight", Parent = root })
	local velocity = Create("LinearVelocity", {
		Attachment0 = attachment,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		MaxForce = 1e6,
		VectorVelocity = Vector3.zero,
		Parent = root,
	})
	local align = Create("AlignOrientation", {
		Attachment0 = attachment,
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		MaxTorque = 1e6,
		Responsiveness = 18,
		CFrame = root.CFrame - root.Position,
		Parent = root,
	})
	flight = { velocity = velocity, align = align, attachment = attachment }
end

local function lift(): number
	local up = UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
	local down = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
	local value = touchLift
	if up then
		value = 1
	elseif down then
		value = -1
	end
	return value
end

local function steer()
	local current = flight
	local humanoid = ownHumanoid()
	local camera = workspace.CurrentCamera
	if not current or not humanoid or not camera then
		return
	end
	-- While following someone the ghost waits where it is.
	if camera.CameraSubject ~= humanoid then
		current.velocity.VectorVelocity = Vector3.zero
		return
	end
	local move = humanoid.MoveDirection
	local velocity = Vector3.new(move.X, 0, move.Z) * SPEED + Vector3.new(0, lift() * LIFT, 0)
	current.velocity.VectorVelocity = velocity
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		current.align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end

-- Lost souls ----------------------------------------------------------------------------

local function clearWisps()
	for _, part in pairs(wisps) do
		part:Destroy()
	end
	wisps = {}
end

local function makeWisp(position: Vector3): BasePart
	local orb = Create("Part", {
		Name = "LostSoul",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(170, 205, 255),
		Transparency = 0.2,
		Position = position,
		Parent = workspace.CurrentCamera,
	})
	Create("PointLight", { Color = orb.Color, Range = 10, Brightness = 1.5, Parent = orb })
	Create("ParticleEmitter", {
		Rate = 8,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.3, 1),
		Color = ColorSequence.new(orb.Color),
		LightEmission = 1,
		Parent = orb,
	})
	return orb
end

local function setWisps(list: { any })
	clearWisps()
	for _, entry in ipairs(list) do
		if type(entry) == "table" and typeof(entry.position) == "Vector3" and type(entry.id) == "number" then
			wisps[entry.id] = makeWisp(entry.position)
		end
	end
end

local function checkWisps()
	local character = LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local now = os.clock()
	for id, orb in pairs(wisps) do
		orb.CFrame = CFrame.new(orb.Position) * CFrame.new(0, math.sin(now * 2 + id) * 0.02, 0)
		if (orb.Position - root.Position).Magnitude <= COLLECT_RANGE and now - (collectAsked[id] or 0) > 1 then
			collectAsked[id] = now
			GhostRemote:FireServer({ action = "collect", id = id })
		end
	end
end

-- Real names ----------------------------------------------------------------------------------

local function clearNames()
	for _, tag in pairs(nameTags) do
		tag:Destroy()
	end
	nameTags = {}
end

local function refreshNameTags()
	clearNames()
	if not ClientState.isSpecter() then
		return
	end
	for key, realName in pairs(names) do
		local userId = tonumber(key)
		local player = if userId then Players:GetPlayerByUserId(userId) else nil
		local character = if player then player.Character else nil
		local head = if character then character:FindFirstChild("Head") else nil
		if userId and head and head:IsA("BasePart") then
			local gui = Create("BillboardGui", {
				Name = "SpecterSight",
				Adornee = head,
				AlwaysOnTop = true,
				LightInfluence = 0,
				MaxDistance = 90,
				Size = UDim2.fromOffset(220, 26),
				StudsOffset = Vector3.new(0, 4.2, 0),
				ResetOnSpawn = false,
				Parent = playerGui,
			})
			Create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(realName),
				TextColor3 = Color3.fromRGB(255, 70, 70),
				TextStrokeTransparency = 0.3,
				TextScaled = true,
				Font = Enum.Font.SpecialElite,
				Parent = gui,
			})
			nameTags[userId] = gui
		end
	end
end

local function onGhost(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.action == "names" and type(payload.names) == "table" then
		names = payload.names
		refreshNameTags()
	elseif payload.action == "duties" then
		local before = duties.done
		duties.done = tonumber(payload.done) or 0
		duties.max = tonumber(payload.max) or 8
		if type(payload.wisps) == "table" then
			setWisps(payload.wisps)
		end
		if duties.done > before then
			Sfx.play("wisp")
		end
		GhostController.DutiesChanged:Fire(duties.done, duties.max)
	end
end

local function onCharacter(character: Model)
	stopFlight()
	local function check()
		if character:GetAttribute("Specter") and character == LocalPlayer.Character then
			startFlight(character)
		end
	end
	character:GetAttributeChangedSignal("Specter"):Connect(check)
	check()
end

function GhostController.init()
	GhostRemote.OnClientEvent:Connect(onGhost)
	LocalPlayer.CharacterAdded:Connect(onCharacter)
	if LocalPlayer.Character then
		onCharacter(LocalPlayer.Character)
	end
	RunService.RenderStepped:Connect(function()
		if flight then
			steer()
			checkWisps()
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if not ClientState.isSpecter() then
			clearWisps()
			names = {}
			clearNames()
			duties = { done = 0, max = 8 }
		end
	end)
	-- Name tags follow respawns of the living.
	ClientState.PublicChanged:Connect(function()
		if next(names) ~= nil then
			refreshNameTags()
		end
	end)
end

return GhostController
