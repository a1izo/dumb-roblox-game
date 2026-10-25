--!strict
-- The display settings that act on the whole screen (UI/Core/Settings, 2026-10-25): the camera's field of view
-- outside cutscenes, a brightness over the scene's own grade, a small frames-a-second counter, the HUD shown or
-- hidden, and chat bubbles. Each follows its setting the moment it changes.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Screens = require(script.Parent.Parent.UI.Screens)
local Kit = require(script.Parent.Parent.UI.Kit)
local CameraDirector = require(script.Parent.Parent.Presentation.CameraDirector)

local PlayerDisplay = {}

local C = Kit.color

local grade: ColorCorrectionEffect? = nil
local fpsLabel: TextLabel? = nil
local fpsConnection: RBXScriptConnection? = nil

-- The field of view, only while nothing else holds the camera (cutscenes save and give back their own).
local function applyFov()
	local camera = workspace.CurrentCamera
	if not camera or CameraDirector.busy() or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	camera.FieldOfView = math.clamp(tonumber(Settings.get("fov")) or 70, 60, 100)
end

local function applyBrightness()
	local value = tonumber(Settings.get("brightness")) or 0
	if math.abs(value) < 0.005 then
		if grade then
			grade:Destroy()
			grade = nil
		end
		return
	end
	if not grade or not grade.Parent then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "DGPlayerBrightness"
		cc.Parent = Lighting
		grade = cc
	end
	local cc = grade :: ColorCorrectionEffect
	cc.Brightness = value * 0.5
	cc.Contrast = -value * 0.15
end

local function applyFps()
	local on = Settings.get("showFps") == true
	if not on then
		if fpsConnection then
			fpsConnection:Disconnect()
			fpsConnection = nil
		end
		if fpsLabel then
			fpsLabel:Destroy()
			fpsLabel = nil
		end
		return
	end
	if fpsLabel then
		return
	end
	local label = Kit.label({
		Name = "Fps",
		font = "mono",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(90, 0),
		Parent = Screens.system,
	}) :: TextLabel
	fpsLabel = label
	local frames, since = 0, os.clock()
	fpsConnection = RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - since >= 0.5 then
			label.Text = string.format("%d FPS", math.floor(frames / (now - since) + 0.5))
			frames, since = 0, now
		end
	end)
end

local function applyHud()
	Screens.hud.Enabled = Settings.get("showHud") ~= false
end

local function applyBubbles()
	local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	if bubbles then
		pcall(function()
			bubbles.Enabled = Settings.get("chatBubbles") ~= false
		end)
	end
end

function PlayerDisplay.init()
	applyFov()
	applyBrightness()
	applyFps()
	applyHud()
	applyBubbles()
	Settings.Changed:Connect(function(key)
		if key == "fov" then
			applyFov()
		elseif key == "brightness" then
			applyBrightness()
		elseif key == "showFps" then
			applyFps()
		elseif key == "showHud" then
			applyHud()
		elseif key == "chatBubbles" then
			applyBubbles()
		end
	end)
	-- (a new camera, a respawn, or a cutscene giving the camera back: the setting again)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyFov)
	task.spawn(function()
		while true do
			task.wait(1)
			local camera = workspace.CurrentCamera
			local wanted = tonumber(Settings.get("fov")) or 70
			if camera and not CameraDirector.busy() and math.abs(camera.FieldOfView - 70) < 0.01 and wanted ~= 70 then
				applyFov()
			end
		end
	end)
end

return PlayerDisplay
