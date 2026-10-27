-- Quick chat and the emote wheel: in a case, the only way to talk outside meetings. A page rises above the
-- bottom of the screen, each on its own key and with no tabs between them (2026-10-27: Q had opened both): the
-- phrases (a grid of them, M, in a case) and the emotes (Q, anywhere). The emotes are the wheel (UI/Wheel: the four
-- slots of Shared/EmoteWheel round a ring, pointed at with the mouse, a stick or a finger, played with a click, a
-- tap, A, letting go of Q, or the keys 1 to 4); the rest wait on the inventory's Emotes page until put on it. An
-- emote that cannot be played where you are (one made for the lobby only, in a case) is locked, with the reason.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared:WaitForChild("Bindings"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
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
local CAPTION = 22
local WIDTH = 470
local PAD = T.space.l
local GRID = 144 -- the phrases' grid
local HEIGHT_EMOTES = PAD * 2 + CAPTION + Wheel.HEIGHT
local HEIGHT_PHRASES = PAD * 2 + GRID
-- The slot a key plays: the wheel's slot keys (1 to 4 unless the player set their own, Shared/Bindings).
local function slotFor(key: Enum.KeyCode): number?
	local profile = ClientState.profile
	local saved = profile and profile.keybinds or nil
	for index = 1, EmoteWheel.SLOTS do
		if table.find(Bindings.keys("slot" .. index, "keyboard", saved), key.Name) then
			return index
		end
	end
	return nil
end

local panel: Frame
local sizeLimit: UISizeConstraint?
local phrasesPage: Frame
local emotesPage: Frame
local caption: TextLabel
local wheelHolder: Frame
local wheelScale: UIScale
local firstPhrase: GuiObject? = nil
local tab = "emotes"
local keyConnection: RBXScriptConnection? = nil

function QuickChatPanel.toggle()
	Router.toggle("quickChat")
end

function QuickChatPanel.close()
	Router.close(if tab == "phrases" then "phrases" else "quickChat", "user")
end

-- The wheel asks to play an emote: it goes to the server, and the page closes.
local function play(emote: QuickChat.Emote)
	EmoteController.play(emote.id)
	QuickChatPanel.close()
end

-- The wheel stands on its own over the world: no panel behind it (the old grey box). The phrases keep the panel,
-- which they need to be read.
local function backing()
	local surface = panel and panel:FindFirstChild("Surface")
	if surface and surface:IsA("GuiObject") then
		surface.Visible = tab ~= "emotes"
	end
end

-- Lays the page out for the one it shows: the phrases' grid, or the wheel.
local function arrange()
	local phrases = tab == "phrases"
	local height = if phrases then HEIGHT_PHRASES else HEIGHT_EMOTES
	panel.Size = UDim2.new(0.9, 0, 0, height)
	if sizeLimit then
		sizeLimit.MaxSize = Vector2.new(if phrases then 720 else WIDTH + PAD * 2, height)
	end
	phrasesPage.Size = UDim2.fromScale(1, 1)
	emotesPage.Size = UDim2.fromScale(1, 1)
	phrasesPage.Visible = tab == "phrases"
	emotesPage.Visible = tab == "emotes"
	backing()
	-- A narrow screen shrinks the wheel to fit.
	task.defer(function()
		local width = emotesPage.AbsoluteSize.X / Kit.Base.scaleOf(emotesPage)
		wheelScale.Scale = if width > 0 then math.min(1, width / WIDTH) else 1
	end)
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
		Size = UDim2.new(0.9, 0, 0, HEIGHT_EMOTES),
		Visible = false,
		Parent = Screens.panels,
	})
	panel = page
	sizeLimit = Kit.Base.maxSize(panel, Vector2.new(720, HEIGHT_EMOTES))

	-- Phrases: a grid, four to a row.
	phrasesPage = Kit.frame({ Name = "Phrases", Parent = content })
	local phrases = Kit.frame({ Name = "Grid", Size = UDim2.new(1, 0, 0, GRID), Parent = phrasesPage })
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

	-- Emotes: a caption, then the wheel.
	emotesPage = Kit.frame({ Name = "Emotes", Parent = content })
	caption = Kit.label({
		Text = string.format("EMOTES  ·  1 TO %d", EmoteWheel.SLOTS),
		font = "label",
		size = "micro",
		color = C.bone,
		Size = UDim2.new(1, 0, 0, CAPTION),
		Parent = emotesPage,
	})
	-- (over the world, with no panel behind it: an outline keeps it readable)
	caption.TextStrokeColor3 = C.void
	caption.TextStrokeTransparency = 0.35
	wheelHolder = Kit.frame({
		Name = "WheelHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CAPTION),
		Size = UDim2.fromOffset(WIDTH, Wheel.HEIGHT),
		Parent = emotesPage,
	})
	wheelScale = Kit.Base.make("UIScale", { Parent = wheelHolder })
	Wheel.mount(wheelHolder, play)

	ClientState.ProfileChanged:Connect(function()
		Wheel.refresh()
	end)
	-- Two views on the one page: the emotes (Q) and the phrases (M), each opened on its own, never switched between.
	local function view(id: string, page: string, allowed: (any) -> boolean)
		Router.register(id, {
			layer = "panel",
			window = panel,
			allowed = allowed,
			show = function()
				tab = page
				arrange()
				panel.Visible = true
				Wheel.shown(page == "emotes")
				if keyConnection then
					keyConnection:Disconnect()
					keyConnection = nil
				end
				if page == "emotes" then
					keyConnection = UserInputService.InputBegan:Connect(onKey)
				end
			end,
			hide = function()
				if tab ~= page then
					return
				end
				panel.Visible = false
				Wheel.shown(false)
				if keyConnection then
					keyConnection:Disconnect()
					keyConnection = nil
				end
			end,
			firstSelection = function()
				return if page == "phrases" then firstPhrase else Wheel.first()
			end,
		})
	end
	view("quickChat", "emotes", Actions.emotesAllowed)
	view("phrases", "phrases", function(state)
		return state.participant and Actions.emotesAllowed(state)
	end)
end

return QuickChatPanel
