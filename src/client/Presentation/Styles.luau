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
--   verdict  how Ace's arrest lands (Presenters/Arrest, the ending): a small scene over the shot, its impacts drawn
--            over the view (Presentation/ViewFx: flares, rings, dust, sparks, a shake): gavel (struck twice on its
--            block), cuffs (snapping shut on the case file with sparks and a glint), checkmate (the king topples
--            and cracks across), sugar (the top cube flicked off, the tower falling in a puff of sugar), stamp
--            (GUILTY slammed onto the file), lamp (a lamp on a cord swings in over an empty chair and the room goes
--            dark round a shaft of warm light, dust turning in it). Styles.verdictStill: one at its moment.
--   death    what becomes of a body after it falls (Presenters/Death, Your look): ash, strings (cut
--            from above), crows (a whirl of feathers that flies off as crows), stone (stone creeps up from
--            the feet, then it crumbles), glass (it cracks like glass and falls in shards).
--   form     what a Deathsinger wears (World/GhostVisibility): embers (a smouldering heart, the shoulders
--            burning low, embers trailing off the hands, a flickering warm light), veil (a veiled hood and thin
--            veils streaming back from it as it moves), chains (chains hanging and crossed over the body, a red
--            glow beating in the chest, a red haze at the feet), crows (a moulting feather cloak, a crow on each
--            shoulder, a dark mist at its hem), marionette (the control bar and strings, wooden pegs at its
--            joints, the leg strings cut), moths (a cold light in the chest, pale moths and motes of light about it).
--
-- Everything here is built from parts, so it also plays inside a 3D view (the shop), where particles
-- and beams do not draw; in the world, particles are added on top. The props come from the Core models
-- (Quill, Knife, Gavel, Handcuffs, ChessKing, SugarCube, Teacup, Chair, Chain, CrowCloak, MarionetteBar,
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
local FxKit = require(script.Parent.FxKit)
local Vfx = require(script.Parent.Vfx)
local ViewFx = require(script.Parent.ViewFx)
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

-- Verdicts --------------------------------------------------------------------------------------------------

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
local function prop(key: string, cf: CFrame, parent: Instance, height: number?): Model?
	local model = ModelLibrary.get(key)
	if not model then
		return nil
	end
	if height then
		local _, size = model:GetBoundingBox()
		if size.Y > 0 then
			model:ScaleTo(model:GetScale() * height / size.Y)
		end
	end
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

local function tweenPivot(
	model: Model,
	to: CFrame,
	seconds: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local from = model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(t: number)
		if model.Parent then
			model:PivotTo(from:Lerp(to, t))
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween.Completed:Once(function()
		value:Destroy()
	end)
	tween:Play()
	return tween
end

local function group(parent: Instance, name: string): Model
	return Create("Model", { Name = name, Parent = parent }) :: Model
end

local DESK = Color3.fromRGB(38, 25, 18)
local DESK_EDGE = Color3.fromRGB(62, 42, 30)
local MANILA = Color3.fromRGB(206, 182, 128)
local PAPER = Color3.fromRGB(232, 226, 210)
local STEEL = Color3.fromRGB(196, 200, 210)
local WARM = Color3.fromRGB(255, 226, 170)
local DUST = Color3.fromRGB(196, 186, 168)
local STAMP_RED = Color3.fromRGB(122, 22, 28)
local HARD_WHITE = Color3.fromRGB(255, 244, 222)

-- The desk a verdict lands on: dark wood on a lighter worn edge, a leather blotter.
local function desk(world: Instance)
	part(world, Vector3.new(5.6, 0.34, 3.8), CFrame.new(0, -0.17, 0), DESK, Enum.Material.Wood)
	part(world, Vector3.new(5.7, 0.08, 3.9), CFrame.new(0, -0.3, 0), DESK_EDGE, Enum.Material.Wood)
	part(
		world,
		Vector3.new(3.4, 0.03, 2.2),
		CFrame.new(-0.2, 0.015, 0.2),
		Color3.fromRGB(30, 34, 30),
		Enum.Material.Leather
	)
end

-- A case file lying on the desk: a manila folder, the sheet in it with its typed lines and a photo clipped to it.
local function caseFile(world: Instance, at: CFrame)
	part(world, Vector3.new(2.3, 0.05, 1.7), at, MANILA, Enum.Material.Fabric)
	part(world, Vector3.new(2.0, 0.02, 1.5), at * CFrame.new(0.05, 0.035, 0.02), PAPER)
	for k = 0, 4 do
		local width = if k == 4 then 0.7 else 1.3
		part(
			world,
			Vector3.new(width, 0.01, 0.05),
			at * CFrame.new(-0.25 + (1.3 - width) / 2 - 0.1, 0.05, -0.45 + k * 0.2),
			Color3.fromRGB(60, 56, 54)
		)
	end
	part(world, Vector3.new(0.5, 0.012, 0.62), at * CFrame.new(0.68, 0.052, -0.28), Color3.fromRGB(70, 70, 74))
	part(world, Vector3.new(0.06, 0.03, 0.2), at * CFrame.new(0.68, 0.06, -0.62), STEEL, Enum.Material.Metal)
end

-- The light a scene is lit with, kept so a flash can come back to it.
local function baseLight(view: ViewportFrame?): Color3
	if not view then
		return WARM
	end
	local kept = view:GetAttribute("BaseLight")
	if typeof(kept) == "Color3" then
		return kept
	end
	view:SetAttribute("BaseLight", view.LightColor)
	return view.LightColor
end

-- An impact on the desk at `at` (`hard` 0..1): a hard white flare, a flat ring running out over the wood, a puff of
-- dust, the view shaken and its light thrown up for a moment. In a still (a card): the flare and the ring as they
-- are an instant after it.
local function impact(view: ViewportFrame?, at: Vector3, hard: number, still: boolean?, tint: Color3?)
	if not view then
		return
	end
	local color = tint or HARD_WHITE
	local flare = { 0.08, 0.45 + 0.35 * hard }
	local ring = { 0.04, 0.32 + 0.25 * hard }
	if still then
		ViewFx.burst(view, at, { tex = "VfxFlare", color = color, size = flare, alpha = { 0, 1 }, still = 0.3, z = 3 })
		ViewFx.burst(
			view,
			at,
			{ tex = "VfxRing", color = color, size = ring, squash = 3, alpha = { 0.15, 1 }, still = 0.45, z = 2 }
		)
		return
	end
	ViewFx.burst(
		view,
		at,
		{ tex = "VfxFlare", color = color, size = flare, alpha = { 0, 1 }, life = 0.2, rot = { 0, 30 }, z = 3 }
	)
	ViewFx.burst(
		view,
		at,
		{ tex = "VfxRing", color = color, size = ring, squash = 3, alpha = { 0.15, 1 }, life = 0.4, z = 2 }
	)
	ViewFx.burst(view, at + Vector3.new(0, 0.15, 0), {
		tex = "VfxDust",
		color = DUST,
		size = { 0.12, 0.45 },
		alpha = { 0.45, 1 },
		life = 0.7,
		drift = Vector2.new(0, -0.06),
		rot = { 0, 40 },
		z = 1,
	})
	ViewFx.shake(view, 0.04 + 0.08 * hard, 0.25 + 0.15 * hard)
	local base = baseLight(view)
	view.LightColor = Color3.new(1, 1, 1)
	TweenService:Create(view, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { LightColor = base }):Play()
end

-- A glint off steel at `at`: a small star and a long thin streak across it.
local function glint(view: ViewportFrame?, at: Vector3, still: boolean?)
	if not view then
		return
	end
	local streak = { tex = "VfxStreak", color = HARD_WHITE, size = { 0.05, 0.42 }, squash = 0.12, alpha = { 0, 1 } }
	local star = { tex = "VfxFlare", color = HARD_WHITE, size = { 0.04, 0.2 }, alpha = { 0, 1 } }
	for _, spec in ipairs({ streak, star }) do
		local s = table.clone(spec) :: any
		s.rot = { 45, 60 }
		s.z = 3
		if still then
			s.still = 0.35
		else
			s.life = 0.35
		end
		ViewFx.burst(view, at, s)
	end
end

local function gavelScene(world: Instance, view: ViewportFrame?, still: boolean?): number
	desk(world)
	-- The sound block: a round of dark wood with a brass band.
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local block = part(
		world,
		Vector3.new(0.34, 1.5, 1.5),
		CFrame.new(0.7, 0.17, 0.1) * upright,
		Color3.fromRGB(58, 36, 24),
		Enum.Material.Wood
	)
	block.Shape = Enum.PartType.Cylinder
	local band = part(
		world,
		Vector3.new(0.1, 1.54, 1.54),
		CFrame.new(0.7, 0.2, 0.1) * upright,
		Color3.fromRGB(176, 140, 72),
		Enum.Material.Metal
	)
	band.Shape = Enum.PartType.Cylinder
	local raised = CFrame.new(0.7, 1.7, 0.25) * CFrame.Angles(0, math.rad(20), math.rad(-50))
	local struck = CFrame.new(0.7, 0.72, 0.25) * CFrame.Angles(0, math.rad(20), math.rad(-92))
	local gavel = prop("Gavel", if still then struck else raised, world, 1.9)
		or (function()
			local m = group(world, "Gavel")
			local at = if still then struck else raised
			part(
				m,
				Vector3.new(0.95, 0.48, 0.48),
				at * CFrame.new(0, 0.62, 0),
				Color3.fromRGB(60, 36, 24),
				Enum.Material.Wood
			)
			part(
				m,
				Vector3.new(0.14, 1.5, 0.14),
				at * CFrame.new(0, -0.2, 0),
				Color3.fromRGB(60, 36, 24),
				Enum.Material.Wood
			)
			m.WorldPivot = at
			return m
		end)()
	local top = Vector3.new(0.7, 0.36, 0.1)
	if still then
		impact(view, top, 1, true)
		return 0
	end
	-- Lifted a little higher, then down hard; lifted, and down harder.
	tweenPivot(gavel, raised * CFrame.Angles(0, 0, math.rad(12)), 0.3, Enum.EasingStyle.Sine)
	task.delay(0.32, function()
		tweenPivot(gavel, struck, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.1, function()
			Sfx.play("gavel")
			impact(view, top, 0.5)
		end)
		task.delay(0.45, function()
			tweenPivot(gavel, raised * CFrame.Angles(0, 0, math.rad(18)), 0.3, Enum.EasingStyle.Sine)
		end)
		task.delay(0.8, function()
			tweenPivot(gavel, struck, 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.09, function()
				Sfx.play("gavel")
				impact(view, top, 1)
			end)
		end)
	end)
	return 2.0
end

local function cuffsScene(world: Instance, view: ViewportFrame?, still: boolean?): number
	desk(world)
	caseFile(world, CFrame.new(-0.1, 0.04, 0.1) * CFrame.Angles(0, math.rad(-8), 0))
	local open = CFrame.new(0, 1.5, -0.2) * CFrame.Angles(math.rad(70), math.rad(30), 0)
	local shut = CFrame.new(0, 0.34, 0.05) * CFrame.Angles(math.rad(86), math.rad(-12), 0)
	local cuffs = prop("Handcuffs", if still then shut else open, world, 0.9)
		or (function()
			local m = group(world, "Cuffs")
			local at = if still then shut else open
			for side = -1, 1, 2 do
				local ring =
					part(m, Vector3.new(0.7, 0.12, 0.7), at * CFrame.new(side * 0.55, 0, 0), STEEL, Enum.Material.Metal)
				ring.Shape = Enum.PartType.Cylinder
			end
			m.WorldPivot = at
			return m
		end)()
	local lock = Vector3.new(0.25, 0.42, 0.05)
	if still then
		glint(view, lock + Vector3.new(0, 0.12, 0), true)
		return 0
	end
	task.delay(0.25, function()
		tweenPivot(cuffs, shut, 0.35, Enum.EasingStyle.Back)
		task.delay(0.33, function()
			Sfx.play("handcuffs")
			if view then
				glint(view, lock + Vector3.new(0, 0.12, 0))
				ViewFx.sparks(view, lock, 12, Color3.fromRGB(255, 196, 120), 0.22)
				ViewFx.burst(view, lock, {
					tex = "VfxRing",
					color = STEEL,
					size = { 0.03, 0.22 },
					squash = 3,
					alpha = { 0.2, 1 },
					life = 0.3,
					z = 2,
				})
				ViewFx.shake(view, 0.05, 0.2)
			end
		end)
		-- (the light catching the steel once more as it settles)
		task.delay(1.0, function()
			glint(view, lock + Vector3.new(-0.5, 0.1, 0))
		end)
	end)
	return 1.8
end

local function checkmateScene(world: Instance, view: ViewportFrame?, still: boolean?): number
	desk(world)
	-- A corner of the board: squares of marble in a dark wooden frame.
	part(world, Vector3.new(4.3, 0.08, 3.3), CFrame.new(0, 0.04, 0.2), Color3.fromRGB(46, 30, 20), Enum.Material.Wood)
	for x = -2, 1 do
		for z = -1, 1 do
			part(
				world,
				Vector3.new(1, 0.05, 1),
				CFrame.new(x + 0.5, 0.1, z + 0.2),
				if (x + z) % 2 == 0 then Color3.fromRGB(214, 206, 190) else Color3.fromRGB(30, 28, 28),
				Enum.Material.Marble
			)
		end
	end
	local base = CFrame.new(0.5, 0.125, 0.2)
	local edge = CFrame.new(0.92, 0.125, 0.2)
	local down = edge * CFrame.Angles(0, 0, math.rad(-90)) * edge:Inverse() * base
	local king = prop("ChessKing", if still then down else base, world, 1.8)
		or (function()
			local m = group(world, "King")
			local at = if still then down else base
			local black = Color3.fromRGB(20, 20, 22)
			part(m, Vector3.new(0.8, 0.3, 0.8), at * CFrame.new(0, 0.15, 0), black)
			part(m, Vector3.new(0.36, 1.2, 0.36), at * CFrame.new(0, 0.9, 0), black)
			part(m, Vector3.new(0.12, 0.36, 0.12), at * CFrame.new(0, 1.66, 0), black)
			m.WorldPivot = at
			return m
		end)()
	-- (where it lies: its middle, along the board)
	local middle = Vector3.new(1.75, 0.45, 0.2)
	local function cracked(asStill: boolean?)
		if not view then
			return
		end
		local spec: ViewFx.Spec = {
			tex = "VfxCrack",
			color = Color3.fromRGB(10, 10, 12),
			size = { 0.18, 0.34 },
			alpha = { 0.05, 0.05 },
			rot = { -20, -20 },
			z = 2,
		}
		if asStill then
			spec.still = 1
		else
			spec.life = 1.2
			spec.keep = true
		end
		ViewFx.burst(view, middle, spec)
	end
	if still then
		cracked(true)
		return 0
	end
	task.delay(0.5, function()
		tweenPivot(king, down, 0.45, Enum.EasingStyle.Bounce)
		task.delay(0.22, function()
			-- It lands: it cracks across, chips fly and a dull dust rises off the board.
			cracked()
			Sfx.play("gavel", { volume = 0.5, pitch = 0.7 })
			if view then
				impact(view, middle - Vector3.new(0, 0.2, 0), 0.4, false, Color3.fromRGB(220, 214, 204))
				local rng = Random.new(5)
				for _ = 1, 7 do
					local angle = rng:NextNumber(-math.pi, 0)
					ViewFx.burst(view, middle, {
						tex = "VfxChunk",
						color = Color3.fromRGB(40, 40, 44),
						size = { 0.04, 0.02 },
						alpha = { 0, 1 },
						life = rng:NextNumber(0.35, 0.6),
						rot = { 0, rng:NextNumber(-200, 200) },
						drift = Vector2.new(math.cos(angle) * 0.2, math.sin(angle) * 0.14 + 0.08),
						z = 3,
					})
				end
			end
		end)
	end)
	return 2.0
end

local function sugarScene(world: Instance, view: ViewportFrame?, still: boolean?): number
	desk(world)
	-- A saucer under a tower of sugar cubes, a cup of tea beside it.
	local saucer = part(
		world,
		Vector3.new(0.06, 1.5, 1.5),
		CFrame.new(-0.2, 0.03, 0.1) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(236, 234, 228),
		Enum.Material.SmoothPlastic
	)
	saucer.Shape = Enum.PartType.Cylinder
	prop("Teacup", CFrame.new(1.25, 0, 0.35) * CFrame.Angles(0, math.rad(-30), 0), world, 0.7)
	local cubes: { Model } = {}
	for level = 0, 6 do
		local cf = CFrame.new(-0.2, 0.28 + level * 0.43, 0.1) * CFrame.Angles(0, math.rad(level * 9), 0)
		local cube = prop("SugarCube", cf * CFrame.new(0, -0.21, 0), world, 0.42)
			or (function()
				local m = group(world, "Cube")
				part(m, Vector3.new(0.42, 0.42, 0.42), cf, Color3.fromRGB(244, 242, 236), Enum.Material.Sand)
				m.WorldPivot = cf * CFrame.new(0, -0.21, 0)
				return m
			end)()
		table.insert(cubes, cube)
	end
	local top = cubes[#cubes]
	local flicked = CFrame.new(1.6, 2.4, -0.2) * CFrame.Angles(math.rad(70), math.rad(40), math.rad(20))
	local function streak(asStill: boolean?)
		if not view then
			return
		end
		local spec: ViewFx.Spec = {
			tex = "VfxStreak",
			color = Color3.fromRGB(250, 248, 240),
			size = { 0.28, 0.12 },
			squash = 0.16,
			alpha = { 0.2, 1 },
			rot = { 62, 62 },
			z = 2,
		}
		if asStill then
			spec.still = 0.2
			ViewFx.burst(view, Vector3.new(0.75, 3.0, -0.1), spec)
		else
			spec.life = 0.35
			ViewFx.burst(view, function()
				return top:GetPivot().Position
			end, spec)
		end
	end
	if still then
		top:PivotTo(CFrame.new(1.1, 3.3, -0.1) * CFrame.Angles(math.rad(40), math.rad(30), math.rad(15)))
		streak(true)
		return 0
	end
	-- The top cube flicked off; then the tower goes.
	task.delay(0.45, function()
		tweenPivot(top, flicked, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		streak()
		Sfx.play("clockTick", { volume = 0.7, pitch = 1.4 })
	end)
	task.delay(0.8, function()
		local rng = Random.new(7)
		for index = 1, #cubes - 1 do
			local cube = cubes[index]
			local at = cube:GetPivot()
			local land = CFrame.new(
				at.X + (index - 2) * 0.3 + rng:NextNumber(-0.2, 0.2),
				0.06,
				at.Z + rng:NextNumber(-0.6, 0.6)
			) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextInteger(0, 1) * 90))
			task.delay(index * 0.04, function()
				tweenPivot(cube, land, 0.45 + index * 0.04, Enum.EasingStyle.Bounce)
			end)
		end
		task.delay(0.35, function()
			if view then
				ViewFx.burst(view, Vector3.new(-0.2, 0.4, 0.1), {
					tex = "VfxDust",
					color = Color3.fromRGB(250, 248, 242),
					size = { 0.2, 0.6 },
					alpha = { 0.35, 1 },
					life = 0.9,
					drift = Vector2.new(0, -0.05),
					z = 2,
				})
				ViewFx.sparks(view, Vector3.new(-0.2, 0.2, 0.1), 10, Color3.fromRGB(250, 248, 242), 0.18)
			end
		end)
	end)
	return 2.2
end

local function stampScene(world: Instance, view: ViewportFrame?, still: boolean?): number
	desk(world)
	caseFile(world, CFrame.new(0, 0.04, 0.15) * CFrame.Angles(0, math.rad(4), 0))
	-- The seal: a turned wooden handle and knob on a steel block, its rubber face underneath.
	local up = CFrame.new(-0.1, 1.7, 0.05) * CFrame.Angles(0, math.rad(-10), 0)
	local down = CFrame.new(-0.1, 0.43, 0.05) * CFrame.Angles(0, math.rad(-6), 0)
	local seal = group(world, "Seal")
	part(seal, Vector3.new(1.3, 0.22, 0.62), up * CFrame.new(0, -0.24, 0), STEEL, Enum.Material.Metal)
	part(seal, Vector3.new(1.24, 0.06, 0.56), up * CFrame.new(0, -0.38, 0), STAMP_RED, Enum.Material.Rubber)
	local neck = part(
		seal,
		Vector3.new(0.5, 0.26, 0.26),
		up * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(80, 52, 32),
		Enum.Material.Wood
	)
	neck.Shape = Enum.PartType.Cylinder
	local knob = part(
		seal,
		Vector3.new(0.52, 0.52, 0.52),
		up * CFrame.new(0, 0.48, 0),
		Color3.fromRGB(80, 52, 32),
		Enum.Material.Wood
	)
	knob.Shape = Enum.PartType.Ball
	seal.WorldPivot = up
	local fileAt = Vector3.new(0.05, 0.08, 0.15)
	local function guilty(asStill: boolean?)
		if not view then
			return
		end
		local at = ViewFx.project(view, fileAt) or Vector2.new(0.5, 0.6)
		local frame = Create("Frame", {
			Name = "Guilty",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(at.X, at.Y),
			Size = UDim2.fromScale(0.4, 0.13),
			Rotation = -8,
			ZIndex = view.ZIndex + 1,
			Parent = view,
		})
		local stroke = Create("UIStroke", { Color = STAMP_RED, Thickness = 2, Transparency = 0.15, Parent = frame })
		local word = Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "GUILTY",
			TextScaled = true,
			FontFace = Font.fromEnum(Enum.Font.SpecialElite),
			TextColor3 = STAMP_RED,
			TextTransparency = 0.08,
			ZIndex = view.ZIndex + 1,
			Parent = frame,
		})
		word:SetAttribute("KeepFont", true)
		if not asStill and not Motion.isReduced() then
			local scale = Instance.new("UIScale")
			scale.Scale = 1.35
			scale.Parent = frame
			TweenService
				:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
			word.TextTransparency = 1
			stroke.Transparency = 1
			TweenService:Create(word, TweenInfo.new(0.1), { TextTransparency = 0.08 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.1), { Transparency = 0.15 }):Play()
		end
	end
	if still then
		seal:PivotTo(up * CFrame.new(0.9, 0.5, 0.4) * CFrame.Angles(0, 0, math.rad(-18)))
		guilty(true)
		return 0
	end
	task.delay(0.35, function()
		tweenPivot(seal, down, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.1, function()
			Sfx.play("stamp")
			impact(view, fileAt, 0.8)
		end)
		task.delay(0.5, function()
			tweenPivot(seal, up * CFrame.new(0.6, 0.4, 0.3) * CFrame.Angles(0, 0, math.rad(-12)), 0.35)
			guilty()
		end)
	end)
	return 2.0
