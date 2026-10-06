-- The debug panel (F2). Shown to players the server marks with the LDebug attribute (everyone
-- in a Studio play test; listed user ids in live servers). Tabs:
--   Match    start now, the next map, skip / pause / extend phases, speed, forced wins
--   People   everyone with their role and real name; change roles now or for the next match,
--            kill, vote out, arrest, revive, give the Eyes / a hood / paper, flash letters, move
--   Bots     add test bots, autoplay, how they vote, orders for one bot (Studio only)
--   World    teleports, map previews, Blender scenes on or off, fly / noclip / free camera,
--            collider boxes, role tags, lighting and rain
--   Show     cutscene previews, announcements, the briefing card, results, music and sounds
--   Anim     play any animation clip on yourself or on someone, at any speed
--   Profile  coins, XP, cosmetics, passes, day / week jumps, resets, test purchases

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Clips = require(Shared:WaitForChild("Anim"):WaitForChild("Clips"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Products = require(Shared:WaitForChild("Products"))

local Announcer = require(script.Parent.Parent.UI.Announcer)
local Router = require(script.Parent.Parent.UI.Core.Router)
local Screens = require(script.Parent.Parent.UI.Screens)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local AudioCheck = require(script.Parent.Parent.Audio.AudioCheck)
local MusicController = require(script.Parent.Parent.Audio.MusicController)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local LightingController = require(script.Parent.Parent.World.LightingController)
local RainController = require(script.Parent.Parent.World.RainController)
local DebugTools = require(script.Parent.DebugTools)
local UiGallery = require(script.Parent.UiGallery)

local LocalPlayer = Players.LocalPlayer

local DebugPanel = {}

local COLORS = {
	window = Color3.fromRGB(14, 14, 18),
	bar = Color3.fromRGB(24, 24, 30),
	button = Color3.fromRGB(40, 40, 50),
	hover = Color3.fromRGB(60, 60, 74),
	on = Color3.fromRGB(46, 150, 90),
	pick = Color3.fromRGB(180, 40, 55),
	danger = Color3.fromRGB(120, 30, 36),
	text = Color3.fromRGB(235, 232, 225),
	muted = Color3.fromRGB(150, 146, 140),
	header = Color3.fromRGB(255, 190, 90),
}

local ROLE_COLORS = {
	Kira = Color3.fromRGB(255, 70, 80),
	Follower = Color3.fromRGB(255, 150, 100),
	L = Color3.fromRGB(245, 245, 245),
	Watari = Color3.fromRGB(150, 200, 255),
	TaskForce = Color3.fromRGB(110, 170, 255),
}

local TABS = { "Match", "People", "Bots", "World", "Show", "UI", "Anim", "Profile" }

local remote = Net.event("Debug")
local snap: any = nil
local window: Frame
local statusLabel: TextLabel
local statsLabel: TextLabel
local content: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Match"
local selected: number? = nil -- the person the People and Bots actions apply to
local orderTarget: number? = nil -- the second person for bot orders
local animSpeed, animLoop, animOnSelected = 1, false, false
local lastSignature = ""
local showStats = false

local function send(command: string, args: any?)
	remote:FireServer(command, args)
end

-- UI helpers ---------------------------------------------------------------------------------

local function make(class: string, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(item :: any)[key] = value
		end
	end
	item.Parent = props.Parent
	return item
end

local function corner(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function heading(text: string)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = COLORS.header,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(text),
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function note(text: string)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = COLORS.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

-- A row of buttons that wraps onto new lines.
local function row(): Frame
	local frame = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Wraps = true,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	return frame
end

local function button(parent: Instance, text: string, onClick: () -> (), color: Color3?): TextButton
	local b = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color or COLORS.button,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = COLORS.text,
		Text = text,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b })
	corner(b)
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.15)
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = base
	end)
	b.Activated:Connect(onClick)
	return b
end

local function toggle(parent: Instance, text: string, on: boolean, onClick: () -> ()): TextButton
	return button(parent, text .. (if on then ": on" else ": off"), onClick, if on then COLORS.on else nil)
