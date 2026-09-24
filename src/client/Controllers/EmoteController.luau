-- Plays emotes on the local character. Animations played by the owner replicate to
-- everyone. The emote stops when the character starts moving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local LocalPlayer = Players.LocalPlayer

local EmoteController = {}

local currentTrack: AnimationTrack? = nil
local moveConnection: RBXScriptConnection? = nil

local function stop()
	if currentTrack then
		currentTrack:Stop(0.2)
		currentTrack = nil
	end
	if moveConnection then
		moveConnection:Disconnect()
		moveConnection = nil
	end
end

function EmoteController.play(emoteId: string)
	local character = LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not character or not humanoid or not animator then
		return
	end
	local emote = nil
	for _, candidate in ipairs(QuickChat.EMOTES) do
		if candidate.id == emoteId then
			emote = candidate
		end
	end
	if not emote then
		return
	end
	stop()

	-- Prefer the animation from the character's own Animate script.
	local animation: Animation? = nil
	local animate = character:FindFirstChild("Animate")
	local folder = if animate then animate:FindFirstChild(emote.id) else nil
	if folder then
		animation = folder:FindFirstChildOfClass("Animation")
	end
	if not animation then
		local fallback = Instance.new("Animation")
		fallback.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15 then emote.r15 else emote.r6
		animation = fallback
	end
	if not animation then
		return
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = emote.id == "dance"
	track:Play(0.2)
	currentTrack = track
	moveConnection = humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			stop()
		end
	end)
end

function EmoteController.init()
	LocalPlayer.CharacterAdded:Connect(function()
		stop()
	end)
end

return EmoteController