end

-- The interrogation lamp: a bare concrete floor and an empty chair; a lamp on a cord swings in over it and the room
-- goes dark round a shaft of warm light, a pool of it on the floor under the chair and dust turning in the beam.
local function lampScene(world: Instance, view: ViewportFrame?, still: boolean?): number
	part(world, Vector3.new(9, 0.2, 7), CFrame.new(0, -0.1, 0.8), Color3.fromRGB(44, 44, 46), Enum.Material.Concrete)
	local chair = prop("Chair", CFrame.new(0, 0, 0.5), world, 2.4)
	if not chair then
		local m = group(world, "Chair")
		local metal = Color3.fromRGB(46, 44, 42)
		part(m, Vector3.new(1.2, 0.14, 1.1), CFrame.new(0, 0.8, 0.5), metal, Enum.Material.Metal)
		part(m, Vector3.new(1.2, 1.1, 0.12), CFrame.new(0, 1.4, 1.05), metal, Enum.Material.Metal)
		for _, x in ipairs({ -0.5, 0.5 }) do
			for _, z in ipairs({ 0.05, 0.95 }) do
				part(m, Vector3.new(0.08, 0.8, 0.08), CFrame.new(x, 0.4, z), metal, Enum.Material.Metal)
			end
		end
	end
	-- The lamp: a dark enamel dome on a cord, a rolled rim, the bulb's warm glass showing under it.
	local pivot = CFrame.new(0, 6.2, 0.5)
	local lamp = group(world, "Lamp")
	local hang = pivot * CFrame.new(0, -3.4, 0)
	part(lamp, Vector3.new(0.035, 3.2, 0.035), pivot * CFrame.new(0, -1.7, 0), Color3.fromRGB(18, 18, 20))
	local cap = part(
		lamp,
		Vector3.new(0.32, 0.22, 0.22),
		hang * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(26, 26, 28),
		Enum.Material.Metal
	)
	cap.Shape = Enum.PartType.Cylinder
	local dome = part(lamp, Vector3.new(1.3, 1.3, 1.3), hang, Color3.fromRGB(34, 36, 34), Enum.Material.Metal)
	dome.Shape = Enum.PartType.Ball
	-- (its open mouth: the inside of the shade, lit, and the rolled rim round it)
	local mouth = part(
		lamp,
		Vector3.new(0.06, 1.18, 1.18),
		hang * CFrame.new(0, -0.32, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 238, 200),
		Enum.Material.Neon
	)
	mouth.Shape = Enum.PartType.Cylinder
	local rim = part(
		lamp,
		Vector3.new(0.1, 1.36, 1.36),
		hang * CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(22, 22, 24),
		Enum.Material.Metal
	)
	rim.Shape = Enum.PartType.Cylinder
	local bulb = part(lamp, Vector3.new(0.36, 0.36, 0.36), hang * CFrame.new(0, -0.38, 0), WARM, Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	lamp.WorldPivot = pivot
	local function bulbAt(): Vector3
		return bulb.Position - Vector3.new(0, 0.1, 0)
	end
	-- The room going dark round the lamp's light.
	local function lightsDown(seconds: number)
		if not view then
			return
		end
		local goal = {
			Ambient = Color3.fromRGB(12, 12, 16),
			LightColor = WARM,
			LightDirection = Vector3.new(0, -1, 0.2),
		}
		if seconds <= 0 then
			for key, value in pairs(goal) do
				(view :: any)[key] = value
			end
		else
			TweenService:Create(view, TweenInfo.new(seconds, Enum.EasingStyle.Quad), goal):Play()
		end
	end
	-- The shaft: three soft columns from the bulb to the floor (narrow and bright at the lamp, wide and faint at the
	-- floor), the pool of light on the floor, the bulb's flare. Kept on the lamp as it swings.
	local function shaft(asStill: boolean?)
		if not view then
			return
		end
		local layers = {}
		for k, look in ipairs({ { 0.16, 0.25, 0.35 }, { 0.42, 0.55, 0.8 }, { 0.85, 0.78, 0.92 } }) do
			local column = Create("ImageLabel", {
				Name = "Shaft" .. k,
				BackgroundTransparency = 1,
				Image = Vfx.Tex.id("VfxColumn"),
				ImageColor3 = WARM,
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = view.ZIndex + 1,
				Parent = view,
			}) :: ImageLabel
			Create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, look[2]),
					NumberSequenceKeypoint.new(0.7, look[3]),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = column,
			})
			table.insert(layers, { label = column, width = look[1] })
		end
		local function place()
			local top = ViewFx.project(view, bulbAt())
			local floor = ViewFx.project(view, Vector3.new(bulbAt().X, 0, bulbAt().Z))
			if not top or not floor then
				return
			end
			local size = view.AbsoluteSize
			local dx, dy = (floor.X - top.X) * size.X, (floor.Y - top.Y) * size.Y
			local length = math.sqrt(dx * dx + dy * dy)
			for _, layer in ipairs(layers) do
				layer.label.Position = UDim2.fromScale(top.X, top.Y)
				layer.label.Size = UDim2.fromOffset(size.Y * layer.width, length)
				layer.label.Rotation = math.deg(math.atan2(-dx, dy))
			end
		end
		place()
		local pool: ViewFx.Spec = {
			tex = "VfxGlow",
			color = WARM,
			size = { 0.5, 0.5 },
			squash = 2.4,
			alpha = { 0.45, 0.45 },
			z = 0,
		}
		local flare: ViewFx.Spec = {
			tex = "VfxFlare",
			color = Color3.fromRGB(255, 246, 226),
			size = { 0.22, 0.22 },
			alpha = { 0.05, 0.05 },
			z = 3,
		}
		if asStill then
			pool.still = 0
			flare.still = 0
			ViewFx.burst(view, Vector3.new(0, 0.02, 0.5), pool)
			ViewFx.burst(view, bulbAt(), flare)
			view:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
			return
		end
		pool.life = 60
		flare.life = 60
		ViewFx.burst(view, function()
			return Vector3.new(bulbAt().X, 0.02, bulbAt().Z)
		end, pool)
		ViewFx.burst(view, bulbAt, flare)
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if not view.Parent then
				connection:Disconnect()
				return
			end
			place()
		end)
		-- (dust turning slowly in the beam)
		task.spawn(function()
			local rng = Random.new()
			while view.Parent do
				local at = bulbAt()
					+ Vector3.new(rng:NextNumber(-0.5, 0.5), -rng:NextNumber(0.6, 3.2), rng:NextNumber(-0.4, 0.4))
				ViewFx.burst(view, at, {
					tex = "VfxEmber",
					color = Color3.fromRGB(255, 236, 200),
					size = { 0.012, 0.012 },
					alpha = { 0.5, 1 },
					life = rng:NextNumber(1.2, 2),
					drift = Vector2.new(rng:NextNumber(-0.02, 0.02), rng:NextNumber(0.01, 0.04)),
					z = 2,
				})
				task.wait(0.12)
			end
		end)
	end
	if still then
		lightsDown(0)
		shaft(true)
		return 0
	end
	local from = pivot * CFrame.Angles(0, 0, math.rad(38))
	lamp:PivotTo(from)
	tweenPivot(lamp, pivot * CFrame.Angles(0, 0, math.rad(-14)), 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.4, function()
		lightsDown(0.45)
		shaft()
		Sfx.play("clockTick", { volume = 0.9, pitch = 0.7 })
	end)
	task.delay(0.55, function()
		tweenPivot(lamp, pivot * CFrame.Angles(0, 0, math.rad(6)), 0.65, Enum.EasingStyle.Sine)
		task.delay(0.65, function()
			tweenPivot(lamp, pivot * CFrame.Angles(0, 0, math.rad(-2)), 0.7, Enum.EasingStyle.Sine)
		end)
	end)
	return 2.4