end

-- Data helpers --------------------------------------------------------------------------------

local function people(): { any }
	return if snap then snap.people else {}
end

local function find(userId: number?): any
	for _, entry in ipairs(people()) do
		if entry.userId == userId then
			return entry
		end
	end
	return nil
end

local function roleName(id: string?): string
	for _, role in ipairs(if snap then snap.roles else {}) do
		if role.id == id then
			return role.name
		end
	end
	return id or "-"
end

local function roleNames(): { [string]: string }
	local map = {}
	for _, role in ipairs(if snap then snap.roles else {}) do
		map[role.id] = role.name
	end
	return map
end

local function selectedName(): string
	local entry = find(selected)
	if not entry then
		return "nobody"
	end
	return (entry.alias or entry.name) .. (if entry.me then " (you)" else "")
end

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- Tabs -------------------------------------------------------------------------------------------

local builders: { [string]: () -> () } = {}

builders.Match = function()
	local match = snap.match
	heading("Start")
	local r = row()
	button(r, "Start match now", function()
		send("startMatch")
	end, COLORS.on)
	if snap.settings.botsAllowed then
		button(r, "Fill to 6 with bots", function()
			send("fillBots", { total = 6 })
		end)
	end
	note("Start match now takes everyone in the server (and every bot) straight into a match.")
	heading("Next map")
	r = row()
	for _, map in ipairs(snap.maps) do
		button(r, map.name, function()
			send("nextMap", { mapId = map.id })
		end, if map.id == match.nextMap then COLORS.pick else nil)
	end
	heading("Phase")
	r = row()
	button(r, "Next phase", function()
		send("nextPhase")
	end)
	button(r, if match.paused then "Resume timer" else "Pause timer", function()
		send("pause")
	end, if match.paused then COLORS.pick else nil)
	for _, seconds in ipairs({ -30, 30, 300 }) do
		button(r, string.format("%+d s", seconds), function()
			send("addTime", { seconds = seconds })
		end)
	end
	r = row()
	for _, phase in ipairs({
		{ "Briefing", "Briefing" },
		{ "Investigation", "Investigation" },
		{ "DeathNote", Terms.PHASE.DeathNote },
		{ "Meeting", "Meeting" },
		{ "Vote", "Vote" },
	}) do
		button(r, "Skip to " .. phase[2], function()
			send("skipTo", { phase = phase[1] })
		end)
	end
	r = row()
	for round = 1, Config.MAX_ROUNDS do
		button(r, "Round " .. round, function()
			send("skipTo", { phase = "Investigation", round = round })
		end, if match.round == round then COLORS.pick else nil)
	end
	heading("Speed")
	r = row()
	for _, scale in ipairs({ 0.1, 0.3, 0.5, 1, 2 }) do
		button(r, "x" .. scale, function()
			send("timeScale", { value = scale })
		end, if math.abs(snap.settings.timeScale - scale) < 1e-3 then COLORS.pick else nil)
	end
	toggle(r, "Cutscene phases", not snap.settings.skipCutscenes, function()
		send("skipCutscenes")
	end)
	heading("End")
	r = row()
	button(r, Terms.f("{Agency} wins"), function()
		send("win", { side = "Team" })
	end)
	button(r, Terms.f("{Hand} wins"), function()
		send("win", { side = "Kira" })
	end)
	button(r, "End match now (no outro)", function()
		send("endMatch")
	end, COLORS.danger)
	if match.butlerHint then
		note("Butler's hint this match: " .. match.butlerHint)
	end
end

