--!strict
-- The first join (2026-10-27, the owner's references: an anime eye in close profile, shut, then opening red). From
-- black, a face in close profile in the dark, hair falling across it, the eye shut; it holds (two seconds at least,
-- longer until the game has loaded) while the view creeps in on the eye and the near hair drifts across it; then the
-- eye opens, red, a glint in it, with a flare; a second's fade to black and three seconds' fade into the lobby. Once
-- everything has loaded, a click, a tap or a key skips what is left.
--
-- The picture is painted in layers (art/scripts/ui/eye_intro.py, laid out by UI/EyeArt): the face in two halves, the
-- eye's corner in four frames laid over it as it opens, and the foreground hair in two halves, which moves more than the
-- face, for depth; dust in the air and film grain over it. It is drawn on ReplicatedFirst's DGIntro (first/Cover: black
-- from the very first frame, full screen, the top bar too), which may already show the face.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local EyeArt = require(script.Parent.EyeArt)
local Motion = require(script.Parent.Core.Motion)
local Textures = require(script.Parent.Kit.Textures)

local EyeIntro = {}

local HOLD = 2 -- the shut eye, at least
local MOST = 45 -- the longest the intro waits for the game to load
local OPEN_STEPS = { 0.06, 0.06, 0.07 } -- each frame of the eye opening (the last stays)
local OPEN_HOLD = 1.3 -- the open eye, looking
local TO_BLACK = 1
local INTO_LOBBY = 3
local CREEP = 0.045 -- how much nearer the view creeps over the hold
local CREEP_TIME = 10
local NEAR = 2.2 -- how much more the near hair moves than the face
local MOTES = 18

local function image(name: string): string
	return Assets.contentId(Assets.images[name] or "")
end