end

local SCENES: { [string]: (Instance, ViewportFrame?, boolean?) -> number } = {
	gavel = gavelScene,
	cuffs = cuffsScene,
	checkmate = checkmateScene,
	sugar = sugarScene,
	stamp = stampScene,
	lamp = lampScene,
}

-- Builds a verdict's little scene in `world` (around the origin, the camera looking at it from -Z) and plays it, or
-- (`still`) sets it at its moment for a card. Returns how long it runs.
local function verdictScene(world: Instance, style: string, view: ViewportFrame?, still: boolean?): number
	local scene = SCENES[style]
	return if scene then scene(world, view, still) else 0
end

-- The view a verdict plays in, its world and its camera (looking at the desk from -Z, a little above).
local function verdictView(parent: Instance, props: { [string]: any }): (ViewportFrame, WorldModel)
	local view = Create("ViewportFrame", {
		Name = "Verdict",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 158),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, 0.4),
		Parent = parent,
	}) :: ViewportFrame
	for key, value in pairs(props) do
		(view :: any)[key] = value
	end
	local world = Instance.new("WorldModel")
	world.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.4, -5.2), Vector3.new(0, 0.6, 0))
	camera.Parent = view
	view.CurrentCamera = camera
	return view, world
end

-- Plays a verdict over the screen in a small 3D view (`parent`: a GuiObject or a ScreenGui; `size`
-- and `position` place the view). Returns a function that takes it away.
function Styles.verdict(style: string?, parent: Instance, position: UDim2?, size: UDim2?): () -> ()
	if not style then
		return function() end
	end
	local view, world = verdictView(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.78, 0.5),
		Size = size or UDim2.fromOffset(340, 300),
		ZIndex = 8,
	})
	if style == "lamp" then
		-- (the lamp's room: seen from lower down and further back, the cord's top out of sight)
		(view.CurrentCamera :: Camera).CFrame = CFrame.lookAt(Vector3.new(0, 2.2, -6.4), Vector3.new(0, 1.5, 0.5))
	end
	verdictScene(world, style, view)
	if not Motion.isReduced() then
		local scale = Instance.new("UIScale")
		scale.Scale = 0.85
		scale.Parent = view
		Motion.tween(scale, { Scale = 1 }, 0.25)
	end
	return function()
		view:Destroy()
	end
