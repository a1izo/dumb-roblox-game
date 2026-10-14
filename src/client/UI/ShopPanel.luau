-- The shop, "Death's hand": a table of tarot cards dealt by Death (Shop/Card). The suits run along the
-- top (Cosmetics.SUITS: Today's hand, Wardrobe, Diavolo, Ace, The dead, Emotes, Titles, Sets, and Robux
-- once a product is on sale); a suit with nothing in it yet is not shown. Today's hand is the day's six,
-- dealt face down (the same six for everyone): each is turned over with a click, and stays turned that
-- day (ShopService "turn"). The other suits lay their cards out by kind (Emotes by its sections: dances,
-- poses, with props, strolls, duo); Sets lays out each set (Shared/Sets) with how many of its pieces you
-- own, and the title it earns.
--
-- Picking a card lifts it and shows it on you in Your look (Shop/YourLook), on the right; under it, what
-- you can do: hold "Buy · 300" for half a second (a bought thing is worn at once; a bought emote goes on
-- the emote wheel's first empty slot), "N more coins" when you are short, or wear / take off what you
-- own. An emote you own shows the wheel's eight slots instead: pick one to put it there (Shared/EmoteWheel);
-- one that can be a stance also offers to be yours (stand still a while and you settle into it).
-- On a phone the cards fill the window and Your look rises as a sheet from the bottom when a card is
-- picked. Open in the lobby only.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local Sets = require(Shared:WaitForChild("Sets"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Card = require(script.Parent.Shop.Card)
local YourLook = require(script.Parent.Shop.YourLook)

local ShopRequest = Net.event("ShopRequest")
local ProfileRequest = Net.event("ProfileRequest")
local LocalPlayer = Players.LocalPlayer

local C = Kit.color
local T = Kit.Tokens

local ShopPanel = {}

-- Layout (design px).
local TOP = 40 -- the purse line
local SUITS_HEIGHT = 48
local LOOK_WIDTH = 300
local INFO_HEIGHT = 226 -- under Your look: the name, its line, the button, the stance button, a note
local GAP = T.space.l
local HOLD_SECONDS = 0.5

local purseLabel: TextLabel
local noteLabel: TextLabel
local suitScroll: ScrollingFrame
local suitTabs: Frame?
local chooseSuit: ((string) -> ())? = nil
local tableScroll: ScrollingFrame
local lookPanel: Frame
local look: YourLook.YourLook
local lookName: any
local lookLine: TextLabel
local actionHolder: Frame
local stanceHolder: Frame
local actionNote: TextLabel
local sheetClose: TextButton

local currentSuit = "today"
local pickedId: string? = nil
local cards: { [string]: Card.Card } = {}
local turnedHere: { [string]: boolean } = {} -- turned on this screen, before the profile says so
local shownSuits = ""
local firstButton: GuiObject? = nil

local function owns(profile, item): boolean
	if item.source == "vip" then
		return table.find(profile.passes or {}, "vip") ~= nil
	end
	-- (the Emote Pack's four emotes come with the pass)
	if item.pass and table.find(profile.passes or {}, item.pass) then
		return true
	end
	if item.kind == "title" then
		local key = string.gsub(item.id, "^title_", "")
		if profile.titles and profile.titles[key] then
			return true
		end
	end
	return table.find(profile.owned, item.id) ~= nil
end

local function hasPass(profile, key: string): boolean
	return table.find(profile.passes or {}, key) ~= nil
end

local function formatTime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%dh %02dm", hours, minutes)
end

local function capitalised(text: string): string
	return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

local function onSale(): boolean
	for _, pack in ipairs(Products.COIN_PACKS) do
		if pack.id ~= 0 then
			return true
		end
	end
	for _, pass in ipairs(Products.PASSES) do
		if pass.id ~= 0 then
			return true
		end
	end
	return false
end

-- The suits worth showing: Today's hand always; a suit of kinds once it has something in it; Sets once
-- there are sets; Robux once something is on sale.
local function suits(): { Cosmetics.Suit }
	local list = {}
	for _, suit in ipairs(Cosmetics.SUITS) do
		local show
		if suit.id == "today" then
			show = true
		elseif suit.id == "robux" then
			show = onSale()
		elseif suit.id == "sets" then
			show = #Sets.LIST > 0
		elseif suit.kinds then
			show = false
			for _, kind in ipairs(suit.kinds) do
				if #Cosmetics.ofKind(kind) > 0 then
					show = true
				end
			end
		else
			show = false
		end
		if show then
			table.insert(list, suit)
		end
	end
	return list
end

-- What a card's chip says: its price, or where you stand with it.
local function chipFor(profile, item: Cosmetics.Item): (string, boolean)
	if owns(profile, item) and item.kind == "emote" then
		return if EmoteWheel.slotOf(profile.emoteWheel, item.emote) then "On wheel" else "Owned", false
	elseif owns(profile, item) then
		return if profile.equipped[item.kind] == item.id then "Worn" else "Owned", false
	elseif item.source == "vip" then
		return "VIP", false
	elseif not item.price then
		return "Earned", false
	elseif item.source == "rotation" and not ShopRotation.isFeatured(item.id, os.time()) then
		return "Not today", false
	end
	return tostring(item.price), true
end

-- Your look -------------------------------------------------------------------------------------------------

local function clearAction()
	for _, holder in ipairs({ actionHolder, stanceHolder }) do
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	stanceHolder.Visible = false
end

-- An emote you own: the wheel's eight slots, numbered, its own lit; a click puts it there (or takes it off
-- the slot it is in).
local function wheelSlots(profile, item: Cosmetics.Item)
	local slots = EmoteWheel.slots(profile.emoteWheel)
	local at = table.find(slots, item.emote)
	local row = Kit.frame({ Name = "Wheel", Size = UDim2.fromScale(1, 1), Parent = actionHolder })
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
			ProfileRequest:FireServer({ action = "emoteWheel", slot = index, emote = if here then "" else item.emote })
		end)
	end
	actionNote.Text = if at
		then string.format("On your emote wheel, key %d. Pick its number again to take it off.", at)
		else "Pick a number to put it on your emote wheel (Q)."
	if item.stance then
		local mine = profile.stance == item.id
		stanceHolder.Visible = true
		Kit.button({
			text = if mine then "Your stance  ·  take it off" else "Make it your stance",
			variant = if mine then "ghost" else "secondary",
			size = "s",
			upper = false,
			Size = UDim2.fromScale(1, 1),
			Parent = stanceHolder,
		}, function()
			ShopRequest:FireServer({ action = "stance", itemId = item.id })
		end)
	end
end

-- The button under Your look for the picked item, and the note under it.
local function showAction(profile, item: Cosmetics.Item?)
	clearAction()
	actionNote.Text = ""
	if not item then
		lookName:set("Your look")
		lookLine.Text = "Pick a card to see it on you."
		return
	end
	lookName:set(item.name)
	lookLine.Text = string.format(
		"%s  ·  %s",
		capitalised(item.rarity),
		Cosmetics.KIND_SINGULAR[item.kind] or item.kind
	) .. (if item.stance then "  ·  Stance" elseif item.stroll then "  ·  Stroll" else "")
	local size = UDim2.new(1, 0, 0, T.touch)
	local function press(text: string, action: string, variant: string)
		Kit.button({ text = text, variant = variant, size = "m", Size = size, Parent = actionHolder }, function()
			ShopRequest:FireServer({ action = action, itemId = item.id })
		end)
	end
	local function closed(text: string)
		local button =
			Kit.button({ text = text, variant = "secondary", size = "m", Size = size, Parent = actionHolder })
		Kit.setEnabled(button, false)
	end
	if owns(profile, item) and item.kind == "emote" then
		wheelSlots(profile, item)
	elseif owns(profile, item) then
		if profile.equipped[item.kind] == item.id then
			press("Take off", "unequip", "ghost")
			actionNote.Text = "You are wearing it."
		else
			press("Wear", "equip", "primary")
		end
	elseif item.source == "vip" then
		closed("VIP pass")
		actionNote.Text = "Comes with the VIP pass."
	elseif item.source == "set" then
		closed("Set title")
		actionNote.Text = "Yours with every piece of its set."
	elseif not item.price then
		closed("Earned")
		actionNote.Text = "Earned in play, never sold."
	elseif item.source == "rotation" and not ShopRotation.isFeatured(item.id, os.time()) then
		closed("Not today")
		actionNote.Text = "Only sold on a day it is in Today's hand."
	elseif profile.coins < item.price then
		closed(string.format("%d more coins", item.price - profile.coins))
		actionNote.Text = string.format("It costs %d coins.", item.price)
	else
		Kit.hold(
			{
				text = string.format("Buy  ·  %d", item.price),
				icon = "coin",
				variant = "primary",
				size = "m",
				Size = size,
				Parent = actionHolder,
			},
			HOLD_SECONDS,
			function()
				ShopRequest:FireServer({ action = "buy", itemId = item.id })
			end
		)
		actionNote.Text = "Hold to buy. You wear it at once."
	end
end

local function openSheet(open: boolean)
	if not Kit.Layout.isPhone() then
		lookPanel.Visible = true
		return
	end
	if open then
		lookPanel.Visible = true
		Motion.slideIn(lookPanel, Vector2.new(0, 60), T.motion.slow)
	else
		lookPanel.Visible = false
	end
end

local function pick(item: Cosmetics.Item?)
	pickedId = if item then item.id else nil
	for id, card in pairs(cards) do
		card:setPicked(id == pickedId)
	end
	look:show(item)
	showAction(ClientState.profile, item)
	if item then
		openSheet(true)
	end
end

-- The table ------------------------------------------------------------------------------------------------

local function section(title: string?, order: number): Frame
	local holder = Kit.frame({
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = tableScroll,
	})
	Kit.list(holder, T.space.s)
	if title then
		Kit.heading({ text = title, LayoutOrder = 1, Parent = holder })
	end
	local grid = Kit.frame({
		Name = "Cards",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = holder,
	})
	Kit.grid(grid, UDim2.fromOffset(Card.WIDTH, Card.HEIGHT + 10), T.space.m)
	return grid
end

local function deal(profile, item: Cosmetics.Item, grid: Frame, order: number, faceDown: boolean)
	local text, coin = chipFor(profile, item)
	local card = Card.new(item, {
		Parent = grid,
		LayoutOrder = order,
		chip = text,
		chipCoin = coin,
		faceDown = faceDown,
		onPick = function()
			ShopPanel.choose(item.id)
		end,
	})
	cards[item.id] = card
	firstButton = firstButton or card.hit
	if item.id == pickedId then
		card:setPicked(true)
	end
end

-- Robux (only once something is on sale): coin packs, passes, the custom alias.
local function robuxCard(
	grid: Frame,
	order: number,
	title: string,
	lines: { string },
	buttonText: string?,
	onBuy: (() -> ())?
)
	local card = Kit.card({ Size = UDim2.fromScale(1, 1), LayoutOrder = order, Parent = grid })
	Kit.text({ face = "Head", text = title, size = 22, color = C.bone, Parent = card })
	Kit.label({
		Text = table.concat(lines, "\n"),
		color = C.dim,
		Position = UDim2.fromOffset(0, 34),
		Parent = card,
	})
	if buttonText then
		local button = Kit.button({
			text = buttonText,
			icon = if onBuy then "coin" else "check",
			variant = if onBuy then "primary" else "secondary",
			size = "s",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, T.touch),
			Parent = card,
		}, onBuy)
		Kit.setEnabled(button, onBuy ~= nil)
		firstButton = firstButton or button
	end
end

local function buildRobux(profile)
	local holder = section(nil, 1)
	local layout = holder:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.CellSize = UDim2.fromOffset(220, 196)
	end
	local order = 0
	for _, pack in ipairs(Products.COIN_PACKS) do
		if pack.id ~= 0 then
			order += 1
			robuxCard(
				holder,
				order,
				pack.label,
				{ string.format("%d coins", pack.coins), "Premium: +10%" },
				"Buy",
				function()
					MarketplaceService:PromptProductPurchase(LocalPlayer, pack.id)
				end
			)
		end
	end
	for _, pass in ipairs(Products.PASSES) do
		local owned = hasPass(profile, pass.key)
		if pass.id ~= 0 or owned then
			order += 1
			robuxCard(
				holder,
				order,
				pass.name,
				pass.perks,
				if owned then "Owned" else "Buy pass",
				if owned
					then nil
					else function()
						MarketplaceService:PromptGamePassPurchase(LocalPlayer, pass.id)
					end
			)
		end
	end
	if hasPass(profile, "alias") then
		order += 1
		local card = Kit.card({ Size = UDim2.fromScale(1, 1), LayoutOrder = order, Parent = holder })
		Kit.text({ face = "Head", text = "Your custom alias", size = 22, color = C.bone, Parent = card })
		local _, box = Kit.field({
			placeholder = "3 to 12 letters",
			text = profile.alias or "",
			maxLength = 12,
			size = "body",
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, T.touch),
			Parent = card,
		})
		Kit.button({
			text = "Save alias",
			icon = "quill",
			variant = "primary",
			size = "s",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, T.touch),
			Parent = card,
		}, function()
			ProfileRequest:FireServer({ action = "alias", alias = box.Text })
		end)
	end
