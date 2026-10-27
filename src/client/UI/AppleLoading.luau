--!strict
-- The loading screen (2026-10-27, the owner's references: an apple falling through the dark, caught in a hand). Black;
-- a red apple turning as it falls, its height how far the loading has got (never quicker than MIN_FALL, so a fast load
-- still reads); near the end a hand in a dark suit sleeve with a white cuff comes up, and at the end it catches the
-- apple. Then the screen goes to black and fades into the game. No text. Full screen, the top bar too.
--
-- Every load uses it: a match map (World/MapPreloader), the way back to the lobby (UI/LobbyIntro), and the teleport to
-- a match in another server (its first picture rides the teleport: AppleLoading.teleportGui).
--
--   local loader = AppleLoading.open()
--   loader.progress(0.4)
--   loader.finish(onLift)   -- yields until the game shows again (onLift runs as it starts to show)

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local LoadingArt = require(script.Parent.LoadingArt)
local Motion = require(script.Parent.Core.Motion)

local AppleLoading = {}

local MIN_FALL = 1.5 -- seconds the apple takes to fall at the quickest
local SPIN_FPS = 12 -- frames of its turn a second
local TOP = 0.12 -- where the apple starts, a share of the screen's height
local CATCH = Vector2.new(0.5, 0.64) -- where the hand catches it
local HAND = 0.62 -- the hand's picture, a share of the screen's height
local HAND_FROM = 0.78 -- how far down the apple is when the hand starts to come up
local TO_BLACK = 0.5
local FADE_IN = 1

export type Loader = {
	progress: (fraction: number) -> (),
	finish: (onLift: (() -> ())?) -> (),
	close: () -> (),
	gui: ScreenGui,
}

local function image(name: string): string
	return Assets.contentId(Assets.images[name] or "")
end

-- The screen itself: a ScreenGui of its own over everything (the join's black, DGIntro, sits over it).
local function screen(name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 950
	gui.ResetOnSpawn = false
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.Parent = gui
	return gui
end

local function cellOffset(frame: number): Vector2
	local grid = LoadingArt.grid
	local k = frame % (grid * grid)
	return Vector2.new((k % grid) * LoadingArt.cell, (k // grid) * LoadingArt.cell)
end

-- The apple: a cell of the turning sheet, or (before the pictures are uploaded) a red disc.
local function makeApple(parent: Instance): GuiObject
	local sheet = image("AppleSpin")
	if sheet ~= "" then
		local apple = Instance.new("ImageLabel")
		apple.Name = "Apple"
		apple.BackgroundTransparency = 1
		apple.Image = sheet
		apple.ImageRectSize = Vector2.new(LoadingArt.cell, LoadingArt.cell)
		apple.ImageRectOffset = cellOffset(0)
		apple.AnchorPoint = Vector2.new(0.5, 0.5)
		apple.ZIndex = 2
		apple.Parent = parent
		return apple
	end
	local apple = Instance.new("Frame")
	apple.Name = "Apple"
	apple.BackgroundColor3 = Color3.fromRGB(176, 10, 22)
	apple.BorderSizePixel = 0
	apple.AnchorPoint = Vector2.new(0.5, 0.5)
	apple.ZIndex = 2
	apple.Parent = parent
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = apple
	return apple
end

-- The still the teleport carries to the next server (Roblox shows it, unmoving, while the player crosses): the apple at
-- the top of its fall. The next server's join picks it up (first/Cover) and this screen carries on from it.
function AppleLoading.teleportGui(): ScreenGui
	local gui = screen("DGTeleport")
	local apple = makeApple(gui)
	apple.Position = UDim2.fromScale(CATCH.X, TOP)
	apple.Size = UDim2.fromScale(HAND * LoadingArt.appleScale * 9 / 16, HAND * LoadingArt.appleScale)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = apple
	return gui
end

-- Puts the loading screen up now and returns its loader.
function AppleLoading.open(): Loader
	local gui = screen("DGLoading")
	local black = gui:FindFirstChild("Black") :: Frame
	local apple = makeApple(black)
	local handOpen, handHolding = image("AppleHand1"), image("AppleHand2")
	local hand: ImageLabel? = nil
	if handOpen ~= "" then
		local made = Instance.new("ImageLabel")
		made.Name = "Hand"
		made.BackgroundTransparency = 1
		made.Image = handOpen
		made.ZIndex = 3
		made.Visible = false
		made.Parent = black
		hand = made
	end
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 10
	veil.Parent = black
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.spawn(function()
		local ids = {}
		for _, id in ipairs({ image("AppleSpin"), handOpen, handHolding }) do
			if id ~= "" then
				table.insert(ids, id)
			end
		end
		if #ids > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(ids)
			end)
		end
	end)

	local target, shown = 0, 0
	local started = os.clock()
	local caught = false
	local closed = false
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		local size = black.AbsoluteSize
		if size.Y <= 0 then
			return
		end
		if not caught then
			shown = math.min(target, shown + dt / MIN_FALL)
		end
		local handSize = size.Y * HAND
		local appleSize = handSize * LoadingArt.appleScale
		local catchAt = Vector2.new(size.X * CATCH.X, size.Y * CATCH.Y)
		apple.Size = UDim2.fromOffset(appleSize, appleSize)
		apple.Position = UDim2.fromOffset(catchAt.X, size.Y * TOP + (catchAt.Y - size.Y * TOP) * shown)
		if apple:IsA("ImageLabel") and not Motion.isReduced() then
			apple.ImageRectOffset = cellOffset(math.floor((os.clock() - started) * SPIN_FPS))
		end
		if hand then
			local rise = math.clamp((shown - HAND_FROM) / (1 - HAND_FROM), 0, 1)
			rise = 1 - (1 - rise) ^ 3
			local left = catchAt.X - LoadingArt.catch.X * handSize
			local top = catchAt.Y - LoadingArt.catch.Y * handSize
			hand.Visible = rise > 0
			hand.Size = UDim2.fromOffset(handSize, handSize)
			hand.Position = UDim2.fromOffset(left, size.Y + (top - size.Y) * rise)
		end
	end)

	local function close()
		if closed then
			return
		end
		closed = true
		connection:Disconnect()
		gui:Destroy()
	end

	local loader: Loader
	loader = {
		gui = gui,
		progress = function(fraction: number)
			target = math.max(target, math.clamp(fraction, 0, 1))
		end,
		finish = function(onLift: (() -> ())?)
			target = 1
			local sound = Sfx.play("loadAppleFall")
			local waited = 0
			while shown < 1 and not closed and waited < MIN_FALL + 1 do
				waited += task.wait()
			end
			if closed then
				return
			end
			-- The catch: the hand closes round the apple.
			caught = true
			shown = 1
			if hand and handHolding ~= "" then
				hand.Image = handHolding
				apple.Visible = false
			end
			Sfx.play("loadAppleCatch")
			if sound then
				sound:Stop()
			end
			task.wait(0.35)
			-- To black, then the game fades in.
			local dark = TweenService:Create(veil, TweenInfo.new(TO_BLACK), { BackgroundTransparency = 0 })
			dark:Play()
			dark.Completed:Wait()
			connection:Disconnect()
			apple.Visible = false
			if hand then
				hand.Visible = false
			end
			veil.Visible = false
			if onLift then
				task.spawn(onLift)
			end
			local lift = TweenService:Create(black, TweenInfo.new(FADE_IN), { BackgroundTransparency = 1 })
			lift:Play()
			lift.Completed:Wait()
			close()
		end,
		close = close,
	}
	return loader
end

return AppleLoading
