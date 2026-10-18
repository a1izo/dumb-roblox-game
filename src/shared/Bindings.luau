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
	action("privateScreen", Terms.f("{Grimoire}"), "world", { "P" }, { "ButtonY" }),
	action("quickChat", "The emote wheel", "world", { "Q" }, { "DPadLeft" }),
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
	action("slot1", "Wheel slot 1", "wheel", { "One" }, {}),
	action("slot2", "Wheel slot 2", "wheel", { "Two" }, {}),
	action("slot3", "Wheel slot 3", "wheel", { "Three" }, {}),
	action("slot4", "Wheel slot 4", "wheel", { "Four" }, {}),
	action("slot5", "Wheel slot 5", "wheel", { "Five" }, {}),
	action("slot6", "Wheel slot 6", "wheel", { "Six" }, {}),
	action("slot7", "Wheel slot 7", "wheel", { "Seven" }, {}),
	action("slot8", "Wheel slot 8", "wheel", { "Eight" }, {}),
	action("flyUp", "Fly up", "ghost", { "Space" }, { "ButtonA" }),
	action("flyDown", "Fly down", "ghost", { "LeftControl" }, { "ButtonL2" }),
	action("noteOffer", "Take the offered note", "offer", { "X" }, { "ButtonL1" }),
	action("emoteContext", "An emote's press-to-do", "plate", { "F" }, { "ButtonX" }),
	action("joinIn", "Join in", "plate", { "J" }, { "ButtonY" }),
	action("passNote", "Pass your note", "plate", { "X" }, { "ButtonL1" }),
	action("rallyHit", "Hit the ball (Match Point)", "rally", { "F" }, { "ButtonX" }),
} :: { Action }

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
function Bindings.keys(id: string, platform: string, saved: { [string]: { [string]: { string } } }?): { string }
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

-- A player's saved bindings as sent or stored, made safe: known platforms and actions only, real keys that are
-- not reserved, at most MAX_KEYS each, no key twice in one action. Anything else is dropped.
function Bindings.clean(raw: any): { [string]: { [string]: { string } } }
	local out: { [string]: { [string]: { string } } } = {}
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
	return out
end

-- Pairs of actions that would take the same key at the same time on a platform: { a, b, key }.
function Bindings.clashes(platform: string, saved: { [string]: { [string]: { string } } }?): { { string } }
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
