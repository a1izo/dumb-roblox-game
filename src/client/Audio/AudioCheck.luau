-- Finds out which music and sound ids this experience can actually play. An id fails when the
-- audio is private to another creator, was not shared with this experience, or was moderated;
-- Roblox then plays silence. Each failed id is swapped for the slot's fallbackId, and Studio
-- prints one line per blocked slot with what to do about it.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local AudioCheck = {}

export type Status = "ok" | "failed" | "pending" | "empty"

-- content id -> status
local statuses: { [string]: Status } = {}
local changed = Instance.new("BindableEvent")
AudioCheck.Changed = changed.Event
AudioCheck.done = false

function AudioCheck.status(contentId: string?): Status
	if not contentId or contentId == "" then
		return "empty"
	end
	return statuses[contentId] or "pending"
end

-- The id to play for an audio entry: the upload unless it is known to fail, then the fallback
-- unless that fails too. nil means silence.
function AudioCheck.idFor(entry: Assets.Audio?): string?
	if not entry then
		return nil
	end
	local primary = Assets.contentId(entry.id)
	local fallback = Assets.contentId(entry.fallbackId)
	if primary ~= "" and statuses[primary] ~= "failed" then
		return primary
	end
	if fallback ~= "" and statuses[fallback] ~= "failed" then
		return fallback
	end
	return nil
end

-- Slot status for the debug panel: "ok", "fallback", "blocked", "no id" or "checking".
function AudioCheck.slotStatus(entry: Assets.Audio?): string
	if not entry then
		return "no id"
	end
	local primary = Assets.contentId(entry.id)
	local fallback = Assets.contentId(entry.fallbackId)
	if primary == "" and fallback == "" then
		return "no id"
	end
	local main = AudioCheck.status(if primary ~= "" then primary else fallback)
	if main == "pending" then
		return "checking"
	elseif main == "ok" then
		return if primary ~= "" then "ok" else "fallback"
	end
	if primary ~= "" and fallback ~= "" and AudioCheck.status(fallback) == "ok" then
		return "fallback"
	end
	return "blocked"
end

local function collect(): { [string]: { string } }
	-- content id -> the slots that use it
	local uses: { [string]: { string } } = {}
	local function add(label: string, entry: Assets.Audio)
		for _, id in ipairs({ entry.id, entry.fallbackId }) do
			local contentId = Assets.contentId(id)
			if contentId ~= "" then
				uses[contentId] = uses[contentId] or {}
				table.insert(uses[contentId], label)
			end
		end
	end
	for slot, entry in pairs(Assets.music) do
		add("music " .. slot, entry)
	end
	for key, entry in pairs(Assets.sfx) do
		add("sound " .. key, entry)
	end
	return uses
end

local function report(uses: { [string]: { string } })
	local blocked = {}
	local total, ok = 0, 0
	for contentId, labels in pairs(uses) do
		total += 1
		if statuses[contentId] == "ok" then
			ok += 1
		else
			table.sort(labels)
			table.insert(
				blocked,
				string.format("%s (%s)", table.concat(labels, ", "), string.match(contentId, "%d+") or contentId)
			)
		end
	end
	table.sort(blocked)
	print(string.format("[DeathsGambit] Audio check: %d of %d audio ids play.", ok, total))
	if #blocked > 0 then
		warn(
			"[DeathsGambit] Audio blocked (silent until fixed): "
				.. table.concat(blocked, "; ")
				.. ". Audio must be owned by you or your group and shared with this experience:"
				.. " Creator Hub > Creations > Audio > the track > Permissions > add this experience"
				.. " (or click 'share access' on the error above). Audio uploaded by someone else"
				.. " only works if it is public in the Creator Store."
		)
	end
	-- Two slots on one id is usually a paste mistake.
	local seen = {}
	for slot, entry in pairs(Assets.music) do
		if entry.id ~= "" then
			if seen[entry.id] then
				warn(
					string.format(
						"[DeathsGambit] Music %s and %s use the same id (%s).",
						seen[entry.id],
						slot,
						entry.id
					)
				)
			else
				seen[entry.id] = slot
			end
		end
	end
end

-- Client, once at start: preloads every id and records which ones fail.
function AudioCheck.init()
	task.spawn(function()
		local uses = collect()
		local sounds = {}
		for contentId in pairs(uses) do
			local sound = Instance.new("Sound")
			sound.SoundId = contentId
			table.insert(sounds, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(sounds, function(contentId: string, status: Enum.AssetFetchStatus)
				if uses[contentId] then
					statuses[contentId] = if status == Enum.AssetFetchStatus.Success then "ok" else "failed"
				end
			end)
		end)
		for contentId in pairs(uses) do
			if statuses[contentId] == nil then
				statuses[contentId] = "failed"
			end
		end
		for _, sound in ipairs(sounds) do
			sound:Destroy()
		end
		AudioCheck.done = true
		if RunService:IsStudio() then
			report(uses)
		end
		changed:Fire()
	end)
end

return AudioCheck
