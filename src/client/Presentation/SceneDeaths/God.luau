-- A GOD.. IS NOT... AFRAID OF... (art/refs/deaths/god.md; 17 s since 2026-11-12): the victim IS the Devourer of Gods,
-- a colossal armoured cosmic serpent (our own models of its look: GodHead, GodBody, GodTail in Core, props_god.py)
-- coiling through a purple sky of stars. "A GOD DOES NOT FEAR DEATH!" in an old game's chat at the bottom left, then
-- spammed faster and faster while the god falls apart: glowing fractures run from the tail to the head, and each link
-- they pass BREAKS (2026-11-12, the user: "you can barely notice his body crumbling"): a flash, its plates flung off
-- as shards, magenta smoke, the rest of it going to ash, the gap travelling up the body to the head. The head alone
-- shudders with light, flares, and the screen goes white SLOWLY, then fades to black, and in the bottom right, in
-- purple, as Terraria says it: "<Name> has been defeated!" ("Player" when there is no player).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SceneDeaths = require(script.Parent)
local Vfx = require(script.Parent.Parent.Vfx)
local ModelLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelLibrary"))

local MAGENTA = Color3.fromRGB(255, 60, 220)
local CYAN = Color3.fromRGB(60, 230, 255)
local CRACK = Color3.fromRGB(255, 240, 255)
local PLATE = Color3.fromRGB(40, 30, 64)
local SEGMENTS = 20
local SCALE = 1.5 -- the serpent's size over the models' own (the head 10 studs wide)
local CRACK_FROM, CRACK_TO = 4.4, 9.2 -- the fractures run from the tail to the head between these
local BREAK_AFTER = 0.55 -- a link breaks this long after its cracks light
local FLARE = 10.6 -- the head flares; the white comes up slowly over WHITE_IN
local WHITE_IN = 1.7
local BLACK_AT, BLACK_IN = 12.9, 1.3 -- then the white goes down to black
local DEFEATED_AT = 14.5 -- the purple line, on the black
local LENGTH = 17.0
local LAVENDER = Color3.fromRGB(150, 154, 206)
local DEFEATED = Color3.fromRGB(175, 75, 255) -- (Terraria's own purple for a boss's defeat)

-- One link of the serpent: its model (or a stand-in part), the length it takes along the body, its crack parts.
local function link(ctx, key: string, scale: number, standIn: Vector3)
	local model = ModelLibrary.get(key)
	local cracks = {}
	local plates = {}
	if model then
		model:ScaleTo(model:GetScale() * scale)
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				if string.find(p.Name, "_Cracks", 1, true) then
					p.Material = Enum.Material.Neon
					p.Color = CRACK
					p.Transparency = 1
					if p:IsA("MeshPart") then
						p.TextureID = ""
					end
					p.CastShadow = false
					table.insert(cracks, p)
				elseif not string.find(p.Name, "_Glow", 1, true) then
					table.insert(plates, p)
				end
			end
		end
		model.Parent = ctx.stage.folder
		local _, size = model:GetBoundingBox()
		return { model = model, length = size.Z, cracks = cracks, plates = plates, pivot = model:GetPivot() }
	end
	local part = ctx:part({ size = standIn * scale, color = PLATE, material = Enum.Material.Metal })
	local m = Instance.new("Model")
	part.Parent = m
	m.PrimaryPart = part
	m.Parent = ctx.stage.folder
	return { model = m, length = standIn.Z * scale, cracks = {}, plates = { part }, pivot = m:GetPivot() }
end