end

-- A verdict at its moment, still, filling `parent` (a card's picture): the gavel just landed, the cuffs shut with a
-- glint, the king lying cracked, the top cube flicked off its tower, GUILTY on the file, the lamp's light on the chair.
function Styles.verdictStill(style: string, parent: GuiObject): ViewportFrame?
	if not SCENES[style] then
		return nil
	end
	local view, world = verdictView(parent, { Size = UDim2.fromScale(1, 1), ZIndex = parent.ZIndex + 1 })
	local camera = view.CurrentCamera :: Camera
	camera.CFrame = if style == "lamp"
		then CFrame.lookAt(Vector3.new(0, 2.3, -6.6), Vector3.new(0, 1.6, 0.5))
		else CFrame.lookAt(Vector3.new(-0.4, 2.6, -5.0), Vector3.new(0.2, 0.5, 0.1))
	verdictScene(world, style, view, true)
	return view
end

-- Death styles ----------------------------------------------------------------------------------------------

local ASH = Color3.fromRGB(96, 92, 88)
local STONE = Color3.fromRGB(128, 126, 120)
local GLASS = Color3.fromRGB(196, 214, 222)
local FEATHER = Color3.fromRGB(18, 18, 22)

-- Breaks a body part into `count` pieces of its material that tumble down and fade (stone crumbling, glass
-- falling in shards). Returns them.
local function shatter(
	piece: BasePart,
	here: Instance,
	count: number,
	color: Color3,
	material: Enum.Material,
	rng: Random
)
	local size = piece.Size
	for k = 1, count do
		local bit = part(
			here,
			Vector3.new(size.X * rng:NextNumber(0.35, 0.6), size.Y / count, size.Z * rng:NextNumber(0.35, 0.7)),
			piece.CFrame
				* CFrame.new(rng:NextNumber(-0.2, 0.2), size.Y * ((k - 0.5) / count - 0.5), rng:NextNumber(-0.2, 0.2)),
			color,
			material
		)
		if material == Enum.Material.Glass then
			bit.Transparency = 0.35
		end
		local fall = bit.CFrame
			* CFrame.new(
				rng:NextNumber(-0.8, 0.8),
				-(bit.Position.Y - piece.Position.Y + size.Y / 2) - 0.2,
				rng:NextNumber(-0.8, 0.8)
			)
			* CFrame.Angles(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5))
		TweenService
			:Create(bit, TweenInfo.new(rng:NextNumber(0.45, 0.8), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = fall,
			})
			:Play()
		task.delay(1.2, function()
			TweenService:Create(bit, TweenInfo.new(1.0), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(bit, 2.4)
	end
end

local function bodyParts(model: Model): { BasePart }
	local list = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
			table.insert(list, item)
		end
	end
	return list
end

local function inView(model: Instance): boolean
	return model:FindFirstAncestorWhichIsA("ViewportFrame") ~= nil
end

-- A crow (Tokyo's prop, or a small dark shape) that bursts up and flies off.
local function crow(parent: Instance, from: Vector3, rng: Random)
	local cf = CFrame.new(from) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local bird = prop("Crow", cf, parent, 0.9)
		or (function()
			local m = group(parent, "Crow")
			part(m, Vector3.new(0.5, 0.4, 1.0), cf, Color3.fromRGB(16, 16, 20))
			part(m, Vector3.new(1.6, 0.06, 0.5), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(16, 16, 20))
			m.WorldPivot = cf
			return m
		end)()
	local away = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.9, 1.6), rng:NextNumber(-1, 1)).Unit
		* rng:NextNumber(14, 22)
	tweenPivot(
		bird,
		CFrame.new(from + away) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		rng:NextNumber(1.4, 2.2),
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.In
	)
	Debris:AddItem(bird, 2.6)
end

-- (the world's own effects on top of the parts, from the VFX kit: none in a 3D view, none on Low graphics)

-- Grey dust and a few chips off a piece as it turns to stone.
local function stoneDust(piece: BasePart)
	Vfx.Emit.burst(piece.Position, {
		{
			{
				tex = "VfxDust",
				grid = 4,
				mode = "OneShot",
				color = STONE,
				light = 0,
				lit = 0.7,
				size = { { 0, 0.5 }, { 1, 1.5 } },
				alpha = { { 0, 0.2 }, { 0.7, 0.5 }, { 1, 1 } },
				life = { 0.5, 0.8 },
				speed = { 1.5, 3 },
				drag = 3,
				spread = 180,
				rot = { 0, 360 },
			},
			3,
		},
		{
			{
				tex = "VfxChunk",
				grid = 2,
				fps = 0, -- (each a piece of its own: a random frame that stays)
				startRandom = true,
				color = STONE,
				light = 0,
				lit = 1,
				size = { { 0, 0.18 }, { 1, 0.12 } },
				life = { 0.5, 0.8 },
				speed = { 3, 6 },
				accel = Vector3.new(0, -40, 0),
				spread = 70,
				rot = { 0, 360 },
				spin = { -300, 300 },
			},
			3,
		},
	})
end

-- The stone figure crumbling: chunks of it tumbling down, a low cloud of grit rolling out over the floor, a ring
-- of it along the floor and the dust hanging after.
local function stoneCrumble(centre: Vector3)
	local floor = centre - Vector3.new(0, 2.9, 0)
	Vfx.Emit.burst(centre, {
		{
			{
				tex = "VfxChunk",
				grid = 2,
				fps = 0, -- (each a piece of its own: a random frame that stays)
				startRandom = true,
				color = { { 0, STONE }, { 1, Color3.fromRGB(96, 94, 90) } },
				light = 0,
				lit = 1,
				size = { { 0, 0.5 }, { 1, 0.35 } },
				life = { 0.7, 1.1 },
				speed = { 4, 11 },
				accel = Vector3.new(0, -55, 0),
				drag = 0.5,
				spread = 120,
				rot = { 0, 360 },
				spin = { -260, 260 },
			},
			26,
		},
		{
			{
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = Color3.fromRGB(150, 146, 140),
				light = 0,
				lit = 0.7,
				size = { { 0, 1.4 }, { 1, 4.2 } },
				alpha = { { 0, 0.35 }, { 0.6, 0.55 }, { 1, 1 } },
				life = { 1.4, 2.2 },
				speed = { 1, 3 },
				drag = 1.5,
				spread = 180,
				rot = { 0, 360 },
				spin = { -20, 20 },
				shape = Enum.ParticleEmitterShape.Box,
			},
			7,
		},
	}, nil, Vector3.new(2, 4, 2))
	Vfx.Emit.burst(CFrame.new(floor + Vector3.new(0, 0.15, 0)), {
		tex = "VfxDust",
		grid = 4,
		mode = "OneShot",
		color = STONE,
		light = 0,
		lit = 0.7,
		size = { { 0, 1.4 }, { 1, 3.6 } },
		alpha = { { 0, 0.1 }, { 0.7, 0.4 }, { 1, 1 } },
		life = { 0.8, 1.3 },
		speed = { 9, 15 },
		drag = 5,
		spread = { 88, 88 },
		rot = { 0, 360 },
		spin = { -40, 40 },
	}, 12)
	Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.12, 0)), 0.8, 8, 0.5, {
		tex = "VfxRingBand",
		color = STONE,
		width = 1.2,
		light = 0.2,
		bright = 0.9,
	})
