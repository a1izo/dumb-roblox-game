-- Death's Gambit whole-game audit harness (temporary local plugin, installed and removed by the audit session
-- 3e64b245). Acts only in the harness place (Workspace attribute DGEmoteHarness), never in any other place.
-- Starts a play test (server and client), waits for the probe script inside the place to end it, reports the
-- errors and warnings the Output saw. Prints [EHARNESS] lines.

local RunService = game:GetService("RunService")
if not workspace:GetAttribute("DGEmoteHarness") then
	return
end
if not RunService:IsEdit() then
	return
end

local LogService = game:GetService("LogService")

local function log(fmt, ...)
	print("[EHARNESS] " .. string.format(fmt, ...))
end

local errors, warnings = {}, {}
LogService.MessageOut:Connect(function(message, kind)
	if string.sub(message, 1, 10) == "[EHARNESS]" then
		return
	end
	if kind == Enum.MessageType.MessageError then
		table.insert(errors, message)
	elseif kind == Enum.MessageType.MessageWarning then
		table.insert(warnings, message)
	end
end)

-- With the place's DGSharp attribute (2026-10-23, the owner asked for pictures where avatars do not look
-- pixelated): Studio's graphics at their highest for the test, and the owner's own levels put back after it.
local function sharpen(): () -> ()
	if not workspace:GetAttribute("DGSharp") then
		return function() end
	end
	local rendering = settings().Rendering
	local saved = {}
	-- (the owner's own levels, read on 2026-10-23: put back even when a run cut short left the forced ones behind)
	local OWN = {
		QualityLevel = Enum.QualityLevel.Automatic,
		EditQualityLevel = Enum.QualityLevel.Automatic,
		MeshPartDetailLevel = Enum.MeshPartDetailLevel.DistanceBased,
	}
	for name, value in pairs({
		QualityLevel = Enum.QualityLevel.Level21,
		EditQualityLevel = Enum.QualityLevel.Level21,
		MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04,
	}) do
		local ok, old = pcall(function()
			return (rendering :: any)[name]
		end)
		if ok and old == value then
			old = OWN[name]
		end
		local set = ok and pcall(function()
			(rendering :: any)[name] = value
		end)
		if set then
			saved[name] = old
		end
		log("graphics %s: %s -> %s (%s)", name, tostring(old), tostring(value), if set then "set" else "not settable")
	end
	return function()
		for name, old in pairs(saved) do
			pcall(function()
				(rendering :: any)[name] = old
			end)
			log("graphics %s back to %s", name, tostring(old))
		end
	end
end

task.delay(8, function()
	log("start dg_emote_harness")
	local restore = sharpen()
	local played, result = pcall(function()
		return game:GetService("StudioTestService"):ExecutePlayModeAsync({ harness = true })
	end)
	restore()
	log("play test: %s (%s)", tostring(played), tostring(result))
	log("%d errors, %d warnings in the edit session's Output", #errors, #warnings)
	for i = 1, math.min(#errors, 40) do
		log("E %s", string.sub(errors[i], 1, 500))
	end
	for i = 1, math.min(#warnings, 40) do
		log("W %s", string.sub(warnings[i], 1, 300))
	end
	log("DONE")
end)
