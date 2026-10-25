-- Your inventory (the owner, 2026-10-25: "an inventory tab where players can equip everything they bought from the
-- shop (with tabs)"): everything you own, a tab for each kind down the left (with how many you have), your cards in
-- their tier's frame and colour in the middle, and on the right your look with the picked card on you, its name in its
-- tier's colour, and what you can do with it: wear or take off, use a seat, a chair or a win cutscene (and watch it),
-- write a custom death, or put an emote on a slot of your emote wheel. Open in the lobby only, like the shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local Net = require(Shared:WaitForChild("Net"))
local Rarity = require(Shared:WaitForChild("Rarity"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Card = require(script.Parent.Shop.Card)
local YourLook = require(script.Parent.Shop.YourLook)
local WinCinema = require(script.Parent.Parent.Presentation.WinCinema)

local ShopRequest = Net.event("ShopRequest")
local ProfileRequest = Net.event("ProfileRequest")

local C = Kit.color
local T = Kit.Tokens

local InventoryPanel = {}

-- Layout (design px).
local TABS_WIDTH = 176
local LOOK_WIDTH = 290
local INFO_HEIGHT = 200
local GAP = T.space.l

-- The tabs, in order: each a kind (Shared/Cosmetics), its label.
local TABS = {
	{ id = "emote", label = "Emotes" },
	{ id = "hat", label = "Hats" },
	{ id = "title", label = "Titles" },
	{ id = "grimoire", label = "Manual covers" },
	{ id = "writing", label = "Writing styles" },
	{ id = "verdict", label = "Verdict styles" },
	{ id = "death", label = "Death styles" },
	{ id = "reason", label = "Custom deaths" },
	{ id = "specter", label = "Deathsinger forms" },
	{ id = "chair", label = "Chairs" },
	{ id = "seat", label = "Seats" },
	{ id = "win", label = "Win cutscenes" },
}

local current = "emote"
local pickedId: string? = nil
local cards: { [string]: any } = {}
local grid: ScrollingFrame
local emptyNote: Frame
local look: YourLook.YourLook
local lookName: any
local lookLine: TextLabel
local actionHolder: Frame
local actionNote: TextLabel
local setTabLabel: { [string]: (string) -> () } = {}
local chooseTab: ((string) -> ())? = nil

-- (as the shop decides it: Shop panel's own)
local function owns(profile, item): boolean
	if item.source == "free" then
		return true
	end
	if item.source == "vip" then
		return table.find(profile.passes or {}, "vip") ~= nil
	end
	if item.pass and table.find(profile.passes or {}, item.pass) then
		return true
	end
	if item.kind == "title" then
		local key = string.gsub(item.id, "^title_", "")
		if profile.titles and profile.titles[key] then
			return true
		end
	end
	return table.find(profile.owned or {}, item.id) ~= nil
end

local function ownedOf(profile, kind: string): { Cosmetics.Item }
	local list = {}
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.kind == kind and owns(profile, item) then
			table.insert(list, item)
		end
	end
	-- (the rarest first, then by name)
	table.sort(list, function(a, b)
		local ra, rb = table.find(Rarity.ORDER, a.rarity) or 0, table.find(Rarity.ORDER, b.rarity) or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.name < b.name
	end)
	return list
end

local function worn(profile, item): boolean
	return profile.equipped ~= nil and profile.equipped[Cosmetics.slotOf(item)] == item.id
end

-- What a card's chip says about you and it.
local function stateOf(profile, item): { text: string, filled: boolean }?
	if item.kind == "emote" then
		local at = table.find(EmoteWheel.slots(profile.emoteWheel), item.emote)
		return if at then { text = "Wheel · " .. at, filled = true } else nil
	end
	if worn(profile, item) then
		local used = item.kind == "seat" or item.kind == "chair" or item.kind == "win" or item.kind == "reason"
		return { text = if used then "In use" else "Worn", filled = true }
	end
	return nil
end

local function clearAction()
	for _, child in ipairs(actionHolder:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	actionNote.Text = ""
end

local function showAction(profile, item: Cosmetics.Item?)
	clearAction()
	if not item then
		lookName:set("Your look")
		lookLine.Text = "Pick a card to see it on you."
		lookLine.TextColor3 = C.dim
		return
	end
	lookName:set(item.name)
	lookLine.Text =
		string.format("◆ %s  ·  %s", Rarity.name(item.rarity), Cosmetics.KIND_SINGULAR[item.kind] or item.kind)
	lookLine.TextColor3 = Rarity.color(item.rarity):Lerp(C.bone, 0.2)
	if item.kind == "emote" then
		-- the wheel's eight slots, its own lit: a click puts it there or takes it off
		local slots = EmoteWheel.slots(profile.emoteWheel)
		local at = table.find(slots, item.emote)
		local row = Kit.frame({ Name = "Wheel", Size = UDim2.new(1, 0, 0, T.touch), Parent = actionHolder })
		Kit.list(row, 4, true)
		for index = 1, EmoteWheel.SLOTS do
			local here = index == at
			Kit.button({
				text = tostring(index),
				variant = if here then "primary" else "secondary",
				size = "s",
				Size = UDim2.new(1 / EmoteWheel.SLOTS, -4 * (EmoteWheel.SLOTS - 1) / EmoteWheel.SLOTS, 1, 0),
				LayoutOrder = index,
				Parent = row,
			}, function()
				ProfileRequest:FireServer({
					action = "emoteWheel",
					slot = index,
					emote = if here then "" else item.emote,
				})
			end)
		end
		actionNote.Text = if at
			then string.format("On your emote wheel, key %d. Pick its number again to take it off.", at)
			else "Pick a number to put it on your emote wheel."
		return
	end
	local used = item.kind == "seat" or item.kind == "chair" or item.kind == "win" or item.kind == "reason"
	local hasPreview = item.kind == "win" and type(item.cut) == "string"
	local size = if hasPreview then UDim2.new(0.5, -T.space.s / 2, 0, T.touch) else UDim2.new(1, 0, 0, T.touch)
	local at = if hasPreview then UDim2.new(0.5, T.space.s / 2, 0, 0) else UDim2.new()
	if hasPreview then
		Kit.button(
			{ text = "Preview", variant = "secondary", size = "m", Size = size, Parent = actionHolder },
			function()
				Router.close("inventory")
				WinCinema.preview(item.cut, function()
					Router.open("inventory")
				end)
			end
		)
	end
	local on = worn(profile, item)
	Kit.button({
		text = if on then (if used then "Stop using" else "Take off") else (if used then "Use" else "Wear"),
		variant = if on then "ghost" else "primary",
		size = "m",
		Size = size,
		Position = at,
		Parent = actionHolder,
	}, function()
		ShopRequest:FireServer({ action = if on then "unequip" else "equip", itemId = item.id })
	end)
	if item.kind == "reason" then
		actionNote.Text = if on
			then string.format('You can write "%s" as a cause of death.', tostring(item.cause))
			else "Use it to write it in the Manual as a cause of death."
	elseif on then
		actionNote.Text = if used then "You are using it." else "You are wearing it."
	else
		actionNote.Text = tostring(item.blurb or "")
	end
end

local function pick(id: string?)
	pickedId = id
	for itemId, card in pairs(cards) do
		card:setPicked(itemId == id)
	end
	local item = Cosmetics.byId(id)
	look:show(item)
	local profile = ClientState.profile
	if profile then
		showAction(profile, item)
	end
end

local function deal()
	for _, card in pairs(cards) do
		card:destroy()
	end
	table.clear(cards)
	local profile = ClientState.profile
	if not profile then
		return
	end
	for _, tab in ipairs(TABS) do
		local count = #ownedOf(profile, tab.id)
		local set = setTabLabel[tab.id]
		if set then
			set(if count > 0 then string.format("%s  %d", tab.label, count) else tab.label)
		end
	end
	local list = ownedOf(profile, current)
	emptyNote.Visible = #list == 0
	for order, item in ipairs(list) do
		local state = stateOf(profile, item)
		local card = Card.new(item, {
			Parent = grid,
			LayoutOrder = order,
			chip = "",
			state = state,
			onPick = function()
				pick(item.id)
			end,
		})
		cards[item.id] = card
		if item.id == pickedId then
			card:setPicked(true)
		end
	end
	if pickedId and not cards[pickedId] then
		pick(nil)
	elseif pickedId then
		showAction(profile, Cosmetics.byId(pickedId))
	end
end

-- Opens the inventory on a kind's tab.
function InventoryPanel.open(kind: string?)
	if Router.open("inventory") ~= false and kind and chooseTab then
		chooseTab(kind)
	end
end

function InventoryPanel.init()
	local win = Kit.window({ name = "inventory", title = "Inventory", jp = "持ち物", size = "L" })
	-- the tabs, down the left
	local tabItems = {}
	for _, tab in ipairs(TABS) do
		table.insert(tabItems, { id = tab.id, label = tab.label })
	end
	local tabsScroll = Kit.scroll({
		Name = "Kinds",
		Size = UDim2.new(0, TABS_WIDTH, 1, 0),
		Parent = win.body,
	})
	-- (all twelve in sight on a desktop screen; a touch screen keeps fingertip rows and scrolls)
	local row = if Kit.Layout.isTouch() then T.touch else 40
	local tabs, choose = Kit.tabs({
		items = tabItems,
		selected = current,
		vertical = true,
		marker = true,
		rowHeight = row,
		Size = UDim2.new(1, 0, 0, #TABS * (row + T.space.xs)),
		Parent = tabsScroll,
	}, function(id)
		current = id
		pickedId = nil
		deal()
		pick(nil)
	end)
	chooseTab = choose
	for _, tab in ipairs(TABS) do
		local button = tabs:FindFirstChild("Tab_" .. tab.id, true)
		local label = if button then button:FindFirstChildWhichIsA("TextLabel", true) else nil
		if label then
			setTabLabel[tab.id] = function(text: string)
				label.Text = text
			end
		end
	end
	-- the cards, in the middle
	grid = Kit.scroll({
		Name = "Cards",
		Position = UDim2.new(0, TABS_WIDTH + GAP, 0, 0),
		Size = UDim2.new(1, -(TABS_WIDTH + LOOK_WIDTH + 2 * GAP), 1, 0),
		Parent = win.body,
	})
	Kit.grid(grid, UDim2.fromOffset(Card.WIDTH, Card.HEIGHT + 14), T.space.m)
	Kit.pad(grid, T.space.xs, T.space.xs)
	emptyNote = Kit.frame({
		Name = "Empty",
		Position = UDim2.new(0, TABS_WIDTH + GAP, 0, 0),
		Size = UDim2.new(1, -(TABS_WIDTH + LOOK_WIDTH + 2 * GAP), 0, 120),
		Visible = false,
		Parent = win.body,
	})
	Kit.list(emptyNote, T.space.s)
	Kit.label({
		Text = "Nothing of this kind is yours yet.",
		font = "bodyItalic",
		color = C.dim,
		LayoutOrder = 1,
		Parent = emptyNote,
	})
	Kit.button(
		{ text = "To the shop", icon = "cards", variant = "secondary", size = "s", LayoutOrder = 2, Parent = emptyNote },
		function()
			Router.close("inventory")
			Router.open("shop")
		end
	)
	-- your look, on the right
	local lookPanel = Kit.frame({
		Name = "Look",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, LOOK_WIDTH, 1, 0),
		Parent = win.body,
	})
	look = YourLook.new(lookPanel, { background = C.void, Size = UDim2.new(1, 0, 1, -INFO_HEIGHT) })
	local info = Kit.frame({
		Name = "Info",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, INFO_HEIGHT - T.space.s),
		Parent = lookPanel,
	})
	Kit.list(info, T.space.xs)
	lookName = Kit.text({
		face = "Head",
		text = "Your look",
		size = 26,
		color = C.bone,
		maxWidth = LOOK_WIDTH - 2 * T.space.m,
		LayoutOrder = 1,
		Parent = info,
	})
	lookLine = Kit.label({
		color = C.dim,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 2,
		Parent = info,
	})
	actionHolder = Kit.frame({ Name = "Action", Size = UDim2.new(1, 0, 0, T.touch), LayoutOrder = 3, Parent = info })
	actionNote = Kit.label({ font = "bodyItalic", size = "small", color = C.dim, LayoutOrder = 4, Parent = info })

	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			look:open(ClientState.profile)
			deal()
			pick(pickedId)
		end,
		hide = function()
			look:close()
		end,
	})
	ClientState.ProfileChanged:Connect(function()
		if Router.isOpen("inventory") then
			look:profileChanged(ClientState.profile)
			deal()
		end
	end)
end

return InventoryPanel
