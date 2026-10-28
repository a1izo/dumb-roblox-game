--!strict
-- The name duel on this client: a small card at the top of the screen for whoever stands at one of the two
-- stones under the lobby's ribs. (Rules: Shared/LobbyGames/Duel. The duel is the server's, Services/LobbyDuel;
-- the prompts on the stones are Controllers/LobbyGamesController's.)
--
-- While you wait it says so. Once someone takes the other stone it shows their name leaking, a field to
-- write it in, how much of your own name they can see, and the time left. It is not a window: the lobby
-- stays in view, and you can step down at any moment (mid-duel that hands the duel to the other).
-- Onlookers get no card: they read the stones' slates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Duel = require(Shared:WaitForChild("LobbyGames"):WaitForChild("Duel"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Kit = require(script.Parent.Kit)
local Responsive = require(script.Parent.Core.Responsive)
local Screens = require(script.Parent.Screens)

local DuelPanel = {}

local C = Kit.color
local T = Kit.Tokens

local request = Net.event("LobbyGame")

local WIDTH = 440
local WRITE_WIDTH = 104

local card: Frame
local titleLabel: TextLabel
local maskLabel: TextLabel
local writeRow: Frame
local box: TextBox
local writeButton: TextButton
local lineLabel: TextLabel
local noteLabel: TextLabel
local leaveButton: TextButton

