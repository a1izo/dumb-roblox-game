-- Quick chat and the emote wheel: in a case, the only way to talk outside meetings. A page rises above the
-- bottom of the screen. In a case it has two tabs, Phrases (a grid of them) and Emotes; in the lobby it is
-- the emotes alone. The emotes are the wheel (Shared/EmoteWheel): eight slots round a ring, filled in the
-- shop's Your look, played with a click, a tap or the keys 1 to 8; "More" in its middle lists every emote
-- you have. An emote made for the lobby only (it looks like a death, an arrest or the Eyes) is greyed in a
-- case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local Actions = require(script.Parent.Parent.Input.Actions)
local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local UiSound = require(script.Parent.Core.UiSound)
local Screens = require(script.Parent.Screens)

local QuickChatRemote = Net.event("QuickChat")

local C = Kit.color
local T = Kit.Tokens

local QuickChatPanel = {}

-- Layout (design px).
local TABS = 48 -- the tab row, in a case
local CAPTION = 22
local RING = Vector2.new(470, 260) -- the wheel's ring of slots
local RADIUS = Vector2.new(175, 108)
local SLOT = Vector2.new(120, 44)
local PAD = T.space.l
local HEIGHT_CASE = PAD * 2 + TABS + T.space.s + CAPTION + RING.Y
local HEIGHT_LOBBY = PAD * 2 + CAPTION + RING.Y
local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

local panel: Frame
local sizeLimit: UISizeConstraint?
local tabsHolder: Frame
local chooseTab: ((string) -> ())? = nil
local phrasesPage: Frame
local emotesPage: Frame
local caption: TextLabel
local ring: Frame
local ringScale: UIScale
local morePage: Frame
local moreGrid: ScrollingFrame
local backButton: GuiObject
local firstPhrase: GuiObject? = nil
local firstSlot: GuiObject? = nil
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

local function usable(emote: QuickChat.Emote): boolean
	return not (emote.lobbyOnly and inCase())
end

local function play(emote: QuickChat.Emote)
	if not usable(emote) then
		return
	end
	EmoteController.play(emote.id)
	QuickChatPanel.close()
end

