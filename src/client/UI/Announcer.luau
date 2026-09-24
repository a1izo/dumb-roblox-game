-- Big announcements in the middle of the screen (rounds, deaths, votes, results).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Announcer = {}

local queue = {}
local running = false
local frame: Frame
local title: TextLabel
local subtitle: TextLabel

local function setTransparency(value: number)
	frame.BackgroundTransparency = 0.25 + value * 0.75
	title.TextTransparency = value
	subtitle.TextTransparency = value
end

local function fade(from: number, to: number, duration: number)
	local steps = 12
	for i = 1, steps do
		setTransparency(from + (to - from) * (i / steps))
		task.wait(duration / steps)
	end
end

local function run()
	running = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		title.Text = item.title
		title.TextColor3 = Theme.TONES[item.tone] or Theme.TONES.neutral
		subtitle.Text = item.subtitle or ""
		frame.Visible = true
		fade(1, 0, 0.25)
		task.wait(if #queue > 0 then 2.2 else 3.2)
		fade(0, 1, 0.35)
		frame.Visible = false
	end
	running = false
end

function Announcer.show(titleText: string, subtitleText: string?, tone: string?)
	table.insert(queue, { title = titleText, subtitle = subtitleText, tone = tone })
	if #queue > 4 then
		table.remove(queue, 1)
	end
	if not running then
		task.spawn(run)
	end
end

function Announcer.init()
	frame = Widgets.frame({
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.new(0.8, 0, 0, 96),
		BackgroundTransparency = 1,
		BackgroundColor3 = Theme.colors.backdrop,
		Visible = false,
		Parent = Screens.overlay,
	})
	Widgets.sizeLimit(frame, Vector2.new(820, 96))
	Widgets.corner(frame, 12)
	title = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.fromOffset(10, 10),
		Parent = frame,
	})
	subtitle = Widgets.label({
		Font = Theme.fonts.medium,
		TextSize = 17,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 56),
		Parent = frame,
	})
	Net.event("Announce").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.title) == "string" then
			Announcer.show(payload.title, payload.subtitle, payload.tone)
		end
	end)
end

return Announcer
