--!strict
-- A curtain over the whole screen, for a cut that should not be seen: the lobby's falls (a chasm, the world's edge,
-- Controllers/LobbyGamesController) go to black before the body is moved and come back up after (the user's call of
-- 2026-10-27: they had cut straight from the dark to the terrace); the rift's diver is given back at the rim through a
-- white one, as if hauled back up through the cloud (Controllers/DiveController, 2026-11-04).
--
--   Curtain.close(0.35)   Curtain.close(0.35, Color3.new(1, 1, 1))   Curtain.open(0.6)   Curtain.isClosed()

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
	local cover = Instance.new("Frame")
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.Parent = gui
	frame = cover
	return cover
end

-- Closes over `seconds`, to black or to `color`.
function Curtain.close(seconds: number, color: Color3?)
	closed = true
	local cover = get()
	cover.BackgroundColor3 = color or Color3.new(0, 0, 0)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(cover, info, { BackgroundTransparency = 0 }):Play()
end

-- Comes back up over `seconds`.
function Curtain.open(seconds: number)
	closed = false
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(get(), info, { BackgroundTransparency = 1 }):Play()
end

-- A flash of `color` (a body passing through cloud): up to `strength` over `rise` seconds, and away over `fade`.
function Curtain.flash(color: Color3, strength: number, rise: number, fade: number)
	if closed then
		return
	end
	local cover = get()
	cover.BackgroundColor3 = color
	local up = TweenService:Create(
		cover,
		TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 - strength }
	)
	up.Completed:Connect(function()
		if not closed then
			TweenService:Create(
				cover,
				TweenInfo.new(fade, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			):Play()
		end
	end)
	up:Play()
end

function Curtain.isClosed(): boolean
	return closed
end

return Curtain
