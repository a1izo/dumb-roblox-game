-- The verdict: every ballot is counted onto a bar per candidate (the totals are public),
-- then at the climax the gavel falls and the camera and a spotlight find the player voted
-- out. When nobody is removed, the tally stays up with a stamp instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.Parent.UI.Screens)
local Theme = require(script.Parent.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.Parent.UI.Widgets)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)

local C = Theme.colors

local ROW_HEIGHT = 34
local MAX_ROWS = 8

type Row = { name: string, count: number, userId: number? }

local function buildTally(rows: { Row }, total: number): (CanvasGroup, { [number]: Frame }, () -> ())
	local group = Instance.new("CanvasGroup")
	group.Name = "VerdictTally"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.46)
	group.Size = UDim2.fromOffset(520, 70 + math.min(#rows, MAX_ROWS) * (ROW_HEIGHT + 6))
	group.Parent = Screens.cinematic

	local header = Widgets.ribbon({ Position = UDim2.fromOffset(0, 0), Parent = group }, Terms.phase("Verdict"))
	header.ZIndex = 2
	local panel = Widgets.panel({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		Parent = group,
	})
	Widgets.padding(panel, Theme.space.md)
	Widgets.list(panel, 6)

	local rowFrames: { [number]: Frame } = {}
	local fills: { { fill: Frame, count: number, label: TextLabel } } = {}
	for index, row in ipairs(rows) do
		if index > MAX_ROWS then
			break
		end
		local frame = Widgets.frame({ Size = UDim2.new(1, 0, 0, ROW_HEIGHT), LayoutOrder = index, Parent = panel })
		Widgets.display({
			Text = string.upper(row.name),
			TextSize = Theme.text.bodyLarge,
			Size = UDim2.new(0.34, 0, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		local track = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = C.panelLight,
			Position = UDim2.fromScale(0.36, 0.18),
			Size = UDim2.new(0.52, 0, 0.64, 0),
			Parent = frame,
		})
		Widgets.slant(track, 0.02)
		local fill = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = C.paper,
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		})
		local countLabel = Widgets.display({
			Text = "0",
			TextSize = Theme.text.title,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.1, 0, 1, 0),
			Parent = frame,
		})
		if row.userId then
			rowFrames[row.userId] = frame
		end
		table.insert(fills, { fill = fill, count = row.count, label = countLabel })
	end

	local function animate()
		for index, item in ipairs(fills) do
			task.delay((index - 1) * 0.18, function()
				if not group.Parent then
					return
				end
				local share = if total > 0 then item.count / total else 0
				Motion.tween(item.fill, { Size = UDim2.fromScale(share, 1) }, 0.9, Enum.EasingStyle.Quart)
				Motion.countUp(item.label, 0, item.count, 0.9)
				if item.count > 0 then
					Sfx.play("pageTurn", { volume = 0.5, pitch = 0.9 + index * 0.05 })
				end
			end)
		end
	end
	return group, rowFrames, animate
end

-- A stamp across the tally ("TIE", "NO ONE REMOVED").
local function stamp(parent: GuiObject, text: string)
	local label = Widgets.display({
		Text = text,
		TextSize = 44,
		TextColor3 = C.accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(1, 0, 0, 56),
		Rotation = -8,
		ZIndex = 5,
		Parent = parent,
	})
	Widgets.stroke(label, C.accent, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = if Motion.isReduced() then 1 else 1.6
	scale.Parent = label
	Motion.tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
end

return function(cue)
	if not ClientState.isParticipant() then
		return
	end
	local data = cue.data
	local climax = tonumber(data.climax) or 0
	if climax <= 0 or type(data.counts) ~= "table" then
		return
	end
	local rows: { Row } = {}
	for _, item in ipairs(data.counts) do
		if type(item) == "table" then
			table.insert(rows, {
				name = tostring(item.name),
				count = tonumber(item.count) or 0,
				userId = tonumber(item.userId),
			})
		end
	end
	table.sort(rows, function(a, b)
		return a.count > b.count
	end)
	local total = tonumber(data.total) or 0

	Cinema.waitUntil(cue.at)
	local group, rowFrames, animate = buildTally(rows, total)
	Motion.fade(group, true, 0.2)
	Motion.slideIn(group, Vector2.new(0, 30), 0.3)
	animate()

	Cinema.waitUntil(cue.at + climax)
	Sfx.play("gavel")
	local removedId = tonumber(data.removedUserId)
	if removedId then
		local row = rowFrames[removedId]
		if row then
			Widgets.frame({
				BackgroundTransparency = 0.2,
				BackgroundColor3 = C.accent,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
				Parent = row,
			})
		end
		Cinema.flash(C.paper, 0.45, 0.4)
		task.wait(0.4)
		local tween = Motion.fade(group, false, 0.3)
		if tween then
			tween.Completed:Wait()
		end
		group:Destroy()
		local character = Cinema.character(removedId)
		if character then
			local token = CameraDirector.take(2.6)
			Cinema.letterbox(true)
			local removeLight = Cinema.spotlight(character)
			local removeOutline = Cinema.outline(character, C.paper)
			CameraDirector.cut(token, Cinema.faceShot(character, 8, 2, -3), 55)
			CameraDirector.move(token, Cinema.faceShot(character, 5, 1, -1), 1.6, 42)
			task.wait(1.7)
			removeOutline()
			removeLight()
			Cinema.letterbox(false)
			CameraDirector.release(token)
		end
	else
		stamp(group, if data.tie then "TIE" else "NO ONE REMOVED")
		task.wait(0.5)
		local tween = Motion.fade(group, false, 0.3)
		if tween then
			tween.Completed:Wait()
		end
		group:Destroy()
	end
end
