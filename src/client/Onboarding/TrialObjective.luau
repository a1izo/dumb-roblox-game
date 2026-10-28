-- The Trial's step, in the top right corner of the lobby: one step at a time, never a list.
--
--   STEP 2 OF 5                    X   (the notice's eyebrow, Kit/Notice)
--   Work a case file                   (the instruction, the notice's title)
--   Follow the wisp.                   (how, one short line)
--
-- When the step is done the eyebrow says DONE with a check, the "how" gives way to one line on why it matters, and a
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

local WHY_TIME = 3.2 -- seconds the "why" line stays before the next step

local notice: any -- the panel (Kit/Notice)
local holder: CanvasGroup
local page: Frame
local whyLabel: TextLabel
local cardRow: Frame
local cardButton: TextButton
local counterText = ""

local wanted = false -- something to show (an offer, a step, the end)
local allowed = true -- the lobby is on screen (not in a case, the UI not hidden)
local token = 0
local onBegin: (() -> ())? = nil
local onSkip: (() -> ())? = nil
local onLeave: (() -> ())? = nil
local onCardHeld: ((boolean) -> ())? = nil

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
	notice:setKind("guide")
	notice.title:setColor(C.white)
	notice:setEyebrow(nil)
	notice:setBody(nil)
	whyLabel.Visible = false
	cardRow.Visible = false
	notice.actions.Visible = false
	if notice.closeButton then
		notice.closeButton.Visible = false
	end
end

-- The offer: begin now, or skip it (it is not offered again; the Academy's gate can still start it).
function TrialObjective.offer(title: string, line: string, begin: () -> (), skip: () -> ())
	reset()
	onBegin, onSkip = begin, skip
	notice:setEyebrow("Tutorial")
	notice:setTitle(title)
	notice:setBody(line)
	notice.actions.Visible = true
	present()
end

-- Step `index` of `total`: its instruction and how to do it. `card` adds the hold button for the role card
-- (on a touch screen, where there is no C key or bumper).
function TrialObjective.step(index: number, total: number, line: string, how: string, card: boolean)
	reset()
	counterText = string.format("Step %d of %d", index, total)
	notice:setEyebrow(counterText)
	notice:setTitle(line)
	notice:setBody(how)
	cardRow.Visible = card
	if notice.closeButton then
		notice.closeButton.Visible = true
	end
	present()
end

-- New wording for the current step's "how" (the player picked up a gamepad, say).
function TrialObjective.setHow(how: string)
	if not whyLabel.Visible then
		notice:setBody(how)
	end
end

-- The current step is done: a tick, the "why" for a few seconds, then the panel slides out and `after` runs.
function TrialObjective.done(why: string, after: () -> ())
	token += 1
	local mine = token
	notice:setKind("good")
	notice:setEyebrow(counterText .. "   Done")
	notice.title:setColor(C.dim)
	notice:setBody(nil)
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
	notice:setKind("good")
	notice:setEyebrow("Tutorial done")
	notice:setTitle(line)
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
	notice = Kit.notice({
		Name = "TrialObjective",
		kind = "guide",
		Visible = false,
		close = function()
			if onLeave then
				onLeave()
			end
		end,
		actions = {
			{
				text = "Begin",
				onClick = function()
					if onBegin then
						onBegin()
					end
				end,
			},
			{
				text = "Skip",
				onClick = function()
					if onSkip then
						onSkip()
					end
				end,
			},
		},
		Parent = Screens.hud,
	})
	holder = notice.group
	page = notice.page
	Kit.Layout.place(holder, "topRight")
	-- Why the step mattered, once it is done.
	whyLabel = Kit.label({
		font = "bodyItalic",
		size = "body",
		color = C.white,
		Visible = false,
		LayoutOrder = 1,
		Parent = notice.slot,
	})
	-- The role card on a touch screen: press and hold to turn it over.
	cardRow = Kit.frame({
		Name = "Card",
		Size = UDim2.new(1, 0, 0, T.touch),
		Visible = false,
		LayoutOrder = 2,
		Parent = notice.slot,
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
	Kit.Layout.watch(function()
		notice:setWidth(Kit.Notice.width())
	end)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(tellToasts)
	LobbyChrome.Changed:Connect(apply)
end

return TrialObjective
