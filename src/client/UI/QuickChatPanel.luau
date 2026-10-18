-- Quick chat and the emote wheel: in a case, the only way to talk outside meetings. A page rises above the
-- bottom of the screen. In a case it has two tabs, Phrases (a grid of them) and Emotes; in the lobby it is
-- the emotes alone. The emotes are the wheel (UI/Wheel: the eight slots of Shared/EmoteWheel round a ring,
-- pointed at with the mouse, a stick or a finger, played with a click, a tap, A, letting go of Q, or the keys
-- 1 to 8); "More" over it lists every emote you have. An emote that cannot be played where you are (one made
-- for the lobby only, in a case) is locked, with the reason.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared:WaitForChild("Bindings"))
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local Actions = require(script.Parent.Parent.Input.Actions)
local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Wheel = require(script.Parent.Wheel)

local QuickChatRemote = Net.event("QuickChat")

local C = Kit.color
local T = Kit.Tokens

local QuickChatPanel = {}

-- Layout (design px).
local TABS = 48 -- the tab row, in a case
local CAPTION = 22
local WIDTH = 470
local PAD = T.space.l
local HEIGHT_CASE = PAD * 2 + TABS + T.space.s + CAPTION + Wheel.HEIGHT
local HEIGHT_LOBBY = PAD * 2 + CAPTION + Wheel.HEIGHT
-- The slot a key plays: the wheel's slot keys (1 to 8 unless the player set their own, Shared/Bindings).
local function slotFor(key: Enum.KeyCode): number?
	local profile = ClientState.profile
	local saved = profile and profile.keybinds or nil
	for index = 1, 8 do
		if table.find(Bindings.keys("slot" .. index, "keyboard", saved), key.Name) then
			return index
		end
	end
	return nil
end

local panel: Frame
local sizeLimit: UISizeConstraint?
local tabsHolder: Frame
local chooseTab: ((string) -> ())? = nil
local phrasesPage: Frame
local emotesPage: Frame
local caption: TextLabel
local wheelHolder: Frame
local wheelScale: UIScale
local moreButton: TextButton
local moreShown = false
local firstPhrase: GuiObject? = nil
local tab = "emotes"
local keyConnection: RBXScriptConnection? = nil

function QuickChatPanel.toggle()
	Router.toggle("quickChat")
end

function QuickChatPanel.close()
	Router.close("quickChat", "user")
end

-- In a case (not the lobby, where a Specter waiting is too).
local function inCase(): boolean
	return ClientState.isParticipant()
end

-- The wheel asks to play an emote: it goes to the server, and the page closes.
local function play(emote: QuickChat.Emote)
	EmoteController.play(emote.id)
	QuickChatPanel.close()
end

local function showMore(on: boolean)
	moreShown = on
	Wheel.showMore(on)
	caption.Text = if on then "ALL YOUR EMOTES" else "EMOTES  ·  1 TO 8"
	Kit.setText(moreButton, if on then "Wheel" else "More")
end

-- Lays the page out for where you are: tabs in a case, the emotes alone in the lobby.
local function arrange()
	local case = inCase()
	local height = if case then HEIGHT_CASE else HEIGHT_LOBBY
	panel.Size = UDim2.new(0.9, 0, 0, height)
	if sizeLimit then
		sizeLimit.MaxSize = Vector2.new(if case then 720 else WIDTH + PAD * 2, height)
	end
	tabsHolder.Visible = case
	local top = if case then TABS + T.space.s else 0
	phrasesPage.Position = UDim2.fromOffset(0, top)
	phrasesPage.Size = UDim2.new(1, 0, 1, -top)
	emotesPage.Position = UDim2.fromOffset(0, top)
	emotesPage.Size = UDim2.new(1, 0, 1, -top)
	if not case then
		tab = "emotes"
	end
	phrasesPage.Visible = tab == "phrases"
	emotesPage.Visible = tab == "emotes"
	-- A narrow screen shrinks the wheel to fit.
	task.defer(function()
		local width = emotesPage.AbsoluteSize.X / Kit.Base.scaleOf(emotesPage)
		wheelScale.Scale = if width > 0 then math.min(1, width / WIDTH) else 1
	end)
