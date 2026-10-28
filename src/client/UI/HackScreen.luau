-- Hacking a station's log (Diavolo and the Muertos), after GTA Online's hacks. Each hack is one of
-- three games, picked by the server's seed, played over three stages with a short decrypt between:
--   crack       the data crack: a column of symbols scrolls past a window; lock it when the target
--               symbol sits in the window.
--   voltage     the Voltlab: wire three numbers to the x1, x2 and x10 multipliers so their sum hits
--               the target.
--   fingerprint the casino's fingerprint clone: pick the four pieces that make up the print out of
--               eight.
-- A wrong answer, or a stage left too long, is a miss: the server sets off the station's alarm. The
-- server only ever hears pass or miss per stage (HackService checks the rest: the order, and that no
-- hack is quicker than a person could play it).

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

local GAMES = { "crack", "voltage", "fingerprint" }
local BOOT = 1 -- seconds before the first stage
local DECRYPT = 2 -- seconds between two stages
local LIMIT = { crack = 7, voltage = 16, fingerprint = 14 } -- seconds a stage may run before it is a miss
local TITLES = { crack = "Data crack", voltage = "Voltage", fingerprint = "Fingerprint" }
local BUTTONS = { crack = "Lock  (Space)", voltage = "Connect  (Space)", fingerprint = "Clone  (Space)" }

-- The data crack.
local ROW = 44 -- px between two symbols
local ROWS = 7 -- symbols in view
local WINDOW_ROW = 3 -- the window's row (0-based, from the top)
local TOLERANCE = 0.32 -- how far off the window's middle a lock still counts, in rows
local SPEEDS = { 120, 170, 230 } -- px a second, per stage
local SYMBOLS = { "A3", "7F", "C9", "1E", "B4", "5D", "E2", "08", "9A", "F6", "3C", "D7", "6B", "2F" }

-- The Voltlab's multipliers.
local MULTIPLIERS = { 1, 2, 10 }

-- The fingerprint's ridge pieces (mono text, so every piece is the same width).
local RIDGES = {
	"((((((",
	"))))))",
	"()()()",
	"(())((",
	"))(())",
	")()()(",
	"((()))",
	"()))((",
	"(()(()",
	")(()))",
	"((()((",
	"))()))",
}

local win: any
local stationLabel: TextLabel
local stageLabel: TextLabel
local targetText: any
local area: Frame
local statusLabel: TextLabel
local actionButton: TextButton

-- The hack in progress (nil when none). `play` is the stage's own game: confirm() and draw().
local current: any = nil

local function report(index: number, ok: boolean)
	HackRemote:FireServer({ action = "stage", index = index, ok = ok })
end

local function setStatus(text: string, color: Color3?)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or C.dim
end

-- The data crack -----------------------------------------------------------------------------------