builders.People = function()
	heading("Everyone (click to pick)")
	for _, entry in ipairs(people()) do
		local text = string.format(
			"%s%s  ·  %s  ·  %s%s%s%s%s",
			entry.alias or entry.name,
			if entry.alias then " (" .. entry.name .. ")" else "",
			if entry.role then roleName(entry.role) else (if entry.ready then "ready" else "lobby"),
			entry.realName or "-",
			if entry.alive == false then "  [" .. tostring(entry.status) .. "]" else "",
			if entry.bot then "  [bot]" else "",
			if entry.eyes then "  [eyes " .. entry.eyes .. "]" else "",
			if entry.hood then "  [hood]" else ""
		)
		local b = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = if entry.userId == selected then COLORS.pick else COLORS.bar,
			Size = UDim2.new(1, 0, 0, 26),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if entry.role then ROLE_COLORS[entry.role] or COLORS.text else COLORS.muted,
			Text = "  " .. text,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		corner(b)
		b.Activated:Connect(function()
			selected = entry.userId
			lastSignature = ""
		end)
	end
	heading("Role now: " .. selectedName())
	local r = row()
	for _, role in ipairs(snap.roles) do
		button(r, role.name, function()
			send("setRole", { userId = selected, role = role.id })
		end, if find(selected) and find(selected).role == role.id then COLORS.pick else nil)
	end
	note(Terms.f("Unique roles ({hand}, {zero}, {butler}) swap with whoever held them."))
	heading("Role next match")
	r = row()
	local forced = if find(selected) then find(selected).forced else nil
	button(r, "Random", function()
		send("forceRole", { userId = selected, role = "" })
	end, if forced == nil then COLORS.pick else nil)
	for _, role in ipairs(snap.roles) do
		button(r, role.name, function()
			send("forceRole", { userId = selected, role = role.id })
		end, if forced == role.id then COLORS.pick else nil)
	end
	heading("Eliminate")
	r = row()
	for _, cause in ipairs(Config.DEATH_CAUSES) do
		button(r, "Kill: " .. cause, function()
			send("kill", { userId = selected, cause = cause })
		end, COLORS.danger)
	end
	r = row()
	button(r, "Vote out", function()
		send("voteOut", { userId = selected })
	end, COLORS.danger)
	button(r, "Arrest (warrant)", function()
		send("arrest", { userId = selected })
	end, COLORS.danger)
	button(r, "Leave / remove", function()
		send("leave", { userId = selected })
	end, COLORS.danger)
	button(r, "Revive", function()
		send("revive", { userId = selected })
	end, COLORS.on)
	heading("Give")
	r = row()
	button(r, Terms.NAMES.Eyes, function()
		send("eyes", { userId = selected })
	end)
	button(r, "Hood", function()
		send("hood", { userId = selected })
	end)
	button(r, "Blank paper", function()
		send("sheet", { userId = selected })
	end)
	button(r, "Letter flash now", function()
		send("flash", { userId = selected })
	end)
	button(r, "+20 suspicion", function()
		send("suspicion", { userId = selected, amount = 20 })
	end)
	heading("Move")
	r = row()
	button(r, "Go to them", function()
		send("tpTo", { userId = selected })
	end)
	button(r, "Bring to me", function()
		send("bring", { userId = selected })
	end)
	button(r, "Freeze", function()
		send("freeze", { userId = selected, on = true })
	end)
	button(r, "Unfreeze", function()
		send("freeze", { userId = selected, on = false })
	end)
end

