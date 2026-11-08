-- 2026-11-07 harness (server), the cutscene pass: only in the throwaway harness place. Every server error and the
-- spec suite's line; waits for the client probe (it plays every cutscene), then ends the test.
if not workspace:GetAttribute("DGEmoteHarness") then
	return
end

local CollectionService = game:GetService("CollectionService")
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
local lobby = workspace:WaitForChild("LGameLobby", 120)
task.wait(3)
if lobby then
	local solids, standIns, colliders = 0, 0, 0
	local gateBoard = false
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("BasePart") then
			if string.sub(d.Name, 1, 10) == "PropSolid_" then
				solids += 1
			elseif string.sub(d.Name, 1, 8) == "StandIn_" then
				standIns += 1
			elseif d.Name == "Collider" then
				colliders += 1
			end
		elseif d:IsA("TextLabel") and d.Text == "ACADEMY" then
			gateBoard = true
		end
	end
	local cameraModels = 0
	for _, item in ipairs(CollectionService:GetTagged("LCameraBlock")) do
		if item:IsA("Model") then
			cameraModels += 1
		end
	end
	say("lobby: %d colliders, %d prop solids, %d stand-ins, %d models stopping the camera, gate board %s",
		colliders, solids, standIns, cameraModels, tostring(gateBoard))
	local rift = CollectionService:GetTagged("LRift")[1]
	if rift then
		say("rift: rim %.1f cloud %.1f roof %.1f rx %.1f rz %.1f", rift:GetAttribute("RimY") or -1,
			rift:GetAttribute("CloudY") or -1, rift:GetAttribute("RoofY") or -1, rift:GetAttribute("Rx") or -1,
			rift:GetAttribute("Rz") or -1)
	end
else
	say("no lobby built")
end
local waited = 0
while clientBad < 0 and waited < 540 do
	waited += task.wait(0.5)
end
say("the spec suite: %s", tostring(specLine))
say("client bad %d, server errors %d", clientBad, errors)
say("PROBE DONE")
task.wait(2)
pcall(function()
	game:GetService("StudioTestService"):EndTest("done")
end)
