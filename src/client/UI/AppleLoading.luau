--!strict
-- The loading screen (2026-10-27, your sketch of the apple falling through the dark and caught in a hand, after your two
-- frames). Black; a red apple turning as it falls, its height and its turn how far the loading has got (it turns in step
-- with the fall, two whole turns from the top to the hand, and sways a little while a load holds it still); once the
-- loading is done it falls the last stretch (never quicker than MIN_FALL from the top, so a fast load still reads)
-- while a hand in a dark suit sleeve with a white cuff rises from the lower left, thumb up, and catches it, the thumb
-- closing over it and the hand giving a little under its weight. Then the screen goes to black and fades into the
-- game. No text. Full screen, the top bar too.
--
-- The pictures (art/scripts/ui/intro_frames.py and ui/apple_hand.py, laid out by UI/LoadingArt): the apple's turns on
-- four sheets, 64 to a turn (2026-11-03: 16 a turn stepped as it fell; now it turns smoothly), its first cell how it
-- lies in the hand; the hand in layers round it, the inside of the cupped palm behind it and the hand in front of it
-- (the palm's lip, the fingers round its side); and the thumb, a picture of its own that the screen turns about its
-- root, standing up while the hand waits and closing over the apple as it lands (it stepped through four pictures).
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

local MIN_FALL = 1.5 -- seconds the apple takes to fall from the top, at the quickest
local TURNS = 2 -- whole turns it makes from the top to the hand (whole, so it lands as it lies in the hand)
local TOP = 0.12 -- where the apple starts, a share of the screen's height
local CATCH = Vector2.new(0.5, 0.72) -- where it is caught (your frames: a little under the middle)
local HAND_FROM = 0.78 -- how far down it may get before the loading is done; the hand rises for the rest
local LAND = 0.7 -- seconds for that last stretch, the hand rising to meet it
local RISE = Vector2.new(0.42, 1) -- the hand rises along its forearm, from below the screen's lower left
local SWAY = 7 -- degrees the apple sways while a load holds it
local GIVE = 0.014 -- how far the hand gives under the apple's weight, a share of the screen's height
local CLOSE = 0.26 -- seconds the thumb takes to close over the caught apple
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

-- The sheets of the apple's turns that are uploaded, in order (an empty list: the stand-in disc).
local function sheets(): { string }
	local list = {}
	for k = 1, LoadingArt.sheets do
		local id = image("AppleSpin" .. k)
		if id == "" then
			break
		end
		table.insert(list, id)
	end
	return list
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

-- A turn's sheet (1-based among the uploaded ones) and its cell's place on the sheet.
local function cellOf(turn: number, count: number): (number, Vector2)
	local perSheet = LoadingArt.grid * LoadingArt.grid
	local k = turn % (perSheet * count)
	local within = k % perSheet
	local grid = LoadingArt.grid
	return k // perSheet + 1, Vector2.new((within % grid) * LoadingArt.cell, (within // grid) * LoadingArt.cell)
end

-- The apple's cell, a share of the screen's height.
local function cellSize(): number
	return LoadingArt.handHeight * LoadingArt.appleCell
end

-- The apple: a cell of the turning sheets, or (before the pictures are uploaded) a red disc.
local function makeApple(parent: Instance): GuiObject
	local list = sheets()
	if #list > 0 then
		local apple = Instance.new("ImageLabel")
		apple.Name = "Apple"
		apple.BackgroundTransparency = 1
		apple.Image = list[1]
		apple.ImageRectSize = Vector2.new(LoadingArt.cell, LoadingArt.cell)
		apple.ImageRectOffset = Vector2.zero
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

-- One of the hand's pictures (nil until it is uploaded).
local function layer(parent: Instance, name: string, z: number): ImageLabel?
	local id = image(name)
	if id == "" then
		return nil
	end
	local made = Instance.new("ImageLabel")
	made.Name = name
	made.BackgroundTransparency = 1
	made.Image = id
	made.ZIndex = z
	made.Visible = false
	made.Parent = parent
	return made
end

-- The still the teleport carries to the next server (Roblox shows it, unmoving, while the player crosses): the apple at
-- the top of its fall. The next server's join picks it up (first/Cover) and this screen carries on from it.
function AppleLoading.teleportGui(): ScreenGui
	local gui = screen("DGTeleport")
	local apple = makeApple(gui)
	apple.Position = UDim2.fromScale(CATCH.X, TOP)
	apple.Size = UDim2.fromScale(cellSize() * 9 / 16, cellSize())
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = apple
	return gui
end

-- Puts the loading screen up now and returns its loader.
function AppleLoading.open(): Loader
	local gui = screen("DGLoading")
	local black = gui:FindFirstChild("Black") :: Frame
	local turns = sheets()
	local apple = makeApple(black)
	-- (the hand round the apple: the inside of the palm behind it, the hand in front, the thumb over it)
	local back = layer(black, "AppleHandBack", 1)
	local front = layer(black, "AppleHandFront", 3)
	local thumb = layer(black, "AppleThumb", 4)
	if thumb then
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		thumb.Rotation = LoadingArt.thumbOpen
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
		local ids = table.clone(turns)
		for _, part in ipairs({ back, front, thumb }) do
			if part then
				table.insert(ids, part.Image)
			end
		end
		if #ids > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(ids)
			end)
		end
	end)

	local frames = LoadingArt.frames
	local still = Motion.isReduced()
	local target, shown = 0, 0
	local done = false -- the loading is done: the last stretch may fall
	local caught: number? = nil -- when it was caught
	local closed = false
	local give = 0 -- the hand and the apple giving under its weight (screen px down)
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		local size = black.AbsoluteSize
		if size.Y <= 0 then
			return
		end
		if not caught then
			local rate = if shown < HAND_FROM then 1 / MIN_FALL else (1 - HAND_FROM) / LAND
			shown = math.min(if done then 1 else math.min(target, HAND_FROM), shown + dt * rate)
		end
		local t = os.clock() - started
		local handH = size.Y * LoadingArt.handHeight
		local handW = handH * LoadingArt.handAspect
		local cell = size.Y * cellSize()
		local catchAt = Vector2.new(size.X * CATCH.X, size.Y * CATCH.Y)
		local land = math.clamp((shown - HAND_FROM) / (1 - HAND_FROM), 0, 1)
		-- The apple: falling, turning with the fall; swaying and bobbing a little (less as it nears the hand).
		local calm = if still then 0 else 1 - land
		local bob = math.sin(t * 1.7) * size.Y * 0.005 * calm
		apple.Size = UDim2.fromOffset(cell, cell)
		apple.Position = UDim2.fromOffset(catchAt.X, size.Y * TOP + (catchAt.Y - size.Y * TOP) * shown + bob + give)
		apple.Rotation = math.sin(t * 1.25) * SWAY * calm
		if apple:IsA("ImageLabel") and #turns > 0 then
			-- (the turns there are: four sheets' worth once all are uploaded, fewer meanwhile)
			local count = #turns
			local sheet, offset = cellOf(math.floor(shown * TURNS * frames * count / LoadingArt.sheets + 0.5), count)
			if apple.Image ~= turns[sheet] then
				apple.Image = turns[sheet]
			end
			apple.ImageRectOffset = offset
		end
		-- The hand: up along its forearm, eased, as the apple comes down the last stretch.
		local rise = 1 - (1 - land) ^ 3
		local away = (1 - rise) * size.Y * 0.62
		local left = catchAt.X - LoadingArt.catch.X * handW - RISE.X * away
		local top = catchAt.Y - LoadingArt.catch.Y * handH + RISE.Y * away + give
		for _, part in ipairs({ back, front }) do
			if part then
				part.Visible = land > 0
				part.Size = UDim2.fromOffset(handW, handH)
				part.Position = UDim2.fromOffset(left, top)
			end
		end
		if thumb then
			local side = handH * LoadingArt.thumbSize
			thumb.Visible = land > 0
			thumb.Size = UDim2.fromOffset(side, side)
			thumb.Position =
				UDim2.fromOffset(left + LoadingArt.thumbPivot.X * handW, top + LoadingArt.thumbPivot.Y * handH)
			-- (closing over the apple once it is caught: quick at first, settling onto it)
			local closing = if caught then math.clamp((os.clock() - caught) / CLOSE, 0, 1) else 0
			if still and caught then
				closing = 1
			end
			thumb.Rotation = LoadingArt.thumbOpen * (1 - closing) ^ 3
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
			done = true
			local sound = Sfx.play("loadAppleFall")
			local waited = 0
			while shown < 1 and not closed and waited < MIN_FALL + LAND + 1 do
				waited += task.wait()
			end
			if closed then
				return
			end
			-- The catch: the thumb closes over it, and the hand gives a little under it and comes back.
			caught = os.clock()
			shown = 1
			Sfx.play("loadAppleCatch")
			if sound then
				sound:Stop()
			end
			if not Motion.isReduced() then
				local depth = black.AbsoluteSize.Y * GIVE
				local began = os.clock()
				while os.clock() - began < 0.32 and not closed do
					local u = (os.clock() - began) / 0.32
					give = depth * math.sin(math.pi * u) * (1 - u * 0.4)
					task.wait()
				end
				give = 0
			end
			task.wait(0.3)
			-- To black, then the game fades in.
			local dark = TweenService:Create(veil, TweenInfo.new(TO_BLACK), { BackgroundTransparency = 0 })
			dark:Play()
			dark.Completed:Wait()
			connection:Disconnect()
			apple.Visible = false
			for _, part in ipairs({ back, front, thumb }) do
				if part then
					part.Visible = false
				end
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