builders.Bots = function()
	if not snap.settings.botsAllowed then
		note("Test bots only exist in Studio play tests.")
		return
	end
	heading("Add and remove")
	local r = row()
	for _, count in ipairs({ 1, 3, 5 }) do
		button(r, "Add " .. count, function()
			send("addBots", { count = count })
		end)
	end
	for _, total in ipairs({ 6, 8, 12 }) do
		button(r, "Fill to " .. total, function()
			send("fillBots", { total = total })
		end)
	end
	button(r, "Remove all", function()
		send("removeBots")
	end, COLORS.danger)
	note("Bots are ready whenever you are, and join the next match (or press Start match now).")
	heading("Behaviour")
	r = row()
	toggle(r, "Autoplay", snap.settings.botsAuto, function()
		send("botsAuto")
	end)
	toggle(r, "Bot Hand writes names", snap.settings.botsKill, function()
		send("botsKill")
	end)
	heading("Bots vote")
	r = row()
	local vt = snap.settings.voteTarget
	button(r, "At random", function()
		send("botsVote", { target = nil })
	end, if vt == nil then COLORS.pick else nil)
	button(r, "Skip", function()
		send("botsVote", { target = "skip" })
	end, if vt == "skip" then COLORS.pick else nil)
	button(r, "For " .. selectedName(), function()
		send("botsVote", { target = selected })
	end, if type(vt) == "number" and vt == selected then COLORS.pick else nil)
	heading("Order the picked bot: " .. selectedName())
	note("Pick a bot in the People tab (or below). Orders go through the same checks as a player's.")
	r = row()
	for _, entry in ipairs(people()) do
		if entry.bot then
			button(r, entry.alias or entry.name, function()
				selected = entry.userId
				lastSignature = ""
			end, if entry.userId == selected then COLORS.pick else nil)
		end
	end
	heading(
		"Order target: " .. (if find(orderTarget) then find(orderTarget).alias or find(orderTarget).name else "none")
	)
	r = row()
	for _, entry in ipairs(people()) do
		if entry.alive then
			button(r, entry.alias or entry.name, function()
				orderTarget = entry.userId
				lastSignature = ""
			end, if entry.userId == orderTarget then COLORS.pick else nil)
		end
	end
	r = row()
	for _, orderSpec in ipairs({
		{ "come", "Come to me" },
		{ "work", "Work a station" },
		{ "fake", "Fake a case file" },
		{ "vote", "Vote for the target" },
		{ "write", "Write the target's name" },
		{ "warrant", "Warrant on the target" },
		{ "deal", "Take the Eyes deal" },
	}) do
		button(r, orderSpec[2], function()
			send("botOrder", { userId = selected, action = orderSpec[1], target = orderTarget })
		end)
	end
end

