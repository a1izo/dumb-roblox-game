-- Being a Specter on this client: flying (camera-relative, up and down, straight through
-- walls), the lost souls only you can see, and the real names of the living when the
-- server says you may see them. Spectators from the lobby fly the same way, and get
-- nothing else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Bindings = require(Shared:WaitForChild("Bindings"))
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Characters = require(script.Parent.Parent.Characters)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)

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

-- Whether any key of a flight action is held (the player's own keys or the defaults, Shared/Bindings).
local function held(id: string): boolean
	local profile = ClientState.profile
	local saved = profile and profile.keybinds or nil
	for _, platform in ipairs(Bindings.PLATFORMS) do
		for _, name in ipairs(Bindings.keys(id, platform, saved)) do
			local ok, key = pcall(function()
				return (Enum.KeyCode :: any)[name]
			end)
			if ok and key then
				if platform == "gamepad" then
					if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, key) then
						return true
					end
				elseif UserInputService:IsKeyDown(key) then
					return true
				end
			end
		end
	end
	return false
end

local function lift(): number
	local up = held("flyUp")
	local down = held("flyDown")
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
	local glow = Assets.texture("SoulGlow")
	if glow ~= "" then
		-- A soft glow sprite around the orb.
		local gui = Create("BillboardGui", {
			Size = UDim2.fromScale(5, 5),
			LightInfluence = 0,
			Parent = orb,
		})
		Create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = glow,
			ImageColor3 = orb.Color,
			Size = UDim2.fromScale(1, 1),
			Parent = gui,
		})
	end
	-- (a soul-fire: pale blue tongues licking up off it and tearing away dark, a hard white star at its heart, specks
	-- drifting off it)
	Vfx.Emit.make(orb, {
		tex = "VfxFlame",
		grid = 8,
		fps = 36,
		startRandom = true,
		color = {
			{ 0, Color3.fromRGB(235, 245, 255) },
			{ 0.35, Color3.fromRGB(140, 190, 255) },
			{ 1, Color3.fromRGB(30, 50, 110) },
		},
		size = { { 0, 1.6 }, { 0.5, 1.2 }, { 1, 0.3 } },
		alpha = { { 0, 0.3 }, { 0.6, 0.5 }, { 1, 1 } },
		life = { 0.5, 0.8 },
		speed = { 0.8, 1.6 },
		accel = Vector3.new(0, 2.5, 0),
		spread = 12,
		face = "up",
		light = 0.8,
		bright = 1.2,
		rate = 26,
	})
	Vfx.Emit.make(orb, {
		tex = "VfxFlare",
		color = Color3.fromRGB(225, 240, 255),
		size = { { 0, 1.4 }, { 0.5, 1.8 }, { 1, 1.4 } },
		alpha = { { 0, 1 }, { 0.15, 0.3 }, { 0.85, 0.3 }, { 1, 1 } },
		life = 1.4,
		rate = 1.4,
		rot = { 0, 90 },
		spin = { -25, 25 },
		locked = true,
		bright = 1.2,
		z = 0.5,
	})
	Vfx.Emit.make(orb, {
		tex = "VfxEmber",
		color = orb.Color,
		size = { { 0, 0.22 }, { 1, 0 } },
		life = { 1, 1.6 },
		speed = { 0.5, 1.5 },
		spread = 180,
		accel = Vector3.new(0, 0.8, 0),
		bright = 1.4,
		rate = 8,
	})
	return orb
end

-- A soul gathered: its light goes up in a white star, a ring of it opens and specks stream up.
local function gathered(at: Vector3)
	Vfx.Recipes.twinkle(at, { color = Color3.fromRGB(170, 205, 255), scale = 1.6 })
	Vfx.Emit.burst(at, {
		{
			{
				tex = "VfxRing",
				color = Color3.fromRGB(190, 220, 255),
				size = { { 0, 0.5 }, { 1, 6 } },
				alpha = { { 0, 0.1 }, { 0.5, 0.5 }, { 1, 1 } },
				life = 0.35,
				light = 0.8,
				bright = 1.1,
			},
			1,
		},
		{
			{
				tex = "VfxStreak",
				color = { { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(140, 190, 255) } },
				size = { { 0, 0.3 }, { 1, 0.06 } },
				squash = -2,
				life = { 0.4, 0.8 },
				speed = { 8, 16 },
				spread = 25,
				drag = 2,
				face = "along",
				bright = 1.5,
			},
			12,
		},
	})
end

local function setWisps(list: { any })
	-- (the souls gone from the list near you were gathered by you)
	local character = LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local still: { [number]: boolean } = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" and type(entry.id) == "number" then
			still[entry.id] = true
		end
	end
	for id, orb in pairs(wisps) do
		if
			not still[id]
			and root
			and root:IsA("BasePart")
			and (orb.Position - root.Position).Magnitude <= COLLECT_RANGE + 3
		then
			gathered(orb.Position)
		end
	end
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
		local character = Characters.byUserId(userId)
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
				TextColor3 = Color3.fromRGB(244, 245, 247),
				TextStrokeColor3 = Color3.fromRGB(8, 9, 11),
				TextStrokeTransparency = 0.3,
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
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
		local ghost = character:GetAttribute("Specter") or character:GetAttribute("Spectator")
		if ghost and character == LocalPlayer.Character and not flight then
			startFlight(character)
		end
	end
	character:GetAttributeChangedSignal("Specter"):Connect(check)
	character:GetAttributeChangedSignal("Spectator"):Connect(check)
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
		elseif ClientState.isAway() then
			-- Lost souls drift in the lobby too while you wait there.
			checkWisps()
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if not ClientState.isSpecter() and not ClientState.isAway() then
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
