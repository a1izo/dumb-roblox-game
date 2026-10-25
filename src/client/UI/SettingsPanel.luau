-- Settings, in five tabs: Sound, Display, Game (what of other players you see), Controls (every key, the gamepad
-- and the touch buttons: UI/ControlsPage) and Help (How to Play and the guide). Changes apply at once and are saved
-- to the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ControlsPage = require(script.Parent.ControlsPage)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Settings = require(script.Parent.Core.Settings)

local T = Kit.Tokens

local SettingsPanel = {}

local setters: { [string]: (any) -> () } = {}
local chooseTab: ((string) -> ())? = nil

-- Opens Settings on a tab ("sound", "display", "game", "controls", "help").
function SettingsPanel.open(tab: string?)
	Router.open("settings")
	if tab and chooseTab then
		chooseTab(tab)
	end
end

function SettingsPanel.init()
	local win = Kit.window({ name = "settings", title = "Settings", jp = "設定", size = "M" })
	local pages: { [string]: GuiObject } = {}
	local controls: any = nil
	local current = "sound"

	local function page(id: string): ScrollingFrame
		local list = Kit.scroll({
			Name = "Page_" .. id,
			Position = UDim2.new(0, 0, 0, T.touch + T.space.s),
			Size = UDim2.new(1, 0, 1, -(T.touch + T.space.s)),
			-- (the rows end clear of the scroll bar, so a slider's value is never cut under it)
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			Visible = false,
			Parent = win.body,
		})
		Kit.list(list, T.space.xs)
		Kit.pad(list, 0, T.space.xs).PaddingRight = UDim.new(0, T.space.s)
		pages[id] = list
		return list
	end

	local function show(id: string)
		current = id
		for name, frame in pairs(pages) do
			frame.Visible = name == id
		end
		if id == "controls" and controls then
			controls.opened()
		else
			ControlsPage.closed()
		end
	end

	local _, choose = Kit.tabs({
		items = {
			{ id = "sound", label = "Sound" },
			{ id = "display", label = "Display" },
			{ id = "game", label = "Game" },
			{ id = "controls", label = "Controls" },
			{ id = "help", label = "Help" },
		},
		selected = current,
		Size = UDim2.new(1, 0, 0, T.touch),
		Parent = win.body,
	}, show)

	local function rows(list: ScrollingFrame)
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
		local function slider(
			key: string,
			label: string,
			min: number,
			max: number,
			step: number,
			format: ((number) -> string)?
		)
			local _, set = Kit.slider(
				{ LayoutOrder = nextOrder(), Parent = list },
				label,
				Settings.get(key),
				min,
				max,
				step,
				function(value)
					Settings.set(key, value)
				end,
				format
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
			local row = Kit.frame({
				Size = UDim2.new(1, 0, 0, T.touch + T.space.s),
				LayoutOrder = nextOrder(),
				Parent = list,
			})
			Kit.list(row, T.space.m, true)
			return row
		end
		return header, volume, toggle, buttonRow, nextOrder, slider
	end

	do
		local header, volume = rows(page("sound"))
		header("Sound")
		volume("master", "Master volume")
		volume("music", "Music")
		volume("sfx", "Sound effects")
		volume("ambience", "Ambience")
		volume("ui", "Interface sounds")
	end

	do
		local list = page("display")
		local header, _, toggle, _, nextOrder, slider = rows(list)
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
		slider("fov", "Field of view", 60, 100, 1, function(v: number): string
			return string.format("%d°", math.floor(v + 0.5))
		end)
		slider("brightness", "Brightness", -0.3, 0.3, 0.05, function(v: number): string
			local n = math.floor(v * 100 + 0.5)
			return if n > 0 then "+" .. n else tostring(n)
		end)
		-- Low quality: no bloom or haze, fewer shadows, shorter lamp light, effects and weather cut back, the menus'
		-- moving touches still (slower devices, more frames a second).
		toggle("lowGraphics", "Low quality mode (more FPS on slower devices)")
		toggle("showFps", "Show frames a second")
		toggle("weather", "Rain and snow")
		header("Comfort")
		toggle("reduceMotion", "Reduce motion")
		toggle("cameraShake", "Camera shake")
		toggle("screenFlashes", "Screen flashes")
		toggle("showHud", "Show the HUD")
		-- Your own emotes, in the lobby (both stay still under Reduce motion).
		toggle("emoteCamera", "Camera moves round your showpiece emotes")
		toggle("emoteCutscenes", "Godhood emote cutscenes")
	end

	do
		local header, _, toggle = rows(page("game"))
		header("Other players")
		toggle("nameTags", "Names over other players")
		toggle("chatBubbles", "Chat bubbles")
		toggle("otherAuras", "Other players' auras")
		toggle("otherEmoteFx", "Other players' emote effects")
		toggle("emoteMusic", "Other players' emote music")
	end

	do
		local holder = Kit.frame({
			Name = "Page_controls",
			Position = UDim2.new(0, 0, 0, T.touch + T.space.s),
			Size = UDim2.new(1, 0, 1, -(T.touch + T.space.s)),
			Visible = false,
			Parent = win.body,
		})
		pages.controls = holder
		controls = ControlsPage.new(holder)
	end

	do
		local header, _, toggle, buttonRow = rows(page("help"))
		header("Help")
		-- How to Play opens over Settings and comes back here when it closes.
		Kit.button({ text = "How to play", icon = "help", variant = "primary", Parent = buttonRow() }, function()
			Router.open("howToPlay", { returnTo = "settings" })
		end)
		toggle("hints", "Show the guide (tips and objectives)")
		Kit.button({ text = "Show all tips again", variant = "ghost", size = "s", Parent = buttonRow() }, function()
			Net.event("ProfileRequest"):FireServer({ action = "resetHints" })
		end)
	end

	show(current)
	chooseTab = choose

	Settings.Changed:Connect(function(key, value)
		local set = setters[key]
		if set then
			set(value)
		end
	end)

	Kit.register(win, {
		show = function()
			if current == "controls" and controls then
				controls.opened()
			end
		end,
		hide = function()
			ControlsPage.closed()
		end,
	})
end

return SettingsPanel
