-- The shop. Tabs down the left: today's featured items, each kind of cosmetic, and Robux
-- (coin packs, passes and the custom alias). Cosmetic tabs show a 3D preview of your own
-- character wearing the selected item. Open in the lobby only.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ShopRequest = Net.event("ShopRequest")
local ProfileRequest = Net.event("ProfileRequest")
local LocalPlayer = Players.LocalPlayer

local C = Theme.colors

local ShopPanel = {}

local TABS = { "featured", "hat", "trail", "tie", "grimoire", "victory", "specter", "title", "robux" }
local TAB_NAMES = { featured = "Featured", robux = "Robux" }

local window: Frame
local coinsLabel: TextLabel
local noteLabel: TextLabel
local tabList: Frame
local grid: ScrollingFrame
local previewHolder: Frame
local viewport: ViewportFrame
local previewCaption: TextLabel
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

-- 3D preview ---------------------------------------------------------------------------------

local function clearPreview()
	for _, child in ipairs(viewport:GetChildren()) do
		if not child:IsA("UICorner") then
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
	local torso = clone:FindFirstChild("UpperTorso") or clone:FindFirstChild("Torso")
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
		return "Equip", "equip", "team", true
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
	local card = Widgets.panel({ BackgroundColor3 = C.panelLight, LayoutOrder = order, Parent = grid })
	local rarityColor = Cosmetics.RARITY_COLORS[item.rarity] or C.muted
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = rarityColor,
		Size = UDim2.new(0, 5, 1, 0),
		Parent = card,
	})
	local swatch = item.color or (item.colors and item.colors[1]) or C.ink
	local preview = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = swatch,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -24, 0, 30),
		Parent = card,
	})
	if item.colors then
		Create("UIGradient", { Color = ColorSequence.new(item.colors[1], item.colors[2]), Parent = preview })
	end
	if item.kind == "title" or item.kind == "victory" then
		preview.BackgroundColor3 = C.ink
		Widgets.display({
			Text = string.upper(item.name),
			TextSize = Theme.text.body,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = preview,
		})
	end
	Widgets.label({
		Text = item.name,
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.bodyLarge,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Position = UDim2.fromOffset(14, 46),
		Size = UDim2.new(1, -24, 0, 20),
		Parent = card,
	})
	Widgets.label({
		Text = string.upper(item.rarity .. "  ·  " .. (Cosmetics.KIND_NAMES[item.kind] or item.kind)),
		TextSize = Theme.text.caption,
		TextColor3 = rarityColor,
		FontFace = Theme.faces.display,
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -24, 0, 14),
		Parent = card,
	})
	local text, action, variant, enabled = actionFor(profile, item)
	local button = Widgets.button({
		Text = text,
		TextSize = Theme.text.small,
		Variant = variant,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -10),
		Size = UDim2.new(1, -24, 0, 32),
		Parent = card,
	}, function()
		selectedId = item.id
		showPreview(item)
		if action then
			ShopRequest:FireServer({ action = action, itemId = item.id })
		end
	end)
	Widgets.setEnabled(button, enabled)
	-- Clicking the card previews the item.
	local hit = Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, 0, 1, -48),
		Parent = card,
	})
	hit.Activated:Connect(function()
		selectedId = item.id
		showPreview(item)
	end)
	firstButton = firstButton or button
end

-- Robux tab -------------------------------------------------------------------------------------

local function robuxCard(order: number, title: string, lines: { string }, buttonText: string?, onBuy: (() -> ())?)
	local card = Widgets.panel({ BackgroundColor3 = C.panelLight, LayoutOrder = order, Parent = grid })
	Widgets.label({
		Text = title,
		FontFace = Theme.faces.display,
		TextSize = Theme.text.title,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 26),
		Parent = card,
	})
	Widgets.label({
		Text = table.concat(lines, "\n"),
		TextSize = Theme.text.small,
		TextColor3 = C.muted,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 1, -86),
		Parent = card,
	})
	if buttonText then
		local button = Widgets.button({
			Text = buttonText,
			TextSize = Theme.text.small,
			Variant = if onBuy then "primary" else "secondary",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -10),
			Size = UDim2.new(1, -24, 0, 32),
			Parent = card,
		}, onBuy)
		Widgets.setEnabled(button, onBuy ~= nil)
		firstButton = firstButton or button
	end
	return card
