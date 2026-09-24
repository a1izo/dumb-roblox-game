-- A death at the table: the camera pushes in on the victim's seat, the heart monitor beats
-- twice and flatlines, and the screen edges bleed red. The announcement names the cause.
-- The victim sees their own screen drain of colour instead.

local Players = game:GetService("Players")

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.Parent.UI.Theme)
local Mixer = require(script.Parent.Parent.Parent.Audio.Mixer)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)

local LocalPlayer = Players.LocalPlayer

local SHOT = 3.6

return function(cue)
	if not ClientState.isParticipant() then
		return
	end
	local data = cue.data
	Cinema.waitUntil(cue.at)
	Mixer.duck("death", true)
	Sfx.play("heartbeat")
	task.delay(0.8, Sfx.play, "heartbeat")
	task.delay(1.7, Sfx.play, "flatline")
	local removeVignette = Cinema.vignette(Theme.colors.accent, 0.3)

	if data.userId == LocalPlayer.UserId then
		local untint = Cinema.tint({ Saturation = -1, Contrast = 0.15, Brightness = -0.05 }, 1.2)
		task.wait(5)
		untint()
	else
		local character = Cinema.character(data.userId)
		if character then
			local token = CameraDirector.take(SHOT + 0.5)
			Cinema.letterbox(true)
			CameraDirector.cut(token, Cinema.faceShot(character, 11, 2.5, 4), 60)
			CameraDirector.move(token, Cinema.faceShot(character, 5.5, 0.9, 1.2), SHOT - 0.2, 45)
			local removeOutline = Cinema.outline(character, Theme.colors.accent)
			task.wait(SHOT)
			removeOutline()
			Cinema.letterbox(false)
			CameraDirector.release(token)
		else
			task.wait(SHOT)
		end
	end
	removeVignette()
	Mixer.duck("death", false)
end
