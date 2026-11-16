-- How the shop's styles look when they play (the items: Shared/Cosmetics). One place for each, used by
-- the cutscenes, the world and the shop's Your look and cards alike (redone 2026-10-25 for the owner's "more high
-- quality ... completely redo"):
--
--   writing  how Diavolo's names go into the Manual (BookStage writes each line through write()), the effects the
--            VFX kit's textures drawn on the page at the writing's front: quill (a live ember at the nib, the
--            strokes smouldering behind it, smoke and sparks lifting off them), typewriter (struck letter by
--            letter, the line jolting, a breath of dust at each strike), fire (a flame running along the line
--            burning the letters in white-hot, cooling to char with a glowing rim), knife (a blade's glint ahead
--            of the cut, a pale edge under the groove, splinters of paper), chalk (dust shaken off as it goes and
--            falling under the grainy letters), frost (a cold breath where the letters form, crystals blooming
--            along them). Plain without one. Styles.page and Styles.writeStill: the page, and a finished name on it.
--   death    what becomes of a body after it falls, played with its acting (Presentation/Fallen, 2026-11-07): ash
--            (greys from the head down on its last try, crumbles into a drift of ash), strings (strings from a
--            control bar haul it up, follow its limbs through a puppet's dance and snap), crows (feathers shed as it
--            lifts; it bursts into crows), stone (stone climbs it as it reaches, it sets, it crumbles), glass (it turns
--            to glass as it is drawn up, glints, shatters).
--   form     what a Deathsinger wears (World/GhostVisibility): embers (a smouldering heart, the shoulders
--            burning low, embers trailing off the hands, a flickering warm light), veil (a veiled hood and thin
--            veils streaming back from it as it moves), chains (chains hanging and crossed over the body, a red
--            glow beating in the chest, a red haze at the feet), crows (a moulting feather cloak, a crow on each
--            shoulder, a dark mist at its hem), marionette (the control bar and strings, wooden pegs at its
--            joints, the leg strings cut), moths (a cold light in the chest, pale moths and motes of light about it).
--
-- Everything here is built from parts, so it also plays inside a 3D view (the shop), where particles
-- and beams do not draw; in the world, particles are added on top. The props come from the Core models
-- (Quill, Knife, Chain, CrowCloak, MarionetteBar,
-- and Tokyo's Crow), with plain parts standing in until they are imported.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Vfx = require(script.Parent.Vfx)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

local Styles = {}

-- Writing -------------------------------------------------------------------------------------------------

local PLAIN = Color3.fromRGB(26, 17, 11)
local SOOT = Color3.fromRGB(22, 16, 14)
local SMOULDER = Color3.fromRGB(255, 120, 40)
local CHALK = Color3.fromRGB(236, 232, 222)
local FROST = Color3.fromRGB(150, 200, 235)
local EMBER = Color3.fromRGB(255, 168, 80)
local CHAR = Color3.fromRGB(34, 20, 12)
local CUT = Color3.fromRGB(46, 34, 26)
local CUT_EDGE = Color3.fromRGB(176, 150, 118)

-- The colour and the hand a style writes in.
function Styles.pen(style: string?): (Color3, Font)
	if style == "quill" then
		return SOOT, WorldFont.hand()
	elseif style == "chalk" then
		return CHALK, WorldFont.hand()
	elseif style == "frost" then
		return Color3.fromRGB(245, 250, 255), WorldFont.hand()
	elseif style == "typewriter" then
		return Color3.fromRGB(20, 18, 18), Font.fromEnum(Enum.Font.SpecialElite)
	elseif style == "fire" then
		return EMBER, WorldFont.hand()
	elseif style == "knife" then
		return CUT, WorldFont.hand()
	end
	return PLAIN, WorldFont.hand()
end

-- The writing's effects are the VFX kit's textures drawn on the page beside the line (2026-10-25, the owner: "redo
-- what the writing styles look like ... more high quality"): smoke and embers, a flame, chalk dust, frost, a blade's
-- glint, each an image on the page that grows, drifts, turns and fades; a flipbook (the flame, the smoke) steps
-- through its cells while it lives.
type Mark = {
	tex: string,
	color: Color3,
	size: { number }, -- from, to (px)
	alpha: { number }?, -- from, to
	life: number,
	drift: Vector2?, -- px over its life
	rot: { number }?,
	grid: number?, -- a flipbook's cells across
	sheet: number?,
	fps: number?,
	squash: number?, -- width over height
	z: number?,
}

-- One mark on the page at `at` (px in the line's parent, the page), living out `spec`; taken away after.
local function mark(page: Instance, at: Vector2, spec: Mark, base: number?): ImageLabel
	local alpha = spec.alpha or { 0, 1 }
	local rot = spec.rot or { 0, 0 }
	local squash = spec.squash or 1
	local image = Create("ImageLabel", {
		Name = "Mark",
		BackgroundTransparency = 1,
		Image = Vfx.Tex.id(spec.tex),
		ImageColor3 = spec.color,
		ImageTransparency = alpha[1],
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(spec.size[1] * squash, spec.size[1]),
		Rotation = rot[1],
		ZIndex = (base or 1) + (spec.z or 1),
		Parent = page,
	}) :: ImageLabel
	local grid = if spec.grid and Vfx.Tex.real(spec.tex) then spec.grid else 1
	local cell = (spec.sheet or 1024) / grid
	if grid > 1 then
		image.ImageRectSize = Vector2.new(cell, cell)
		local start = os.clock()
		local stepper: RBXScriptConnection
		stepper = RunService.RenderStepped:Connect(function()
			if not image.Parent then
				stepper:Disconnect()
				return
			end
			local frame = math.floor((os.clock() - start) * (spec.fps or 30)) % (grid * grid)
			image.ImageRectOffset = Vector2.new((frame % grid) * cell, math.floor(frame / grid) * cell)
		end)
	end
	local move = spec.drift or Vector2.zero
	local info = TweenInfo.new(spec.life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(image, info, {
		Position = UDim2.fromOffset(at.X + move.X, at.Y + move.Y),
		Size = UDim2.fromOffset(spec.size[2] * squash, spec.size[2]),
		ImageTransparency = alpha[2],
		Rotation = rot[2],
	}):Play()
	Debris:AddItem(image, spec.life + 0.05)
	return image
end

-- Where the writing is: the front of a line as it is written (px in the page), a little under its middle.
local function front(clip: Frame): Vector2
	return Vector2.new(clip.Position.X.Offset + clip.Size.X.Offset, clip.Position.Y.Offset + clip.Size.Y.Offset * 0.62)
end

-- A random spot along the written part of the line (px in the page).
local function along(clip: Frame, rng: Random, shown: number): Vector2
	return Vector2.new(
		clip.Position.X.Offset + rng:NextNumber(4, math.max(5, shown - 4)),
		clip.Position.Y.Offset + clip.Size.Y.Offset * rng:NextNumber(0.35, 0.85)
	)
end

-- While the line is written (over `time`), `each` is called at the writing's front every `every` seconds.
local function atFront(clip: Frame, time: number, every: number, each: (Vector2, number) -> ())
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < time and clip.Parent do
			each(front(clip), (os.clock() - start) / time)
			task.wait(every)
		end
	end)
end

-- Writes one line: `clip` is the line's clipping frame (empty), `label` its text inside, `shown` how wide
-- the writing is (px), `pace` seconds per letter. Yields until the line is written.
function Styles.write(clip: Frame, label: TextLabel, shown: number, pace: number, style: string?)
	local height = clip.Size.Y.Offset
	local page = clip.Parent :: Instance
	local z = clip.ZIndex
	local letters = math.max(4, utf8.len(label.Text) or #label.Text)
	local rng = Random.new(#label.Text + letters)
	local quiet = Motion.isReduced() or Motion.isLow()
	if style == "typewriter" then
		-- Struck one letter at a time, the line already there: each strike jolts the line and leaves a breath of
		-- dust at the letter; the carriage bell at the end.
		clip.Size = UDim2.fromOffset(shown, height)
		label.MaxVisibleGraphemes = 0
		local rest = label.Position
		for count = 1, letters do
			label.MaxVisibleGraphemes = count
			if count % 2 == 1 then
				Sfx.play("typewriter", { volume = 0.5, pitch = 0.95 + math.random() * 0.1 })
			end
			if not quiet then
				label.Position = rest + UDim2.fromOffset(0, rng:NextInteger(-1, 1))
				local x = clip.Position.X.Offset + shown * count / letters - 2
				mark(page, Vector2.new(x, clip.Position.Y.Offset + height * 0.55), {
					tex = "VfxDust",
					color = Color3.fromRGB(70, 64, 58),
					size = { height * 0.25, height * 0.55 },
					alpha = { 0.65, 1 },
					life = 0.35,
					drift = Vector2.new(0, -height * 0.15),
				}, z)
			end
			task.wait(pace * 0.9)
		end
		label.Position = rest
		label.MaxVisibleGraphemes = -1
		return
	end
	local time = pace * letters * (if style == "knife" then 0.7 else 1)
	if style == "knife" then
		-- Cut into the page: a pale edge under the dark groove, a blade's glint running ahead of the cut, splinters
		-- of paper lifting off it.
		local edge = label:Clone()
		edge.Name = "CutEdge"
		edge.TextColor3 = CUT_EDGE
		edge.TextTransparency = 0.25
		edge.Position = UDim2.fromOffset(0, math.max(1, math.floor(height * 0.03)))
		edge.ZIndex = label.ZIndex - 1
		edge.Parent = clip
		Sfx.play("knifeScrape", { volume = 0.6 })
		if not quiet then
			atFront(clip, time, 0.05, function(at)
				mark(page, at, {
					tex = "VfxStreak",
					color = Color3.fromRGB(255, 252, 244),
					size = { height * 1.1, height * 0.6 },
					squash = 0.08,
					alpha = { 0.1, 1 },
					life = 0.12,
					rot = { 62, 62 },
					z = 2,
				}, z)
				if rng:NextNumber() < 0.5 then
					mark(page, at, {
						tex = "VfxChunk",
						color = Color3.fromRGB(226, 216, 196),
						size = { height * 0.14, height * 0.05 },
						alpha = { 0, 1 },
						life = 0.5,
						drift = Vector2.new(rng:NextNumber(-6, 6), -height * rng:NextNumber(0.3, 0.7)),
						rot = { 0, rng:NextNumber(-200, 200) },
					}, z)
				end
			end)
		end
	elseif style == "fire" and not quiet then
		-- A flame runs along the line burning the letters in, embers flying off it.
		atFront(clip, time, 0.04, function(at)
			mark(page, at - Vector2.new(0, height * 0.25), {
				tex = "VfxFlame",
				grid = 8,
				fps = 40,
				color = Color3.fromRGB(255, 190, 110),
				size = { height * 0.9, height * 0.5 },
				alpha = { 0.05, 1 },
				life = 0.22,
				drift = Vector2.new(0, -height * 0.35),
				z = 2,
			}, z)
			if rng:NextNumber() < 0.6 then
				mark(page, at, {
					tex = "VfxEmber",
					color = Color3.fromRGB(255, 170, 70),
					size = { height * 0.1, 0 },
					life = rng:NextNumber(0.5, 0.9),
					drift = Vector2.new(rng:NextNumber(-8, 8), -height * rng:NextNumber(0.6, 1.3)),
					z = 2,
				}, z)
			end
		end)
	elseif style == "quill" and not quiet then
		-- A live ember at the nib, the fresh strokes already smouldering behind it.
		atFront(clip, time, 0.06, function(at)
			mark(page, at, {
				tex = "VfxGlow",
				color = SMOULDER,
				size = { height * 0.5, height * 0.3 },
				alpha = { 0.35, 1 },
				life = 0.2,
				z = 2,
			}, z)
		end)
	elseif style == "chalk" and not quiet then
		-- Dust shaken off the chalk as it goes.
		atFront(clip, time, 0.07, function(at)
			mark(page, at, {
				tex = "VfxDust",
				color = CHALK,
				size = { height * 0.3, height * 0.6 },
				alpha = { 0.55, 1 },
				life = 0.6,
				drift = Vector2.new(rng:NextNumber(-3, 3), height * 0.5),
				rot = { 0, 30 },
			}, z)
		end)
	elseif style == "frost" and not quiet then
		-- A cold breath where the letters form.
		atFront(clip, time, 0.06, function(at)
			mark(page, at, {
				tex = "VfxGlow",
				color = Color3.fromRGB(210, 236, 255),
				size = { height * 0.7, height * 1.1 },
				alpha = { 0.55, 1 },
				life = 0.4,
				z = 2,
			}, z)
		end)
	end
	if style == "fire" then
		-- (the letters come in white-hot)
		label.TextColor3 = Color3.fromRGB(255, 236, 170)
		label.TextStrokeColor3 = Color3.fromRGB(255, 120, 40)
		label.TextStrokeTransparency = 0.2
	end
	TweenService:Create(
		clip,
		TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Size = UDim2.fromOffset(shown, height) }
	):Play()
	task.wait(time)
	if style == "quill" then
		-- The strokes smoulder at their edges as they dry: a hot rim cooling to soot, thin smoke and a few sparks
		-- lifting off them.
		label.TextStrokeColor3 = SMOULDER
		label.TextStrokeTransparency = 0.25
		TweenService:Create(label, TweenInfo.new(2.6, Enum.EasingStyle.Quad), { TextStrokeTransparency = 1 }):Play()
		if not quiet then
			for k = 1, 5 do
				local at = along(clip, rng, shown)
				task.delay(k * 0.12, function()
					mark(page, at, {
						tex = "VfxSmoke",
						grid = 8,
						fps = 24,
						color = Color3.fromRGB(110, 104, 100),
						size = { height * 0.4, height * 1.3 },
						alpha = { 0.55, 1 },
						life = 1.6,
						drift = Vector2.new(rng:NextNumber(-6, 6), -height * rng:NextNumber(0.9, 1.5)),
						rot = { 0, rng:NextNumber(-40, 40) },
					}, z)
					mark(page, at, {
						tex = "VfxEmber",
						color = SMOULDER,
						size = { height * 0.08, 0 },
						life = 0.8,
						drift = Vector2.new(rng:NextNumber(-5, 5), -height * rng:NextNumber(0.5, 1)),
						z = 2,
					}, z)
				end)
			end
		end
	elseif style == "chalk" then
		-- Rough chalk: the letters' grain (a fainter copy a hair off them), and dust falling off the page under them.
		label.TextStrokeColor3 = Color3.fromRGB(70, 58, 44)
		label.TextStrokeTransparency = 0.75
		local grain = label:Clone()
		grain.Name = "ChalkGrain"
		grain.TextTransparency = 0.6
		grain.TextStrokeTransparency = 1
		grain.Position = label.Position + UDim2.fromOffset(1, -1)
		grain.Parent = clip
		if not quiet then
			for _ = 1, 8 do
				mark(page, along(clip, rng, shown), {
					tex = "VfxDust",
					color = CHALK,
					size = { height * 0.15, height * 0.35 },
					alpha = { 0.45, 1 },
					life = rng:NextNumber(1, 1.5),
					drift = Vector2.new(rng:NextNumber(-3, 3), height * rng:NextNumber(0.6, 1.3)),
				}, z)
			end
		end
	elseif style == "frost" then
		-- The letters frost over (white cooling to ice blue) and crystals bloom along them and spread.
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.5
		TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { TextColor3 = FROST }):Play()
		if not quiet then
			for k = 1, 9 do
				local at = along(clip, rng, shown)
				task.delay(k * 0.07, function()
					mark(page, at, {
						tex = "VfxFlare",
						color = Color3.fromRGB(236, 248, 255),
						size = { 0, height * rng:NextNumber(0.35, 0.6) },
						alpha = { 0, 0.35 },
						life = 1.6,
						rot = { 0, rng:NextNumber(20, 60) },
						z = 2,
					}, z)
				end)
			end
		end
	elseif style == "fire" then
		-- Burnt in: the bright letters cool to char with a glowing rim that dies slowly, and a last breath of smoke.
		TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { TextColor3 = CHAR }):Play()
		TweenService:Create(label, TweenInfo.new(3, Enum.EasingStyle.Quad), { TextStrokeTransparency = 0.7 }):Play()
		if not quiet then
			for _ = 1, 4 do
				mark(page, along(clip, rng, shown), {
					tex = "VfxSmoke",
					grid = 8,
					fps = 24,
					color = Color3.fromRGB(70, 60, 54),
					size = { height * 0.5, height * 1.4 },
					alpha = { 0.6, 1 },
					life = 1.4,
					drift = Vector2.new(rng:NextNumber(-6, 6), -height * 1.2),
				}, z)
			end
		end
	end
end

-- A page for a name to be written on (the shop's Your look, a card's picture): cream paper in a soft shadow, its faint
-- blue rules and red margin, turned a little; for chalk, a slate board in a wooden frame instead. Returns the page
-- (sized and placed by the caller).
function Styles.page(parent: Instance, style: string?): Frame
	local chalk = style == "chalk"
	local shadow = Create("Frame", {
		Name = "PageShadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = parent,
	}) :: Frame
	Create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = shadow })
	local page = Create("Frame", {
		Name = "Page",
		BackgroundColor3 = if chalk then Color3.fromRGB(42, 50, 46) else Color3.fromRGB(236, 230, 214),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-3, -3),
		Size = UDim2.fromScale(1, 1),
		Parent = shadow,
	}) :: Frame
	Create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = page })
	Create("UIGradient", {
		Rotation = 90,
		Color = if chalk
			then ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 196, 192))
			else ColorSequence.new(Color3.fromRGB(255, 252, 244), Color3.fromRGB(214, 204, 184)),
		Parent = page,
	})
	if chalk then
		Create("UIStroke", { Color = Color3.fromRGB(96, 66, 42), Thickness = 3, Parent = page })
	else
		for k = 1, 3 do
			Create("Frame", {
				Name = "Rule",
				BackgroundColor3 = Color3.fromRGB(140, 160, 196),
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 0.27 * k, 0),
				Size = UDim2.new(1, 0, 0, 1),
				Parent = page,
			})
		end
		Create("Frame", {
			Name = "Margin",
			BackgroundColor3 = Color3.fromRGB(196, 92, 92),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			Parent = page,
		})
	end
	return shadow
