--!strict
-- The cutscenes' lens (the owner, 2026-10-26: "polish the cutscenes even more and make them as perfect as you can ...
-- camera movements, manipulate lighting, use extremely good vfx"): while any cutscene's frame is up
-- (Cinema.letterbox), this screen sees like a film camera: it breathes a little in the operator's hands and a fine
-- grain moves over the picture. Low quality leaves out the grain, Reduce motion the breathing. (No blur of its own:
-- the owner, 2026-10-28, had the depth of field it laid over every cutscene taken out; a cutscene that wants focus
-- sets its own, Cinema.focus or a shot's focus events.)

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Parent.UI.Kit)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)

local Lens = {}

local BIND = "DeathsGambitLens"
local BREATH = math.rad(0.16) -- the breathing's sway, at most

local on = false
local grain: ImageLabel? = nil
local lastBase: CFrame? = nil
local lastApplied: CFrame? = nil
local started = 0
local grained = 0

local function step(_dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
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
	lastBase, lastApplied = nil, nil
	if not Motion.isLow() then
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
