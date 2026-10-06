-- The shop: tabs down the left (today's featured items, each kind of cosmetic, and Robux: coin packs,
-- passes and the custom alias), the items as cards, and a 3D preview of your own character wearing the
-- selected item on the right. Rarity is greyscale: one to four slashes, a grey edge rising to white, and a
-- moving shine on the top tier. On a phone the tabs are a scrolling row, the cards are two across and the
-- preview is left out. Open in the lobby only.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)

local ShopRequest = Net.event("ShopRequest")
local ProfileRequest = Net.event("ProfileRequest")
local LocalPlayer = Players.LocalPlayer

local C = Kit.color
local T = Kit.Tokens

local ShopPanel = {}

local TABS = { "featured", "hat", "trail", "tie", "grimoire", "specter", "title", "robux" }
local TAB_NAMES = { featured = "Featured", robux = "Robux" }

-- Layout of the spread (design px).
local TOP = 44 -- the coins line
local TABS_WIDTH = 180
local PREVIEW_WIDTH = 240
local GAP = T.space.l

local coinsLabel: TextLabel
local noteLabel: TextLabel
local grid: ScrollingFrame
local previewHolder: Frame
local viewport: ViewportFrame
local previewCaption: TextLabel
local gridLayout: UIGridLayout
local verticalTabs: Frame
local rowScroll: ScrollingFrame
local currentTab = "featured"
local selectedId: string? = nil
local firstButton: TextButton? = nil

local function owns(profile, item): boolean
	if item.source == "vip" then
		return table.find(profile.passes or {}, "vip") ~= nil
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

-- The Kit's rarity inks are keyed "Common", "Rare"...; items say "common", "rare"...
local function rarityInk(rarity: string): Color3
	local key = string.upper(string.sub(rarity, 1, 1)) .. string.sub(rarity, 2)
	return (T.rarity :: any)[key] or C.dim
end

-- Slashes on the card: 1 common, 2 rare, 3 epic, 4 legendary.
local RARITY_TIER = { common = 1, uncommon = 1, rare = 2, epic = 3, legendary = 4, mythic = 4 }

-- 3D preview ---------------------------------------------------------------------------------

local function clearPreview()
	for _, child in ipairs(viewport:GetChildren()) do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

local function showPreview(item: Cosmetics.Item?)
	clearPreview()
	previewCaption.Text = if item then string.upper(item.name) else "YOUR LOOK"
	local character = LocalPlayer.Character
	if not character then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	if not clone then
		return
	end
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Sound") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
		end
	end
	for _, name in ipairs({ "LCosmeticHat", "LTitleTag" }) do
		local old = clone:FindFirstChild(name, true)
		if old then
			old:Destroy()
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(200), 0))
	clone.Parent = world
	local head = clone:FindFirstChild("Head")
	local torso = clone:FindFirstChild("Torso")
	if item and item.kind == "hat" and head and head:IsA("BasePart") then
		for _, part in ipairs(CosmeticBuild.hat(item, head.CFrame, head)) do
			part.Anchored = true
			part.Parent = world
		end
	elseif item and item.kind == "tie" and torso and torso:IsA("BasePart") then
		local top = torso.Size.Y / 2
		Create("Part", {
			Anchored = true,
			Size = Vector3.new(0.2, 0.95, 0.05),
			Color = item.color,
			Material = Enum.Material.Fabric,
			CFrame = torso.CFrame * CFrame.new(0, top - 0.75, -torso.Size.Z / 2 - 0.05),
			Parent = world,
		})
	elseif item and item.kind == "grimoire" and torso and torso:IsA("BasePart") then
		local book = Models.grimoire()
		local cover = book:FindFirstChild("Cover")
		if cover and cover:IsA("BasePart") then
			cover.Color = item.color
		end
		book:PivotTo(torso.CFrame * CFrame.new(0, -0.3, -1.4) * CFrame.Angles(math.rad(70), 0, 0))
		book:ScaleTo(0.6)
		book.Parent = world
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local focus = if head and head:IsA("BasePart") then head.Position - Vector3.new(0, 1.2, 0) else Vector3.new(0, 2, 0)
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 1.2, -11), focus)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Cards ----------------------------------------------------------------------------------------

local function actionFor(profile, item): (string, string?, string, boolean)
	-- returns text, action, variant, enabled
	local isOwned = owns(profile, item)
	if profile.equipped[item.kind] == item.id and isOwned then
		return "Unequip", "unequip", "ghost", true
	elseif isOwned then
		return "Equip", "equip", "secondary", true
	elseif item.source == "vip" then
		return "VIP pass", nil, "secondary", false
	elseif not item.price then
		return "Earned", nil, "secondary", false
	elseif item.source == "rotation" and not ShopRotation.isFeatured(item.id, os.time()) then
		return "Not today", nil, "secondary", false
	end
	local affordable = profile.coins >= item.price
	return string.format("Buy  ·  %d", item.price), "buy", if affordable then "primary" else "secondary", affordable
end

