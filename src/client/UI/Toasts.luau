-- Short notifications stacked on the right side of the screen. Each toast slides in and
-- fades out as a whole (text, border and colour bar together).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Motion = require(script.Parent.Core.Motion)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Toasts = {}

local MAX_TOASTS = 4
local LIFETIME = 6

local container: Frame? = nil
local order = 0

local function trim(holder: Frame)
	local current = {}
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("CanvasGroup") then
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
	local toast = Instance.new("CanvasGroup")
	toast.BackgroundColor3 = Theme.colors.panel
	toast.BackgroundTransparency = 0.06
	toast.BorderSizePixel = 0
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.Size = UDim2.new(1, 0, 0, 0)
	toast.LayoutOrder = -order
	Widgets.corner(toast, Theme.radius.md)
	Widgets.stroke(toast, color, 1, 0.6)
	Widgets.padding(toast, Theme.space.sm + 2, Theme.space.md)
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(-Theme.space.md, -Theme.space.sm - 2),
		Size = UDim2.new(0, 3, 1, Theme.space.sm * 2 + 4),
		Parent = toast,
	})
	Widgets.label({
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = text,
		TextColor3 = color,
		TextSize = Theme.text.body,
		Font = Theme.fonts.medium,
		Parent = toast,
	})
	toast.Parent = holder
	trim(holder)
	Motion.fade(toast, true, 0.2)

	task.delay(LIFETIME, function()
		if not toast.Parent then
			return
		end
		local tween = Motion.fade(toast, false, 0.4)
		if tween then
			tween.Completed:Wait()
		end
		toast:Destroy()
	end)
end

function Toasts.init()
	local holder = Widgets.frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 96),
		Size = UDim2.new(0.3, 0, 0.6, 0),
		Parent = Screens.toast,
	})
	Widgets.sizeLimit(holder, Vector2.new(340, 2000), Vector2.new(220, 0))
	Widgets.list(holder, Theme.space.sm)
	container = holder
	Net.event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			Toasts.show(payload.text, payload.kind)
		end
	end)
end

return Toasts
