-- Ace's verdict styles as insert shots (rebuilt 2026-11-16 for the user's "check how verdict styles work and make them
-- way more high quality"; until then a small boxed 3D view beside the arrest). Each is a short scene of its own, played
-- full screen through the scene deaths' frame (SceneDeaths.register / play: its own lamps, real shadows, cuts, focus,
-- particles), on Ace's desk in a dark office under a banker's lamp, the arrested one's name typed on the case file:
--
--   gavel      the gavel comes down on its sound block twice, dust jumping off the wood in the lamp's beam
--   cuffs      the cuffs dropped onto the case file, a spark where the steel hits, a glint running along them
--   checkmate  the ivory queen slides in beside the black king; the king rocks, topples and cracks, a red line in it
--   sugar      the top cube of the sugar tower flicked off into the tea, the tower falling after it
--   stamp      the stamp lifted wet off its pad and slammed down: GUILTY in red over the name
--   lamp       one lamp on a cord swinging in over an empty chair, everything else dark, dust in its light
--
-- Played after the arrest's stamp (Presenters/Arrest: on Ace's screen, on everyone's when the one arrested is the
-- Hand) and as the ending's last beat when the Bureau won (Presenters/Outro); the shop's "Your look" previews them.
-- Each runs VerdictTiming.LENGTH seconds (the server holds the match that long, ArrestService / RoundService). Ace
-- is never seen: the hands that strike and stamp stay out of the frame, as in a film's insert.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local VerdictTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("VerdictTiming"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local SceneDeaths = require(script.Parent.SceneDeaths)
local Vfx = require(script.Parent.Vfx)
local Governor = require(script.Parent.Parent.World.Governor)

local Verdicts = {}

