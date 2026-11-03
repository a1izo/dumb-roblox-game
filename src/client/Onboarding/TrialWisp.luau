-- The Trial's wisp, on this client only: a warm amber soul-flame you follow to where the next step is done.
-- It is built to be seen and never mistaken for the pale blue lost souls a Deathsinger gathers:
--   * a white-hot heart in a flickering flame, two motes circling it, a thread of smoke off its tip, sparks, a
--     wake of light behind it, a lamp, and a glow that shows through walls once you are far from it;
--   * it walks the real way there (PathfindingService, round walls and across bridges), a little ahead of
--     you; if you fall behind it stops and pulses until you catch up;
--   * when it is off the screen an amber arrow at the edge of the screen points to it;
--   * near the place itself it circles over it, above whatever stands there (a station's tablet: it hung in
--     front of the name on it, the user's picture of 2026-11-03), and a soft column of light stands on the
--     floor where you go to use it until you get there (it stood on the desk and rose through the tablet);
--   * a soft chime each time it sets off somewhere new (Assets.sfx trialChime: silent until uploaded).
--
--   TrialWisp.target("file", deskPosition, "lead")   -- walk the player there
--   TrialWisp.target("offer", spot, "wait")          -- wait there
--   TrialWisp.clear()

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local Screens = require(UI.Screens)
local UiSound = require(UI.Core.UiSound)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)

local LocalPlayer = Players.LocalPlayer

local TrialWisp = {}

local CORE = Color3.fromRGB(255, 228, 176)
local AMBER = Color3.fromRGB(255, 166, 72)
local EMBER = Color3.fromRGB(150, 52, 22)

