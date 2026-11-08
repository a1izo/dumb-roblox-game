-- 2026-11-07 harness (client), the deaths' pictures: only in the throwaway harness place. Plays every shop death scene
-- (Shared/Cinema/DeathCuts) as the shop's Preview does, and takes a picture at its moments: the death's first beat, the
-- moment the body hits the floor, and the climax after (a style's own moment). Each picture is logged with its label
-- in order, so the copies the harness keeps can be matched to them.
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
	if kind == Enum.MessageType.MessageError or string.find(message, "VFX step failed", 1, true) or string.find(message, "death effect", 1, true) then
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

local WinCinema = require(Client:WaitForChild("Presentation"):WaitForChild("WinCinema"))
local DeathCuts = require(ReplicatedStorage.Shared.Cinema.DeathCuts) :: any
local DeathTiming = require(ReplicatedStorage.Shared.Anim.DeathTiming) :: any

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

local names = {}
for name in pairs(DeathCuts) do
	table.insert(names, name)
end
table.sort(names)
local only = workspace:GetAttribute("DGPicsOnly")
local bad = 0
for _, name in ipairs(names) do
	if type(only) == "string" and not string.find(only, name, 1, true) then
		continue
	end
	local cut = DeathCuts[name]
	local timing = DeathTiming.deaths[cut.clip] or { hit = 0, fx = nil }
	local moments = {}
	-- (the second batch, 2026-11-08: each on its own signature moments, seconds into its clip)
	local OWN = {
		reason_requiem = { { 0.42, "blow" }, { 1.0, "rewind" }, { 1.75, "what" }, { 2.5, "barrage" }, { 3.82, "again" } },
		reason_blackwall = { { 0.45, "scan" }, { 0.9, "glitch" }, { 1.36, "burst" }, { 1.8, "burning" } },
		reason_god = { { 1.0, "boast" }, { 1.7, "segments" }, { 2.3, "pulse" } },
		reason_ironman = { { 1.2, "stones" }, { 1.74, "snap" }, { 2.4, "burnt" } },
		reason_sam = { { 0.6, "zan" }, { 1.3, "lines" }, { 1.66, "cuts" } },
		reason_walrider = { { 0.52, "shots" }, { 2.8, "reach" }, { 3.3, "swarm" } },
		reason_sans = { { 0.6, "zzz" }, { 1.45, "miss" }, { 2.3, "line" }, { 2.62, "slash" } },
		reason_patriot = { { 0.36, "shot" }, { 2.0, "petals" } },
	}
	if cut.kind == "grave" then
		moments = { { 1.2, "stone" }, { 4.4, "salute" }, { 5.9, "tear" }, { 7.8, "wide" }, { 9.6, "close" } }
	elseif OWN[name] then
		for _, m in ipairs(OWN[name]) do
			table.insert(moments, { cut.clipAt + m[1], m[2] })
		end
		table.insert(moments, { cut.clipAt + timing.hit + 0.06, "hit" })
	else
		table.insert(moments, { cut.clipAt + 0.3, "beat" })
		table.insert(moments, { cut.clipAt + timing.hit + 0.06, "hit" })
	end
	local style = nil
	for _, e in ipairs(cut.events) do
		if e.act == "fallen" then
			style = e
		end
	end
	if style then
		local slen = 3
		for clip, m in pairs(DeathTiming.fallen) do
			if string.find(clip, "fallen" .. string.upper(string.sub(style.style, 1, 1)) .. string.sub(style.style, 2), 1, true) then
				slen = m.length
				local key = m.burst or m.snap or m.shatter or m.crumble or m.set
				if key then
					table.insert(moments, { style.at + key - 0.05, "climax" })
				end
				table.insert(moments, { style.at + slen * 0.45, "acting" })
				break
			end
		end
	elseif cut.kind ~= "grave" and not OWN[name] then
		local fx = timing.fx
		if fx and fx + 0.35 < timing.hit then
			table.insert(moments, { cut.clipAt + fx + 0.25, "effect" })
		end
		table.insert(moments, { cut.clipAt + timing.hit + 0.6, "after" })
	end
	table.sort(moments, function(a, b)
		return a[1] < b[1]
	end)
	local before = errors
	local started = os.clock()
	local finished = false
	WinCinema.play(name, {
		userId = LocalPlayer.UserId,
		named = "Probe Name",
		wait = false,
		onEnd = function()
			finished = true
		end,
	})
	for _, m in ipairs(moments) do
		local wait = m[1] - (os.clock() - started)
		if wait > 0 then
			task.wait(wait)
		end
		picture(name .. " " .. m[2])
	end
	while not finished and os.clock() - started < cut.length + 6 do
		task.wait(0.2)
	end
	say("%s: finished %s, %d errors", name, tostring(finished), errors - before)
	if not finished then
		bad += 1
	end
	task.wait(1)
end
say("all pictures taken (%d); client errors %d", count, errors)
doneEvent:FireServer(bad + errors)
