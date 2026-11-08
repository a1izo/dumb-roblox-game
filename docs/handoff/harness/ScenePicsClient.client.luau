-- 2026-11-08 harness (client), the scene deaths' pictures: only in the throwaway harness place. Plays every scene death
-- as the shop's Preview does and takes a picture at the moments its frame-by-frame sheet marks (art/refs/deaths/), so
-- they can be laid beside the reference. Each picture is logged with its label in order.
if not workspace:GetAttribute("DGEmoteHarness") then
	return
end

local CaptureService = game:GetService("CaptureService")
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

local Presentation = Client:WaitForChild("Presentation")
local SceneDeaths = require(Presentation:WaitForChild("SceneDeaths"))
local WinCinema = require(Presentation:WaitForChild("WinCinema"))

local count = 0
local function picture(label: string)
	local done = false
	count += 1
	CaptureService:CaptureScreenshot(function(contentId)
		say("picture %d %s -> %s", count, label, tostring(contentId))
		done = true
	end)
	local t = os.clock()
	while not done and os.clock() - t < 3 do
		task.wait()
	end
end

-- the moments each sheet marks (seconds into the scene)
local MOMENTS = {
	requiem = { 0.1, 0.6, 1.8, 2.7, 4.5, 9.0, 12.0, 16.3 },
	blackwall = { 0.8, 3.0, 7.2, 11.0, 13.6, 15.2, 16.35, 19.0, 22.8 },
	god = { 1.5, 4.0, 7.5, 10.5, 13.0, 14.7 },
	ironMan = { 1.0, 3.2, 4.2, 6.5, 8.7, 9.3, 11.0, 14.0, 17.0 },
	sam = { 0.5, 1.6, 2.1, 2.8, 3.4, 5.5, 8.0, 12.0 },
	walrider = { 1.0, 2.8, 5.0, 7.3, 8.0, 10.5, 16.3, 18.3 },
	sans = { 3.0, 19.5, 24.05, 25.3, 25.85, 28.5 },
	patriot = { 1.5, 4.5, 7.5, 11.0, 15.0, 20.0, 24.0 },
	selection = { 1.0, 4.5, 7.5, 8.5, 9.8, 11.0 },
}

local only = workspace:GetAttribute("DGPicsOnly")
for _, style in ipairs(SceneDeaths.names()) do
	if type(only) == "string" and not string.find(only, style, 1, true) then
		continue
	end
	local before = errors
	local started = os.clock()
	local finished = false
	WinCinema.preview("scene:" .. style, function()
		finished = true
	end)
	for _, t in ipairs(MOMENTS[style] or {}) do
		local wait = t - (os.clock() - started)
		if wait > 0 then
			task.wait(wait)
		end
		picture(style .. " " .. string.format("%.2f", t))
	end
	while not finished and os.clock() - started < SceneDeaths.length(style) + 6 do
		task.wait(0.2)
	end
	say("%s: finished %s, %d errors", style, tostring(finished), errors - before)
	task.wait(1.5)
end
say("all pictures taken (%d); client errors %d", count, errors)
doneEvent:FireServer(errors)