end

-- The glass body bursting: a white glint, shards flung tumbling and glinting as they fall, glitter hanging after,
-- a cold flash.
local function glassBurst(centre: Vector3)
	Vfx.Emit.burst(centre, {
		{
			{
				tex = "VfxFlare",
				color = Color3.new(1, 1, 1),
				size = { { 0, 1 }, { 0.25, 6 }, { 1, 0 } },
				life = 0.25,
				rot = { 0, 360 },
				bright = 1.6,
				z = 2,
			},
			1,
		},
		{
			{
				tex = "VfxRing",
				color = GLASS,
				size = { { 0, 1 }, { 1, 10 } },
				alpha = { { 0, 0.2 }, { 0.5, 0.55 }, { 1, 1 } },
				life = 0.3,
				light = 0.5,
				bright = 1,
				z = 1,
			},
			1,
		},
		{
			{
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = { { 0, Color3.new(1, 1, 1) }, { 1, GLASS } },
				size = { { 0, 0.42 }, { 1, 0.3 } },
				alpha = { { 0, 0.25 }, { 0.7, 0.4 }, { 1, 1 } },
				life = { 0.6, 1.1 },
				speed = { 6, 16 },
				accel = Vector3.new(0, -50, 0),
				drag = 1,
				spread = 180,
				rot = { 0, 360 },
				spin = { -500, 500 },
				light = 0.5,
				bright = 1.3,
			},
			30,
		},
		{
			{
				tex = "VfxFlare",
				color = Color3.new(1, 1, 1),
				size = { { 0, 0 }, { 0.15, 0.5 }, { 0.3, 0 }, { 0.55, 0.4 }, { 0.7, 0 }, { 1, 0 } },
				life = { 0.9, 1.5 },
				speed = { 2, 7 },
				accel = Vector3.new(0, -8, 0),
				drag = 2,
				spread = 180,
				rot = { 0, 90 },
				bright = 1.5,
			},
			16,
		},
	})
	Vfx.Light.flash(centre, GLASS, 16, 3, 0.4)
