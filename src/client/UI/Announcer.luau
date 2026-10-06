-- Big announcements across the upper middle of the screen (rounds, deaths, votes): the title
-- slams in as Aktura lettering on a bar (red for danger, black otherwise) with a videotape glitch, and
-- the subtitle is cut in beneath it. While a full-screen overlay is up (the briefing, the results, your own
-- elimination) the queue waits, and anything older than a few seconds is dropped instead of
-- shown late.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Kit = require(script.Parent.Kit)
local Glitch = require(script.Parent.Core.Glitch)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local UiSound = require(script.Parent.Core.UiSound)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local Announcer = {}

local MAX_AGE = 6

-- tone -> bar colour, lettering colour
local TONES = {
	neutral = { C.g0, C.white },
	danger = { C.danger, C.white },
	kira = { C.danger, C.white },
	team = { C.g0, C.white },
}

-- Aktura is set in mixed case (its capitals are ornate): "ROUND 2" becomes "Round 2".
local function mixedCase(text: string): string
	if text ~= string.upper(text) then
		return text
	end
	return (
		string.gsub(text, "(%a)(%a*)", function(first: string, rest: string): string
			return string.upper(first) .. string.lower(rest)
		end)
	)
end

local queue = {}
local running = false
local group: CanvasGroup
local titleHolder: Frame
local subtitleText: any
local glitch: any

local function run()
	running = true
	while #queue > 0 do
		while Router.isBlocking() do
			task.wait(0.2)
		end
		local item = table.remove(queue, 1)
		if os.clock() - item.at <= MAX_AGE then
			local tone = TONES[item.tone] or TONES.neutral
			Kit.clear(titleHolder)
			local bannerFrame = Kit.banner({
				text = mixedCase(item.title),
				face = "Title",
				size = if Kit.Layout.isPhone() then T.size.display else 72,
				tone = tone[1],
				ink = tone[2],
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Rotation = -2,
				Parent = titleHolder,
			})
			bannerFrame.Rotation = -2
			subtitleText:set(item.subtitle or "")
			group.GroupTransparency = 0
			group.Visible = true
			glitch:enter()
			UiSound.play("slam")
			-- The slam: in from a little larger, settling hard.
			local scale = Instance.new("UIScale")
			scale.Scale = if Motion.isReduced() then 1 else 1.25
			scale.Parent = bannerFrame
			Motion.tween(scale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			subtitleText:write(0.6)
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

-- True while an announcement is on screen (the guide's tips wait for it to pass).
function Announcer.isShowing(): boolean
	return group ~= nil and group.Visible
end

function Announcer.show(titleText: string, subtitle: string?, tone: string?)
	table.insert(queue, { title = titleText, subtitle = subtitle, tone = tone, at = os.clock() })
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
	group.Position = UDim2.fromScale(0.5, 0.18)
	group.Size = UDim2.new(1, 0, 0, 190)
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.Visible = false
	titleHolder = Kit.frame({ Name = "Title", Size = UDim2.new(1, 0, 0, 110), Parent = group })
	subtitleText = Kit.text({
		face = "Semi",
		text = "",
		size = 28,
		color = C.bone,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Parent = group,
	})
	group.Parent = Screens.overlay
	glitch = Glitch.attach(group, { loop = false, enter = false })
	Net.event("Announce").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.title) == "string" then
			Announcer.show(payload.title, payload.subtitle, payload.tone)
		end
	end)
end

return Announcer
