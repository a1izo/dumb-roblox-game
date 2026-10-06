-- The guide's one-time tips for new players, written on a slip under the objectives (under
-- the phase banner on phones). Each tip appears once per profile (the server remembers it in
-- tipsSeen). The X on a tip turns the whole guide off (tips and the objective list); Settings
-- turns it back on, and "Show all tips again" there resets which tips were seen.
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
local UI = script.Parent.Parent.UI
local Announcer = require(UI.Announcer)
local Hud = require(UI.Hud)
local Kit = require(UI.Kit)
local Motion = require(UI.Core.Motion)
local Router = require(UI.Core.Router)
local Screens = require(UI.Screens)
local Settings = require(UI.Core.Settings)
local Toasts = require(UI.Toasts)

local C = Kit.color
local T = Kit.Tokens

local LocalPlayer = Players.LocalPlayer

local HintController = {}

local SHOW_TIME = 14
local WIDTH = 400

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
		-- Wait for full-screen overlays and for announcements to pass.
		while Router.isBlocking() or Announcer.isShowing() do
			task.wait(0.3)
		end
		local id = table.remove(queue, 1)
		local hint = Hints.BY_ID[id]
		if hint and Settings.get("hints") then
			Net.event("ProfileRequest"):FireServer({ action = "hint", id = id })
			titleLabel.Text = "TIP  ·  " .. string.upper(hint.title)
			textLabel.Text = hint.text
			dismissed = false
			local position, anchor = Hud.tipPlacement()
			card.AnchorPoint = anchor
			card.Position = position
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
	-- A slip from the guide with a red ink mark: TIP and its title, the hint, GOT IT, and an
	-- X that turns the whole guide off. A CanvasGroup so it fades as one piece.
	card = Instance.new("CanvasGroup")
	card.Name = "Hint"
	card.Size = UDim2.fromOffset(WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Visible = false
	local page, content = Kit.page({
		Name = "Slip",
		tone = "raised",
		padding = T.space.l,
		autoHeight = true,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = card,
	})
	Kit.Base.make("Frame", {
		Name = "Mark",
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.new(0, 3, 1, -28),
		ZIndex = page.ZIndex + 2,
		Parent = page,
	})
	Kit.list(content, T.space.xs)
	-- Title row: TIP · title, and the X that turns the whole guide off.
	local titleRow = Kit.frame({ Name = "Title", Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = content })
	Kit.icon({
		name = "help",
		size = 22,
		color = C.white,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Parent = titleRow,
	})
	titleLabel = Kit.label({
		font = "label",
		size = "small",
		color = C.white,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -78, 1, 0),
		Parent = titleRow,
	})
	-- X: no more tips and no objective list, until the guide is turned on in Settings.
	local close = Kit.iconButton({
		icon = "cross",
		size = 32,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Parent = titleRow,
	}, function()
		dismissed = true
		table.clear(queue)
		Settings.set("hints", false)
		Toasts.show("Guide turned off. You can turn it back on in Settings.", "info")
	end)
	close.Name = "HideGuide"
	textLabel = Kit.label({ size = "body", color = C.bone, LayoutOrder = 2, Parent = content })
	local row = Kit.frame({ Name = "Actions", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, Parent = content })
	Kit.button({
		text = "Got it",
		variant = "secondary",
		size = "s",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = row,
	}, function()
		dismissed = true
	end)
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
