--!strict
-- Light cues for cutscenes (the owner, 2026-10-26: "use camera movements, manipulate lightning"): the room's own
-- lamps stutter and sink when a body falls or a verdict lands, and a hard light from above and behind picks someone
-- out of the dark, their outline burning. On this screen alone; everything goes back as it was after. Flashes off
-- (Settings) keeps the dip and leaves out the stutter.
--
--   local undip = StageLight.dip(position, 40, 0.4, 3)
--   local unrim = StageLight.rim(character, camera.CFrame.Position, Color3.fromRGB(255, 60, 60), 3)

local TweenService = game:GetService("TweenService")

local Create = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Create"))
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local LightingController = require(script.Parent.Parent.World.LightingController)

local StageLight = {}

local SLOW = TweenInfo.new(0.8, Enum.EasingStyle.Sine)

-- The lamps within `radius` of `at` stutter (off, on, off) and sink to `to` of their light, for `seconds`, then
-- come back up over a moment. Returns a function that brings them back sooner.
function StageLight.dip(at: Vector3, radius: number?, to: number?, seconds: number?): () -> ()
	local lamps = LightingController.lampsNear(at, radius or 40)
	local level = to or 0.45
	local resting: { [Light]: number } = {}
	for _, light in ipairs(lamps) do
		resting[light] = LightingController.lampBrightness(light) or light.Brightness
	end
	local back = false
	task.spawn(function()
		local steps = if Motion.flashesOff() then { level } else { 0.08, 0.85, 0.04, level }
		for _, k in ipairs(steps) do
			if back then
				return
			end
			for light, brightness in pairs(resting) do
				if light.Parent then
					light.Brightness = brightness * k
				end
			end
			task.wait(0.05 + math.random() * 0.06)
		end
	end)
	local function restore()
		if back then
			return
		end
		back = true
		for light in pairs(resting) do
			if light.Parent then
				local brightness = LightingController.lampBrightness(light) or resting[light]
				TweenService:Create(light, SLOW, { Brightness = brightness }):Play()
			end
		end
	end
	task.delay(seconds or 3, restore)
	return restore
end

-- A hard light from above and behind `model` (behind as seen from `eye`, the camera), in `color`, fading in.
-- Returns a function that fades it out and takes it away.
function StageLight.rim(model: Model, eye: Vector3?, color: Color3?, brightness: number?): () -> ()
	local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
	if not (root and root:IsA("BasePart")) then
		return function() end
	end
	local at = root.Position
	local camera = workspace.CurrentCamera
	local from = eye or (if camera then camera.CFrame.Position else at + Vector3.new(0, 0, -10))
	local away = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	local holder = Create("Part", {
		Name = "StageRim",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.lookAt(at + away * 4.5 + Vector3.new(0, 7, 0), at + Vector3.new(0, 1, 0)),
		Parent = workspace,
	})
	local light = Create("SpotLight", {
		Face = Enum.NormalId.Front,
		Angle = 50,
		Range = 18,
		Brightness = 0,
		Shadows = true,
		Color = color or Color3.fromRGB(255, 230, 210),
		Parent = holder,
	}) :: SpotLight
	TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Brightness = brightness or 3 }):Play()
	local gone = false
	return function()
		if gone then
			return
		end
		gone = true
		local fade = TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Brightness = 0 })
		fade.Completed:Once(function()
			holder:Destroy()
		end)
		fade:Play()
	end
end

return StageLight
