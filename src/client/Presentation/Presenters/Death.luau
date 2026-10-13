-- A death at the table. A death by the Manual opens on the book, alone in the dark, the victim's real
-- name and the cause being written in it (everyone sees it, the victim too). Then quick cuts of two
-- others reacting (their reactions are picked from the cue, the same on every screen, never from
-- roles), then the victim's collapse in close-up while the heart monitor beats twice and flatlines,
-- and the cause is written across the screen. The victim sees their own screen drain of colour
-- instead. The name goes into the book in the writer's writing style on the writer's screen only (the
-- server sends it there alone); the victim's death style (ash, cut strings, crows, stone) plays on the
-- body after it falls, on every screen, under the cause of death.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ManualTiming =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"):WaitForChild("ManualTiming"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Mixer = require(script.Parent.Parent.Parent.Audio.Mixer)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local BookStage = require(script.Parent.Parent.BookStage)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local DeathFx = require(script.Parent.Parent.DeathFx)
local ShotSolver = require(script.Parent.Parent.ShotSolver)
local Styles = require(script.Parent.Parent.Styles)

local C = Kit.color
local LocalPlayer = Players.LocalPlayer

local SHOT = 3.8

-- Two living witnesses (not the victim), picked the same way on every screen.
local function witnesses(cue, victim: number): { Model }
	local list = {}
	for _, entry in ipairs(ClientState.public.players or {}) do
		if entry.alive and entry.userId ~= victim then
			local character = Cinema.character(entry.userId)
			if character then
				table.insert(list, { userId = entry.userId, character = character })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.userId < b.userId
	end)
	local rng = Random.new(tonumber(cue.id) or 1)
	local out = {}
	while #list > 0 and #out < 2 do
		table.insert(out, table.remove(list, rng:NextInteger(1, #list)).character)
	end
	return out
end

return function(cue)
	-- Players in the case and spectators watching it (the cues carry only public things).
	if not (ClientState.isParticipant() or ClientState.isWatching()) then
		return
	end
	local data = cue.data
	Cinema.waitUntil(cue.at)
	Mixer.duck("death", true)
	-- The name, written. (The server lets the body fall only when this shot is over.)
	local book = data.written == true and type(data.realName) == "string"
	local bookToken = 0
	if book then
		bookToken = CameraDirector.take(ManualTiming.BOOK + 0.8)
		Cinema.letterbox(true)
		local lines = { { text = data.realName }, { text = tostring(data.cause or ""), small = true } }
		local writing = if type(data.writing) == "string" then data.writing else nil
		local stop = BookStage.play(bookToken, lines, ManualTiming.BOOK, writing)
		task.wait(ManualTiming.BOOK)
		stop()
		-- (The cuts below take the camera over; the victim's own screen gets it back.)
		if data.userId == LocalPlayer.UserId then
			CameraDirector.release(bookToken)
			Cinema.letterbox(false)
		end
	end
	Sfx.play("heartbeat")
	task.delay(0.8, Sfx.play, "heartbeat")
	task.delay(1.9, Sfx.play, "flatline")
	local removeVignette = Cinema.vignette(C.red, 0.3)
	-- The body hits the floor in a burst of shards and leaves a chalk outline.
	task.delay(1.15, function()
		local body = Cinema.character(data.userId)
		local root = if body then body:FindFirstChild("Torso") or body:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			DeathFx.burst(root.Position, DeathFx.DARK, 40)
			DeathFx.chalk(root.Position, 7, DeathFx.CHALK, 14)
		end
		-- The victim's death style, once the body is down.
		if body and type(data.death) == "string" then
			task.delay(0.9, Styles.death, data.death, body)
		end
	end)

	if data.userId == LocalPlayer.UserId then
		DeathFx.screenTear(3.5)
		local untint = Cinema.tint({ Saturation = -1, Contrast = 0.15, Brightness = -0.05 }, 1.2)
		task.wait(5)
		untint()
	else
		local victim = Cinema.character(data.userId)
		if victim then
			local token = CameraDirector.take(SHOT + 0.6)
			Cinema.letterbox(true)
			local cleanup = {}
			-- The witnesses react (their bodies act on every screen through ActingController).
			for index, character in ipairs(witnesses(cue, data.userId)) do
				CameraDirector.cut(
					token,
					ShotSolver.frame(character, { distance = 5, height = 0.6, angle = if index == 1 then 25 else -25 }),
					45
				)
				task.wait(0.55)
			end
			-- The victim goes down.
			local wide = ShotSolver.frame(victim, { distance = 9, height = 2.5, angle = 20 })
			local close = ShotSolver.frame(victim, { distance = 5.5, height = 1.2, lookHeight = 0.5, angle = 10 })
			CameraDirector.cut(token, wide, 58)
			CameraDirector.move(token, close, SHOT - 1.1, 44)
			table.insert(cleanup, Cinema.outline(victim, C.red))
			table.insert(
				cleanup,
				Cinema.card({
					kicker = "Cause of death: " .. tostring(data.cause or ""),
					title = tostring(data.alias or ""),
					subtitle = "is dead.",
					color = C.danger,
					y = 0.74,
				})
			)
			task.wait(SHOT - 1.1)
			for index = #cleanup, 1, -1 do
				cleanup[index]()
			end
			Cinema.letterbox(false)
			CameraDirector.release(token)
		else
			task.wait(SHOT)
		end
		if book then
			Cinema.letterbox(false)
			CameraDirector.release(bookToken) -- (no body to cut to: nothing took the camera over)
		end
	end
	removeVignette()
	Mixer.duck("death", false)
end
