-- The Specter's Eyes deal, seen only by the Cultist who took it: the screen floods red, a
-- whisper, and the terms of the deal. Nobody else gets this cue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local Theme = require(script.Parent.Parent.Parent.UI.Theme)
local Mixer = require(script.Parent.Parent.Parent.Audio.Mixer)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local Cinema = require(script.Parent.Parent.Cinema)

local C = Theme.colors

return function(cue)
	local data = cue.data
	Cinema.waitUntil(cue.at)
	Mixer.duck("eyes", true)
	Sfx.play("eyesOpen")
	Cinema.flash(C.accent, 0.75, 0.9)
	local untint = Cinema.tint({ TintColor = Color3.fromRGB(255, 150, 150), Saturation = -0.4, Contrast = 0.2 }, 0.3)
	local removeVignette = Cinema.vignette(C.accent, 0.4)
	local hide = Cinema.card({
		kicker = "The deal is struck",
		title = Terms.f("{EYES}"),
		subtitle = Terms.f(
			"Half your life for {reads} names. Your time runs out at the end of round {round}.",
			{ reads = tonumber(data.reads) or 0, round = tonumber(data.deathRound) or 0 }
		),
		color = C.ink,
		textColor = C.accent,
		y = 0.62,
	})
	task.wait(3.5)
	hide()
	untint()
	removeVignette()
	Mixer.duck("eyes", false)
end