end

-- The suits along the top (built again only when which suits show changes).
local function buildSuits()
	local list = suits()
	local ids = {}
	local items = {}
	for _, suit in ipairs(list) do
		table.insert(ids, suit.id)
		table.insert(items, { id = suit.id, label = suit.name, icon = suit.icon })
	end
	local key = table.concat(ids, ",")
	if key == shownSuits and suitTabs then
		return
	end
	shownSuits = key
	if not table.find(ids, currentSuit) then
		currentSuit = "today"
	end
	if suitTabs then
		suitTabs:Destroy()
	end
	local tabs, choose = Kit.tabs({
		items = items,
		selected = currentSuit,
		Size = UDim2.fromOffset(0, SUITS_HEIGHT),
		Parent = suitScroll,
	}, function(id: string)
		if id ~= currentSuit then
			currentSuit = id
			pick(nil)
			ShopPanel.rebuild()
		end
	end)
	tabs.AutomaticSize = Enum.AutomaticSize.X
	suitTabs = tabs
	chooseSuit = choose
end

function ShopPanel.rebuild()
	for _, card in pairs(cards) do
		card:destroy()
	end
	table.clear(cards)
	Kit.clear(tableScroll)
	firstButton = nil
	local profile = ClientState.profile
	if not profile then
		purseLabel.Text = "Loading your profile…"
		return
	end
	buildSuits()
	purseLabel.Text = string.format("%d coins", profile.coins)
	noteLabel.Text = ""
	local now = os.time()
	if currentSuit == "today" then
		local day = ShopRotation.dayOf(now)
		local turned = ShopRotation.turned(profile.shopTurned, day)
		local grid = section(nil, 1)
		local faceDown = 0
		for index, id in ipairs(ShopRotation.forDay(day)) do
			local item = Cosmetics.byId(id)
			if item then
				local down = not table.find(turned, id) and not turnedHere[id]
				if down then
					faceDown += 1
				end
				deal(profile, item, grid, index, down)
			end
		end
		noteLabel.Text = (if faceDown > 0 then "Six cards, dealt today: turn them over.  ·  " else "")
			.. "A new hand in "
			.. formatTime(ShopRotation.secondsLeft(now))
	elseif currentSuit == "robux" then
		buildRobux(profile)
	elseif currentSuit == "sets" then
		for index, set in ipairs(Sets.LIST) do
			local have = Sets.progress(set, function(id: string): boolean
				local item = Cosmetics.byId(id)
				return item ~= nil and owns(profile, item)
			end)
			local title = Cosmetics.byId(set.title)
			local done = title ~= nil and owns(profile, title)
			local grid = section(
				string.format(
					"%s  ·  %s",
					set.name,
					if done then "complete" else string.format("%d of %d", have, #set.pieces)
				),
				index
			)
			for order, id in ipairs(set.pieces) do
				local item = Cosmetics.byId(id)
				if item then
					deal(profile, item, grid, order, false)
				end
			end
			if title then
				deal(profile, title, grid, #set.pieces + 1, false)
			end
		end
		noteLabel.Text = "Own every piece of a set and its title is yours."
	else
		local suit = Cosmetics.suit(currentSuit)
		local order = 0
		local function lay(title: string, items: { Cosmetics.Item })
			if #items > 0 then
				order += 1
				local grid = section(title, order)
				for index, item in ipairs(items) do
					deal(profile, item, grid, index, false)
				end
			end
		end
		for _, kind in ipairs((suit and suit.kinds) or {}) do
			local items = Cosmetics.ofKind(kind)
			if kind == "emote" then
				-- Emotes by their sections.
				for _, category in ipairs(Cosmetics.EMOTE_CATEGORIES) do
					local inSection = {}
					for _, item in ipairs(items) do
						if item.category == category.id then
							table.insert(inSection, item)
						end
					end
					lay(category.name, inSection)
				end
			else
				lay(Cosmetics.KIND_NAMES[kind] or kind, items)
			end
		end
	end
	local picked = Cosmetics.byId(pickedId)
	showAction(profile, picked)
end

local function arrange()
	local phone = Kit.Layout.isPhone()
	local top = TOP + SUITS_HEIGHT + T.space.s
	if phone then
		tableScroll.Position = UDim2.fromOffset(0, top)
		tableScroll.Size = UDim2.new(1, 0, 1, -top)
		lookPanel.AnchorPoint = Vector2.new(0.5, 1)
		lookPanel.Position = UDim2.fromScale(0.5, 1)
		lookPanel.Size = UDim2.new(1, 0, 0.8, 0)
		lookPanel.Visible = pickedId ~= nil
		sheetClose.Visible = true
	else
		tableScroll.Position = UDim2.fromOffset(0, top)
		tableScroll.Size = UDim2.new(1, -(LOOK_WIDTH + GAP), 1, -top)
		lookPanel.AnchorPoint = Vector2.new(1, 0)
		lookPanel.Position = UDim2.new(1, 0, 0, top)
		lookPanel.Size = UDim2.new(0, LOOK_WIDTH, 1, -top)
		lookPanel.Visible = true
		sheetClose.Visible = false
	end
end

-- For checks: shows a suit, as its tab does.
function ShopPanel.showSuit(id: string)
	currentSuit = id
	if chooseSuit then
		chooseSuit(id) -- (lights its tab; the suit is already the current one, so nothing is rebuilt twice)
	end
	pick(nil)
	ShopPanel.rebuild()
end

-- Picks a card on the table (a click on it): a face-down one is turned over first.
function ShopPanel.choose(id: string)
	local card = cards[id]
	if not card then
		return
	end
	if card.faceDown then
		turnedHere[id] = true
		ShopRequest:FireServer({ action = "turn", itemId = id })
		card:turn(function()
			pick(card.item)
		end)
	else
		pick(card.item)
	end
end

-- For checks: the suit shown, the card picked, the cards on the table and how many lie face down.
function ShopPanel.state(): { suit: string, picked: string?, cards: number, faceDown: number }
	local count, down = 0, 0
	for _, card in pairs(cards) do
		count += 1
		if card.faceDown then
			down += 1
		end
	end
	return { suit = currentSuit, picked = pickedId, cards = count, faceDown = down }
end

function ShopPanel.init()
	local win = Kit.window({ name = "shop", title = "Death's hand", jp = "ショップ", size = "L" })
	local body = win.body
	-- The purse on the left, a note on the right.
	local purse = Kit.frame({ Name = "Purse", Size = UDim2.new(0.4, 0, 0, 32), Parent = body })
	Kit.list(purse, T.space.s, true)
	Kit.icon({ name = "coin", size = 24, color = C.candle, LayoutOrder = 1, Parent = purse })
	purseLabel = Kit.label({
		font = "bodyBold",
		size = "lead",
		color = C.candle,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = purse,
	})
	noteLabel = Kit.label({
		font = "bodyItalic",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.6, 0, 0, 32),
		Parent = body,
	})
	-- The suits: one scrolling row on every screen.
	suitScroll = Kit.Base.make("ScrollingFrame", {
		Name = "Suits",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TOP),
		Size = UDim2.new(1, 0, 0, SUITS_HEIGHT),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Parent = body,
	}) :: any
	tableScroll = Kit.scroll({ Name = "Table", Parent = body })
	Kit.pad(tableScroll, T.space.xs, T.space.xs)
	Kit.list(tableScroll, T.space.l)
	-- Your look, with the picked card's name, its line, what you can do and a note.
	lookPanel = Kit.card({ Name = "YourLookPanel", tone = "page", padding = 0, ZIndex = 30, Parent = body })
	look = YourLook.new(lookPanel, { background = C.void, Size = UDim2.new(1, 0, 1, -INFO_HEIGHT) })
	local info = Kit.frame({
		Name = "Info",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, INFO_HEIGHT),
		Parent = lookPanel,
	})
	Kit.pad(info, T.space.m, T.space.m)
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
	stanceHolder = Kit.frame({
		Name = "Stance",
		Size = UDim2.new(1, 0, 0, T.touch),
		Visible = false,
		LayoutOrder = 4,
		Parent = info,
	})
	actionNote = Kit.label({ font = "bodyItalic", color = C.dim, LayoutOrder = 5, Parent = info })
	sheetClose = Kit.iconButton({
		icon = "cross",
		size = 28,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		ZIndex = 40,
		Parent = lookPanel,
	}, function()
		openSheet(false)
	end)
	ClientState.ProfileChanged:Connect(function()
		if Router.isOpen("shop") then
			-- The cards follow the profile; the 3D copy is taken again only if what you wear changed.
			ShopPanel.rebuild()
			look:profileChanged(ClientState.profile)
		end
	end)
	Kit.Layout.watch(function()
		arrange()
		if Router.isOpen("shop") then
			ShopPanel.rebuild()
		end
	end)
	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			pickedId = nil
			table.clear(turnedHere)
			arrange()
			look:open(ClientState.profile)
			ShopPanel.rebuild()
			pick(nil)
			if Kit.Layout.isPhone() then
				openSheet(false)
			end
		end,
		hide = function()
			look:close()
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return ShopPanel