end

-- A name written in a style, finished, on its page (a card's picture): the letters as they are once the style has
-- done its work, with its marks still on the page round them (smoke off the quill's strokes, the fire's glowing rim
-- and embers, the knife's pale cut edge, chalk's grain and dust, frost's crystals).
function Styles.writeStill(parent: GuiObject, style: string, text: string)
	local holder = Styles.page(parent, style)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.new(0.9, 0, 0.5, 0)
	holder.Rotation = -3
	local page = holder:FindFirstChild("Page") :: Frame
	local colour, font = Styles.pen(style)
	local finished = {
		quill = colour,
		fire = CHAR,
		frost = FROST,
	}
	local label = Create("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.54, 0.56),
		Size = UDim2.fromScale(0.84, 0.8),
		Text = text,
		FontFace = font,
		TextScaled = true,
		TextColor3 = finished[style] or colour,
		TextStrokeColor3 = if style == "fire"
			then Color3.fromRGB(255, 120, 40)
			elseif style == "quill" then SMOULDER
			elseif style == "frost" then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(70, 58, 44),
		TextStrokeTransparency = if style == "fire"
			then 0.35
			elseif style == "quill" then 0.55
			elseif style == "frost" then 0.5
			elseif style == "chalk" then 0.75
			else 1,
		ZIndex = page.ZIndex + 2,
		Parent = page,
	}) :: TextLabel
	label:SetAttribute("KeepFont", true)
	Create("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 10, Parent = label })
	if style == "knife" or style == "chalk" then
		local copy = label:Clone()
		copy.Name = if style == "knife" then "CutEdge" else "ChalkGrain"
		copy.TextColor3 = if style == "knife" then CUT_EDGE else CHALK
		copy.TextTransparency = if style == "knife" then 0.25 else 0.6
		copy.TextStrokeTransparency = 1
		copy.Position = label.Position
			+ UDim2.fromOffset(if style == "knife" then 0 else 1, if style == "knife" then 2 else -1)
		copy.ZIndex = label.ZIndex - 1
		copy.Parent = page
	end
	-- (its marks, held still: a mark's look at one point of its life)
	local function still(
		tex: string,
		x: number,
		y: number,
		size: number,
		color: Color3,
		alpha: number,
		extra: { [string]: any }?
	)
		local image = Create("ImageLabel", {
			Name = "Mark",
			BackgroundTransparency = 1,
			Image = Vfx.Tex.id(tex),
			ImageColor3 = color,
			ImageTransparency = alpha,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(size * 0.5, size),
			ZIndex = page.ZIndex + 3,
			Parent = page,
		}) :: ImageLabel
		Create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = image })
		for key, value in pairs(extra or {}) do
			(image :: any)[key] = value
		end
		return image
	end
	local rng = Random.new(#style)
	if style == "quill" then
		for k = 1, 3 do
			local smoke = still("VfxSmoke", 0.25 + k * 0.17, 0.2, 0.7, Color3.fromRGB(120, 114, 110), 0.55)
			if Vfx.Tex.real("VfxSmoke") then
				smoke.ImageRectSize = Vector2.new(128, 128)
				smoke.ImageRectOffset = Vector2.new(128 * (k * 3 % 8), 128 * k)
			end
			still("VfxEmber", 0.2 + k * 0.2, 0.3 + rng:NextNumber(-0.1, 0.1), 0.12, SMOULDER, 0.1)
		end
	elseif style == "fire" then
		still("VfxGlow", 0.5, 0.56, 1.6, Color3.fromRGB(255, 130, 50), 0.75, { Size = UDim2.fromScale(1.1, 1.3) })
		for k = 1, 5 do
			still("VfxEmber", 0.15 + k * 0.15, 0.15 + rng:NextNumber(0, 0.25), 0.1, Color3.fromRGB(255, 170, 70), 0.05)
		end
	elseif style == "knife" then
		still("VfxStreak", 0.86, 0.45, 1.2, Color3.fromRGB(255, 252, 244), 0.2, { Rotation = 62 })
	elseif style == "chalk" then
		for k = 1, 4 do
			still("VfxDust", 0.2 + k * 0.17, 0.92, 0.35, CHALK, 0.6)
		end
	elseif style == "frost" then
		for k = 1, 6 do
			still(
				"VfxFlare",
				0.12 + k * 0.14,
				0.35 + rng:NextNumber(0, 0.45),
				0.3,
				Color3.fromRGB(236, 248, 255),
				0.25,
				{
					Rotation = rng:NextNumber(0, 60),
				}
			)
		end
	elseif style == "typewriter" then
		-- (the line's end: the carriage's cursor waiting)
		Create("Frame", {
			Name = "Cursor",
			BackgroundColor3 = Color3.fromRGB(20, 18, 18),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.93, 0.62),
			Size = UDim2.new(0, 2, 0.42, 0),
			ZIndex = page.ZIndex + 3,
			Parent = page,
		})
	end
end

-- Helpers for the forms ---------------------------------------------------------------------------------------

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return Create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- A prop from the imports placed at `cf`, or nil.
local function prop(key: string, cf: CFrame, parent: Instance, height: number?, longest: boolean?): Model?
	local model = ModelLibrary.get(key)
	if not model then
		return nil
	end
	if height then
		-- (scaled to `height` tall, or with `longest` to that length along its longest side: a prop that lies flat,
		-- like the cuffs, is only a sliver tall and would come out huge)
		local _, size = model:GetBoundingBox()
		local along = if longest then math.max(size.X, size.Y, size.Z) else size.Y
		if along > 0 then
			model:ScaleTo(model:GetScale() * height / along)
		end
	end
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

-- Deathsinger forms -----------------------------------------------------------------------------------------

local FORM = "LGhostForm"
local FEATHER = Color3.fromRGB(18, 18, 22)

local function weldTo(piece: BasePart, to: BasePart)
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	Create("WeldConstraint", { Part0 = to, Part1 = piece, Parent = piece })
end

local function attachModel(model: Model, to: BasePart, offset: CFrame, folder: Instance)
	model:PivotTo(to.CFrame * offset)
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			weldTo(piece, to)
		end
	end
	model.Parent = folder
end

-- A light that flickers like a fire's (or breathes, `slow`) for as long as `folder` is worn.
local function flicker(folder: Instance, light: PointLight, base: number, slow: boolean?)
	if Motion.isLow() or folder:FindFirstAncestorWhichIsA("ViewportFrame") then
		return
	end
	task.spawn(function()
		local t = math.random() * 10
		while folder.Parent and light.Parent do
			t += 0.05
			light.Brightness = if slow
				then base * (0.75 + 0.25 * math.sin(t * 2.2))
				else base * (0.7 + 0.3 * math.noise(t * 3, 0.5))
			task.wait(0.05)
		end
	end)
end

-- Veils trailing from points on a body (`starts`: attachments on it): each a soft beam out to a free end that
-- follows behind and below the body with a lag, so they stream back as it moves and settle as it stops.
local function trailingVeils(folder: Instance, character: Model, starts: { Attachment }, color: Color3)
	if character:FindFirstAncestorWhichIsA("ViewportFrame") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	if not root or not root:IsA("BasePart") then
		return
	end
	local tails = {}
	for k, start in ipairs(starts) do
		local tail = part(folder, Vector3.new(0.1, 0.1, 0.1), start.WorldCFrame, color)
		tail.Transparency = 1
		local endAt = Create("Attachment", { Parent = tail }) :: Attachment
		Create("Beam", {
			Attachment0 = start,
			Attachment1 = endAt,
			Texture = Vfx.Tex.id("VfxWisp"),
			TextureMode = Enum.TextureMode.Stretch,
			TextureSpeed = 0.15,
			Width0 = 1.5 - k * 0.2,
			Width1 = 0.5,
			Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(30, 30, 36), 0.5)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(0.7, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			}),
			LightEmission = 0.25,
			LightInfluence = 0.3,
			FaceCamera = true,
			Segments = 12,
			CurveSize0 = -0.8,
			CurveSize1 = 0.5,
			Parent = folder,
		})
		table.insert(tails, { tail = tail, start = start, length = 3.2 + k * 0.6, drop = 1.6 + k * 0.4 })
	end
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if not folder.Parent then
			connection:Disconnect()
			return
		end
		local back = -(root :: BasePart).CFrame.LookVector
		for k, entry in ipairs(tails) do
			local goal = entry.start.WorldPosition + back * entry.length - Vector3.new(0, entry.drop, 0)
			local sway = math.sin(os.clock() * 1.3 + k) * 0.35
			goal += (root :: BasePart).CFrame.RightVector * sway
			local now = entry.tail.Position
			entry.tail.Position = now:Lerp(goal, 1 - math.exp(-dt * (2.2 - k * 0.3)))
		end
	end)
