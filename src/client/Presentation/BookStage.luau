-- Death's Manual alone in the dark, open, with names being written in it. Three cutscenes use it: a
-- death by the Manual opens on it (Presenters/Death), Diavolo sees the name he wrote go in
-- (Presenters/ManualWrite), and the ending shows every name written in the match (Presenters/Outro).
-- The owner's staging (2026-10-12): nothing but the book on a black floor under one soft light from
-- above, no place and no hands, so it never shows who wrote. Like every set, it exists on this screen
-- alone.
--
--   local stop = BookStage.play(token, { { text = "Kenji Mori" }, { text = "Heart attack", small = true } }, 1.6)
--
-- A writing style (Diavolo's, from the shop: Presentation/Styles) changes the ink and how each line goes
-- in; without one it is plain dark ink from a pen.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local ManualBook = require(Shared:WaitForChild("ManualBook"))
local Models = require(Shared:WaitForChild("Models"))

local CameraDirector = require(script.Parent.CameraDirector)
local Stage = require(script.Parent.Stage)
local Styles = require(script.Parent.Styles)
local Vfx = require(script.Parent.Vfx)

local BookStage = {}

export type Line = {
	text: string,
	struck: boolean?, -- crossed out once written (a name that took a life, at the ending)
	small: boolean?, -- a smaller hand (the cause under a name)
}

local SET = Vector3.new(0, 1500, 300) -- far above the world, beside the role reveal's void
local INK = Color3.fromRGB(26, 17, 11)
local PIXELS = 380 -- per stud, on the page (sharp in the close-up; the page stays under 1024 across)
local STROKE = math.floor(PIXELS * 0.012) -- a strike-through's thickness
local LIGHT = 2.6

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	return Create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- The set: a black floor, a black lid high above it that keeps the sky off, and one soft light.
local function buildSet(stage: any, page: Vector3)
	local set = Instance.new("Model")
	set.Name = "Manual"
	local dark = Color3.fromRGB(9, 8, 10)
	block(set, Vector3.new(60, 1, 60), CFrame.new(SET - Vector3.new(0, 0.5, 0)), dark)
	block(set, Vector3.new(60, 1, 60), CFrame.new(SET + Vector3.new(0, 14, 0)), dark)
	-- The light hangs a little over the page. (A spotlight from higher up lit nothing in the game, which left
	-- the Manual's whole shot black: a point light close over the book is what reads, its falloff giving the
	-- pool of light in the dark.)
	local lamp = block(set, Vector3.new(0.2, 0.2, 0.2), CFrame.new(page + Vector3.new(0.4, 3.2, -0.8)), dark)
	lamp.Transparency = 1
	lamp.CastShadow = false
	-- (Each mood sets its own exposure: the lamp makes up for it, so the page reads in every phase.)
	local exposure = math.clamp(Lighting.ExposureCompensation, -3, 3)
	Create("PointLight", {
		Range = 9,
		Brightness = LIGHT * 1.6 * 2 ^ -exposure,
		Color = Color3.fromRGB(255, 240, 222),
		Shadows = false,
		Parent = lamp,
	})
	-- Dust turning slowly in the lamp's light over the page: the dark has air in it, the place stays nowhere (the
	-- owner's staging holds; 2026-10-26: "polish the cutscenes even more"). None under Low quality.
	if not Vfx.quiet() then
		local motes = block(set, Vector3.new(4.5, 3, 4.5), CFrame.new(page + Vector3.new(0, 1.7, 0)), dark)
		motes.Transparency = 1
		motes.CastShadow = false
		Vfx.Emit.make(motes, {
			tex = "VfxEmber",
			color = Color3.fromRGB(214, 206, 192),
			size = { { 0, 0.05 }, { 1, 0.03 } },
			alpha = { { 0, 1 }, { 0.3, 0.5 }, { 0.7, 0.55 }, { 1, 1 } },
			life = { 4, 6 },
			speed = { 0.04, 0.14 },
			spread = 180,
			rot = { 0, 360 },
			spin = { -20, 20 },
			rate = 8,
			light = 0,
			lit = 1,
			shape = Enum.ParticleEmitterShape.Box,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
	end
	stage:add(set)
end

-- One line of the page as a clipped strip, empty at first: write() uncovers its text from the left,
-- as a pen moves (a font carries no strokes to follow).
local function strip(gui: SurfaceGui, rule: ManualBook.Rule, row: number, line: Line, style: string?)
	local top = (rule.first + row * rule.pitch - rule.pitch * 0.92) * PIXELS
	local left = (rule.margin + 0.07) * PIXELS
	local wide = (rule.size.X - rule.margin - 0.16) * PIXELS
	local clip = Create("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(left, top),
		Size = UDim2.fromOffset(0, rule.pitch * PIXELS),
		Parent = gui,
	})
	local colour, font = Styles.pen(style)
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(wide, rule.pitch * PIXELS),
		Text = line.text,
		FontFace = font,
		TextSize = math.floor(rule.pitch * PIXELS * (if line.small then 0.6 else 0.86)),
		TextColor3 = if line.small then INK else colour,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = clip,
	})
	return clip, label, wide