local function crackStage(rng: Random, stage: number)
	local target = SYMBOLS[rng:NextInteger(1, #SYMBOLS)]
	local others = {}
	for _, symbol in ipairs(SYMBOLS) do
		if symbol ~= target then
			table.insert(others, symbol)
		end
	end
	-- The target comes round every three to five rows.
	local sequence = {}
	local nextTarget = rng:NextInteger(4, 6)
	for i = 1, 400 do
		if i == nextTarget then
			table.insert(sequence, target)
			nextTarget = i + rng:NextInteger(3, 5)
		else
			table.insert(sequence, others[rng:NextInteger(1, #others)])
		end
	end
	targetText:set(target)
	local column = Kit.frame({
		Name = "Column",
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(160, ROW * ROWS),
		Parent = area,
	})
	column.BackgroundTransparency = 0.2
	column.BackgroundColor3 = C.g0
	local window = Kit.Base.make("Frame", {
		Name = "Window",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, WINDOW_ROW * ROW),
		Size = UDim2.new(1, 0, 0, ROW),
		ZIndex = 5,
		Parent = column,
	})
	Kit.Base.make("UIStroke", { Color = C.danger, Thickness = 2, Parent = window })
	local labels = {}
	for i = 1, ROWS + 1 do
		table.insert(
			labels,
			Kit.label({
				Text = "",
				font = "mono",
				TextScaled = true,
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, ROW),
				Position = UDim2.fromOffset(0, (i - 1) * ROW),
				Parent = column,
			})
		)
	end
	local startedAt = os.clock()
	local function position(): number
		return (os.clock() - startedAt) * SPEEDS[math.clamp(stage, 1, #SPEEDS)]
	end
	return {
		hint = "Lock the target inside the window.",
		confirm = function(): boolean
			local at = position()
			local top = math.floor(at / ROW)
			local fraction = at - top * ROW
			local row = if fraction >= ROW / 2 then WINDOW_ROW + 1 else WINDOW_ROW
			local offset = (fraction - (row - WINDOW_ROW) * ROW) / ROW
			return sequence[top + row + 1] == target and math.abs(offset) <= TOLERANCE
		end,
		draw = function(running: boolean)
			local at = if running then position() else 0
			local top = math.floor(at / ROW)
			local fraction = at - top * ROW
			for i, label in ipairs(labels) do
				local row = i - 1
				label.Position = UDim2.new(0, 0, 0, row * ROW - fraction)
				local symbol = sequence[top + row + 1] or ""
				label.Text = symbol
				label.TextColor3 = if symbol == target then C.danger else C.dim
			end
		end,
	}
end

-- The Voltlab --------------------------------------------------------------------------------------

local function voltageStage(rng: Random, _stage: number)
	local numbers = { rng:NextInteger(1, 9), rng:NextInteger(1, 9), rng:NextInteger(1, 9) }
	local order = { 1, 2, 3 }
	for i = 3, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local target = 0
	for i, number in ipairs(numbers) do
		target += number * MULTIPLIERS[order[i]]
	end
	targetText:set(tostring(target))
	-- links[left] = the multiplier index wired to it
	local links: { [number]: number } = {}
	local picked: number? = nil
	local leftButtons, rightButtons = {}, {}
	local function refresh()
		local used = {}
		for _, right in pairs(links) do
			used[right] = true
		end
		for i, button in ipairs(leftButtons) do
			local wired = links[i]
			local text = if wired
				then string.format("%d  =  x%d", numbers[i], MULTIPLIERS[wired])
				else tostring(numbers[i])
			-- (the number being wired is marked with arrows: the button's own fill is drawn by the kit)
			Kit.setText(button, if picked == i then "> " .. text .. " <" else text)
		end
		for i, button in ipairs(rightButtons) do
			Kit.setEnabled(button, not used[i])
		end
	end
	local column = Kit.frame({ Name = "Left", Size = UDim2.new(0.5, -8, 1, 0), Parent = area })
	Kit.list(column, 10)
	local right = Kit.frame({
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -8, 1, 0),
		Parent = area,
	})
	Kit.list(right, 10)
	for i = 1, 3 do
		table.insert(
			leftButtons,
			Kit.button({ text = tostring(numbers[i]), size = "l", LayoutOrder = i, Parent = column }, function()
				if links[i] then
					links[i] = nil -- unplug
				end
				picked = i
				refresh()
			end)
		)
		table.insert(
			rightButtons,
			Kit.button({ text = "x" .. MULTIPLIERS[i], size = "l", LayoutOrder = i, Parent = right }, function()
				if picked then
					links[picked] = i
					picked = nil
					refresh()
				end
			end)
		)
	end
	refresh()
	return {
		hint = "Wire each number to a multiplier. Hit the target.",
		confirm = function(): boolean
			local sum, count = 0, 0
			for left, rightIndex in pairs(links) do
				sum += numbers[left] * MULTIPLIERS[rightIndex]
				count += 1
			end
			return count == 3 and sum == target
		end,
	}
end

-- The fingerprint clone -----------------------------------------------------------------------------

local function fingerprintStage(rng: Random, _stage: number)
	local pool = table.clone(RIDGES)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local print = { pool[1], pool[2], pool[3], pool[4] }
	local candidates = { pool[1], pool[2], pool[3], pool[4], pool[5], pool[6], pool[7], pool[8] }
	for i = #candidates, 2, -1 do
		local j = rng:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	targetText:set("4")
	-- The print on the left, the pieces to pick from on the right.
	local printFrame = Kit.frame({ Name = "Print", Size = UDim2.new(0.42, 0, 1, 0), Parent = area })
	printFrame.BackgroundTransparency = 0.2
	printFrame.BackgroundColor3 = C.g0
	Kit.list(printFrame, 4)
	for i, piece in ipairs(print) do
		Kit.label({
			Text = piece,
			font = "mono",
			color = C.bone,
			TextScaled = true,
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0.25, -4),
			LayoutOrder = i,
			Parent = printFrame,
		})
	end
	local grid = Kit.frame({
		Name = "Pieces",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.55, 0, 1, 0),
		Parent = area,
	})
	Kit.grid(grid, UDim2.new(0.5, -4, 0.25, -6), 8)
	local chosen: { [number]: boolean } = {}
	for i, piece in ipairs(candidates) do
		local button
		button = Kit.button({ text = piece, LayoutOrder = i, Parent = grid }, function()
			chosen[i] = not chosen[i] or nil
			Kit.setText(button, if chosen[i] then "[" .. piece .. "]" else piece)
		end)
	end
	return {
		hint = "Pick the four pieces of the print.",
		confirm = function(): boolean
			local count = 0
			for index in pairs(chosen) do
				count += 1
				if not table.find(print, candidates[index]) then
					return false
				end
			end
			return count == 4
		end,
	}
end

local BUILD = { crack = crackStage, voltage = voltageStage, fingerprint = fingerprintStage }

-- Flow ---------------------------------------------------------------------------------------------

local function setupStage(hack, index: number)
	Kit.clear(area)
	hack.stage = index
	hack.startedAt = os.clock()
	hack.state = "run"
	hack.play = BUILD[hack.game](Random.new(hack.seed + index * 7919), index)
	stageLabel.Text = string.format("%s  %d / %d", string.upper(TITLES[hack.game]), index, hack.stages)
	setStatus(hack.play.hint)
	Kit.setEnabled(actionButton, true)
end

local function miss()
	local hack = current
	if not hack or hack.state ~= "run" then
		return
	end
	hack.state = "wait"
	Kit.setEnabled(actionButton, false)
	setStatus("Missed", C.danger)
	report(hack.stage, false)
end

local function confirm()
	local hack = current
	if not hack or hack.state ~= "run" or not hack.play then
		return
	end
	if not hack.play.confirm() then
		miss()
		return
	end
	-- A pass: the next stage starts after a short decrypt. The last one is reported once its decrypt
	-- is done, so the whole hack takes as long as a person plays it.
	Kit.setEnabled(actionButton, false)
	setStatus("Cracked", C.good)
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
		if os.clock() - hack.startedAt > LIMIT[hack.game] then
			miss()
		end
	elseif hack.state == "decrypt" and os.clock() >= hack.stateUntil then
		if hack.stage < hack.stages then
			setupStage(hack, hack.stage + 1)
		else
			hack.state = "wait"
			setStatus("Reading log")
			report(hack.stage, true)
		end
	end
	if hack.play and hack.play.draw then
		hack.play.draw(hack.state == "run")
	end
end

local function close()
	Router.close("hack", "rule")
end

local function start(payload)
	local seed = tonumber(payload.seed) or 1
	local game = if type(payload.game) == "string" and BUILD[payload.game]
		then payload.game
		else GAMES[(seed % #GAMES) + 1]
	current = {
		stationId = payload.stationId,
		stages = tonumber(payload.stages) or 3,
		stage = 0,
		seed = seed,
		game = game,
		play = nil,
		startedAt = os.clock(),
		state = "boot",
		stateUntil = os.clock() + BOOT,
	}
	Kit.clear(area)
	stationLabel.Text = string.upper(tostring(payload.stationName or ""))
	stageLabel.Text = "CONNECTING"
	targetText:set("--")
	setStatus("Hacking")
	Kit.setText(actionButton, BUTTONS[game])
	Kit.setEnabled(actionButton, false)
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
	-- Where each stage's game is built.
	area = Kit.frame({
		Name = "Game",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -(52 + 92)),
		Parent = body,
	})
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
	actionButton = Kit.button({
		text = BUTTONS.crack,
		icon = "lock",
		variant = "primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 52),
		Parent = body,
	}, confirm)

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
			setStatus(string.format("%s is %s.", tostring(payload.alias), tostring(payload.name)), C.good)
			task.delay(1.6, close)
		elseif payload.state == "empty" then
			if current then
				current.state = "done"
			end
			setStatus("Nobody used this lately.")
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
			-- Space confirms in every game (and the pad's A in the data crack, where nothing else is pressed).
			local keys = { Enum.KeyCode.Space }
			if current and current.game == "crack" then
				table.insert(keys, Enum.KeyCode.ButtonA)
			end
			ContextActionService:BindActionAtPriority("DeathsGambit_HackLock", function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					confirm()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, table.unpack(keys))
		end,
		firstSelection = function()
			return actionButton
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
