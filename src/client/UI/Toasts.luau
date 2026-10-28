-- Short notifications stacked on the right: notices (Kit/Notice) with an accent in the kind's colour. Each one
-- slides in, and fades away after a few seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Screens = require(script.Parent.Screens)

local Toasts = {}

local MAX_TOASTS = 4
local LIFETIME = 6

local GAP = 8 -- px between a panel holding the top right corner and the first toast

local container: Frame? = nil
local order = 0
local below = 0 -- how far down (design px) a panel in the top right corner reaches (0: none)

-- Where the stack starts: its zone, or under the panel in the top right corner when that reaches lower.
local function place()
	local holder = container
	if not holder then
		return
	end
	local base = if Kit.Layout.isPhone() then UDim2.new(1, -12, 0, 64) else Kit.Layout.ZONES.right.position
	local y = if below > 0 then math.max(base.Y.Offset, below + GAP) else base.Y.Offset
	holder.Position = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, y)
end

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
	local group = Kit.slip({ text = text, kind = kind, LayoutOrder = -order, Parent = holder })
	group.Name = "Toast"
	trim(holder)
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

-- A panel holds the top right corner down to `bottom` design px (the Trial's step; 0 when it is gone): the
-- toasts start under it instead of over it.
function Toasts.keepBelow(bottom: number)
	below = bottom
	place()
end

function Toasts.init()
	local holder = Kit.frame({
		Name = "Toasts",
		Size = UDim2.new(0, Kit.Tokens.notice.width, 0.6, 0),
		Parent = Screens.toast,
	})
	Kit.Layout.place(holder, "right")
	Kit.list(holder, Kit.space.s, false, Enum.HorizontalAlignment.Right)
	container = holder
	Kit.Layout.watch(place)
	Net.event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			Toasts.show(payload.text, payload.kind)
		end
	end)
end

return Toasts
