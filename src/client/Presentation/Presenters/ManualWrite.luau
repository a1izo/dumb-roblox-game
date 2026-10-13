-- Diavolo's own shot of the name he has just written: the open Manual, alone in the dark, the name
-- inking itself in. Only the writer gets this cue (DeathNoteService), right after the name is sent,
-- and it is the same shot whether the name was right or wrong: a wrong name still fails silently. The
-- writing screen steps aside for it and comes back, unchanged. It keeps the phase's red grade (the
-- owner, 2026-10-12). The name goes in in the writer's writing style, if they have one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ManualTiming =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"):WaitForChild("ManualTiming"))

local Router = require(script.Parent.Parent.Parent.UI.Core.Router)
local BookStage = require(script.Parent.Parent.BookStage)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)

local SCREEN = "grimoire" -- the writing screen (UI/PrivateScreen)

return function(cue)
	local name = cue.data.name
	if type(name) ~= "string" or name == "" then
		return
	end
	Cinema.waitUntil(cue.at)
	local wasOpen = Router.isOpen(SCREEN)
	if wasOpen then
		Router.close(SCREEN, "cutscene")
	end
	local token = CameraDirector.take(ManualTiming.WRITE + 0.6)
	Cinema.letterbox(true)
	local writing = if type(cue.data.writing) == "string" then cue.data.writing else nil
	local stop = BookStage.play(token, { { text = name } }, ManualTiming.WRITE - 0.4, writing)
	task.wait(ManualTiming.WRITE)
	stop()
	Cinema.letterbox(false)
	CameraDirector.release(token)
	if wasOpen then
		Router.open(SCREEN)
	end
end
