-- One-shot sound effects by name from the asset registry. A slot with no id plays nothing,
-- so every call is safe before the sounds are uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local Mixer = require(script.Parent.Mixer)

local Sfx = {}

export type Options = {
	group: string?, -- "Sfx" (default), "Ui" or "Ambience"
	volume: number?,
	pitch: number?,
	parent: Instance?, -- a part for positional sound; plays on the listener otherwise
	looped: boolean?,
}

-- Plays the effect and returns the Sound (nil when the slot is empty). Looped sounds must be
-- destroyed by the caller; one-shots clean themselves up.
function Sfx.play(key: string, options: Options?): Sound?
	local entry = Assets.sfx[key]
	local id = Assets.audioId(entry)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. key
	sound.SoundId = id
	sound.Volume = (if options and options.volume then options.volume else 1) * (entry.volume or 1)
	sound.PlaybackSpeed = if options and options.pitch then options.pitch else 1
	sound.Looped = options ~= nil and options.looped == true
	sound.SoundGroup = Mixer.group(if options and options.group then options.group else "Sfx")
	sound.Parent = if options and options.parent then options.parent else SoundService
	if not sound.Looped then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		task.delay(30, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
	sound:Play()
	return sound
end

return Sfx
