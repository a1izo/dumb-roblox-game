-- 2026-11-08 harness (client), the scene deaths rebuilt 1 for 1: only in the throwaway harness place, no match running.
-- Plays every scene death through the debug gallery (as its button does), one after another: each must start and
-- finish with no errors (scene and effect warnings counted); the patriot's headstone must read this player's name;
-- the Manual's sentence for a few causes, and one written scattered on the page.
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
		or string.find(message, "scene death", 1, true)
		or string.find(message, "VFX step failed", 1, true)
		or string.find(message, "death effect", 1, true)
		or string.find(message, "win cutscene", 1, true)
	then
		errors += 1
		if errors <= 60 then
			print("[EHARNESS] CLIENT ERROR " .. string.sub(message, 1, 600))
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
local Presentation = Client:WaitForChild("Presentation")
local SceneDeaths = require(Presentation:WaitForChild("SceneDeaths"))
local WinCinema = require(Presentation:WaitForChild("WinCinema"))
local DebugPanel = require(Client:WaitForChild("Debug"):WaitForChild("DebugPanel"))
local DeathLines = require(ReplicatedStorage.Shared.Presentation.DeathLines)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)

-- 0. Every scene death's module loads, with its length; every custom death's item points at it
for _, name in ipairs(SceneDeaths.names()) do
	say("scene %s: loads %s, %.1f s", name, tostring(SceneDeaths.has(name)), SceneDeaths.length(name))
	if not SceneDeaths.has(name) then
		bad += 1
	end
end
local scenesInShop = 0
for _, item in ipairs(Cosmetics.ofKind("reason")) do
	local cut = WinCinema.cutOf(item)
	if type(item.scene) == "number" then
		scenesInShop += 1
		if cut ~= "scene:" .. item.style or math.abs(SceneDeaths.length(item.style) - item.scene) > 0.01 then
			say("item %s: cut %s, length %s vs %s", item.id, tostring(cut), tostring(item.scene), tostring(SceneDeaths.length(item.style)))
			bad += 1
		end
	end
end
say("%d custom deaths are scene deaths", scenesInShop)

-- 1. The Manual's sentences
for _, cause in ipairs({ "Heart attack", "Walrider", "Let's dance!", "Dead by selection", "This is... requiem" }) do
	say("sentence: %s", DeathLines.sentence("John Doe", cause))
end

-- 1b. A sentence written scattered in the Manual: every word its own label, not all on one line or one angle
do
	local before = errors
	local CameraDirector = require(Presentation:WaitForChild("CameraDirector"))
	local BookStage = require(Presentation:WaitForChild("BookStage"))
	local token = CameraDirector.take(6)
	local sentence = DeathLines.sentence("John Doe", "Walrider")
	local stop = BookStage.play(token, { { text = sentence, scatter = true } }, 2.8)
	task.wait(3.4)
	local words, rotations, rows = 0, {}, {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("TextLabel") and string.find(sentence, d.Text, 1, true) and d.Text ~= "" and d.Parent and d.Parent:IsA("Frame") then
			words += 1
			rotations[math.floor(d.Parent.Rotation * 10)] = true
			rows[math.floor(d.Parent.Position.Y.Offset / 20)] = true
		end
	end
	local angles, lines = 0, 0
	for _ in pairs(rotations) do
		angles += 1
	end
	for _ in pairs(rows) do
		lines += 1
	end
	stop()
	CameraDirector.release(token)
	say("manual: %q written as %d words, %d different tilts, %d heights, %d errors", sentence, words, angles, lines, errors - before)
	if words < 5 or angles < 3 then
		bad += 1
	end
end

-- 2. Every scene, as the gallery's button plays it
local list = DebugPanel.gallery.list()
local labels = {}
for _, scene in ipairs(list) do
	labels[scene.name] = scene.label
end
for _, name in ipairs(DebugPanel.gallery.new) do
	local style = string.sub(name, 7)
	local before = errors
	local started, finished = false, false
	local stone = nil
	local t0 = os.clock()
	DebugPanel.gallery.play({ name }, labels)
	local length = SceneDeaths.length(style)
	while os.clock() - t0 < length + 8 do
		if SceneDeaths.current == style then
			started = true
			local ctx = SceneDeaths.lastCtx
			if style == "patriot" and ctx and ctx.stage and not stone then
				for _, d in ipairs(ctx.stage.folder:GetDescendants()) do
					if d:IsA("TextLabel") and d.Name == "DeadName" then
						stone = d.Text
					end
				end
			end
		elseif started and not WinCinema.previewing() then
			finished = true
			break
		end
		task.wait(0.1)
	end
	say("%s: started %s, finished %s in %.1f s (length %.1f), %d errors%s", style, tostring(started), tostring(finished),
		os.clock() - t0, length, errors - before, if stone then ", headstone " .. stone else "")
	if not (started and finished) or (style == "patriot" and stone ~= string.upper(LocalPlayer.DisplayName)) then
		bad += 1
	end
	task.wait(1.5)
end

say("all scene checks done; client errors %d", errors)
doneEvent:FireServer(bad + errors)
