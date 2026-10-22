-- How the shop's styles look when they play (the items: Shared/Cosmetics). One place for each, used by
-- the cutscenes, the world and the shop's Your look alike:
--
--   writing  how Diavolo's names go into the Manual (BookStage writes each line through write()):
--            quill (black strokes that smoulder at the edges as they dry), typewriter (struck letter by
--            letter), fire (letters that burn in bright and char), knife (cut into the page), chalk (the
--            dust falls off the page), frost (the letters frost over, crystals spreading). Plain without one.
--   verdict  how Ace's arrest lands (Presenters/Arrest, the ending): a small scene over the shot:
--            gavel, cuffs, checkmate (a king toppled), sugar (a tower of sugar cubes falls), stamp (GUILTY
--            pressed into the file), lamp (an interrogation lamp swings down, the rest goes dark).
--   death    what becomes of a body after it falls (Presenters/Death, Your look): ash, strings (cut
--            from above), crows (a whirl of feathers that flies off as crows), stone (stone creeps up from
--            the feet, then it crumbles), glass (it cracks like glass and falls in shards).
--   form     what a Deathsinger wears (World/GhostVisibility): embers, veil, chains, crows (a moulting
--            feather cloak, a crow on each shoulder), marionette, moths (a cold light in the chest, pale moths
--            about it).
--
-- Everything here is built from parts, so it also plays inside a 3D view (the shop), where particles
-- and beams do not draw; in the world, particles are added on top. The props come from the Core models
-- (Quill, Knife, Gavel, Handcuffs, ChessKing, SugarCube, Coin, Apple, Chain, CrowCloak, MarionetteBar,
-- and Tokyo's Crow), with plain parts standing in until they are imported.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local FxKit = require(script.Parent.FxKit)
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

-- Little squares laid over the page by a line (smoke, chalk dust, frost crystals): each from a spot along the
-- line, moved by `drift` (px) and faded out over `seconds`, grown from nothing when `grow`.
local function flecks(
	clip: Frame,
	shown: number,
	count: number,
	color: Color3,
	size: number,
	drift: () -> Vector2,
	seconds: number,
	grow: boolean?
)
	local height = clip.Size.Y.Offset
	local rng = Random.new(shown + count)
	for _ = 1, count do
		local at = Vector2.new(
			clip.Position.X.Offset + rng:NextInteger(4, math.max(5, math.floor(shown) - 4)),
			clip.Position.Y.Offset + math.floor(height * rng:NextNumber(0.35, 0.85))
		)
		local fleck = Create("Frame", {
			Name = "Fleck",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Rotation = rng:NextNumber(0, 90),
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = if grow then UDim2.fromOffset(0, 0) else UDim2.fromOffset(size, size),
			Parent = clip.Parent,
		})
		local move = drift()
		TweenService:Create(fleck, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(at.X + move.X, at.Y + move.Y),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size, size),
		}):Play()
		Debris:AddItem(fleck, seconds + 0.1)
	end
end