end

local function setTab(id: string)
	tab = id
	showMore(false)
	arrange()
end

local function onKey(input: InputObject, processed: boolean)
	if processed or tab ~= "emotes" then
		return
	end
	local index = slotFor(input.KeyCode)
	if index then
		Wheel.playSlot(index)
	end
end

function QuickChatPanel.init()
	local page, content = Kit.page({
		Name = "QuickChat",
		tone = "raised",
		padding = PAD,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.new(0.9, 0, 0, HEIGHT_CASE),
		Visible = false,
		Parent = Screens.panels,
	})
	panel = page
	sizeLimit = Kit.Base.maxSize(panel, Vector2.new(720, HEIGHT_CASE))

	tabsHolder = Kit.frame({ Name = "Tabs", Size = UDim2.new(1, 0, 0, TABS), Parent = content })
	local tabs, choose = Kit.tabs({
		items = {
			{ id = "phrases", label = "Phrases", icon = "chat" },
			{ id = "emotes", label = "Emotes", icon = "palm" },
		},
		selected = tab,
		Size = UDim2.fromOffset(0, TABS),
		Parent = tabsHolder,
	}, function(id: string)
		if id ~= tab then
			setTab(id)
		end
	end)
	tabs.AutomaticSize = Enum.AutomaticSize.X
	chooseTab = choose

	-- Phrases: a grid, four to a row.
	phrasesPage = Kit.frame({ Name = "Phrases", Parent = content })
	local phrases = Kit.frame({ Name = "Grid", Size = UDim2.new(1, 0, 0, 144), Parent = phrasesPage })
	Kit.grid(phrases, UDim2.new(0.25, -T.space.s, 0, 40), T.space.s)
	for index, phrase in ipairs(QuickChat.PHRASES) do
		local button = Kit.button({
			text = phrase,
			variant = "secondary",
			size = "s",
			upper = false,
			Size = UDim2.fromScale(1, 1),
			LayoutOrder = index,
			Parent = phrases,
		}, function()
			QuickChatRemote:FireServer(index)
			QuickChatPanel.close()
		end)
		firstPhrase = firstPhrase or button
	end

	-- Emotes: a caption and More (or the way back to the wheel), then the wheel.
	emotesPage = Kit.frame({ Name = "Emotes", Parent = content })
	caption = Kit.label({
		Text = "",
		font = "label",
		size = "micro",
		color = C.dim,
		Size = UDim2.new(1, -120, 0, CAPTION),
		Parent = emotesPage,
	})
	moreButton = Kit.button({
		text = "More",
		variant = "ghost",
		size = "s",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = emotesPage,
	}, function()
		showMore(not moreShown)
	end)
	wheelHolder = Kit.frame({
		Name = "WheelHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CAPTION),
		Size = UDim2.fromOffset(WIDTH, Wheel.HEIGHT),
		Parent = emotesPage,
	})
	wheelScale = Kit.Base.make("UIScale", { Parent = wheelHolder })
	Wheel.mount(wheelHolder, play)
	showMore(false)

	ClientState.ProfileChanged:Connect(function()
		Wheel.refresh()
	end)
	Router.register("quickChat", {
		layer = "panel",
		window = panel,
		allowed = function(view)
			return Actions.emotesAllowed(view)
		end,
		show = function()
			if not inCase() then
				tab = "emotes"
			end
			if chooseTab then
				chooseTab(tab)
			end
			arrange()
			panel.Visible = true
			Wheel.shown(true)
			showMore(false)
			if keyConnection then
				keyConnection:Disconnect()
			end
			keyConnection = UserInputService.InputBegan:Connect(onKey)
		end,
		hide = function()
			panel.Visible = false
			Wheel.shown(false)
			if keyConnection then
				keyConnection:Disconnect()
				keyConnection = nil
			end
		end,
		firstSelection = function()
			return if tab == "phrases" then firstPhrase else Wheel.first()
		end,
	})
end

return QuickChatPanel
