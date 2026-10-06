-- Building blocks for cutscenes, all local to this client: letterbox bars, Aktura title cards that cut in
-- with a videotape glitch, captions, dips to black, colour grades, flashes, vignettes, depth of field,
-- spotlights mounted under the ceiling, outlines, and a hold-to-skip button. Every helper returns (or
-- cleans up) what it made. Camera positions come from ShotSolver.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Kit = require(script.Parent.Parent.UI.Kit)
local Glitch = require(script.Parent.Parent.UI.Core.Glitch)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)
local UiSound = require(script.Parent.Parent.UI.Core.UiSound)
local Characters = require(script.Parent.Parent.Characters)
local ShotSolver = require(script.Parent.ShotSolver)

local C = Kit.color
local T = Kit.Tokens

local Cinema = {}

local topBar: Frame
local bottomBar: Frame
local letterboxCount = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Waits until the given server time (does nothing if it has passed).
function Cinema.waitUntil(serverTime: number)
	local left = serverTime - now()
	if left > 0 then
		task.wait(left)
	end
end

-- The character of a player by user id, if it is in the world.
function Cinema.character(userId: number?): Model?
	if not userId then
		return nil
	end
	local character = Characters.byUserId(userId)
	if character and character.Parent and character:FindFirstChild("HumanoidRootPart") then
		return character
	end
	return nil
end

-- A camera frame looking at a character's face from in front of it, moved round or closer if
-- a wall or the ceiling is in the way. `side` is studs to the right (turned into an angle).
function Cinema.faceShot(character: Model, distance: number, height: number, side: number?): CFrame
	local angle = if side and distance > 0 then math.deg(math.atan2(side, distance)) else 0
	return ShotSolver.frame(character, { distance = distance, height = height, angle = angle })
end

-- Letterbox ------------------------------------------------------------------------------------

function Cinema.letterbox(on: boolean)
	letterboxCount = math.max(0, letterboxCount + (if on then 1 else -1))
	local show = letterboxCount > 0
	local height = if show then 0.11 else 0
	Motion.tween(topBar, { Size = UDim2.new(1, 0, height, 0) }, 0.4)
	Motion.tween(bottomBar, { Size = UDim2.new(1, 0, height, 0) }, 0.4)
end

-- Title cards -----------------------------------------------------------------------------------

export type CardOptions = {
	title: string,
	subtitle: string?,
	kicker: string?, -- a small line above the title
	color: Color3?, -- the bar behind the title (black by default; red for danger)
	textColor: Color3?,
	y: number?, -- vertical position, 0..1 (0.72 by default)
	typewriter: boolean?, -- cut the title in letter by letter after the glitch
}

local function fadeAway(group: CanvasGroup)
	local tween = Motion.fade(group, false, 0.3)
	if tween then
		tween.Completed:Once(function()
			group:Destroy()
		end)
	else
		group:Destroy()
	end
end

-- The title in Aktura on a bar that glitches in, the subtitle cut in beneath it. Returns a function that
-- hides it.
function Cinema.card(options: CardOptions): () -> ()
	local group = Instance.new("CanvasGroup")
	group.Name = "Card"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, options.y or 0.72)
	group.Size = UDim2.new(1, 0, 0, 200)
	group.Parent = Screens.cinematic
	local column = Kit.frame({ Parent = group })
	local list = Kit.list(column, T.space.xs, false, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	if options.kicker then
		Kit.label({
			Text = string.upper(options.kicker),
			font = "label",
			size = "small",
			color = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			LayoutOrder = 1,
			Parent = column,
		})
	end
	local banner, title = Kit.banner({
		text = Kit.mixedCase(options.title),
		face = "Title",
		size = if Kit.Layout.isPhone() then T.size.heading else T.size.display,
		tone = options.color or C.g0,
		ink = options.textColor or C.white,
		LayoutOrder = 2,
		Parent = column,
	})
	banner.Rotation = -2
	local subtitle: any = nil
	if options.subtitle and options.subtitle ~= "" then
		subtitle = Kit.text({
			face = "Semi",
			text = options.subtitle,
			size = 28,
			color = C.bone,
			align = "center",
			maxWidth = 900,
			LayoutOrder = 3,
			Parent = column,
		})
	end
	local glitch = Glitch.attach(group, { loop = false })
	UiSound.play("slam")
	if options.typewriter then
		title:write(0.9)
		if subtitle then
			task.delay(0.6, function()
				subtitle:write(0.8)
			end)
		end
	elseif subtitle then
		subtitle:write(0.5)
	end
	local closed = false
	return function()
		if closed then
			return
		end
		closed = true
		glitch:destroy()
		fadeAway(group)
	end
end

-- A caption at the bottom left: a name in Melodrama with a white rule and a line under it.
function Cinema.caption(name: string, line: string?): () -> ()
	local group = Instance.new("CanvasGroup")
	group.Name = "Caption"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0, 1)
	group.Position = UDim2.new(0, 48, 0.86, 0)
	group.Size = UDim2.fromOffset(700, 110)
	group.Parent = Screens.cinematic
	local nameText = Kit.text({
		face = "Head",
		text = name,
		size = 48,
		color = C.bone,
		Position = UDim2.fromOffset(0, 0),
		Parent = group,
	})
	if line and line ~= "" then
		Kit.label({
			Text = line,
			font = "label",
			size = "lead",
			color = C.dim,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Position = UDim2.fromOffset(4, 70),
			Parent = group,
		})
	end
	Kit.Base.make("Frame", {
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 64),
		Size = UDim2.fromOffset(90, 3),
		Parent = group,
	})
	local glitch = Glitch.attach(group, { loop = false })
	nameText:write(0.5)
	local closed = false
	return function()
		if not closed then
			closed = true
			glitch:destroy()
			fadeAway(group)
		end
	end
