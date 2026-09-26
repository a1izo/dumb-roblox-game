-- Private-server rules. The owner of a private server with the Director pass sets rounds,
-- phase times and maps here between matches; everyone else in the server sees the rules
-- and is reminded that custom rules pay participation rewards only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SettingsSchema = require(Shared:WaitForChild("SettingsSchema"))
local Signal = require(Shared:WaitForChild("Signal"))

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local PrivateServerRemote = Net.event("PrivateServer")

local C = Kit.color
local T = Kit.Tokens

local DirectorPanel = {}

-- Fired with the latest state { vip, canEdit, custom, settings }.
DirectorPanel.Changed = Signal.new()

DirectorPanel.state = { vip = false, canEdit = false, custom = false, settings = SettingsSchema.defaults() }

local MAP_NAMES = {
	TaskForceHQ = "Agency HQ",
	UniversityCampus = "University Campus",
	TokyoDistrict = "Tokyo District",
}

local win: any
local list: ScrollingFrame
local draft: SettingsSchema.Settings = SettingsSchema.defaults()

local function lock(row: Instance)
	for _, child in ipairs(row:GetDescendants()) do
		if child:IsA("GuiButton") then
			Kit.setEnabled(child, false)
		end
	end
end

local function rebuild()
	Kit.clear(list)
	Kit.clear(win.footer)
	local state = DirectorPanel.state
	local nextOrder = Kit.counter()
	Kit.label({
		Text = if state.canEdit
			then "You own this server. Changes apply from the next match. Custom rules pay participation rewards only."
			elseif state.vip then "The server owner sets these rules." .. (if state.custom
				then " Custom rules are on: participation rewards only."
				else "")
			else "Rules can be changed in private servers by an owner with the Director pass.",
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	Kit.heading({ text = "The match", LayoutOrder = nextOrder(), Parent = list })
	for _, key in ipairs(SettingsSchema.ORDER) do
		local range = SettingsSchema.RANGES[key]
		local row = Kit.slider(
			{ LayoutOrder = nextOrder(), Parent = list },
			range.label,
			(draft :: any)[key],
			range.min,
			range.max,
			range.step,
			function(value)
				(draft :: any)[key] = value
			end,
			function(value)
				return tostring(value)
			end
		)
		if not state.canEdit then
			lock(row)
		end
	end
	Kit.heading({ text = "Maps", LayoutOrder = nextOrder(), Parent = list })
	for _, mapId in ipairs(SettingsSchema.MAPS) do
		local row = Kit.toggle(
			{ LayoutOrder = nextOrder(), Parent = list },
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
		if not state.canEdit then
			lock(row)
		end
	end
	win.footer.Visible = state.canEdit
	if state.canEdit then
		Kit.button({ text = "Defaults", variant = "ghost", LayoutOrder = 1, Parent = win.footer }, function()
			PrivateServerRemote:FireServer({ action = "reset" })
		end)
		Kit.button(
			{ text = "Apply", icon = "check", variant = "primary", LayoutOrder = 2, Parent = win.footer },
			function()
				PrivateServerRemote:FireServer({ action = "set", settings = draft })
			end
		)
	end
end

function DirectorPanel.init()
	win = Kit.window({ name = "director", title = "Private server", size = "M", footer = true })
	list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.xs)
	Kit.pad(list, 0, T.space.xs)
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
	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			draft = SettingsSchema.clamp(DirectorPanel.state.settings)
			rebuild()
		end,
	})
	PrivateServerRemote:FireServer({ action = "get" })
end

return DirectorPanel
