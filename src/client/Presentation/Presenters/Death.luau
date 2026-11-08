-- A death at the table. A death by the Manual opens on the book, alone in the dark, the victim's real
-- name and the cause being written in it (everyone sees it, the victim too). Then the victim, from the moment the
-- body goes (cause and effect: the cut lands on the death's first beat), the camera pushing in on where the body will
-- lie as it falls (Shared/Anim/DeathTiming says when it hits the floor; the clip says where); quick cuts of two others
-- reacting once it is down (their reactions are picked from the cue, the same on every screen, never from roles); and
-- back to the body, from above, while the heart monitor flatlines and the cause is written across the screen. The
-- victim sees their own screen drain of colour instead. The name goes into the book in the writer's writing style on
-- the writer's screen only (the server sends it there alone); a custom death's effect (Presentation/CustomDeaths) plays
-- on the body as it goes, timed to its acting; the victim's death style (Presentation/Fallen: ash, cut strings, crows,
-- stone, glass) takes the body once it lies still, on every screen, and the last shot stays on it until it is done.
-- A scene death (Presentation/SceneDeaths: requiem, Blackwall, the god, Iron Man, Sam, Walrider, sans, the patriot's
-- grave, dead by selection) plays its own full cutscene instead, then shows the body.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Causes = require(Shared:WaitForChild("Anim"):WaitForChild("Causes"))
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local DeathLines = require(Shared:WaitForChild("Presentation"):WaitForChild("DeathLines"))
local ManualTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("ManualTiming"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Mixer = require(script.Parent.Parent.Parent.Audio.Mixer)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local BookStage = require(script.Parent.Parent.BookStage)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local CustomDeaths = require(script.Parent.Parent.CustomDeaths)
local Cinema = require(script.Parent.Parent.Cinema)
local DeathFx = require(script.Parent.Parent.DeathFx)
local Fallen = require(script.Parent.Parent.Fallen)
local ShotSolver = require(script.Parent.Parent.ShotSolver)
local StageLight = require(script.Parent.Parent.StageLight)
local Styles = require(script.Parent.Parent.Styles)
local SceneDeaths = require(script.Parent.Parent.SceneDeaths)

local C = Kit.color
local LocalPlayer = Players.LocalPlayer

local WITNESS = 0.55 -- seconds on each witness

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

-- Where the body's middle is `t` seconds into its clip (the clip's own offset from where it stood).
local function bodyAt(mark: CFrame, clip: string, t: number): Vector3
	local prepared = ClipPlayer.get(clip)
	local offset = if prepared then ClipPlayer.sampleOffset(prepared, t) else nil
	return mark:PointToWorldSpace(offset or Vector3.zero)
end

