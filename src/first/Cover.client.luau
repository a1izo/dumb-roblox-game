-- The very first thing a joining player sees: a black screen, put up before anything else loads (it also
-- replaces Roblox's loading screen), full screen with the top bar. As soon as the game's pictures can be read, the
-- shut eye comes up out of it (2026-10-27); the client picks it up and plays the rest of the join (UI/LobbyIntro,
-- UI/EyeIntro). A player arriving by teleport from a match search keeps the loading screen they left with (its still
-- rides the teleport, UI/AppleLoading) until the client's own takes over. If the client never takes over (an error),
-- it lifts by itself after a while.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "DGIntro"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false

local black = Instance.new("Frame")
black.Name = "Black"
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BorderSizePixel = 0
black.Size = UDim2.fromScale(1, 1)
black.Parent = gui

-- The painted face's layers (UI/EyeIntro lays and moves them): the face in two halves, the near hair in two halves,
-- covering the screen in the picture's own shape. They are drawn whole from the start under the Dawn, a black veil over
-- them all, which lifts off the head in one piece (the hair never fades in by itself, showing the face through it).
local ASPECT = 16 / 9
local dawn = Instance.new("Frame")
dawn.Name = "Dawn"
dawn.BackgroundColor3 = Color3.new(0, 0, 0)
dawn.BorderSizePixel = 0
dawn.Size = UDim2.fromScale(1, 1)
dawn.ZIndex = 7
dawn.Parent = black
local layers: { [string]: Frame } = {}
local pictures: { ImageLabel } = {}
for _, spec in ipairs({ { "Face", 1, "IntroBaseL", "IntroBaseR" }, { "Near", 3, "IntroHairL", "IntroHairR" } }) do
	local layer = Instance.new("Frame")
	layer.Name = spec[1]
	layer.BackgroundTransparency = 1
	layer.ZIndex = spec[2]
	layer.Parent = black
	layers[spec[1]] = layer
	for side = 0, 1 do
		local half = Instance.new("ImageLabel")
		half.Name = spec[3 + side]
		half.BackgroundTransparency = 1
		half.Position = UDim2.fromScale(side * 0.5, 0)
		half.Size = UDim2.fromScale(0.5, 1)
		half.ZIndex = spec[2]
		half.Parent = layer
		table.insert(pictures, half)
	end
end
local function cover()
	local view = black.AbsoluteSize
	local scale = math.max(view.X / ASPECT, view.Y)
	local size = Vector2.new(scale * ASPECT, scale)
	for _, layer in pairs(layers) do
		layer.Size = UDim2.fromOffset(size.X, size.Y)
		layer.Position = UDim2.fromOffset((view.X - size.X) / 2, (view.Y - size.Y) / 2)
	end
end
black:GetPropertyChangedSignal("AbsoluteSize"):Connect(cover)
cover()

-- (arriving by teleport: the loading screen's still, kept up under the black's place)
local arriving = TeleportService:GetArrivingTeleportGui()
if arriving then
	arriving.Parent = playerGui
	gui:SetAttribute("Teleported", true)
	black.BackgroundTransparency = 1
	dawn.BackgroundTransparency = 1
end

gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- The face, its eye shut, once the game's list of pictures has arrived and the pictures themselves have loaded.
if not arriving then
	task.spawn(function()
		local shared = ReplicatedStorage:WaitForChild("Shared", 30)
		local module = if shared then shared:WaitForChild("Assets", 30) else nil
		if not module then
			return
		end
		local ok, Assets = pcall(require, module)
		if not ok or type(Assets.images) ~= "table" then
			return
		end
		local ids = {}
		for _, half in ipairs(pictures) do
			half.Image = Assets.contentId(Assets.images[half.Name] or "")
			if half.Image ~= "" then
				table.insert(ids, half.Image)
			end
		end
		if #ids < #pictures then
			return
		end
		pcall(function()
			ContentProvider:PreloadAsync(ids)
		end)
		if dawn.Parent and dawn.BackgroundTransparency < 1 then
			TweenService:Create(dawn, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		end
	end)
end

task.delay(60, function()
	if gui.Parent and not gui:GetAttribute("Claimed") then
		gui:Destroy()
		if arriving and arriving.Parent then
			arriving:Destroy()
		end
	end
end)
