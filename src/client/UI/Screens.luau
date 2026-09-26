-- The ScreenGuis every UI module draws into, from back to front. Each one has a UIScale
-- that Responsive sets for the device, so panels are designed once at desktop size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local Screens = {}

-- Every ScreenGui in draw order, for Responsive to scale.
Screens.all = {} :: { ScreenGui }

local function screen(name: string, order: number, fullBleed: boolean?): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
	})
	-- Full-bleed layers (dimmed backdrops, cutscenes) cover the whole screen; the others
	-- stay clear of the Roblox top bar and phone notches.
	gui.ScreenInsets = if fullBleed then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	Create("UIScale", { Name = "DeviceScale", Parent = gui })
	gui.Parent = playerGui
	table.insert(Screens.all, gui)
	return gui
end

-- Under everything: effects laid over the world itself (the lighting's vignette).
Screens.world = screen("InkboundWorld", 5, true)
Screens.hud = screen("InkboundHUD", 10)
Screens.panels = screen("InkboundPanels", 20)
Screens.modal = screen("InkboundModal", 30, true)
Screens.overlay = screen("InkboundOverlay", 40, true)
Screens.toast = screen("InkboundToasts", 50)
Screens.cinematic = screen("InkboundCinematic", 60, true)
Screens.system = screen("InkboundSystem", 70)

return Screens
