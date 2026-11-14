-- Let's dance! (art/refs/deaths/sam.md, 14 s): two characters on dusk desert hills (brown-gold sky, boulders): the
-- victim (Sam's part, a red sword) and the killer (white-haired, silver cyborg armour, a long blade leaving RED trails).
-- It opens on the two blades locked, close (2026-11-14, the user: "clashing swords in a close up shot", not trading
-- blows); the lock is thrown open and two cuts land (the COMBAT LOG counts them: "2 HITS", shown only until the kanji
-- and never after); the huge white brush 斬 painted on;
-- BLADE MODE: the whole picture cool BLUE (not inverted), the 斬 at the right, the lock-on box on the victim's chest and
-- the green cut line; the cut (sparks); the stagger; the overhead swing; grabbed, "Play time's over.", run through,
-- red cuts glowing on the chest; the blade out; staggering away; both standing; black. A small HUD like the game's.

local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local SceneDeaths = require(script.Parent)
local Splat = require(script.Parent.Splat)

-- the white brush 斬, drawn stroke by stroke (art/scripts/ui/zan_kanji.py)
local ZAN = "rbxassetid://96312430448376"

local RED = Color3.fromRGB(255, 36, 40)
local SPARK = Color3.fromRGB(255, 150, 40)
local DUSK = Color3.fromRGB(214, 170, 110)

-- The set of parts (before it was modelled): only when the Scenes import is missing.
local function standIn(ctx)
	-- the hills at dusk
	ctx:part({
		size = Vector3.new(220, 1, 220),
		at = Vector3.new(0, -0.5, 0),
		color = Color3.fromRGB(92, 74, 52),
		material = Enum.Material.Ground,
	})
	for k = 1, 9 do
		local a = math.rad(k * 40)
		ctx:part({
			size = Vector3.new(60, 18 + (k % 3) * 8, 40),
			at = Vector3.new(math.cos(a) * 90, 0, math.sin(a) * 90 - 20),
			rot = Vector3.new(0, k * 23, 0),
			color = Color3.fromRGB(70, 56, 40),
			material = Enum.Material.Ground,
			shape = "Ball",
		})
	end
	for _, b in ipairs({
		{ Vector3.new(-9, 1.6, 6), 4 },
		{ Vector3.new(7, 1.2, -12), 3 },
		{ Vector3.new(-14, 2.2, -10), 5 },
	}) do
		ctx:part({
			size = Vector3.new(b[2] * 1.4, b[2], b[2] * 1.2),
			at = b[1],
			rot = Vector3.new(10, b[2] * 20, 6),
			color = Color3.fromRGB(150, 134, 112),
			material = Enum.Material.Rock,
		})
	end
	-- the sky: a wall of dusk round everything, gold low, brown-grey high
	local sky = ctx:part({ size = Vector3.new(400, 160, 1), at = Vector3.new(0, 60, -150), color = DUSK, cast = false })
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.LightInfluence = 0
	g.Parent = sky
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 80, 74)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(176, 136, 90)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(236, 196, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 90, 66)),
	})
	grad.Parent = f
	for _, side in ipairs({
		{ Vector3.new(1, 160, 400), Vector3.new(-150, 60, 0) },
		{ Vector3.new(1, 160, 400), Vector3.new(150, 60, 0) },
		{ Vector3.new(400, 160, 1), Vector3.new(0, 60, 150) },
	}) do
		local p = ctx:part({ size = side[1], at = side[2], color = Color3.fromRGB(150, 118, 84), cast = false })
		local copy = g:Clone()
		copy.Face = if side[2].X < 0
			then Enum.NormalId.Right
			elseif side[2].X > 0 then Enum.NormalId.Left
			else Enum.NormalId.Front
		copy.Parent = p
	end
	ctx:part({
		size = Vector3.new(400, 1, 400),
		at = Vector3.new(0, 140, 0),
		color = Color3.fromRGB(86, 78, 72),
		cast = false,
	})
	ctx:light(Vector3.new(-30, 20, -60), Color3.fromRGB(255, 200, 140), 120, 2.4, true)
	ctx:light(Vector3.new(6, 10, 10), Color3.fromRGB(200, 180, 160), 30, 0.8)
end

-- The scene's first second belongs to the blade lock (2026-11-14): every scene opens on black for its first three
-- quarters of a second (SceneDeaths.play: the engine lights a new place late), which hid the lock, so everything
-- the sheet times is played OPEN seconds later, and the lock is on the screen from the fade up until then. The
-- scene below is written in the sheet's own times through `ctx`, which adds OPEN; times before 0 are the lock's.
local OPEN = 1.0