builders.World = function()
	heading("Go to")
	local r = row()
	for _, place in ipairs({ { "lobby", "Lobby" }, { "map", "Map spawn" }, { "meeting", "Meeting room" } }) do
		button(r, place[2], function()
			send("tpPlace", { place = place[1] })
		end)
	end
	if #snap.places.stations > 0 then
		r = row()
		for _, station in ipairs(snap.places.stations) do
			button(r, station.name, function()
				send("tpPlace", { place = "station:" .. station.id })
			end)
		end
		r = row()
		for index, area in ipairs(snap.places.areas) do
			button(r, area, function()
				send("tpPlace", { place = "area:" .. index })
			end)
		end
	end
	heading("Maps")
	r = row()
	for _, map in ipairs(snap.maps) do
		button(r, "Preview " .. map.name, function()
			send("preview", { mapId = map.id })
		end)
	end
	if snap.settings.previewing then
		button(r, "Close preview", function()
			send("closePreview")
		end, COLORS.pick)
	end
	r = row()
	toggle(r, "Blender scenes", snap.settings.scenes, function()
		send("scenes")
	end)
	button(r, "Check map contract", function()
		send("contract")
	end)
	button(r, "Prop gallery", function()
		send("propGallery")
	end)
	button(r, "Tokyo props", function()
		send("propGallery", { set = "Tokyo" })
	end)
	button(r, "Campus props", function()
		send("propGallery", { set = "Campus" })
	end)
	r = row()
	button(r, "Lobby props", function()
		send("propGallery", { set = "Lobby" })
	end)
	button(r, "Meeting props", function()
		send("propGallery", { set = "Meeting" })
	end)
	button(r, "Flip facing + gallery", function()
		send("propGallery", { flip = true })
	end)
	note(
		"Previews build a map outside a match (between matches). Turning scenes off rebuilds the lobby, the meeting room and the maps as greyboxes."
	)
	heading("Me")
	r = row()
	toggle(r, "Fly (WASD, Space/E up, Ctrl/Q down)", DebugTools.flying, function()
		DebugTools.setFly(not DebugTools.flying)
		lastSignature = ""
	end)
	toggle(r, "Noclip", DebugTools.noclip, function()
		DebugTools.setNoclip(not DebugTools.noclip)
		lastSignature = ""
	end)
	toggle(r, "Free camera (right mouse to look)", DebugTools.freeCam, function()
		DebugTools.setFreeCam(not DebugTools.freeCam)
		lastSignature = ""
	end)
	r = row()
	for _, speed in ipairs({ 20, 40, 80, 160 }) do
		button(r, "Fly " .. speed, function()
			DebugTools.flySpeed = speed
			lastSignature = ""
		end, if DebugTools.flySpeed == speed then COLORS.pick else nil)
	end
	heading("Show")
	r = row()
	toggle(r, "Colliders", DebugTools.colliders, function()
		DebugTools.setColliders(not DebugTools.colliders)
		lastSignature = ""
	end)
	toggle(r, "Roles over heads", DebugTools.tags, function()
		DebugTools.setTags(not DebugTools.tags)
		DebugTools.updateTags(people(), roleNames())
		lastSignature = ""
	end)
	toggle(r, "Stats", showStats, function()
		showStats = not showStats
		statsLabel.Visible = showStats
		lastSignature = ""
	end)
	note(Terms.f("Colliders: red blocks movement and sight lines, blue only movement, purple {Specter} bounds."))
	heading("Lighting")
	r = row()
	button(r, "Follow the camera", function()
		LightingController.setDebugPreset(nil)
	end)
	button(r, "Lobby", function()
		LightingController.setDebugPreset("lobby")
	end)
	button(r, "Meeting", function()
		LightingController.setDebugPreset("meeting")
	end)
	for _, map in ipairs(snap.maps) do
		button(r, map.name, function()
			LightingController.setDebugPreset("map:" .. map.id)
		end)
	end
	button(r, "Lightning", function()
		LightingController.lightning()
	end)
	heading("Phase mood (lighting only)")
	r = row()
	for _, spec in ipairs({
		{ "Follow the phase", nil },
		{ "Investigation", "Investigation" },
		{ "Grimoire", "DeathNote" },
		{ "Meeting", "Meeting" },
		{ "Vote", "Vote" },
		{ "Verdict", "Verdict" },
		{ Terms.f("End: {Hand} wins"), "OutroHand" },
		{ Terms.f("End: {Agency} wins"), "OutroAgency" },
	}) do
		button(r, spec[1], function()
			LightingController.setDebugMood(spec[2])
		end)
	end
	heading("Rain")
	r = row()
	for _, spec in ipairs({ { "Preset", nil }, { "Off", 0 }, { "Light", 0.3 }, { "Heavy", 1 } }) do
		button(r, spec[1], function()
			RainController.setDebug(spec[2], RainController.debugSnow)
			lastSignature = ""
		end, if RainController.debugRain == spec[2] then COLORS.pick else nil)
	end
	heading("Snow")
	r = row()
	for _, spec in ipairs({ { "Preset", nil }, { "Off", 0 }, { "Light", 0.4 }, { "Heavy", 1 } }) do
		button(r, spec[1], function()
			RainController.setDebug(RainController.debugRain, spec[2])
			lastSignature = ""
		end, if RainController.debugSnow == spec[2] then COLORS.pick else nil)
	end
	note("Snow leaves footprints on snowy ground (the campus lawns) while it falls.")
end

