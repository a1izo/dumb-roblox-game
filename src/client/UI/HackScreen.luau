-- Hacking a station's log (Diavolo and the Muertos), after GTA Online's data crack: a column of
-- symbols scrolls past a window, and the player locks it when the target symbol sits in the window.
-- Three columns, each faster than the last, with a short "decrypting" pause between them. Locking on
-- anything else, or letting a column run too long, is a miss: the server sets off the station's
-- alarm for everyone. The server only ever hears pass or miss per column (HackService checks the
-- rest: the order, and that no hack is quicker than a person could play it).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Toasts = require(script.Parent.Toasts)

local HackRemote = Net.event("Hack")
local HackStateRemote = Net.event("HackState")

local C = Kit.color

local HackScreen = {}

local ROW = 44 -- px between two symbols
local ROWS = 7 -- symbols in view
local WINDOW_ROW = 3 -- the window's row (0-based, from the top)
local TOLERANCE = 0.32 -- how far off the window's middle a lock still counts, in rows
local SPEEDS = { 120, 170, 230 } -- px a second, per column
local BOOT = 1 -- seconds before the first column moves
local DECRYPT = 2 -- seconds between two columns
local COLUMN_LIMIT = 7 -- seconds a column may run before it counts as a miss
local SYMBOLS = { "A3", "7F", "C9", "1E", "B4", "5D", "E2", "08", "9A", "F6", "3C", "D7", "6B", "2F" }

local win: any
local stationLabel: TextLabel
local stageLabel: TextLabel
local targetText: any
local column: Frame
local labels: { TextLabel } = {}
local statusLabel: TextLabel
local lockButton: TextButton

-- The hack in progress (nil when none).
local current: {
	stationId: string,
	stages: number,
	stage: number,
	seed: number,
	sequence: { string },
	target: string,
	startedAt: number,
	state: string, -- "boot", "run", "decrypt", "wait" (for the server), "done"
	stateUntil: number,
}? =
	nil

