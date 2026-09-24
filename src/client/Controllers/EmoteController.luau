-- Emotes. The player asks the server, which checks the emote (and the Emote Pack pass) and
-- tells every client that may see it; each client then plays the Blender clip on that
-- character. Moving stops the emote (LocomotionController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Net = require(Shared:WaitForChild("Net"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)

local EmoteRemote = Net.event("Emote")

local EmoteController = {}

-- How long a one-shot emote holds its last pose before easing back.
local HOLD = 0.6

function EmoteController.play(emoteId: string)
	EmoteRemote:FireServer(emoteId)
end

local function onEmote(payload)
	if type(payload) ~= "table" or type(payload.emote) ~= "string" or type(payload.userId) ~= "number" then
		return
	end
	local player = Players:GetPlayerByUserId(payload.userId)
	local character = if player then player.Character else nil
	local clip = ClipPlayer.get(payload.emote)
	if not character or not clip then
		return
	end
	PoseController.play(character, payload.emote, {
		emote = true,
		fadeIn = 0.15,
		fadeOut = 0.3,
		duration = if clip.loop then nil else clip.length + HOLD,
	})
end

function EmoteController.init()
	EmoteRemote.OnClientEvent:Connect(onEmote)
end

return EmoteController