builders.Show = function()
	heading("Cutscenes (in a match; only you see them)")
	local r = row()
	button(r, "Intro", function()
		send("cue", { kind = "intro" })
	end)
	for _, cause in ipairs(Config.DEATH_CAUSES) do
		button(r, "Death: " .. cause, function()
			send("cue", { kind = "death", userId = selected, extra = cause })
		end)
	end
	button(r, "Verdict", function()
		send("cue", { kind = "verdict", userId = selected })
	end)
	button(r, "Arrest", function()
		send("cue", { kind = "arrest", userId = selected })
	end)
	button(r, "Eyes deal", function()
		send("cue", { kind = "eyesDeal" })
	end)
	button(r, Terms.f("Outro: {Agency}"), function()
		send("cue", { kind = "outro", extra = "Team" })
	end)
	button(r, Terms.f("Outro: {Hand}"), function()
		send("cue", { kind = "outro", extra = "Kira" })
	end)
	note("Death, verdict and arrest use the person picked in People (" .. selectedName() .. ").")
	heading("Screens")
	r = row()
	for _, tone in ipairs({ "neutral", "danger", "team", "kira" }) do
		button(r, "Announce: " .. tone, function()
			send("announce", { tone = tone })
		end)
	end
	r = row()
	for _, role in ipairs(snap.roles) do
		button(r, "Briefing: " .. role.name, function()
			send("briefing", { role = role.id })
		end)
	end
	r = row()
	button(r, Terms.f("Results: {Agency} wins"), function()
		send("results", { winner = "Team" })
	end)
	button(r, Terms.f("Results: {Hand} wins"), function()
		send("results", { winner = "Kira" })
	end)
	heading("Music (" .. (MusicController.current() or "silence") .. ")")
	r = row()
	button(r, "Automatic", function()
		MusicController.setDebugSlot(nil)
		lastSignature = ""
	end)
	button(r, "Silence", function()
		MusicController.setDebugSlot("none")
		lastSignature = ""
	end)
	note(
		"Audio check: ok = plays, fallback = the upload is blocked and the fallback id plays,"
			.. " blocked = silent (share the audio with this experience in Creator Hub)."
	)
	for _, slot in ipairs(sortedKeys(Assets.music)) do
		local entry = Assets.music[slot]
		local status = AudioCheck.slotStatus(entry)
		button(r, slot .. (if status == "ok" then "" else " (" .. status .. ")"), function()
			MusicController.setDebugSlot(slot)
			lastSignature = ""
		end, if MusicController.current() == slot then COLORS.pick else nil)
	end
	heading("Sounds")
	r = row()
	for _, key in ipairs(sortedKeys(Assets.sfx)) do
		button(r, key, function()
			Sfx.play(key)
		end)
	end
end

builders.UI = function()
	heading("Design system")
	local r = row()
	button(r, "Kit gallery", function()
		UiGallery.open()
	end, COLORS.pick)
	note(
		"Every component, lettering size, surface and icon on one page. The lettering, paper and"
			.. " icons need DeathsGambitModels_Core.fbx imported; until then the code-only versions show."
	)
	heading("Notifications")
	r = row()
	for _, kind in ipairs({ "info", "good", "bad", "warn", "secret", "coin" }) do
		button(r, kind, function()
			Toasts.show("A " .. kind .. " notification from the debug panel.", kind)
		end)
	end
	r = row()
	for _, tone in ipairs({ "neutral", "danger", "team" }) do
		button(r, "Announce " .. tone, function()
			Announcer.show("Round 2", Terms.f("{Grimoire} has been used."), tone)
		end)
	end
	heading("Screens")
	r = row()
	for _, name in ipairs({
		"settings",
		"howToPlay",
		"shop",
		"quests",
		"profile",
		"leaderboards",
		"party",
		"evidence",
		"scratchpad",
		"quickChat",
	}) do
		button(r, name, function()
			Router.toggle(name)
		end)
	end
	note(Terms.f("Screens with rules (the vote, {grimoire}, {zeroDesk}) only open when the match allows them."))
end

builders.Anim = function()
	heading("Play on")
	local r = row()
	button(r, "Me", function()
		animOnSelected = false
		lastSignature = ""
	end, if not animOnSelected then COLORS.pick else nil)
	button(r, selectedName(), function()
		animOnSelected = true
		lastSignature = ""
	end, if animOnSelected then COLORS.pick else nil)
	for _, speed in ipairs({ 0.1, 0.25, 0.5, 1, 2 }) do
		button(r, "x" .. speed, function()
			animSpeed = speed
			lastSignature = ""
		end, if animSpeed == speed then COLORS.pick else nil)
	end
	toggle(r, "Loop", animLoop, function()
		animLoop = not animLoop
		lastSignature = ""
	end)
	button(r, "Stop", function()
		DebugTools.stopClips(if animOnSelected then selected else nil)
	end, COLORS.danger)
	note("Previews play on this screen only. Movement (idle, walk, run) is mixed in underneath.")
	heading("Clips")
	r = row()
	for _, id in ipairs(sortedKeys(Clips)) do
		button(r, id, function()
			DebugTools.playClip(if animOnSelected then selected else nil, id, animSpeed, animLoop)
		end)
	end
