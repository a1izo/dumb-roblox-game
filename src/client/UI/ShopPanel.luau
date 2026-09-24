-- Cosmetic shop: buy hats and trails with coins and equip them. Open in the lobby only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ShopRequest = Net.event("ShopRequest")

local ShopPanel = {}

local window: Frame
local coinsLabel: TextLabel
local grid: ScrollingFrame
local firstButton: TextButton? = nil

local function isOwned(profile, id: string): boolean
	return table.find(profile.owned, id) ~= nil
end

local function rebuild()
	Widgets.clear(grid)
	firstButton = nil
	local profile = ClientState.profile
	if not profile then
		coinsLabel.Text = "Loading your profile..."
		return
	end
	coinsLabel.Text = string.format("%d coins", profile.coins)
	for index, item in ipairs(Cosmetics.ITEMS) do
		local card = Widgets.panel({
			BackgroundColor3 = Theme.colors.panelLight,
			LayoutOrder = index,
			Parent = grid,
		})
		Widgets.padding(card, Theme.space.md)
		local swatch = if item.kind == "hat" then item.color else item.colors[1]
		local preview = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = swatch,
			Size = UDim2.new(1, 0, 0, 40),
			Parent = card,
		})
		Widgets.corner(preview, Theme.radius.md)
		if item.kind == "trail" then
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(item.colors[1], item.colors[2] or item.colors[1])
			gradient.Parent = preview
		end
		Widgets.label({
			Font = Theme.fonts.bold,
			Text = item.name,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 20),
			Parent = card,
		})
		Widgets.label({
			TextSize = Theme.text.caption,
			TextColor3 = Theme.colors.muted,
			Text = if item.kind == "hat" then "HAT" else "TRAIL",
			Font = Theme.fonts.black,
			Position = UDim2.fromOffset(0, 70),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = card,
		})
		local owned = isOwned(profile, item.id)
		local equipped = profile.equipped[item.kind] == item.id
		local text, action, variant
		if equipped then
			text, action, variant = "Unequip", "unequip", "ghost"
		elseif owned then
			text, action, variant = "Equip", "equip", "team"
		else
			text, action = string.format("Buy  ·  %d", item.price), "buy"
			variant = if profile.coins >= item.price then "gold" else "secondary"
		end
		local button = Widgets.button({
			Text = text,
			Variant = variant,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 34),
			Parent = card,
		}, function()
			ShopRequest:FireServer({ action = action, itemId = item.id })
		end)
		if not owned and profile.coins < item.price then
			Widgets.setEnabled(button, false)
		end
		firstButton = firstButton or button
	end
end

function ShopPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Cosmetic shop", Vector2.new(680, 540), function()
		Router.close("shop", "user")
	end)
	coinsLabel = Widgets.label({
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.gold,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = body,
	})
	grid = Widgets.scroll({
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		Parent = body,
	})
	Widgets.padding(grid, Theme.space.xs)
	Widgets.grid(grid, UDim2.fromOffset(196, 160), Theme.space.md)
	ClientState.ProfileChanged:Connect(function()
		if Router.isOpen("shop") then
			rebuild()
		end
	end)
	Router.register("shop", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return not view.living
		end,
		show = function()
			window.Visible = true
			rebuild()
		end,
		hide = function()
			window.Visible = false
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return ShopPanel
