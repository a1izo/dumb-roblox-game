--!strict
-- One-time hints for new players. Each shows once per profile (saved in tipsSeen) and never
-- mentions anyone else's hidden state. The client decides when each one triggers; the
-- server only accepts ids from this list.
--
-- A text names what to press as {key.<name>}: Hints.resolve fills it in for the input the player is
-- using (keyboard, gamepad or touch), so a phone is never told to press a key it does not have.

local Bindings = require(script.Parent.Bindings)
local Terms = require(script.Parent.Terms)

export type Hint = { id: string, title: string, text: string }

local RAW: { { string } } = {
	-- { id, title, text }
	{
		"role_Kira", -- terms:ok (internal role id)
		"You are {hand}",
		"Hack a station ({key.use}) right after someone finishes a case file there to read their real name, then write it in {grimoire} ({key.manual}). Miss a check and the alarm goes off.",
	},
	{
		"role_Follower",
		"You are a {cultist}",
		"You know {hand}; they do not know you. Hack stations for names ({key.use}), pass them on paper notes, and sabotage ({key.sabotage}).",
	},
	{
		"role_L",
		"You are {zero}",
		"Nobody knows it is you. In a meeting you can arrest one player ({key.arrest}). Arrest an innocent and it costs your life.",
	},
	{
		"role_Watari", -- terms:ok (internal role id)
		"You are {butler}",
		"You know who {zero} is. If {zero} dies, you name the next one. Keep them alive.",
	},
	{
		"role_TaskForce",
		"You are an {agent}",
		"Work case files to fill the task bar, watch for glowing eyes and a burning red book, and vote {hand} out. {key.card} to see your role card again.",
	},
	{
		"phase_Investigation",
		"Investigation",
		"{key.work} at a station to work a case file. Every file fills the Bureau's task bar; fill it and the Bureau wins. Ring the bell to call a meeting.",
	},
	{ "phase_Meeting", "Meeting", "Talk it over. Full real names of living players are blocked in every chat." },
	{
		"phase_Vote",
		"Vote",
		"Pick a suspect or skip. Nobody sees who you voted for, and removed players' roles stay secret.",
	},
	{
		"sheet",
		"Blank sheets",
		"Take a sheet to write a secret note. Notes are the only way to pass on a real name. Drop it, or hand it over ({key.pass}).",
	},
	{
		"pass",
		"Passing notes",
		"Stand close to someone and {key.passDo} to offer your note. Anyone watching sees it change hands.",
	},
	{ "offer", "A note for you", "Take it ({key.pass}) or leave it." },
	{
		"death",
		"Someone died",
		"{Grimoire} took them. Who was at the stations they used, or seen writing, in the last minute?",
	},
	{
		"eliminated",
		"You are a {Specter}",
		"Fly with {key.fly}. The living cannot see or hear you. You can still work case files for {agency}, gather lost souls and chat with other {specters}.",
	},
	{
		"scratchpad",
		"Your notes",
		"{key.pad} to open a private notepad. Only you can see it, and it clears when the match ends.",
	},
}

local Hints = {}