Verdicts.LENGTH = VerdictTiming.LENGTH
-- (beside the scene deaths' origin, far enough that neither set reaches the other)
local ORIGIN = CFrame.new(-6000, 650, 6600)

local TOP = 3 -- the desk's top, studs off the floor
-- (lighter than the wood itself: under one lamp a true walnut read black in a play test, 2026-11-16)
local WALNUT = Color3.fromRGB(104, 66, 42)
local WALNUT_DARK = Color3.fromRGB(62, 40, 26)
local BLOTTER = Color3.fromRGB(44, 70, 52)
local ROOM = Color3.fromRGB(16, 14, 13)
local PAPER = Color3.fromRGB(226, 220, 204)
local TYPE = Color3.fromRGB(34, 32, 34)
local LAMP = Color3.fromRGB(255, 208, 150)
local RIM = Color3.fromRGB(150, 170, 210)
local DUST = Color3.fromRGB(214, 196, 168)
local STEEL = Color3.fromRGB(226, 230, 238)
local INK_RED = Color3.fromRGB(150, 18, 28)
local SPARK = Color3.fromRGB(255, 226, 170)

local function clamp01(u: number): number
	return math.clamp(u, 0, 1)
end

local function smooth(u: number): number
	u = clamp01(u)
	return u * u * (3 - 2 * u)
end

-- How far a move from t0 to t1 has got at t: `kind` "in" (accelerating, a strike), "out" (settling), else smooth.
local function along(t: number, t0: number, t1: number, kind: string?): number
	local u = clamp01((t - t0) / math.max(1e-3, t1 - t0))
	if kind == "in" then
		return u * u * u
	elseif kind == "out" then
		return 1 - (1 - u) ^ 3
	end
	return smooth(u)
end

-- A prop from the imports, anchored and without collisions, its pivot at `cf` (scene space), scaled so its longest
-- side is `longest` (or as it comes). Nil when the import that holds it is not here.
local function model(ctx: any, key: string, cf: CFrame, longest: number?): Model?
	local m = ModelLibrary.get(key)
	if not m then
		return nil
	end
	if longest then
		local _, size = m:GetBoundingBox()
		local side = math.max(size.X, size.Y, size.Z)
		if side > 0 then
			m:ScaleTo(m:GetScale() * longest / side)
		end
	end
	for _, item in ipairs(m:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	m:PivotTo(ctx.origin * cf)
	m.Parent = ctx.stage.folder
	return m
end

-- A spot light on an invisible point (scene space) aimed at `look`.
local function spot(
	ctx: any,
	at: Vector3,
	look: Vector3,
	color: Color3,
	range: number,
	brightness: number,
	angle: number
)
	local p = ctx:part({ size = Vector3.new(0.2, 0.2, 0.2), alpha = 1, cast = false })
	p.CFrame = ctx.origin * CFrame.lookAt(at, look)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Angle = angle
	light.Shadows = not Governor.low("shadows")
	light.Parent = p
	return light
end

-- A sheet of typed paper lying on the desk (scene space, its head away from the camera), with `lines` typed on it: the
-- first in capitals as a heading, the name larger. Returns the sheet and its gui.
local function sheet(ctx: any, cf: CFrame, size: Vector2, lines: { string }): (BasePart, SurfaceGui)
	-- (turned a quarter so the gui's lines run across the frame, left to right, their tops away from the camera)
	local p = ctx:part({ size = Vector3.new(size.Y, 0.012, size.X), color = PAPER, material = Enum.Material.Fabric })
	p.CFrame = ctx.origin * cf * CFrame.Angles(0, math.rad(90), 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 220
	gui.LightInfluence = 1
	gui.Parent = p
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.08, 0)
	pad.PaddingRight = UDim.new(0.08, 0)
	pad.PaddingTop = UDim.new(0.07, 0)
	pad.Parent = gui
	for index, text in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, if index == 2 then 58 else 26)
		label.Font = Enum.Font.SpecialElite
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = TYPE
		label.TextTransparency = if index == 1 then 0.2 else 0.05
		label.Text = text
		label.Parent = gui
	end
	-- a few lines of the report under the name, typed but too small to read
	local rng = Random.new(1116)
	for row = 1, 9 do
		local line = Instance.new("Frame")
		line.LayoutOrder = 100 + row
		line.BorderSizePixel = 0
		line.BackgroundColor3 = TYPE
		line.BackgroundTransparency = 0.45
		line.Size = UDim2.new(rng:NextNumber(0.55, 0.95), 0, 0, 5)
		line.Parent = gui
	end
	return p, gui
end

-- The office every verdict but the lamp's plays in: a dark room, Ace's walnut desk with its green blotter, the
-- banker's lamp at the back left throwing a warm pool over the blotter, a cold rim from behind, dust in the light,
-- and the case file open on the left with the name on it. Returns the lamp's key light.
local function office(ctx: any, fileAt: CFrame?): SpotLight
	SceneDeaths.box(ctx, Vector3.new(28, 14, 28), Vector3.new(0, 0, 3), ROOM, Enum.Material.Plaster)
	ctx:part({
		size = Vector3.new(10, 0.34, 5.6),
		at = Vector3.new(0, TOP - 0.17, 0.8),
		color = WALNUT,
		material = Enum.Material.Wood,
	})
	ctx:part({
		size = Vector3.new(10.1, 0.12, 5.7),
		at = Vector3.new(0, TOP - 0.4, 0.8),
		color = WALNUT_DARK,
		material = Enum.Material.Wood,
	})
	ctx:part({
		size = Vector3.new(9.6, TOP - 0.46, 5.2),
		at = Vector3.new(0, (TOP - 0.46) / 2, 0.9),
		color = WALNUT_DARK,
		material = Enum.Material.Wood,
	})
	ctx:part({
		size = Vector3.new(5.4, 0.03, 3.2),
		at = Vector3.new(0.3, TOP + 0.015, 0.6),
		color = BLOTTER,
		material = Enum.Material.Leather,
	})
	for _, x in ipairs({ -2.4, 3.0 }) do
		-- (the blotter's leather corners)
		ctx:part({
			size = Vector3.new(0.5, 0.035, 3.24),
			at = Vector3.new(x, TOP + 0.018, 0.6),
			color = WALNUT_DARK,
			material = Enum.Material.Leather,
		})
	end
	local lamp = model(ctx, "BankerLamp", CFrame.new(-3.4, TOP, 2.3) * CFrame.Angles(0, math.rad(-20), 0), 2.3)
	if not lamp then
		ctx:part({
			size = Vector3.new(1.6, 0.5, 0.7),
			at = Vector3.new(-3.4, TOP + 1.7, 2.3),
			color = Color3.fromRGB(30, 70, 46),
			material = Enum.Material.Glass,
		})
	end
	-- (the lamp's pool falls on the blotter from above and a little in front, so what lies on it shows its face to the
	-- camera; seen in a play test 2026-11-16: from behind the desk it left every face black)
	local key = spot(ctx, Vector3.new(-1.4, TOP + 3.6, -0.6), Vector3.new(0.6, TOP, 0.5), LAMP, 18, 4.5, 80)
	ctx:light(Vector3.new(-3.4, TOP + 1.5, 2.1), LAMP, 7, 0.8)
	spot(ctx, Vector3.new(3.5, TOP + 3.5, 5.5), Vector3.new(0, TOP + 0.4, 0), RIM, 16, 1.1, 50)
	-- a dim warm fill from the camera's side
	spot(ctx, Vector3.new(0.8, TOP + 1.8, -5), Vector3.new(0.2, TOP + 0.3, 0.3), LAMP, 12, 0.55, 60)
	-- the room beyond the lamp falls off to black: a faint warm bounce off the wall behind
	ctx:light(Vector3.new(0, TOP + 2, 8), Color3.fromRGB(90, 66, 50), 14, 0.25)
	-- dust turning in the lamp's light
	SceneDeaths.emit(ctx, Vector3.new(-0.8, TOP + 1.6, 0.8), Vector3.new(4, 2.6, 3), {
		tex = "VfxDust",
		color = DUST,
		size = { { 0, 0.02 }, { 1, 0.035 } },
		alpha = { { 0, 1 }, { 0.3, 0.55 }, { 0.7, 0.6 }, { 1, 1 } },
		life = { 2.5, 4 },
		speed = { 0.05, 0.15 },
		spread = 180,
		lit = 1,
		rate = 40,
	})
	-- the case file, open, the name typed on its top sheet
	local at = fileAt or CFrame.new(-1.3, TOP + 0.03, 0.1) * CFrame.Angles(0, math.rad(6), 0)
	if not model(ctx, "CaseFolder", at, 2.4) then
		ctx:part({
			size = Vector3.new(2.4, 0.03, 1.7),
			at = at.Position,
			color = Color3.fromRGB(200, 172, 118),
			material = Enum.Material.Fabric,
		})
	end
	sheet(ctx, at * CFrame.new(-0.58, 0.05, -0.02) * CFrame.Angles(0, math.rad(-2), 0), Vector2.new(0.98, 1.3), {
		"SUSPECT",
		ctx.victimName or "Unknown",
	})
	return key
end

-- A spark and dust off a hit at `at` (scene space): `hard` 0..1, `tint` the spark's colour, `chips` bits of wood.
local function hit(ctx: any, at: Vector3, hard: number, tint: Color3?, chips: Color3?)
	local world = ctx:world(at)
	Vfx.Emit.burst(CFrame.new(world), {
		{
			{
				tex = "VfxFlare",
				color = tint or SPARK,
				size = { { 0, 0.3 * hard }, { 0.3, 1.1 * hard }, { 1, 0.2 } },
				alpha = { { 0, 0.1 }, { 1, 1 } },
				life = 0.18,
				light = 1,
				z = 1,
			},
			1,
		},
		{
			{
				tex = "VfxDust",
				color = DUST,
				size = { { 0, 0.15 }, { 1, 0.6 + 0.5 * hard } },
				alpha = { { 0, 0.45 }, { 1, 1 } },
				life = { 0.6, 1.1 },
				speed = { 0.6, 1.6 * hard + 0.4 },
				spread = 80,
				dir = Enum.NormalId.Top,
				drag = 3,
				lit = 1,
				rot = { 0, 360 },
			},
			math.floor(10 + 14 * hard),
		},
	})
	if chips then
		Vfx.Emit.burst(CFrame.new(world), {
			tex = "VfxChunk",
			color = chips,
			size = { { 0, 0.08 }, { 1, 0.05 } },
			life = { 0.4, 0.7 },
			speed = { 3, 6 },
			spread = 70,
			dir = Enum.NormalId.Top,
			accel = Vector3.new(0, -40, 0),
			rot = { 0, 360 },
			spin = { -400, 400 },
			lit = 1,
		}, math.floor(4 + 8 * hard))
	end
	Vfx.Screen.shake(0.25 + 0.55 * hard, 0.18 + 0.12 * hard)
end

-- A glint off steel or glass at `at` (scene space): a star and a long thin streak.
local function glint(at: Vector3, ctx: any, size: number?)
	local s = size or 1
	Vfx.Emit.burst(CFrame.new(ctx:world(at)), {
		{
			{
				tex = "VfxStreak",
				color = STEEL,
				size = { { 0, 0.05 }, { 0.4, 1.4 * s }, { 1, 0.1 } },
				squash = 0.08,
				alpha = { { 0, 0.1 }, { 1, 1 } },
				life = 0.35,
				light = 1,
				rot = { 40, 50 },
				z = 2,
			},
			1,
		},
		{
			{
				tex = "VfxFlare",
				color = STEEL,
				size = { { 0, 0.05 }, { 0.4, 0.5 * s }, { 1, 0.05 } },
				alpha = { { 0, 0 }, { 1, 1 } },
				life = 0.35,
				light = 1,
				z = 2,
			},
			1,
		},
	})
end

local function sound(ctx: any, t: number, name: string, volume: number?)
	ctx:at(t, function()
		Sfx.play(name, { volume = volume })
	end)
end

-- The lamp's light jumping with a hit, back in a moment.
local function kick(ctx: any, light: SpotLight, t: number, amount: number)
	local base = light.Brightness
	ctx:at(t, function()
		light.Brightness = base * (1 + amount)
		ctx:tween(light, 0.25, { Brightness = base })
	end)
end

-- The verdicts ---------------------------------------------------------------------------------------------------------

-- Final Gavel: the gavel lies along x, its head over the sound block; it turns about its grip (off to the left, out of
-- the frame) and strikes at STRIKE1 and STRIKE2.
local function gavel(ctx: any)
	local key = office(ctx)
	local strike = Vector3.new(1.3, TOP + 0.28, 0.3) -- the block's top
	model(ctx, "SoundBlock", CFrame.new(1.3, TOP, 0.3), 1.35)
	local piece = model(ctx, "Gavel", CFrame.new(strike + Vector3.new(0, 1, 0)), 1.93)
	local STRIKE1, STRIKE2 = 0.62, 1.62
	-- (the gavel's own frame: head centre 0.725 up its handle, the head's face 0.475 off it, the grip 0.85 down)
	local grip = strike + Vector3.new(-1.575, 0.475, 0)
	local lie = CFrame.Angles(0, 0, math.rad(-90))
	local function angleAt(t: number): (number, number)
		-- (degrees up from the strike, and how far the hand has lifted the grip)
		if t < STRIKE1 - 0.17 then
			return 48 + 6 * along(t, 0, STRIKE1 - 0.17), 0.3
		elseif t < STRIKE1 then
			return 54 * (1 - along(t, STRIKE1 - 0.17, STRIKE1, "in")), 0.3 * (1 - along(t, STRIKE1 - 0.17, STRIKE1))
		elseif t < STRIKE1 + 0.12 then
			return 7 * math.sin(math.pi * (t - STRIKE1) / 0.12), 0
		elseif t < STRIKE2 - 0.16 then
			local u = along(t, STRIKE1 + 0.2, STRIKE2 - 0.25, "out")
			return 62 * u, 0.35 * u
		elseif t < STRIKE2 then
			return 62 * (1 - along(t, STRIKE2 - 0.16, STRIKE2, "in")), 0.35 * (1 - along(t, STRIKE2 - 0.16, STRIKE2))
		elseif t < STRIKE2 + 0.14 then
			return 9 * math.sin(math.pi * (t - STRIKE2) / 0.14), 0
		end
		return 0, 0
	end
	if piece then
		ctx:during(0, Verdicts.LENGTH, function(t)
			local degrees, lift = angleAt(t)
			local at = CFrame.new(grip + Vector3.new(0, lift, 0))
				* CFrame.Angles(0, 0, math.rad(degrees))
				* CFrame.new(0.85, 0, 0)
				* lie
			piece:PivotTo(ctx.origin * at)
		end)
	end
	for _, s in ipairs({ { STRIKE1, 0.7 }, { STRIKE2, 1 } }) do
		ctx:at(s[1], function()
			hit(ctx, strike + Vector3.new(0.05, 0.02, -0.1), s[2], nil, Color3.fromRGB(96, 62, 38))
			Sfx.play("gavel", { volume = 0.7 + 0.3 * s[2] })
		end)
		kick(ctx, key, s[1], 0.6 * s[2])
	end
	-- 1: low on the block, the head coming down into the frame from above
	ctx:shot(0, strike + Vector3.new(1.2, 0.45, -3.6), strike + Vector3.new(-0.2, 0.45, 0), 30, {
		eye = strike + Vector3.new(1.05, 0.4, -3.1),
	})
	-- 2: from the block's far side along the desk, the gavel rising and coming down again, the file behind it soft
	ctx:shot(1.08, strike + Vector3.new(2.3, 0.75, -1.3), strike + Vector3.new(-0.5, 0.3, 0.2), 34, {
		eye = strike + Vector3.new(2.05, 0.62, -1.1),
	})
	-- 3: wide on the desk under its lamp, the gavel at rest on the block, the name in the file, dust settling
	ctx:shot(2.15, Vector3.new(-0.2, TOP + 3.1, -4.6), Vector3.new(-0.1, TOP + 0.2, 0.4), 38, {
		eye = Vector3.new(-0.2, TOP + 2.7, -3.9),
	})
	ctx:focus(0, 1.08, 2.4, 1)
	ctx:focus(1.08, 2.15, 2.6, 1.2)
end

-- Iron Cuffs: dropped from above onto the case file, a spark and a bounce where steel hits paper over wood, they slide
-- to a stop across the name; a glint runs along them.
local function cuffs(ctx: any)
	local fileAt = CFrame.new(-0.2, TOP + 0.03, 0.1) * CFrame.Angles(0, math.rad(-4), 0)
	local key = office(ctx, fileAt)
	local rest = Vector3.new(-0.55, TOP + 0.2, 0.05)
	local LAND = 0.5
	local piece = model(ctx, "Handcuffs", CFrame.new(rest), 1.9)
	if piece then
		local flat = CFrame.Angles(0, math.rad(18), 0)
		ctx:during(0, Verdicts.LENGTH, function(t)
			local pos: Vector3
			local tilt = 0
			if t < LAND then
				-- falling, turning a little as they come
				local u = along(t, 0, LAND, "in")
				pos = rest + Vector3.new(0.25 * (1 - u), 3.2 * (1 - u), -0.1 * (1 - u))
				tilt = 35 * (1 - u)
			elseif t < LAND + 0.22 then
				-- the bounce
				local u = (t - LAND) / 0.22
				pos = rest + Vector3.new(-0.12 * u, 0.22 * math.sin(math.pi * u), 0)
				tilt = -8 * math.sin(math.pi * u)
			else
				-- a short slide to a stop
				local u = along(t, LAND + 0.22, LAND + 0.6, "out")
				pos = rest + Vector3.new(-0.12 - 0.18 * u, 0, 0.02 * u)
			end
			piece:PivotTo(ctx.origin * CFrame.new(pos) * flat * CFrame.Angles(math.rad(tilt), 0, math.rad(tilt * 0.4)))
		end)
	end
	ctx:at(LAND, function()
		hit(ctx, rest + Vector3.new(0.1, -0.1, 0), 0.75, STEEL)
		Vfx.Emit.burst(CFrame.new(ctx:world(rest)), {
			tex = "VfxStreak",
			color = SPARK,
			size = { { 0, 0.04 }, { 1, 0.01 } },
			squash = -4,
			face = "along",
			life = { 0.2, 0.4 },
			speed = { 6, 10 },
			spread = 75,
			dir = Enum.NormalId.Top,
			accel = Vector3.new(0, -30, 0),
			light = 1,
		}, 16)
		Sfx.play("handcuffs", { volume = 1 })
	end)
	kick(ctx, key, LAND, 0.5)
	sound(ctx, LAND + 0.22, "handcuffs", 0.4)
	ctx:at(1.55, function()
		glint(rest + Vector3.new(-0.5, 0.15, -0.1), ctx, 0.8)
	end)
	ctx:at(1.85, function()
		glint(rest + Vector3.new(0.05, 0.12, -0.2), ctx, 1)
	end)
	-- 1: high over the file, looking down: the cuffs fall into the frame and hit
	ctx:shot(0, rest + Vector3.new(0.3, 4.2, -2.2), rest + Vector3.new(0, 0, 0.1), 38, {
		eye = rest + Vector3.new(0.25, 3.8, -1.9),
	})
	-- 2: down at the desk's level, the steel close, the name behind it coming into focus
	ctx:shot(1.2, rest + Vector3.new(-1.9, 0.25, -1.4), rest + Vector3.new(0.3, 0.05, 0.4), 30, {
		eye = rest + Vector3.new(-1.6, 0.22, -1.15),
	})
	-- 3: the desk under its lamp
	ctx:shot(2.3, Vector3.new(0.6, TOP + 2.8, -4.2), Vector3.new(-0.4, TOP + 0.2, 0.3), 36, {
		eye = Vector3.new(0.5, TOP + 2.5, -3.6),
	})
	ctx:focus(1.2, 2.3, 1.9, 0.9)
end

-- Endgame: the board on the desk, the black king alone; the ivory queen slides in beside him (mate), he rocks, topples
-- in slow time and cracks where he lands, a red line glowing in the crack.
local function checkmate(ctx: any)
	local key = office(ctx, CFrame.new(-3.0, TOP + 0.03, -0.2) * CFrame.Angles(0, math.rad(14), 0))
	local board = Vector3.new(0.6, TOP, 0.5)
	model(ctx, "ChessBoard", CFrame.new(board), 3.4)
	local square = 3.4 * 0.38 / 3.4 -- (a square of the board)
	local top = board + Vector3.new(0, 0.17, 0)
	local kingAt = top + Vector3.new(0.5 * square, 0, 1.5 * square)
	local queenTo = top + Vector3.new(-0.5 * square, 0, 0.5 * square)
	local queenFrom = top + Vector3.new(-3.5 * square, 0, 3.5 * square)
	local king = model(ctx, "ChessKing", CFrame.new(kingAt), 1.4)
	local queen = model(ctx, "ChessQueen", CFrame.new(queenFrom), 1.25)
	local SLIDE0, SLIDE1, TIP, LAND = 0.15, 0.6, 1.1, 1.7
	if queen then
		ctx:during(0, Verdicts.LENGTH, function(t)
			local u = along(t, SLIDE0, SLIDE1, "out")
			queen:PivotTo(ctx.origin * CFrame.new(queenFrom:Lerp(queenTo, u)))
		end)
	end
	-- the king turns about the edge of his base away from the queen: a rock, then the fall
	local away = (kingAt - queenTo) * Vector3.new(1, 0, 1)
	local dir = if away.Magnitude > 0 then away.Unit else Vector3.new(1, 0, 0)
	local axis = Vector3.new(0, 1, 0):Cross(dir).Unit
	local edge = kingAt + dir * 0.28
	local function kingAngle(t: number): number
		if t < SLIDE1 + 0.05 then
			return 0
		elseif t < TIP then
			return 7 * math.sin(math.pi * (t - SLIDE1 - 0.05) / (TIP - SLIDE1 - 0.05))
		elseif t < LAND then
			return 90 * along(t, TIP, LAND, "in")
		elseif t < LAND + 0.18 then
			return 90 - 8 * math.sin(math.pi * (t - LAND) / 0.18)
		end
		return 90
	end
	if king then
		ctx:during(0, Verdicts.LENGTH, function(t)
			local turn = CFrame.fromAxisAngle(axis, math.rad(kingAngle(t)))
			local at = CFrame.new(edge) * turn * CFrame.new(kingAt - edge)
			king:PivotTo(ctx.origin * at)
		end)
	end
	-- the crack: a thin red glowing line along the fallen king, from his base up
	local crack = ctx:part({
		size = Vector3.new(0.025, 0.04, 0.02),
		color = Color3.fromRGB(255, 40, 50),
		glow = true,
		alpha = 1,
	})
	ctx:at(LAND + 0.02, function()
		local length = 1.1
		crack.Size = Vector3.new(0.03, 0.03, length)
		crack.CFrame = ctx.origin
			* CFrame.lookAt(edge + dir * 0.02 + Vector3.new(0, 0.33, 0), edge + dir * length)
			* CFrame.new(0, 0, -length / 2)
		crack.Transparency = 0
		ctx:tween(crack, 1.2, { Transparency = 0.35 })
		hit(
			ctx,
			edge + dir * 0.6 + Vector3.new(0, 0.25, 0),
			0.8,
			Color3.fromRGB(255, 70, 70),
			Color3.fromRGB(30, 22, 18)
		)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 50, 60)
		glow.Range = 3
		glow.Brightness = 2
		glow.Parent = crack
		ctx:tween(glow, 1.4, { Brightness = 0.6 })
		Sfx.play("winShatter", { volume = 0.6 })
		Sfx.play("bookImpact", { volume = 0.5 })
	end)
	kick(ctx, key, LAND + 0.02, 0.4)
	sound(ctx, SLIDE1, "winPieceFlick", 0.8)
	-- 1: low at the board, the king big in the frame, the queen sliding in from the dark
	ctx:shot(0, kingAt + Vector3.new(0.9, 0.55, -2.4), kingAt + Vector3.new(-0.4, 0.6, 0), 30, {
		eye = kingAt + Vector3.new(0.75, 0.5, -2.05),
	})
	-- 2: the fall, side on, the board's squares running away
	ctx:shot(1.0, edge + Vector3.new(-0.4, 0.45, -2.6), edge + Vector3.new(0.1, 0.35, 0), 32, {
		eye = edge + Vector3.new(-0.3, 0.38, -2.25),
	})
	-- 3: over the board: the king down and cracked, the queen standing over him
	ctx:shot(2.2, board + Vector3.new(-0.6, 4.2, -2.8), board + Vector3.new(0, 0, 0.6), 36, {
		eye = board + Vector3.new(-0.5, 3.7, -2.3),
	})
	ctx:focus(0, 1.0, 2.4, 1)
	ctx:focus(1.0, 2.2, 2.6, 1)
end

-- Sweet Justice: a tower of sugar cubes beside the teacup; the top one is flicked off, tumbles into the tea with a
-- splash, and the tower comes down after it in a puff of sugar.
local function sugar(ctx: any)
	local key = office(ctx)
	local base = Vector3.new(0.9, TOP, 0.2)
	local cupAt = Vector3.new(2.2, TOP, 0.6)
	model(ctx, "Teacup", CFrame.new(cupAt) * CFrame.Angles(0, math.rad(-30), 0), 1.0)
	local CUBE = 0.36
	local FLICK, SPLASH, FALL = 0.45, 1.25, 1.95
	local cubes = {}
	for k = 1, 7 do
		local at = base + Vector3.new(0, (k - 1) * CUBE, 0)
		local cube = model(ctx, "SugarCube", CFrame.new(at) * CFrame.Angles(0, math.rad((k * 37) % 11 - 5), 0), CUBE)
		if not cube then
			local p = ctx:part({
				size = Vector3.new(CUBE, CUBE, CUBE),
				at = at + Vector3.new(0, CUBE / 2, 0),
				color = Color3.fromRGB(244, 242, 236),
				material = Enum.Material.Sand,
			})
			cube = Instance.new("Model")
			p.Parent = cube
			cube.PrimaryPart = p
			cube.Parent = ctx.stage.folder
			cube:PivotTo(ctx.origin * CFrame.new(at))
		end
		table.insert(cubes, cube)
	end
	local topCube = cubes[#cubes]
	local topAt = base + Vector3.new(0, 6 * CUBE, 0)
	local into = cupAt + Vector3.new(0, 0.12, 0)
	ctx:during(0, Verdicts.LENGTH, function(t)
		if t < FLICK then
			return
		end
		-- off along a high arc into the cup, tumbling
		local u = clamp01((t - FLICK) / (SPLASH - FLICK))
		local p = topAt:Lerp(into, u) + Vector3.new(0, 1.1 * math.sin(math.pi * u), 0)
		if t > SPLASH then
			p = into - Vector3.new(0, 0.15 * clamp01((t - SPLASH) / 0.3), 0)
		end
		topCube:PivotTo(ctx.origin * CFrame.new(p) * CFrame.Angles(u * 9, u * 4, u * 6))
	end)
	-- the tower falls the way the flick went: each cube tips and drops, the lower ones last
	for k = #cubes - 1, 1, -1 do
		local cube = cubes[k]
		local start = FALL + (#cubes - 1 - k) * 0.05
		local from = base + Vector3.new(0, (k - 1) * CUBE, 0)
		local rng = Random.new(k * 13)
		local to = base + Vector3.new(0.35 + (k - 1) * 0.3 + rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.4, 0.4))
		local spin = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-3, 3), rng:NextNumber(-2, 2))
		ctx:during(start, Verdicts.LENGTH, function(t)
			local u = clamp01((t - start) / 0.4)
			local fall = u * u
			local p = from:Lerp(to, u) * Vector3.new(1, 0, 1) + Vector3.new(0, from.Y + (TOP - from.Y) * fall, 0)
			cube:PivotTo(ctx.origin * CFrame.new(p) * CFrame.Angles(spin.X * u, spin.Y * u, spin.Z * u))
		end)
	end
	ctx:at(FLICK, function()
		Sfx.play("winPieceFlick", { volume = 0.7 })
		Vfx.Emit.burst(CFrame.new(ctx:world(topAt + Vector3.new(0, CUBE / 2, 0))), {
			tex = "VfxDust",
			color = Color3.fromRGB(250, 248, 244),
			size = { { 0, 0.05 }, { 1, 0.25 } },
			alpha = { { 0, 0.3 }, { 1, 1 } },
			life = { 0.5, 0.8 },
			speed = { 0.4, 1 },
			spread = 60,
			lit = 1,
		}, 8)
	end)
	ctx:at(SPLASH, function()
		local world = CFrame.new(ctx:world(into + Vector3.new(0, 0.05, 0)))
		Vfx.Emit.burst(world, {
			{
				{
					tex = "VfxDust",
					color = Color3.fromRGB(150, 96, 52),
					size = { { 0, 0.04 }, { 1, 0.02 } },
					life = { 0.35, 0.55 },
					speed = { 2.5, 4.5 },
					spread = 30,
					dir = Enum.NormalId.Top,
					accel = Vector3.new(0, -30, 0),
					lit = 1,
				},
				14,
			},
			{
				{
					tex = "VfxRing",
					color = Color3.fromRGB(196, 150, 110),
					size = { { 0, 0.05 }, { 1, 0.45 } },
					alpha = { { 0, 0.3 }, { 1, 1 } },
					life = 0.5,
					face = "flat",
					speed = 0.01,
					dir = Enum.NormalId.Top,
					lit = 1,
				},
				1,
			},
		})
		Sfx.play("winPieceFlick", { volume = 0.4 })
	end)
	ctx:at(FALL + 0.35, function()
		hit(ctx, base + Vector3.new(0.9, 0.1, 0), 0.5, Color3.fromRGB(255, 255, 255))
		Sfx.play("bookImpact", { volume = 0.35 })
	end)
	kick(ctx, key, SPLASH, 0.25)
	-- 1: the tower's top, close, the flick
	ctx:shot(0, topAt + Vector3.new(-0.7, 0.3, -2.0), topAt + Vector3.new(0.35, -0.1, 0.1), 30, {
		eye = topAt + Vector3.new(-0.6, 0.25, -1.75),
	})
	-- 2: the cup, the cube dropping in
	ctx:shot(0.95, into + Vector3.new(-0.6, 0.9, -1.8), into + Vector3.new(0, 0, 0.05), 32)
	-- 3: wide: the tower coming down, sugar over the blotter
	ctx:shot(1.75, base + Vector3.new(0.6, 2.1, -3.6), base + Vector3.new(0.5, 0.8, 0.2), 34, {
		eye = base + Vector3.new(0.5, 1.8, -3.0),
	})
	ctx:focus(0, 0.95, 2.1, 0.9)
	ctx:focus(0.95, 1.75, 1.9, 0.8)
end

-- Guilty Stamp: lifted wet off its pad, slammed down on the file: GUILTY in red over the name.
local function stamp(ctx: any)
	local fileAt = CFrame.new(-0.4, TOP + 0.03, 0.1) * CFrame.Angles(0, math.rad(3), 0)
	local key = office(ctx, fileAt)
	local padAt = Vector3.new(2.1, TOP, 0.9)
	model(ctx, "InkPad", CFrame.new(padAt) * CFrame.Angles(0, math.rad(-12), 0), 1.0)
	local onFile = (fileAt * CFrame.new(-0.58, 0.04, -0.15)).Position
	local onPad = padAt + Vector3.new(0, 0.11, -0.05)
	local LIFT, SLAM, UP = 0.15, 1.2, 1.55
	local piece = model(ctx, "RubberStamp", CFrame.new(onPad), 0.95)
	local function stampAt(t: number): (Vector3, number)
		if t < LIFT then
			return onPad, 0
		elseif t < 0.75 then
			local u = along(t, LIFT, 0.75, "out")
			return onPad + Vector3.new(0, 1.4 * u, 0), -10 * u
		elseif t < SLAM - 0.12 then
			local u = along(t, 0.75, SLAM - 0.12)
			local high = onFile + Vector3.new(0, 1.6, 0)
			return (onPad + Vector3.new(0, 1.4, 0)):Lerp(high, u), -10 + 10 * u
		elseif t < SLAM then
			local u = along(t, SLAM - 0.12, SLAM, "in")
			return (onFile + Vector3.new(0, 1.6, 0)):Lerp(onFile, u), 0
		elseif t < UP then
			return onFile, 0
		end
		local u = along(t, UP, UP + 0.5, "out")
		return onFile + Vector3.new(0.9 * u, 1.3 * u, 0.4 * u), 12 * u
	end
	if piece then
		ctx:during(0, Verdicts.LENGTH, function(t)
			local p, tilt = stampAt(t)
			piece:PivotTo(ctx.origin * CFrame.new(p) * CFrame.Angles(0, math.rad(-6), math.rad(tilt)))
		end)
	end
	-- the print: GUILTY in a red box, a little crooked and patchy, on the sheet with the name
	local print = ctx:part({
		size = Vector3.new(0.5, 0.002, 0.84),
		color = PAPER,
		alpha = 1,
		cast = false,
	})
	print.CFrame = ctx.origin
		* CFrame.new(onFile + Vector3.new(0, 0.026, 0))
		* CFrame.Angles(0, math.rad(-6), 0)
		* CFrame.Angles(0, math.rad(90), 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 260
	gui.LightInfluence = 1
	gui.Enabled = false
	gui.Parent = print
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK_RED
	stroke.Thickness = 9
	stroke.Transparency = 0.12
	stroke.Parent = box
	local word = Instance.new("TextLabel")
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromScale(0.92, 0.8)
	word.Position = UDim2.fromScale(0.04, 0.1)
	word.Font = Enum.Font.SpecialElite
	word.TextScaled = true
	word.TextColor3 = INK_RED
	word.TextTransparency = 0.08
	word.Text = "GUILTY"
	word.Parent = box
	ctx:at(SLAM, function()
		gui.Enabled = true
		hit(ctx, onFile + Vector3.new(0, 0.05, 0), 0.9, Color3.fromRGB(255, 240, 220))
		Vfx.Emit.burst(CFrame.new(ctx:world(onFile + Vector3.new(0, 0.04, 0))), {
			tex = "VfxDust",
			color = INK_RED,
			size = { { 0, 0.05 }, { 1, 0.025 } },
			life = { 0.25, 0.4 },
			speed = { 2, 4 },
			spread = 85,
			dir = Enum.NormalId.Top,
			accel = Vector3.new(0, -30, 0),
			lit = 1,
		}, 12)
		Sfx.play("stamp", { volume = 1 })
		Sfx.play("winStamp", { volume = 0.5 })
	end)
	kick(ctx, key, SLAM, 0.7)
	-- 1: the pad, close and low: the stamp lifted off it wet
	ctx:shot(0, onPad + Vector3.new(-0.9, 0.5, -1.9), onPad + Vector3.new(0, 0.5, 0), 30, {
		eye = onPad + Vector3.new(-0.8, 0.7, -1.7),
		look = onPad + Vector3.new(0, 0.9, 0),
	})
	-- 2: straight down on the file: the stamp comes down at the lens and slams
	ctx:shot(0.8, onFile + Vector3.new(0.05, 3.3, -0.55), onFile, 40, {
		eye = onFile + Vector3.new(0.05, 3.0, -0.5),
	})
	-- 3: pushing in on GUILTY over the name
	ctx:shot(1.95, onFile + Vector3.new(-0.2, 1.6, -1.8), onFile + Vector3.new(0, 0, 0.1), 32, {
		eye = onFile + Vector3.new(-0.15, 1.15, -1.25),
	})
	ctx:focus(1.95, Verdicts.LENGTH, 1.7, 0.7)
end

-- Interrogation Lamp: no desk; one lamp on a cord swings in over an empty chair, flickers and holds, everything else
-- black, the chair's shadow swinging under it, dust in its cone.
local function lamp(ctx: any)
	SceneDeaths.box(
		ctx,
		Vector3.new(30, 16, 30),
		Vector3.new(0, 0, 0),
		Color3.fromRGB(10, 10, 11),
		Enum.Material.Concrete
	)
	ctx:part({
		size = Vector3.new(30, 0.05, 30),
		at = Vector3.new(0, 0.025, 0),
		color = Color3.fromRGB(44, 42, 40),
		material = Enum.Material.Concrete,
	})
	local chairAt = Vector3.new(0, 0, 0)
	if not model(ctx, "Chair", CFrame.new(chairAt) * CFrame.Angles(0, math.rad(180 + 18), 0), 3.9) then
		ctx:part({ size = Vector3.new(1.8, 0.2, 1.8), at = Vector3.new(0, 1.7, 0), color = Color3.fromRGB(60, 40, 30) })
	end
	-- the lamp: a cord from the dark above, a conical steel shade, a bulb in it
	local pivot = Vector3.new(0, 15, 0)
	local CORD = 8.4
	local cord = ctx:part({
		size = Vector3.new(0.06, CORD, 0.06),
		color = Color3.fromRGB(20, 20, 22),
		material = Enum.Material.Rubber,
		shape = "Cylinder",
	})
	local shade = ctx:part({
		size = Vector3.new(0.9, 1.5, 1.5),
		color = Color3.fromRGB(40, 44, 40),
		material = Enum.Material.Metal,
		shape = "Cylinder",
	})
	local bulb = ctx:part({
		size = Vector3.new(0.45, 0.45, 0.45),
		color = Color3.fromRGB(255, 236, 196),
		glow = true,
		shape = "Ball",
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = Color3.fromRGB(255, 226, 180)
	light.Range = 22
	light.Angle = 62
	light.Brightness = 0
	light.Shadows = not Governor.low("shadows")
	light.Parent = bulb
	local fill = Instance.new("PointLight")
	fill.Color = Color3.fromRGB(255, 220, 170)
	fill.Range = 6
	fill.Brightness = 0
	fill.Parent = bulb
	local ON = 0.55
	local function swing(t: number): number
		-- degrees off the vertical: in from the left, swinging smaller and smaller
		local damp = math.exp(-0.55 * t)
		return -34 * damp * math.cos(2.2 * t)
	end
	ctx:during(0, Verdicts.LENGTH, function(t)
		local a = math.rad(swing(t))
		local hang = CFrame.new(pivot) * CFrame.Angles(0, 0, a)
		cord.CFrame = ctx.origin * hang * CFrame.new(0, -CORD / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		local low = hang * CFrame.new(0, -CORD - 0.6, 0)
		shade.CFrame = ctx.origin * low * CFrame.Angles(0, 0, math.rad(90))
		bulb.CFrame = ctx.origin * low * CFrame.new(0, -0.55, 0)
	end)
	-- it flickers on as it comes in, then holds
	local flick = { { 0.2, 1.4 }, { 0.27, 0 }, { 0.38, 2.2 }, { 0.44, 0.3 }, { ON, 3.4 } }
	for _, f in ipairs(flick) do
		ctx:at(f[1], function()
			light.Brightness = f[2]
			fill.Brightness = f[2] * 0.3
			bulb.Transparency = if f[2] > 0.5 then 0 else 0.6
		end)
	end
	sound(ctx, 0.2, "hauntFlicker", 0.6)
	sound(ctx, ON, "hauntFlicker", 0.35)
	-- dust turning in the cone under the shade
	SceneDeaths.emit(ctx, Vector3.new(0, 3.5, 0), Vector3.new(4.5, 5, 4.5), {
		tex = "VfxDust",
		color = DUST,
		size = { { 0, 0.03 }, { 1, 0.05 } },
		alpha = { { 0, 1 }, { 0.3, 0.45 }, { 0.7, 0.5 }, { 1, 1 } },
		life = { 2.5, 4 },
		speed = { 0.05, 0.12 },
		spread = 180,
		lit = 1,
		rate = 60,
	}, ON)
	-- 1: the dark room, low and wide: the lamp swings in from the left and flickers on over the chair
	ctx:shot(0, Vector3.new(0, 2.6, -11), Vector3.new(0, 4.2, 0), 40, {
		eye = Vector3.new(0, 2.6, -9.6),
	})
	-- 2: from high beside the cord, down the cone of light onto the chair, its shadow swinging on the floor
	ctx:shot(1.35, Vector3.new(3.4, 9.5, -3.4), Vector3.new(0, 0.8, 0), 44, {
		eye = Vector3.new(2.8, 9.0, -2.8),
	})
	-- 3: behind the chair, low, into the lamp: the chair back black against its glare
	ctx:shot(2.4, Vector3.new(0.6, 1.6, 4.2), Vector3.new(0, 5.4, -1), 46, {
		eye = Vector3.new(0.5, 1.5, 3.7),
	})
end

local SCENES: { [string]: (any) -> () } = {
	gavel = gavel,
	cuffs = cuffs,
	checkmate = checkmate,
	sugar = sugar,
	stamp = stamp,
	lamp = lamp,
}

for style, build in pairs(SCENES) do
	SceneDeaths.register("verdict:" .. style, {
		length = Verdicts.LENGTH,
		build = build,
		origin = ORIGIN,
		look = "verdict",
		-- (a cut into the middle of a cutscene: only a blink of black while the engine lights the set)
		fromBlack = { 0.08, 0.18 },
	})
end

function Verdicts.has(style: string?): boolean
	return style ~= nil and SCENES[style] ~= nil
end

-- Plays a verdict full screen (options as SceneDeaths.play's: `named` the name on the case file, `at` the server time
-- its first frame stands at, `wait`). Returns a function that stops it.
function Verdicts.play(style: string?, options: { [string]: any }?): () -> ()
	if not Verdicts.has(style) then
		return function() end
	end
	return SceneDeaths.play("verdict:" .. (style :: string), options :: any)
end

return Verdicts