end

-- Ash lifting off a body: grey flakes drifting up and away, embers glowing and going grey, a thin smoke.
local function ashRise(centre: Vector3, seconds: number)
	local box = Vfx.Emit.point(CFrame.new(centre), Vector3.new(2.6, 4, 2.6))
	local flakes = Vfx.Emit.make(box, {
		tex = "VfxChunk",
		grid = 2,
		fps = 0,
		startRandom = true,
		color = { { 0, Color3.fromRGB(70, 66, 62) }, { 1, ASH } },
		light = 0,
		lit = 0.9,
		size = { { 0, 0.16 }, { 1, 0.1 } },
		alpha = { { 0, 0 }, { 0.75, 0.2 }, { 1, 1 } },
		life = { 1.8, 2.8 },
		speed = { 0.6, 1.6 },
		accel = Vector3.new(0.8, 2.2, 0.3),
		drag = 0.8,
		spread = 60,
		rot = { 0, 360 },
		spin = { -120, 120 },
		rate = 34,
		shape = Enum.ParticleEmitterShape.Box,
	})
	local embers = Vfx.Emit.make(box, {
		tex = "VfxEmber",
		color = { { 0, Color3.fromRGB(255, 150, 70) }, { 0.6, Color3.fromRGB(200, 70, 30) }, { 1, ASH } },
		size = { { 0, 0.14 }, { 1, 0 } },
		life = { 1, 1.8 },
		speed = { 1, 2.5 },
		accel = Vector3.new(0.5, 2.5, 0),
		drag = 1,
		spread = 50,
		bright = 1.4,
		rate = 16,
		shape = Enum.ParticleEmitterShape.Box,
	})
	local smoke = Vfx.Emit.make(box, {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(110, 106, 102),
		light = 0,
		lit = 0.6,
		size = { { 0, 1 }, { 1, 3.4 } },
		alpha = { { 0, 0.6 }, { 0.5, 0.7 }, { 1, 1 } },
		life = { 1.8, 2.6 },
		speed = { 1.5, 3 },
		accel = Vector3.new(0.6, 0.8, 0),
		spread = 25,
		rot = { 0, 360 },
		spin = { -20, 20 },
		rate = 6,
		shape = Enum.ParticleEmitterShape.Box,
	})
	Vfx.Clock.after(seconds, function()
		flakes.Enabled = false
		embers.Enabled = false
		smoke.Enabled = false
	end)
	Vfx.Clock.after(seconds + 3, function()
		box:Destroy()
	end)
