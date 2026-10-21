-- The private cutscenes of the Godhood emotes (New World, Final Breakdown, Reaper's Eyes, Just As Planned): while
-- this player's own one plays, in the lobby, their camera goes through the emote's shot list (Shared/Anim/EmoteMeta
-- `cinema`), timed to the clip, with letterbox bars, a colour grade, a vignette and the list's beats (flashes,
-- impact frames, a shake). Only this screen: everyone else sees the emote and its world effects (Controllers/
-- EmoteFx). Off with Settings "emoteCutscenes" (the showpiece camera, Presentation/EmoteCamera, then turns round
-- them instead) and under Reduce motion (no camera moves at all); never in a case. Every shot's eye is checked
-- against the walls first (Presentation/ShotSolver): pulled in towards what it looks at, or mirrored to the other
-- side, or left out.
--
-- The camera and every screen effect come back whatever happens: the emote ending (gliding back), the player
-- moving off, another emote, a death, a respawn, the body going, a case starting (at once), a step that errors
-- (each runs under pcall), and two watchdogs (CameraDirector's, and this one's for the screen effects).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmoteMeta = require(Shared:WaitForChild("Anim"):WaitForChild("EmoteMeta"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))

local CameraDirector = require(script.Parent.CameraDirector)
local Cinema = require(script.Parent.Cinema)
local ShotSolver = require(script.Parent.ShotSolver)
local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local EmoteCinema = {}

