-- The showpiece camera: while this player's own emote of the top tiers plays (Sealed and up: Shared/Rarity),
-- or a duo, in the lobby, the camera leaves the shoulder and makes the emote's own single move round them (Anim/
-- EmoteMeta `camera`, the owner's Q22: a push in, a low hero angle, a high one, over the shoulder, a side track, an
-- orbit either way, or a still frame), easing round to where the move begins and arriving where it ends on the
-- emote's beat; no cuts. MAX seconds at most (a looping dance keeps going; the camera comes back). Nobody else's
-- camera moves. It comes back gliding when the emote ends, and at once when the player moves off; CameraDirector
-- gives it back whatever happens (a death, a respawn, its watchdog). Off with Settings "emoteCamera" and under
-- Reduce motion; never in a case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmoteMeta = require(Shared:WaitForChild("Anim"):WaitForChild("EmoteMeta"))
local Rarity = require(Shared:WaitForChild("Rarity"))

local CameraDirector = require(script.Parent.CameraDirector)
local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local EmoteCamera = {}

local MAX = 8 -- seconds the camera stays out
local IN = 0.9 -- seconds to ease round to the first view
local BACK = 0.45 -- seconds to glide back

-- A view of the body: `az` degrees round it from its front (0 in front, looking back at it; 180 behind), the eye
-- `up` studs above its middle and `dist` away, `side` studs to the body's right, looking at its middle raised by
-- `aim` (or, with `ahead`, at the point that far in front of it: over the shoulder at what it faces).
type View = { az: number, up: number, dist: number, side: number?, aim: number?, ahead: number? }
-- Each move: where it begins, where it ends, and how it gets there.
local MOVES: { [string]: { from: View, to: View, style: Enum.EasingStyle } } = {
	push = {
		from = { az = 18, up = 1.4, dist = 12 },
		to = { az = 10, up = 0.9, dist = 6.5 },
		style = Enum.EasingStyle.Quad,
	},
	hero = {
		from = { az = 30, up = -0.6, dist = 9, aim = 0.8 },
		to = { az = 14, up = -1.3, dist = 7, aim = 1.4 },
		style = Enum.EasingStyle.Sine,
	},
	high = {
		from = { az = 24, up = 6, dist = 8 },
		to = { az = 4, up = 7.5, dist = 6.5 },
		style = Enum.EasingStyle.Sine,
	},
	shoulder = {
		from = { az = 205, up = 2.0, dist = 6, side = 1.7, ahead = 6 },
		to = { az = 192, up = 1.7, dist = 4.8, side = 1.4, ahead = 6 },
		style = Enum.EasingStyle.Sine,
	},
	track = {
		from = { az = 104, up = 1.2, dist = 9 },
		to = { az = 62, up = 1.2, dist = 9 },
		style = Enum.EasingStyle.Sine,
	},
	orbitLeft = {
		from = { az = 28, up = 1.4, dist = 10 },
		to = { az = -24, up = 1.4, dist = 10 },
		style = Enum.EasingStyle.Sine,
	},
	orbitRight = {
		from = { az = -28, up = 1.4, dist = 10 },
		to = { az = 18, up = 1.4, dist = 10 },
		style = Enum.EasingStyle.Sine,
	},
	hold = {
		from = { az = 16, up = 1.3, dist = 9.5 },
		to = { az = 16, up = 1.3, dist = 9.5 },
		style = Enum.EasingStyle.Sine,
	},
}
local DEFAULT = "orbitRight"

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

-- Takes the camera for one emote (`clip`, `seconds` long). Returns a function that gives it back (gliding back,
-- unless `atOnce`).
function EmoteCamera.start(character: Model, seconds: number, clip: string?): (atOnce: boolean?) -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not camera then
		return nothing
	end
	local hold = math.min(seconds, MAX)
	local token = CameraDirector.take(hold + BACK + 1)
	local home = camera.CFrame
	local meta = if clip then (EmoteMeta :: any)[clip] else nil
	local spec = if meta and type(meta.camera) == "table" then meta.camera else nil
	local move = MOVES[if spec and MOVES[spec.move] then spec.move else DEFAULT]
	-- (the body's place and facing as the emote begins: the camera moves round that, not after the body)
	local pivot = root.Position + Vector3.new(0, 0.5, 0)
	local facing = root.CFrame - root.Position
	local function view(v: View): CFrame
		local look = (facing * CFrame.Angles(0, math.rad(v.az), 0)).LookVector
		local right = facing.RightVector
		local eye = pivot + look * v.dist + Vector3.new(0, v.up, 0) + right * (v.side or 0)
		local target = if v.ahead
			then pivot + facing.LookVector * v.ahead + Vector3.new(0, 0.6, 0)
			else pivot + Vector3.new(0, v.aim or 0, 0)
		return CFrame.lookAt(eye, target)
	end
	-- arriving where the move ends on the emote's beat (`at` s in), or as the time out ends
	local arrive = if spec and type(spec.at) == "number" then math.clamp(spec.at, IN + 0.3, hold) else hold
	CameraDirector.move(token, view(move.from), IN, nil, Enum.EasingStyle.Quint)
	local done = false
	task.delay(IN, function()
		if not done then
			CameraDirector.move(token, view(move.to), math.max(0.1, arrive - IN), nil, move.style)
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
