-- The ScreenGuis every UI module draws into, from back to front.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function screen(name: string, order: number): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	return Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Parent = playerGui,
	})
end

local Screens = {}

Screens.hud = screen("LGameHUD", 10)
Screens.panels = screen("LGamePanels", 20)
Screens.modal = screen("LGameModal", 30)
Screens.overlay = screen("LGameOverlay", 40)
Screens.toast = screen("LGameToasts", 50)

return Screens