local BACK = 0.6 -- seconds to glide back to the player's own camera at the end
local HOLD = 1 -- seconds the emote may run past its clip (EmoteController's hold, and some to spare)
local LATE = 2 -- the watchdog: this long after that, everything is put back no matter what
local PULL = { 1, 0.8, 0.6, 0.45 } -- how far out an eye may stay when a wall is in the way (of the shot's distance)

type Vec = { number }
type Framing = { eye: Vec?, look: Vec?, fov: number? }
type Shot = {
	at: number,
	eye: Vec,
	look: Vec,
	fov: number,
	glide: number?,
	to: Framing?,
	focus: number?,
}
type Beat = { at: number, kind: string, color: Vec?, strength: number?, seconds: number? }
export type Cut = {
	grade: { saturation: number?, contrast: number?, brightness: number?, tint: Vec? }?,
	vignette: { color: Vec?, strength: number? }?,
	shots: { Shot },
	beats: { Beat }?,
}

-- A shot solved here, in the world.
type Solved = {
	at: number,
	view: CFrame,
	distance: number, -- from the eye to what it looks at
	fov: number,
	glide: number,
	to: CFrame?,
	toFov: number?,
	focus: number?,
}

local playing: string? = nil
local playingToken = 0 -- (the camera token of the one playing)

local function color(c: Vec?, fallback: Color3): Color3
	if type(c) ~= "table" then
		return fallback
	end
	return Color3.fromRGB(c[1] or 0, c[2] or 0, c[3] or 0)
end

-- An emote's cutscene (nil for one without).
function EmoteCinema.of(clip: string): Cut?
	local meta = (EmoteMeta :: any)[clip]
	local cut = meta and meta.cinema
	if type(cut) ~= "table" or type(cut.shots) ~= "table" or #cut.shots == 0 then
		return nil
	end
	return cut :: Cut
end

-- The clip whose cutscene is on this screen now (nil when none is).
function EmoteCinema.playing(): string?
	return playing
end

-- Whether this player's own emote gets its cutscene here, now.
function EmoteCinema.wants(clip: string): boolean
	if ClientState.isParticipant() or ClientState.isWatching() then
		return false
	end
	if Settings.get("emoteCutscenes") == false or Motion.isReduced() or CameraDirector.busy() then
		return false
	end
	local info = EmoteInfo.of(clip)
	if not info.cinematic or not EmoteCinema.of(clip) then
		return false
	end
	return EmotePolicy.camera(info, { inCase = false, phase = "Lobby", deathsinger = false, cutscene = false })
end

-- The shots placed round the body as it stands now (its place, and its facing on the flat), each eye cleared of
-- the walls; a shot no eye can be found for is left out.
local function solve(cut: Cut, root: BasePart): { Solved }
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(root.Position, root.Position + flat)
	local function point(v: Vec, side: number): Vector3
		return base:PointToWorldSpace(Vector3.new((v[1] or 0) * side, v[2] or 0, v[3] or 0))
	end
	-- (an eye that sees what it looks at: as written, else pulled in towards it)
	local function view(eye: Vec, at: Vec, side: number): (CFrame?, number)
		local target = point(at, side)
		local from = point(eye, side)
		for _, k in ipairs(PULL) do
			local here = target + (from - target) * k
			if ShotSolver.clear(target, here) then
				return CFrame.lookAt(here, target), (target - here).Magnitude
			end
		end
		return nil, 0
	end
	local list: { Solved } = {}
	for _, shot in ipairs(cut.shots) do
		for _, side in ipairs({ 1, -1 }) do -- (else mirrored to the other side of the body)
			local cf, distance = view(shot.eye, shot.look, side)
			local to = shot.to
			local toView = if to then view(to.eye or shot.eye, to.look or shot.look, side) else nil
			if cf and (not to or toView) then
				table.insert(list, {
					at = shot.at,
					view = cf,
					distance = distance,
					fov = shot.fov,
					glide = shot.glide or 0,
					to = toView,
					toFov = if to then to.fov or shot.fov else nil,
					focus = shot.focus,
				})
				break
			end
		end
	end
	return list
end

-- Takes this player's camera through the emote's cutscene, from `zero` (the server time the clip's start stands
-- at) for a clip of `length` seconds. Returns the function that gives everything back (gliding back, unless
-- `atOnce`), or nil when no shot can be seen here (the caller may turn the showpiece camera on instead).
function EmoteCinema.start(character: Model, clip: string, zero: number, length: number): ((atOnce: boolean?) -> ())?
	local cut = EmoteCinema.of(clip)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not cut or not root or not root:IsA("BasePart") or not humanoid or not camera then
		return nil
	end
	local shots = solve(cut, root)
	if #shots == 0 then
		return nil
	end
	local token = CameraDirector.take(length + HOLD + BACK + 1)
	local home, homeFov = camera.CFrame, camera.FieldOfView
	playing, playingToken = clip, token

	local done = false
	local runner: thread? = nil
	local cleanups: { () -> () } = {}
	local connections: { RBXScriptConnection } = {}
	local unfocus: (() -> ())? = nil

	local function finish(atOnce: boolean?)
		if done then
			return
		end
		done = true
		if playingToken == token then
			playing = nil
		end
		if runner and runner ~= coroutine.running() and coroutine.status(runner) ~= "dead" then
			task.cancel(runner)
		end
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		if unfocus then
			table.insert(cleanups, unfocus)
		end
		for _, cleanup in ipairs(cleanups) do
			local ok, err = pcall(cleanup)
			if not ok then
				warn("[DeathsGambit] emote cutscene clean-up: " .. tostring(err))
			end
		end
		if atOnce then
			CameraDirector.release(token)
			return
		end
		CameraDirector.move(token, home, BACK, homeFov, Enum.EasingStyle.Quint)
		task.delay(BACK, function()
			CameraDirector.release(token)
		end)
	end

	-- Runs one step; a step that errors ends the cutscene at once (the emote goes on).
	local function step(fn: () -> ())
		if done then
			return
		end
		local ok, err = pcall(fn)
		if not ok then
			warn("[DeathsGambit] emote cutscene " .. clip .. ": " .. tostring(err))
			finish(true)
		end
	end

	-- The screen for the whole of it: the bars, the grade, the vignette.
	step(function()
		Cinema.letterbox(true)
		table.insert(cleanups, function()
			Cinema.letterbox(false)
		end)
		local grade = cut.grade
		if grade then
			table.insert(
				cleanups,
				Cinema.tint({
					Saturation = grade.saturation or 0,
					Contrast = grade.contrast or 0,
					Brightness = grade.brightness or 0,
					TintColor = color(grade.tint, Color3.new(1, 1, 1)),
				}, 0.4)
			)
		end
		local vignette = cut.vignette
		if vignette then
			table.insert(cleanups, Cinema.vignette(color(vignette.color, Color3.new()), vignette.strength))
		end
	end)
	if done then
		return finish
	end

	-- Everything timed, in the clip's seconds.
	local events: { { t: number, fn: () -> (), order: number? } } = {}
	for index, shot in ipairs(shots) do
		local nextAt = if shots[index + 1] then shots[index + 1].at else length
		table.insert(events, {
			t = shot.at,
			fn = function()
				if shot.glide > 0 then
					CameraDirector.move(token, shot.view, shot.glide, shot.fov, Enum.EasingStyle.Sine)
				else
					CameraDirector.cut(token, shot.view, shot.fov)
				end
				if unfocus then
					unfocus()
					unfocus = nil
				end
				if shot.focus then
					unfocus = Cinema.focus(shot.distance, shot.focus)
				end
			end,
		})
		local to = shot.to
		if to then
			table.insert(events, {
				t = shot.at + shot.glide,
				fn = function()
					local seconds = math.max(0.1, nextAt - shot.at - shot.glide)
					CameraDirector.move(token, to, seconds, shot.toFov, Enum.EasingStyle.Sine)
				end,
			})
		end
	end
	for _, beat in ipairs(cut.beats or {}) do
		table.insert(events, {
			t = beat.at,
			fn = function()
				if beat.kind == "flash" then
					Cinema.flash(color(beat.color, Color3.new(1, 1, 1)), beat.strength, beat.seconds)
				elseif beat.kind == "impact" then
					Cinema.impact(color(beat.color, Color3.new(1, 1, 1)), beat.strength, beat.seconds)
				elseif beat.kind == "shake" then
					CameraDirector.shake(token, beat.strength or 0.1, beat.seconds or 0.3)
				elseif beat.kind == "vignette" then
					table.insert(cleanups, Cinema.vignette(color(beat.color, Color3.new()), beat.strength))
				end
			end,
		})
	end
	-- (in time, and those at the same time in the order made: a shot's cut before its drift)
	for index, event in ipairs(events) do
		event.order = index
	end
	table.sort(events, function(a, b)
		if a.t ~= b.t then
			return a.t < b.t
		end
		return a.order < b.order
	end)

	-- Whatever happens, it all comes back.
	table.insert(
		connections,
		character.Destroying:Once(function()
			finish(true)
		end)
	)
	table.insert(
		connections,
		humanoid.Died:Once(function()
			finish(true)
		end)
	)
	table.insert(
		connections,
		Players.LocalPlayer.CharacterAdded:Once(function()
			finish(true)
		end)
	)
	table.insert(
		connections,
		ClientState.PhaseChanged:Connect(function()
			if ClientState.isParticipant() or ClientState.isWatching() then
				finish(true)
			end
		end)
	)
	task.delay(length + HOLD + BACK + LATE, function()
		finish(true)
	end)

	runner = task.spawn(function()
		for _, event in ipairs(events) do
			Cinema.waitUntil(zero + event.t)
			if done then
				return
			end
			step(event.fn)
		end
	end)
	return finish
end

return EmoteCinema
