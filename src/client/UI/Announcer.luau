-- Big announcements across the upper middle of the screen (rounds, deaths, votes).
-- While a full-screen overlay is up (the briefing, the results, your own elimination) the
-- queue waits, and anything older than a few seconds is dropped instead of shown late.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Announcer = {}

local MAX_AGE = 6

local queue = {}
local running = false
local group: CanvasGroup
local rule: Frame
local title: TextLabel
local subtitle: TextLabel

local function run()
	running = true
	while #queue > 0 do
		while Router.isBlocking() do
			task.wait(0.2)
		end
		local item = table.remove(queue, 1)
		if os.clock() - item.at <= MAX_AGE then
			local color = Theme.TONES[item.tone] or Theme.TONES.neutral
			title.Text = item.title
			title.TextColor3 = color
			rule.BackgroundColor3 = color
			subtitle.Text = item.subtitle or ""
			subtitle.Visible = subtitle.Text ~= ""
			Motion.fade(group, true, 0.25)
			Motion.slideIn(group, Vector2.new(0, -12), 0.3)
			task.wait(if #queue > 0 then 2.2 else 3.2)
			local tween = Motion.fade(group, false, 0.35)
			if tween then
				tween.Completed:Wait()
			end
			group.Visible = false
		end
	end
	running = false
end

function Announcer.show(titleText: string, subtitleText: string?, tone: string?)
	table.insert(queue, { title = titleText, subtitle = subtitleText, tone = tone, at = os.clock() })
	if #queue > 4 then
		table.remove(queue, 1)
	end
	if not running then
		task.spawn(run)
	end
end

function Announcer.init()
	group = Instance.new("CanvasGroup")
	group.Name = "Announcement"
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.fromScale(0.5, 0.17)
	group.Size = UDim2.new(0.8, 0, 0, 0)
	group.AutomaticSize = Enum.AutomaticSize.Y
	group.BackgroundColor3 = Theme.colors.backdrop
	group.BackgroundTransparency = 0.2
	group.BorderSizePixel = 0
	group.Visible = false
	Widgets.sizeLimit(group, Vector2.new(760, 200))
	Widgets.corner(group, Theme.radius.lg)
	Widgets.padding(group, Theme.space.md, Theme.space.xl)
	Widgets.list(group, Theme.space.xs, false, Enum.HorizontalAlignment.Center)
	title = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 1,
		Parent = group,
	})
	rule = Widgets.frame({
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(48, 2),
		LayoutOrder = 2,
		Parent = group,
	})
	subtitle = Widgets.label({
		Font = Theme.fonts.medium,
		TextSize = Theme.text.bodyLarge,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = group,
	})
	group.Parent = Screens.overlay
	Net.event("Announce").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.title) == "string" then
			Announcer.show(payload.title, payload.subtitle, payload.tone)
		end
	end)
end

return Announcer
