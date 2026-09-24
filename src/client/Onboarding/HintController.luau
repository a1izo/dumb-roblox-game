-- The guide's one-time tips for new players, shown as a red tag at the top of the screen.
-- Each tip appears once per profile (the server remembers it in tipsSeen). The X on a tip
-- turns the whole guide off (tips and the objective list); Settings turns it back on, and
-- "Show all tips again" there resets which tips were seen.
--
-- Triggers: first match as each role, first time in each phase, first letter flash, first
-- evidence, first sheet / drop point / hood prompt, first death seen, being eliminated.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hints = require(Shared:WaitForChild("Hints"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Router = require(script.Parent.Parent.UI.Core.Router)
local Screens = require(script.Parent.Parent.UI.Screens)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local LocalPlayer = Players.LocalPlayer

local HintController = {}

local SHOW_TIME = 14

local queue: { string } = {}
local shownThisSession: { [string]: boolean } = {}
local running = false
local dismissed = false

local card: CanvasGroup
local titleLabel: TextLabel
local textLabel: TextLabel

local function seen(id: string): boolean
	if shownThisSession[id] then
		return true
	end
	local profile = ClientState.profile
	return profile ~= nil and type(profile.tipsSeen) == "table" and profile.tipsSeen[id] == true
end

local function run()
	running = true
	while #queue > 0 do
		while Router.isBlocking() do
			task.wait(0.3)
		end
		local id = table.remove(queue, 1)
		local hint = Hints.BY_ID[id]
		if hint and Settings.get("hints") then
			Net.event("ProfileRequest"):FireServer({ action = "hint", id = id })
			titleLabel.Text = "TIP  ·  " .. string.upper(hint.title)
			textLabel.Text = hint.text
			dismissed = false
			Motion.fade(card, true, 0.25)
			Motion.slideIn(card, Vector2.new(0, -10), 0.3)
			local started = os.clock()
			while not dismissed and Settings.get("hints") and os.clock() - started < SHOW_TIME do
				task.wait(0.1)
			end
			local tween = Motion.fade(card, false, 0.3)
			if tween then
				tween.Completed:Wait()
			end
			card.Visible = false
			task.wait(0.4)
		end
	end
	running = false
end

-- Queues a hint if this profile has not seen it yet.
function HintController.trigger(id: string)
	if seen(id) or not Settings.get("hints") or not Hints.BY_ID[id] then
		return
	end
	shownThisSession[id] = true
	table.insert(queue, id)
	if not running then
		task.spawn(run)
	end
end

local function buildCard()
	-- A red tag, tilted like the rest of the UI: TIP, the hint, GOT IT and an X that turns
	-- the whole guide off.
	card = Instance.new("CanvasGroup")
	card.Name = "Hint"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 60, 0, 18)
	card.Size = UDim2.new(0.5, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.colors.accent
	card.BorderSizePixel = 0
	card.Rotation = Theme.tilt
	card.Visible = false
	Widgets.sizeLimit(card, Vector2.new(440, 300), Vector2.new(300, 0))
	Widgets.padding(card, Theme.space.md, Theme.space.lg)
	Widgets.list(card, Theme.space.xs)
	-- Title row: TIP · title, and the X that turns the whole guide off.
	local titleRow = Widgets.frame({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = card })
	titleLabel = Widgets.display({
		TextSize = Theme.text.bodyLarge,
		TextColor3 = Theme.colors.paper,
		Size = UDim2.new(1, -40, 1, 0),
		Parent = titleRow,
	})
	textLabel = Widgets.label({
		TextSize = Theme.text.body,
		TextColor3 = Theme.colors.paper,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = card,
	})
	local row = Widgets.frame({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, Parent = card })
	Widgets.button({
		Text = "Got it",
		TextSize = Theme.text.small,
		Variant = "inverse",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(96, 30),
		Parent = row,
	}, function()
		dismissed = true
	end)
	-- X: no more tips and no objective list, until the guide is turned on in Settings.
	local close = Widgets.button({
		Text = "X",
		Variant = "inverse",
		Slant = false,
		TextSize = Theme.text.bodyLarge,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(28, 28),
		Parent = titleRow,
	}, function()
		dismissed = true
		table.clear(queue)
		Settings.set("hints", false)
		Toasts.show("Guide turned off. You can turn it back on in Settings.", "info")
	end)
	close.Name = "HideGuide"
	card.Parent = Screens.toast
end

function HintController.init()
	buildCard()

	local lastPhase = ClientState.phase()
	ClientState.PhaseChanged:Connect(function(phase)
		local previous = lastPhase
		lastPhase = phase
		if not ClientState.isLiving() then
			return
		end
		if previous == "Briefing" and phase == "Investigation" then
			local role = ClientState.role()
			if role then
				HintController.trigger("role_" .. role)
			end
		end
		HintController.trigger("phase_" .. phase)
	end)
	Net.event("LetterFlash").OnClientEvent:Connect(function()
		HintController.trigger("flash")
		HintController.trigger("scratchpad")
	end)
	Net.event("Evidence").OnClientEvent:Connect(function()
		if ClientState.isParticipant() then
			HintController.trigger("evidence")
		end
	end)
	Net.event("Elimination").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.userId == LocalPlayer.UserId then
			HintController.trigger("eliminated")
		elseif payload.kind == "dead" and ClientState.isParticipant() then
			HintController.trigger("death")
		end
	end)
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "LTake" and prompt.ObjectText == "Blank sheet" then
			HintController.trigger("sheet")
		elseif prompt.Name == "LSearch" then
			HintController.trigger("dropPoint")
		elseif prompt.Name == "LWear" then
			HintController.trigger("hood")
		end
	end)
end

return HintController
