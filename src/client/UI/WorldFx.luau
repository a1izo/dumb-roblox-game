-- World-space effects only this client sees: letter flashes above stations, names seen
-- with Specter's Eyes, and the overlay when this player is eliminated.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local WorldFx = {}

local overlay: Frame
local overlayTitle: TextLabel
local overlaySubtitle: TextLabel
local overlayToken = 0

local function findScreen(stationId: string): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("LStationScreen")) do
		if part:IsA("BasePart") and part:GetAttribute("StationId") == stationId then
			return part
		end
	end
	return nil
end

-- Three letters of the worker's real name, shown above the station for a few seconds.
local function onLetterFlash(payload)
	if type(payload) ~= "table" or type(payload.pattern) ~= "string" or type(payload.stationId) ~= "string" then
		return
	end
	local screen = findScreen(payload.stationId)
	if not screen then
		return
	end
	local gui = Create("BillboardGui", {
		Name = "LetterFlash",
		Adornee = screen,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 60,
		Size = UDim2.fromScale(15, 1.8),
		StudsOffset = Vector3.new(0, 2.6, 0),
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	Widgets.label({
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Color3.fromRGB(8, 10, 16),
		Font = Theme.fonts.mono,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(120, 255, 170),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = if type(payload.alias) == "string"
			then string.upper(payload.alias) .. "  ·  " .. payload.pattern
			else payload.pattern,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	task.delay(tonumber(payload.duration) or 3, function()
		gui:Destroy()
	end)
end

-- A real name seen with Specter's Eyes. Nothing is stored anywhere.
local function onEyesName(payload)
	if type(payload) ~= "table" or type(payload.name) ~= "string" or type(payload.userId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(payload.userId)
	local character = if target then target.Character else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Create("BillboardGui", {
		Name = "SpecterEyesName",
		Adornee = head,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 80,
		Size = UDim2.fromScale(8, 1.4),
		StudsOffset = Vector3.new(0, 3.2, 0),
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	Widgets.label({
		Font = Theme.fonts.typewriter,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 50, 50),
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = string.upper(payload.name),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	task.delay(tonumber(payload.duration) or 3, function()
		gui:Destroy()
	end)
end

local function onElimination(payload)
	if type(payload) ~= "table" or payload.userId ~= LocalPlayer.UserId then
		return
	end
	overlayToken += 1
	local myToken = overlayToken
	local kind = payload.kind
	if kind == "dead" then
		overlayTitle.Text = "YOU DIED"
		overlaySubtitle.Text = "Cause of death: " .. tostring(payload.cause) .. ". You are now a spectator."
	elseif kind == "voted" then
		overlayTitle.Text = "VOTED OUT"
		overlaySubtitle.Text = Terms.f("{Agency} removed you. You are now a spectator.")
	elseif kind == "arrested" then
		overlayTitle.Text = "ARRESTED"
		overlaySubtitle.Text = Terms.f("{Zero} served a warrant with your real name. You are now a spectator.")
	else
		return
	end
	overlay.Visible = true
	Router.setBlocking("eliminated", true)
	task.delay(5, function()
		if overlayToken == myToken then
			overlay.Visible = false
			Router.setBlocking("eliminated", false)
		end
	end)
end

function WorldFx.init()
	overlay = Widgets.frame({
		Name = "Eliminated",
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Theme.colors.ink,
		ClipsDescendants = true,
		Visible = false,
		Parent = Screens.overlay,
	})
	-- A red band across the screen behind the title.
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.accent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(2, 0, 0, 110),
		Rotation = -6,
		Parent = overlay,
	})
	overlayTitle = Widgets.label({
		FontFace = Theme.faces.display,
		TextSize = 84,
		TextColor3 = Theme.colors.paper,
		Rotation = -6,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 70),
		Parent = overlay,
	})
	overlaySubtitle = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(0.9, 0, 0, 30),
		Parent = overlay,
	})
	Net.event("LetterFlash").OnClientEvent:Connect(onLetterFlash)
	Net.event("EyesName").OnClientEvent:Connect(onEyesName)
	Net.event("Elimination").OnClientEvent:Connect(onElimination)
end

return WorldFx