-- The column's symbols: random, with the target coming round every three to five rows.
local function makeSequence(rng: Random, target: string): { string }
	local list = {}
	local others = {}
	for _, symbol in ipairs(SYMBOLS) do
		if symbol ~= target then
			table.insert(others, symbol)
		end
	end
	local nextTarget = rng:NextInteger(4, 6)
	for i = 1, 400 do
		if i == nextTarget then
			table.insert(list, target)
			nextTarget = i + rng:NextInteger(3, 5)
		else
			table.insert(list, others[rng:NextInteger(1, #others)])
		end
	end
	return list
end

local function setupStage(hack, index: number)
	local rng = Random.new(hack.seed + index * 7919)
	hack.stage = index
	hack.target = SYMBOLS[rng:NextInteger(1, #SYMBOLS)]
	hack.sequence = makeSequence(rng, hack.target)
	hack.startedAt = os.clock()
	hack.state = "run"
	stageLabel.Text = string.format("COLUMN %d / %d", index, hack.stages)
	targetText:set(hack.target)
	statusLabel.Text = "Lock it inside the window."
	statusLabel.TextColor3 = C.dim
	Kit.setEnabled(lockButton, true)
end

-- Where the column is now: the symbol nearest the window and how far off its middle (in rows).
local function inWindow(hack): (string, number)
	local position = (os.clock() - hack.startedAt) * SPEEDS[hack.stage]
	local top = math.floor(position / ROW)
	local fraction = position - top * ROW
	local row = if fraction >= ROW / 2 then WINDOW_ROW + 1 else WINDOW_ROW
	local offset = (fraction - (row - WINDOW_ROW) * ROW) / ROW
	return hack.sequence[top + row + 1] or "", offset
end

local function draw(hack)
	local position = if hack.state == "run" then (os.clock() - hack.startedAt) * SPEEDS[hack.stage] else 0
	local top = math.floor(position / ROW)
	local fraction = position - top * ROW
	for i, label in ipairs(labels) do
		local row = i - 1
		label.Position = UDim2.new(0, 0, 0, row * ROW - fraction)
		local symbol = if hack.sequence then hack.sequence[top + row + 1] or "" else ""
		label.Text = symbol
		label.TextColor3 = if symbol == hack.target then C.danger else C.dim
	end
end

local function report(index: number, ok: boolean)
	HackRemote:FireServer({ action = "stage", index = index, ok = ok })
end

local function miss()
	local hack = current
	if not hack or hack.state ~= "run" then
		return
	end
	hack.state = "wait"
	Kit.setEnabled(lockButton, false)
	statusLabel.Text = "MISSED. Alarm!"
	statusLabel.TextColor3 = C.danger
	report(hack.stage, false)
end

local function lock()
	local hack = current
	if not hack or hack.state ~= "run" then
		return
	end
	local symbol, offset = inWindow(hack)
	if symbol ~= hack.target or math.abs(offset) > TOLERANCE then
		miss()
		return
	end
	-- A pass: the column is cracked; the next one starts after a short decrypt. The last one is
	-- reported once its decrypt is done, so the whole hack takes as long as a person plays it.
	Kit.setEnabled(lockButton, false)
	statusLabel.Text = "Cracked"
	statusLabel.TextColor3 = C.good
	if hack.stage < hack.stages then
		report(hack.stage, true)
	end
	hack.state = "decrypt"
	hack.stateUntil = os.clock() + DECRYPT
end

local function update()
	local hack = current
	if not hack then
		return
	end
	if hack.state == "boot" and os.clock() >= hack.stateUntil then
		setupStage(hack, 1)
	elseif hack.state == "run" then
		if os.clock() - hack.startedAt > COLUMN_LIMIT then
			miss()
		end
	elseif hack.state == "decrypt" and os.clock() >= hack.stateUntil then
		if hack.stage < hack.stages then
			setupStage(hack, hack.stage + 1)
		else
			hack.state = "wait"
			statusLabel.Text = "Reading log"
			report(hack.stage, true)
		end
	end
	draw(hack)
end

local function close()
	Router.close("hack", "rule")
end

local function start(payload)
	current = {
		stationId = payload.stationId,
		stages = tonumber(payload.stages) or 3,
		stage = 0,
		seed = tonumber(payload.seed) or 1,
		sequence = {},
		target = "",
		startedAt = os.clock(),
		state = "boot",
		stateUntil = os.clock() + BOOT,
	}
	stationLabel.Text = string.upper(tostring(payload.stationName or ""))
	stageLabel.Text = "CONNECTING"
	targetText:set("--")
	statusLabel.Text = "Hacking"
	statusLabel.TextColor3 = C.dim
	Kit.setEnabled(lockButton, false)
	Router.open("hack")
end

-- Called by the station prompt "Hack the log".
function HackScreen.request(stationId: string)
	if current then
		return
	end
	HackRemote:FireServer({ action = "start", stationId = stationId })
end

function HackScreen.isBusy(): boolean
	return current ~= nil
end

function HackScreen.init()
	win = Kit.window({ name = "hack", title = "Hacking", jp = "ハッキング", size = "M" })
	local body = win.body
	stationLabel = Kit.label({ font = "label", size = "micro", color = C.dim, Parent = body })
	stageLabel = Kit.label({
		font = "label",
		size = "micro",
		color = C.bone,
		Position = UDim2.fromOffset(0, 20),
		Parent = body,
	})
	Kit.label({
		Text = "TARGET",
		font = "label",
		size = "micro",
		color = C.dim,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -90, 0, 6),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = body,
	})
	targetText = Kit.num({
		text = "--",
		size = 34,
		color = C.danger,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Parent = body,
	})
	-- The column, clipped to ROWS symbols, and the window across its middle.
	column = Kit.frame({
		Name = "Column",
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(160, ROW * ROWS),
		Parent = body,
	})
	column.BackgroundTransparency = 0.2
	column.BackgroundColor3 = C.g0
	Kit.Base.make("Frame", {
		Name = "Window",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, WINDOW_ROW * ROW),
		Size = UDim2.new(1, 0, 0, ROW),
		ZIndex = 5,
		Parent = column,
	})
	local window = column:FindFirstChild("Window") :: Frame
	Kit.Base.make("UIStroke", { Color = C.danger, Thickness = 2, Parent = window })
	for i = 1, ROWS + 1 do
		local label = Kit.label({
			Text = "",
			font = "mono",
			TextScaled = true,
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, ROW),
			Position = UDim2.fromOffset(0, (i - 1) * ROW),
			Parent = column,
		})
		table.insert(labels, label)
	end
	statusLabel = Kit.label({
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -64),
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = body,
	})
	lockButton = Kit.button({
		text = "Lock  (Space)",
		icon = "lock",
		variant = "primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 52),
		Parent = body,
	}, lock)

	HackStateRemote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.state == "started" then
			start(payload)
		elseif payload.state == "read" then
			if current then
				current.state = "done"
			end
			statusLabel.Text = string.format("%s is %s.", tostring(payload.alias), tostring(payload.name))
			statusLabel.TextColor3 = C.good
			task.delay(1.6, close)
		elseif payload.state == "empty" then
			if current then
				current.state = "done"
			end
			statusLabel.Text = "Nobody used this lately."
			task.delay(1.6, close)
		elseif payload.state == "stopped" then
			close()
			if type(payload.reason) == "string" then
				Toasts.show(payload.reason, "bad")
			end
		end
	end)
	Kit.register(win, {
		allowed = function(view)
			return view.living and view.phase == "Investigation" and (view.role == "Kira" or view.role == "Follower")
		end,
		show = function()
			ContextActionService:BindActionAtPriority("DeathsGambit_HackLock", function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					lock()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		end,
		firstSelection = function()
			return lockButton
		end,
		hide = function(reason)
			ContextActionService:UnbindAction("DeathsGambit_HackLock")
			-- Walked away from it: the server ends the hack quietly (no alarm).
			local hack = current
			if hack and hack.state ~= "done" and (reason == "user" or reason == "back" or reason == "replaced") then
				HackRemote:FireServer({ action = "cancel" })
			end
			current = nil
		end,
	})
	RunService.RenderStepped:Connect(update)
end

return HackScreen