-- A camera at `distance` from `target`, `height` over it, `angle` degrees round from `facing` (0: in front), or the
-- nearest angle round it with nothing in the way.
local function frameAt(target: Vector3, facing: Vector3, distance: number, height: number, angle: number): CFrame
	local flat = Vector3.new(facing.X, 0, facing.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	for _, scale in ipairs({ 1, 0.8, 0.6 }) do
		for _, delta in ipairs({ 0, 25, -25, 50, -50, 90, -90, 140, -140, 180 }) do
			local dir = CFrame.Angles(0, math.rad(angle + delta), 0):VectorToWorldSpace(flat)
			local eye = target + dir * distance * scale + Vector3.new(0, height * scale, 0)
			if ShotSolver.clear(target, eye) then
				return CFrame.lookAt(eye, target)
			end
		end
	end
	return CFrame.lookAt(target + flat * 2 + Vector3.new(0, 1, 0), target)
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
		-- (one sentence: the name and how they died, the words scattered as a hand writes: Shared/Presentation/DeathLines)
		local lines = { { text = DeathLines.sentence(data.realName, tostring(data.cause or "")), scatter = true } }
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
	-- A scene death (Presentation/SceneDeaths): everyone watches its cutscene from the moment the book closes, then the
	-- body where it lies, from above, under the cause of death.
	local scene = Causes.scene(tostring(data.cause or ""))
	if scene and SceneDeaths.has(scene) then
		if book then
			CameraDirector.release(bookToken)
		end
		local fell = cue.at + (if book then ManualTiming.BOOK else 0)
		local named = if scene == "patriot"
				and type(data.realName) == "string"
				and data.realName ~= ""
			then data.realName
			else tostring(data.alias or "")
		SceneDeaths.play(scene, {
			victim = data.userId,
			saluter = if type(data.saluter) == "number" then data.saluter else nil,
			named = named,
			at = fell,
			wait = true,
		})
		local body = Fallen.bodyOf(data.userId)
		local mark = if body then body:FindFirstChild("Torso") or body:FindFirstChild("HumanoidRootPart") else nil
		if mark and mark:IsA("BasePart") then
			local token = CameraDirector.take(ManualTiming.SCENE_AFTER + 1)
			Cinema.letterbox(true)
			local at = mark.Position
			CameraDirector.cut(token, CFrame.lookAt(at + Vector3.new(3, 6, 3), at), 46)
			CameraDirector.move(token, CFrame.lookAt(at + Vector3.new(2.2, 4.4, 2.2), at), ManualTiming.SCENE_AFTER, 42)
			local closeCard = Cinema.card({
				kicker = "Cause of death: " .. tostring(data.cause or ""),
				title = tostring(data.alias or ""),
				subtitle = "is dead.",
				color = C.danger,
				y = 0.74,
			})
			Sfx.play("flatline")
			task.wait(ManualTiming.SCENE_AFTER)
			closeCard()
			Cinema.letterbox(false)
			CameraDirector.release(token)
		end
		Mixer.duck("death", false)
		return
	end
	local clip = Causes.clipFor(tostring(data.cause or ""))
	local timing = Causes.timing(clip)
	local style = if type(data.death) == "string" then data.death else nil
	local acted = style ~= nil and Fallen.has(style)
	local styleAt = timing.length + ManualTiming.STYLE_AFTER
	local total = if acted then styleAt + Causes.fallenLength(style) + 0.4 else timing.length + 1.6
	Sfx.play("heartbeat")
	task.delay(0.8, Sfx.play, "heartbeat")
	task.delay(timing.hit + 0.35, Sfx.play, "flatline")
	local removeVignette = Cinema.vignette(C.red, 0.3)
	-- A custom death written as the cause (Presentation/CustomDeaths): its effect starts on its beat, its impact on the
	-- moment the body hits the floor.
	if type(data.reason) == "string" then
		local fx = timing.fx or 0.9
		task.delay(fx, function()
			CustomDeaths.play(data.reason, Fallen.bodyOf(data.userId), { hit = timing.hit - fx })
		end)
	end
	-- The body hits the floor in a burst of shards and leaves a chalk outline.
	task.delay(timing.hit, function()
		local body = Fallen.bodyOf(data.userId)
		local root = if body then body:FindFirstChild("Torso") or body:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			DeathFx.burst(root.Position, DeathFx.DARK, 40)
			DeathFx.chalk(root.Position, 7, DeathFx.CHALK, 14)
		end
		-- (a death style with no acting of its own plays on the body as it lies)
		if body and style and not acted then
			task.delay(timing.length - timing.hit + 0.3, Styles.death, style, body)
		end
	end)

	if data.userId == LocalPlayer.UserId then
		DeathFx.screenTear(3.5)
		local untint = Cinema.tint({ Saturation = -1, Contrast = 0.15, Brightness = -0.05 }, 1.2)
		task.wait(math.max(5, total))
		untint()
	else
		-- (the copy that stands in for a body with a death style is made on this same beat: ActingController)
		local victim = if acted then Fallen.waitFor(data.userId, 0.4) else Fallen.bodyOf(data.userId)
		local mark = if victim then victim:FindFirstChild("HumanoidRootPart") else nil
		if victim and mark and mark:IsA("BasePart") then
			local token = CameraDirector.take(total + 1)
			Cinema.letterbox(true)
			local cleanup = {}
			local start = mark.CFrame
			local facing = start.LookVector
			-- The victim, from the first beat: wide from the front, pushing in, tilting as it comes (a Dutch angle: the
			-- world is wrong now), on where the body lands; a hard red light finds them as the room's lamps sink.
			local standing = start.Position + Vector3.new(0, 1.2, 0)
			local lying = bodyAt(start, clip, timing.still)
			local wide = frameAt(standing:Lerp(lying, 0.35), facing, 10.5, 2.6, 20)
			local close = frameAt(lying + Vector3.new(0, 0.4, 0), facing, 6, 2.2, 14)
				* CFrame.Angles(0, 0, math.rad(-7))
			CameraDirector.cut(token, wide, 58)
			CameraDirector.move(token, close, timing.hit + 0.45, 44)
			table.insert(cleanup, Cinema.outline(victim, C.red))
			table.insert(cleanup, StageLight.rim(victim, wide.Position, Color3.fromRGB(255, 52, 60), total))
			task.delay(0.6, function()
				table.insert(cleanup, StageLight.dip(start.Position, 40, 0.35, total))
			end)
			task.delay(timing.hit, function()
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
			end)
			task.wait(timing.hit + 0.5)
			-- The witnesses react (their bodies act on every screen through ActingController).
			for index, character in ipairs(witnesses(cue, data.userId)) do
				CameraDirector.cut(
					token,
					ShotSolver.frame(character, { distance = 5, height = 0.6, angle = if index == 1 then 25 else -25 }),
					45
				)
				task.wait(WITNESS)
			end
			-- Back on the body, from above, the camera sinking slowly towards it (through its death style).
			local left = math.max(0.8, total - (timing.hit + 0.5 + WITNESS * 2))
			local over = frameAt(lying, facing, 5.5, 5.2, 35)
			local nearer = frameAt(lying, facing, 4.4, 3.6, 30)
			CameraDirector.cut(token, over, 46)
			CameraDirector.move(token, nearer, left, 42)
			task.wait(left)
			for index = #cleanup, 1, -1 do
				cleanup[index]()
			end
			Cinema.letterbox(false)
			CameraDirector.release(token)
		else
			task.wait(total)
		end
		if book then
			Cinema.letterbox(false)
			CameraDirector.release(bookToken) -- (no body to cut to: nothing took the camera over)
		end
	end
	removeVignette()
	Mixer.duck("death", false)
end
