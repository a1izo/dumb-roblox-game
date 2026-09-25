-- Short notifications stacked on the right: torn paper slips with an ink mark in the kind's
-- colour. Each one slides in from the edge and fades away after a few seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Screens = require(script.Parent.Screens)

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
	-- A CanvasGroup so the slip fades as one piece.
	local group = Instance.new("CanvasGroup")
	group.Name = "Toast"
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.Size = UDim2.fromOffset(340, 0)
	group.AutomaticSize = Enum.AutomaticSize.Y
	group.LayoutOrder = -order
	local slip = Kit.slip({ text = text, kind = kind, width = 340, Parent = group })
	local _ = slip
	group.Parent = holder
	trim(holder)
	Motion.fade(group, true, Kit.Tokens.motion.base)
	Motion.slideIn(group, Vector2.new(40, 0), Kit.Tokens.motion.slow)

	task.delay(LIFETIME, function()
		if not group.Parent then
			return
		end
		local tween = Motion.fade(group, false, 0.4)
		if tween then
			tween.Completed:Wait()
		end
		group:Destroy()
	end)
end

function Toasts.init()
	local holder = Kit.frame({
		Name = "Toasts",
		Size = UDim2.new(0, 340, 0.6, 0),
		Parent = Screens.toast,
	})
	Kit.Layout.place(holder, "right")
	Kit.list(holder, Kit.space.s, false, Enum.HorizontalAlignment.Right)
	container = holder
	Kit.Layout.watch(function(class)
		holder.Position = if class == "phone" then UDim2.new(1, -12, 0, 64) else Kit.Layout.ZONES.right.position
	end)
	Net.event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			Toasts.show(payload.text, payload.kind)
		end
	end)
end

return Toasts