-- A slot of the wheel (or an emote in More): its name on a notched plate, its key on the left.
local function slotButton(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local button = Kit.Base.hit({
		Name = props.Name or "Slot",
		Size = props.Size or UDim2.fromOffset(SLOT.X, SLOT.Y),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	Kit.Controls.focusable(button)
	local enabled = props.enabled ~= false and onClick ~= nil
	local rest = if props.empty then C.raised else C.lifted
	local bg = Kit.frame({ Name = "Bg", Size = UDim2.fromScale(1, 1), Parent = button })
	local fill: GuiObject? = nil
	local function paint(color: Color3)
		if fill and fill:IsA("ImageLabel") then
			fill.ImageColor3 = color
		elseif fill and fill:IsA("Frame") then
			fill.BackgroundColor3 = color
		end
	end
	Kit.Surfaces.redrawWhenReady(button, function()
		Kit.clear(bg)
		fill = Kit.Surfaces.notch(bg, { shape = "button", color = rest })
	end)
	local left = T.space.s
	if props.key then
		local cap = Kit.Controls.keycap({
			text = props.key,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			ZIndex = 2,
			Parent = button,
		})
		if cap.Visible then
			left = 34
		end
	end
	Kit.label({
		Name = "Name",
		Text = props.text,
		size = "body",
		color = if props.empty or not enabled then C.faint else C.white,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + T.space.s), 1, 0),
		ZIndex = 2,
		Parent = button,
	})
	button.Active = enabled
	if enabled then
		button.MouseEnter:Connect(function()
			paint(C.g4)
			UiSound.play("uiHover")
		end)
		button.MouseLeave:Connect(function()
			paint(rest)
		end)
		button.SelectionGained:Connect(function()
			paint(C.g4)
		end)
		button.SelectionLost:Connect(function()
			paint(rest)
		end)
		button.Activated:Connect(function()
			UiSound.play("uiClick")
			if onClick then
				onClick()
			end
		end)
	end
	return button
end

local function showMore(on: boolean)
	ring.Visible = not on
	morePage.Visible = on
	backButton.Visible = on
	caption.Text = if on then "ALL YOUR EMOTES" else "EMOTES  ·  1 TO 8"
end

-- The ring: the eight slots from the top, clockwise, and More in the middle.
local function buildRing()
	Kit.clear(ring)
	firstSlot = nil
	local profile = ClientState.profile
	local slots = EmoteWheel.slots(profile and profile.emoteWheel)
	local centre = RING / 2
	for index, id in ipairs(slots) do
		local angle = math.rad(-90 + (index - 1) * 45)
		local at = centre + Vector2.new(math.cos(angle) * RADIUS.X, math.sin(angle) * RADIUS.Y)
		local emote = QuickChat.emote(id)
		local owned = emote ~= nil and EmoteWheel.owns(profile, emote)
		local button = slotButton(
			{
				text = if emote and owned then emote.name else "Empty",
				key = tostring(index),
				empty = not (emote and owned),
				enabled = emote ~= nil and owned and usable(emote),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(at.X, at.Y),
				LayoutOrder = index,
				Parent = ring,
			},
			if emote and owned
				then function()
					play(emote)
				end
				else nil
		)
		if index == 1 then
			firstSlot = button
		end
	end
	Kit.button({
		text = "More",
		variant = "ghost",
		size = "s",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(centre.X, centre.Y),
		Size = UDim2.fromOffset(96, 40),
		Parent = ring,
	}, function()
		showMore(true)
	end)
end

-- More: every emote you have, in the shop's order, and a way back to the ring.
local function buildMore()
	Kit.clear(moreGrid)
	local profile = ClientState.profile
	local order = 0
	for _, emote in ipairs(QuickChat.EMOTES) do
		if EmoteWheel.owns(profile, emote) then
			order += 1
			slotButton({
				text = emote.name,
				enabled = usable(emote),
				Size = UDim2.fromScale(1, 1),
				LayoutOrder = order,
				Parent = moreGrid,
			}, function()
				play(emote)
			end)
		end
	end
end

local function refresh()
	if not panel then
		return
	end
	buildRing()
	buildMore()
end

-- Lays the page out for where you are: tabs in a case, the emotes alone in the lobby.
local function arrange()
	local case = inCase()
	local height = if case then HEIGHT_CASE else HEIGHT_LOBBY
	panel.Size = UDim2.new(0.9, 0, 0, height)
	if sizeLimit then
		sizeLimit.MaxSize = Vector2.new(if case then 720 else RING.X + PAD * 2, height)
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
	-- A narrow screen shrinks the ring to fit.
	task.defer(function()
		local width = emotesPage.AbsoluteSize.X / Kit.Base.scaleOf(emotesPage)
		ringScale.Scale = if width > 0 then math.min(1, width / RING.X) else 1
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
	local index = table.find(KEYS, input.KeyCode)
	if not index then
		return
	end
	local profile = ClientState.profile
	local emote = QuickChat.emote(EmoteWheel.slots(profile and profile.emoteWheel)[index])
	if emote and EmoteWheel.owns(profile, emote) then
		play(emote)
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

	-- Emotes: a caption, then the ring (or More in its place).
	emotesPage = Kit.frame({ Name = "Emotes", Parent = content })
	caption = Kit.label({
		Text = "",
		font = "label",
		size = "micro",
		color = C.dim,
		Size = UDim2.new(1, -120, 0, CAPTION),
		Parent = emotesPage,
	})
	ring = Kit.frame({
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CAPTION),
		Size = UDim2.fromOffset(RING.X, RING.Y),
		Parent = emotesPage,
	})
	ringScale = Kit.Base.make("UIScale", { Parent = ring })
	-- More sits under the way back to the wheel (top right, where the caption ends).
	morePage = Kit.frame({
		Name = "More",
		Position = UDim2.fromOffset(0, T.touch + T.space.xs),
		Size = UDim2.new(1, 0, 1, -(T.touch + T.space.xs)),
		Visible = false,
		Parent = emotesPage,
	})
	moreGrid = Kit.scroll({ Name = "All", Parent = morePage })
	Kit.grid(moreGrid, UDim2.fromOffset(140, SLOT.Y), T.space.s)
	backButton = Kit.button({
		text = "Wheel",
		icon = "back",
		variant = "ghost",
		size = "s",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = emotesPage,
	}, function()
		showMore(false)
	end)
	showMore(false)

	ClientState.ProfileChanged:Connect(refresh)
	refresh()
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
			showMore(false)
			refresh()
			arrange()
			panel.Visible = true
			if keyConnection then
				keyConnection:Disconnect()
			end
			keyConnection = UserInputService.InputBegan:Connect(onKey)
		end,
		hide = function()
			panel.Visible = false
			if keyConnection then
				keyConnection:Disconnect()
				keyConnection = nil
			end
		end,
		firstSelection = function()
			return if tab == "phrases" then firstPhrase else firstSlot
		end,
	})
end

return QuickChatPanel
