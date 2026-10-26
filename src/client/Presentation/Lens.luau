--!strict
-- The cutscenes' lens (the owner, 2026-10-26: "polish the cutscenes even more and make them as perfect as you can ...
-- camera movements, manipulate lighting, use extremely good vfx"): while any cutscene's frame is up
-- (Cinema.letterbox), this screen sees like a film camera. Its focus racks to the actor nearest the middle of the
-- frame (eased: a cut lands soft and pulls sharp), what lies far behind and close in front goes soft; it breathes a
-- little in the operator's hands; a fine grain moves over the picture. Low quality leaves out the focus and the
-- grain, Reduce motion the breathing. A cutscene that sets its own focus (Cinema.focus) keeps it.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.UI.Kit)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)

local Lens = {}

local BIND = "DeathsGambitLens"
local CONE = math.cos(math.rad(22)) -- how near the frame's middle an actor must be to take the focus
local FAR = 90 -- studs the focus rests at when no actor is in the frame
local BREATH = math.rad(0.16) -- the breathing's sway, at most

local on = false
local dof: DepthOfFieldEffect? = nil
local grain: ImageLabel? = nil
local focus = FAR
local lastBase: CFrame? = nil
local lastApplied: CFrame? = nil
local started = 0
local grained = 0

local cached: { Model } = {}
local cachedAt = -math.huge

-- The actors a cutscene films: the stage's copies (Presentation/Stage) and the players' bodies (looked for twice a
-- second: a win cutscene's stage holds a city of parts).
local function actors(): { Model }
	if os.clock() - cachedAt < 0.5 then
		return cached
	end
	cachedAt = os.clock()
	local list = {}
	local stage = workspace:FindFirstChild("DeathsGambitStage")
	if stage then
		for _, item in ipairs(stage:GetDescendants()) do
			if item:IsA("Model") and item:FindFirstChildOfClass("Humanoid") then
				table.insert(list, item)
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	cached = list
	return list
end

-- How far off the actor nearest the frame's middle is (its head), or nil.
local function subject(camera: Camera): number?
	local eye, look = camera.CFrame.Position, camera.CFrame.LookVector
	local best, bestDot = nil :: number?, CONE
	for _, model in ipairs(actors()) do
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") and head.Transparency < 1 then
			local to = head.Position - eye
			local distance = to.Magnitude
			if distance > 0.5 and distance < 400 then
				local dot = look:Dot(to / distance)
				if dot > bestDot then
					best, bestDot = distance, dot
				end
			end
		end
	end
	return best
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- the focus, eased towards the subject (a cutscene's own focus wins)
	if dof then
		local own = camera:FindFirstChild("CinemaFocus")
		local target = subject(camera) or FAR
		focus += (target - focus) * (1 - math.exp(-dt * 5))
		dof.FocusDistance = focus
		dof.InFocusRadius = math.clamp(focus * 0.3, 2.5, 30)
		dof.Enabled = own == nil
	end
	-- the breathing: a slow sway laid over whatever set the camera this frame (on a shot nobody moves, over the
	-- shot as it was, so it never adds up)
	if not Motion.isReduced() then
		local cf = camera.CFrame
		if lastApplied and cf == lastApplied and lastBase then
			cf = lastBase
		end
		local t = os.clock() - started
		local sway = math.min(1, t / 1.2)
		local pitch = math.noise(t * 0.31, 3.1) * BREATH * sway
		local yaw = math.noise(t * 0.23, 7.7) * BREATH * sway
		local roll = math.noise(t * 0.17, 11.3) * BREATH * 0.5 * sway
		lastBase = cf
		lastApplied = cf * CFrame.Angles(pitch, yaw, roll)
		camera.CFrame = lastApplied :: CFrame
	end
	-- the grain: its tiles jump 24 times a second, as film's do
	if grain and os.clock() - grained >= 1 / 24 then
		grained = os.clock()
		grain.Position = UDim2.fromOffset(math.random(-64, 0), math.random(-64, 0))
	end
end

local function start()
	started = os.clock()
	cachedAt = -math.huge
	focus = FAR
	lastBase, lastApplied = nil, nil
	if not Motion.isLow() then
		dof = Kit.Base.make("DepthOfFieldEffect", {
			Name = "LensFocus",
			FarIntensity = 0.28,
			NearIntensity = 0.22,
			FocusDistance = FAR,
			InFocusRadius = 20,
			Parent = workspace.CurrentCamera,
		}) :: DepthOfFieldEffect
		local id = Kit.Textures.id("UiGrain")
		if id ~= "" then
			grain = Kit.Base.make("ImageLabel", {
				Name = "LensGrain",
				BackgroundTransparency = 1,
				Image = id,
				ImageTransparency = 0.93,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(128, 128),
				Size = UDim2.new(1, 64, 1, 64),
				ZIndex = 49, -- (under the letterbox's bars)
				Parent = Screens.world,
			}) :: ImageLabel
		end
	end
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 20, step)
end

local function stop()
	pcall(function()
		RunService:UnbindFromRenderStep(BIND)
	end)
	local camera = workspace.CurrentCamera
	if camera and lastApplied and lastBase and camera.CFrame == lastApplied then
		camera.CFrame = lastBase
	end
	lastBase, lastApplied = nil, nil
	if dof then
		dof:Destroy()
		dof = nil
	end
	if grain then
		grain:Destroy()
		grain = nil
	end
end

-- On while any cutscene's frame is up (Cinema.letterbox counts them).
function Lens.set(value: boolean)
	if value == on then
		return
	end
	on = value
	if on then
		start()
	else
		stop()
	end
end

return Lens