end

-- Black feathers: a dark burst as the body comes apart, feathers whirling up off it, and more drifting down as the
-- crows fly.
local function featherBurst(centre: Vector3, count: number, up: boolean)
	local list: { any } = {
		{
			{
				tex = "VfxFeather",
				color = FEATHER,
				light = 0,
				lit = 0.6,
				size = { { 0, 0.5 }, { 1, 0.4 } },
				alpha = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
				life = { 1.4, 2.4 },
				speed = if up then { 5, 11 } else { 1, 4 },
				accel = Vector3.new(0, if up then 2 else -3, 0),
				drag = 2.5,
				spread = 180,
				rot = { 0, 360 },
				spin = { -220, 220 },
			},
			count,
		},
	}
	if up then
		table.insert(list, {
			{
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = Color3.fromRGB(34, 30, 38),
				light = 0,
				lit = 0.4,
				size = { { 0, 1.8 }, { 1, 5 } },
				alpha = { { 0, 0.55 }, { 0.6, 0.72 }, { 1, 1 } },
				life = { 1.0, 1.6 },
				speed = { 3, 7 },
				accel = Vector3.new(0, 3, 0),
				drag = 3,
				spread = 180,
				rot = { 0, 360 },
				spin = { -40, 40 },
			},
			8,
		})
	end
	Vfx.Emit.burst(centre, list, nil, Vector3.new(1.6, 3, 1.6))
end

