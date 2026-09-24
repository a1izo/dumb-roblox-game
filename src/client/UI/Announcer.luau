-- Big announcements across the upper middle of the screen (rounds, deaths, votes): a tilted
-- ribbon with the title and a black strip with the subtitle, like a manga panel caption.
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

local C = Theme.colors

local Announcer = {}

local MAX_AGE = 6

-- tone -> ribbon colour, title colour
local TONES = {
	neutral = { C.paper, C.ink },
	danger = { C.accent, C.paper },
	kira = { C.accent, C.paper },
	team = { C.team, C.paper },
}

local queue = {}
local running = false
local group: CanvasGroup
local titleRibbon: Frame
local title: TextLabel
local subtitleStrip: Frame
local subtitle: TextLabel

local function run()
	running = true
	while #queue > 0 do
		while Router.isBlocking() do
			task.wait(0.2)
		end
		local item = table.remove(queue, 1)
		if os.clock() - item.at <= MAX_AGE then
			local tone = TONES[item.tone] or TONES.neutral
			titleRibbon.BackgroundColor3 = tone[1]
			title.TextColor3 = tone[2]
			title.Text = string.upper(item.title)
			subtitle.Text = item.subtitle or ""
			subtitleStrip.Visible = subtitle.Text ~= ""
			Motion.fade(group, true, 0.2)
			Motion.slideIn(titleRibbon, Vector2.new(-60, 0), 0.3)
			Motion.slideIn(subtitleStrip, Vector2.new(60, 0), 0.35)
			task.wait(if #queue > 0 then 2.2 else 3.2)
			local tween = Motion.fade(group, false, 0.3)
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
	group.Position = UDim2.fromScale(0.5, 0.2)
	group.Size = UDim2.new(1, 0, 0, 150)
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.Visible = false
	titleRibbon = Widgets.frame({
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(0, 64),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = Theme.tilt,
		Parent = group,
	})
	Widgets.slant(titleRibbon, 0.04)
	Widgets.padding(titleRibbon, 0, 48)
	title = Widgets.display({
		TextSize = 44,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = titleRibbon,
	})
	subtitleStrip = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.ink,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 30, 0, 90),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = Theme.tilt,
		Parent = group,
	})
	Widgets.slant(subtitleStrip, 0.04)
	Widgets.padding(subtitleStrip, 0, 30)
	subtitle = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.bodyLarge,
		TextColor3 = C.paper,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = subtitleStrip,
	})
	-- An ink splat behind the title ribbon.
	Widgets.inkSplat({
		ImageTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -40, 0, -30),
		Size = UDim2.fromOffset(240, 200),
		Rotation = 8,
		ZIndex = 0,
		Parent = group,
	}, 1)
	group.Parent = Screens.overlay
	Net.event("Announce").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.title) == "string" then
			Announcer.show(payload.title, payload.subtitle, payload.tone)
		end
	end)
end

return Announcer
