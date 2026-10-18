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

-- A line of dialogue at the bottom of the screen, for `seconds`. Returns a function that removes it early.
function Cinema.subtitle(text: string, seconds: number?): () -> ()
	local group = Instance.new("CanvasGroup")
	group.Name = "Subtitle"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.new(0.5, 0, 0.87, 0)
	group.Size = UDim2.new(0.8, 0, 0, 60)
	group.Parent = Screens.cinematic
	Kit.label({
		Text = text,
		font = "label",
		size = "lead",
		color = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
		Parent = group,
	})
	Motion.fade(group, true, 0.2)
	local closed = false
	local function close()
		if not closed then
			closed = true
			fadeAway(group)
		end
	end
	if seconds then
		task.delay(seconds, close)
	end
	return close
end

export type CaptionLine = { text: string, color: Color3?, size: any?, font: string?, head: boolean? }

-- A caption over a cutscene, low on the left, above the letterbox: a small kicker ("YOU ARE") and its
-- lines (a line with head = true is written out in the heading face, `size` in pixels). Fades in;
-- fades out on close() or after `seconds`.
function Cinema.caption(kicker: string, lines: { CaptionLine }, seconds: number?): () -> ()
	local group = Instance.new("CanvasGroup")
	group.Name = "Caption"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0, 1)
	group.Position = UDim2.new(0.06, 0, 0.84, 0)
	group.Size = UDim2.new(0.5, 0, 0, 0)
	group.AutomaticSize = Enum.AutomaticSize.Y
	group.Parent = Screens.cinematic
	Kit.list(group, T.space.xs)
	Kit.label({
		Text = kicker,
		font = "label",
		size = "micro",
		color = C.dim,
		TextStrokeTransparency = 0.6,
		LayoutOrder = 0,
		Parent = group,
	})
	for index, line in ipairs(lines) do
		if line.head then
			local text = Kit.text({
				face = "Head",
				text = line.text,
				size = if type(line.size) == "number" then line.size else T.size.heading + 6,
				color = line.color or C.bone,
				LayoutOrder = index,
				Parent = group,
			})
			text:write(0.6)
		else
			Kit.label({
				Text = line.text,
				font = line.font or "body",
				size = line.size or "small",
				color = line.color or C.white,
				TextStrokeTransparency = 0.5,
				LayoutOrder = index,
				Parent = group,
			})
		end
	end
	Motion.fade(group, true, 0.25)
	local closed = false
	local function close()
		if not closed then
			closed = true
			fadeAway(group)
		end
	end
	if seconds then
		task.delay(seconds, close)
	end
	return close
end

-- A longer black: fades to black over `cover` seconds, shows what `during` puts up (a card, under
-- the black's own layer so it shows on it; it returns its closer) for `hold` seconds, then closes it
-- and fades back over `uncover`. Returns when the screen is clear again.
function Cinema.blackout(cover: number, hold: number, uncover: number, during: (() -> (() -> ())?)?)
	local frame = Kit.Base.make("Frame", {
		Name = "Blackout",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = Screens.cinematic,
	})
	local tween = Motion.tween(frame, { BackgroundTransparency = 0 }, cover)
	if tween then
		tween.Completed:Wait()
	end
	frame.BackgroundTransparency = 0
	local close = if during then during() else nil
	task.wait(hold)
	if close then
		close()
	end
	local out = Motion.tween(frame, { BackgroundTransparency = 1 }, uncover)
	if out then
		out.Completed:Wait()
	end
	frame:Destroy()
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

-- An anime impact frame: for a blink the screen washes over in `color` and thin streaks of light shoot out
-- from the middle, then everything fades. Lands on a hit (a pen driven into the page, a slam).
function Cinema.impact(color: Color3, strength: number?, seconds: number?)
	local life = seconds or 0.22
	local holder = Kit.Base.make("Frame", {
		BackgroundTransparency = 1 - (strength or 0.55),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		ClipsDescendants = true,
		Parent = Screens.cinematic,
	})
	local streaks = {}
	for k = 1, 14 do
		local angle = (k / 14) * 360 + math.random(-10, 10)
		local length = 0.5 + math.random() * 0.6
		local streak = Kit.Base.make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(length, 0, 0, math.random(2, 6)),
			Rotation = angle,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = holder,
		})
		-- the streak starts a little out from the middle, so the centre of the hit stays clear
		Kit.Base.make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 1),
				NumberSequenceKeypoint.new(0.3, 0),
				NumberSequenceKeypoint.new(1, 0.6),
			}),
			Parent = streak,
		})
		table.insert(streaks, streak)
	end
	Motion.tween(holder, { BackgroundTransparency = 1 }, life)
	for _, streak in ipairs(streaks) do
		Motion.tween(streak, { BackgroundTransparency = 1 }, life * 0.8)
	end
	task.delay(life + 0.05, function()
		holder:Destroy()
	end)
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

-- A "Skip" button at the bottom right. Returns a remover.
function Cinema.skipButton(onSkip: () -> ()): () -> ()
	local button = Kit.button({
		text = "Skip",
		variant = "ghost",
		size = "s",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		ZIndex = 6,
		Parent = Screens.cinematic,
	}, onSkip)
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
