-- The Trial's wisp, on this client only: a warm amber soul-flame you follow to where the next step is done.
-- It is built to be seen and never mistaken for the pale blue lost souls a Deathsinger gathers:
--   * a bright core in a flickering flame, sparks, a ribbon of light trailing behind it, a lamp, and a glow
--     that shows through walls once you are far from it;
--   * it walks the real way there (PathfindingService, round walls and across bridges), a little ahead of
--     you; if you fall behind it stops and pulses until you catch up;
--   * when it is off the screen an amber arrow at the edge of the screen points to it;
--   * near the place itself it circles it, and a pillar of light stands there;
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
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local Motion = require(UI.Core.Motion)
local Screens = require(UI.Screens)
local UiSound = require(UI.Core.UiSound)

local LocalPlayer = Players.LocalPlayer

local TrialWisp = {}

local CORE = Color3.fromRGB(255, 228, 176)
local AMBER = Color3.fromRGB(255, 166, 72)
local EMBER = Color3.fromRGB(150, 52, 22)

local LEAD = 12 -- studs of path the wisp keeps ahead of you
local HOVER = 3.5 -- studs above the path
local WAIT_FOR = 24 -- further than this from you, it stops and calls
local CIRCLE_AT = 22 -- this close to the place (flat), it goes and circles it
local PILLAR_AT = 48 -- this close, the pillar shows
local SHINE_THROUGH = 30 -- further than this, its glow shows through walls
local REPATH = 1.5 -- seconds between new paths while you are off the old one
local OFF_PATH = 12 -- studs from the path that count as off it

type Mode = "lead" | "wait"

local model: Model? = nil
local core: BasePart? = nil
local shell: BasePart? = nil
local light: PointLight? = nil
local halo: BillboardGui? = nil
local pillar: Model? = nil
local arrow: Frame? = nil
local connection: RBXScriptConnection? = nil

local goalKey: string? = nil
local goal: Vector3? = nil
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

-- Building ------------------------------------------------------------------------------------------------

local function particleTexture(name: string, fallback: string): string
	local id = Assets.texture(name)
	return if id ~= "" then id else fallback
end

local function build(at: Vector3)
	local holder = Create("Model", { Name = "TrialWisp" }) :: Model
	local ball = Create("Part", {
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
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
		Transparency = 0.78,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Position = at,
		Parent = holder,
	}) :: BasePart
	-- The flame licks up off the core and is left behind as it moves.
	Create("ParticleEmitter", {
		Name = "Flame",
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 45,
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(0.8, 1.8),
		Acceleration = Vector3.new(0, 4, 0),
		SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(0.6, 0.9),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.7, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CORE),
			ColorSequenceKeypoint.new(0.45, AMBER),
			ColorSequenceKeypoint.new(1, EMBER),
		}),
		LightEmission = 1,
		LightInfluence = 0,
		Parent = ball,
	})
	Create("ParticleEmitter", {
		Name = "Sparks",
		Texture = particleTexture("Spark", "rbxasset://textures/particles/sparkles_main.dds"),
		Rate = 10,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(0.6, 1.6),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.2, 1),
		Color = ColorSequence.new(AMBER),
		LightEmission = 1,
		LightInfluence = 0,
		Parent = ball,
	})
	-- A wake of light behind it (motes left where it passed, shrinking away), so the way it went stays on screen
	-- for a moment (no Trail: the shop overhaul's rule, docs/vfx.md).
	Create("ParticleEmitter", {
		Name = "Wake",
		Texture = particleTexture("SoulGlow", "rbxasset://textures/particles/sparkles_main.dds"),
		Rate = 45,
		Lifetime = NumberRange.new(0.9),
		Speed = NumberRange.new(0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(CORE, AMBER),
		LightEmission = 1,
		LightInfluence = 0,
		Parent = ball,
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
		Size = UDim2.fromScale(5, 5),
		LightInfluence = 0,
		AlwaysOnTop = false,
		Parent = ball,
	}) :: BillboardGui
	local glowImage = Assets.texture("SoulGlow")
	if glowImage ~= "" then
		Create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = glowImage,
			ImageColor3 = AMBER,
			ImageTransparency = 0.15,
			Size = UDim2.fromScale(1, 1),
			Parent = gui,
		})
	else
		local dot = Create("Frame", {
			BackgroundColor3 = AMBER,
			BackgroundTransparency = 0.55,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.45, 0.45),
			Parent = gui,
		})
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
	end
	holder.PrimaryPart = ball
	holder.Parent = workspace.CurrentCamera
	model, core, shell, light, halo = holder, ball, glow, lamp, gui
end

-- The pillar of light standing on the place itself.
local function buildPillar(at: Vector3): Model
	local floor = at - Vector3.new(0, 5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { workspace.CurrentCamera }
	if LocalPlayer.Character then
		table.insert(exclude, LocalPlayer.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
	if hit then
		floor = hit.Position
	end
	local holder = Create("Model", { Name = "TrialPillar" }) :: Model
	local beam = Create("Part", {
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(18, 1.6, 1.6),
		CFrame = CFrame.new(floor + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = AMBER,
		Material = Enum.Material.Neon,
		Transparency = 0.82,
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
		Transparency = 0.7,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = holder,
	})
	Create("ParticleEmitter", {
		Name = "Rising",
		Texture = particleTexture("Spark", "rbxasset://textures/particles/sparkles_main.dds"),
		Rate = 14,
		Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(2.5, 4.5),
		SpreadAngle = Vector2.new(8, 8),
		EmissionDirection = Enum.NormalId.Right, -- the cylinder's long axis points up
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.2, 1),
		Color = ColorSequence.new(CORE, AMBER),
		LightEmission = 1,
		LightInfluence = 0,
		Parent = beam,
	})
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
			-- At the place: circle it.
			local angle = now * 1.6
			target = goal + Vector3.new(math.cos(angle) * 2.4, 0, math.sin(angle) * 2.4)
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
	-- Calling: a quick, bright pulse. Otherwise a slow breath.
	local beat = if calling then (math.sin(now * 9) + 1) / 2 else (math.sin(now * 2) + 1) / 2
	glow.Size = Vector3.one * (if calling then 2.1 + beat * 1.2 else 1.8 + beat * 0.3)
	glow.Transparency = if calling then 0.6 + (1 - beat) * 0.25 else 0.78
	if light then
		light.Brightness = if calling then 2 + beat * 2 else 2
	end
	if halo and root then
		local far = (here - root.Position).Magnitude > SHINE_THROUGH
		halo.AlwaysOnTop = far
		halo.Size = if far then UDim2.new(4, 26, 4, 26) else UDim2.fromScale(5, 5)
	end
	-- The pillar on the place, while you are on your way and close.
	local showPillar = mode == "lead" and root ~= nil and flat(goal - root.Position).Magnitude < PILLAR_AT
	if showPillar and not pillar then
		pillar = buildPillar(goal)
	elseif not showPillar and pillar then
		pillar:Destroy()
		pillar = nil
	end
	if pillar and not Motion.isReduced() then
		local beam = pillar:FindFirstChild("Beam")
		if beam and beam:IsA("BasePart") then
			beam.Transparency = 0.78 + math.sin(now * 2.4) * 0.06
		end
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
		if fresh then
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
	model, core, shell, light, halo, pillar = nil, nil, nil, nil, nil, nil
	goalKey, goal, position = nil, nil, nil
	waypoints = {}
	pathFor = nil
end

return TrialWisp
