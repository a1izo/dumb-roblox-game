-- "Case opening": everyone's avatar is somewhere on the map doing something (the server's cast:
-- a coffee break, a file, a newspaper, a wall to lean on). The camera opens on the place, the
-- case card writes itself in, then it visits up to four of them, each named in handwriting,
-- and the Grimoire falls out of the sky into the middle of the map. Hold to skip.
--
-- Every shot comes from ShotSolver, so indoor maps are filmed from inside the rooms.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Parent.UI.Core.Settings)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local InkFx = require(script.Parent.Parent.InkFx)
local ShotSolver = require(script.Parent.Parent.ShotSolver)
local Stage = require(script.Parent.Parent.Stage)

local C = Kit.color

local function now(): number
	return workspace:GetServerTimeNow()
end

local function aliasOf(userId: number): string
	for _, entry in ipairs(ClientState.public.players or {}) do
		if entry.userId == userId then
			return tostring(entry.alias)
		end
	end
	return "?"
end

-- Drops the book from high above onto `landing` over `seconds`, spinning as it falls.
local function dropBook(book: Model, landing: CFrame, seconds: number, onLand: () -> ())
	local roof = ShotSolver.ceiling(landing.Position + Vector3.new(0, 1, 0), 60)
	local height = math.min(40, roof - landing.Position.Y - 1.5)
	local start = landing
		* CFrame.new(0, math.max(height, 6), 0)
		* CFrame.Angles(math.rad(70), math.rad(160), math.rad(25))
	book:PivotTo(start)
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - began) / seconds, 0, 1)
		book:PivotTo(start:Lerp(landing, t * t))
		if t >= 1 then
			connection:Disconnect()
			onLand()
		end
	end)
end

return function(cue)
	-- Players in the case and spectators watching it (the cues carry only public things).
	if not (ClientState.isParticipant() or ClientState.isWatching()) then
		return
	end
	local data = cue.data
	local duration = tonumber(data.duration) or 0
	local endAt = cue.at + duration
	Cinema.waitUntil(cue.at)
	local left = endAt - now()
	if left < 2 then
		return
	end
	local cast = if type(data.cast) == "table" then data.cast else {}
	local vignettes = if type(data.vignettes) == "table" then data.vignettes else {}
	local landmark = if typeof(data.landmark) == "Vector3" then data.landmark else nil

	local finished = false
	local cleanup: { () -> () } = {}
	local stage = Stage.new()
	table.insert(cleanup, function()
		stage:destroy()
	end)
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

	-- The cast takes its places.
	local actors: { [number]: Model } = {}
	for index, role in ipairs(cast) do
		if typeof(role.cf) == "CFrame" and type(role.userId) == "number" then
			if role.kind == "seat" then
				stage:chair(role.cf)
			end
			local actor = stage:cast(role.userId, role.cf, role.clip, role.props)
			if actor then
				actors[index] = actor
			end
		end
	end

	-- 1. The place, and the case card.
	local opening = landmark or (if cast[1] and typeof(cast[1].cf) == "CFrame" then cast[1].cf.Position else nil)
	local openingTime = math.min(2.4, left * 0.25)
	if opening then
		local from, to = ShotSolver.establish(opening, 9)
		CameraDirector.cut(token, from, 62)
		CameraDirector.move(token, to, openingTime, 56)
	end
	local mapName = if type(data.mapName) == "string" then data.mapName else ""
	local caseNumber = tonumber(data.caseNumber) or 0
	local count = tonumber(data.playerCount) or #ClientState.public.players
	local hideCard = Cinema.card({
		kicker = string.format("Case %04d", caseNumber),
		title = mapName,
		subtitle = Terms.f("{count} suspects. One of them is {hand}.", { count = count }),
		typewriter = true,
		y = 0.7,
	})
	table.insert(cleanup, hideCard)
	task.wait(openingTime)
	hideCard()
	if finished then
		return
	end

	-- 2. The vignettes.
	local bookTime = 1.6
	local vignetteTime = math.clamp((endAt - now() - bookTime) / math.max(#vignettes, 1), 0.9, 1.6)
	for number, index in ipairs(vignettes) do
		if finished or endAt - now() < bookTime + 0.5 then
			break
		end
		local role = cast[index]
		local actor = actors[index]
		if role and actor then
			local side = if number % 2 == 0 then 32 else -32
			local wide = ShotSolver.frame(actor, { distance = 8, height = 1.6, angle = side })
			local close = ShotSolver.frame(actor, { distance = 5, height = 0.8, angle = side * 0.6 })
			CameraDirector.cut(token, wide, 50)
			CameraDirector.move(token, close, vignetteTime, 42)
			local where = if type(role.area) == "string" and role.area ~= "" then role.area else ""
			local line = tostring(role.caption or "")
			if where ~= "" then
				line = line .. "  ·  " .. where
			end
			local hideCaption = Cinema.caption(aliasOf(role.userId), line)
			table.insert(cleanup, hideCaption)
			task.wait(vignetteTime)
			hideCaption()
		end
	end
	if finished then
		return
	end

	-- 3. The Grimoire falls.
	if landmark then
		local shot = ShotSolver.frame(landmark + Vector3.new(0, 0.5, 0), { distance = 11, height = 3.5 })
		CameraDirector.cut(token, shot, 55)
		local book = Models.grimoire()
		book.Parent = workspace.CurrentCamera
		table.insert(cleanup, function()
			book:Destroy()
		end)
		local landing = CFrame.new(landmark + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(20), 0)
		dropBook(book, landing, math.min(0.9, math.max(0.4, endAt - now() - 0.8)), function()
			if finished then
				return
			end
			Sfx.play("thunder")
			Cinema.flash(C.bone, 0.5, 0.35)
			InkFx.burst(landing.Position + Vector3.new(0, 0.5, 0), InkFx.INK, 40)
			InkFx.splat(landing.Position, 9, InkFx.INK, 8)
			InkFx.sparks(landing.Position + Vector3.new(0, 0.6, 0), C.red)
			if Settings.get("cameraShake") then
				CameraDirector.shake(token, 0.6, 0.35)
			end
		end)
	end

	task.wait(math.max(0, endAt - now() - 0.3))
	finish()
end
