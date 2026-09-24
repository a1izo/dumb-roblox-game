-- "Case opening": the camera sweeps over the map in the rain, the case card types itself out,
-- and the Grimoire falls out of the sky where the players stand. Hold to skip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Parent.UI.Core.Settings)
local Theme = require(script.Parent.Parent.Parent.UI.Theme)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local InkFx = require(script.Parent.Parent.InkFx)

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Drops the book from high above onto `landing` over `seconds`, spinning as it falls.
local function dropBook(book: Model, landing: CFrame, seconds: number, onLand: () -> ())
	local start = landing * CFrame.new(0, 45, 0) * CFrame.Angles(math.rad(70), math.rad(160), math.rad(25))
	book:PivotTo(start)
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - began) / seconds, 0, 1)
		local eased = t * t
		book:PivotTo(start:Lerp(landing, eased))
		if t >= 1 then
			connection:Disconnect()
			onLand()
		end
	end)
end

return function(cue)
	if not ClientState.isParticipant() then
		return
	end
	local data = cue.data
	local duration = tonumber(data.duration) or 0
	local endAt = cue.at + duration
	Cinema.waitUntil(cue.at)
	local left = endAt - now()
	if left < 1.5 or type(data.path) ~= "table" or #data.path < 3 then
		return
	end
	local path = data.path :: { CFrame }
	local landmark = if typeof(data.landmark) == "Vector3" then data.landmark else path[3].Position

	local finished = false
	local cleanup: { () -> () } = {}
	local token = CameraDirector.take(left + 0.5)
	Cinema.letterbox(true)

	local function finish()
		if finished then
			return
		end
		finished = true
		for index = #cleanup, 1, -1 do
			cleanup[index]()
		end
		Cinema.letterbox(false)
		CameraDirector.release(token)
	end
	table.insert(cleanup, Cinema.skipButton(finish))

	CameraDirector.cut(token, path[1], 60)
	CameraDirector.move(token, path[2], left * 0.45, 55)

	task.delay(0.3, function()
		if finished then
			return
		end
		local mapName = if type(data.mapName) == "string" then data.mapName else ""
		local caseNumber = tonumber(data.caseNumber) or 0
		local count = tonumber(data.playerCount) or #ClientState.public.players
		table.insert(
			cleanup,
			Cinema.card({
				kicker = Terms.phase("Intro"),
				title = string.format("Case %04d  ·  %s", caseNumber, mapName),
				subtitle = Terms.f("{count} suspects. One of them is {hand}.", { count = count }),
				typewriter = true,
				y = 0.74,
			})
		)
	end)

	task.delay(left * 0.45, function()
		if finished then
			return
		end
		CameraDirector.move(token, path[3], left * 0.5, 50)
		local book = Models.grimoire()
		book.Parent = workspace.CurrentCamera
		table.insert(cleanup, function()
			book:Destroy()
		end)
		local landing = CFrame.new(landmark + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(20), 0)
		dropBook(book, landing, math.min(1, left * 0.15), function()
			if finished then
				return
			end
			Sfx.play("thunder")
			Cinema.flash(Theme.colors.paper, 0.5, 0.35)
			InkFx.burst(landing.Position + Vector3.new(0, 0.5, 0), InkFx.INK, 40)
			InkFx.splat(landing.Position, 9, InkFx.INK, 8)
			InkFx.sparks(landing.Position + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 60, 60))
			if Settings.get("cameraShake") then
				CameraDirector.shake(token, 0.6, 0.35)
			end
		end)
	end)

	task.wait(math.max(0, endAt - now() - 0.3))
	finish()
end
