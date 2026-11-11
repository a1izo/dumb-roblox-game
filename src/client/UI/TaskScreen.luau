-- Case-file tasks. The server picks a puzzle from the station type's pool and sends its id and
-- seed; this builds the same puzzle (Shared/Tasks/Puzzles) and shows it with its view
-- (UI/Puzzles/<id>). The answer is checked here for instant feedback and again by the server; a
-- solved puzzle is filed at once, with no timer.
-- Every case file done fills the Bureau's shared task bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Tasks = Shared:WaitForChild("Tasks")
local PuzzleSet = require(Tasks:WaitForChild("PuzzleSet"))
local TaskTypes = require(Tasks:WaitForChild("TaskTypes"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Common = require(script.Parent:WaitForChild("Puzzles"):WaitForChild("Common"))
local Toasts = require(script.Parent.Toasts)

local C = Kit.color

local Views = script.Parent:WaitForChild("Puzzles")

local TaskRequest = Net.event("TaskRequest")
local TaskStateRemote = Net.event("TaskState")

local TaskScreen = {}

local win: any
local typeIcon: ImageLabel
local typeLabel: TextLabel
local hintLabel: TextLabel
local area: Frame
local progressLabel: TextLabel
local firstSelection: GuiObject? = nil
-- A miss stops every pick for this long (seconds), so guessing through a puzzle costs more than thinking it out.
local MISS_LOCK = 1.1

local current = nil

-- Views ---------------------------------------------------------------------------------------

local function mountPuzzle(task_)
	Kit.clear(area)
	firstSelection = nil
	local def = PuzzleSet.get(task_.puzzle)
	local view = Views:FindFirstChild(task_.puzzle or "")
	if not def or not view then
		hintLabel.Text = "This file is damaged. Filed anyway."
		task_.solved = true
		return
	end
	hintLabel.Text = def.hint
	hintLabel.TextColor3 = C.bone
	local puzzle = def.generate(task_.seed)
	local lockedUntil = 0
	local missCount = 0
	local ctx = {
		area = area,
		puzzle = puzzle,
		def = def,
		practice = task_.practice ~= nil,
		submit = function(answer: any): boolean
			if current ~= task_ then
				return false
			end
			local ok, right = pcall(def.check, puzzle, answer)
			if not ok or not right then
				return false
			end
			task_.solved = true
			task_.answer = answer
			hintLabel.Text = "Solved. Filing it."
			hintLabel.TextColor3 = C.bone
			return true
		end,
		miss = function(gui: GuiObject?, text: string?)
			if current ~= task_ or task_.solved then
				return
			end
			missCount += 1
			local mine = missCount
			lockedUntil = os.clock() + MISS_LOCK
			hintLabel.Text = text or "Not that one."
			hintLabel.TextColor3 = C.danger
			if gui and gui.Parent then
				local cross = Common.cross(gui)
				Common.shake(gui)
				task.delay(MISS_LOCK, function()
					cross:Destroy()
				end)
			end
			task.delay(MISS_LOCK, function()
				if current == task_ and not task_.solved and missCount == mine then
					hintLabel.Text = def.hint
					hintLabel.TextColor3 = C.bone
				end
			end)
		end,
		busy = function(): boolean
			return task_.solved or current ~= task_ or os.clock() < lockedUntil
		end,
		hint = function(text: string)
			-- (a miss's line, or the solved one, stays until it is done)
			if not task_.solved and os.clock() >= lockedUntil then
				hintLabel.Text = text
				hintLabel.TextColor3 = C.bone
			end
		end,
		first = function(gui: GuiObject)
			if not firstSelection then
				firstSelection = gui
			end
		end,
	}
	local ok, err = pcall(function()
		(require(view) :: any)(ctx)
	end)
	if not ok then
		warn("[DeathsGambit] Puzzle " .. tostring(task_.puzzle) .. " failed to open: " .. tostring(err))
		task_.solved = true
		task_.answer = def.solve(puzzle)
	end
end

-- Flow ----------------------------------------------------------------------------------------

local function close()
	Router.close("task", "rule")
end

local function start(payload, practice: (() -> ())?)
	Kit.clear(area)
	current = {
		stationId = payload.stationId,
		puzzle = payload.puzzle,
		seed = tonumber(payload.seed) or 0,
		solved = false,
		answer = nil,
		submittedAt = nil,
		-- Academy practice: runs only on this client and calls this when finished.
		practice = practice,
	}
	local task_ = current
	local info = TaskTypes.INFO[payload.stationType] or TaskTypes.INFO.Camera
	win.setTitle(tostring(payload.stationName))
	Kit.Icon.set(typeIcon, info.icon)
	local def = PuzzleSet.get(payload.puzzle or "")
	typeLabel.Text = string.upper(info.label .. (if def then "   /   " .. def.title else ""))
	typeIcon.ImageColor3 = C.bone
	Router.open("task")
	mountPuzzle(task_)
end

local function update()
	local task_ = current
	if not task_ then
		return
	end
	progressLabel.Text = if task_.solved then "FILING" else ""
	-- Solved is done: the report goes in at once (practice finishes on this client).
	if task_.solved and task_.practice then
		local done = task_.practice
		close()
		done()
		return
	end
	if task_.solved then
		if task_.submittedAt == nil or os.clock() - task_.submittedAt > 2 then
			task_.submittedAt = os.clock()
			TaskRequest:FireServer({ action = "complete", stationId = task_.stationId, answer = task_.answer })
		end
	end
end

-- Called by the station prompt "Work case file" (Bureau players, alive or as a Specter).
function TaskScreen.request(stationId: string)
	if current or not ClientState.isParticipant() or ClientState.phase() ~= "Investigation" then
		return
	end
	TaskRequest:FireServer({ action = "start", stationId = stationId })
end

function TaskScreen.isBusy(): boolean
	return current ~= nil
end

-- An Academy drill: a random puzzle of the station type (or the one named), checked only on this client.
function TaskScreen.practice(stationType: string, title: string, onDone: () -> (), puzzle: string?)
	if current or not TaskTypes.exists(stationType) then
		return
	end
	local rng = Random.new()
	start({
		stationId = "practice",
		stationType = stationType,
		stationName = title,
		puzzle = puzzle or TaskTypes.pickPuzzle(stationType, rng),
		seed = rng:NextInteger(1, 2 ^ 30),
	}, onDone)
end

function TaskScreen.init()
	win = Kit.window({ name = "task", title = "Case file", jp = "事件ファイル", size = "M" })
	-- The head: what kind of file and which puzzle in small capitals, then the one thing to do, big in the hand.
	local head = Kit.frame({ Name = "Head", Size = UDim2.new(1, 0, 0, 58), Parent = win.body })
	typeIcon = Kit.icon({ name = "task", size = 20, color = C.bone, Position = UDim2.fromOffset(0, 0), Parent = head })
	typeLabel = Kit.label({
		font = "label",
		size = "micro",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 0, 20),
		Parent = head,
	})
	hintLabel = Kit.label({
		size = "lead",
		color = C.bone,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = head,
	})
	area = Kit.frame({
		Name = "Puzzle",
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -90),
		Parent = win.body,
	})
	progressLabel = Kit.label({
		font = "mono",
		size = "micro",
		color = C.dim,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = win.body,
	})

	TaskStateRemote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.state == "started" then
			start(payload)
		elseif payload.state == "done" then
			close()
			Toasts.show("Case file complete.", "good")
		elseif payload.state == "cancelled" then
			close()
			if type(payload.reason) == "string" then
				Toasts.show(payload.reason, "bad")
			end
		elseif payload.state == "wrong" and current then
			-- The server did not accept the answer: start the same puzzle again.
			local task_ = current
			task_.solved = false
			task_.answer = nil
			task_.submittedAt = nil
			mountPuzzle(task_)
			hintLabel.Text = "Rejected. Try again."
			hintLabel.TextColor3 = C.red
		end
	end)
	Kit.register(win, {
		stay = true,
		allowed = function(view)
			if current and current.practice then
				return not view.participant
			end
			return (view.living or view.specter) and view.phase == "Investigation"
		end,
		firstSelection = function()
			return firstSelection or win.close
		end,
		hide = function(reason)
			-- The player walked away from the puzzle: tell the server. When the phase ends the
			-- server has already cancelled the task.
			local real = current and not current.practice
			if real and (reason == "user" or reason == "back" or reason == "replaced") then
				TaskRequest:FireServer({ action = "cancel", stationId = current.stationId })
			end
			current = nil
			Kit.clear(area)
		end,
	})
	RunService.RenderStepped:Connect(update)
end

return TaskScreen