end

local function aliasCard(profile, order: number)
	local card = Widgets.panel({ BackgroundColor3 = C.panelLight, LayoutOrder = order, Parent = grid })
	Widgets.label({
		Text = "Your custom alias",
		FontFace = Theme.faces.display,
		TextSize = Theme.text.title,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 26),
		Parent = card,
	})
	local box = Widgets.textbox({
		Text = profile.alias or "",
		PlaceholderText = "3 to 12 letters",
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = card,
	})
	Widgets.limitLength(box, 12)
	Widgets.button({
		Text = "Save alias",
		TextSize = Theme.text.small,
		Variant = "primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 32),
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

-- Tabs -------------------------------------------------------------------------------------------

local rebuild: () -> ()

local function buildTabs()
	Widgets.clear(tabList)
	for index, tab in ipairs(TABS) do
		Widgets.button({
			Name = tab,
			Text = TAB_NAMES[tab] or Cosmetics.KIND_NAMES[tab] or tab,
			TextSize = Theme.text.small,
			Variant = if tab == currentTab then "primary" else "ghost",
			Size = UDim2.new(1, -4, 0, 34),
			LayoutOrder = index,
			Parent = tabList,
		}, function()
			currentTab = tab
			selectedId = nil
			rebuild()
		end)
	end
end

function rebuild()
	Widgets.clear(grid)
	firstButton = nil
	local profile = ClientState.profile
	if not profile then
		coinsLabel.Text = "Loading your profile..."
		return
	end
	coinsLabel.Text = string.format("%d coins", profile.coins)
	noteLabel.Text = ""
	buildTabs()
	previewHolder.Visible = currentTab ~= "robux"
	grid.Size = if currentTab == "robux" then UDim2.new(1, -150, 1, -40) else UDim2.new(1, -390, 1, -40)
	if currentTab == "robux" then
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
	local body
	window, body = Widgets.modal(Screens.modal, "Shop", Vector2.new(900, 580), function()
		Router.close("shop", "user")
	end)
	coinsLabel = Widgets.display({
		TextColor3 = C.paper,
		TextSize = Theme.text.title,
		Size = UDim2.new(0.4, 0, 0, 28),
		Parent = body,
	})
	noteLabel = Widgets.label({
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.6, 0, 0, 28),
		Parent = body,
	})
	tabList = Widgets.frame({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0, 140, 1, -40), Parent = body })
	Widgets.list(tabList, Theme.space.xs)
	grid = Widgets.scroll({
		Position = UDim2.fromOffset(150, 40),
		Size = UDim2.new(1, -390, 1, -40),
		Parent = body,
	})
	Widgets.padding(grid, Theme.space.xs)
	Widgets.grid(grid, UDim2.fromOffset(186, 150), Theme.space.md)
	previewHolder = Widgets.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 40),
		Size = UDim2.new(0, 230, 1, -40),
		Parent = body,
	})
	viewport = Create("ViewportFrame", {
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 240, 225),
		LightDirection = Vector3.new(-1, -1, -0.5),
		Size = UDim2.new(1, 0, 1, -34),
		Parent = previewHolder,
	})
	previewCaption = Widgets.display({
		Text = "YOUR LOOK",
		TextSize = Theme.text.body,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 30),
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
	Router.register("shop", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			window.Visible = true
			selectedId = nil
			rebuild()
		end,
		hide = function()
			window.Visible = false
			clearPreview()
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return ShopPanel
