-- The showpiece camera: while this player's own emote of the top tiers plays (Sealed and up: Shared/Rarity),
-- or a duo, in the lobby, the camera leaves the shoulder, eases round to a three-quarter view in front and turns
-- slowly round them, for MAX seconds at most (a looping dance keeps going; the camera comes back). Nobody else's
-- camera moves. It comes back gliding when the emote ends, and at once when the player moves off; CameraDirector
-- gives it back whatever happens (a death, a respawn, its watchdog). Off with Settings "emoteCamera" and under
-- Reduce motion; never in a case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local Rarity = require(Shared:WaitForChild("Rarity"))

local CameraDirector = require(script.Parent.CameraDirector)
local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local EmoteCamera = {}

local MAX = 8 -- seconds the camera stays out
local IN = 0.9 -- seconds to ease round to the first view
local BACK = 0.45 -- seconds to glide back
local DISTANCE = 10 -- studs from the body
local FROM, TO = -28, 18 -- degrees round the body, from its front: where the turn starts and ends

local function nothing() end

-- Whether an emote is a showpiece here, now, for this player.
function EmoteCamera.wants(clip: string): boolean
	if ClientState.isParticipant() or ClientState.isWatching() then
		return false
	end
	if Settings.get("emoteCamera") == false or Motion.isReduced() or CameraDirector.busy() then
		return false
	end
	local info = EmoteInfo.of(clip)
	if info.stroll or info.stance then
		return false
	end
	return info.duo or clip == "matchPointReturn" or Rarity.rank(info.rarity) >= 3
end

-- Takes the camera for one emote of `seconds`. Returns a function that gives it back (gliding back, unless
-- `atOnce`).
function EmoteCamera.start(character: Model, seconds: number): (atOnce: boolean?) -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not camera then
		return nothing
	end
	local hold = math.min(seconds, MAX)
	local token = CameraDirector.take(hold + BACK + 1)
	local home = camera.CFrame
	-- (the body's place and facing as the emote begins: the camera turns round that, not after the body)
	local pivot = root.Position + Vector3.new(0, 0.5, 0)
	local facing = root.CFrame - root.Position
	local function view(degrees: number): CFrame
		local look = (facing * CFrame.Angles(0, math.rad(degrees), 0)).LookVector
		local eye = pivot + look * DISTANCE + Vector3.new(0, 1.4, 0)
		return CFrame.lookAt(eye, pivot)
	end
	CameraDirector.move(token, view(FROM), IN, nil, Enum.EasingStyle.Quint)
	local done = false
	task.delay(IN, function()
		if not done then
			CameraDirector.move(token, view(TO), math.max(0.1, hold - IN), nil, Enum.EasingStyle.Sine)
		end
	end)
	local function finish(atOnce: boolean?)
		if done then
			return
		end
		done = true
		if atOnce then
			CameraDirector.release(token)
			return
		end
		CameraDirector.move(token, home, BACK, nil, Enum.EasingStyle.Quint)
		task.delay(BACK, function()
			CameraDirector.release(token)
		end)
	end
	task.delay(hold, function()
		finish(false)
	end)
	return finish
end

return EmoteCamera