local function shifted(real)
	local ctx = setmetatable({}, {
		__index = function(_, key)
			local value = real[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(real, ...)
				end
			end
			return value
		end,
	})
	function ctx:now()
		return real:now() - OPEN
	end
	function ctx:at(t, fn)
		real:at(t + OPEN, fn)
	end
	function ctx:atNow(t, fn)
		real:atNow(t + OPEN, fn)
	end
	function ctx:during(t0, t1, fn)
		real:during(t0 + OPEN, t1 + OPEN, function(t, dt)
			fn(t - OPEN, dt)
		end)
	end
	function ctx:shot(t, ...)
		real:shot(t + OPEN, ...)
	end
	function ctx:say(t, ...)
		real:say(t + OPEN, ...)
	end
	function ctx:grade(t0, t1, ...)
		real:grade(t0 + OPEN, if t1 then t1 + OPEN else nil, ...)
	end
	function ctx:actor(who, at, clip, from, ...)
		return real:actor(who, at, clip, (from or 0) + OPEN, ...)
	end
	return ctx
end

local function build(real)
	local ctx: any = shifted(real)
	if ctx:set() then
		-- (the desert, modelled: art/scripts/maps/venues/scenes/sam.py, under the dusk sun of its look; a warm
		-- bounce off the ground on the faces)
		ctx:light(Vector3.new(2, 2, -2.5), Color3.fromRGB(255, 200, 150), 10, 0.35)
	else
		standIn(ctx)
	end
	-- (2026-11-14, the user: "make the sky more dramatic": a storm front over the desert at dusk. Heavy cloud banks
	-- stand round the whole horizon, dark above and lit like coals from under by the low sun; dry lightning walks
	-- through them, never on a beat; the wind carries sparks and dust across the ground between the two of them. The
	-- look itself (LightingPresets.scenes.sam) is harder: a lower, redder sun, deeper shadows.)
	for i, bank in ipairs({
		{ Vector3.new(0, 78, 170), Vector3.new(420, 26, 60) },
		{ Vector3.new(0, 84, -180), Vector3.new(420, 30, 60) },
		{ Vector3.new(180, 74, 0), Vector3.new(60, 24, 420) },
		{ Vector3.new(-180, 88, 0), Vector3.new(60, 30, 420) },
		{ Vector3.new(0, 150, 0), Vector3.new(300, 10, 300) },
	}) do
		SceneDeaths.emit(ctx, bank[1], bank[2], {
			-- (the soft round glow, dark and unlit: a bank of them never shows an edge; the smoke sheet's cells did, that big)
			tex = "VfxGlow",
			color = if i == 5
				then Color3.fromRGB(40, 36, 42)
				else {
					{ 0, Color3.fromRGB(52, 44, 48) },
					{ 0.5, Color3.fromRGB(98, 60, 44) },
					{ 1, Color3.fromRGB(46, 40, 46) },
				},
			size = { { 0, 80 }, { 1, 120 } },
			alpha = { { 0, 1 }, { 0.12, 0.5 }, { 0.85, 0.56 }, { 1, 1 } },
			light = 0,
			life = { 16, 24 },
			speed = { 1.5, 4 },
			spread = 12,
			dir = Enum.NormalId.Right,
			rot = { 0, 360 },
			spin = { -3, 3 },
			lit = 0.25,
			rate = 5,
		}):Emit(44)
	end
	ctx:sunRays(0.14, 0.7)
	-- dry lightning in the banks: far off, soundless at first, its light on the picture a moment later
	for _, strike in ipairs({
		{ 0.62, Vector3.new(60, 0, 150) },
		{ 3.9, Vector3.new(-120, 0, 90) },
		{ 4.35, Vector3.new(-96, 0, 120) },
		{ 8.2, Vector3.new(150, 0, -40) },
		{ 10.1, Vector3.new(30, 0, 160) },
		{ 12.3, Vector3.new(-150, 0, -30) },
	}) do
		ctx:at(strike[1], function()
			local top = ctx:world(strike[2] + Vector3.new(math.random(-12, 12), 96, 0))
			local foot = ctx:world(strike[2] + Vector3.new(math.random(-20, 20), 22, math.random(-10, 10)))
			Vfx.Beams.bolt(top, foot, 0.22, {
				color = Color3.fromRGB(255, 226, 190),
				width = 1.6,
				bright = 3,
				light = 1,
				pieces = 11,
				jag = 9,
			})
			Vfx.Screen.flash(Color3.fromRGB(255, 214, 170), 0.22, 0.3)
		end)
	end
	-- the wind: sparks and grit carried across the ground, low dust rolling under them
	SceneDeaths.emit(ctx, Vector3.new(-26, 4.5, -2.5), Vector3.new(2, 9, 30), {
		tex = "Spark",
		color = { { 0, Color3.fromRGB(255, 232, 180) }, { 0.4, SPARK }, { 1, Color3.fromRGB(190, 50, 16) } },
		size = { { 0, 0.09 }, { 0.7, 0.06 }, { 1, 0 } },
		squash = -3.5,
		face = "along",
		life = { 1.6, 2.6 },
		speed = { 16, 30 },
		spread = 7,
		dir = Enum.NormalId.Right,
		accel = Vector3.new(0, 1.2, 0),
		light = 1,
		bright = 2.6,
		rate = 34,
	}):Emit(30)
	SceneDeaths.emit(ctx, Vector3.new(-22, 0.8, -2.5), Vector3.new(2, 1.4, 36), {
		tex = "VfxDust",
		color = Color3.fromRGB(190, 150, 110),
		size = { { 0, 2.4 }, { 1, 6 } },
		alpha = { { 0, 1 }, { 0.2, 0.72 }, { 1, 1 } },
		life = { 2.4, 3.6 },
		speed = { 10, 16 },
		spread = 6,
		dir = Enum.NormalId.Right,
		rot = { 0, 360 },
		spin = { -20, 20 },
		lit = 0.8,
		rate = 9,
	}):Emit(10)

	-- the two of them
	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -5)), "sceneSamVictim")
	-- (Raiden in his marketplace cyborg armour, white hair and visor: Cast)
	local killer = ctx:actor("cast:raiden", CFrame.lookAt(Vector3.new(0, 0, -5), Vector3.zero), "sceneSamKiller")
	if killer then
		-- the white hair swept back into its tail and the visor, the long blade with its red edge (modelled:
		-- props_scenes)
		ctx:wear(killer, "cyborgHead")
		local sword = ctx:wear(killer, "murasama")
		local arm = ctx:limb(killer, "Right Arm")
		if sword and arm then
			-- the red trail runs from the blade's hilt to its tip, on the arm that swings it
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position = arm.CFrame:PointToObjectSpace(ctx:pointOf(sword, "murasama", "tip"))
			a1.Position = arm.CFrame:PointToObjectSpace(ctx:pointOf(sword, "murasama", "base"))
			a0.Parent, a1.Parent = arm, arm
			-- (2026-11-14, the user: "make the sword afterimages when its swinged VFX better": it was one flat red ribbon.
			-- Now: the swing's sheet, drawn with the slash band and tapering as it ages, white-hot where the blade is
			-- and bleeding out through red to dark; a thin white edge riding the last third of the blade; and the
			-- blade's own ghosts, left hanging behind a fast swing and going out one after another.)
			local sheet = Instance.new("Trail")
			sheet.Attachment0, sheet.Attachment1 = a0, a1
			sheet.Texture = Vfx.Tex.id("VfxSlashBand")
			sheet.TextureMode = Enum.TextureMode.Stretch
			sheet.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 238, 226)),
				ColorSequenceKeypoint.new(0.12, Color3.fromRGB(255, 70, 60)),
				ColorSequenceKeypoint.new(0.6, RED),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 0, 12)),
			})
			sheet.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			sheet.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 0.8),
				NumberSequenceKeypoint.new(1, 0.3),
			})
			sheet.LightEmission = 1
			sheet.Brightness = 3
			sheet.Lifetime = 0.34
			sheet.MinLength = 0.03
			sheet.FaceCamera = true
			sheet.Parent = arm
			local e0, e1 = Instance.new("Attachment"), Instance.new("Attachment")
			e0.Position = a0.Position
			e1.Position = a0.Position:Lerp(a1.Position, 0.34)
			e0.Parent, e1.Parent = arm, arm
			local edge = Instance.new("Trail")
			edge.Attachment0, edge.Attachment1 = e0, e1
			edge.Color = ColorSequence.new(Color3.fromRGB(255, 246, 240))
			edge.Transparency = NumberSequence.new(0, 1)
			edge.WidthScale = NumberSequence.new(1, 0.1)
			edge.LightEmission = 1
			edge.Brightness = 4
			edge.Lifetime = 0.11
			edge.MinLength = 0.03
			edge.FaceCamera = true
			edge.Parent = arm
			-- the ghosts
			local lastTip: Vector3? = nil
			local lastGhost = 0
			ctx:during(-OPEN, 14, function(t, dt)
				local tip = ctx:pointOf(sword, "murasama", "tip")
				local speed = if lastTip and dt > 0 then (tip - lastTip).Magnitude / dt else 0
				lastTip = tip
				if speed < 34 or t - lastGhost < 0.032 then
					return
				end
				lastGhost = t
				local ghost = sword:Clone()
				for _, d in ipairs(ghost:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.Material = Enum.Material.Neon
						d.Color = RED
						d.Transparency = 0.45
						d.CastShadow = false
						if d:IsA("MeshPart") then
							d.TextureID = ""
						end
						ctx:tween(d, 0.2, { Transparency = 1 }, Enum.EasingStyle.Quad)
					elseif not d:IsA("SpecialMesh") then
						d:Destroy()
					end
				end
				ghost.Parent = ctx.stage.folder
				task.delay(0.22, function()
					ghost:Destroy()
				end)
			end)
		end
	end
	local victimBlade: Model? = nil
	if victim then
		victimBlade = ctx:wear(victim, "redBlade")
	end
	local killerBlade: Model? = if killer then killer:FindFirstChild("Costume_murasama") :: any else nil
	local function chest(): Vector3
		local t = victim and ctx:limb(victim, "Torso")
		return if t then ctx.origin:PointToObjectSpace(t.Position) else Vector3.new(0, 3.5, 0)
	end
	local function killerAt(): Vector3
		local t = killer and ctx:limb(killer, "Torso")
		return if t then ctx.origin:PointToObjectSpace(t.Position) else Vector3.new(0, 3.5, -5)
	end

	-- the HUD, drawn like the game's (2026-11-10, "more high quality"): top left the killer's name over a long thin
	-- health bar (an orange lead, white behind, on a dark backing with its number box), the cyan fuel-cell cells under
	-- it with their count; bottom right the victim's name and short bar with its number; the HITS plate right of
	-- centre, bumping on every cut
	local hud = ctx:layer(3)
	local ORANGE = Color3.fromRGB(240, 150, 40)
	local function text(
		parent: Instance,
		str: string,
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		font: Enum.Font?,
		align: Enum.TextXAlignment?
	)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(x, y)
		l.Size = UDim2.fromScale(w, h)
		l.Font = font or Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.5
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.Text = str
		l.Parent = parent
		return l
	end
	local function backing(x: number, y: number, w: number, h: number): Frame
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		b.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
		b.BackgroundTransparency = 0.25
		b.Position = UDim2.fromScale(x, y)
		b.Size = UDim2.fromScale(w, h)
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(150, 160, 170)
		edge.Thickness = 1
		edge.Transparency = 0.4
		edge.Parent = b
		b.Parent = hud
		return b
	end
	local function fill(parent: Frame, color: Color3, from: number, to: number): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.Position = UDim2.fromScale(from, 0.15)
		f.Size = UDim2.fromScale(to - from, 0.7)
		f.Parent = parent
		return f
	end
	-- (all of it below Roblox's own buttons at the top left, which covered the name and the bar: seen 2026-11-14)
	local DOWN = 0.085
	text(hud, "RAIDEN", 0.04, 0.045 + DOWN, 0.1, 0.022, Color3.fromRGB(230, 232, 236))
	local life = backing(0.04, 0.07 + DOWN, 0.27, 0.014)
	fill(life, Color3.fromRGB(236, 238, 240), 0.0, 1.0)
	fill(life, ORANGE, 0.0, 0.09)
	local lifeBox = backing(0.312, 0.064 + DOWN, 0.05, 0.026)
	text(lifeBox, "200", 0.06, 0.08, 0.6, 0.84, Color3.fromRGB(240, 240, 240), Enum.Font.GothamBlack)
	text(lifeBox, "/200", 0.6, 0.3, 0.4, 0.5, Color3.fromRGB(180, 184, 190))
	text(hud, "FC", 0.04, 0.092 + DOWN, 0.03, 0.016, Color3.fromRGB(120, 220, 240))
	local cells = backing(0.07, 0.093 + DOWN, 0.16, 0.012)
	for k = 1, 12 do
		fill(cells, Color3.fromRGB(80, 220, 240), (k - 1) / 12 + 0.006, k / 12 - 0.006)
	end
	text(hud, "1290/1296", 0.235, 0.09 + DOWN, 0.07, 0.016, Color3.fromRGB(160, 220, 236))
	-- the victim's bar, bottom right, in Metal Gear Rising's style (2026-11-12, the user: "how is it a finisher if hes
	-- 77 HP? it should be 0.1%"): the name in small capitals over a long thin bar, its right end cut at a slant, the
	-- life left white (a sliver), the life just lost red and draining away, the share as a number, pulsing red
	local FOE_RED = Color3.fromRGB(230, 40, 50)
	local foeName = text(hud, "SAM", 0.6, 0.83, 0.06, 0.02, Color3.fromRGB(230, 232, 236), Enum.Font.GothamBold)
	local foe = backing(0.6, 0.857, 0.3, 0.011)
	foe.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
	foe.BackgroundTransparency = 0.15
	local lost = fill(foe, FOE_RED, 0.0, 0.08)
	lost.Position = UDim2.fromScale(0, 0.15)
	local foeFill = Instance.new("Frame")
	foeFill.BorderSizePixel = 0
	foeFill.BackgroundColor3 = Color3.fromRGB(244, 246, 248)
	foeFill.Position = UDim2.fromScale(0, 0.15)
	foeFill.Size = UDim2.new(0.001, 2, 0.7, 0)
	foeFill.Parent = foe
	-- the slanted end and a tick every quarter, as the game's bar
	local cap = Instance.new("Frame")
	cap.BorderSizePixel = 0
	cap.BackgroundColor3 = Color3.fromRGB(150, 160, 170)
	cap.AnchorPoint = Vector2.new(0.5, 0.5)
	cap.Position = UDim2.fromScale(1.0, 0.5)
	cap.Size = UDim2.new(0, 3, 2.2, 0)
	cap.Rotation = 30
	cap.Parent = foe
	for q = 1, 3 do
		local tick = Instance.new("Frame")
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = Color3.fromRGB(90, 96, 104)
		tick.Position = UDim2.fromScale(q / 4, 0)
		tick.Size = UDim2.new(0, 1, 1, 0)
		tick.Parent = foe
	end
	local foeNumber =
		text(hud, "0.1%", 0.905, 0.849, 0.05, 0.026, FOE_RED, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
	ctx:during(-OPEN, 14, function(t)
		foeNumber.TextTransparency = 0.25 + 0.25 * math.sin(t * 9)
	end)
	ctx:at(0.05, function()
		ctx:tween(lost, 0.9, { Size = UDim2.fromScale(0.001, 0.7) })
	end)
	-- the COMBAT LOG, as the game's (the user's picture, sam_ref_hud_sparks): its small title, the count on an orange
	-- block, HITS on a pale one beside it. Shown from the first cut that lands until the kanji, and NEVER after
	-- (2026-11-14, the user: "make the 2 hits only appear BEFORE the kanji sign sequence and never again after").
	local log = Instance.new("Frame")
	log.BackgroundTransparency = 1
	log.Position = UDim2.fromScale(0.7, 0.4)
	log.Size = UDim2.fromScale(0.16, 0.085)
	log.Visible = false
	log.Parent = hud
	text(log, "COMBAT LOG", 0, 0, 1, 0.3, ORANGE, Enum.Font.GothamBold)
	local plate = Instance.new("Frame")
	plate.BorderSizePixel = 0
	plate.BackgroundColor3 = ORANGE
	plate.Position = UDim2.fromScale(0, 0.36)
	plate.Size = UDim2.fromScale(0.3, 0.64)
	plate.Parent = log
	local hits = text(
		plate,
		"0",
		0.08,
		0.04,
		0.84,
		0.92,
		Color3.fromRGB(34, 20, 6),
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	hits.TextStrokeTransparency = 1
	local word = Instance.new("Frame")
	word.BorderSizePixel = 0
	word.BackgroundColor3 = Color3.fromRGB(206, 232, 244)
	word.Position = UDim2.fromScale(0.34, 0.44)
	word.Size = UDim2.fromScale(0.6, 0.48)
	word.Parent = log
	local hitsWord = text(
		word,
		"HITS",
		0.08,
		0.1,
		0.84,
		0.8,
		Color3.fromRGB(20, 40, 56),
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	hitsWord.TextStrokeTransparency = 1
	local count = 0
	local function foeLife(share: number)
		foeFill.Size = UDim2.new(math.max(0, share), if share > 0 then 2 else 0, 0.7, 0)
		foeNumber.Text = string.format("%.1f%%", math.max(0, share) * 100)
	end
	-- (each cut flashes the sliver red: there is nothing left to take)
	local function foeHit()
		foeFill.BackgroundColor3 = FOE_RED
		task.delay(0.08, function()
			foeFill.BackgroundColor3 = Color3.fromRGB(244, 246, 248)
		end)
	end

	-- Sparks across the lens from a hit at `at` (world): thin orange streaks thrown out from where it shows on the
	-- screen, each its own length, way and speed.
	local function lensSparks(at: Vector3, n: number)
		local p, front = ctx:screen(at)
		if not front then
			return
		end
		local view = workspace.CurrentCamera.ViewportSize
		for _ = 1, n do
			local a = math.random() * math.pi * 2
			local reach = (0.2 + math.random() * 0.55) * view.Y
			local streak = Instance.new("Frame")
			streak.BorderSizePixel = 0
			streak.AnchorPoint = Vector2.new(0, 0.5)
			streak.BackgroundColor3 = Color3.new(1, 1, 1)
			streak.Size = UDim2.fromOffset(24 + math.random(110), 1 + math.random(3))
			streak.Rotation = math.deg(a)
			streak.Position = UDim2.fromScale(p.X, p.Y)
			streak.ZIndex = 5
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(Color3.fromRGB(255, 110, 24), Color3.fromRGB(255, 244, 210))
			g.Transparency = NumberSequence.new(1, 0)
			g.Parent = streak
			streak.Parent = hud
			local seconds = 0.18 + math.random() * 0.26
			ctx:tween(streak, seconds, {
				Position = UDim2.new(p.X, math.cos(a) * reach, p.Y, math.sin(a) * reach),
				BackgroundTransparency = 1,
			}, Enum.EasingStyle.Quad)
			task.delay(seconds, function()
				streak:Destroy()
			end)
		end
	end
	-- A hit at `at` (world), `power` 1 for a cut (2026-11-14, the user: "orange sparks flying everywhere when something
	-- hit", "more on screen effects and a bit of blood splatter"): a white-hot flare, long fast sparks thrown all
	-- round and falling, slower embers after them, the light of it on both bodies, the camera jolted, streaks across
	-- the lens, the frame's edges pulsing; where steel met flesh (`blood`: the way it sprays), dark drops.
	local function hitFx(at: Vector3, power: number, blood: Vector3?)
		Vfx.Emit.burst(
			at,
			{
				{
					{
						tex = "VfxFlare",
						color = Color3.fromRGB(255, 232, 196),
						size = { { 0, 0.6 }, { 0.15, 4.5 * power }, { 1, 0 } },
						life = 0.22,
						rot = { 0, 360 },
						light = 1,
						bright = 3,
						z = 2,
					},
					1,
				},
				{
					{
						tex = "Spark",
						color = {
							{ 0, Color3.fromRGB(255, 244, 214) },
							{ 0.3, SPARK },
							{ 1, Color3.fromRGB(210, 60, 14) },
						},
						size = { { 0, 0.15 }, { 1, 0.02 } },
						squash = -3.2,
						face = "along",
						life = { 0.35, 0.95 },
						speed = { 16 * power, 48 * power },
						drag = 2.1,
						accel = Vector3.new(0, -30, 0),
						spread = 180,
						light = 1,
						bright = 3,
					},
					math.floor(64 * power),
				},
				{
					{
						tex = "VfxEmber",
						color = { { 0, Color3.fromRGB(255, 200, 120) }, { 1, Color3.fromRGB(230, 70, 18) } },
						size = { { 0, 0.13 }, { 1, 0 } },
						life = { 0.8, 1.7 },
						speed = { 3, 12 },
						drag = 1,
						accel = Vector3.new(4, -11, 0),
						spread = 180,
						light = 1,
						bright = 2.4,
					},
					math.floor(26 * power),
				},
			} :: any
		)
		Vfx.Light.flash(at, SPARK, 30, 6 * power, 0.32)
		Vfx.Screen.shake(1.3 * power, 0.28)
		Vfx.Screen.punch(-2.2 * power, 0.18)
		lensSparks(at, math.floor(9 * power))
		local undo = Cinema.vignette(if blood then RED else SPARK, 0.42)
		task.delay(0.16, undo)
		if blood then
			Splat.spray(at, blood, power)
		end
	end

	-- 0.0 the blades locked, close: the two faces at the frame's edges, the crossing between them throwing sparks
	local function bind(): Vector3
		local hand = victim and ctx:limb(victim, "Right Arm")
		local b = if hand
			then (hand.CFrame * CFrame.new(0, -1, -0.5)).Position
			else ctx:world(Vector3.new(0, 3.6, -1.6))
		local a = if killerBlade
			then ctx:pointOf(killerBlade, "murasama", "base")
			else ctx:world(Vector3.new(0, 3.6, -2.8))
		return ctx.origin:PointToObjectSpace((a + b) / 2 + Vector3.new(0, 0.75, 0))
	end
	ctx:shot(
		-OPEN,
		function()
			return bind() + Vector3.new(4.6, 0.7, 0.2)
		end,
		function()
			return bind() + Vector3.new(0, 0.15, 0)
		end,
		42,
		{
			eye = function()
				return bind() + Vector3.new(3.9, 0.55, 0.2)
			end,
		}
	)
	-- 0.5 closer still, past the killer's shoulder onto the crossing, the victim's face behind it
	ctx:shot(
		0.3,
		function()
			return bind() + Vector3.new(2.3, 0.6, -1.7)
		end,
		function()
			return bind() + Vector3.new(-0.1, 0.1, 0.5)
		end,
		34,
		{
			eye = function()
				return bind() + Vector3.new(2.0, 0.5, -1.5)
			end,
		}
	)
	local grind = ctx:part({ size = Vector3.new(0.2, 0.2, 0.2), at = Vector3.new(0, 4, -2.2), alpha = 1, cast = false })
	local grindSparks = Vfx.Emit.make(grind, {
		tex = "Spark",
		color = { { 0, Color3.fromRGB(255, 246, 220) }, { 0.3, SPARK }, { 1, Color3.fromRGB(200, 50, 12) } },
		size = { { 0, 0.11 }, { 1, 0.015 } },
		squash = -3,
		face = "along",
		life = { 0.25, 0.7 },
		speed = { 8, 26 },
		drag = 2.4,
		accel = Vector3.new(0, -26, 0),
		spread = 180,
		light = 1,
		bright = 3,
		rate = 150,
	})
	local grindGlow = Vfx.Emit.make(grind, {
		tex = "VfxFlare",
		color = Color3.fromRGB(255, 214, 160),
		size = { { 0, 0.4 }, { 0.3, 1.5 }, { 1, 0.2 } },
		life = { 0.07, 0.14 },
		rot = { 0, 360 },
		speed = 0.01,
		light = 1,
		bright = 3,
		rate = 26,
		z = 1,
	})
	local grindLight = Instance.new("PointLight")
	grindLight.Color = SPARK
	grindLight.Range = 12
	grindLight.Brightness = 4
	grindLight.Parent = grind
	ctx:during(-OPEN, 0.95, function(t)
		grind.Position = ctx:world(bind())
		-- (the light of it jumps as the edges bite: noise, not a pulse)
		grindLight.Brightness = 2.5 + 4 * math.noise(t * 23, 1.7)
	end)
	for _, bite in ipairs({ { -0.2, 0.5 }, { 0.1, 0.8 }, { 0.38, 0.6 }, { 0.6, 0.7 }, { 0.82, 1.0 } }) do
		ctx:at(bite[1], function()
			Vfx.Screen.shake(bite[2], 0.16)
			grindSparks:Emit(24)
			lensSparks(ctx:world(bind()), 4)
		end)
	end
	ctx:at(0.95, function()
		-- the lock thrown open
		grindSparks.Enabled = false
		grindGlow.Enabled = false
		grindLight.Enabled = false
		hitFx(ctx:world(bind()), 1.3, nil)
		Cinema.flash(Color3.new(1, 1, 1), 0.4, 0.18)
		Sfx.play("realmMetal1", { pitch = 1.5, volume = 1.3 })
	end)
	-- 0.97 over the killer's shoulder: two cuts across the victim
	ctx:shot(0.97, Vector3.new(-3.4, 6.4, -10.5), Vector3.new(0, 3.6, 0), 50, { eye = Vector3.new(-3.1, 6.3, -10.0) })
	ctx:say(0.2, "Just getting started", 1.1)
	local function cut(t: number, from: Vector3, to: Vector3)
		ctx:at(t, function()
			local c = chest()
			Vfx.Beams.line(
				ctx:world(c + from),
				ctx:world(c + to),
				{ tex = "VfxRingBand", color = RED, width = 0.22, light = 1, bright = 2.4 }
			)
			local _, fade = Vfx.Beams.line(ctx:world(c + from), ctx:world(c + to), {
				tex = "VfxRingBand",
				color = RED,
				width = 0.12,
				light = 1,
				bright = 2.4,
			})
			task.delay(0.12, function()
				fade(0.15)
			end)
			hitFx(
				ctx:world(c + Vector3.new(0, 0, -0.5)),
				0.8,
				ctx.origin:VectorToWorldSpace((to - from).Unit + Vector3.new(0, 0.4, -0.6))
			)
			count += 1
			hits.Text = tostring(count)
			log.Visible = true
			-- (the count lands with a bump: bigger at once, back in a tenth of a second)
			plate.Size = UDim2.fromScale(0.38, 0.8)
			ctx:tween(plate, 0.12, { Size = UDim2.fromScale(0.3, 0.64) })
			foeHit()
		end)
	end
	cut(1.08, Vector3.new(1.5, 1.0, -0.6), Vector3.new(-1.5, -0.8, -0.6))
	cut(1.32, Vector3.new(0.2, 2.2, -0.6), Vector3.new(-0.2, -2.0, -0.6))
	-- 1.5 the white brush 斬, painted on over the whole right half of the screen (2026-11-12, the user: "It should be
	-- entirely on the right part of the screen, covering it"): the drawn character, swept on from the top in 0.3 s, a
	-- faint dry second impression a hair off
	local kanji: ImageLabel? = nil
	ctx:at(1.5, function()
		local k = Instance.new("ImageLabel")
		k.BackgroundTransparency = 1
		k.AnchorPoint = Vector2.new(1, 0.5)
		k.Position = UDim2.fromScale(1.0, 0.5)
		k.Size = UDim2.fromScale(0.5, 1.0)
		k.ScaleType = Enum.ScaleType.Fit
		k.Image = ZAN
		k.Rotation = -3
		k.ZIndex = 4
		local dry = k:Clone()
		dry.Position = UDim2.fromScale(1.008, 0.506)
		dry.Rotation = -1
		dry.ImageTransparency = 0.86
		dry.Parent = hud
		ctx:atNow(3.2, function()
			dry:Destroy()
		end)
		local paint = Instance.new("UIGradient")
		paint.Rotation = 90
		paint.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		paint.Offset = Vector2.new(0, -1)
		paint.Parent = k
		k.Parent = hud
		ctx:tween(paint, 0.3, { Offset = Vector2.new(0, 0.6) })
		kanji = k
		-- the COMBAT LOG is gone for good from here
		log:Destroy()
		-- (Sam's bar sits in the right half the 斬 covers: it steps away while the kanji is up, 2026-11-14)
		foeName.Visible = false
		foe.Visible = false
		foeNumber.Visible = false
	end)
	ctx:at(3.2, function()
		if kanji then
			kanji:Destroy()
		end
		foeName.Visible = true
		foe.Visible = true
		foeNumber.Visible = true
	end)
	ctx:at(1.48, function()
		Cinema.flash(Color3.new(1, 1, 1), 0.5, 0.25)
	end)
	-- 1.75 BLADE MODE: blue, from behind the killer's left
	ctx:grade(
		1.6,
		3.25,
		{ Saturation = -0.25, Contrast = 0.22, Brightness = -0.06, TintColor = Color3.fromRGB(100, 145, 255) },
		0.12
	)
	ctx:shot(
		1.75,
		Vector3.new(-3.6, 4.2, -9.4),
		Vector3.new(0.2, 4.0, -1.5),
		48,
		{ eye = Vector3.new(-3.3, 4.3, -9.0) }
	)
	-- the blade-mode screen: a cool blue wash over the whole picture (under the 斬 and the lock-on), as the game's
	ctx:at(1.6, function()
		local wash = ctx:layer(2)
		local blue = Instance.new("Frame")
		blue.BorderSizePixel = 0
		blue.BackgroundColor3 = Color3.fromRGB(40, 96, 255)
		blue.BackgroundTransparency = 1
		blue.Size = UDim2.fromScale(1, 1)
		blue.Parent = wash
		ctx:tween(blue, 0.12, { BackgroundTransparency = 0.72 })
		-- the blade mode frame: a cyan border and corner brackets, faint scan lines
		local border = Instance.new("Frame")
		border.BackgroundTransparency = 1
		border.Size = UDim2.fromScale(1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(120, 220, 255)
		stroke.Thickness = 6
		stroke.Transparency = 0.3
		stroke.Parent = border
		border.Parent = wash
		for i = 0, 11 do
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = Color3.fromRGB(140, 200, 255)
			line.BackgroundTransparency = 0.9
			line.Position = UDim2.fromScale(0, i / 12)
			line.Size = UDim2.new(1, 0, 0, 2)
			line.Parent = wash
		end
		for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			local bracket = Instance.new("Frame")
			bracket.BackgroundTransparency = 1
			bracket.AnchorPoint = Vector2.new(c[1], c[2])
			bracket.Position = UDim2.fromScale(c[1] * 0.96 + 0.02, c[2] * 0.94 + 0.03)
			bracket.Size = UDim2.fromScale(0.05, 0.08)
			local bs = Instance.new("UIStroke")
			bs.Color = Color3.fromRGB(120, 220, 255)
			bs.Thickness = 3
			bs.Parent = bracket
			bracket.Parent = wash
		end
		ctx:atNow(3.25, function()
			wash:Destroy()
		end)
	end)
	-- 2.5 over the killer's shoulder, close on the victim: the lock-on box, the green cut line
	ctx:shot(2.5, Vector3.new(-2.6, 6.0, -9.4), Vector3.new(0, 3.9, 0), 38)
	local lock: Frame? = nil
	local line: BasePart? = nil
	ctx:at(2.5, function()
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Size = UDim2.fromScale(0.09, 0.15)
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(255, 110, 140)
		s.Thickness = 3
		s.Parent = box
		for _, spec in ipairs({ { 0.5, 0.5, 0.25, 0.006 }, { 0.5, 0.5, 0.006, 0.25 } }) do
			local x = Instance.new("Frame")
			x.BorderSizePixel = 0
			x.BackgroundColor3 = Color3.fromRGB(255, 110, 140)
			x.AnchorPoint = Vector2.new(0.5, 0.5)
			x.Position = UDim2.fromScale(spec[1], spec[2])
			x.Size = UDim2.fromScale(spec[3], spec[4])
			x.Parent = box
		end
		box.Parent = hud
		lock = box
		local c = chest()
		line = ctx:part({
			size = Vector3.new(0.08, 3.4, 0.08),
			at = c + Vector3.new(0.1, 0, -0.62),
			rot = Vector3.new(0, 0, 8),
			color = Color3.fromRGB(80, 255, 140),
			glow = true,
			cast = false,
		})
	end)
	ctx:during(2.5, 3.25, function()
		if lock then
			local p = ctx:screen(ctx:world(chest() + Vector3.new(0, 0.3, 0)))
			lock.Position = UDim2.fromScale(p.X, p.Y)
		end
	end)
	-- 3.25 the cut: sparks at the chest; the red cuts glow on him from now
	ctx:at(3.25, function()
		if lock then
			lock:Destroy()
		end
		if line then
			line:Destroy()
		end
		local c = ctx:world(chest())
		Vfx.Emit.burst(c, {
			{
				{
					tex = "VfxFlare",
					color = Color3.fromRGB(255, 200, 140),
					size = { { 0, 0.5 }, { 0.2, 4 }, { 1, 0 } },
					life = 0.2,
					rot = { 0, 360 },
					bright = 2.4,
					z = 2,
				},
				1,
			},
			{
				{
					tex = "VfxStreak",
					color = { { 0, Color3.fromRGB(255, 230, 180) }, { 1, Color3.fromRGB(255, 110, 40) } },
					size = { { 0, 0.16 }, { 1, 0.03 } },
					squash = -2.2,
					life = { 0.3, 0.6 },
					speed = { 12, 26 },
					drag = 3,
					accel = Vector3.new(0, -25, 0),
					spread = 180,
					face = "along",
					light = 1,
					bright = 2,
				},
				50,
			},
		})
		Vfx.Light.flash(c, Color3.fromRGB(255, 150, 90), 26, 5, 0.3)
		hitFx(c, 1.5, ctx.origin:VectorToWorldSpace(Vector3.new(0.5, 0.6, 0.6)))
		if victim and killer then
			Vfx.Screen.impact({ victim, killer }, 0.09)
		end
		if victim then
			for i, spec in ipairs({ { 0.2, 0.3, 30 }, { -0.1, -0.2, -40 }, { 0.05, 0.6, 70 } }) do
				ctx:attach(victim, "Torso", {
					size = Vector3.new(0.08, 1.8, 0.05),
					at = Vector3.new(spec[1], spec[2], -0.53),
					rot = Vector3.new(0, 0, spec[3]),
					color = RED,
					glow = true,
					name = "Cut" .. i,
				})
			end
		end
	end)
	ctx:shot(3.3, Vector3.new(6.5, 4.4, -2.6), Vector3.new(0, 3.5, -2.0), 50)
	ctx:shot(3.5, Vector3.new(4.2, 2.6, 4.4), Vector3.new(0.4, 3.0, 0.8), 46)
	ctx:shot(4.2, Vector3.new(7.5, 4.2, -6), Vector3.new(0, 4.2, -3), 52)
	-- 5.0 grabbed: over the victim's shoulder (his back to us), the killer behind him facing us
	ctx:at(5.0, function()
		if killer then
			killer:PivotTo(ctx.origin * CFrame.lookAt(Vector3.new(0, 3, -2.2), Vector3.new(0, 3, 0)))
		end
	end)
	ctx:shot(5.0, Vector3.new(1.3, 5.2, 3.4), Vector3.new(-0.2, 4.8, -2.4), 42, { eye = Vector3.new(1.1, 5.1, 3.0) })
	ctx:say(5.2, "Play time's over.", 2.2)
	ctx:at(6.8, function()
		foeHit()
		Cinema.flash(RED, 0.35, 0.25)
		-- the thrust: sparks off the armour, blood out of his back toward the lens, and some of it on the lens
		hitFx(ctx:world(chest()), 1.2, ctx.origin:VectorToWorldSpace(Vector3.new(0.2, 0.3, 1)))
		Splat.screen(
			hud,
			{ at = Vector2.new(0.2, 0.62), size = 0.42, image = 2, seed = 7, hold = 1.4, fade = 1.0, drips = 2 }
		)
		Splat.screen(
			hud,
			{ at = Vector2.new(0.86, 0.3), size = 0.2, image = 4, seed = 12, hold = 1.1, fade = 0.9, drips = 0 }
		)
		Vfx.Emit.burst(ctx:world(chest()), {
			tex = "VfxFlare",
			color = RED,
			size = { { 0, 0.5 }, { 0.2, 3.5 }, { 1, 0 } },
			life = 0.25,
			rot = { 0, 360 },
			bright = 2.4,
			z = 2,
		}, 1)
	end)
	-- 7.3 run through, his hand opens: the red sword falls, turning, hits the ground point first, tips over flat
	-- (2026-11-12, the user: after "playtime's over" he pierced Sam, so Sam drops it)
	ctx:at(7.3, function()
		local blade = victimBlade
		if not blade or not blade.Parent then
			return
		end
		for _, d in ipairs(blade:GetDescendants()) do
			if d:IsA("WeldConstraint") or d:IsA("Weld") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		blade.Parent = ctx.stage.folder
		local from = blade:GetPivot()
		local floor = ctx.origin.Position.Y
		local landing = Vector3.new(from.Position.X + 0.5, floor + 0.12, from.Position.Z - 0.4)
		local flat = CFrame.new(landing) * CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(math.rad(90), 0, 0)
		local start = ctx:now()
		local landed = false
		ctx:during(7.3, 8.3, function(t)
			local u = math.clamp((t - start) / 0.55, 0, 1)
			if u < 1 then
				-- falling: gravity's ease, the blade turning toward flat as it goes
				local fall = u * u
				local pos = from.Position:Lerp(landing, fall)
				blade:PivotTo(CFrame.new(pos) * (from - from.Position):Lerp(flat - flat.Position, u * 0.8))
			else
				if not landed then
					landed = true
					Sfx.play("realmMetal1", { pitch = 1.9, volume = 1.2 })
					Vfx.Emit.burst(landing, {
						tex = "VfxStreak",
						color = Color3.fromRGB(255, 210, 160),
						size = { { 0, 0.06 }, { 1, 0.01 } },
						squash = -2,
						life = { 0.15, 0.3 },
						speed = { 4, 9 },
						spread = 70,
						face = "along",
						light = 1,
						bright = 2,
					}, 8)
				end
				-- a small bounce and it settles
				local v = math.clamp((t - start - 0.55) / 0.3, 0, 1)
				local hop = math.sin(v * math.pi) * 0.12 * (1 - v)
				blade:PivotTo(flat + Vector3.new(0, hop, 0))
			end
		end)
	end)
	-- 7.25 over the killer's back: the blade through him, sparks at the wound
	ctx:shot(7.25, Vector3.new(-2.8, 6.2, -6.8), Vector3.new(0, 3.9, 0), 40, { eye = Vector3.new(-2.5, 6.0, -6.4) })
	ctx:during(7.25, 11.0, function()
		if math.random() < 0.3 then
			Vfx.Emit.burst(ctx:world(chest() + Vector3.new(0, 0.1, -0.5)), {
				tex = "VfxStreak",
				color = Color3.fromRGB(255, 120, 60),
				size = { { 0, 0.1 }, { 1, 0.02 } },
				squash = -2,
				life = { 0.15, 0.3 },
				speed = { 6, 12 },
				spread = 60,
				face = "along",
				light = 1,
				bright = 2,
			}, 4)
		end
	end)
	ctx:at(11.0, function()
		foeLife(0)
		-- the blade out: a last spray after it, a few sparks
		hitFx(ctx:world(chest()), 0.7, ctx.origin:VectorToWorldSpace(Vector3.new(0, 0.5, -1)))
		Splat.screen(
			hud,
			{ at = Vector2.new(0.74, 0.7), size = 0.24, image = 1, seed = 31, hold = 0.9, fade = 0.9, drips = 1 }
		)
		Vfx.Emit.burst(ctx:world(chest()), {
			tex = "VfxFlare",
			color = RED,
			size = { { 0, 0.5 }, { 0.2, 3 }, { 1, 0 } },
			life = 0.25,
			rot = { 0, 360 },
			bright = 2.2,
			z = 2,
		}, 1)
		if killer then
			killer:PivotTo(ctx.origin * CFrame.lookAt(Vector3.new(-0.5, 3, -4.5), Vector3.new(0, 3, 0)))
		end
	end)
	-- 11.75 wide, side on: the stagger away; 12.5 the overhead; 13 both standing; black
	ctx:shot(11.75, Vector3.new(9, 4.2, -1.5), Vector3.new(0.3, 3.6, -1.5), 48)
	ctx:at(13.75, function()
		local black = Instance.new("Frame")
		black.BackgroundColor3 = Color3.new(0, 0, 0)
		black.BackgroundTransparency = 1
		black.BorderSizePixel = 0
		black.Size = UDim2.fromScale(1, 1)
		black.ZIndex = 6
		black.Parent = hud
		ctx:tween(black, 0.25, { BackgroundTransparency = 0 })
	end)
	ctx:grade(0, nil, { Saturation = -0.1, Contrast = 0.12, TintColor = Color3.fromRGB(255, 236, 214) }, 0.1)
	local _ = killerAt
end

return { length = 14 + OPEN, build = build }