local function itemCard(profile, item: Cosmetics.Item, order: number)
	local ink = rarityInk(item.rarity)
	local tier = RARITY_TIER[item.rarity] or 1
	local card = Kit.card({ accent = ink, Size = UDim2.fromScale(1, 1), LayoutOrder = order, Parent = grid })
	if tier >= 3 then
		local edge = card:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Color = ink
			edge.Thickness = 2
			edge.Transparency = 0
		end
	end
	if tier >= 4 and not Motion.isReduced() then
		-- The top tier shimmers: a soft white band sweeps across the card.
		local shine = Kit.Base.make("Frame", {
			Name = "Shine",
			BackgroundColor3 = C.white,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = card.ZIndex + 3,
			Parent = card,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 20
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Offset = Vector2.new(-1, 0)
		gradient.Parent = shine
		TweenService:Create(
			gradient,
			TweenInfo.new(2.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	end
	-- A swatch of the item's colour (its lettering for titles and poses).
	local swatch = Kit.Base.make("Frame", {
		Name = "Swatch",
		BackgroundColor3 = item.color or (item.colors and item.colors[1]) or C.void,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = card,
	})
	Kit.Base.corner(swatch, T.radius.key)
	if item.colors then
		Create("UIGradient", { Color = ColorSequence.new(item.colors[1], item.colors[2]), Parent = swatch })
	end
	if item.kind == "title" then
		swatch.BackgroundColor3 = C.void
		Kit.label({
			Text = string.upper(item.name),
			font = "label",
			size = "small",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			Parent = swatch,
		})
	end
	Kit.label({
		Text = item.name,
		font = "bodyBold",
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = card,
	})
	Kit.label({
		Text = string.upper(item.rarity .. "  ·  " .. (Cosmetics.KIND_NAMES[item.kind] or item.kind)),
		font = "label",
		size = "micro",
		color = if tier == 1 then C.g5 else ink,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, -(tier * 9 + 6), 0, 14),
		Parent = card,
	})
	-- The slashes, one per tier, at the right of the rarity line.
	for slash = 1, tier do
		Kit.Base.make("Frame", {
			Name = "Slash",
			BackgroundColor3 = if tier == 1 then C.g5 else ink,
			BorderSizePixel = 0,
			Rotation = 20,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -((tier - slash) * 9), 0, 66),
			Size = UDim2.fromOffset(4, 14),
			Parent = card,
		})
	end
	local text, action, variant, enabled = actionFor(profile, item)
	local button = Kit.button({
		text = text,
		variant = variant,
		size = "s",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 2,
		Parent = card,
	}, function()
		selectedId = item.id
		showPreview(item)
		if action then
			ShopRequest:FireServer({ action = action, itemId = item.id })
		end
	end)
	Kit.setEnabled(button, enabled)
	-- Clicking the card itself previews the item.
	local hit = Kit.Base.hit({ Name = "Preview", Selectable = false, Size = UDim2.new(1, 0, 1, -48), Parent = card })
	hit.Activated:Connect(function()
		selectedId = item.id
		showPreview(item)
	end)
	firstButton = firstButton or button
end

-- Robux tab -------------------------------------------------------------------------------------

local function robuxCard(order: number, title: string, lines: { string }, buttonText: string?, onBuy: (() -> ())?)
	local card = Kit.card({ Size = UDim2.fromScale(1, 1), LayoutOrder = order, Parent = grid })
	Kit.text({ face = "Head", text = title, size = 22, color = C.bone, Parent = card })
	Kit.label({
		Text = table.concat(lines, "\n"),
		size = "small",
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
			Size = UDim2.new(1, 0, 0, 40),
			Parent = card,
		}, onBuy)
		Kit.setEnabled(button, onBuy ~= nil)
		firstButton = firstButton or button
	end
	return card
end

local function aliasCard(profile, order: number)
	local card = Kit.card({ Size = UDim2.fromScale(1, 1), LayoutOrder = order, Parent = grid })
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
		Size = UDim2.new(1, 0, 0, 40),
		Parent = card,
	}, function()
		ProfileRequest:FireServer({ action = "alias", alias = box.Text })
	end)
end

