--!strict
-- A black curtain over the whole screen, for a cut that should not be seen: the lobby's falls (a chasm, the world's
-- edge, Controllers/LobbyGamesController) and the rift's diver given back at the rim (Controllers/DiveController)
-- go to black before the body is moved and come back up after (the user's call of 2026-10-27: they had cut
-- straight from the dark to the terrace).
--
--   Curtain.close(0.35)   Curtain.open(0.6)   Curtain.isClosed()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Curtain = {}

local frame: Frame? = nil
local closed = false

local function get(): Frame
	local made = frame
	if made and made.Parent then
		return made
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DGCurtain"
	gui.DisplayOrder = 90
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local black = Instance.new("Frame")
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.Parent = gui
	frame = black
	return black
end

-- Goes to black over `seconds`.
function Curtain.close(seconds: number)
	closed = true
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(get(), info, { BackgroundTransparency = 0 }):Play()
end

-- Comes back up from black over `seconds`.
function Curtain.open(seconds: number)
	closed = false
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(get(), info, { BackgroundTransparency = 1 }):Play()
end

function Curtain.isClosed(): boolean
	return closed
end

return Curtain
