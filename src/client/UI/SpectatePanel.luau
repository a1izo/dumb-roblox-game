-- Spectating: dead, voted-out and lobby players can watch the living during a match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local SpectateRemote = Net.event("Spectate")
local LocalPlayer = Players.LocalPlayer

local SpectatePanel = {}

local bar: Frame
local nameLabel: TextLabel
local toggleButton: TextButton
local spectating = false
local targetUserId: number? = nil

local function ownHumanoid(): Humanoid?
	local character = LocalPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function resetCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraSubject = ownHumanoid()
	end
end

local function targets()
	local list = {}
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			table.insert(list, entry)
		end
	end
	return list
end

local function focus()
	local list = targets()
	if #list == 0 then
		nameLabel.Text = "Nobody left to watch"
		resetCamera()
		return
	end
	local index = 1
	for i, entry in ipairs(list) do
		if entry.userId == targetUserId then
			index = i
		end
	end
	local entry = list[index]
	targetUserId = entry.userId
	nameLabel.Text = "Watching " .. entry.alias
	SpectateRemote:FireServer(entry.userId)
	local player = Players:GetPlayerByUserId(entry.userId)
	local character = if player then player.Character else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local camera = workspace.CurrentCamera
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
end

local function step(direction: number)
	local list = targets()
	if #list == 0 then
		return
	end
	local index = 0
	for i, entry in ipairs(list) do
		if entry.userId == targetUserId then
			index = i
		end
	end
	index = ((index - 1 + direction) % #list) + 1
	targetUserId = list[index].userId
	focus()
end

function SpectatePanel.stop()
	if not spectating then
		return
	end
	spectating = false
	targetUserId = nil
	SpectateRemote:FireServer(nil)
	resetCamera()
	toggleButton.Text = "SPECTATE"
	nameLabel.Text = "Watch the living players"
end

function SpectatePanel.toggle()
	if spectating then
		SpectatePanel.stop()
		return
	end
	if ClientState.isLiving() or not ClientState.public.active then
		return
	end
	spectating = true
	toggleButton.Text = "STOP"
	focus()
end

local function refresh()
	local canSpectate = ClientState.public.active and not ClientState.isLiving()
	bar.Visible = canSpectate
	if not canSpectate then
		SpectatePanel.stop()
	elseif spectating then
		focus()
	end
end

function SpectatePanel.init()
	bar = Widgets.panel({
		Name = "Spectate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(460, 52),
		Visible = false,
		Parent = Screens.hud,
	})
	Widgets.button({
		Text = "<",
		Slant = false,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(34, 34),
		Parent = bar,
	}, function()
		if spectating then
			step(-1)
		end
	end)
	nameLabel = Widgets.label({
		Text = "Watch the living players",
		FontFace = Theme.faces.displayMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(48, 15),
		Size = UDim2.new(1, -230, 0, 20),
		Parent = bar,
	})
	Widgets.button({
		Text = ">",
		Slant = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -140, 0, 8),
		Size = UDim2.fromOffset(34, 34),
		Parent = bar,
	}, function()
		if spectating then
			step(1)
		end
	end)
	toggleButton = Widgets.button({
		Text = "SPECTATE",
		Variant = "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(120, 34),
		Parent = bar,
	}, SpectatePanel.toggle)

	ClientState.PublicChanged:Connect(refresh)
	LocalPlayer.CharacterAdded:Connect(function()
		if not spectating then
			task.defer(resetCamera)
		end
	end)
	refresh()
end

return SpectatePanel