local function build(ctx)
	if not ctx:imported() then
		SceneDeaths.box(ctx, Vector3.new(500, 400, 500), Vector3.new(0, -150, 0), Color3.fromRGB(44, 16, 86))
	end
	SceneDeaths.emit(ctx, Vector3.new(0, 20, 0), Vector3.new(160, 100, 160), {
		tex = "VfxEmber",
		color = Color3.new(1, 1, 1),
		size = { { 0, 0.1 }, { 0.5, 0.35 }, { 1, 0.1 } },
		life = { 4, 7 },
		speed = { 0.1, 0.3 },
		spread = 180,
		bright = 2.6,
		light = 1,
		rate = 120,
	}):Emit(400)
	ctx:light(Vector3.new(0, 30, 20), Color3.fromRGB(230, 200, 255), 120, 1.3)
	ctx:light(Vector3.new(-30, 0, -20), MAGENTA, 90, 1.1)
	ctx:light(Vector3.new(30, 10, -20), CYAN, 90, 1.0)

	-- the serpent: the head, the body's rings tapering to the tail
	local links = {}
	table.insert(links, link(ctx, "GodHead", SCALE, Vector3.new(6.7, 5.8, 9.7)))
	for i = 1, SEGMENTS do
		local s = SCALE * (1 - (i / SEGMENTS) * 0.45)
		table.insert(links, link(ctx, "GodBody", s, Vector3.new(8.2, 6.4, 4.7)))
	end
	table.insert(links, link(ctx, "GodTail", SCALE * 0.55, Vector3.new(4.7, 4.7, 5.5)))

	-- the path: a slow coil through the sky (scene space), the head leading; the serpent walked along it by arc length
	local function path(s: number, t: number): Vector3
		local a = s * 0.07 - t * 0.5
		return Vector3.new(
			math.sin(a) * 40 + math.sin(s * 0.03) * 6,
			16 + math.sin(a * 1.7 + 1) * 10,
			math.cos(a) * 28 - 10
		)
	end
	local STEP = 0.5
	local frozen: number? = nil -- scene time the coil seized up at (the fractures have reached the head)
	local headFrame = CFrame.new()
	local function place(t: number)
		-- (the coil slows as it cracks, then stops dead)
		local tt = if frozen
			then frozen - math.max(0, frozen - CRACK_FROM) * 0.5
			else t - math.max(0, t - CRACK_FROM) * 0.5
		local s, prev, walked = 0, path(0, tt), 0
		local want = 0 -- the arc distance the next link's middle wants
		local n = 1
		local lastPos = prev
		while n <= #links and s < 200 do
			s += STEP
			local p = path(s, tt)
			local d = (p - prev).Magnitude
			while n <= #links and walked + d >= want do
				local f = (want - walked) / math.max(d, 1e-3)
				local pos = prev:Lerp(p, f)
				local ahead = pos + (prev - p).Unit * 2 -- toward the head
				local cf = CFrame.lookAt(ctx:world(pos), ctx:world(ahead))
				local wiggle = CFrame.Angles(0, 0, math.sin(tt * 2 + n * 0.5) * 0.12)
				links[n].model:PivotTo(cf * wiggle)
				if n == 1 then
					headFrame = cf
				end
				local half = links[n].length / 2
				want += half + (if links[n + 1] then links[n + 1].length / 2 else 0) - 0.4 * SCALE
				n += 1
				lastPos = pos
			end
			walked += d
			prev = p
		end
		return lastPos
	end
	ctx:during(0, LENGTH, function(t)
		place(t)
	end)

	-- the chat at the bottom left: the boast, then spammed
	local chat = ctx:layer(3)
	local log = Instance.new("Frame")
	log.BackgroundTransparency = 1
	log.AnchorPoint = Vector2.new(0, 1)
	log.Position = UDim2.fromScale(0.02, 0.86)
	log.Size = UDim2.fromScale(0.6, 0.4)
	log.ClipsDescendants = true
	log.Parent = chat
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = log
	local lines = 0
	local function say(text: string, color: Color3)
		lines += 1
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 26)
		l.Font = Enum.Font.Arcade
		l.TextSize = 24
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.1
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = text
		l.LayoutOrder = lines
		l.Parent = log
		if lines > 14 then
			local oldest
			for _, c in ipairs(log:GetChildren()) do
				if c:IsA("TextLabel") and (not oldest or c.LayoutOrder < oldest.LayoutOrder) then
					oldest = c
				end
			end
			if oldest then
				oldest:Destroy()
			end
		end
		return l
	end
	local BOAST = "A GOD DOES NOT FEAR DEATH!"
	ctx:at(0.4, function()
		say(BOAST, CYAN)
	end)
	ctx:at(2.8, function()
		say(BOAST, CYAN)
	end)
	local spam = 4.4
	while spam < FLARE do
		local t = spam
		ctx:at(t, function()
			say(BOAST, if math.floor(t * 2) % 4 == 0 then MAGENTA else CYAN)
		end)
		spam += math.max(0.14, 0.5 - (spam - 4.4) * 0.07)
	end

	-- the fractures: each link's cracks light up in turn from the tail to the head, light leaking from the plates
	-- (their colour lifting toward white); a moment later the link BREAKS: a flash, its plates flung off as shards,
	-- magenta smoke, sparks, the rest of it gone to ash. The coil seizes when the cracks reach the head.
	local gone = {}
	local function breakLink(n: number)
		local l = links[n]
		gone[n] = true
		local pos = l.model:GetPivot().Position
		local size = SCALE * (if n == #links then 0.6 else 1 - (n / #links) * 0.45)
		Vfx.Emit.burst(
			pos,
			{
				{
					{
						tex = "VfxChunk",
						color = { { 0, LAVENDER }, { 1, PLATE } },
						size = { { 0, 1.0 * size }, { 1, 0.55 * size } },
						life = { 1.6, 2.6 },
						speed = { 9 * size, 20 * size },
						spread = 180,
						accel = Vector3.new(0, -16, 0),
						drag = 0.5,
						rot = { 0, 360 },
						spin = { -260, 260 },
						lit = 0.8,
					},
					28,
				},
				{
					{
						tex = "VfxFlare",
						color = CRACK,
						size = { { 0, 3 * size }, { 0.15, 12 * size }, { 1, 0 } },
						life = 0.45,
						speed = 0.01,
						light = 1,
						bright = 3,
					},
					1,
				},
				{
					{
						tex = "VfxSmoke",
						color = { { 0, MAGENTA }, { 1, Color3.fromRGB(70, 36, 130) } },
						size = { { 0, 3 * size }, { 1, 10 * size } },
						alpha = { { 0, 0.35 }, { 0.5, 0.6 }, { 1, 1 } },
						life = { 1.4, 2.4 },
						speed = { 2, 6 },
						spread = 180,
						rot = { 0, 360 },
						spin = { -30, 30 },
						light = 0.7,
						bright = 1.6,
					},
					7,
				},
				{
					{
						tex = "Spark",
						color = { { 0, Color3.new(1, 1, 1) }, { 1, if n % 2 == 0 then CYAN else MAGENTA } },
						size = { { 0, 0.35 * size }, { 1, 0.05 } },
						squash = -3,
						face = "along",
						life = { 0.4, 1.0 },
						speed = { 24, 46 },
						drag = 2.5,
						spread = 180,
						light = 1,
						bright = 3,
					},
					20,
				},
			} :: any,
			nil,
			Vector3.new(4, 4, 4) * size
		)
		Vfx.Light.flash(pos, MAGENTA, 46 * SCALE, 6, 0.55)
		local all = {}
		for _, p in ipairs(l.model:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				table.insert(all, p)
			end
		end
		Vfx.Recipes.dissolve(all, 0.2, {
			tint = LAVENDER,
			glow = MAGENTA,
			wind = Vector3.new(0, 0, 0),
			rise = 1.4,
			scale = 5 * size,
			fade = 0.35,
		})
	end
	for n = #links, 1, -1 do
		local at = CRACK_FROM + (CRACK_TO - CRACK_FROM) * (#links - n) / (#links - 1)
		local l = links[n]
		ctx:at(at, function()
			for _, c in ipairs(l.cracks) do
				TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0,
				}):Play()
			end
			local pos = l.model:GetPivot().Position
			Vfx.Light.flash(pos, CRACK, 24 * SCALE, 3, 0.4)
			if n == 1 then
				frozen = ctx:now()
			end
		end)
		if n > 1 then
			ctx:at(at + BREAK_AFTER, function()
				breakLink(n)
				if n % 4 == 0 then
					Vfx.Screen.shake(0.8, 0.3)
				end
			end)
		end
		-- the cracks pulse while they spread, and the plates pale toward the light inside (until the link breaks)
		ctx:during(at + 0.35, FLARE, function(t)
			if gone[n] then
				return
			end
			local u = math.clamp((t - at) / math.max(BREAK_AFTER, FLARE - at), 0, 1)
			local pulse = 0.5 + 0.5 * math.sin(t * 17 + n)
			for _, c in ipairs(l.cracks) do
				c.Transparency = 0.15 * pulse
			end
			for _, p in ipairs(l.plates) do
				p.Color = PLATE:Lerp(Color3.fromRGB(230, 200, 255), u * 0.7)
			end
		end)
	end
	-- the head alone: it shudders with light, more and more
	ctx:during(CRACK_TO, FLARE, function(t)
		local u = (t - CRACK_TO) / (FLARE - CRACK_TO)
		if math.floor(t * 8) ~= (ctx :: any).godBeat then
			(ctx :: any).godBeat = math.floor(t * 8)
			Vfx.Screen.shake(0.3 + u * 1.2, 0.2)
			Vfx.Light.flash(headFrame.Position, CRACK, 30 * SCALE, 2 + u * 4, 0.2)
		end
	end)
	-- the flare: the head goes white and bursts, the screen comes up white, slowly
	local white: Frame? = nil
	ctx:at(FLARE, function()
		local l = links[1]
		for _, p in ipairs(l.plates) do
			p.Material = Enum.Material.Neon
			p.Color = Color3.new(1, 1, 1)
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
		end
		local at = headFrame.Position
		for i = 0, 2 do
			Vfx.Clock.after(i * 0.15, function()
				Vfx.Beams.wave(CFrame.new(at) * CFrame.Angles(0, 0, i * 0.6), 1, 50 + i * 25, 1.4, {
					tex = "VfxRingBand",
					color = if i == 1 then MAGENTA else CRACK,
					width = 1.6 - i * 0.4,
					light = 1,
					bright = 2,
				})
			end)
		end
		Vfx.Light.flash(at, Color3.new(1, 1, 1), 90, 8, 1.2)
		Vfx.Screen.shake(2.4, 0.8)
		Vfx.Clock.after(0.5, function()
			breakLink(1)
		end)
		local layer = ctx:layer(8)
		local w = Instance.new("Frame")
		w.BackgroundColor3 = Color3.new(1, 1, 1)
		w.BorderSizePixel = 0
		w.Size = UDim2.fromScale(1, 1)
		w.BackgroundTransparency = 1
		w.Parent = layer
		white = w
		TweenService:Create(w, TweenInfo.new(WHITE_IN, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			BackgroundTransparency = 0,
		}):Play()
		-- the chat fades under the white
		for _, c in ipairs(log:GetChildren()) do
			if c:IsA("TextLabel") then
				TweenService:Create(c, TweenInfo.new(WHITE_IN * 0.8), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			end
		end
	end)
	-- the white goes down to black
	ctx:at(BLACK_AT, function()
		if white then
			TweenService:Create(white, TweenInfo.new(BLACK_IN, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundColor3 = Color3.new(0, 0, 0),
			}):Play()
		end
	end)
	-- on the black, bottom right, in Terraria's purple: who was defeated
	ctx:at(DEFEATED_AT, function()
		local layer = ctx:layer(9)
		local name = ctx.victimName
		if name == nil or name == "" or name == "Unknown" then
			name = "Player"
		end
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(1, 1)
		l.Position = UDim2.fromScale(0.975, 0.95)
		l.Size = UDim2.fromScale(0.7, 0.07)
		l.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Right
		l.TextColor3 = DEFEATED
		l.TextTransparency = 1
		l.Text = name .. " has been defeated!"
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 6, 30)
		stroke.Thickness = 2
		stroke.Transparency = 1
		stroke.Parent = l
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 34
		cap.Parent = l
		l.Parent = layer
		TweenService:Create(l, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	end)

	-- cameras: wide; the head from in front (the body trails behind it); a slow circling medium as it cracks; close on
	-- the head's fractures; white
	local function headAt(): Vector3
		return ctx.origin:PointToObjectSpace(headFrame.Position)
	end
	local function facing(): Vector3
		local v = ctx.origin:VectorToObjectSpace(headFrame.LookVector)
		return Vector3.new(v.X, 0, v.Z).Unit
	end
	ctx:shot(0.0, Vector3.new(0, 26, 66), Vector3.new(0, 14, -6), 58, { eye = Vector3.new(-14, 24, 62) })
	ctx:camera(2.6, 5.0, function()
		local h = headAt()
		return CFrame.lookAt(h + facing() * 30 * SCALE / 1.5 + Vector3.new(0, 6, 0), h), 44
	end)
	-- (close enough to see each link break, circling slowly)
	ctx:camera(5.0, 8.6, function(t)
		local a = (t - 5) * 0.16
		local eye = Vector3.new(math.sin(a) * 60, 24, math.cos(a) * 60)
		return CFrame.lookAt(eye, Vector3.new(0, 14, -8)), 58
	end)
	ctx:camera(8.6, BLACK_AT, function(t)
		local h = headAt()
		local push = math.clamp((t - 8.6) / (FLARE - 8.6), 0, 1)
		return CFrame.lookAt(h + facing() * (34 - push * 10) + Vector3.new(0, 6, 0), h), 44
	end)
	ctx:grade(0, nil, { Saturation = 0.15, Contrast = 0.2, TintColor = Color3.fromRGB(240, 220, 255) }, 0.1)
end

return { length = LENGTH, build = build }
