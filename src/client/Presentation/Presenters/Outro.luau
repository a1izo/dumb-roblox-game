-- The ending. Everyone still standing is gathered at the table; the camera circles it, the
-- winning side is called, and then the lights find the Hand. Winners and losers each hear
-- their own music. The roster and rewards follow on the results screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.Parent.UI.Theme)
local MusicController = require(script.Parent.Parent.Parent.Audio.MusicController)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)

local C = Theme.colors
local LocalPlayer = Players.LocalPlayer

-- Circles the camera around `center` for `seconds`, starting at `fromAngle` (radians).
local function orbit(token: number, center: Vector3, seconds: number, fromAngle: number): () -> ()
	local began = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - began) / seconds, 0, 1)
		local angle = fromAngle + t * math.rad(70)
		local radius = 26 - t * 6
		local eye = center + Vector3.new(math.cos(angle) * radius, 13 - t * 3, math.sin(angle) * radius)
		CameraDirector.cut(token, CFrame.lookAt(eye, center + Vector3.new(0, 2, 0)))
	end)
	return function()
		connection:Disconnect()
	end
end

return function(cue)
	local data = cue.data
	local handWon = data.winner ~= "Team"
	local participant = ClientState.isParticipant()
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
	if not participant or left < 2 then
		return
	end

	local cleanup: { () -> () } = {}
	local token = CameraDirector.take(left + 0.5)
	Cinema.letterbox(true)
	Sfx.play("bell")

	local center = if typeof(data.center) == "Vector3" then data.center else nil
	local firstShot = left * 0.5
	local stopOrbit = if center then orbit(token, center, firstShot, math.rad(200)) else nil
	if stopOrbit then
		table.insert(cleanup, stopOrbit)
	end
	local winnerName = if handWon then Terms.role("Kira", "Name") else Terms.side("Team", "Name")
	local hideTitle = Cinema.card({
		kicker = if participant then (if won then "Victory" else "Defeat") else Terms.phase("Outro"),
		title = Terms.f("{name} wins", { name = winnerName }),
		subtitle = if type(data.reason) == "string" then data.reason else nil,
		color = if handWon then C.accent else C.team,
		y = 0.74,
	})
	table.insert(cleanup, hideTitle)
	if handWon then
		table.insert(cleanup, Cinema.tint({ TintColor = Color3.fromRGB(255, 190, 190), Saturation = -0.3 }, 1.5))
	end

	task.wait(firstShot)
	hideTitle()
	if stopOrbit then
		stopOrbit()
	end

	-- The Hand, under the lights.
	local hand = Cinema.character(tonumber(data.handUserId))
	if hand then
		Sfx.play("gavel")
		table.insert(cleanup, Cinema.spotlight(hand, if handWon then C.accent else Color3.new(1, 1, 1)))
		table.insert(cleanup, Cinema.outline(hand, C.accent))
		CameraDirector.cut(token, Cinema.faceShot(hand, 9, 2, 3), 55)
		CameraDirector.move(token, Cinema.faceShot(hand, 5, 0.8, 1), left * 0.45, 40)
	end
	if type(data.handAlias) == "string" then
		table.insert(
			cleanup,
			Cinema.card({
				kicker = Terms.f("{Hand} was"),
				title = data.handAlias,
				subtitle = if type(data.handRealName) == "string" then "Real name: " .. data.handRealName else nil,
				color = C.ink,
				textColor = C.accent,
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