local LEAD = 12 -- studs of path the wisp keeps ahead of you
local HOVER = 3.5 -- studs above the path
local WAIT_FOR = 24 -- further than this from you, it stops and calls
local CIRCLE_AT = 22 -- this close to the place (flat), it goes and circles it
local CIRCLE = 1.6 -- studs round, circling
local PILLAR_AT = 48 -- this close, the pillar shows
local ARRIVED = 7 -- this close to where you stand to use it, the pillar goes (you are there)
local STAND_OUT = 4.4 -- studs out from the place towards you: where you stand to use it
local PERCH_ROOF = 12 -- studs over the place the rays for its top start (a canopy higher up is not the place's)
local PERCH_SEARCH = 1.75 -- studs between the rays, five by five round the place
local PERCH_GAP = 2.2 -- studs it circles over the top of what stands at the place
local SHINE_THROUGH = 30 -- further than this, its glow shows through walls
local REPATH = 1.5 -- seconds between new paths while you are off the old one
local OFF_PATH = 12 -- studs from the path that count as off it

type Mode = "lead" | "wait"

local model: Model? = nil
local core: BasePart? = nil
local shell: BasePart? = nil
local light: PointLight? = nil
local halo: BillboardGui? = nil
local haloFx: ParticleEmitter? = nil
local orbits: { Attachment } = {}
local pillar: Model? = nil
local arrow: Frame? = nil
local connection: RBXScriptConnection? = nil

local goalKey: string? = nil
local goal: Vector3? = nil
local perch: Vector3? = nil -- where it circles at the place (over its top)
local stand: Vector3? = nil -- where the pillar stands (on your side of the place)
local mode: Mode = "wait"
local waypoints: { Vector3 } = {}
local pathFor: Vector3? = nil
local pathing = false
local lastPath = 0
local position: Vector3? = nil

local function rootPart(): BasePart?
	local character = LocalPlayer.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if part and part:IsA("BasePart") then part else nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function solidRays(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { workspace.CurrentCamera }
	if LocalPlayer.Character then
		table.insert(exclude, LocalPlayer.Character)
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

-- The spot over a place: a little above the top of whatever stands there (the tablet behind a station's desk,
-- a figure's head), found by rays straight down round it; the place itself when nothing stands over it.
local function perchOver(at: Vector3): Vector3
	local params = solidRays()
	local top = -math.huge
	for dx = -2, 2 do
		for dz = -2, 2 do
			local from = at + Vector3.new(dx * PERCH_SEARCH, PERCH_ROOF, dz * PERCH_SEARCH)
			local hit = workspace:Raycast(from, Vector3.new(0, -PERCH_ROOF - 6, 0), params)
			if hit and hit.Position.Y < from.Y - 0.5 then
				top = math.max(top, hit.Position.Y)
			end
		end
	end
	return Vector3.new(at.X, math.max(at.Y, top + PERCH_GAP), at.Z)
end

-- Building ------------------------------------------------------------------------------------------------

local function build(at: Vector3)
	local holder = Create("Model", { Name = "TrialWisp" }) :: Model
	local ball = Create("Part", {
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.5, 0.5, 0.5),
		Color = CORE,
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Position = at,
		Parent = holder,
	}) :: BasePart
	local glow = Create("Part", {
		Name = "Shell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.9, 1.9, 1.9),
		Color = AMBER,
		Material = Enum.Material.Neon,
		-- (unseen: a see-through neon ball read as glass; its breath is the halo's now)
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Position = at,
		Parent = holder,
	}) :: BasePart
	-- The flame licks up off the core and is left behind as it moves: the kit's fire, white-gold at its heart,
	-- amber through its body, darkening as it tears away; a soft halo round it and a hard star at its heart.
	Vfx.Emit.make(ball, {
		name = "Flame",
		tex = "VfxFlame",
		grid = 8,
		fps = 40,
		startRandom = true,
		color = { { 0, CORE }, { 0.45, AMBER }, { 1, EMBER } },
		size = { { 0, 1.5 }, { 0.6, 1.0 }, { 1, 0.3 } },
		alpha = { { 0, 0.2 }, { 0.6, 0.45 }, { 1, 1 } },
		life = { 0.35, 0.6 },
		speed = { 0.8, 1.8 },
		accel = Vector3.new(0, 4, 0),
		spread = 14,
		face = "up",
		light = 0.7,
		bright = 1.3,
		rate = 45,
	})
	-- (and at its heart a smaller white-hot flame, quicker than the body round it)
	Vfx.Emit.make(ball, {
		name = "Inner",
		tex = "VfxFlame",
		grid = 8,
		fps = 50,
		startRandom = true,
		color = { { 0, Color3.new(1, 1, 1) }, { 0.5, CORE }, { 1, AMBER } },
		size = { { 0, 0.8 }, { 0.7, 0.55 }, { 1, 0.1 } },
		alpha = { { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } },
		life = { 0.22, 0.36 },
		speed = { 0.5, 1.2 },
		accel = Vector3.new(0, 5, 0),
		spread = 10,
		face = "up",
		light = 1,
		bright = 1.8,
		rate = 34,
		z = 0.3,
	})
	-- (no smoke off its tip any more: in the lobby's grey it read as a haze round a white puff, 2026-11-03)
	local haloEmitter = Vfx.Emit.make(ball, {
		name = "Halo",
		tex = "VfxGlow",
		color = AMBER,
		size = 2.9,
		alpha = { { 0, 1 }, { 0.05, 0.55 }, { 0.95, 0.55 }, { 1, 1 } },
		life = 4,
		rate = 1 / 3.8,
		locked = true,
		light = 0.8,
		bright = 0.8,
		z = -0.5,
	})
	haloEmitter:Emit(1)
	-- Two motes circling it on tilted rings, each drawing a short comet tail (moved round in step()).
	local rings = {}
	for k = 1, 2 do
		local spot = Create("Attachment", { Name = "Orbit" .. k, Parent = ball }) :: Attachment
		Vfx.Emit.make(spot, {
			tex = "VfxGlow",
			color = { { 0, CORE }, { 1, AMBER } },
			size = { { 0, 0.32 }, { 1, 0 } },
			alpha = { { 0, 0.1 }, { 1, 1 } },
			life = 0.32,
			light = 1,
			bright = 1.6,
			rate = 60,
		})
		table.insert(rings, spot)
	end
	Vfx.Emit.make(ball, {
		name = "Heart",
		tex = "VfxFlare",
		color = CORE,
		size = { { 0, 1.3 }, { 0.5, 1.6 }, { 1, 1.3 } },
		alpha = { { 0, 1 }, { 0.15, 0.25 }, { 0.85, 0.25 }, { 1, 1 } },
		life = 1.2,
		rate = 1.6,
		rot = { 0, 90 },
		spin = { -30, 30 },
		locked = true,
		light = 1,
		bright = 1.2,
		z = 0.5,
	})
	Vfx.Emit.make(ball, {
		name = "Sparks",
		tex = "VfxEmber",
		color = { { 0, CORE }, { 1, AMBER } },
		size = { { 0, 0.22 }, { 1, 0 } },
		life = { 0.8, 1.4 },
		speed = { 0.6, 1.6 },
		spread = 180,
		accel = Vector3.new(0, 1.2, 0),
		bright = 1.4,
		rate = 12,
	})
	-- A wake of light behind it (motes left where it passed, shrinking away), so the way it went stays on screen
	-- for a moment (no Trail: the shop overhaul's rule, docs/vfx.md).
	Vfx.Emit.make(ball, {
		name = "Wake",
		tex = "VfxGlow",
		color = { { 0, CORE }, { 1, AMBER } },
		size = { { 0, 0.5 }, { 1, 0 } },
		alpha = { { 0, 0.35 }, { 1, 1 } },
		life = 0.8,
		light = 1,
		bright = 1,
		rate = 26,
	})
	local lamp = Create("PointLight", {
		Color = AMBER,
		Range = 18,
		Brightness = 2,
		Shadows = false,
		Parent = ball,
	}) :: PointLight
	-- The glow around it: drawn over walls when you are far off (see step()).
	local gui = Create("BillboardGui", {
		Name = "Glow",
		Size = UDim2.fromScale(2.6, 2.6),
		LightInfluence = 0,
		AlwaysOnTop = false,
		Parent = ball,
	}) :: BillboardGui
	-- (round, never a square: the owner saw one through a wall, 2026-10-25. The kit's soft glow and its star, each
	-- clipped to a circle; plain rings of light before the Fx import)
	local function disc(size: number, image: string?, transparency: number): GuiObject
		local item = if image
			then Create("ImageLabel", {
				BackgroundTransparency = 1,
				Image = image,
				ImageColor3 = AMBER,
				ImageTransparency = transparency,
			})
			else Create("Frame", { BackgroundColor3 = AMBER, BackgroundTransparency = transparency })
		item.AnchorPoint = Vector2.new(0.5, 0.5)
		item.Position = UDim2.fromScale(0.5, 0.5)
		item.Size = UDim2.fromScale(size, size)
		item.BorderSizePixel = 0
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = item })
		item.Parent = gui
		return item
	end
	if Vfx.Tex.real("VfxGlow") then
		disc(1, Vfx.Tex.id("VfxGlow"), 0.35)
		local star = disc(0.62, Vfx.Tex.id("VfxFlare"), 0.1) :: ImageLabel
		star.ImageColor3 = CORE
	else
		disc(0.8, nil, 0.88)
		disc(0.55, nil, 0.78)
		disc(0.3, nil, 0.55)
		local heart = disc(0.12, nil, 0.05)
		heart.BackgroundColor3 = CORE
	end
	holder.PrimaryPart = ball
	holder.Parent = workspace.CurrentCamera
	model, core, shell, light, halo, haloFx, orbits = holder, ball, glow, lamp, gui, haloEmitter, rings
end

-- The pillar of light standing on the floor where you go to use the place.
local function buildPillar(at: Vector3): Model
	local floor = at - Vector3.new(0, 5, 0)
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), solidRays())
	if hit then
		floor = hit.Position
	end
	local holder = Create("Model", { Name = "TrialPillar" }) :: Model
	local beam = Create("Part", {
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(18, 0.5, 0.5),
		CFrame = CFrame.new(floor + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = CORE,
		Material = Enum.Material.Neon,
		-- (unseen: the hard neon rod read as a white pole; the column is the soft beam round it, and its embers)
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = holder,
	}) :: BasePart
	Create("Part", {
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 6, 6),
		CFrame = CFrame.new(floor + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = AMBER,
		Material = Enum.Material.Neon,
		-- (unseen: a flat neon disc looked cheap; the ring of light on the floor is its emitter's)
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = holder,
	})
	Vfx.Emit.make(beam, {
		name = "Rising",
		tex = "VfxEmber",
		color = { { 0, CORE }, { 1, AMBER } },
		size = { { 0, 0.35 }, { 1, 0 } },
		life = { 1.6, 2.6 },
		speed = { 2.5, 4.5 },
		spread = 8,
		dir = Enum.NormalId.Right, -- the cylinder's long axis points up
		bright = 1.4,
		rate = 14,
	})
	-- (streaks of light racing up a textured column inside it)
	local bottom = Create("Attachment", { Parent = beam }) :: Attachment
	bottom.WorldPosition = floor
	local top = Create("Attachment", { Parent = beam }) :: Attachment
	top.WorldPosition = floor + Vector3.new(0, 18, 0)
	Vfx.Beams.make(bottom, top, {
		tex = "VfxColumn",
		color = AMBER,
		width = 2.6,
		bright = 0.5,
		light = 1,
		speed = -6, -- (toward its top: rising)
		repeats = 9,
	}, beam)
	-- (and a ring of light on the floor round its foot)
	local ring = holder:FindFirstChild("Ring")
	if ring then
		Vfx.Emit
			.make(ring, {
				tex = "VfxRing",
				color = AMBER,
				size = 7,
				alpha = { { 0, 1 }, { 0.05, 0.4 }, { 0.95, 0.4 }, { 1, 1 } },
				life = 4,
				rate = 1 / 3.8,
				speed = 0.001,
				dir = Enum.NormalId.Right,
				face = "flat",
				locked = true,
				light = 0.8,
				bright = 1,
			})
			:Emit(1)
	end
	holder.Parent = workspace.CurrentCamera
	return holder
end

-- The arrow at the edge of the screen.
local function buildArrow(): Frame
	local frame = Kit.Base.make("Frame", {
		Name = "TrialWispArrow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		Visible = false,
		ZIndex = 5,
		Parent = Screens.hud,
	})
	local dot = Kit.Base.make("Frame", {
		Name = "Dot",
		BackgroundColor3 = AMBER,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 5,
		Parent = frame,
	})
	Kit.Base.corner(dot, 999)
	Kit.icon({
		name = "play",
		size = 22,
		color = AMBER,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 15, 0.5, 0),
		ZIndex = 5,
		Parent = frame,
	})
	return frame
end

-- The way there -------------------------------------------------------------------------------------------

-- A new path from where you stand to the place (in the background; the wisp keeps going meanwhile).
local function repath(from: Vector3, to: Vector3)
	if pathing then
		return
	end
	pathing = true
	lastPath = os.clock()
	task.spawn(function()
		-- Aim at the ground just in front of the place on your side (a desk itself is solid).
		local side = flat(from - to)
		local target = to - Vector3.new(0, HOVER + 1.5, 0)
		if side.Magnitude > 0.1 then
			target += side.Unit * 4
		end
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 5,
		})
		local ok = pcall(function()
			path:ComputeAsync(from, target)
		end)
		local points = {}
		if ok and path.Status == Enum.PathStatus.Success then
			for _, waypoint in ipairs(path:GetWaypoints()) do
				table.insert(points, waypoint.Position)
			end
		end
		if goal == to then
			waypoints = points
			pathFor = to
		end
		pathing = false
	end)