-- Writes one line: `clip` is the line's clipping frame (empty), `label` its text inside, `shown` how wide
-- the writing is (px), `pace` seconds per letter. Yields until the line is written.
function Styles.write(clip: Frame, label: TextLabel, shown: number, pace: number, style: string?)
	local height = clip.Size.Y.Offset
	local letters = math.max(4, utf8.len(label.Text) or #label.Text)
	if style == "typewriter" then
		-- Struck one letter at a time, the line already there.
		clip.Size = UDim2.fromOffset(shown, height)
		label.MaxVisibleGraphemes = 0
		for count = 1, letters do
			label.MaxVisibleGraphemes = count
			if count % 2 == 1 then
				Sfx.play("typewriter", { volume = 0.5, pitch = 0.95 + math.random() * 0.1 })
			end
			task.wait(pace * 0.9)
		end
		label.MaxVisibleGraphemes = -1
		return
	end
	local time = pace * letters * (if style == "knife" then 0.7 else 1)
	if style == "knife" then
		-- Cut into the page: a pale edge under the dark groove.
		local edge = label:Clone()
		edge.Name = "CutEdge"
		edge.TextColor3 = CUT_EDGE
		edge.TextTransparency = 0.25
		edge.Position = UDim2.fromOffset(0, math.max(1, math.floor(height * 0.03)))
		edge.ZIndex = label.ZIndex - 1
		edge.Parent = clip
		Sfx.play("knifeScrape", { volume = 0.6 })
	end
	TweenService:Create(
		clip,
		TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Size = UDim2.fromOffset(shown, height) }
	):Play()
	task.wait(time)
	local rng = Random.new(#label.Text)
	if style == "quill" then
		-- The strokes smoulder at their edges as they dry, and a little smoke comes off them.
		label.TextStrokeColor3 = SMOULDER
		label.TextStrokeTransparency = 0.3
		TweenService:Create(label, TweenInfo.new(2.4, Enum.EasingStyle.Quad), { TextStrokeTransparency = 1 }):Play()
		flecks(clip, shown, 4, Color3.fromRGB(120, 116, 112), math.max(3, math.floor(height * 0.08)), function()
			return Vector2.new(rng:NextNumber(-6, 6), -height * rng:NextNumber(0.6, 1.1))
		end, 1.6)
	elseif style == "chalk" then
		-- Chalk dust falls off the page under the letters.
		label.TextStrokeColor3 = Color3.fromRGB(70, 58, 44)
		label.TextStrokeTransparency = 0.75
		flecks(clip, shown, 7, CHALK, math.max(2, math.floor(height * 0.05)), function()
			return Vector2.new(rng:NextNumber(-3, 3), height * rng:NextNumber(0.5, 1.2))
		end, 1.3)
	elseif style == "frost" then
		-- The letters frost over (white cooling to ice blue) and crystals spread out from them.
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.55
		TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { TextColor3 = FROST }):Play()
		flecks(clip, shown, 6, Color3.fromRGB(236, 246, 255), math.max(4, math.floor(height * 0.14)), function()
			return Vector2.new(rng:NextNumber(-10, 10), rng:NextNumber(-8, 8))
		end, 1.8, true)
	elseif style == "fire" then
		-- Burnt in: the bright letters cool to char.
		TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { TextColor3 = CHAR }):Play()
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

