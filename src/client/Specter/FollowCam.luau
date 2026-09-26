-- Following a living player's view: Specters and spectators can point their camera at a
-- living player and step through them.
-- While following, a Specter's own ghost waits where it is (see GhostController). The
-- Specter HUD draws the controls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local ClientState = require(script.Parent.Parent.ClientState)
local Characters = require(script.Parent.Parent.Characters)

local SpectateRemote = Net.event("Spectate")
local LocalPlayer = Players.LocalPlayer

local FollowCam = {}

-- Fired as (following, alias?) when following starts, stops or moves to someone else.
FollowCam.Changed = Signal.new()

local following = false
local targetUserId: number? = nil
local targetAlias: string? = nil

local function ownHumanoid(): Humanoid?
	local character = LocalPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function resetCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraSubject = ownHumanoid()
	end
end

local function targets()
	local list = {}
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			table.insert(list, entry)
		end
	end
	return list
end

-- Points the camera at the current target (or the first living player).
local function focus()
	local list = targets()
	if #list == 0 then
		targetUserId, targetAlias = nil, nil
		resetCamera()
		FollowCam.Changed:Fire(following, nil)
		return
	end
	local index = 1
	for i, entry in ipairs(list) do
		if entry.userId == targetUserId then
			index = i
		end
	end
	local entry = list[index]
	targetUserId = entry.userId
	targetAlias = entry.alias
	SpectateRemote:FireServer(entry.userId)
	local character = Characters.byUserId(entry.userId)
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local camera = workspace.CurrentCamera
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
	FollowCam.Changed:Fire(following, targetAlias)
end

-- True when this player may follow someone right now.
function FollowCam.canFollow(): boolean
	return ClientState.isSpecter() or ClientState.isWatching()
end

function FollowCam.isFollowing(): boolean
	return following
end

function FollowCam.alias(): string?
	return targetAlias
end

function FollowCam.start()
	if following or not FollowCam.canFollow() then
		return
	end
	following = true
	focus()
end

function FollowCam.stop()
	if not following then
		return
	end
	following = false
	targetUserId, targetAlias = nil, nil
	SpectateRemote:FireServer(nil)
	resetCamera()
	FollowCam.Changed:Fire(false, nil)
end

function FollowCam.toggle()
	if following then
		FollowCam.stop()
	else
		FollowCam.start()
	end
end

-- The next (1) or previous (-1) living player.
function FollowCam.step(direction: number)
	if not following then
		FollowCam.start()
		return
	end
	local list = targets()
	if #list == 0 then
		return
	end
	local index = 0
	for i, entry in ipairs(list) do
		if entry.userId == targetUserId then
			index = i
		end
	end
	index = ((index - 1 + direction) % #list) + 1
	targetUserId = list[index].userId
	focus()
end

function FollowCam.init()
	local function refresh()
		if not FollowCam.canFollow() then
			FollowCam.stop()
		elseif following then
			-- The target may have died: move on to someone still alive.
			focus()
		end
	end
	ClientState.PublicChanged:Connect(refresh)
	ClientState.WatchChanged:Connect(refresh)
	LocalPlayer.CharacterAdded:Connect(function()
		if not following then
			task.defer(resetCamera)
		end
	end)
end

return FollowCam
