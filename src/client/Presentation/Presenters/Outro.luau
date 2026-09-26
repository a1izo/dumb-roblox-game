-- The ending. Everyone still standing is gathered round the table, each celebrating or
-- despairing in their own way (ActingController). The camera stands in the middle of the table,
-- under the ceiling, and turns slowly across their faces while the winning side is written in;
-- then the lights find the Hand. Winners and losers each hear their own music; the roster and
-- rewards follow on the results screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local MusicController = require(script.Parent.Parent.Parent.Audio.MusicController)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local ShotSolver = require(script.Parent.Parent.ShotSolver)

local C = Kit.color
local LocalPlayer = Players.LocalPlayer

-- Turns the camera from the middle of the table across the faces around it. Returns a stopper.
local function sweep(token: number, center: Vector3, seconds: number): () -> ()
	local roof = ShotSolver.ceiling(center + Vector3.new(0, 1, 0), 40)
	local eye = center + Vector3.new(0, math.min(5.2, roof - center.Y - 1.2), 0)
	local began = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - began) / seconds, 0, 1)
		local eased = t * t * (3 - 2 * t)
		local yaw = math.rad(-60 + eased * 150)
		local look = eye + Vector3.new(math.cos(yaw), -0.12, math.sin(yaw))
		CameraDirector.cut(token, CFrame.lookAt(eye, look), 70 - eased * 12)
	end)
	return function()
		connection:Disconnect()
	end
end

return function(cue)
	local data = cue.data
	local handWon = data.winner ~= "Team"
	local participant = ClientState.isParticipant()
	local watching = ClientState.isWatching()
	local won = false
	if participant and type(data.winners) == "table" then
		won = table.find(data.winners, LocalPlayer.UserId) ~= nil
	end
	local winSlot = if handWon then "winHand" else "winAgency"
	MusicController.setOutcome(if not participant or won then winSlot else "defeat")

	local duration = tonumber(data.duration) or 0
	local endAt = cue.at + duration
	Cinema.waitUntil(cue.at)
	local left = endAt - workspace:GetServerTimeNow()
	if not (participant or watching) or left < 2 then
		return
	end

	local cleanup: { () -> () } = {}
	local token = CameraDirector.take(left + 0.5)
	Cinema.letterbox(true)
	Sfx.play("bell")

	local center = if typeof(data.center) == "Vector3" then data.center else nil
	local firstShot = left * 0.5
	if center then
		table.insert(cleanup, sweep(token, center, firstShot))
	end
	local winnerName = if handWon then Terms.role("Kira", "Name") else Terms.side("Team", "Name")
	local hideTitle = Cinema.card({
		kicker = if participant then (if won then "Victory" else "Defeat") else Terms.phase("Outro"),
		title = Terms.f("{name} wins", { name = winnerName }),
		subtitle = if type(data.reason) == "string" then data.reason else nil,
		color = if handWon then C.blood else C.steel:Lerp(C.void, 0.4),
		typewriter = true,
		y = 0.74,
	})
	table.insert(cleanup, hideTitle)
	-- A world written by the Hand is washed in red until the end.
	local untint = if handWon
		then Cinema.tint({ TintColor = Color3.fromRGB(255, 190, 190), Saturation = -0.3 }, 1.5)
		else nil

	task.wait(firstShot)
	for index = #cleanup, 1, -1 do
		cleanup[index]()
	end
	cleanup = {}
	if untint then
		table.insert(cleanup, untint)
	end

	-- The Hand, under the lights.
	local hand = Cinema.character(tonumber(data.handUserId))
	if hand then
		Sfx.play("gavel")
		table.insert(cleanup, Cinema.spotlight(hand, if handWon then C.red else Color3.new(1, 1, 1)))
		table.insert(cleanup, Cinema.outline(hand, C.red))
		CameraDirector.cut(token, ShotSolver.frame(hand, { distance = 9, height = 2, angle = 20 }), 55)
		CameraDirector.move(token, ShotSolver.frame(hand, { distance = 5, height = 0.8, angle = 8 }), left * 0.45, 40)
	end
	if type(data.handAlias) == "string" then
		table.insert(
			cleanup,
			Cinema.card({
				kicker = Terms.f("{Hand} was"),
				title = data.handAlias,
				subtitle = if type(data.handRealName) == "string" then "Real name: " .. data.handRealName else nil,
				color = C.void,
				textColor = C.red,
				y = 0.74,
			})
		)
	end

	task.wait(math.max(0, endAt - workspace:GetServerTimeNow() - 0.3))
	for index = #cleanup, 1, -1 do
		cleanup[index]()
	end
	Cinema.letterbox(false)
	CameraDirector.release(token)
end
