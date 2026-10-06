-- The very first thing a joining player sees: a black screen, put up before anything else loads (it also
-- replaces Roblox's loading screen). The client picks it up once the lobby is ready and glitches the lobby in
-- from it (UI/LobbyIntro). If the client never takes over (an error), it lifts by itself after a while.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

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

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

task.delay(30, function()
	if gui.Parent and not gui:GetAttribute("Claimed") then
		gui:Destroy()
	end
end)
