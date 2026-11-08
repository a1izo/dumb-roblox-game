--!strict
-- What the second batch of custom deaths (2026-11-08, art/scripts/deaths_scenes.py) puts on the screen and over the
-- body, beyond the VFX kit: each echoes the scene the death re-acts (Presentation/DeathVfx and CustomDeaths call them).
--
--   DeathScreen.chat(text, color, seconds)       -- a line in an old game's chat box, low on the left (the god's boast)
--   DeathScreen.glyph(text, color, seconds)      -- one big character slammed onto the screen (a blade's 斬)
--   DeathScreen.zzz(head, seconds)               -- Z's drifting up off a sleeping head
--   DeathScreen.bar(head, seconds, drainAt)      -- a health bar over the head, emptied in one hit
--   DeathScreen.ghost(model, color, life)        -- a see-through afterimage of the body where it is now
--
-- All local to this screen, gone by themselves; nothing flashes with flashes off (Motion.flashesOff).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)

local DeathScreen = {}

local function layer(): Instance
	local gui = Screens.cinematic
	if gui then
		return gui
	end
	local player = Players.LocalPlayer
	return player:WaitForChild("PlayerGui")
end

local function fade(item: GuiObject, seconds: number, props: { [string]: any })
	local tween =
		TweenService:Create(item, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- A line in an old game's chat box: low on the left over the letterbox, small pixel letters in `color` with a dark
-- edge, typed out in a blink and gone after `seconds`.
function DeathScreen.chat(text: string, color: Color3, seconds: number?)
	local life = seconds or 3.2
	local label = Instance.new("TextLabel")
	label.Name = "DeathChat"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0.03, 0, 0.84, 0)
	label.Size = UDim2.new(0.7, 0, 0, 30)
	label.Font = Enum.Font.Arcade
	label.TextSize = 28
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.RichText = false
	label.Text = text
	label.MaxVisibleGraphemes = 0
	label.ZIndex = 6
	label.Parent = layer()
	task.spawn(function()
		local count = utf8.len(text) or #text
		for shown = 1, count, 2 do
			if not label.Parent then
				return
			end
			label.MaxVisibleGraphemes = shown
			task.wait(0.012)
		end
		label.MaxVisibleGraphemes = -1
	end)
	task.delay(life, function()
		if label.Parent then
			fade(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 }).Completed:Once(function()
				label:Destroy()
			end)
		end
	end)
end

-- One big character slammed onto the screen, right of centre: in at twice its size, settling in a tenth of a second,
-- held, then gone in a smear.
function DeathScreen.glyph(text: string, color: Color3, seconds: number?)
	local life = seconds or 0.9
	local label = Instance.new("TextLabel")
	label.Name = "DeathGlyph"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.68, 0.42)
	label.Size = UDim2.fromScale(0.5, 0.5)
	label.SizeConstraint = Enum.SizeConstraint.RelativeYY
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.Rotation = -6
	label.ZIndex = 6
	label.Parent = layer()
	local scale = Instance.new("UIScale")
	scale.Scale = if Motion.isReduced() then 1 else 2
	scale.Parent = label
	if not Motion.isReduced() then
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	task.delay(life, function()
		if label.Parent then
			TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 1.15 }):Play()
			fade(label, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1 }).Completed:Once(function()
				label:Destroy()
			end)
		end
	end)
end

local function billboard(head: BasePart, size: UDim2, lift: number, name: string): BillboardGui
	local board = Instance.new("BillboardGui")
	board.Name = name
	board.Adornee = head
	board.Size = size
	board.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
	board.AlwaysOnTop = false
	board.LightInfluence = 0
	board.MaxDistance = 120
	board.Parent = workspace.CurrentCamera
	return board
end

-- Z's drifting up off a sleeping head, one after another, for `seconds`.
function DeathScreen.zzz(head: BasePart, seconds: number)
	local board = billboard(head, UDim2.fromScale(3, 3), 1.6, "DeathZzz")
	local ended = false
	task.delay(seconds, function()
		ended = true
	end)
	task.spawn(function()
		local k = 0
		while not ended and board.Parent and head.Parent do
			k += 1
			local z = Instance.new("TextLabel")
			z.BackgroundTransparency = 1
			z.AnchorPoint = Vector2.new(0.5, 0.5)
			z.Position = UDim2.fromScale(0.35, 0.85)
			z.Size = UDim2.fromScale(0.28 + (k % 3) * 0.06, 0.28 + (k % 3) * 0.06)
			z.Font = Enum.Font.Arcade
			z.TextScaled = true
			z.Text = "Z"
			z.TextColor3 = Color3.fromRGB(235, 235, 240)
			z.TextStrokeTransparency = 0.3
			z.Parent = board
			fade(z, 1.1, { Position = UDim2.fromScale(0.75, 0.1), TextTransparency = 1, TextStrokeTransparency = 1 })
			task.delay(1.15, function()
				z:Destroy()
			end)
			task.wait(0.38)
		end
		task.wait(1.2)
		board:Destroy()
	end)
end

