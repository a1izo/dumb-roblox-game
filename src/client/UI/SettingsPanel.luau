-- Settings: volumes, UI scale, reduced motion, camera shake and hints. Changes apply at
-- once and are saved to the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Router = require(script.Parent.Core.Router)
local Settings = require(script.Parent.Core.Settings)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local SettingsPanel = {}

local window: Frame
local setters: { [string]: (any) -> () } = {}

function SettingsPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Settings", Vector2.new(520, 560), function()
		Router.close("settings", "user")
	end)
	local list = Widgets.scroll({ Parent = body })
	Widgets.list(list, Theme.space.sm)
	Widgets.padding(list, 0, Theme.space.xs)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function header(text: string)
		Widgets.header({ Text = text, LayoutOrder = nextOrder(), Parent = list })
	end
	local function volume(key: string, label: string)
		local _, set = Widgets.slider(
			{ LayoutOrder = nextOrder(), Parent = list },
			label,
			Settings.get(key),
			0,
			1,
			0.1,
			function(value)
				Settings.set(key, value)
			end
		)
		setters[key] = set
	end
	local function toggle(key: string, label: string)
		local _, set = Widgets.toggle(
			{ LayoutOrder = nextOrder(), Parent = list },
			label,
			Settings.get(key),
			function(value)
				Settings.set(key, value)
			end
		)
		setters[key] = set
	end

	header("Sound")
	volume("music", "Music")
	volume("sfx", "Sound effects")
	volume("ambience", "Ambience")
	volume("ui", "Interface sounds")
	header("Display")
	local _, setScale = Widgets.slider(
		{ LayoutOrder = nextOrder(), Parent = list },
		"UI size",
		Settings.get("uiScale"),
		0.8,
		1.25,
		0.05,
		function(value)
			Settings.set("uiScale", value)
		end
	)
	setters.uiScale = setScale
	toggle("reduceMotion", "Reduce motion")
	toggle("cameraShake", "Camera shake")
	header("Help")
	toggle("hints", "Show the guide (tips and objectives)")
	Widgets.button({
		Text = "Show all tips again",
		TextSize = Theme.text.small,
		Variant = "ghost",
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = nextOrder(),
		Parent = list,
	}, function()
		Net.event("ProfileRequest"):FireServer({ action = "resetHints" })
	end)

	Settings.Changed:Connect(function(key, value)
		local set = setters[key]
		if set then
			set(value)
		end
	end)

	Router.register("settings", {
		layer = "modal",
		window = window,
		show = function()
			window.Visible = true
		end,
		hide = function()
			window.Visible = false
		end,
	})
end

return SettingsPanel
