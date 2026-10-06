-- Case-file tasks. The server picks a puzzle from the station type's pool and sends its id and
-- seed; this builds the same puzzle (Shared/Tasks/Puzzles) and shows it with its view
-- (UI/Puzzles/<id>). The answer is checked here for instant feedback and again by the server,
-- which also only accepts it after the full task time, so a task always takes about 15 s.
-- The Hand's side can fake a task instead, from a second prompt at the station.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Tasks = Shared:WaitForChild("Tasks")
local PuzzleSet = require(Tasks:WaitForChild("PuzzleSet"))
local TaskTypes = require(Tasks:WaitForChild("TaskTypes"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
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
local setProgress: (number, boolean?) -> ()
local progressLabel: TextLabel
local firstSelection: GuiObject? = nil

local current = nil

-- Views ---------------------------------------------------------------------------------------

local function fakeView()
	Kit.text({
		face = "Scrawl",
		text = "Pretending to work…",
		size = 44,
		color = C.secret,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Parent = area,
	})
	Kit.label({
		Text = "Stay at the station until the bar fills. No clue is posted and no letters flash.",
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.8, 0),
		Parent = area,
	})
end

local function mountPuzzle(task_)
	Kit.clear(area)
	firstSelection = nil
	local def = PuzzleSet.get(task_.puzzle)
	local view = Views:FindFirstChild(task_.puzzle or "")
	if not def or not view then
		hintLabel.Text = "This case file is damaged. Wait for the bar and file it anyway."
		task_.solved = true
		return
	end
	hintLabel.Text = def.hint
	local puzzle = def.generate(task_.seed)
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
			hintLabel.Text = "Done. Filing the report…"
			hintLabel.TextColor3 = C.good
			return true
		end,
		hint = function(text: string)
			hintLabel.Text = text
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
	-- Progress follows the server clock, so the bar fills exactly when the server accepts.
	local startedAt = tonumber(payload.startedAt) or workspace:GetServerTimeNow()
	current = {
		stationId = payload.stationId,
		fake = payload.fake == true,
		puzzle = payload.puzzle,
		seed = tonumber(payload.seed) or 0,
		duration = tonumber(payload.duration) or Config.TASK_DURATION,
		startedAt = startedAt,
		solved = payload.fake == true,
		answer = nil,
		submittedAt = nil,
		-- Academy practice: runs only on this client and calls this when finished.
		practice = practice,
	}
	local task_ = current
	local info = TaskTypes.INFO[payload.stationType] or TaskTypes.INFO.Camera
	win.setTitle(tostring(payload.stationName))
	Kit.Icon.set(typeIcon, info.icon)
	typeIcon.ImageColor3 = info.color
	typeLabel.Text = string.upper(info.label)
	typeLabel.TextColor3 = info.color
	hintLabel.TextColor3 = C.dim
	setProgress(0)
	Router.open("task")
	if task_.fake then
		hintLabel.Text = "Faking it."
		fakeView()
	else
		mountPuzzle(task_)
	end
end

local function update()
	local task_ = current
	if not task_ then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - task_.startedAt
	local progress = math.clamp(elapsed / task_.duration, 0, 1)
	setProgress(progress)
	if progress < 1 then
		progressLabel.Text = string.format("Working…  %d s", math.ceil(task_.duration - elapsed))
	elseif not task_.solved then
		progressLabel.Text = "Finish the puzzle to file the report."
	else
		progressLabel.Text = "Filing the report…"
	end
	if task_.solved and progress >= 1 and task_.practice then
		local done = task_.practice
		close()
		done()
		return
	end
	if task_.solved and progress >= 1 then
		if task_.submittedAt == nil or os.clock() - task_.submittedAt > 2 then
			task_.submittedAt = os.clock()
			TaskRequest:FireServer({ action = "complete", stationId = task_.stationId, answer = task_.answer })
		end
	end
end

-- Called by the station prompts: "Work case file" (fake = false) or, for the Hand's side
-- only, "Fake it" (fake = true).
function TaskScreen.request(stationId: string, fake: boolean)
	if current or not ClientState.isLiving() or ClientState.phase() ~= "Investigation" then
		return
	end
	TaskRequest:FireServer({ action = "start", stationId = stationId, fake = fake and ClientState.isKiraSide() })
end

function TaskScreen.isBusy(): boolean
	return current ~= nil
end

-- An Academy drill: a random puzzle of the station type with a shorter bar, checked only on
-- this client.
function TaskScreen.practice(stationType: string, title: string, onDone: () -> ())
	if current or not TaskTypes.exists(stationType) then
		return
	end
	local rng = Random.new()
	start({
		stationId = "practice",
		stationType = stationType,
		stationName = title,
		puzzle = TaskTypes.pickPuzzle(stationType, rng),
		seed = rng:NextInteger(1, 2 ^ 30),
		duration = 6,
		startedAt = workspace:GetServerTimeNow(),
	}, onDone)
end

function TaskScreen.init()
	win = Kit.window({ name = "task", title = "Case file", jp = "事件ファイル", size = "M" })
	local head = Kit.frame({ Name = "Head", Size = UDim2.new(1, 0, 0, 48), Parent = win.body })
	typeIcon = Kit.icon({ name = "task", size = 22, Position = UDim2.fromOffset(0, 0), Parent = head })
	typeLabel = Kit.label({
		font = "label",
		size = "micro",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(30, 3),
		Size = UDim2.new(1, -30, 0, 16),
		Parent = head,
	})
	hintLabel = Kit.label({
		size = "small",
		color = C.dim,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = head,
	})
	area = Kit.frame({
		Name = "Puzzle",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -106),
		Parent = win.body,
	})
	local _meter
	_meter, setProgress = Kit.meter({
		color = C.white,
		height = 6,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -26),
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
			if payload.fake then
				Toasts.show("Fake task done. Nothing was posted.", "secret")
			else
				Toasts.show(
					string.format(
						"Case file complete. The clue is on the evidence board, and %d letters of your real name flashed on the screen.",
						Config.LETTERS_PER_FLASH
					),
					"good"
				)
			end
		elseif payload.state == "cancelled" then
			close()
			if type(payload.reason) == "string" then
				Toasts.show(payload.reason, "bad")
			end
		elseif payload.state == "wait" and current then
			-- The server has not counted the full task time yet; retry in a second.
			current.submittedAt = os.clock() - 1
		elseif payload.state == "wrong" and current then
			-- The server did not accept the answer: start the same puzzle again.
			local task_ = current
			task_.solved = false
			task_.answer = nil
			task_.submittedAt = nil
			mountPuzzle(task_)
			hintLabel.Text = "The report was rejected. Check your work."
			hintLabel.TextColor3 = C.red
		end
	end)
	Kit.register(win, {
		allowed = function(view)
			if current and current.practice then
				return not view.participant
			end
			return view.living and view.phase == "Investigation"
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