end

-- The point `ahead` studs along the path from the waypoint nearest to `from` (nil when there is no path).
local function aheadOnPath(from: Vector3, ahead: number): (Vector3?, number)
	if #waypoints < 2 then
		return nil, math.huge
	end
	local nearest, nearestDistance = 1, math.huge
	for index, point in ipairs(waypoints) do
		local distance = (point - from).Magnitude
		if distance < nearestDistance then
			nearest, nearestDistance = index, distance
		end
	end
	local left = ahead
	for index = nearest, #waypoints - 1 do
		local a, b = waypoints[index], waypoints[index + 1]
		local length = (b - a).Magnitude
		if length >= left then
			return a:Lerp(b, left / math.max(length, 0.001)), nearestDistance
		end
		left -= length
	end
	return waypoints[#waypoints], nearestDistance
end

-- Every frame --------------------------------------------------------------------------------------------

local function placeArrow(at: Vector3)
	local frame = arrow
	local camera = workspace.CurrentCamera
	if not frame or not camera then
		return
	end
	local point, onScreen = camera:WorldToViewportPoint(at)
	local size = camera.ViewportSize
	if onScreen and point.Z > 0 then
		frame.Visible = false
		return
	end
	local centre = size / 2
	local direction = Vector2.new(point.X, point.Y) - centre
	if point.Z < 0 then
		-- Behind you: the projection is mirrored.
		direction = -direction
	end
	if direction.Magnitude < 1 then
		direction = Vector2.new(0, 1)
	end
	local inset = 48
	local half = centre - Vector2.new(inset, inset)
	local scale =
		math.min(half.X / math.max(math.abs(direction.X), 0.001), half.Y / math.max(math.abs(direction.Y), 0.001))
	local spot = centre + direction * scale
	local origin = Screens.hud.AbsolutePosition
	frame.Position = UDim2.fromOffset(spot.X - origin.X, spot.Y - origin.Y)
	frame.Rotation = math.deg(math.atan2(direction.Y, direction.X))
	frame.Visible = true
end

local function step(dt: number)
	local ball, glow, here = core, shell, position
	local root = rootPart()
	if not ball or not glow or not here or not goal then
		return
	end
	local now = os.clock()
	local bob = Vector3.new(0, math.sin(now * 2.2) * 0.35, 0)
	local target = goal
	local calling = false
	local near = false
	if mode == "lead" and root then
		local player = root.Position
		near = flat(goal - player).Magnitude < CIRCLE_AT
		if near then
			-- At the place: circle over it.
			local angle = now * 1.6
			perch = perch or perchOver(goal)
			target = (perch :: Vector3) + Vector3.new(math.cos(angle) * CIRCLE, 0, math.sin(angle) * CIRCLE)
		elseif (here - player).Magnitude > WAIT_FOR then
			-- You fell behind: it stops and calls.
			target = here - bob
			calling = true
		else
			local point, off = aheadOnPath(player, LEAD)
			if point then
				target = point + Vector3.new(0, HOVER, 0)
			else
				-- No path (yet): straight towards the place.
				local towards = flat(goal - player)
				target = player + towards.Unit * math.min(LEAD, towards.Magnitude) + Vector3.new(0, HOVER, 0)
			end
			if (pathFor ~= goal or off > OFF_PATH) and now - lastPath > REPATH then
				repath(player, goal)
			end
		end
	end
	here = here:Lerp(target + bob, 1 - math.exp(-dt * 4))
	position = here
	ball.Position = here
	glow.Position = here
	-- Calling: a quick, bright pulse. Otherwise a slow breath (the halo round it swelling and settling).
	local beat = if calling then (math.sin(now * 9) + 1) / 2 else (math.sin(now * 2) + 1) / 2
	if haloFx then
		haloFx.Size = NumberSequence.new(if calling then 3.2 + beat * 1.6 else 2.8 + beat * 0.4)
	end
	-- The two motes round it, on rings tilted against each other.
	for k, spot in ipairs(orbits) do
		local angle = now * (if k == 1 then 3.1 else -2.6) + k * 2
		local ring = Vector3.new(math.cos(angle) * 0.95, 0, math.sin(angle) * 0.95)
		local tilt = CFrame.Angles(math.rad(if k == 1 then 28 else -34), 0, math.rad(if k == 1 then 12 else -18))
		spot.Position = tilt * ring
	end
	if light then
		light.Brightness = if calling then 2 + beat * 2 else 2
	end
	if halo and root then
		local far = (here - root.Position).Magnitude > SHINE_THROUGH
		halo.AlwaysOnTop = far
		halo.Size = if far then UDim2.new(2.6, 22, 2.6, 22) else UDim2.fromScale(2.6, 2.6)
	end
	-- The pillar where you stand to use the place (on your side of it, fixed once it shows), while you are on your
	-- way and close, until you are there.
	local showPillar = false
	if mode == "lead" and root then
		local away = flat(goal - root.Position).Magnitude
		if away < PILLAR_AT then
			if not stand then
				local side = flat(root.Position - goal)
				stand = if side.Magnitude > 0.1 then goal + side.Unit * STAND_OUT else goal
			end
			showPillar = flat((stand :: Vector3) - root.Position).Magnitude > ARRIVED
		end
	end
	if showPillar and not pillar then
		pillar = buildPillar(stand :: Vector3)
	elseif not showPillar and pillar then
		pillar:Destroy()
		pillar = nil
	end
	placeArrow(here)
end

-- Public ------------------------------------------------------------------------------------------------

-- Sends the wisp to a place. `key` names the place (a new key is a new journey: a fresh path and a chime);
-- the same key with a new position just moves the place (the spot in front of you during the role card).
-- mode "lead": walk you there; "wait": hover at the place.
function TrialWisp.target(key: string, at: Vector3, how: Mode)
	local root = rootPart()
	if not model then
		local start = if root then root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 3, 0) else at
		build(if how == "wait" then at else start)
		position = if how == "wait" then at else start
		arrow = arrow or buildArrow()
	end
	local fresh = key ~= goalKey
	goalKey = key
	mode = how
	if fresh or not goal or (goal - at).Magnitude > 4 then
		goal = at
		perch = nil
		if fresh then
			stand = nil
			waypoints = {}
			pathFor = nil
			if pillar then
				pillar:Destroy()
				pillar = nil
			end
			if how == "lead" then
				UiSound.play("trialChime")
				if root then
					repath(root.Position, at)
				end
			end
		end
	end
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

-- Where the wisp is now (nil when there is none).
function TrialWisp.position(): Vector3?
	return position
end

-- What it is doing, for checks: the place's key, the mode, how many waypoints its path has, the pillar.
function TrialWisp.state(): { key: string?, mode: string, waypoints: number, pillar: boolean, arrow: boolean }
	return {
		key = goalKey,
		mode = mode,
		waypoints = if pathFor == goal then #waypoints else 0,
		pillar = pillar ~= nil,
		arrow = arrow ~= nil and arrow.Visible,
	}
end

-- Takes the wisp, its pillar and its arrow away.
function TrialWisp.clear()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if model then
		model:Destroy()
	end
	if pillar then
		pillar:Destroy()
	end
	if arrow then
		arrow.Visible = false
	end
	model, core, shell, light, halo, haloFx, pillar = nil, nil, nil, nil, nil, nil, nil
	orbits = {}
	goalKey, goal, position, perch, stand = nil, nil, nil, nil, nil
	waypoints = {}
	pathFor = nil
end

return TrialWisp
