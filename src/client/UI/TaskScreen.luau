-- Case-file tasks. Each station type has a short puzzle; the server only accepts the
-- result after the full task time, so a task always takes about 15 seconds.
-- The Hand's side can fake a task instead, from a second prompt at the station.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local TaskRequest = Net.event("TaskRequest")
local TaskStateRemote = Net.event("TaskState")

local TaskScreen = {}

local window: Frame
local titleLabel: TextLabel
local hintLabel: TextLabel
local area: Frame
local setProgress: (number) -> ()
local progressLabel: TextLabel

local current = nil
local rng = Random.new()

local function flash(button: GuiObject, color: Color3)
	local original = button.BackgroundColor3
	button.BackgroundColor3 = color
	task.delay(0.25, function()
		if button.Parent then
			button.BackgroundColor3 = original
		end
	end)
end

-- Puzzles ------------------------------------------------------------------------------

local function cameraPuzzle(onSolved: () -> ())
	hintLabel.Text = "Camera footage: tap the frames in time order, earliest first."
	local grid = Widgets.frame({ Parent = area })
	Widgets.grid(grid, UDim2.new(0.33, -8, 0.5, -8), 8)
	local times = {}
	local t = rng:NextInteger(20 * 3600, 23 * 3600)
	for i = 1, 6 do
		t += rng:NextInteger(20, 420)
		times[i] = t
	end
	local order = { 1, 2, 3, 4, 5, 6 }
	Util.shuffle(order, rng)
	local nextIndex = 1
	for position, index in ipairs(order) do
		local seconds = times[index]
		local stamp = string.format("%02d:%02d:%02d", (seconds // 3600) % 24, (seconds // 60) % 60, seconds % 60)
		local button
		button = Widgets.button({
			Text = string.format("CAM %02d\n%s", rng:NextInteger(1, 24), stamp),
			Font = Theme.fonts.mono,
			TextSize = 18,
			BackgroundColor3 = Color3.fromRGB(20, 32, 52),
			LayoutOrder = position,
			Parent = grid,
		}, function()
			if button.Active == false then
				return
			end
			if index == nextIndex then
				nextIndex += 1
				button.Active = false
				button.AutoButtonColor = false
				button.BackgroundColor3 = Theme.colors.good
				if nextIndex > #times then
					onSolved()
				end
			else
				flash(button, Theme.colors.bad)
			end
		end)
	end
end

local function drawPrint(parent: GuiObject, bits: { boolean })
	local holder = Widgets.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		Parent = parent,
	})
	Widgets.grid(holder, UDim2.new(0.25, -3, 0.25, -3), 3)
	for i = 1, 16 do
		local cell = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = if bits[i] then Theme.colors.ink else Color3.fromRGB(215, 205, 185),
			LayoutOrder = i,
			Parent = holder,
		})
		Widgets.corner(cell, 3)
	end
end

local function fingerprintPuzzle(onSolved: () -> ())
	hintLabel.Text = "Fingerprints: pick the print that matches the sample. Three samples."
	local roundsLeft = 3

	local function newRound()
		Widgets.clear(area)
		local target = {}
		for i = 1, 16 do
			target[i] = rng:NextNumber() < 0.5
		end
		local sample = Widgets.panel({
			BackgroundColor3 = Theme.colors.paper,
			Size = UDim2.new(0.3, 0, 1, 0),
			Parent = area,
		})
		drawPrint(sample, target)
		Widgets.label({
			Text = string.format("SAMPLE (%d left)", roundsLeft),
			TextColor3 = Theme.colors.ink,
			Font = Theme.fonts.bold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 16),
			Parent = sample,
		})
		local choices = Widgets.frame({
			Position = UDim2.new(0.33, 0, 0, 0),
			Size = UDim2.new(0.67, 0, 1, 0),
			Parent = area,
		})
		Widgets.grid(choices, UDim2.new(0.5, -6, 0.5, -6), 6)
		local candidates = { { bits = target, correct = true } }
		for _ = 1, 3 do
			local decoy = table.clone(target)
			local flips = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
			Util.shuffle(flips, rng)
			for k = 1, 3 do
				decoy[flips[k]] = not decoy[flips[k]]
			end
			table.insert(candidates, { bits = decoy, correct = false })
		end
		Util.shuffle(candidates, rng)
		for position, candidate in ipairs(candidates) do
			local button
			button = Widgets.button({
				BackgroundColor3 = Theme.colors.paper,
				LayoutOrder = position,
				Parent = choices,
			}, function()
				if candidate.correct then
					roundsLeft -= 1
					if roundsLeft <= 0 then
						Widgets.clear(area)
						onSolved()
					else
						newRound()
					end
				else
					flash(button, Theme.colors.bad)
				end
			end)
			drawPrint(button, candidate.bits)
		end
	end

	newRound()
end

