--!strict
-- Whether the camera is far away from this player's own place in the world: a cutscene on a set of its own far off
-- (the scene deaths at SceneDeaths.ORIGIN, the win rooms, the Manual's stage, the shop's previews from the lobby).
-- The map's own life round the body (the street crowd, the rain) is out of sight then, and stops its work until
-- the camera comes back (2026-11-15, the user: "fix the lag esp during cutscenes").

local Players = game:GetService("Players")

local Away = {}

-- Studs between the camera and the body (or, with no body, the camera and the map's middle) past which it is away.
Away.FAR = 900

local mapAt: Vector3? = nil

-- The map's middle, for when there is no body to measure from (Venues.MAP; set by the caller that knows it).
function Away.setMap(at: Vector3)
	mapAt = at
end

function Away.now(): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local eye = camera.CFrame.Position
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (eye - root.Position).Magnitude > Away.FAR
	end
	return mapAt ~= nil and (eye - mapAt).Magnitude > Away.FAR * 2
end

return Away
