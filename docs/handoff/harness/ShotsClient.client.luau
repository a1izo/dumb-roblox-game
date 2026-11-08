-- 2026-11-07 harness (client), the cutscene pass: only in the throwaway harness place. Plays every cutscene in
-- Shared/Cinema/Shots (cast as this player where a slot is "self"), each to its end, and reports for each: whether it
-- finished, how long it took against its own length, how many actors it staged, how far their legs moved (a cutscene
-- whose feet were planned must step), and every client error meanwhile.
if not workspace:GetAttribute("DGEmoteHarness") then
	return
end

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	if kind == Enum.MessageType.MessageError or string.find(message, "Anim/Life failed", 1, true) then
		errors += 1
		if errors <= 40 then
			print("[EHARNESS] CLIENT ERROR " .. string.sub(message, 1, 500))
		end
	end
end)

-- (the server rebuilds an R15 avatar as R6 a few seconds after it spawns: wait for the R6 body)
local tWait = os.clock()
repeat
	task.wait(0.5)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
until (humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 and os.clock() - tWait > 8) or os.clock() - tWait > 40
task.wait(2)

local ShotPlayer = require(Client:WaitForChild("Presentation"):WaitForChild("ShotPlayer"))
local shotsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cinema"):WaitForChild("Shots")
local names = {}
for _, m in ipairs(shotsFolder:GetChildren()) do
	if m:IsA("ModuleScript") then
		table.insert(names, m.Name)
	end
end
table.sort(names)
say("%d cutscenes: %s", #names, table.concat(names, ", "))

local bad = 0
for _, name in ipairs(names) do
	local before = errors
	local data = ShotPlayer.get(name)
	local length = data and data.length or -1
	local finished = false
	local started = os.clock()
	task.spawn(function()
		local ok, err = pcall(ShotPlayer.play, name, { cast = { self = LocalPlayer.UserId } })
		if not ok then
			say("%s: play error %s", name, tostring(err))
			bad += 1
		end
		finished = true
	end)
	-- the actors' legs: how far each leg's joint turned over the shot (summed), the most of any actor
	local seen, travelled = {}, {}
	local lastScan = -1
	local conn = RunService.Heartbeat:Connect(function()
		if os.clock() - lastScan > 0.5 then
			lastScan = os.clock()
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("Model") and d:GetAttribute("DGLife") ~= nil and not seen[d] then
					seen[d] = true
					travelled[d] = 0
				end
			end
		end
		for model in pairs(seen) do
			local torso = model:FindFirstChild("Torso")
			local hip = torso and torso:FindFirstChild("Right Hip")
			if hip and hip:IsA("Motor6D") then
				local last = model:GetAttribute("EHLastHip")
				local now = hip.Transform
				if typeof(last) == "CFrame" then
					local _, angle = (last:Inverse() * now):ToAxisAngle()
					travelled[model] += math.abs(angle)
				end
				model:SetAttribute("EHLastHip", now)
			end
		end
	end)
	while not finished and os.clock() - started < length + 25 do
		task.wait(0.25)
	end
	conn:Disconnect()
	local actors, most, moving = 0, 0, 0
	for model, total in pairs(travelled) do
		actors += 1
		most = math.max(most, math.deg(total))
		if math.deg(total) > 30 then
			moving += 1
		end
	end
	local took = os.clock() - started
	say("%s: finished %s in %.1f s (length %.1f), %d actors, %d with legs that moved (most %.0f degrees), %d errors",
		name, tostring(finished), took, length, actors, moving, most, errors - before)
	if not finished then
		bad += 1
	end
	task.wait(2)
end
say("all cutscenes played; client errors %d", errors)
doneEvent:FireServer(bad + errors)