end

-- Dresses a Deathsinger's body in its form (`color`: the form's own). Returns the folder of what it wears
-- (destroy it to take the form off), or nil for no form.
function Styles.form(character: Model, form: string?, color: Color3?): Folder?
	local old = character:FindFirstChild(FORM)
	if old then
		old:Destroy()
	end
	if not form then
		return nil
	end
	local torso = character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	if not torso or not torso:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nil
	end
	local folder = Create("Folder", { Name = FORM, Parent = character }) :: Folder
	local tint = color or Color3.fromRGB(210, 225, 255)
	if form == "embers" then
		-- (on a small carrier welded to the torso, so it goes with the folder)
		local carrier = part(folder, Vector3.new(0.2, 0.2, 0.2), torso.CFrame, tint)
		carrier.Transparency = 1
		weldTo(carrier, torso)
		-- (a warm heart glowing in the chest, embers rising off it, now and then a breath of smoke)
		local at = Create("Attachment", { Parent = carrier }) :: Attachment
		Vfx.Emit
			.make(at, {
				tex = "VfxGlow",
				color = tint,
				size = 2.4,
				alpha = { { 0, 1 }, { 0.05, 0.3 }, { 0.95, 0.3 }, { 1, 1 } },
				life = 4,
				rate = 1 / 3.8,
				locked = true,
				light = 0.7,
				bright = 1.1,
				z = 1.6, -- (drawn forward of the body, which would hide it inside it)
			})
			:Emit(1)
		Vfx.Emit.make(at, {
			tex = "VfxEmber",
			color = { { 0, Color3.fromRGB(255, 236, 190) }, { 0.3, tint }, { 1, tint:Lerp(Color3.new(0, 0, 0), 0.6) } },
			size = { { 0, 0.22 }, { 0.5, 0.16 }, { 1, 0 } },
			life = { 0.9, 1.7 },
			speed = { 1, 3 },
			spread = 35,
			accel = Vector3.new(0, 4, 0),
			drag = 0.8,
			bright = 1.4,
			rate = 22,
			shape = Enum.ParticleEmitterShape.Sphere,
			z = 1.2,
		})
		Vfx.Emit.make(at, {
			tex = "VfxWisp",
			grid = 4,
			mode = "OneShot",
			color = tint:Lerp(Color3.fromRGB(60, 56, 58), 0.6),
			light = 0,
			lit = 0.4,
			size = { { 0, 1 }, { 1, 2.4 } },
			alpha = { { 0, 0.5 }, { 0.6, 0.65 }, { 1, 1 } },
			life = { 1.2, 1.8 },
			speed = { 1.5, 3 },
			spread = 15,
			face = "up",
			rate = 2,
		})
		-- (the shoulders smouldering, embers trailing off the hands as they move, a warm light flickering on it)
		for _, side in ipairs({ -1, 1 }) do
			local shoulder =
				Create("Attachment", { Position = Vector3.new(side * 0.9, 0.9, 0), Parent = carrier }) :: Attachment
			Vfx.Emit.make(shoulder, {
				tex = "VfxFlame",
				grid = 8,
				fps = 36,
				startRandom = true,
				color = {
					{ 0, Color3.fromRGB(255, 220, 160) },
					{ 0.5, tint },
					{ 1, tint:Lerp(Color3.new(0, 0, 0), 0.7) },
				},
				size = { { 0, 0.7 }, { 0.6, 0.45 }, { 1, 0.1 } },
				alpha = { { 0, 0.3 }, { 0.7, 0.5 }, { 1, 1 } },
				life = { 0.3, 0.5 },
				speed = { 0.6, 1.4 },
				accel = Vector3.new(0, 3, 0),
				face = "up",
				light = 0.8,
				bright = 1.2,
				rate = 9,
				z = 0.6,
			})
		end
		for _, name in ipairs({ "Left Arm", "Right Arm" }) do
			local arm = character:FindFirstChild(name)
			if arm and arm:IsA("BasePart") then
				local hand = Create("Attachment", { Position = Vector3.new(0, -1, 0), Parent = arm }) :: Attachment
				hand:SetAttribute("DGForm", true)
				Vfx.Emit.make(hand, {
					tex = "VfxEmber",
					color = { { 0, Color3.fromRGB(255, 220, 160) }, { 1, tint } },
					size = { { 0, 0.14 }, { 1, 0 } },
					life = { 0.5, 0.9 },
					speed = { 0.2, 0.6 },
					spread = 60,
					accel = Vector3.new(0, 1.5, 0),
					bright = 1.4,
					rate = 7,
				})
				-- (taken off with the form: the hand's attachment lives on the arm, not in the folder)
				folder.Destroying:Once(function()
					hand:Destroy()
				end)
			end
		end
		local warm = Create(
			"PointLight",
			{ Color = tint, Range = 10, Brightness = 1, Shadows = false, Parent = carrier }
		) :: PointLight
		flicker(folder, warm, 1.1)
	elseif form == "veil" then
		local hood = prop("Hood", head.CFrame, folder, 1.6)
		if hood then
			for _, piece in ipairs(hood:GetDescendants()) do
				if piece:IsA("BasePart") then
					piece.Color = tint
					piece.Transparency = 0.35
				end
			end
			attachModel(hood, head, CFrame.new(0, 0.2, 0.05), folder)
		else
			local veil = part(
				folder,
				Vector3.new(1.6, 2.2, 1.4),
				head.CFrame * CFrame.new(0, -0.1, 0.1),
				tint,
				Enum.Material.Fabric
			)
			veil.Transparency = 0.45
			weldTo(veil, head)
		end
		-- (and the veils themselves: thin layers streaming back from the head and the shoulders)
		local starts = {}
		for _, spot in ipairs({ Vector3.new(0, 0.3, 0.45), Vector3.new(-0.8, 0.9, 0.4), Vector3.new(0.8, 0.9, 0.4) }) do
			local on = if spot.Y > 0.5 then torso else head
			local anchor = part(folder, Vector3.new(0.1, 0.1, 0.1), on.CFrame * CFrame.new(spot), tint)
			anchor.Transparency = 1
			weldTo(anchor, on)
			table.insert(starts, Create("Attachment", { Parent = anchor }) :: Attachment)
		end
		trailingVeils(folder, character, starts, tint)
	elseif form == "chains" then
		for _, name in ipairs({ "Left Arm", "Right Arm" }) do
			local arm = character:FindFirstChild(name)
			if arm and arm:IsA("BasePart") then
				local chain = prop("Chain", arm.CFrame * CFrame.new(0, -2.6, 0), folder, 3)
				if chain then
					for _, piece in ipairs(chain:GetDescendants()) do
						if piece:IsA("BasePart") then
							piece.Color = tint
						end
					end
					attachModel(chain, arm, CFrame.new(0, -2.6, 0), folder)
				else
					local links = part(
						folder,
						Vector3.new(0.25, 3, 0.25),
						arm.CFrame * CFrame.new(0, -2.6, 0),
						tint,
						Enum.Material.Metal
					)
					weldTo(links, arm)
				end
			end
		end
		-- (a red glow low in the chest that beats, a red haze about the feet, and chains crossed over the body)
		local heart = part(folder, Vector3.new(0.2, 0.2, 0.2), torso.CFrame * CFrame.new(0, 0.1, -0.2), tint)
		heart.Transparency = 1
		weldTo(heart, torso)
		Vfx.Emit
			.make(heart, {
				tex = "VfxGlow",
				color = tint,
				size = 2.2,
				alpha = { { 0, 1 }, { 0.05, 0.35 }, { 0.95, 0.35 }, { 1, 1 } },
				life = 4,
				rate = 1 / 3.8,
				locked = true,
				light = 0.8,
				bright = 1.2,
				z = 1.4,
			})
			:Emit(1)
		local beat = Create(
			"PointLight",
			{ Color = tint, Range = 9, Brightness = 1.2, Shadows = false, Parent = heart }
		) :: PointLight
		flicker(folder, beat, 1.3, true)
		local feet = part(folder, Vector3.new(2, 0.2, 1.4), torso.CFrame * CFrame.new(0, -3, 0), tint)
		feet.Transparency = 1
		weldTo(feet, torso)
		Vfx.Emit.make(feet, {
			tex = "VfxSmoke",
			grid = 8,
			color = tint:Lerp(Color3.new(0, 0, 0), 0.65),
			light = 0.1,
			lit = 0.2,
			size = { { 0, 1.2 }, { 1, 2.6 } },
			alpha = { { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } },
			life = { 1.6, 2.4 },
			speed = { 0.2, 0.5 },
			spread = 80,
			rot = { 0, 360 },
			spin = { -20, 20 },
			rate = 3,
			shape = Enum.ParticleEmitterShape.Box,
		})
		for _, turn in ipairs({ 35, -35 }) do
			local across = CFrame.new(0, 0, -0.55) * CFrame.Angles(0, 0, math.rad(turn))
			local wrap = prop("Chain", torso.CFrame * across, folder, 2.6)
			if wrap then
				for _, piece in ipairs(wrap:GetDescendants()) do
					if piece:IsA("BasePart") then
						piece.Color = tint:Lerp(Color3.fromRGB(60, 60, 64), 0.5)
					end
				end
				attachModel(wrap, torso, across, folder)
			end
		end
	elseif form == "crows" then
		local cloak = prop("CrowCloak", torso.CFrame, folder, 2.6)
		if cloak then
			attachModel(cloak, torso, CFrame.new(0, 0.2, 0.15), folder)
		else
			local mantle = part(
				folder,
				Vector3.new(2.6, 2.4, 1.6),
				torso.CFrame * CFrame.new(0, 0, 0.2),
				Color3.fromRGB(16, 16, 20),
				Enum.Material.Fabric
			)
			weldTo(mantle, torso)
		end
		-- (2026-10-22, the owner's "change it": a crow on each shoulder, and the cloak moulting as it goes)
		for side = -1, 1, 2 do
			local spot = CFrame.new(side * 1.05, 1.25, 0.1) * CFrame.Angles(0, math.rad(side * 70), 0)
			local bird = prop("Crow", torso.CFrame * spot, folder, 0.75)
			if bird then
				attachModel(bird, torso, spot, folder)
			else
				local body = part(folder, Vector3.new(0.35, 0.4, 0.7), torso.CFrame * spot, Color3.fromRGB(16, 16, 20))
				weldTo(body, torso)
			end
		end
		local carrier = part(folder, Vector3.new(1.6, 0.4, 1), torso.CFrame * CFrame.new(0, -0.6, 0.4), FEATHER)
		carrier.Transparency = 1
		weldTo(carrier, torso)
		Vfx.Emit.make(carrier, {
			tex = "VfxFeather",
			color = FEATHER,
			light = 0,
			lit = 0.8,
			size = { { 0, 0.32 }, { 1, 0.26 } },
			alpha = { { 0, 0.05 }, { 0.8, 0.2 }, { 1, 1 } },
			life = { 1.8, 2.8 },
			speed = { 0.2, 0.6 },
			spread = 60,
			accel = Vector3.new(0, -1.4, 0),
			drag = 1.5,
			rot = { 0, 360 },
			spin = { -90, 90 },
			rate = 3,
			shape = Enum.ParticleEmitterShape.Box,
		})
		-- (a low dark mist trailing at its hem)
		Vfx.Emit.make(carrier, {
			tex = "VfxSmoke",
			grid = 8,
			color = Color3.fromRGB(14, 14, 18),
			light = 0,
			lit = 0.3,
			size = { { 0, 1 }, { 1, 2.4 } },
			alpha = { { 0, 1 }, { 0.3, 0.7 }, { 1, 1 } },
			life = { 1.4, 2 },
			speed = { 0.2, 0.6 },
			spread = 70,
			accel = Vector3.new(0, -0.3, 0),
			rot = { 0, 360 },
			rate = 3,
			shape = Enum.ParticleEmitterShape.Box,
		})
	elseif form == "moths" then
		-- A cold light in the chest, and pale moths drifting about it.
		local light = part(
			folder,
			Vector3.new(0.55, 0.55, 0.55),
			torso.CFrame * CFrame.new(0, 0.2, -0.3),
			tint,
			Enum.Material.Neon
		)
		light.Shape = Enum.PartType.Ball
		light.Transparency = 0.25
		weldTo(light, torso)
		Create("PointLight", { Color = tint, Range = 8, Brightness = 1.2, Shadows = false, Parent = light })
		-- (the light's glow, and moths that flutter round it: a wingbeat flipbook, drifting and turning)
		Vfx.Emit
			.make(light, {
				tex = "VfxGlow",
				color = tint,
				size = 3.2,
				alpha = { { 0, 1 }, { 0.05, 0.3 }, { 0.95, 0.3 }, { 1, 1 } },
				life = 4,
				rate = 1 / 3.8,
				locked = true,
				light = 0.8,
				bright = 1.1,
				z = 1.2, -- (drawn forward of the chest it sits in)
			})
			:Emit(1)
		Vfx.Emit.make(light, {
			tex = "VfxMoth",
			grid = 2,
			fps = { 12, 18 },
			startRandom = true,
			blend = false,
			color = Color3.fromRGB(240, 234, 214),
			light = 0.5,
			lit = 0.3,
			bright = 1.2,
			size = { { 0, 0 }, { 0.12, 0.6 }, { 0.88, 0.6 }, { 1, 0 } },
			life = { 2.4, 3.6 },
			speed = { 1, 2 },
			spread = 180,
			accel = Vector3.new(0, 0.3, 0),
			drag = 0.6,
			rot = { -40, 40 },
			spin = { -60, 60 },
			rate = 6,
			shape = Enum.ParticleEmitterShape.Sphere,
			z = 0.6,
		})
		Vfx.Emit.make(light, {
			tex = "VfxEmber",
			color = tint:Lerp(Color3.new(1, 1, 1), 0.4),
			size = { { 0, 0.1 }, { 1, 0 } },
			life = { 1.2, 2 },
			speed = { 0.3, 0.8 },
			spread = 180,
			drag = 0.5,
			bright = 1.5,
			rate = 8,
			z = 0.8,
		})
		flicker(folder, light:FindFirstChildWhichIsA("PointLight") :: PointLight, 1.2, true)
	elseif form == "marionette" then
		-- A control bar over the head, its strings down to the head and the hands.
		local high = head.CFrame * CFrame.new(0, 5, 0)
		local bar = prop("MarionetteBar", high, folder, 0.5)
		local barPart: BasePart
		if bar then
			attachModel(bar, head, CFrame.new(0, 5, 0), folder)
			barPart = bar:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		else
			barPart =
				part(folder, Vector3.new(2.4, 0.15, 0.15), high, Color3.fromRGB(180, 150, 110), Enum.Material.Wood)
			weldTo(barPart, head)
		end
		for _, name in ipairs({ "Head", "Left Arm", "Right Arm" }) do
			local limb = character:FindFirstChild(name)
			if limb and limb:IsA("BasePart") and barPart then
				local top = Create("Attachment", { Parent = barPart }) :: Attachment
				top.WorldPosition = limb.Position + Vector3.new(0, 5 - (limb.Position.Y - head.Position.Y), 0)
				local low = Create("Attachment", {
					Position = if name == "Head" then Vector3.new(0, 0.5, 0) else Vector3.new(0, -1, 0),
					Parent = limb,
				}) :: Attachment
				Create("Beam", {
					Attachment0 = top,
					Attachment1 = low,
					Width0 = 0.04,
					Width1 = 0.04,
					FaceCamera = true,
					Color = ColorSequence.new(tint),
					Parent = folder,
				})
			end
		end
		-- (wooden pegs at its joints, as a marionette's, and the strings to its feet cut: short ends hanging from
		-- the bar)
		for _, spot in ipairs({
			Vector3.new(-1, 0.6, 0),
			Vector3.new(1, 0.6, 0),
			Vector3.new(-0.5, -1, 0),
			Vector3.new(0.5, -1, 0),
		}) do
			local peg = part(
				folder,
				Vector3.new(0.42, 0.42, 0.42),
				torso.CFrame * CFrame.new(spot),
				Color3.fromRGB(176, 150, 112),
				Enum.Material.Wood
			)
			peg.Shape = Enum.PartType.Ball
			weldTo(peg, torso)
		end
		if barPart then
			for _, side in ipairs({ -0.6, 0.6 }) do
				local hang = Create("Attachment", { Parent = barPart }) :: Attachment
				hang.WorldPosition = head.Position + Vector3.new(side, 5, 0)
				local loose = Create("Attachment", { Parent = barPart }) :: Attachment
				loose.WorldPosition = head.Position + Vector3.new(side * 1.2, 3.4, 0.2)
				Create("Beam", {
					Attachment0 = hang,
					Attachment1 = loose,
					Width0 = 0.04,
					Width1 = 0.03,
					FaceCamera = true,
					CurveSize0 = 0.3,
					Color = ColorSequence.new(tint),
					Parent = folder,
				})
			end
		end
	end
	return folder
end

return Styles
