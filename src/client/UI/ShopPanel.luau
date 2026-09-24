-- Cosmetic shop: buy hats and trails with coins, equip them in the lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ShopRequest = Net.event("ShopRequest")

local ShopPanel = {}

local window: Frame
local coinsLabel: TextLabel
local grid: ScrollingFrame

local function isOwned(profile, id: string): boolean
	return table.find(profile.owned, id) ~= nil
end

local function rebuild()
	Widgets.clear(grid)
	local profile = ClientState.profile
	if not profile then
		coinsLabel.Text = "Loading your profile..."
		return
	end
	coinsLabel.Text = string.format("Coins: %d", profile.coins)
	for index, item in ipairs(Cosmetics.ITEMS) do
		local card = Widgets.panel({
			BackgroundColor3 = Theme.colors.panelLight,
			LayoutOrder = index,
			Parent = grid,
		})
		local swatch = if item.kind == "hat" then item.color else item.colors[1]
		Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = swatch,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 34),
			Parent = card,
		})
		Widgets.label({
			Font = Theme.fonts.bold,
			Text = item.name,
			Position = UDim2.fromOffset(10, 50),
			Size = UDim2.new(1, -20, 0, 20),
			Parent = card,
		})
		Widgets.label({
			TextSize = 13,
			TextColor3 = Theme.colors.muted,
			Text = if item.kind == "hat" then "Hat" else "Trail",
			Position = UDim2.fromOffset(10, 72),
			Size = UDim2.new(1, -20, 0, 16),
			Parent = card,
		})
		local owned = isOwned(profile, item.id)
		local equipped = profile.equipped[item.kind] == item.id
		local text, action, color
		if equipped then
			text, action, color = "Unequip", "unequip", Theme.colors.button
		elseif owned then
			text, action, color = "Equip", "equip", Theme.colors.team
		else
			text, action = string.format("Buy  %d", item.price), "buy"
			color = if profile.coins >= item.price then Theme.colors.good else Theme.colors.button
		end
		Widgets.button({
			Text = text,
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -10),
			Size = UDim2.new(1, -20, 0, 32),
			Parent = card,
		}, function()
			ShopRequest:FireServer({ action = action, itemId = item.id })
		end)
	end
end

function ShopPanel.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		rebuild()
	end
end

function ShopPanel.close()
	window.Visible = false
end

function ShopPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Cosmetic shop", Vector2.new(660, 520))
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
	Widgets.grid(grid, UDim2.fromOffset(190, 150), 10)
	ClientState.ProfileChanged:Connect(function()
		if window.Visible then
			rebuild()
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if ClientState.isLiving() then
			window.Visible = false
		end
	end)
end

return ShopPanel
