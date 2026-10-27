--!strict
-- Every control a player can rebind (the emote overhaul's S6, owner's call: every control, movement, jump and
-- camera included, keyboard and gamepad apart), with its default keys, in plain data: Client/Input applies it,
-- Settings lists it, the profile saves a player's own (validated here), and the checks read it.
--
--   id       the action's name (Input/Actions uses the same ids for its own)
--   label    what Settings calls it
--   context  when it is live (see GROUPS): two actions may share a key only if no group holds both contexts
--   keyboard default keys (Enum.KeyCode names), at most MAX_KEYS
--   gamepad  default buttons (Enum.KeyCode names); none for the actions a pad reaches another way
--
-- Contexts: "move" walking, "jump", "camera", "world" the case's actions, "wheel" the wheel's slots, "ghost" a
-- Specter's flight, "offer" a note offer's slip (while it shows, the role card's hold steps aside), "plate" a
-- press-to-do plate's key (taken only while its plate shows, otherwise passed on), "rally" Match Point's hit.

local Terms = require(script.Parent.Terms)

local Bindings = {}

export type Action = {
	id: string,
	label: string,
	context: string,
	keyboard: { string },
	gamepad: { string },
}

Bindings.MAX_KEYS = 2
Bindings.PLATFORMS = { "keyboard", "gamepad" }

-- Contexts live at the same time.
Bindings.GROUPS = {
	play = { "move", "jump", "camera", "world", "wheel" },
	ghost = { "move", "camera", "ghost" },
	offer = { "move", "camera", "offer" },
	plate = { "move", "camera", "plate" },
	rally = { "camera", "rally" },
}

-- Keys no action may take: Roblox's own (the menu, the chat, the player list, the screenshot) and Escape.
Bindings.RESERVED = {
	Escape = true,
	Slash = true,
	Tab = true,
	F9 = true,
	F12 = true,
	Print = true,
	ButtonStart = true,
	ButtonSelect = true,
	Menu = true,
	Unknown = true,
}

local function action(id: string, label: string, context: string, keyboard: { string }, gamepad: { string }): Action
	return { id = id, label = label, context = context, keyboard = keyboard, gamepad = gamepad }
end

Bindings.ACTIONS = {
	action("moveForward", "Walk forward", "move", { "W", "Up" }, {}),
	action("moveBack", "Walk back", "move", { "S", "Down" }, {}),
	action("moveLeft", "Walk left", "move", { "A" }, {}),
	action("moveRight", "Walk right", "move", { "D" }, {}),
	action("move", "Walk", "move", {}, { "Thumbstick1" }),
	action("jump", "Jump", "jump", { "Space" }, { "ButtonA" }),
	action("turnLeft", "Turn the camera left", "camera", { "Left" }, {}),
	action("turnRight", "Turn the camera right", "camera", { "Right" }, {}),
	action("look", "Look round", "camera", {}, { "Thumbstick2" }),
	action("zoomIn", "Zoom in", "camera", { "I" }, {}),
	action("zoomOut", "Zoom out", "camera", { "O" }, {}),
	action("shiftLock", "Shift lock (when it is on in Roblox's settings)", "camera", { "LeftShift", "RightShift" }, {}),
	action("privateScreen", Terms.f("{Grimoire}"), "world", { "P" }, { "ButtonY" }),
	action("quickChat", "The emote wheel", "world", { "Q" }, { "DPadLeft" }),
	-- (quick chat's phrases on their own key, 2026-10-27: Q had opened both, on two tabs)
	action("phrases", "Quick chat", "world", { "M" }, { "ButtonL3" }),
	action("note", "Notes", "world", { "N" }, { "DPadRight" }),
	action("drop", "Drop", "world", { "G" }, { "DPadDown" }),
	action("eyesRead", "Stare (learn a real name)", "world", { "R" }, { "ButtonR1" }),
	action("scratchpad", "Scratchpad", "world", { "V" }, { "ButtonR2" }),
	action("help", "Help", "world", { "H" }, {}),
	action("sabotageBlackout", "Sabotage: blackout", "world", { "Z" }, { "ButtonL2" }),
	action("sabotageJam", "Sabotage: jam stations", "world", { "B" }, { "DPadUp" }),
	action("sabotageBarricade", "Sabotage: barricade", "world", { "T" }, {}),
	action("arrest", Terms.f("{Zero}'s arrest"), "world", { "K" }, {}),
	action("roleCard", "Hold your role card", "world", { "C" }, { "ButtonL1" }),
	action("interact", "Use", "world", { "E" }, { "ButtonX" }),
	action("pickUp", "Pick up a dropped note", "world", { "F" }, { "ButtonB" }),
	action("slot1", "Wheel slot 1", "wheel", { "One" }, {}),
	action("slot2", "Wheel slot 2", "wheel", { "Two" }, {}),
	action("slot3", "Wheel slot 3", "wheel", { "Three" }, {}),
	action("slot4", "Wheel slot 4", "wheel", { "Four" }, {}),
	action("flyUp", "Fly up", "ghost", { "Space" }, { "ButtonA" }),
	action("flyDown", "Fly down", "ghost", { "LeftControl" }, { "ButtonL2" }),
	action("noteOffer", "Take the offered note", "offer", { "X" }, { "ButtonL1" }),
	-- (its own key on both, the owner's call of 2026-10-24: no other action shares Y or R3)
	action("emoteContext", "An emote's press-to-do", "plate", { "Y" }, { "ButtonR3" }),
	action("joinIn", "Join in", "plate", { "J" }, { "ButtonY" }),
	action("passNote", "Pass your note", "plate", { "X" }, { "ButtonL1" }),
	action("rallyHit", "Hit the ball (Match Point)", "rally", { "F" }, { "ButtonX" }),
} :: { Action }

-- How Settings > Controls groups the actions (every action is in exactly one; the specs check it).
Bindings.SECTIONS = {
	{ title = "Moving", ids = { "moveForward", "moveBack", "moveLeft", "moveRight", "move", "jump" } },
	{ title = "The camera", ids = { "turnLeft", "turnRight", "look", "zoomIn", "zoomOut", "shiftLock" } },
	{
		title = "The case",
		ids = {
			"interact",
			"pickUp",
			"roleCard",
			"eyesRead",
			"privateScreen",
			"note",
			"drop",
			"scratchpad",
			"sabotageBlackout",
			"sabotageJam",
			"sabotageBarricade",
			"arrest",
			"help",
		},
	},
	{
		title = "Emotes and quick chat",
		ids = { "quickChat", "phrases", "slot1", "slot2", "slot3", "slot4" },
	},
	{
		title = "Emotes with others, and notes",
		ids = { "emoteContext", "joinIn", "rallyHit", "passNote", "noteOffer" },
	},
	{ title = Terms.f("As a {specter}"), ids = { "flyUp", "flyDown" } },
} :: { { title: string, ids: { string } } }

local byId: { [string]: Action } = {}
for _, a in ipairs(Bindings.ACTIONS) do
	byId[a.id] = a
end

function Bindings.get(id: string): Action?
	return byId[id]
end

-- Whether two contexts can be live at once.
function Bindings.together(a: string, b: string): boolean
	if a == b then
		return true
	end
	for _, contexts in pairs(Bindings.GROUPS) do
		if table.find(contexts, a) and table.find(contexts, b) then
			return true
		end
	end
	return false
end

-- Whether a key name is a real key an action may take.
function Bindings.keyAllowed(name: any): boolean
	if type(name) ~= "string" or Bindings.RESERVED[name] then
		return false
	end
	local ok, key = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return ok and key ~= nil
end

-- The keys an action has on a platform: the player's own when they set some, else the default.
function Bindings.keys(id: string, platform: string, saved: any): { string }
	local own = saved and saved[platform] and saved[platform][id]
	if own then
		return own
	end
	local a = byId[id]
	return if a then (a :: any)[platform] or {} else {}
end

-- The same as Enum.KeyCodes, from a player's profile (its `keybinds`; nil for the defaults).
function Bindings.keyCodes(id: string, platform: string, saved: any): { Enum.KeyCode }
	local out = {}
	for _, name in ipairs(Bindings.keys(id, platform, saved)) do
		local ok, key = pcall(function()
			return (Enum.KeyCode :: any)[name]
		end)
		if ok and key then
			table.insert(out, key)
		end
	end
	return out
end

-- How a key reads in a hint: "E", "1", "Shift", "Space", "LB", "D-Up", "Left stick".
local LABELS: { [string]: string } = {
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Zero = "0",
	LeftShift = "Shift",
	RightShift = "Right Shift",
	LeftControl = "Ctrl",
	RightControl = "Right Ctrl",
	LeftAlt = "Alt",
	RightAlt = "Right Alt",
	Return = "Enter",
	Backspace = "Backspace",
	Space = "Space",
	Up = "Up",
	Down = "Down",
	Left = "Left",
	Right = "Right",
	Semicolon = ";",
	Quote = "'",
	Comma = ",",
	Period = ".",
	Minus = "-",
	Equals = "=",
	LeftBracket = "[",
	RightBracket = "]",
	BackSlash = "\\",
	Backquote = "`",
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	DPadUp = "D-Up",
	DPadDown = "D-Down",
	DPadLeft = "D-Left",
	DPadRight = "D-Right",
	Thumbstick1 = "Left stick",
	Thumbstick2 = "Right stick",
}

function Bindings.label(name: string): string
	local known = LABELS[name]
	if known then
		return known
	end
	-- (KeypadOne reads "Num One"; letters and F-keys read as themselves)
	return (string.gsub(name, "^Keypad", "Num "))
end

-- An action's keys as hint text ("E", "W / Up"), or "" when it has none on that platform.
function Bindings.text(id: string, platform: string, saved: any, joiner: string?): string
	local parts = {}
	for _, name in ipairs(Bindings.keys(id, platform, saved)) do
		table.insert(parts, Bindings.label(name))
	end
	return table.concat(parts, joiner or " / ")
end

-- Whether a player's set differs from the defaults for any of these actions on a platform.
function Bindings.changed(ids: { string }, platform: string, saved: any): boolean
	for _, id in ipairs(ids) do
		local a = byId[id]
		local default = if a then (a :: any)[platform] or {} else {}
		local now = Bindings.keys(id, platform, saved)
		if #now ~= #default then
			return true
		end
		for i, name in ipairs(now) do
			if default[i] ~= name then
				return true
			end
		end
	end
	return false
end

-- Touch screens have no keys to rebind; a player arranges the buttons instead: which side the action buttons
-- sit on, how big they are, how high, which ones are hidden (by action id; the action still works by its
-- prompt or panel where it has one), and how big the world prompts' buttons are.
export type TouchLayout = { side: string, size: number, height: number, prompts: number, hide: { [string]: boolean } }

Bindings.TOUCH_DEFAULT = { side = "right", size = 1, height = 0.42, prompts = 1 }
Bindings.TOUCH_RANGE = {
	size = { 0.75, 1.4 },
	height = { 0.25, 0.7 },
	prompts = { 0.8, 1.6 },
}

local function cleanTouch(raw: any): any
	if type(raw) ~= "table" then
		return nil
	end
	local out: { [string]: any } = {}
	if raw.side == "left" or raw.side == "right" then
		out.side = raw.side
	end
	for name, range in pairs(Bindings.TOUCH_RANGE) do
		local value = raw[name]
		if type(value) == "number" and value == value then
			out[name] = math.clamp(value, range[1], range[2])
		end
	end
	if type(raw.hide) == "table" then
		local hide = {}
		for id, on in pairs(raw.hide) do
			if type(id) == "string" and byId[id] and on == true then
				hide[id] = true
			end
		end
		out.hide = hide
	end
	return out
end

-- A player's touch layout with the defaults filled in.
function Bindings.touchLayout(saved: any): TouchLayout
	local own = if type(saved) == "table" then cleanTouch(saved.touch) or {} else {}
	local d = Bindings.TOUCH_DEFAULT
	return {
		side = own.side or d.side,
		size = own.size or d.size,
		height = own.height or d.height,
		prompts = own.prompts or d.prompts,
		hide = own.hide or {},
	}
end

-- A player's saved bindings as sent or stored, made safe: known platforms and actions only, real keys that are
-- not reserved, at most MAX_KEYS each, no key twice in one action. Anything else is dropped.
function Bindings.clean(raw: any): { [string]: any }
	local out: { [string]: any } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, platform in ipairs(Bindings.PLATFORMS) do
		local list = raw[platform]
		if type(list) == "table" then
			local kept: { [string]: { string } } = {}
			for id, keys in pairs(list) do
				if type(id) == "string" and byId[id] and type(keys) == "table" then
					local good: { string } = {}
					for _, name in ipairs(keys) do
						if #good < Bindings.MAX_KEYS and Bindings.keyAllowed(name) and not table.find(good, name) then
							table.insert(good, name)
						end
					end
					kept[id] = good
				end
			end
			out[platform] = kept
		end
	end
	out.touch = cleanTouch(raw.touch)
	return out
end

-- Pairs of actions that would take the same key at the same time on a platform: { a, b, key }.
function Bindings.clashes(platform: string, saved: any): { { string } }
	local found: { { string } } = {}
	local list = Bindings.ACTIONS
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if Bindings.together(a.context, b.context) then
				local keysB = Bindings.keys(b.id, platform, saved)
				for _, key in ipairs(Bindings.keys(a.id, platform, saved)) do
					if table.find(keysB, key) then
						table.insert(found, { a.id, b.id, key })
					end
				end
			end
		end
	end
	return found
end

return Bindings