-- "none" (not at a stone), "waiting" (alone at one), "duel", "over" (the result shows).
local phase = "none"
local rival = ""
local endsAt: number? = nil
local lockedUntil = 0
local own = { name = "", mask = "" }
-- A word about the last thing that happened (the other's wrong name), shown for a moment.
local word = ""
local wordUntil = 0
local canWrite = true

local function now(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	local left = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(left / 60), left % 60)
end

local function isPhone(): boolean
	return Responsive.class() == "phone"
end

-- The other's name as it stands: on a phone small and on one line (the keyboard takes half the screen),
-- elsewhere large, first name over last name, so the card never changes shape as letters come.
local function setMask(mask: string)
	maskLabel.Text = if isPhone() then mask else (string.gsub(mask, "   ", "\n"))
end

-- On a phone the card sits higher and tighter, so the name and the field stay above the keyboard.
local function layout()
	local phone = isPhone()
	Kit.Layout.place(card, "topCenter", Vector2.new(0, if phone then 44 else 96))
	maskLabel.TextSize = if phone then T.size.lead else T.size.title
end

-- The two lines under the field, which change with the clock.
local function refreshLines()
	if phase ~= "duel" then
		return
	end
	local t = now()
	local left = if endsAt then endsAt - t else 0
	titleLabel.Text = string.format("NAME DUEL   %s   %s", string.upper(rival), clock(left))
	local locked = lockedUntil - t
	if locked > 0 then
		lineLabel.Text = string.format("Not their name. Wait %d.", math.ceil(locked))
		lineLabel.TextColor3 = C.danger
	elseif t < wordUntil then
		lineLabel.Text = word
		lineLabel.TextColor3 = C.bone
	else
		lineLabel.Text = "Write their full name first."
		lineLabel.TextColor3 = C.dim
	end
	if canWrite ~= (locked <= 0) then
		canWrite = locked <= 0
		Kit.setEnabled(writeButton, canWrite)
	end
	box.PlaceholderText = if locked > 0 then string.format("Wait %d", math.ceil(locked)) else "Their full name"
	noteLabel.Text = string.format("You are %s. They see %s", string.upper(own.name), own.mask)
end

local function show(newPhase: string)
	phase = newPhase
	layout()
	card.Visible = newPhase ~= "none"
	writeRow.Visible = newPhase == "duel"
	maskLabel.Visible = newPhase == "duel" or newPhase == "over"
	noteLabel.Visible = newPhase == "duel" or newPhase == "over"
	leaveButton.Visible = newPhase == "waiting" or newPhase == "duel"
	Kit.setText(leaveButton, if newPhase == "duel" then "Give up" else "Step down")
	if newPhase ~= "duel" then
		box:ReleaseFocus()
		box.Text = ""
	end
end

local function submit()
	if phase ~= "duel" or now() < lockedUntil then
		return
	end
	local text = box.Text
	if string.match(text, "%a") == nil then
		return
	end
	request:FireServer({ game = "duel", action = "guess", text = string.sub(text, 1, Duel.MAX_GUESS) })
end

local OVER: { [string]: { [string]: string } } = {
	won = {
		named = "You named them first.",
		forfeit = "They left. You win.",
	},
	lost = {
		named = "They named you first.",
		forfeit = "You walked away.",
	},
	draw = {
		time = "Time's up. No winner.",
		called = "A case is starting. No winner.",
	},
}

local function onState(p: any)
	if type(p) ~= "table" or p.game ~= "duel" then
		return
	end
	if p.kind == "stand" then
		show("waiting")
		titleLabel.Text = "NAME DUEL"
		lineLabel.Text = "Waiting for an opponent."
		lineLabel.TextColor3 = C.dim
	elseif p.kind == "start" then
		rival = tostring(p.rival)
		endsAt = if type(p.endsAt) == "number" then p.endsAt else now() + Duel.LIMIT
		lockedUntil = 0
		wordUntil = 0
		own.name = tostring(p.you)
		own.mask = tostring(p.yourMask)
		show("duel")
		setMask(tostring(p.mask))
		refreshLines()
		Sfx.play("gameCheckpoint", { volume = 0.7 })
		-- With a keyboard in front of you, you are writing at once; a touch screen's keyboard waits for a tap.
		if not Responsive.isTouch() then
			box:CaptureFocus()
		end
	elseif p.kind == "leak" and phase == "duel" then
		setMask(tostring(p.mask))
		own.mask = tostring(p.yourMask)
		refreshLines()
		Sfx.play("gameRune", { volume = 0.5 })
	elseif p.kind == "miss" and phase == "duel" then
		lockedUntil = if type(p.lockedUntil) == "number" then p.lockedUntil else now() + Duel.LOCKOUT
		box.Text = ""
		refreshLines()
		Sfx.play("gameWrong")
	elseif p.kind == "rivalMiss" and phase == "duel" then
		word = "They wrote a wrong name."
		wordUntil = now() + 2.5
		refreshLines()
	elseif p.kind == "over" then
		local result = tostring(p.result)
		local lines = OVER[result] or OVER.draw
		show("over")
		titleLabel.Text = "NAME DUEL   " .. string.upper(rival)
		maskLabel.Text = string.upper(tostring(p.rival))
		canWrite = true
		Kit.setEnabled(writeButton, true)
		lineLabel.Text = (lines[tostring(p.why)] or "Duel over.")
			.. (if type(p.wins) == "number" then string.format("   Duels won: %d", p.wins) else "")
		lineLabel.TextColor3 = C.bone
		noteLabel.Text = string.format("You were %s.", string.upper(tostring(p.you)))
		Sfx.play(if result == "won" then "gameFinish" else "gameWrong", { volume = 0.8 })
	elseif p.kind == "left" then
		show("none")
	end
end

local function build()
	card = Kit.card({
		Name = "DuelCard",
		tone = "raised",
		padding = T.space.m,
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Screens.hud,
	})
	card.BackgroundTransparency = T.alpha.glass
	Create("UISizeConstraint", { MaxSize = Vector2.new(WIDTH, math.huge), Parent = card })
	Kit.Layout.place(card, "topCenter", Vector2.new(0, 96))
	Kit.list(card, T.space.s)
	titleLabel = Kit.label({
		Name = "Title",
		font = "label",
		size = "small",
		color = C.dim,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Parent = card,
	})
	maskLabel = Kit.label({
		Name = "Mask",
		font = "bodyBold",
		size = "title",
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = card,
	})
	writeRow = Kit.frame({
		Name = "Write",
		Size = UDim2.new(1, 0, 0, T.touch + 4),
		LayoutOrder = 3,
		Parent = card,
	})
	local _, field = Kit.field({
		placeholder = "Their full name",
		maxLength = Duel.MAX_GUESS,
		Size = UDim2.new(1, -(WRITE_WIDTH + T.space.s), 1, 0),
		Parent = writeRow,
	})
	box = field
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
			-- Still writing: the next try needs no second click.
			task.defer(function()
				if phase == "duel" then
					box:CaptureFocus()
				end
			end)
		end
	end)
	writeButton = Kit.button({
		Name = "WriteButton",
		text = "Write",
		variant = "primary",
		size = "s",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(WRITE_WIDTH, T.touch),
		Parent = writeRow,
	}, submit)
	lineLabel = Kit.label({ Name = "Line", size = "small", LayoutOrder = 4, Parent = card })
	noteLabel = Kit.label({ Name = "Note", size = "small", color = C.dim, LayoutOrder = 5, Parent = card })
	leaveButton = Kit.button({
		Name = "Leave",
		text = "Step down",
		variant = "ghost",
		size = "s",
		LayoutOrder = 6,
		Parent = card,
	}, function()
		request:FireServer({ game = "duel", action = "leave" })
	end)
end

-- Where this player is in a duel: "none", "waiting", "duel" or "over" (for checks and the stones' prompts).
function DuelPanel.phase(): string
	return phase
end

function DuelPanel.init()
	build()
	Net.event("LobbyGameState").OnClientEvent:Connect(onState)
	task.spawn(function()
		while true do
			task.wait(0.2)
			refreshLines()
		end
	end)
end

return DuelPanel