-- Plays a death style on a fallen body (a character in the world, or the copy in Your look). Returns
-- how long it runs. The body is left as the style leaves it (stone stays stone; ash and crows leave
-- nothing).
function Styles.death(style: string?, model: Model): number
	if not style then
		return 0
	end
	local parts = bodyParts(model)
	local box = model:GetBoundingBox()
	local centre = box.Position
	local here = model.Parent or workspace
	local world = not inView(model)
	local rng = Random.new(math.floor(centre.X * 7 + centre.Z))
	local low = centre.Y - 3
	if style == "stone" then
		-- Stone creeps up from the feet, part by part; a held moment; then the figure crumbles.
		Sfx.play("stoneCrack")
		for _, piece in ipairs(parts) do
			local delay = math.clamp((piece.Position.Y - low) / 5, 0, 1) * 0.9
			task.delay(delay, function()
				piece.Material = Enum.Material.Slate
				TweenService:Create(piece, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Color = STONE }):Play()
				if world and not Vfx.quiet() then
					stoneDust(piece)
				end
				for _, decal in ipairs(piece:GetChildren()) do
					if decal:IsA("Decal") then
						TweenService:Create(decal, TweenInfo.new(0.4), { Transparency = 1 }):Play()
					end
				end
			end)
		end
		task.delay(1.9, function()
			Sfx.play("stoneCrack")
			if world then
				stoneCrumble(centre)
			end
			for _, piece in ipairs(parts) do
				if piece.Parent then
					shatter(piece, here, 3, STONE, Enum.Material.Slate, rng)
					piece.Transparency = 1
				end
			end
		end)
		return 3.2
	elseif style == "glass" then
		-- It turns to glass (a glint runs over it), a beat, then cracks and falls in shards.
		if world then
			task.delay(0.45, function()
				Vfx.Recipes.twinkle(centre + Vector3.new(0.4, 1.4, 0), { color = GLASS, scale = 1.2 })
			end)
		end
		for _, piece in ipairs(parts) do
			piece.Material = Enum.Material.Glass
			TweenService:Create(piece, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Color = GLASS, Transparency = 0.3 })
				:Play()
			for _, decal in ipairs(piece:GetChildren()) do
				if decal:IsA("Decal") then
					TweenService:Create(decal, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
		end
		task.delay(0.9, function()
			Sfx.play("stoneCrack")
			if world then
				FxKit.shape(
					"spikes",
					CFrame.new(centre),
					{ size = 5, seconds = 0.2, color = GLASS, transparency = 0.3 }
				)
				glassBurst(centre)
			end
			for _, piece in ipairs(parts) do
				if piece.Parent then
					shatter(piece, here, 4, GLASS, Enum.Material.Glass, rng)
					piece.Transparency = 1
				end
			end
		end)
		return 2.4
	elseif style == "ash" then
		-- It greys from the head down, then crumbles the same way: each part breaking into ash that tumbles and
		-- blows off, until a low drift of ash lies where it fell.
		local _, size = model:GetBoundingBox()
		local top = centre.Y + size.Y / 2
		local floor = centre.Y - size.Y / 2
		for _, piece in ipairs(parts) do
			local delay = math.clamp((top - piece.Position.Y) / math.max(size.Y, 1), 0, 1)
			task.delay(delay * 0.5, function()
				piece.Material = Enum.Material.Sand
				TweenService:Create(piece, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Color = ASH }):Play()
				for _, decal in ipairs(piece:GetChildren()) do
					if decal:IsA("Decal") then
						TweenService:Create(decal, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					end
				end
			end)
			task.delay(0.9 + delay * 0.9, function()
				if piece.Parent then
					shatter(piece, here, 5, ASH, Enum.Material.Sand, rng)
					piece.Transparency = 1
				end
			end)
		end
		-- The drift: low mounds of ash, softly rounded, run together where the body lay.
		local heap = group(here, "AshHeap")
		local along = (box.RightVector * size.X + box.LookVector * size.Z).Unit
		for k = 1, 7 do
			local r = rng:NextNumber(0.5, 1.1) * (if k == 1 then 1.4 else 1)
			local spot = centre + along * rng:NextNumber(-1.4, 1.4) + box.LookVector * rng:NextNumber(-0.5, 0.5)
			local lump = part(
				heap,
				Vector3.new(r * 2.2, r * 0.55, r * 1.7),
				CFrame.new(spot.X, floor + r * 0.08, spot.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				ASH:Lerp(Color3.fromRGB(40, 38, 36), rng:NextNumber(0, 0.35)),
				Enum.Material.Sand
			)
			Create("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = lump })
			lump.Transparency = 1
			task.delay(1.1 + k * 0.08, function()
				TweenService:Create(lump, TweenInfo.new(0.9), { Transparency = 0 }):Play()
			end)
		end
		Debris:AddItem(heap, if world then 8 else 4)
		if world then
			ashRise(centre, 1.8)
		end
		return 2.8
	elseif style == "crows" then
		-- The body comes apart from the feet up into a whirl of black feathers, and the whirl flies off as crows.
		Sfx.play("crows")
		if world then
			featherBurst(centre, 18, true)
			task.delay(1.0, function()
				featherBurst(centre + Vector3.new(0, 2.5, 0), 12, false)
			end)
		end
		for _, piece in ipairs(parts) do
			local delay = math.clamp((piece.Position.Y - low) / 5, 0, 1) * 0.6
			task.delay(delay, function()
				TweenService:Create(piece, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end)
		end
		for k = 1, 22 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0.4, 1.3)
			local start = CFrame.new(centre + Vector3.new(math.cos(a) * r, rng:NextNumber(-2.2, 1.2), math.sin(a) * r))
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
			local feather = part(here, Vector3.new(0.12, 0.05, 0.42), start, FEATHER)
			local turn = a + rng:NextNumber(2, 4)
			local up = CFrame.new(
				centre + Vector3.new(math.cos(turn) * (r + 0.6), rng:NextNumber(1.5, 3.5), math.sin(turn) * (r + 0.6))
			) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
			task.delay(k * 0.025, function()
				TweenService:Create(feather, TweenInfo.new(1.0, Enum.EasingStyle.Sine), { CFrame = up }):Play()
				task.delay(0.8, function()
					TweenService:Create(feather, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end)
			end)
			Debris:AddItem(feather, 1.6)
		end
		task.delay(1.0, function()
			for _ = 1, 9 do
				crow(
					here,
					centre + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(1.2, 3), rng:NextNumber(-1, 1)),
					rng
				)
			end
		end)
		return 3.0
	elseif style == "strings" then
		-- Strings from far above to its head and limbs, taut a moment, then cut: they fall away.
		local holder = group(here, "Strings")
		local tops = {}
		for _, name in ipairs({ "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
			local limb = model:FindFirstChild(name)
			if limb and limb:IsA("BasePart") then
				local low = limb.Position
				local high = low + Vector3.new(0, 14, 0)
				local thread = part(
					holder,
					Vector3.new(0.05, 14, 0.05),
					CFrame.new((low + high) / 2),
					Color3.fromRGB(214, 206, 190)
				)
				table.insert(tops, thread)
			end
		end
		task.delay(0.7, function()
			Sfx.play("stringsSnap")
			if world then
				for _, thread in ipairs(tops) do
					local cut = thread.Position + Vector3.new(0, 4, 0)
					Vfx.Emit.burst(cut, {
						{
							{
								tex = "VfxFlare",
								color = Color3.new(1, 1, 1),
								size = { { 0, 0.3 }, { 0.25, 2.2 }, { 1, 0 } },
								life = 0.2,
								rot = { 0, 360 },
								bright = 1.5,
							},
							1,
						},
						{
							{
								tex = "VfxStreak",
								color = Color3.fromRGB(255, 244, 220),
								size = { { 0, 0.18 }, { 1, 0.04 } },
								squash = -2,
								life = { 0.2, 0.4 },
								speed = { 8, 16 },
								drag = 3,
								accel = Vector3.new(0, -30, 0),
								spread = 180,
								face = "along",
								bright = 1.4,
							},
							6,
						},
					})
				end
			end
			for index, thread in ipairs(tops) do
				local fallen = thread.CFrame
					* CFrame.new(0, -3, 0)
					* CFrame.Angles(math.rad(index * 25), 0, math.rad(index * 40))
				TweenService:Create(thread, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = fallen,
					Transparency = 1,
				}):Play()
			end
		end)
		Debris:AddItem(holder, 2)
		return 1.8
	end
	return 0
end

-- Deathsinger forms -----------------------------------------------------------------------------------------

local FORM = "LGhostForm"

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
