-- A GOD.. IS NOT... AFRAID OF... (art/refs/deaths/god.md; 13 s since 2026-11-10): the victim IS the Devourer of Gods,
-- a colossal armoured cosmic serpent (our own models of its look: GodHead, GodBody, GodTail in Core, props_god.py)
-- coiling through a purple sky of stars. "A GOD DOES NOT FEAR DEATH!" in an old game's chat at the bottom left, then
-- spammed faster and faster while the god CRACKS: glowing fractures spread from the tail to the head, light leaking
-- out of every plate, the coil seizing up; then it flares white, the screen goes white, and the chat says
-- "<Name> has been defeated!" (the user, 2026-11-10: cracks, not pieces falling off; die faster; the white screen
-- transition to the chat line).

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
local CRACK_FROM, CRACK_TO = 4.6, 8.6 -- the fractures run from the tail to the head between these
local FLARE = 9.0 -- the god flares white; the screen is white by 9.35
local LENGTH = 13.0

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

	-- the fractures: each link's cracks light up in turn from the tail to the head, flickering as they spread, light
	-- leaking from the plates (their colour lifting toward white), dust shaken out; the coil seizes when they reach the
	-- head
	for n = #links, 1, -1 do
		local at = CRACK_FROM + (CRACK_TO - CRACK_FROM) * (#links - n) / (#links - 1)
		local l = links[n]
		ctx:at(at, function()
			for _, c in ipairs(l.cracks) do
				TweenService:Create(c, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0,
				}):Play()
			end
			local pos = l.model:GetPivot().Position
			Vfx.Light.flash(pos, CRACK, 24 * SCALE, 3, 0.4)
			Vfx.Emit.burst(pos, {
				tex = "VfxDust",
				color = { { 0, CRACK }, { 1, MAGENTA } },
				size = { { 0, 0.3 }, { 1, 0.1 } },
				life = { 1.0, 1.8 },
				speed = { 2, 6 },
				spread = 180,
				drag = 1,
				light = 1,
				bright = 1.8,
			}, 18, Vector3.new(4, 4, 4) * SCALE)
			if n == 1 then
				frozen = ctx:now()
			end
		end)
		-- the cracks pulse while they spread, and the plates pale toward the light inside
		ctx:during(at + 0.5, FLARE, function(t)
			local u = math.clamp((t - at) / (FLARE - at), 0, 1)
			local pulse = 0.5 + 0.5 * math.sin(t * 17 + n)
			for _, c in ipairs(l.cracks) do
				c.Transparency = 0.1 * pulse * (1 - u)
			end
			for _, p in ipairs(l.plates) do
				p.Color = PLATE:Lerp(Color3.fromRGB(230, 200, 255), u * 0.6)
			end
		end)
	end
	-- 8.6-9.0 the head alone shudders with light; 9.0 the god flares white and the screen goes white
	local white: Frame? = nil
	ctx:at(FLARE, function()
		for _, l in ipairs(links) do
			for _, p in ipairs(l.plates) do
				p.Material = Enum.Material.Neon
				p.Color = Color3.new(1, 1, 1)
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
			end
		end
		local at = headFrame.Position
		Vfx.Beams.wave(
			CFrame.new(at),
			1,
			60,
			1.0,
			{ tex = "VfxRingBand", color = CRACK, width = 1.6, light = 1, bright = 2 }
		)
		Vfx.Light.flash(at, Color3.new(1, 1, 1), 80, 6, 0.5)
		local layer = ctx:layer(8)
		local w = Instance.new("Frame")
		w.BackgroundColor3 = Color3.new(1, 1, 1)
		w.BorderSizePixel = 0
		w.Size = UDim2.fromScale(1, 1)
		w.BackgroundTransparency = 1
		w.Parent = layer
		white = w
		TweenService:Create(w, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 0,
		}):Play()
		-- (the chat stays over the white: it is the last thing seen)
		chat.ZIndex = 9
	end)
	-- 9.6 on the white: the chat clears and says who was defeated
	ctx:at(9.6, function()
		for _, c in ipairs(log:GetChildren()) do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local l = say(ctx.victimName .. " has been defeated!", Color3.fromRGB(200, 40, 160))
		l.TextStrokeTransparency = 0.6
		l.TextStrokeColor3 = Color3.fromRGB(120, 20, 100)
	end)
	ctx:at(LENGTH - 0.4, function()
		if white then
			TweenService:Create(white, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
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
	ctx:camera(5.0, 8.3, function(t)
		local a = (t - 5) * 0.14
		local eye = Vector3.new(math.sin(a) * 76, 26, math.cos(a) * 76)
		return CFrame.lookAt(eye, Vector3.new(0, 14, -8)), 56
	end)
	ctx:camera(8.3, FLARE + 0.3, function()
		local h = headAt()
		return CFrame.lookAt(h + facing() * 22 + Vector3.new(0, 4, 0), h), 40
	end)
	ctx:grade(0, nil, { Saturation = 0.15, Contrast = 0.2, TintColor = Color3.fromRGB(240, 220, 255) }, 0.1)
end

return { length = LENGTH, build = build }
