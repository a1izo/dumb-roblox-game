-- Building blocks for cutscenes, all local to this client: letterbox bars, title cards in the
-- UI style, screen tints and flashes, a red vignette, spotlights and outlines on characters,
-- and a hold-to-skip button. Each helper cleans up after itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Characters = require(script.Parent.Parent.Characters)

local C = Theme.colors

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

-- A camera frame looking at a character's face from in front of it.
function Cinema.faceShot(character: Model, distance: number, height: number, side: number?): CFrame
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local target = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 1.5, 0)
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local eye = target + look * distance + Vector3.new(0, height, 0) + right * (side or 0)
	return CFrame.lookAt(eye, target)
end

-- Letterbox ------------------------------------------------------------------------------

function Cinema.letterbox(on: boolean)
	letterboxCount = math.max(0, letterboxCount + (if on then 1 else -1))
	local show = letterboxCount > 0
	local height = if show then 0.11 else 0
	Motion.tween(topBar, { Size = UDim2.new(1, 0, height, 0) }, 0.4)
	Motion.tween(bottomBar, { Size = UDim2.new(1, 0, height, 0) }, 0.4)
end

-- Title cards ----------------------------------------------------------------------------

export type CardOptions = {
	title: string,
	subtitle: string?,
	kicker: string?, -- a small line above the title
	color: Color3?, -- ribbon colour (red by default)
	textColor: Color3?,
	y: number?, -- vertical position, 0..1 (0.72 by default)
	typewriter: boolean?, -- type the title out letter by letter
}

-- Shows a tilted ribbon card; returns a function that hides it.
function Cinema.card(options: CardOptions): () -> ()
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, options.y or 0.72)
	group.Size = UDim2.new(1, 0, 0, 170)
	group.Parent = Screens.cinematic
	local column = Widgets.frame({ Parent = group })
	local list = Widgets.list(column, Theme.space.xs, false, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	if options.kicker then
		Widgets.display({
			Text = string.upper(options.kicker),
			TextSize = Theme.text.bodyLarge,
			TextColor3 = C.paper,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
			Parent = column,
		})
	end
	local ribbon = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = options.color or C.accent,
		Size = UDim2.fromOffset(0, 66),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = Theme.tilt,
		LayoutOrder = 2,
		Parent = column,
	})
	Widgets.slant(ribbon, 0.04)
	Widgets.padding(ribbon, 0, 44)
	local title = Widgets.display({
		Text = string.upper(options.title),
		TextSize = 48,
		TextColor3 = options.textColor or C.paper,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = ribbon,
	})
	if options.subtitle and options.subtitle ~= "" then
		local strip = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = C.ink,
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = Theme.tilt,
			LayoutOrder = 3,
			Parent = column,
		})
		Widgets.slant(strip, 0.04)
		Widgets.padding(strip, 0, 26)
		Widgets.label({
			Text = options.subtitle,
			FontFace = Theme.faces.displayMedium,
			TextSize = Theme.text.bodyLarge,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = strip,
		})
	end
	Motion.fade(group, true, 0.2)
	if options.typewriter and not Motion.isReduced() then
		local full = title.Text
		title.Text = ""
		task.spawn(function()
			for i = 1, #full do
				if not group.Parent then
					return
				end
				title.Text = string.sub(full, 1, i)
				task.wait(0.04)
			end
		end)
	end
	local closed = false
	return function()
		if closed then
			return
		end
		closed = true
		local tween = Motion.fade(group, false, 0.3)
		if tween then
			tween.Completed:Once(function()
				group:Destroy()
			end)
		else
			group:Destroy()
		end
	end
end

-- Screen effects -------------------------------------------------------------------------

-- A colour grade on this screen only. Returns a function that fades it out and removes it.
function Cinema.tint(props: { [string]: any }, fadeIn: number?): () -> ()
	local camera = workspace.CurrentCamera
	local effect = Create("ColorCorrectionEffect", { Name = "CinemaTint", Parent = camera })
	local target = table.clone(props)
	Motion.tween(effect, target, fadeIn or 0.4)
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

-- A full-screen colour flash that fades out.
function Cinema.flash(color: Color3, strength: number?, seconds: number?)
	local frame = Widgets.frame({
		BackgroundTransparency = 1 - (strength or 0.6),
		BackgroundColor3 = color,
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

-- A red vignette at the edges of the screen. Returns a function that removes it.
function Cinema.vignette(color: Color3?, strength: number?): () -> ()
	local holder = Widgets.frame({ Name = "Vignette", Parent = Screens.cinematic })
	local edge = strength or 0.35
	local sides = {
		{ UDim2.fromScale(1, edge), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, edge), UDim2.fromScale(0, 1 - edge), -90 },
		{ UDim2.fromScale(edge, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(edge, 1), UDim2.fromScale(1 - edge, 0), 180 },
	}
	for _, side in ipairs(sides) do
		local frame = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = color or C.accent,
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

-- World effects --------------------------------------------------------------------------

-- A hard white (or coloured) spotlight shining down on a character. Returns a remover.
function Cinema.spotlight(character: Model, color: Color3?, seconds: number?): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return function() end
	end
	local rig = Create("Part", {
		Name = "CinemaSpotlight",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 16, 0), root.Position),
		Parent = workspace,
	})
	Create("SpotLight", {
		Face = Enum.NormalId.Front,
		Angle = 40,
		Range = 30,
		Brightness = 6,
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
		FillTransparency = 0.75,
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

-- A "HOLD TO SKIP" button at the bottom right. Returns a remover.
function Cinema.skipButton(onSkip: () -> ()): () -> ()
	local button = Widgets.holdButton({
		Text = "Hold to skip",
		TextSize = Theme.text.small,
		Variant = "ghost",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(150, 36),
		Parent = Screens.cinematic,
	}, 0.6, onSkip)
	return function()
		button:Destroy()
	end
end

function Cinema.init()
	topBar = Widgets.frame({
		Name = "LetterboxTop",
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 0,
		Parent = Screens.cinematic,
	})
	bottomBar = Widgets.frame({
		Name = "LetterboxBottom",
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(0, 0, 0),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 0,
		Parent = Screens.cinematic,
	})
end

return Cinema
