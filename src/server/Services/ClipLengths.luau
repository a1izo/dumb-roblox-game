--!strict
-- How long an audio slot's clip runs, in seconds, read once on the server (a voiced cutscene stretches to its clip:
-- Shared/Cinema/CutLength). 0 while the slot is empty or the clip does not load in time; remembered per id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local ClipLengths = {}

local known: { [string]: number } = {}
local loading: { [string]: boolean } = {}

local LOAD_WAIT = 4 -- seconds to wait for a clip's length before going on without it

local function load(id: string)
	if known[id] ~= nil or loading[id] then
		return
	end
	loading[id] = true
	local sound = Instance.new("Sound")
	sound.Name = "ClipLength"
	sound.SoundId = id
	sound.Volume = 0
	sound.Parent = SoundService
	local waited = 0
	while not sound.IsLoaded and waited < LOAD_WAIT do
		waited += task.wait(0.1)
	end
	known[id] = if sound.IsLoaded then sound.TimeLength else 0
	loading[id] = nil
	sound:Destroy()
end

-- The clip's length for an Assets.sfx slot (waits up to LOAD_WAIT seconds the first time).
function ClipLengths.get(slot: string): number
	local id = Assets.audioId(Assets.sfx[slot])
	if not id then
		return 0
	end
	load(id)
	local waited = 0
	while known[id] == nil and waited < LOAD_WAIT + 1 do
		waited += task.wait(0.1)
	end
	return known[id] or 0
end

-- Starts loading these slots now, so a later get() does not wait.
function ClipLengths.warm(slots: { string })
	for _, slot in ipairs(slots) do
		local id = Assets.audioId(Assets.sfx[slot])
		if id then
			task.spawn(load, id)
		end
	end
end

return ClipLengths