end

builders.Profile = function()
	local profile = snap.profile
	heading(if profile then string.format("Coins %d · XP %d", profile.coins, profile.xp) else "Profile not loaded")
	local r = row()
	for _, amount in ipairs({ 100, 1000, -500 }) do
		button(r, string.format("%+d coins", amount), function()
			send("coins", { amount = amount })
		end)
	end
	for _, amount in ipairs({ 500, 5000 }) do
		button(r, string.format("+%d XP", amount), function()
			send("xp", { amount = amount })
		end)
	end
	r = row()
	button(r, "Unlock every cosmetic", function()
		send("allCosmetics")
	end)
	button(r, "Next day", function()
		send("dayPlus")
	end)
	button(r, "Next week", function()
		send("weekPlus")
	end)
	heading("Passes (this session)")
	r = row()
	for _, pass in ipairs(snap.passes) do
		toggle(r, pass.name, pass.owned, function()
			send("pass", { key = pass.key, on = not pass.owned })
		end)
	end
	heading("Reset")
	r = row()
	for _, spec in ipairs({
		{ "tipsSeen", "Hints" },
		{ "training", "Academy" },
		{ "streak", "Streak" },
		{ "quests", "Quests" },
		{ "achievements", "Achievements" },
		{ "owned", "Cosmetics owned" },
		{ "equipped", "Cosmetics worn" },
		{ "stats", "Stats" },
		{ "mastery", "Mastery" },
		{ "all", "Everything" },
	}) do
		button(r, spec[2], function()
			send("reset", { key = spec[1] })
		end, if spec[1] == "all" then COLORS.danger else nil)
	end
	heading("Test purchase (coin packs)")
	r = row()
	for _, pack in ipairs(Products.COIN_PACKS) do
		button(r, pack.label, function()
			send("receipt", { key = pack.key })
		end)
	end
end

-- Rendering -----------------------------------------------------------------------------------

local function signature(): string
	if not snap then
		return ""
	end
	local parts = {
		currentTab,
		tostring(selected),
		tostring(orderTarget),
		snap.match.phase,
		tostring(snap.match.active),
		tostring(snap.match.round),
		tostring(snap.match.paused),
		tostring(snap.match.nextMap),
		#snap.places.stations,
	}
	for key, value in pairs(snap.settings) do
		table.insert(parts, key .. "=" .. tostring(value))
	end
	for _, entry in ipairs(snap.people) do
		table.insert(
			parts,
			table.concat({
				entry.userId,
				tostring(entry.role),
				tostring(entry.alive),
				tostring(entry.status),
				tostring(entry.ready),
				tostring(entry.eyes),
				tostring(entry.hood),
				tostring(entry.forced),
				tostring(entry.alias),
			}, ":")
		)
	end
	for _, pass in ipairs(snap.passes) do
		table.insert(parts, pass.key .. tostring(pass.owned))
	end
	if snap.profile then
		table.insert(parts, snap.profile.coins .. "/" .. snap.profile.xp)
	end
	return table.concat(parts, "|")
end

local function render(force: boolean?)
	if not snap or not window.Visible then
		return
	end
	local sig = signature()
	if sig == lastSignature and not force then
		return
	end
	lastSignature = sig
	local scroll = content.CanvasPosition
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	order = 0
	local builder = builders[currentTab]
	if builder then
		local ok, err = pcall(builder)
		if not ok then
			note("This tab failed to draw: " .. tostring(err))
		end
	end
	content.CanvasPosition = scroll
	for name, b in pairs(tabButtons) do
		b.BackgroundColor3 = if name == currentTab then COLORS.pick else COLORS.button
	end