local function buildRobux(profile)
	local order = 0
	local any = false
	for _, pack in ipairs(Products.COIN_PACKS) do
		if pack.id ~= 0 then
			any = true
			order += 1
			robuxCard(order, pack.label, { string.format("%d coins", pack.coins), "Premium: +10%" }, "Buy", function()
				MarketplaceService:PromptProductPurchase(LocalPlayer, pack.id)
			end)
		end
	end
	for _, pass in ipairs(Products.PASSES) do
		local owned = hasPass(profile, pass.key)
		if pass.id ~= 0 or owned then
			any = true
			order += 1
			robuxCard(
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
		aliasCard(profile, order)
	end
	noteLabel.Text = if any then "" else "Robux items are not on sale yet."
end

-- Contents -----------------------------------------------------------------------------------------

local function rebuild()
	Kit.clear(grid)
	firstButton = nil
	local profile = ClientState.profile
	if not profile then
		coinsLabel.Text = "Loading your profile…"
		return
	end
	coinsLabel.Text = string.format("%d coins", profile.coins)
	noteLabel.Text = ""
	local robux = currentTab == "robux"
	local phone = Kit.Layout.isPhone()
	previewHolder.Visible = not robux and not phone
	-- On a phone the tabs are a row above the cards and there is no preview.
	local left = if phone then 0 else TABS_WIDTH + GAP
	local top = if phone then TOP + 56 else TOP
	local right = if robux or phone then 0 else PREVIEW_WIDTH + GAP
	grid.Position = UDim2.fromOffset(left, top)
	grid.Size = UDim2.new(1, -(left + right), 1, -top)
	gridLayout.CellSize = if phone then UDim2.new(0.5, -T.space.m, 0, 172) else UDim2.new(1 / 3, -T.space.m, 0, 172)
	if robux then
		buildRobux(profile)
		return
	end
	local items
	if currentTab == "featured" then
		items = {}
		for _, id in ipairs(ShopRotation.forDay(ShopRotation.dayOf(os.time()))) do
			local item = Cosmetics.byId(id)
			if item then
				table.insert(items, item)
			end
		end
		noteLabel.Text = "New featured items in " .. formatTime(ShopRotation.secondsLeft(os.time()))
	else
		items = Cosmetics.ofKind(currentTab)
	end
	for index, item in ipairs(items) do
		itemCard(profile, item, index)
	end
	if not selectedId then
		showPreview(nil)
	end
end

function ShopPanel.init()
	local win = Kit.window({ name = "shop", title = "Shop", jp = "ショップ", size = "L" })
	local body = win.body
	-- The coins line: your purse on the left, a note on the right.
	local purse = Kit.frame({ Name = "Purse", Size = UDim2.new(0.45, 0, 0, 32), Parent = body })
	Kit.list(purse, T.space.s, true)
	Kit.icon({ name = "coin", size = 24, color = C.candle, LayoutOrder = 1, Parent = purse })
	coinsLabel = Kit.label({
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
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.55, 0, 0, 32),
		Parent = body,
	})
	local items = {}
	for _, tab in ipairs(TABS) do
		table.insert(items, { id = tab, label = TAB_NAMES[tab] or Cosmetics.KIND_NAMES[tab] or tab })
	end
	-- Two tab strips share one selection: a column for desktops, a scrolling row for phones.
	local syncing = false
	local selectVertical: (string) -> () = function(_id: string) end
	local selectRow: (string) -> () = function(_id: string) end
	local function onTab(id: string)
		if syncing then
			return
		end
		syncing = true
		selectVertical(id)
		selectRow(id)
		syncing = false
		currentTab = id
		selectedId = nil
		rebuild()
	end
	verticalTabs, selectVertical = Kit.tabs({
		items = items,
		selected = currentTab,
		vertical = true,
		Position = UDim2.fromOffset(0, TOP),
		Size = UDim2.new(0, TABS_WIDTH, 1, -TOP),
		Parent = body,
	}, onTab)
	rowScroll = Kit.Base.make("ScrollingFrame", {
		Name = "TabRow",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TOP),
		Size = UDim2.new(1, 0, 0, 48),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Visible = false,
		Parent = body,
	}) :: any
	local rowTabs
	rowTabs, selectRow = Kit.tabs({
		items = items,
		selected = currentTab,
		Size = UDim2.fromOffset(0, 48),
		Parent = rowScroll,
	}, onTab)
	rowTabs.AutomaticSize = Enum.AutomaticSize.X
	grid = Kit.scroll({ Position = UDim2.fromOffset(TABS_WIDTH + GAP, TOP), Parent = body })
	Kit.pad(grid, T.space.xs, T.space.xs)
	gridLayout = Kit.grid(grid, UDim2.new(1 / 3, -T.space.m, 0, 172), T.space.m)
	previewHolder = Kit.card({
		Name = "Preview",
		tone = "page",
		padding = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, TOP),
		Size = UDim2.new(0, PREVIEW_WIDTH, 1, -TOP),
		Parent = body,
	})
	viewport = Create("ViewportFrame", {
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0,
		Ambient = Color3.fromRGB(150, 155, 165),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -0.5),
		Size = UDim2.new(1, 0, 1, -36),
		Parent = previewHolder,
	})
	previewCaption = Kit.label({
		Text = "YOUR LOOK",
		font = "label",
		size = "small",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = previewHolder,
	})
	ClientState.ProfileChanged:Connect(function()
		if Router.isOpen("shop") then
			rebuild()
			if selectedId then
				showPreview(Cosmetics.byId(selectedId))
			end
		end
	end)
	Kit.Layout.watch(function(class: string)
		local phone = class == "phone"
		verticalTabs.Visible = not phone
		rowScroll.Visible = phone
		if Router.isOpen("shop") then
			rebuild()
		end
	end)
	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			selectedId = nil
			verticalTabs.Visible = not Kit.Layout.isPhone()
			rowScroll.Visible = Kit.Layout.isPhone()
			rebuild()
		end,
		hide = function()
			clearPreview()
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return ShopPanel