-- What each {key.<name>} reads as, by input, with the default keys (a keyboard or a gamepad then reads the
-- player's own: see Hints.resolve).
Hints.KEYS = {
	keyboard = {
		card = "Hold C",
		stare = "R",
		manual = "P",
		sabotage = "Z, B, T",
		blackout = "Z",
		jam = "B",
		barricade = "T",
		use = "E",
		note = "N",
		drop = "G",
		wheel = "Q",
		arrest = "K",
		work = "Press E",
		pass = "X",
		passDo = "press X",
		pad = "Press V",
		fly = "WASD, Space (up) and Ctrl (down)",
	},
	gamepad = {
		card = "Hold LB",
		stare = "RB",
		manual = "Y",
		sabotage = "LT, D-pad up",
		blackout = "LT",
		jam = "D-pad up",
		barricade = "its button",
		use = "X",
		note = "D-Right",
		drop = "D-Down",
		wheel = "D-Left",
		arrest = "the meeting panel's button",
		work = "Press X",
		pass = "LB",
		passDo = "press LB",
		pad = "Press RT",
		fly = "the left stick, A (up) and LT (down)",
	},
	touch = {
		card = "Press and hold your role badge",
		stare = "the Stare button",
		manual = "its button on the right",
		sabotage = "the buttons on the right",
		blackout = "its button",
		jam = "its button",
		barricade = "its button",
		use = "tap",
		note = "its button",
		drop = "its button",
		wheel = "its button",
		arrest = "the meeting panel's button",
		work = "Tap the prompt",
		pass = "tap its prompt",
		passDo = "tap the prompt",
		pad = "Tap Scratchpad",
		fly = "the stick and the Up and Down buttons",
	},
} :: { [string]: { [string]: string } }

-- The player's own keys (Shared/Bindings; `saved` is their profile's `keybinds`, nil for the defaults) as the
-- {key.<name>} words for a keyboard or a gamepad. Anything they left without a key keeps its default wording.
local function own(input: string, saved: any): { [string]: string }
	local keys = table.clone(Hints.KEYS[input])
	local function t(id: string, joiner: string?): string
		return Bindings.text(id, input, saved, joiner)
	end
	local function put(name: string, text: string)
		if text ~= "" then
			keys[name] = text
		end
	end
	local function some(list: { string }): string
		local parts = {}
		for _, text in ipairs(list) do
			if text ~= "" then
				table.insert(parts, text)
			end
		end
		return table.concat(parts, ", ")
	end
	local card, stare, use, pass, pad = t("roleCard"), t("eyesRead"), t("interact"), t("passNote"), t("scratchpad")
	if card ~= "" then
		put("card", "Hold " .. card)
	end
	put("stare", stare)
	put("manual", t("privateScreen"))
	put("sabotage", some({ t("sabotageBlackout"), t("sabotageJam"), t("sabotageBarricade") }))
	put("blackout", t("sabotageBlackout"))
	put("jam", t("sabotageJam"))
	put("barricade", t("sabotageBarricade"))
	put("arrest", t("arrest"))
	put("note", t("note"))
	put("drop", t("drop"))
	put("wheel", t("quickChat"))
	put("use", use)
	if use ~= "" then
		put("work", "Press " .. use)
	end
	put("pass", pass)
	if pass ~= "" then
		put("passDo", "press " .. pass)
	end
	if pad ~= "" then
		put("pad", "Press " .. pad)
	end
	local up, down = t("flyUp", " or "), t("flyDown", " or ")
	if up ~= "" and down ~= "" then
		if input == "gamepad" then
			local stick = Bindings.keys("move", "gamepad", saved)[1]
			local walk = if stick == "Thumbstick2" then "the right stick" else "the left stick"
			put("fly", string.format("%s, %s (up) and %s (down)", walk, up, down))
		else
			local walk = {}
			local letters = true
			for _, id in ipairs({ "moveForward", "moveLeft", "moveBack", "moveRight" }) do
				local first = Bindings.keys(id, "keyboard", saved)[1]
				local label = if first then Bindings.label(first) else ""
				letters = letters and #label == 1
				table.insert(walk, label)
			end
			-- WASD reads as one word; anything else as a list (forward, left, back, right).
			local moves = if letters then table.concat(walk) else table.concat(walk, " / ")
			put("fly", string.format("%s, %s (up) and %s (down)", moves, up, down))
		end
	end
	return keys
end

-- A hint's text with every {key.<name>} filled in for `input` ("keyboard", "gamepad" or "touch"), in the
-- player's own keys when `saved` (their profile's `keybinds`) is given.
function Hints.resolve(text: string, input: string, saved: any?): string
	local keys = if input == "keyboard" or input == "gamepad" then own(input, saved) else Hints.KEYS[input]
	keys = keys or own("keyboard", saved)
	return (string.gsub(text, "{key%.(%a+)}", function(name: string): string?
		return keys[name]
	end))
end

Hints.LIST = {} :: { Hint }
Hints.BY_ID = {} :: { [string]: Hint }

for _, row in ipairs(RAW) do
	local hint = { id = row[1], title = Terms.f(row[2]), text = Terms.f(row[3]) }
	table.insert(Hints.LIST, hint)
	Hints.BY_ID[hint.id] = hint
end

return Hints
