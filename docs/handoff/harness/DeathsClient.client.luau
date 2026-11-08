-- 2026-11-07 harness (client), the deaths pass: only in the throwaway harness place.
--   1. Every shop death scene (Shared/Cinema/DeathCuts) played as the shop's Preview plays it, starring this player:
--      whether it finished, how long it took against its length, where the star's torso ended (its height over the
--      set's floor: a body lying down is about 0.5 to 1.5 over it; a heap on its knees higher), whether a style's
--      acting took over (the procedural track), and every client error meanwhile.
--   2. A death in a case with each death style, stood in for by Presentation/Fallen on this player's own body: the
--      stand-in made, the real body hidden, the style's clip playing after the collapse, the stand-in gone after clear.
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
	if kind == Enum.MessageType.MessageError or string.find(message, "win cutscene", 1, true) or string.find(message, "VFX step failed", 1, true) or string.find(message, "death effect", 1, true) then
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

local Presentation = Client:WaitForChild("Presentation")
local WinCinema = require(Presentation:WaitForChild("WinCinema"))
local Fallen = require(Presentation:WaitForChild("Fallen"))
local DeathCuts = require(ReplicatedStorage.Shared.Cinema.DeathCuts) :: any

local names = {}
for name in pairs(DeathCuts) do
	table.insert(names, name)
end
table.sort(names)
say("%d death scenes", #names)

local bad = 0
for _, name in ipairs(names) do
	local before = errors
	local cut = DeathCuts[name]
	local finished = false
	local started = os.clock()
	local lowest, style = math.huge, false
	local graveName = nil
	local stop = WinCinema.play(name, {
		userId = LocalPlayer.UserId,
		named = "Probe Name",
		wait = false,
		onEnd = function()
			finished = true
		end,
	})
	while not finished and os.clock() - started < cut.length + 8 do
		local refs = WinCinema.lastRefs
		local star = refs and refs.star
		local torso = star and star:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			local floorY = refs.origin.Position.Y
			if os.clock() - started > cut.clipAt + 0.5 then
				lowest = math.min(lowest, torso.Position.Y - floorY)
			end
			local plate = refs.parts and refs.parts.Name
			local mark = plate and plate:FindFirstChild("Mark")
			local label = mark and mark:FindFirstChildOfClass("TextLabel")
			if label then
				graveName = label.Text
			end
			local track = star:GetAttribute("DGLife")
			if track == 0 and cut.clip and os.clock() - started > cut.length - 1 then
				style = true
			end
		end
		task.wait(0.1)
	end
	if not finished then
		pcall(stop)
		bad += 1
	end
	say(
		"%s: finished %s in %.1f s (length %.1f), torso's lowest %.2f over the floor, %d errors",
		name,
		tostring(finished),
		os.clock() - started,
		cut.length,
		lowest,
		errors - before
	)
	if cut.kind == "grave" then
		-- (no death here: the one saluting stands; the headstone must read the dead's name)
		say("%s: the headstone reads %q", name, tostring(graveName))
		if graveName ~= "PROBE NAME" then
			bad += 1
		end
	elseif lowest < 0.2 or lowest > 2.6 then
		say("%s: the body did not end on the floor", name)
		bad += 1
	end
	task.wait(1.5)
end

-- 1b. The Preview of "A true patriot" goes on into its grave, the player's own name on the headstone, someone else
-- (or the faceless figure, alone here) at it.
do
	local before = errors
	local saw, nameSeen, starSeen = false, nil, nil
	local ended = false
	local started = os.clock()
	WinCinema.preview("reason_patriot", function()
		ended = true
	end)
	local limit = DeathCuts.reason_patriot.length + DeathCuts.patriot_grave.length + 10
	while not ended and os.clock() - started < limit do
		if WinCinema.current == "patriot_grave" then
			saw = true
			local refs = WinCinema.lastRefs
			local plate = refs and refs.parts and refs.parts.Name
			local mark = plate and plate:FindFirstChild("Mark")
			local label = mark and mark:FindFirstChildOfClass("TextLabel")
			nameSeen = label and label.Text or nameSeen
			starSeen = refs and refs.star and refs.star.Name or starSeen
		end
		task.wait(0.1)
	end
	say(
		"patriot Preview: went on into the grave %s, headstone %q (player %q), saluter %s, ended %s in %.1f s, %d errors",
		tostring(saw),
		tostring(nameSeen),
		string.upper(LocalPlayer.DisplayName),
		tostring(starSeen),
		tostring(ended),
		os.clock() - started,
		errors - before
	)
	if not (saw and ended and nameSeen == string.upper(LocalPlayer.DisplayName)) then
		bad += 1
	end
	task.wait(1.5)
end

-- 2. The stand-in, on this player's own body, once for each style.
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if character and root then
	for _, style in ipairs({ "strings", "crows", "stone", "glass", "ash" }) do
		local before = errors
		local at = workspace:GetServerTimeNow() + 0.2
		Fallen.stand(LocalPlayer.UserId, character, at, "Heart attack", style, "Probe")
		task.wait(0.6)
		local copy = Fallen.bodyOf(LocalPlayer.UserId)
		local hidden = root.LocalTransparencyModifier >= 1
			or (character:FindFirstChild("Torso") :: BasePart).LocalTransparencyModifier >= 1
		local stood = copy ~= nil and copy ~= character
		task.wait(2.7 + 1.2 + 1.0)
		local acting = false
		if copy then
			local torso = copy:FindFirstChild("Torso")
			acting = torso ~= nil
		end
		task.wait(3.5)
		Fallen.clear(LocalPlayer.UserId)
		task.wait(0.5)
		local back = (character:FindFirstChild("Torso") :: BasePart).LocalTransparencyModifier < 1
		say(
			"stand-in %s: made %s, real body hidden %s, acted %s, body back after %s, %d errors",
			style,
			tostring(stood),
			tostring(hidden),
			tostring(acting),
			tostring(back),
			errors - before
		)
		if not (stood and hidden and back) then
			bad += 1
		end
	end
else
	say("no body for the stand-in checks")
	bad += 1
end
-- 3. Your look's try-on (the shop's view): custom deaths and death styles on the copy.
local okLook, YourLook = pcall(function()
	return require(Client:WaitForChild("UI"):WaitForChild("Shop"):WaitForChild("YourLook"))
end)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
if okLook then
	local gui = Instance.new("ScreenGui")
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(420, 520)
	holder.Parent = gui
	local look = YourLook.new(holder)
	look:open({ equipped = {}, owned = {} })
	task.wait(1)
	for _, id in ipairs({ "reason_chip", "reason_requiem", "reason_sans", "reason_patriot", "death_strings", "death_glass" }) do
		local before = errors
		look:show(Cosmetics.byId(id))
		task.wait(1.5)
		local copy = look.copy
		local still = look.still == true
		task.wait(7.5)
		say("try-on %s: copy %s, held still while it played %s, %d errors", id, tostring(copy ~= nil),
			tostring(still), errors - before)
		if copy == nil then
			bad += 1
		end
	end
	look:show(nil)
	look:close()
	gui:Destroy()
else
	say("no Your look: %s", tostring(YourLook))
	bad += 1
end
say("all death checks done; client errors %d", errors)
doneEvent:FireServer(bad + errors)
