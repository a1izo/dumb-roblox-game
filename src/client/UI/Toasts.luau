-- Short notifications stacked on the right side of the screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Toasts = {}

local MAX_TOASTS = 5
local LIFETIME = 6

local container: Frame? = nil
local order = 0

local function trim(holder: Frame)
	local current = {}
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(current, child)
		end
	end
	table.sort(current, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = MAX_TOASTS + 1, #current do
		current[i]:Destroy()
	end
end

function Toasts.show(text: string, kind: string?)
	local holder = container
	if not holder then
		return
	end
	order += 1
	local color = Theme.TOAST_COLORS[kind or "info"] or Theme.TOAST_COLORS.info
	local toast = Widgets.panel({
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 0.12,
		LayoutOrder = -order,
		Parent = holder,
	})
	Widgets.padding(toast, 10, 12)
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Size = UDim2.new(0, 3, 1, 0),
		Parent = toast,
	})
	local label = Widgets.label({
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Position = UDim2.fromOffset(10, 0),
		Text = text,
		TextColor3 = color,
		TextSize = 15,
		Font = Theme.fonts.medium,
		Parent = toast,
	})
	trim(holder)

	task.delay(LIFETIME, function()
		if not toast.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		local tween = TweenService:Create(toast, info, { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

function Toasts.init()
	local holder = Widgets.frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 110),
		Size = UDim2.new(0.3, 0, 0.6, 0),
		Parent = Screens.toast,
	})
	Widgets.sizeLimit(holder, Vector2.new(360, 2000), Vector2.new(220, 0))
	Widgets.list(holder, 8)
	container = holder
	Net.event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			Toasts.show(payload.text, payload.kind)
		end
	end)
end

return Toasts