local function phonePuzzle(onSolved: () -> ())
	hintLabel.Text = "Phone records: dial the number from the call log."
	local digits = { "0", "9", "0" }
	for _ = 1, 8 do
		table.insert(digits, tostring(rng:NextInteger(0, 9)))
	end
	local function formatted(count: number): string
		local out = {}
		for i = 1, #digits do
			out[i] = if i <= count then digits[i] else "_"
		end
		return table.concat(out, "", 1, 3) .. "-" .. table.concat(out, "", 4, 7) .. "-" .. table.concat(out, "", 8, 11)
	end
	Widgets.label({
		Text = "CALL LOG:  " .. formatted(#digits),
		Font = Theme.fonts.mono,
		TextSize = 22,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = area,
	})
	local display = Widgets.label({
		Text = "DIALLED:   " .. formatted(0),
		Font = Theme.fonts.mono,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = area,
	})
	local pad = Widgets.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.new(0.6, 0, 1, -68),
		Parent = area,
	})
	Widgets.grid(pad, UDim2.new(0.33, -6, 0.25, -6), 6)
	local typed = 0
	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#" }
	for position, key in ipairs(keys) do
		local button
		button = Widgets.button({
			Text = key,
			Font = Theme.fonts.mono,
			TextSize = 22,
			LayoutOrder = position,
			Parent = pad,
		}, function()
			if typed >= #digits then
				return
			end
			if key == digits[typed + 1] then
				typed += 1
				display.Text = "DIALLED:   " .. formatted(typed)
				flash(button, Theme.colors.good)
				if typed == #digits then
					onSolved()
				end
			else
				flash(button, Theme.colors.bad)
			end
		end)
	end
end

local function fakePuzzle()
	hintLabel.Text = "Faking it: stay at the station until the bar fills. No clue will be posted."
	Widgets.label({
		Text = "Pretending to work...",
		Font = Theme.fonts.typewriter,
		TextSize = 26,
		TextColor3 = Theme.colors.secret,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = area,
	})
end

-- Flow ------------------------------------------------------------------------------------

local function close()
	Router.close("task", "rule")
end

local function start(payload)
	Widgets.clear(area)
	-- Progress follows the server clock, so the bar fills exactly when the server accepts.
	local startedAt = tonumber(payload.startedAt) or workspace:GetServerTimeNow()
	current = {
		stationId = payload.stationId,
		fake = payload.fake == true,
		duration = tonumber(payload.duration) or 15,
		startedAt = startedAt,
		solved = payload.fake == true,
		submittedAt = nil,
	}
	local task_ = current
	titleLabel.Text = string.upper(tostring(payload.stationName))
	Router.open("task")
	local function onSolved()
		if current == task_ then
			task_.solved = true
			hintLabel.Text = "Done. Filing the report..."
		end
	end
	if task_.fake then
		fakePuzzle()
	elseif payload.stationType == "Camera" then
		cameraPuzzle(onSolved)
	elseif payload.stationType == "Fingerprint" then
		fingerprintPuzzle(onSolved)
	else
		phonePuzzle(onSolved)
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
		progressLabel.Text = string.format("Working... %d s", math.ceil(task_.duration - elapsed))
	elseif not task_.solved then
		progressLabel.Text = "Finish the puzzle to file the report."
	else
		progressLabel.Text = "Filing the report..."
	end
	if task_.solved and progress >= 1 then
		if task_.submittedAt == nil or os.clock() - task_.submittedAt > 2 then
			task_.submittedAt = os.clock()
			TaskRequest:FireServer({ action = "complete", stationId = task_.stationId })
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

function TaskScreen.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Case file", Vector2.new(580, 470), function()
		Router.close("task", "user")
	end)
	titleLabel = window:FindFirstChild("Title") :: TextLabel
	hintLabel = Widgets.label({
		TextSize = 15,
		TextColor3 = Theme.colors.muted,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = body,
	})
	area = Widgets.frame({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -96),
		Parent = body,
	})
	local _, setter = Widgets.progressBar({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = body,
	}, Theme.colors.team)
	setProgress = setter
	progressLabel = Widgets.label({
		TextSize = 14,
		TextColor3 = Theme.colors.muted,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = body,
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
				Toasts.show("Case file complete. Your clue is on the evidence board.", "good")
			end
		elseif payload.state == "cancelled" then
			close()
			if type(payload.reason) == "string" then
				Toasts.show(payload.reason, "bad")
			end
		elseif payload.state == "wait" and current then
			-- The server has not counted the full task time yet; retry in a second.
			current.submittedAt = os.clock() - 1
		end
	end)
	Router.register("task", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return view.living and view.phase == "Investigation"
		end,
		show = function()
			window.Visible = true
		end,
		hide = function(reason)
			-- The player walked away from the puzzle: tell the server. When the phase ends the
			-- server has already cancelled the task.
			if current and (reason == "user" or reason == "back" or reason == "replaced") then
				TaskRequest:FireServer({ action = "cancel", stationId = current.stationId })
			end
			current = nil
			window.Visible = false
			Widgets.clear(area)
		end,
	})
	RunService.RenderStepped:Connect(update)
end

return TaskScreen
