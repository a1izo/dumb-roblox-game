-- Private-server rules. The owner of a private server with the Director pass sets rounds,
-- phase times and maps here between matches; everyone else in the server sees the rules
-- and is reminded that custom rules pay participation rewards only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SettingsSchema = require(Shared:WaitForChild("SettingsSchema"))
local Signal = require(Shared:WaitForChild("Signal"))

local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local PrivateServerRemote = Net.event("PrivateServer")

local DirectorPanel = {}

-- Fired with the latest state { vip, canEdit, custom, settings }.
DirectorPanel.Changed = Signal.new()

DirectorPanel.state = { vip = false, canEdit = false, custom = false, settings = SettingsSchema.defaults() }

local MAP_NAMES = {
	TaskForceHQ = "Agency HQ",
	UniversityCampus = "University Campus",
	TokyoDistrict = "Tokyo District",
}

local window: Frame
local body: Frame
local draft: SettingsSchema.Settings = SettingsSchema.defaults()

local function rebuild()
	Widgets.clear(body)
	local state = DirectorPanel.state
	local list = Widgets.scroll({ Size = UDim2.new(1, 0, 1, -52), Parent = body })
	Widgets.list(list, Theme.space.sm)
	Widgets.label({
		Text = if state.canEdit
			then "You own this server. Changes apply from the next match. Custom rules pay participation rewards only."
			elseif state.vip then "The server owner sets these rules." .. (if state.custom
				then " Custom rules are on: participation rewards only."
				else "")
			else "Rules can be changed in private servers by an owner with the Director pass.",
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = 0,
		Parent = list,
	})
	for index, key in ipairs(SettingsSchema.ORDER) do
		local range = SettingsSchema.RANGES[key]
		local row = Widgets.slider(
			{ LayoutOrder = index, Size = UDim2.new(1, -8, 0, 44), Parent = list },
			range.label,
			(draft :: any)[key],
			range.min,
			range.max,
			range.step,
			function(value)
				(draft :: any)[key] = value
			end
		)
		if not state.canEdit then
			for _, child in ipairs(row:GetDescendants()) do
				if child:IsA("GuiButton") then
					Widgets.setEnabled(child, false)
				end
			end
		end
	end
	for index, mapId in ipairs(SettingsSchema.MAPS) do
		Widgets.toggle(
			{ LayoutOrder = 20 + index, Size = UDim2.new(1, -8, 0, 36), Parent = list },
			MAP_NAMES[mapId] or mapId,
			table.find(draft.maps, mapId) ~= nil,
			function(on)
				local position = table.find(draft.maps, mapId)
				if on and not position then
					table.insert(draft.maps, mapId)
				elseif not on and position and #draft.maps > 1 then
					table.remove(draft.maps, position)
				end
			end
		)
	end
	if state.canEdit then
		Widgets.button({
			Text = "Apply",
			Variant = "primary",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(150, 40),
			Parent = body,
		}, function()
			PrivateServerRemote:FireServer({ action = "set", settings = draft })
		end)
		Widgets.button({
			Text = "Defaults",
			Variant = "secondary",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -160, 1, 0),
			Size = UDim2.fromOffset(130, 40),
			Parent = body,
		}, function()
			PrivateServerRemote:FireServer({ action = "reset" })
		end)
	end
end

function DirectorPanel.init()
	window, body = Widgets.modal(Screens.modal, "Private server", Vector2.new(560, 520), function()
		Router.close("director", "user")
	end)
	PrivateServerRemote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or payload.action ~= "state" then
			return
		end
		DirectorPanel.state = {
			vip = payload.vip == true,
			canEdit = payload.canEdit == true,
			custom = payload.custom == true,
			settings = SettingsSchema.clamp(payload.settings),
		}
		draft = SettingsSchema.clamp(payload.settings)
		DirectorPanel.Changed:Fire(DirectorPanel.state)
		if Router.isOpen("director") then
			rebuild()
		end
	end)
	Router.register("director", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			draft = SettingsSchema.clamp(DirectorPanel.state.settings)
			window.Visible = true
			rebuild()
		end,
		hide = function()
			window.Visible = false
		end,
	})
	PrivateServerRemote:FireServer({ action = "get" })
end

return DirectorPanel