end

-- Writes the lines one after another over `seconds`.
local function write(gui: SurfaceGui, rule: ManualBook.Rule, lines: { Line }, seconds: number, style: string?)
	local letters = 0
	for _, line in ipairs(lines) do
		letters += math.max(4, #line.text)
	end
	local pace = math.min(0.07, seconds / math.max(1, letters))
	for row, line in ipairs(lines) do
		if row > rule.count then
			break
		end
		local lineStyle = if line.small then nil else style
		local clip, label, wide = strip(gui, rule, row - 1, line, lineStyle)
		task.wait()
		-- (The font may still be on its way: then the hand's usual width per letter.)
		local measured = if label.TextBounds.X > 1 then label.TextBounds.X else #line.text * label.TextSize * 0.48
		local shown = math.min(wide, measured + PIXELS * 0.04)
		Styles.write(clip, label, shown, pace, lineStyle)
		if line.struck then
			local bar = Create("Frame", {
				BackgroundColor3 = INK,
				BorderSizePixel = 0,
				Position = UDim2.new(0, -STROKE, 0.62, 0),
				Size = UDim2.fromOffset(0, STROKE),
				Rotation = -1.5,
				Parent = clip,
			})
			local stroke = UDim2.fromOffset(shown + 2 * STROKE, STROKE)
			TweenService:Create(bar, TweenInfo.new(0.25), { Size = stroke }):Play()
		end
	end
end

-- The middle of the first `count` lines' writing, in the world. (The page's sheet carries its SurfaceGui on
-- Front: the gui's left edge is the sheet's +X side, its top the sheet's +Y, the page's head.)
local function writing(sheet: BasePart, rule: ManualBook.Rule, count: number): Vector3
	local across = rule.margin + 0.07 + 0.36 -- (a name's middle, from the page's left edge)
	local down = rule.first + (math.max(1, count) - 1) * rule.pitch / 2 - rule.pitch * 0.4
	return sheet.CFrame:PointToWorldSpace(Vector3.new(rule.size.X / 2 - across, rule.size.Y / 2 - down, 0))
end

-- Plays the shot on the camera token's behalf: the open book, then `lines` written in over
-- `seconds`, in `style` (a writing style, or nil for plain ink). Returns a function that takes the set away
-- (call it when the shot is over).
function BookStage.play(token: number, lines: { Line }, seconds: number, style: string?): () -> ()
	local stage = Stage.new()
	local book = Models.grimoire()
	ManualBook.pose(book, 1, 1)
	book:PivotTo(CFrame.new(SET + Vector3.new(0, 0.22, 0)))
	stage:add(book)
	local sheet = ManualBook.page(book)
	local rule = ManualBook.rule(book)
	local page = if sheet then sheet.Position else SET + Vector3.new(0, 0.4, 0)
	buildSet(stage, page)
	-- The open book first, looking down from its foot; then in close on the lines as they are written
	-- (a name is a hand's size on its ruled line: from where the whole book shows, it cannot be read).
	local into = if sheet and rule then writing(sheet, rule, math.min(#lines, rule.count)) else page
	local up = if sheet then sheet.CFrame.LookVector else Vector3.yAxis
	local head = if sheet then sheet.CFrame.UpVector else Vector3.zAxis
	local side = if sheet then sheet.CFrame.RightVector else Vector3.xAxis
	local function eye(at: Vector3, distance: number): CFrame
		return CFrame.lookAt(at + (up * 0.9 - head * 0.42 + side * 0.06).Unit * distance, at, head)
	end
	CameraDirector.cut(token, eye(page:Lerp(into, 0.4), 2.9), 40)
	CameraDirector.move(token, eye(into, 1.55), seconds + 0.3, 36)
	if sheet and rule then
		local gui = Create("SurfaceGui", {
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = PIXELS,
			LightInfluence = 1,
			Parent = sheet,
		})
		task.spawn(write, gui, rule, lines, math.max(0.3, seconds - 0.3), style)
	end
	return function()
		stage:destroy()
	end
end

return BookStage
