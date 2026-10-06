--!strict
-- The way into the lobby, on joining and on coming back from a case: the screen is black, holds for a
-- moment, then the black tears into strips that flicker, slip sideways and fall away (a videotape picking up
-- a signal) until the lobby shows through, about four and a half seconds in all. Then `onRevealed` runs
-- (the lobby's own entrance: the title cards fall in, the rest glitches in).
--
-- On joining, the black is already there: ReplicatedFirst's DGCover put it up on the very first frame (it also
-- hides Roblox's loading screen), and this picks it up. Under reduced motion the black simply fades.

local Players = game:GetService("Players")

local Motion = require(script.Parent.Core.Motion)
local UiSound = require(script.Parent.Core.UiSound)
local Textures = require(script.Parent.Kit.Textures)
local Tokens = require(script.Parent.Kit.Tokens)

local LobbyIntro = {}

local HOLD = 1.5 -- solid black
local REVEAL = 3 -- the black breaking up
local ROWS = 24
local STEP = 1 / 15 -- the strips change on a choppy, tape-like beat

local C = Tokens.color
local playing = false

-- The black screen, found (DGCover's, on joining) or made.
local function cover(): (ScreenGui, Frame)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("DGIntro") :: ScreenGui?
	if not gui then
		local made = Instance.new("ScreenGui")
		made.Name = "DGIntro"
		made.IgnoreGuiInset = true
		made.ScreenInsets = Enum.ScreenInsets.None
		made.DisplayOrder = 1000
		made.ResetOnSpawn = false
		made.Parent = playerGui
		gui = made
	end
	local screen = gui :: ScreenGui
	local black = screen:FindFirstChild("Black") :: Frame?
	if not black then
		local made = Instance.new("Frame")
		made.Name = "Black"
		made.BackgroundColor3 = Color3.new(0, 0, 0)
		made.BorderSizePixel = 0
		made.Size = UDim2.fromScale(1, 1)
		made.Parent = screen
		black = made
	end
	local frame = black :: Frame
	screen:SetAttribute("Claimed", true)
	screen.Enabled = true
	frame.Visible = true
	frame.BackgroundTransparency = 0
	return screen, frame
end

-- Puts the black up now (before coming back from a case, so the lobby is never seen half-built).
function LobbyIntro.cover()
	cover()
end

function LobbyIntro.isPlaying(): boolean
	return playing
end

local function finish(gui: ScreenGui, black: Frame)
	for _, child in ipairs(gui:GetChildren()) do
		if child ~= black then
			child:Destroy()
		end
	end
	black.Visible = false
	gui.Enabled = false
end

-- The black breaks up into the lobby over REVEAL seconds.
local function tear(gui: ScreenGui, black: Frame)
	local strips: { Frame } = {}
	for row = 1, ROWS do
		local strip = Instance.new("Frame")
		strip.Name = "Strip"
		strip.BackgroundColor3 = Color3.new(0, 0, 0)
		strip.BorderSizePixel = 0
		strip.Size = UDim2.new(1.2, 0, 1 / ROWS, 2)
		strip.Position = UDim2.new(-0.1, 0, (row - 1) / ROWS, 0)
		strip.Parent = gui
		strips[row] = strip
	end
	black.Visible = false
	-- A rolling band, two thin split lines (red and white) and the grain, as in the lobby's glitches.
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = C.white
	band.BackgroundTransparency = 0.88
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0.07, 0)
	band.ZIndex = 3
	band.Parent = gui
	local lines: { Frame } = {}
	for index, color in ipairs({ C.danger, C.white, C.white }) do
		local line = Instance.new("Frame")
		line.Name = "Split" .. index
		line.BackgroundColor3 = color
		line.BackgroundTransparency = 0.25
		line.BorderSizePixel = 0
		line.ZIndex = 4
		line.Parent = gui
		lines[index] = line
	end
	local grain: ImageLabel? = nil
	if Textures.has("UiGrain") then
		local image = Instance.new("ImageLabel")
		image.Name = "Grain"
		image.BackgroundTransparency = 1
		image.Image = Textures.id("UiGrain")
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(128, 128)
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = 2
		image.Parent = gui
		grain = image
	end
	local rng = Random.new()
	local started = os.clock()
	UiSound.play("glitch")
	while true do
		local t = (os.clock() - started) / REVEAL
		if t >= 1 then
			break
		end
		-- How much of the black is gone: slow at first, then it falls apart.
		local gone = t ^ 1.6
		-- Early on the whole screen sometimes snaps back to black for a beat (a monitor losing the signal).
		local snap = t < 0.55 and rng:NextNumber() < 0.12
		for _, strip in ipairs(strips) do
			strip.Visible = snap or rng:NextNumber() > gone
			strip.Position = UDim2.new(-0.1, rng:NextInteger(-24, 24) * (1 - t), strip.Position.Y.Scale, 0)
			strip.BackgroundTransparency = if rng:NextNumber() < 0.15 then 0.35 else 0
		end
		band.Visible = rng:NextNumber() < 0.7
		band.Position = UDim2.fromScale(0, rng:NextNumber() * 0.95)
		for _, line in ipairs(lines) do
			line.Visible = rng:NextNumber() < 0.55
			line.Size = UDim2.new(rng:NextNumber(0.25, 0.9), 0, 0, rng:NextInteger(1, 3))
			line.Position = UDim2.new(rng:NextNumber(-0.1, 0.5), 0, rng:NextNumber(), 0)
		end
		if grain then
			grain.ImageTransparency = rng:NextNumber(0.72, 0.9)
			grain.Visible = rng:NextNumber() < 0.8
		end
		task.wait(STEP)
	end
end

-- Plays the intro from black; `onRevealed` runs once the lobby shows. Does nothing if it is already running.
function LobbyIntro.play(onRevealed: (() -> ())?)
	if playing then
		return
	end
	playing = true
	local gui, black = cover()
	task.spawn(function()
		if Motion.isReduced() then
			task.wait(0.6)
			local fade = Motion.tween(black, { BackgroundTransparency = 1 }, 1)
			if fade then
				fade.Completed:Wait()
			end
		else
			task.wait(HOLD)
			tear(gui, black)
		end
		finish(gui, black)
		playing = false
		if onRevealed then
			onRevealed()
		end
	end)
end

return LobbyIntro