-- A health bar over the head (yellow on red, an old fight screen's), whole until `drainAt` seconds from now, when one
-- hit empties it; gone after `seconds`.
function DeathScreen.bar(head: BasePart, seconds: number, drainAt: number)
	local board = billboard(head, UDim2.fromScale(3.2, 0.42), 1.9, "DeathBar")
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	task.delay(drainAt, function()
		if fill.Parent then
			TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
				:Play()
		end
	end)
	task.delay(seconds, function()
		board:Destroy()
	end)
end

-- A face drawn over a head's own (on this screen): "shock" (wide eyes, pinprick pupils, mouth open), "shout", "pain"
-- (eyes squeezed shut, teeth), "sleep" (eyes closed), "smug" (half-lidded, a wide grin), "sad" (brows up, eyes down).
-- The head's own face decals are hidden while it shows. Returns a function that puts the head's face back.
local function blob(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	round: number?,
	r: number?
)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = r or 0
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

function DeathScreen.face(head: BasePart, kind: string): () -> ()
	local old = head:FindFirstChild("DGDrawnFace")
	if old then
		old:Destroy()
	end
	local hidden = {}
	for _, item in ipairs(head:GetChildren()) do
		if item:IsA("Decal") and item.Transparency < 1 then
			hidden[item] = item.Transparency
			item.Transparency = 1
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DGDrawnFace"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 1
	gui.Parent = head
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local black, white = Color3.fromRGB(16, 12, 12), Color3.fromRGB(250, 248, 244)
	local red = Color3.fromRGB(150, 20, 24)
	if kind == "shock" or kind == "shout" then
		for _, side in ipairs({ -1, 1 }) do
			local x = 0.5 + side * 0.17
			blob(root, x, 0.4, 0.2, 0.22, white, 1)
			blob(root, x, 0.41, 0.045, 0.05, black, 1)
			blob(root, x, 0.25, 0.2, 0.03, black, nil, if kind == "shout" then side * 18 else -side * 12)
		end
		if kind == "shout" then
			local m = blob(root, 0.5, 0.72, 0.36, 0.2, black, 0.4)
			blob(m, 0.5, 0.75, 0.6, 0.35, red, 0.5)
		else
			blob(root, 0.5, 0.72, 0.13, 0.17, black, 1)
		end
	elseif kind == "pain" then
		for _, side in ipairs({ -1, 1 }) do
			local x = 0.5 + side * 0.17
			blob(root, x, 0.4, 0.17, 0.035, black, nil, side * 22)
			blob(root, x, 0.44, 0.17, 0.035, black, nil, -side * 22)
		end
		local m = blob(root, 0.5, 0.72, 0.34, 0.12, black, 0.2)
		blob(m, 0.5, 0.5, 0.86, 0.3, white, nil)
	elseif kind == "sleep" then
		for _, side in ipairs({ -1, 1 }) do
			blob(root, 0.5 + side * 0.17, 0.43, 0.16, 0.03, black, 1)
		end
		blob(root, 0.5, 0.7, 0.08, 0.06, black, 1)
	elseif kind == "smug" then
		for _, side in ipairs({ -1, 1 }) do
			local x = 0.5 + side * 0.17
			local eye = blob(root, x, 0.42, 0.17, 0.11, white, 1)
			blob(eye, 0.5, 0.0, 1.1, 0.55, black, nil)
			blob(root, x, 0.45, 0.04, 0.04, black, 1)
		end
		local m = blob(root, 0.5, 0.7, 0.5, 0.13, black, 0.3)
		blob(m, 0.5, 0.45, 0.9, 0.42, white, 0.2)
	elseif kind == "sad" then
		for _, side in ipairs({ -1, 1 }) do
			local x = 0.5 + side * 0.17
			blob(root, x, 0.44, 0.12, 0.08, black, 1)
			blob(root, x, 0.31, 0.17, 0.025, black, nil, side * 14)
		end
		blob(root, 0.5, 0.74, 0.18, 0.025, black, nil, 0)
	end
	return function()
		gui:Destroy()
		for item, transparency in pairs(hidden) do
			if item.Parent then
				item.Transparency = transparency
			end
		end
	end
end

local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

-- A see-through copy of the body as it stands now, in `color`, fading over `life` seconds (an afterimage).
function DeathScreen.ghost(model: Model, color: Color3, life: number, from: number?)
	local folder = Instance.new("Folder")
	folder.Name = "DeathGhost"
	for _, name in ipairs(LIMBS) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") and part.Parent then
			local copy = Instance.new("Part")
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.Material = Enum.Material.Neon
			copy.Color = color
			copy.Size = part.Size * (if name == "Head" then Vector3.new(1, 1, 1) else Vector3.new(1.02, 1.02, 1.02))
			if name == "Head" then
				copy.Shape = Enum.PartType.Block
				copy.Size = Vector3.new(1.2, 1.2, 1.2)
			end
			copy.CFrame = part.CFrame
			copy.Transparency = from or 0.6
			copy.Parent = folder
			TweenService:Create(copy, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
		end
	end
	folder.Parent = workspace.CurrentCamera
	task.delay(life + 0.1, function()
		folder:Destroy()
	end)
end

return DeathScreen