-- Builds a verdict's little scene in `world` (around the origin, the camera looking at it from -Z) and
-- plays it. Returns how long it runs.
local function verdictScene(world: Instance, style: string, view: ViewportFrame?): number
	part(world, Vector3.new(5, 0.3, 3.4), CFrame.new(0, -0.15, 0), Color3.fromRGB(34, 22, 16), Enum.Material.Wood)
	if style == "gavel" then
		part(
			world,
			Vector3.new(1.4, 0.3, 1.4),
			CFrame.new(0.6, 0.15, 0),
			Color3.fromRGB(70, 44, 30),
			Enum.Material.Wood
		)
		local raised = CFrame.new(0.6, 1.4, 0.2) * CFrame.Angles(0, math.rad(20), math.rad(-60))
		local struck = CFrame.new(0.6, 0.62, 0.2) * CFrame.Angles(0, math.rad(20), math.rad(-92))
		local gavel = prop("Gavel", raised, world, 1.9)
			or (function()
				local m = group(world, "Gavel")
				part(
					m,
					Vector3.new(0.95, 0.48, 0.48),
					raised * CFrame.new(0, 0.62, 0),
					Color3.fromRGB(60, 36, 24),
					Enum.Material.Wood
				)
				part(
					m,
					Vector3.new(0.14, 1.5, 0.14),
					raised * CFrame.new(0, -0.2, 0),
					Color3.fromRGB(60, 36, 24),
					Enum.Material.Wood
				)
				m.WorldPivot = raised
				return m
			end)()
		task.delay(0.35, function()
			tweenPivot(gavel, struck, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.12, function()
				Sfx.play("gavel")
			end)
			task.delay(0.5, function()
				tweenPivot(gavel, raised, 0.3)
			end)
			task.delay(0.85, function()
				tweenPivot(gavel, struck, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.12, function()
					Sfx.play("gavel")
				end)
			end)
		end)
		return 1.8
	elseif style == "cuffs" then
		local open = CFrame.new(0, 1.0, 0) * CFrame.Angles(math.rad(70), math.rad(30), 0)
		local cuffs = prop("Handcuffs", open, world, 0.9)
			or (function()
				local m = group(world, "Cuffs")
				for side = -1, 1, 2 do
					local ring = part(
						m,
						Vector3.new(0.7, 0.12, 0.7),
						open * CFrame.new(side * 0.55, 0, 0),
						Color3.fromRGB(190, 194, 204),
						Enum.Material.Metal
					)
					ring.Shape = Enum.PartType.Cylinder
				end
				m.WorldPivot = open
				return m
			end)()
		task.delay(0.3, function()
			tweenPivot(
				cuffs,
				CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(80), math.rad(-10), 0),
				0.35,
				Enum.EasingStyle.Back
			)
			task.delay(0.35, function()
				Sfx.play("handcuffs")
			end)
		end)
		return 1.6
	elseif style == "checkmate" then
		for x = -2, 1 do
			for z = -1, 0 do
				part(
					world,
					Vector3.new(1, 0.05, 1),
					CFrame.new(x + 0.5, 0.03, z + 0.5),
					if (x + z) % 2 == 0 then Color3.fromRGB(214, 206, 190) else Color3.fromRGB(30, 28, 28)
				)
			end
		end
		local base = CFrame.new(0, 0.05, 0)
		local king = prop("ChessKing", base, world, 1.8)
			or (function()
				local m = group(world, "King")
				part(m, Vector3.new(0.8, 0.3, 0.8), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(20, 20, 22))
				part(m, Vector3.new(0.36, 1.2, 0.36), base * CFrame.new(0, 0.9, 0), Color3.fromRGB(20, 20, 22))
				part(m, Vector3.new(0.12, 0.36, 0.12), base * CFrame.new(0, 1.66, 0), Color3.fromRGB(20, 20, 22))
				m.WorldPivot = base
				return m
			end)()
		-- Toppled: it tips over its foot's edge and lies down.
		local edge = CFrame.new(0.42, 0.05, 0)
		local down = edge * CFrame.Angles(0, 0, math.rad(-90)) * edge:Inverse() * base
		task.delay(0.5, function()
			tweenPivot(king, down, 0.45, Enum.EasingStyle.Bounce)
		end)
		return 1.8
	elseif style == "sugar" then
		-- A tower of sugar cubes, then it falls.
		local cubes = {}
		for level = 0, 5 do
			local cf = CFrame.new(0, 0.22 + level * 0.43, 0) * CFrame.Angles(0, math.rad(level * 9), 0)
			local cube = prop("SugarCube", cf * CFrame.new(0, -0.21, 0), world, 0.42)
				or (function()
					local m = group(world, "Cube")
					part(m, Vector3.new(0.42, 0.42, 0.42), cf, Color3.fromRGB(244, 242, 236), Enum.Material.Sand)
					m.WorldPivot = cf * CFrame.new(0, -0.21, 0)
					return m
				end)()
			table.insert(cubes, cube)
		end
		task.delay(0.6, function()
			local rng = Random.new(7)
			for index, cube in ipairs(cubes) do
				local at = cube:GetPivot()
				local land = CFrame.new(
					at.X + (index - 2) * 0.32 + rng:NextNumber(-0.2, 0.2),
					0,
					at.Z + rng:NextNumber(-0.6, 0.6)
				) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextInteger(0, 1) * 90))
				task.delay(index * 0.05, function()
					tweenPivot(cube, land, 0.45 + index * 0.04, Enum.EasingStyle.Bounce)
				end)
			end
		end)
		return 2.0
	elseif style == "stamp" then
		-- The file, and a steel seal that slams down on it: GUILTY pressed into the page (a word over the view:
		-- a 3D view draws no writing).
		part(
			world,
			Vector3.new(2.6, 0.04, 1.8),
			CFrame.new(0, 0.02, 0),
			Color3.fromRGB(214, 200, 168),
			Enum.Material.Fabric
		)
		local up = CFrame.new(0, 1.6, 0)
		local down = CFrame.new(0, 0.42, 0)
		local seal = group(world, "Seal")
		part(
			seal,
			Vector3.new(1.3, 0.22, 0.6),
			up * CFrame.new(0, -0.3, 0),
			Color3.fromRGB(150, 152, 158),
			Enum.Material.Metal
		)
		part(seal, Vector3.new(0.5, 0.4, 0.4), up, Color3.fromRGB(70, 46, 30), Enum.Material.Wood)
		local knob = part(seal, Vector3.new(0.5, 0.5, 0.5), up * CFrame.new(0, 0.38, 0), Color3.fromRGB(70, 46, 30))
		knob.Shape = Enum.PartType.Ball
		seal.WorldPivot = up
		task.delay(0.35, function()
			tweenPivot(seal, down, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.12, function()
				Sfx.play("gavel")
			end)
			task.delay(0.45, function()
				tweenPivot(seal, up * CFrame.new(0, 0.6, 0), 0.35)
				if view then
					local word = Create("TextLabel", {
						Name = "Guilty",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.6),
						Size = UDim2.fromScale(0.62, 0.2),
						Rotation = -8,
						Text = "GUILTY",
						TextScaled = true,
						FontFace = Font.fromEnum(Enum.Font.SpecialElite),
						TextColor3 = Color3.fromRGB(46, 38, 34),
						TextStrokeColor3 = Color3.fromRGB(226, 212, 182),
						TextStrokeTransparency = 0.55,
						TextTransparency = 1,
						ZIndex = view.ZIndex + 1,
						Parent = view,
					})
					TweenService:Create(word, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
				end
			end)
		end)
		return 1.8
	elseif style == "lamp" then
		-- A hanging lamp swings down onto an empty chair and everything else goes dark.
		local chair = group(world, "Chair")
		part(
			chair,
			Vector3.new(1.2, 0.14, 1.1),
			CFrame.new(0, 0.7, 0.3),
			Color3.fromRGB(46, 44, 42),
			Enum.Material.Metal
		)
		part(
			chair,
			Vector3.new(1.2, 1.1, 0.12),
			CFrame.new(0, 1.3, 0.85),
			Color3.fromRGB(46, 44, 42),
			Enum.Material.Metal
		)
		for _, x in ipairs({ -0.5, 0.5 }) do
			for _, z in ipairs({ -0.15, 0.75 }) do
				part(
					chair,
					Vector3.new(0.08, 0.7, 0.08),
					CFrame.new(x, 0.35, z),
					Color3.fromRGB(40, 38, 36),
					Enum.Material.Metal
				)
			end
		end
		local hang = CFrame.new(0, 2.6, 0.2)
		local lamp = group(world, "Lamp")
		local shade = part(
			lamp,
			Vector3.new(0.7, 0.9, 0.9),
			hang * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(30, 30, 32),
			Enum.Material.Metal
		)
		shade.Shape = Enum.PartType.Cylinder
		part(lamp, Vector3.new(0.04, 3, 0.04), hang * CFrame.new(0, 1.8, 0), Color3.fromRGB(20, 20, 22))
		local bulb = part(
			lamp,
			Vector3.new(0.34, 0.34, 0.34),
			hang * CFrame.new(0, -0.38, 0),
			Color3.fromRGB(255, 236, 190),
			Enum.Material.Neon
		)
		bulb.Shape = Enum.PartType.Ball
		local cone = part(
			lamp,
			Vector3.new(2.3, 0.6, 0.6),
			hang * CFrame.new(0, -1.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 236, 190),
			Enum.Material.Neon
		)
		cone.Shape = Enum.PartType.Cylinder
		cone.Transparency = 1
		lamp.WorldPivot = hang * CFrame.new(0, 3.3, 0)
		local top = lamp.WorldPivot
		local from = top * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(34))
		lamp:PivotTo(from)
		tweenPivot(lamp, top * CFrame.Angles(0, 0, math.rad(-12)), 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.5, function()
			tweenPivot(lamp, top * CFrame.Angles(0, 0, math.rad(5)), 0.6, Enum.EasingStyle.Sine)
			TweenService:Create(cone, TweenInfo.new(0.4), { Transparency = 0.86 }):Play()
			if view then
				TweenService:Create(view, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
					Ambient = Color3.fromRGB(16, 16, 20),
					LightColor = Color3.fromRGB(255, 226, 170),
				}):Play()
			end
			task.delay(0.6, function()
				tweenPivot(lamp, top, 0.7, Enum.EasingStyle.Sine)
			end)
		end)
		return 2.0
	end
	return 0
