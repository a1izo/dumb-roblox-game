-- The Trial's step, in the top right corner of the lobby: one step at a time, never a list.
--
--   ● Step 2 of 5                      (a small amber dot: the wisp's colour)
--   Work a case file                   (the instruction, Melodrama 24)
--   Follow the wisp to the fingerprint altar.   (how, one short line)
--
-- When the step is done its line takes a tick, the "how" gives way to one line on why it matters, and a
-- few seconds later the panel slides out and the next step slides in. The offer to begin sits in the same
-- place, with Begin and Skip. The panel only says what to do; the wisp (Onboarding/TrialWisp) shows where.

local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local LobbyChrome = require(UI.Core.LobbyChrome)
local Motion = require(UI.Core.Motion)
local Screens = require(UI.Screens)
local Toasts = require(UI.Toasts)

local C = Kit.color
local T = Kit.Tokens

local TrialObjective = {}

local WIDTH = 340
local PHONE_WIDTH = 290
local WHY_TIME = 3.2 -- seconds the "why" line stays before the next step
local AMBER = Color3.fromRGB(255, 166, 72)

local holder: CanvasGroup
local page: Frame
local top: Frame
local counterLabel: TextLabel
local tick: ImageLabel
local lineText: any
local howLabel: TextLabel
local whyLabel: TextLabel
local cardRow: Frame
local cardButton: TextButton
local actions: Frame
local closeButton: TextButton

local wanted = false -- something to show (an offer, a step, the end)
local allowed = true -- the lobby is on screen (not in a case, the UI not hidden)
local token = 0
local onBegin: (() -> ())? = nil
local onSkip: (() -> ())? = nil
local onLeave: (() -> ())? = nil
local onCardHeld: ((boolean) -> ())? = nil

local function width(): number
	return if Kit.Layout.isPhone() then PHONE_WIDTH else WIDTH
end

-- How far down the panel reaches, for the toasts (they start under it).
local function tellToasts()
	local bottom = 0
	if holder.Visible then
		bottom = holder.Position.Y.Offset + math.ceil(holder.AbsoluteSize.Y / Kit.Base.scaleOf(holder))
	end
	Toasts.keepBelow(bottom)
end

local function apply()
	holder.Visible = wanted and allowed and not LobbyChrome.isHidden()
	tellToasts()
end

-- Shows the panel with new contents: it slides in from the right.
local function present()
	wanted = true
	apply()
	if holder.Visible then
		Motion.fade(holder, true, 0.25)
		Motion.slideIn(holder, Vector2.new(40, 0), 0.3)
	end
end

local function reset()
	token += 1
	tick.Visible = false
	lineText:setColor(C.white)
	howLabel.Visible = false
	whyLabel.Visible = false
	cardRow.Visible = false
	actions.Visible = false
	closeButton.Visible = false
	counterLabel.Visible = true
	top.Visible = true
end

-- The offer: begin now, or skip it (it is not offered again; the Academy's gate can still start it).
function TrialObjective.offer(title: string, line: string, begin: () -> (), skip: () -> ())
	reset()
	onBegin, onSkip = begin, skip
	-- No step count and no X yet: the top row would be a lone dot.
	top.Visible = false
	lineText:set(title)
	howLabel.Text = line
	howLabel.Visible = true
	actions.Visible = true
	present()
end

-- Step `index` of `total`: its instruction and how to do it. `card` adds the hold button for the role card
-- (on a touch screen, where there is no C key or bumper).
function TrialObjective.step(index: number, total: number, line: string, how: string, card: boolean)
	reset()
	counterLabel.Text = string.format("Step %d of %d", index, total)
	lineText:set(line)
	howLabel.Text = how
	howLabel.Visible = true
	cardRow.Visible = card
	closeButton.Visible = true
	present()
end

-- New wording for the current step's "how" (the player picked up a gamepad, say).
function TrialObjective.setHow(how: string)
	howLabel.Text = how
end

-- The current step is done: a tick, the "why" for a few seconds, then the panel slides out and `after` runs.
function TrialObjective.done(why: string, after: () -> ())
	token += 1
	local mine = token
	tick.Visible = true
	lineText:setColor(C.dim)
	howLabel.Visible = false
	cardRow.Visible = false
	whyLabel.Text = why
	whyLabel.Visible = true
	Motion.pulse(page)
	task.delay(WHY_TIME, function()
		if token ~= mine then
			return
		end
		local tween = Motion.fade(holder, false, 0.25)
		if tween then
			tween.Completed:Wait()
		end
		if token == mine then
			after()
		end
	end)
end

-- The end: what it all comes to, then the panel goes.
function TrialObjective.finish(line: string, why: string)
	reset()
	local mine = token
	top.Visible = false
	tick.Visible = true
	lineText:set(line)
	whyLabel.Text = why
	whyLabel.Visible = true
	present()
	task.delay(7, function()
		if token == mine then
			TrialObjective.hide()
		end
	end)
end

function TrialObjective.hide()
	token += 1
	wanted = false
	apply()
end

-- Whether the lobby is on screen (the panel waits while you are in a case, or watching one).
function TrialObjective.setAllowed(on: boolean)
	allowed = on
	apply()
end

-- Callbacks: leaving the Trial (the panel's X), and the role card button held (true) or let go (false).
function TrialObjective.wire(leave: () -> (), cardHeld: (boolean) -> ())
	onLeave = leave
	onCardHeld = cardHeld
end

function TrialObjective.init()
	holder = Instance.new("CanvasGroup")
	holder.Name = "TrialObjective"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromOffset(WIDTH, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Visible = false
	holder.Parent = Screens.hud
	Kit.Layout.place(holder, "topRight")
	local content
	page, content = Kit.page({
		Name = "Panel",
		tone = "raised",
		glass = true,
		padding = T.space.m,
		autoHeight = true,
		Size = UDim2.fromOffset(WIDTH, 0),
		Parent = holder,
	})
	Kit.list(content, T.space.xs)
	-- The top row: the wisp's dot and "Step 2 of 5"; the X to stop on the right.
	top = Kit.frame({ Name = "Top", Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = content })
	local dot = Kit.Base.make("Frame", {
		Name = "Wisp",
		BackgroundColor3 = AMBER,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(9, 9),
		Parent = top,
	})
	Kit.Base.round(dot)
	counterLabel = Kit.label({
		font = "label",
		size = "small",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -60, 1, 0),
		Parent = top,
	})
	closeButton = Kit.iconButton({
		icon = "cross",
		size = 22,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 12, 0.5, 0),
		Parent = top,
	}, function()
		if onLeave then
			onLeave()
		end
	end)
	-- The instruction, with a tick in front once it is done.
	local lineRow = Kit.frame({
		Name = "Line",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = content,
	})
	tick = Kit.icon({
		name = "check",
		size = 22,
		color = C.white,
		Position = UDim2.fromOffset(0, 4),
		Visible = false,
		Parent = lineRow,
	})
	lineText = Kit.text({
		face = "Head",
		text = "",
		size = 24,
		color = C.white,
		maxWidth = WIDTH - 2 * T.space.m - 30,
		Parent = lineRow,
	})
	tick:GetPropertyChangedSignal("Visible"):Connect(function()
		-- The line steps aside for the tick.
		lineText.frame.Position = UDim2.fromOffset(if tick.Visible then 30 else 0, 0)
	end)
	howLabel = Kit.label({ size = "body", color = C.bone, LayoutOrder = 3, Parent = content })
	whyLabel = Kit.label({
		font = "bodyItalic",
		size = "body",
		color = C.white,
		Visible = false,
		LayoutOrder = 4,
		Parent = content,
	})
	-- The role card on a touch screen: press and hold to turn it over.
	cardRow = Kit.frame({
		Name = "Card",
		Size = UDim2.new(1, 0, 0, T.touch),
		Visible = false,
		LayoutOrder = 5,
		Parent = content,
	})
	cardButton = Kit.button({
		text = "Hold for your card",
		variant = "primary",
		size = "s",
		Size = UDim2.new(1, 0, 0, T.touch),
		Parent = cardRow,
	})
	cardButton.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) and onCardHeld then
			onCardHeld(true)
		end
	end)
	cardButton.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) and onCardHeld then
			onCardHeld(false)
		end
	end)
	actions = Kit.frame({
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, T.touch),
		Visible = false,
		LayoutOrder = 6,
		Parent = content,
	})
	Kit.list(actions, T.space.s, true)
	Kit.button({ text = "Begin", variant = "primary", size = "s", LayoutOrder = 1, Parent = actions }, function()
		if onBegin then
			onBegin()
		end
	end)
	Kit.button({ text = "Skip", variant = "ghost", size = "s", LayoutOrder = 2, Parent = actions }, function()
		if onSkip then
			onSkip()
		end
	end)
	Kit.Layout.watch(function()
		local w = width()
		holder.Size = UDim2.fromOffset(w, 0)
		page.Size = UDim2.fromOffset(w, page.Size.Y.Offset)
		lineText.props.maxWidth = w - 2 * T.space.m - 30
		lineText:refresh()
	end)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(tellToasts)
	LobbyChrome.Changed:Connect(apply)
end

return TrialObjective