local function picture(name: string, parent: Instance, position: UDim2, size: UDim2, z: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Image = image(name)
	label.ScaleType = Enum.ScaleType.Stretch
	label.Position = position
	label.Size = size
	label.ZIndex = z
	label.Parent = parent
	return label
end

-- The stage: the picture's layers, made here or found where Cover made them.
type Stage = { face: Frame, near: Frame, eye: ImageLabel }

local function stageOf(black: Frame): Stage
	local face = black:FindFirstChild("Face") :: Frame?
	if not face then
		local made = Instance.new("Frame")
		made.Name = "Face"
		made.BackgroundTransparency = 1
		made.ZIndex = 1
		made.Parent = black
		picture("IntroBaseL", made, UDim2.fromScale(0, 0), UDim2.fromScale(0.5, 1), 1)
		picture("IntroBaseR", made, UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1), 1)
		face = made
	end
	local near = black:FindFirstChild("Near") :: Frame?
	if not near then
		local made = Instance.new("Frame")
		made.Name = "Near"
		made.BackgroundTransparency = 1
		made.ZIndex = 3
		made.Parent = black
		picture("IntroHairL", made, UDim2.fromScale(0, 0), UDim2.fromScale(0.5, 1), 3)
		picture("IntroHairR", made, UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1), 3)
		near = made
	end
	-- (Cover's halves may not have their pictures yet: the list of them arrives with the game)
	for _, layer in ipairs({ face, near }) do
		for _, half in ipairs((layer :: Frame):GetChildren()) do
			if half:IsA("ImageLabel") and half.Image == "" then
				half.Image = image(half.Name)
			end
		end
	end
	local crop = EyeArt.crop
	local eye = picture("IntroEye1", face :: Frame, UDim2.fromScale(crop.x, crop.y), UDim2.fromScale(crop.w, crop.h), 2)
	eye.Name = "Opening"
	eye.Visible = false
	return { face = face :: Frame, near = near :: Frame, eye = eye }
end

-- Lays a layer over the screen (covering it, the picture's shape kept) at `zoom`, closing in on the eye, moved `drift`.
local function lay(layer: Frame, view: Vector2, zoom: number, drift: Vector2)
	local scale = math.max(view.X / EyeArt.size.X, view.Y / EyeArt.size.Y)
	local base = EyeArt.size * scale
	local size = base * zoom
	local origin = (view - base) / 2
	local focus = EyeArt.eye * base
	local at = origin + focus * (1 - zoom) + drift
	layer.Size = UDim2.fromOffset(size.X, size.Y)
	layer.Position = UDim2.fromOffset(at.X, at.Y)
end

-- Plays the intro on `gui` (DGIntro); `isLoaded` says when the game is ready to be seen; `onRevealed` runs as the
-- lobby starts to fade in. Returns once the lobby shows.
function EyeIntro.play(gui: ScreenGui, isLoaded: () -> boolean, onRevealed: (() -> ())?)
	local black = gui:FindFirstChild("Black") :: Frame
	local drawn = image("IntroBaseL") ~= "" and image("IntroBaseR") ~= ""
	local ambience = Sfx.play("introAmbience", { looped = true, group = "Ambience" })
	local still = Motion.isReduced()

	local stage = stageOf(black)
	local frames = {}
	for k = 1, EyeArt.frames do
		frames[k] = image("IntroEye" .. k)
	end
	-- dust in the light, and the film's grain
	local motes: { { frame: Frame, at: Vector2, speed: number } } = {}
	local rng = Random.new()
	for k = 1, MOTES do
		local mote = Instance.new("Frame")
		mote.Name = "Mote"
		mote.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
		mote.BackgroundTransparency = rng:NextNumber(0.55, 0.85)
		mote.BorderSizePixel = 0
		local size = rng:NextInteger(2, 5)
		mote.Size = UDim2.fromOffset(size, size)
		mote.ZIndex = 4
		mote.Parent = black
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = mote
		motes[k] = {
			frame = mote,
			at = Vector2.new(rng:NextNumber(), rng:NextNumber()),
			speed = rng:NextNumber(0.004, 0.014),
		}
	end
	local grain: ImageLabel? = nil
	if Textures.has("UiGrain") then
		local made = Instance.new("ImageLabel")
		made.Name = "Grain"
		made.BackgroundTransparency = 1
		made.Image = Textures.id("UiGrain")
		made.ScaleType = Enum.ScaleType.Tile
		made.TileSize = UDim2.fromOffset(160, 160)
		made.ImageTransparency = 0.88
		made.Size = UDim2.new(1, 160, 1, 160)
		made.ZIndex = 5
		made.Parent = black
		grain = made
	end
	if drawn then
		local ids = { image("IntroBaseL"), image("IntroBaseR"), image("IntroHairL"), image("IntroHairR") }
		for _, id in ipairs(frames) do
			table.insert(ids, id)
		end
		pcall(function()
			ContentProvider:PreloadAsync(ids)
		end)
	end
	-- (the layers come up out of the black, unless Cover already brought them up)
	for _, layer in ipairs({ stage.face, stage.near }) do
		for _, label in ipairs(layer:GetChildren()) do
			if label:IsA("ImageLabel") and label.ImageTransparency > 0 and label ~= stage.eye then
				TweenService:Create(label, TweenInfo.new(1.2), { ImageTransparency = 0 }):Play()
			end
		end
	end

	local started = os.clock()
	local kick = 0 -- the small push as the eye opens
	local live = RunService.RenderStepped:Connect(function(dt: number)
		local view = black.AbsoluteSize
		if view.X <= 0 then
			return
		end
		local t = os.clock() - started
		local creep = if still then 0 else CREEP * math.min(1, t / CREEP_TIME) ^ 0.8
		local zoom = 1 + creep + kick
		lay(stage.face, view, zoom, Vector2.zero)
		local drift = if still then Vector2.zero else Vector2.new(math.sin(t * 0.31) * 8, -math.min(t, 14) * 1.6)
		lay(stage.near, view, 1 + (zoom - 1) * NEAR, drift)
		for _, mote in ipairs(motes) do
			if not still then
				mote.at = Vector2.new(
					(mote.at.X + math.sin(t * 0.5 + mote.speed * 400) * 0.0006) % 1,
					(mote.at.Y - mote.speed * dt) % 1
				)
			end
			mote.frame.Position = UDim2.fromScale(mote.at.X, mote.at.Y)
		end
		if grain and not still then
			grain.Position = UDim2.fromOffset(-rng:NextInteger(0, 159), -rng:NextInteger(0, 159))
		end
	end)

	local skipped = false
	local skip = UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		local press = kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or kind == Enum.UserInputType.Gamepad1
		if press and isLoaded() then
			skipped = true
		end
	end)
	-- Held shut until the game has loaded (and two seconds at least).
	while not skipped and os.clock() - started < MOST and (os.clock() - started < HOLD or not isLoaded()) do
		task.wait(0.1)
	end
	-- It opens: the frames, a red flare, the view pushing in a little with it.
	if not skipped and drawn then
		Sfx.play("introEyeOpen")
		stage.eye.Visible = true
		for k = 1, #frames do
			stage.eye.Image = frames[k]
			if k < #frames and not still then
				task.wait(OPEN_STEPS[k] or 0.06)
			end
		end
		local flare = Instance.new("Frame")
		flare.Name = "Flare"
		flare.BackgroundColor3 = Color3.fromRGB(200, 10, 24)
		flare.BackgroundTransparency = 0.82
		flare.BorderSizePixel = 0
		flare.Size = UDim2.fromScale(1, 1)
		flare.ZIndex = 6
		flare.Parent = black
		TweenService:Create(flare, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		if not still then
			local from = os.clock()
			task.spawn(function()
				while os.clock() - from < 0.9 do
					local p = (os.clock() - from) / 0.9
					kick = 0.02 * (1 - (1 - p) ^ 3)
					task.wait()
				end
			end)
		end
		local looked = os.clock()
		while not skipped and os.clock() - looked < OPEN_HOLD do
			task.wait(0.05)
		end
	end
	skip:Disconnect()
	-- To black, then into the lobby (quicker when skipped).
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 10
	veil.Parent = black
	local dark =
		TweenService:Create(veil, TweenInfo.new(if skipped then 0.3 else TO_BLACK), { BackgroundTransparency = 0 })
	dark:Play()
	dark.Completed:Wait()
	live:Disconnect()
	if ambience then
		TweenService:Create(ambience, TweenInfo.new(INTO_LOBBY), { Volume = 0 }):Play()
		task.delay(INTO_LOBBY, function()
			ambience:Destroy()
		end)
	end
	for _, child in ipairs(black:GetChildren()) do
		child:Destroy()
	end
	if onRevealed then
		task.spawn(onRevealed)
	end
	local lift =
		TweenService:Create(black, TweenInfo.new(if skipped then 1 else INTO_LOBBY), { BackgroundTransparency = 1 })
	lift:Play()
	lift.Completed:Wait()
end

return EyeIntro
