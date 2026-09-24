-- Device class and UI scale. Panels are laid out at desktop size; the UIScale in every
-- ScreenGui shrinks or grows them to fit the screen, times the player's own UI scale.
--   phone   : touch screen with a short side under 500 px
--   tablet  : other touch screens
--   console : TV / ten-foot interface
--   desktop : everything else

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local Screens = require(script.Parent.Parent.Screens)

local Responsive = {}

-- Fired as (class, scale) when either changes.
Responsive.Changed = Signal.new()

local currentClass = "desktop"
local currentScale = 1
local userScale = 1

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function classify(size: Vector2): string
	if GuiService:IsTenFootInterface() then
		return "console"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return if math.min(size.X, size.Y) < 500 then "phone" else "tablet"
	end
	return "desktop"
end

local function baseScale(class: string, size: Vector2): number
	if class == "phone" then
		return math.clamp(size.Y / 500, 0.72, 1)
	elseif class == "tablet" then
		return math.clamp(size.Y / 760, 0.85, 1.1)
	elseif class == "console" then
		return 1.25
	end
	return math.clamp(math.min(size.X / 1280, size.Y / 820), 0.8, 1.25)
end

local function apply()
	local size = viewport()
	local class = classify(size)
	local scale = baseScale(class, size) * userScale
	for _, gui in ipairs(Screens.all) do
		local uiScale = gui:FindFirstChild("DeviceScale")
		if uiScale and uiScale:IsA("UIScale") then
			uiScale.Scale = scale
		end
	end
	if class ~= currentClass or math.abs(scale - currentScale) > 1e-3 then
		currentClass = class
		currentScale = scale
		Responsive.Changed:Fire(class, scale)
	end
end

function Responsive.class(): string
	return currentClass
end

function Responsive.isTouch(): boolean
	return currentClass == "phone" or currentClass == "tablet"
end

function Responsive.scale(): number
	return currentScale
end

-- The player's own UI scale from the settings (0.8 to 1.25).
function Responsive.setUserScale(value: number)
	userScale = math.clamp(value, 0.8, 1.25)
	apply()
end

-- Picks a value for the current device class, falling back to `desktop`.
function Responsive.pick<T>(options: { [string]: T }): T
	local value = options[currentClass]
	if value == nil and currentClass == "tablet" then
		value = options.phone
	end
	if value == nil then
		value = options.desktop
	end
	return value :: T
end

function Responsive.init()
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		apply()
	end)
	UserInputService.LastInputTypeChanged:Connect(apply)
	watchCamera()
	apply()
end

-- Classify right away so panels built during init already pick the right layout.
apply()

return Responsive