end

local function updateStatus()
	if not snap then
		statusLabel.Text = "Waiting for the server..."
		return
	end
	local match = snap.match
	local left = math.max(0, math.floor(match.endsAt - workspace:GetServerTimeNow()))
	local mapLine = if match.active then match.mapName else "lobby"
	local nextName = match.nextMap
	for _, map in ipairs(snap.maps) do
		if map.id == match.nextMap then
			nextName = map.name
		end
	end
	statusLabel.Text = string.format(
		"%s%s · round %d · %s%s\n%s · next map: %s%s",
		match.phase,
		if match.paused then " (paused)" else "",
		match.round,
		if match.active then string.format("%d:%02d left", left // 60, left % 60) else "no match",
		if match.winner then " · winner: " .. match.winner else "",
		mapLine,
		nextName,
		if snap.settings.previewing then " · previewing a map" else ""
	)
	if showStats then
		statsLabel.Text = DebugTools.stats()
	end
end

local function build()
	window = make("Frame", {
		Name = "DebugPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 70),
		Size = UDim2.fromOffset(480, 620),
		BackgroundColor3 = COLORS.window,
		BackgroundTransparency = 0.04,
		Visible = false,
		Active = true,
		Parent = Screens.overlay,
	})
	corner(window, 6)
	make("UIStroke", { Color = Color3.fromRGB(70, 70, 84), Thickness = 1, Parent = window })
	make("UISizeConstraint", { MaxSize = Vector2.new(480, 620), Parent = window })

	local bar = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = COLORS.bar,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = COLORS.header,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Terms.f("   {GAME} DEBUG   (F2 to hide, drag to move)"),
		Parent = window,
	})
	corner(bar, 6)
	-- Drag the window by its bar.
	local dragging, dragStart, startPos = false, Vector2.zero, window.Position
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = window.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			window.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	statusLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 0, 32),
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = window,
	})

	local tabs = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 68),
		Size = UDim2.new(1, -16, 0, 26),
		Parent = window,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabs,
	})
	for index, name in ipairs(TABS) do
		local b = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = COLORS.button,
			Size = UDim2.fromOffset(62, 26),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = COLORS.text,
			Text = name,
			LayoutOrder = index,
			Parent = tabs,
		})
		corner(b)
		b.Activated:Connect(function()
			currentTab = name
			content.CanvasPosition = Vector2.zero
			render(true)
		end)
		tabButtons[name] = b
	end

	content = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 100),
		Size = UDim2.new(1, -16, 1, -108),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	})
	make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	make("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = content })

	statsLabel = make("TextLabel", {
		Name = "DebugStats",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Position = UDim2.fromOffset(12, 70),
		Size = UDim2.fromOffset(330, 40),
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(160, 255, 170),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Visible = false,
		Parent = Screens.overlay,
	})
end

local function setOpen(open: boolean)
	window.Visible = open
	-- Keep the updates coming while role tags are shown, even with the panel closed.
	send("watch", open or DebugTools.tags)
	if open then
		render(true)
	end
end

function DebugPanel.init()
	local function start()
		if window or LocalPlayer:GetAttribute("LDebug") ~= true then
			return
		end
		build()
		DebugTools.init()
		selected = LocalPlayer.UserId
		remote.OnClientEvent:Connect(function(kind: string, data: any)
			if kind == "snapshot" then
				snap = data
				render(false)
				DebugTools.updateTags(people(), roleNames())
			end
		end)
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.KeyCode == Enum.KeyCode.F2 then
				setOpen(not window.Visible)
			end
		end)
		task.spawn(function()
			while true do
				task.wait(0.25)
				if window.Visible or showStats then
					updateStatus()
				end
			end
		end)
	end
	LocalPlayer:GetAttributeChangedSignal("LDebug"):Connect(start)
	start()
end

return DebugPanel
