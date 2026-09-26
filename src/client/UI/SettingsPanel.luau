-- Settings: sound, display, and help (How to Play and the guide). Changes apply at once and
-- are saved to the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Settings = require(script.Parent.Core.Settings)

local T = Kit.Tokens

local SettingsPanel = {}

local setters: { [string]: (any) -> () } = {}

function SettingsPanel.init()
	local win = Kit.window({ name = "settings", title = "Settings", size = "M" })
	local list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.xs)
	Kit.pad(list, 0, T.space.xs)
	local nextOrder = Kit.counter()

	local function header(text: string)
		Kit.heading({ text = text, LayoutOrder = nextOrder(), Parent = list })
	end
	local function volume(key: string, label: string)
		local _, set = Kit.slider(
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
		local _, set = Kit.toggle(
			{ LayoutOrder = nextOrder(), Parent = list },
			label,
			Settings.get(key),
			function(value)
				Settings.set(key, value)
			end
		)
		setters[key] = set
	end
	local function buttonRow(): Frame
		local row =
			Kit.frame({ Size = UDim2.new(1, 0, 0, T.touch + T.space.s), LayoutOrder = nextOrder(), Parent = list })
		Kit.list(row, T.space.m, true)
		return row
	end

	header("Sound")
	volume("music", "Music")
	volume("sfx", "Sound effects")
	volume("ambience", "Ambience")
	volume("ui", "Interface sounds")

	header("Display")
	local _, setScale = Kit.slider(
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
	-- How to Play opens over Settings and comes back here when it closes.
	Kit.button({ text = "How to play", icon = "help", variant = "primary", Parent = buttonRow() }, function()
		Router.open("howToPlay", { returnTo = "settings" })
	end)
	toggle("hints", "Show the guide (tips and objectives)")
	Kit.button({ text = "Show all tips again", variant = "ghost", size = "s", Parent = buttonRow() }, function()
		Net.event("ProfileRequest"):FireServer({ action = "resetHints" })
	end)

	Settings.Changed:Connect(function(key, value)
		local set = setters[key]
		if set then
			set(value)
		end
	end)

	Kit.register(win)
end

return SettingsPanel
