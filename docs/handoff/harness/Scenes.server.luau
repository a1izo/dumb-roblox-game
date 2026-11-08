-- 2026-11-07 harness (server), the scene deaths: only in the throwaway harness place. Every server error and the spec
-- suite's line; waits for the client probe (it plays every shop death scene and a stand-in death with every style),
-- then ends the test.
if not workspace:GetAttribute("DGEmoteHarness") then
	return
end

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function say(fmt, ...)
	print("[EHARNESS] " .. string.format(fmt, ...))
end

local specLine = nil
local errors = 0
LogService.MessageOut:Connect(function(message, kind)
	if string.sub(message, 1, 10) == "[EHARNESS]" then
		return
	end
	if string.find(message, "[DeathsGambit tests]", 1, true) and string.find(message, "passed", 1, true) then
		specLine = message
	end
	if kind == Enum.MessageType.MessageError then
		errors += 1
		if errors <= 40 then
			print("[EHARNESS] SERVER ERROR " .. string.sub(message, 1, 500))
		end
	end
end)

local doneEvent = Instance.new("RemoteEvent")
doneEvent.Name = "AuditDone"
doneEvent.Parent = ReplicatedStorage
local clientBad = -1
doneEvent.OnServerEvent:Connect(function(_, count)
	clientBad = tonumber(count) or 0
end)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
say("server probe start (%s)", player.Name)
local waited = 0
while clientBad < 0 and waited < 600 do
	waited += task.wait(0.5)
end
say("the spec suite: %s", tostring(specLine))
say("client bad %d, server errors %d", clientBad, errors)
say("PROBE DONE")
task.wait(2)
pcall(function()
	game:GetService("StudioTestService"):EndTest("done")
end)
