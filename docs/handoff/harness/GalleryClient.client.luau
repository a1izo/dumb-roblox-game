-- 2026-11-08 harness (client), the debug panel's cutscene gallery: only in the throwaway harness place, with no match
-- running (as in the lobby). Opens the panel on Show, checks the gallery's buttons are built, plays the new deaths the
-- way its button does (each must start, the panel hidden meanwhile and back after), then a run stopped half way (it
-- must not go on into the next scene or into the grave), then the grave on its own.
if not workspace:GetAttribute("DGEmoteHarness") then
	return
end

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Client = script.Parent:WaitForChild("Client")
local doneEvent = ReplicatedStorage:WaitForChild("AuditDone") :: RemoteEvent

local function say(fmt, ...)
	print("[EHARNESS] CLIENT " .. string.format(fmt, ...))
end

local errors = 0
LogService.MessageOut:Connect(function(message, kind)
	if string.sub(message, 1, 10) == "[EHARNESS]" then
		return
	end
	if
		kind == Enum.MessageType.MessageError
		or string.find(message, "win cutscene", 1, true)
		or string.find(message, "VFX step failed", 1, true)
		or string.find(message, "death effect", 1, true)
	then
		errors += 1
		if errors <= 40 then
			print("[EHARNESS] CLIENT ERROR " .. string.sub(message, 1, 500))
		end
	end
end)

local tWait = os.clock()
repeat
	task.wait(0.5)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
until (humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 and os.clock() - tWait > 8) or os.clock() - tWait > 40
task.wait(2)

local bad = 0
local DebugPanel = require(Client:WaitForChild("Debug"):WaitForChild("DebugPanel"))
local WinCinema = require(Client:WaitForChild("Presentation"):WaitForChild("WinCinema"))
local DeathCuts = require(ReplicatedStorage.Shared.Cinema.DeathCuts) :: any

-- 1. The Show tab, built: the gallery's buttons and every new death's.
local opened = false
local t0 = os.clock()
while not opened and os.clock() - t0 < 20 do
	opened = DebugPanel.openTab("Show")
	task.wait(0.5)
end
task.wait(2)
local texts = {}
local gui = LocalPlayer:WaitForChild("PlayerGui")
for _, item in ipairs(gui:GetDescendants()) do
	if item:IsA("TextButton") then
		texts[item.Text] = true
	end
end
local list = DebugPanel.gallery.list()
local groups = {}
for _, scene in ipairs(list) do
	groups[scene.group] = (groups[scene.group] or 0) + 1
end
local missing = {}
for _, scene in ipairs(list) do
	if not texts[scene.label] then
		table.insert(missing, scene.label)
	end
end
local playAll = false
for text in pairs(texts) do
	if string.find(text, "Play all", 1, true) then
		playAll = true
	end
end
say(
	"Show tab opened %s; gallery %d scenes (custom deaths %d, styles %d, wins %d, others %d); Play all %s, new %s,"
		.. " Stop %s; scenes without a button: %d %s",
	tostring(opened),
	#list,
	groups["Custom deaths"] or 0,
	groups["Death styles"] or 0,
	groups["Win cutscenes"] or 0,
	groups["Others"] or 0,
	tostring(playAll),
	tostring(texts["The 8 new deaths"] == true),
	tostring(texts["Stop"] == true),
	#missing,
	table.concat(missing, ", ")
)
if not (opened and playAll and texts["The 8 new deaths"] and texts["Stop"] and #missing == 0) then
	bad += 1
end

-- 2. The new deaths, as the button plays them: each starts (and the patriot goes on into its grave), the panel hidden
-- while they play and shown again after.
local labels = {}
for _, scene in ipairs(list) do
	labels[scene.name] = scene.label
end
local before = errors
local seen, order = {}, {}
local hidden = true
local started = os.clock()
DebugPanel.gallery.play(DebugPanel.gallery.new, labels)
local total = 0
for _, name in ipairs(DebugPanel.gallery.new) do
	total += (DeathCuts[name] and DeathCuts[name].length or 10) + 1.5
end
total += DeathCuts.patriot_grave.length + 6
task.wait(1)
while os.clock() - started < total do
	local now = WinCinema.current
	if now and not seen[now] then
		seen[now] = true
		table.insert(order, now)
	end
	if now and DebugPanel.shown() then
		hidden = false
	end
	if not now and not WinCinema.previewing() and #order >= #DebugPanel.gallery.new + 1 then
		task.wait(1.5)
		if not WinCinema.previewing() then
			break
		end
	end
	task.wait(0.1)
end
local back = DebugPanel.shown()
say(
	"new deaths: played %d of %d (+ the grave %s) in %.1f s, panel hidden while playing %s, back after %s, %d errors; order: %s",
	#order - (if seen.patriot_grave then 1 else 0),
	#DebugPanel.gallery.new,
	tostring(seen.patriot_grave == true),
	os.clock() - started,
	tostring(hidden),
	tostring(back),
	errors - before,
	table.concat(order, ", ")
)
if #order ~= #DebugPanel.gallery.new + 1 or not seen.patriot_grave or not hidden or not back then
	bad += 1
end
task.wait(1.5)

-- 3. Stopped half way through "A true patriot": nothing more plays (not the grave, not the next scene).
before = errors
DebugPanel.gallery.play({ "reason_patriot", "reason_sans" }, labels)
task.wait(3)
local during = WinCinema.current
DebugPanel.gallery.stop()
local after = {}
local t1 = os.clock()
while os.clock() - t1 < 8 do
	if WinCinema.current then
		after[WinCinema.current] = true
	end
	task.wait(0.1)
end
local leaked = {}
for name in pairs(after) do
	table.insert(leaked, name)
end
say(
	"stopped half way: was playing %s, played after the stop: %s, preview still on %s, %d errors",
	tostring(during),
	if #leaked > 0 then table.concat(leaked, ", ") else "nothing",
	tostring(WinCinema.previewing()),
	errors - before
)
if during ~= "reason_patriot" or #leaked > 0 or WinCinema.previewing() then
	bad += 1
end

-- 4. The grave on its own: someone else at it (alone here: the faceless figure), this player's name on the stone.
before = errors
DebugPanel.gallery.play({ "patriot_grave" }, labels)
task.wait(3)
local refs = WinCinema.lastRefs
local plate = refs and refs.parts and refs.parts.Name
local mark = plate and plate:FindFirstChild("Mark")
local label = mark and mark:FindFirstChildOfClass("TextLabel")
local stone = if label then label.Text else nil
local star = if refs and refs.star then refs.star.Name else nil
local t2 = os.clock()
while WinCinema.previewing() and os.clock() - t2 < DeathCuts.patriot_grave.length + 4 do
	task.wait(0.2)
end
say(
	"the grave alone: headstone %q (player %q), saluter %s, finished %s, %d errors",
	tostring(stone),
	string.upper(LocalPlayer.DisplayName),
	tostring(star),
	tostring(not WinCinema.previewing()),
	errors - before
)
if stone ~= string.upper(LocalPlayer.DisplayName) or WinCinema.previewing() then
	bad += 1
end

say("all gallery checks done; client errors %d", errors)
doneEvent:FireServer(bad + errors)
