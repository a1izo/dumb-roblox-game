-- Haunting the lobby. For a Specter waiting there (away from the case, hidden), a small bar at the bottom
-- centre: Flicker (the nearest brazier or lamp sputters), Whisper and Mist (at the spot you are looking at,
-- within 25 studs), plus the spirit trial's start. One shared cooldown for the haunts; the server decides. Every player in the lobby sees and hears a
-- haunt (this module plays them all), and nothing says who did it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local LobbyGamesController = require(script.Parent.Parent.Controllers.LobbyGamesController)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Kit = require(script.Parent.Kit)
local LobbyChrome = require(script.Parent.Core.LobbyChrome)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local GhostRemote = Net.event("Ghost")
local HauntRemote = Net.event("Haunt")
local LocalPlayer = Players.LocalPlayer

local HauntBar = {}

local RANGE = 25

local bar: Frame
local cooldownLabel: TextLabel
local readyAt = 0

-- The spot you are looking at (screen centre), no further than RANGE from you.
local function aimedSpot(): Vector3?
	local camera = workspace.CurrentCamera
	local character = LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not camera or not root or not root:IsA("BasePart") then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local origin = camera.CFrame.Position
	local hit = workspace:Raycast(origin, camera.CFrame.LookVector * 200, params)
	local spot = if hit then hit.Position + Vector3.new(0, 1.5, 0) else root.Position
	local offset = spot - root.Position
	if offset.Magnitude > RANGE then
		spot = root.Position + offset.Unit * RANGE
	end
	return spot
end

local function haunt(kind: string)
	if workspace:GetServerTimeNow() < readyAt then
		return
	end
	GhostRemote:FireServer({ action = "haunt", kind = kind, position = aimedSpot() })
end

-- Effects (played on every screen) ----------------------------------------------------------------------

local function anchorAt(position: Vector3, seconds: number): Part
	local part = Create("Part", {
		Name = "Haunt",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = position,
		Parent = workspace.CurrentCamera,
	})
	task.delay(seconds, function()
		part:Destroy()
	end)
	return part
end

local function flicker(light: Instance)
	local holder = light.Parent
	if holder and holder:IsA("BasePart") then
		Sfx.play("hauntFlicker", { parent = anchorAt(holder.Position, 4), volume = 0.7 })
	end
	task.spawn(function()
		if light:IsA("Fire") then
			for _ = 1, 6 do
				light.Enabled = not light.Enabled
				task.wait(math.random(4, 14) / 100)
			end
			light.Enabled = true
			return
		end
		if not (light:IsA("PointLight") or light:IsA("SpotLight")) then
			return
		end
		local base = light:GetAttribute("LHauntBase") or light.Brightness
		light:SetAttribute("LHauntBase", base)
		for step = 1, 8 do
			light.Brightness = if step % 2 == 0 then base else base * math.random(0, 25) / 100
			task.wait(math.random(4, 12) / 100)
		end
		light.Brightness = base
	end)
end

local function whisper(position: Vector3)
	Sfx.play("hauntWhisper", { parent = anchorAt(position, 8), volume = 0.8 })
end

local function mist(position: Vector3)
	local part = anchorAt(position, 4)
	local emitter = Create("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(205, 215, 230)),
		LightInfluence = 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 40),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Rate = 0,
		Parent = part,
	})
	local smoke = Assets.texture("Smoke")
	if smoke ~= "" then
		emitter.Texture = smoke
	end
	emitter:Emit(36)
	Sfx.play("hauntMist", { parent = part, volume = 0.6 })
end

local function onHaunt(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "flicker" and typeof(payload.light) == "Instance" then
		flicker(payload.light)
	elseif payload.kind == "whisper" and typeof(payload.position) == "Vector3" then
		whisper(payload.position)
	elseif payload.kind == "mist" and typeof(payload.position) == "Vector3" then
		mist(payload.position)
	end
end

-- The bar -----------------------------------------------------------------------------------------------

local function refresh()
	bar.Visible = ClientState.isAway() and not LobbyChrome.isHidden()
end

function HauntBar.init()
	bar = Kit.frame({
		Name = "HauntBar",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false,
		Parent = Screens.hud,
	})
	Kit.Layout.place(bar, "bottomCenter")
	Kit.list(bar, T.space.s, true, Enum.HorizontalAlignment.Center)
	cooldownLabel = Kit.label({
		Text = "Haunt",
		font = "label",
		size = "small",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = 0,
		Parent = bar,
	})
	for index, item in ipairs({ { "flicker", "Flicker" }, { "whisper", "Whisper" }, { "mist", "Mist" } }) do
		Kit.button({ text = item[2], variant = "secondary", size = "s", LayoutOrder = index, Parent = bar }, function()
			haunt(item[1])
		end)
	end
	Kit.button(
		{ text = "Spirit trial", icon = "eye", variant = "primary", size = "s", LayoutOrder = 9, Parent = bar },
		function()
			LobbyGamesController.startSpiritTrial()
		end
	)
	-- The cooldown, counted down on the bar's label.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if bar.Visible then
				local left = math.ceil(readyAt - workspace:GetServerTimeNow())
				cooldownLabel.Text = if left > 0 then string.format("Haunt  ·  %d s", left) else "Haunt"
			end
		end
	end)
	GhostRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.action == "haunted" and type(payload.ready) == "number" then
			readyAt = payload.ready
		end
	end)
	HauntRemote.OnClientEvent:Connect(onHaunt)
	ClientState.PrivateChanged:Connect(refresh)
	ClientState.PublicChanged:Connect(refresh)
	LobbyChrome.Changed:Connect(refresh)
	refresh()
end

return HauntBar