end

-- Plays a verdict over the screen in a small 3D view (`parent`: a GuiObject or a ScreenGui; `size`
-- and `position` place the view). Returns a function that takes it away.
function Styles.verdict(style: string?, parent: Instance, position: UDim2?, size: UDim2?): () -> ()
	if not style then
		return function() end
	end
	local view = Create("ViewportFrame", {
		Name = "Verdict",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 158),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.78, 0.5),
		Size = size or UDim2.fromOffset(340, 300),
		ZIndex = 8,
		Parent = parent,
	}) :: ViewportFrame
	local world = Instance.new("WorldModel")
	world.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.4, -5.2), Vector3.new(0, 0.6, 0))
	camera.Parent = view
	view.CurrentCamera = camera
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
				FxKit.puff(centre - Vector3.new(0, 1.5, 0), 2.4, STONE, 8)
				FxKit.shape("ring", CFrame.new(centre - Vector3.new(0, 2.9, 0)), {
					size = 9,
					seconds = 0.5,
					color = STONE,
					material = Enum.Material.ForceField,
					transparency = 0.2,
				})
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
		-- It turns to glass, a beat, then cracks and falls in shards.
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
				FxKit.light(centre, GLASS, 14, 3, 0.4)
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
		for _, piece in ipairs(parts) do
			TweenService:Create(piece, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Color = ASH }):Play()
			piece.Material = Enum.Material.Sand
			task.delay(0.9, function()
				TweenService
					:Create(
						piece,
						TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ Transparency = 1 }
					)
					:Play()
			end)
		end
		-- A low heap of ash where it lay.
		local heap = part(
			here,
			Vector3.new(0.4, 3.2, 3.2),
			CFrame.new(centre.X, centre.Y - 0.6, centre.Z) * CFrame.Angles(0, 0, math.rad(90)),
			ASH,
			Enum.Material.Sand
		)
		heap.Shape = Enum.PartType.Cylinder
		heap.Transparency = 1
		TweenService:Create(heap, TweenInfo.new(1.6), { Transparency = 0 }):Play()
		Debris:AddItem(heap, if world then 8 else 4)
		if world then
			local anchor = part(here, Vector3.new(3, 1, 3), CFrame.new(centre), ASH)
			anchor.Transparency = 1
			local smoke = Assets.texture("Smoke")
			local emitter = Create("ParticleEmitter", {
				Rate = 40,
				Lifetime = NumberRange.new(1.5, 2.5),
				Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(40, 40),
				Acceleration = Vector3.new(0, 1.5, 0),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) }),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Color = ColorSequence.new(ASH),
				Parent = anchor,
			}) :: ParticleEmitter
			if smoke ~= "" then
				emitter.Texture = smoke
			end
			task.delay(1.8, function()
				emitter.Enabled = false
			end)
			Debris:AddItem(anchor, 5)
		end
		return 2.6
	elseif style == "crows" then
		-- The body comes apart from the feet up into a whirl of black feathers, and the whirl flies off as crows.
		Sfx.play("crows")
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
		Create("ParticleEmitter", {
			Rate = 18,
			Lifetime = NumberRange.new(0.8, 1.6),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, 4, 0),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(tint, Color3.fromRGB(255, 220, 140)),
			Parent = carrier,
		})
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
		Create("ParticleEmitter", {
			Rate = 3,
			Lifetime = NumberRange.new(1.6, 2.4),
			Speed = NumberRange.new(0.2, 0.6),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -1.6, 0),
			Drag = 1.5,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Size = NumberSequence.new(0.22),
			Squash = NumberSequence.new(1.5),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(FEATHER),
			LightInfluence = 1,
			Shape = Enum.ParticleEmitterShape.Box,
			Parent = carrier,
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
		Create("ParticleEmitter", {
			Rate = 5,
			Lifetime = NumberRange.new(1.8, 3),
			Speed = NumberRange.new(0.6, 1.4),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.4, 0),
			Drag = 0.8,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.18) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(240, 234, 214)),
			LightEmission = 0.4,
			Parent = light,
		})
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
	end
	return folder
end

return Styles
