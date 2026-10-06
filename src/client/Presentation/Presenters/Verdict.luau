-- The verdict, on a dark page that glitches in: every candidate is a name on a row and the ballots are
-- counted in as tally marks (the totals are public). At the climax the gavel falls, the name voted out
-- turns red, and the camera and a spotlight find them while the others react. When nobody is removed
-- the page gets a stamp instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Glitch = require(script.Parent.Parent.Parent.UI.Core.Glitch)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.Parent.UI.Screens)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local ShotSolver = require(script.Parent.Parent.ShotSolver)

local C = Kit.color
local T = Kit.Tokens

local ROW_HEIGHT = 52
local MAX_ROWS = 8

type Row = { name: string, count: number, userId: number? }

-- Tally marks: groups of four strokes and a fifth across them.
local function tally(count: number): string
	local groups = {}
	for _ = 1, count // 5 do
		table.insert(groups, "IIII/")
	end
	if count % 5 > 0 then
		table.insert(groups, string.rep("I", count % 5))
	end
	return table.concat(groups, " ")
end

local function buildPage(rows: { Row }): (CanvasGroup, { [number]: any }, () -> ())
	local group = Instance.new("CanvasGroup")
	group.Name = "VerdictPage"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.47)
	group.Size = UDim2.fromOffset(560, 110 + math.min(#rows, MAX_ROWS) * ROW_HEIGHT)
	group.Parent = Screens.cinematic
	local _, content = Kit.page({ tone = "black", margin = true, Parent = group })
	Kit.list(content, 0)
	Kit.text({
		face = "Head",
		text = Terms.phase("Verdict"),
		size = T.size.heading,
		LayoutOrder = 0,
		Parent = content,
	})
	local lines: { [number]: any } = {}
	local all = {}
	for index, row in ipairs(rows) do
		if index > MAX_ROWS then
			break
		end
		local line = Kit.nameLine({
			text = row.name,
			right = "",
			seed = index,
			height = ROW_HEIGHT,
			LayoutOrder = index,
			Parent = content,
		})
		line.button.Active = false
		line.button.Selectable = false
		if row.userId then
			lines[row.userId] = line
		end
		table.insert(all, { line = line, count = row.count })
	end
	local function animate()
		for index, item in ipairs(all) do
			for stroke = 1, item.count do
				task.delay((index - 1) * 0.15 + stroke * 0.12, function()
					if group.Parent then
						item.line.setRight(tally(stroke))
						Sfx.play("penScratch", { volume = 0.4, pitch = 0.9 + stroke * 0.03 })
					end
				end)
			end
		end
	end
	return group, lines, animate
end

return function(cue)
	-- Players in the case and spectators watching it (the cues carry only public things).
	if not (ClientState.isParticipant() or ClientState.isWatching()) then
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

	Cinema.waitUntil(cue.at)
	local group, lines, animate = buildPage(rows)
	local glitch = Glitch.attach(group, { loop = false })
	animate()

	Cinema.waitUntil(cue.at + climax)
	Sfx.play("gavel")
	local removedId = tonumber(data.removedUserId)
	if removedId then
		local line = lines[removedId]
		if line then
			line.setMarked(true)
			line.name:setColor(C.red)
		end
		Cinema.flash(C.bone, 0.4, 0.35)
		task.wait(0.6)
		local tween = Motion.fade(group, false, 0.3)
		if tween then
			tween.Completed:Wait()
		end
		glitch:destroy()
		group:Destroy()
		local character = Cinema.character(removedId)
		if character then
			local token = CameraDirector.take(2.8)
			Cinema.letterbox(true)
			local removeLight = Cinema.spotlight(character)
			local removeOutline = Cinema.outline(character, C.bone)
			CameraDirector.cut(token, ShotSolver.frame(character, { distance = 8, height = 2, angle = -22 }), 55)
			CameraDirector.move(token, ShotSolver.frame(character, { distance = 5, height = 1, angle = -8 }), 1.8, 42)
			local stamp = Kit.stamp({
				text = "Their role stays secret",
				color = C.white,
				width = 420,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.76),
				ZIndex = 5,
				Parent = Screens.cinematic,
			})
			Motion.pop(stamp)
			task.wait(1.9)
			stamp:Destroy()
			removeOutline()
			removeLight()
			Cinema.letterbox(false)
			CameraDirector.release(token)
		end
	else
		local stamp = Kit.stamp({
			text = if data.tie then "Tie" else "No one removed",
			color = C.white,
			width = 360,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			ZIndex = 5,
			Parent = group,
		})
		Motion.pop(stamp)
		task.wait(0.8)
		local tween = Motion.fade(group, false, 0.3)
		if tween then
			tween.Completed:Wait()
		end
		glitch:destroy()
		group:Destroy()
	end
end