end

-- A quick dip to black between two shots: covers, calls `during`, uncovers.
function Cinema.dip(seconds: number?, during: (() -> ())?)
	local half = (seconds or 0.3) / 2
	local frame = Kit.Base.make("Frame", {
		Name = "Dip",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = Screens.cinematic,
	})
	local tween = Motion.tween(frame, { BackgroundTransparency = 0 }, half)
	if tween then
		tween.Completed:Wait()
	end
	if during then
		during()
	end
	local out = Motion.tween(frame, { BackgroundTransparency = 1 }, half)
	if out then
		out.Completed:Once(function()
			frame:Destroy()
		end)
	else
		frame:Destroy()
	end
end

-- Screen effects ----------------------------------------------------------------------------------

-- A colour grade on this screen only. Returns a function that fades it out and removes it.
function Cinema.tint(props: { [string]: any }, fadeIn: number?): () -> ()
	local camera = workspace.CurrentCamera
	local effect = Create("ColorCorrectionEffect", { Name = "CinemaTint", Parent = camera })
	Motion.tween(effect, table.clone(props), fadeIn or 0.4)
	return function()
		local tween =
			Motion.tween(effect, { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1), Brightness = 0 }, 0.5)
		if tween then
			tween.Completed:Once(function()
				effect:Destroy()
			end)
		else
			effect:Destroy()
		end
	end
end

-- Softens everything but the subject (depth of field). Returns a remover.
function Cinema.focus(distance: number, radius: number?): () -> ()
	local effect = Create("DepthOfFieldEffect", {
		Name = "CinemaFocus",
		FarIntensity = 0,
		NearIntensity = 0,
		FocusDistance = distance,
		InFocusRadius = radius or 6,
		Parent = workspace.CurrentCamera,
	})
	Motion.tween(effect, { FarIntensity = 0.45, NearIntensity = 0.3 }, 0.4)
	return function()
		effect:Destroy()
	end
end

-- A full-screen colour flash that fades out.
function Cinema.flash(color: Color3, strength: number?, seconds: number?)
	local frame = Kit.Base.make("Frame", {
		BackgroundTransparency = 1 - (strength or 0.6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = Screens.cinematic,
	})
	local tween = Motion.tween(frame, { BackgroundTransparency = 1 }, seconds or 0.5)
	if tween then
		tween.Completed:Once(function()
			frame:Destroy()
		end)
	else
		frame:Destroy()
	end
end

-- A coloured vignette at the edges of the screen. Returns a function that removes it.
function Cinema.vignette(color: Color3?, strength: number?): () -> ()
	local holder = Kit.frame({ Name = "Vignette", Parent = Screens.cinematic })
	local edge = strength or 0.35
	local sides = {
		{ UDim2.fromScale(1, edge), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, edge), UDim2.fromScale(0, 1 - edge), -90 },
		{ UDim2.fromScale(edge, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(edge, 1), UDim2.fromScale(1 - edge, 0), 180 },
	}
	for _, side in ipairs(sides) do
		local frame = Kit.Base.make("Frame", {
			BackgroundTransparency = 0,
			BackgroundColor3 = color or C.g0,
			BorderSizePixel = 0,
			Size = side[1],
			Position = side[2],
			Parent = holder,
		})
		Create("UIGradient", {
			Rotation = side[3],
			Transparency = NumberSequence.new(0.35, 1),
			Parent = frame,
		})
	end
	return function()
		holder:Destroy()
	end
end

-- World effects ---------------------------------------------------------------------------------

-- A hard spotlight shining down on a character, hung just under the ceiling (never above the
-- roof, where it would light nothing). Returns a remover.
function Cinema.spotlight(character: Model, color: Color3?, seconds: number?): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return function() end
	end
	local roof = ShotSolver.ceiling(root.Position, 20)
	local height = math.min(14, (roof - root.Position.Y) - 1)
	local rig = Create("Part", {
		Name = "CinemaSpotlight",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.lookAt(root.Position + Vector3.new(0, math.max(height, 4), 0), root.Position),
		Parent = workspace.CurrentCamera,
	})
	Create("SpotLight", {
		Face = Enum.NormalId.Front,
		Angle = 50,
		Range = 28,
		Brightness = 7,
		Color = color or Color3.new(1, 1, 1),
		Shadows = true,
		Parent = rig,
	})
	local function remove()
		rig:Destroy()
	end
	if seconds then
		task.delay(seconds, remove)
	end
	return remove
end

-- An outline around a character (or any model). Returns a remover.
function Cinema.outline(model: Instance, color: Color3, seconds: number?): () -> ()
	local highlight = Create("Highlight", {
		Adornee = model,
		FillColor = color,
		FillTransparency = 0.8,
		OutlineColor = color,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Parent = workspace.CurrentCamera,
	})
	local function remove()
		highlight:Destroy()
	end
	if seconds then
		task.delay(seconds, remove)
	end
	return remove
end

-- A "Hold to skip" button at the bottom right. Returns a remover.
function Cinema.skipButton(onSkip: () -> ()): () -> ()
	local button = Kit.hold({
		text = "Hold to skip",
		variant = "ghost",
		size = "s",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		ZIndex = 6,
		Parent = Screens.cinematic,
	}, 0.6, onSkip)
	return function()
		button:Destroy()
	end
end

function Cinema.init()
	topBar = Kit.Base.make("Frame", {
		Name = "LetterboxTop",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 0,
		Parent = Screens.cinematic,
	})
	bottomBar = Kit.Base.make("Frame", {
		Name = "LetterboxBottom",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 0,
		Parent = Screens.cinematic,
	})
end

return Cinema
