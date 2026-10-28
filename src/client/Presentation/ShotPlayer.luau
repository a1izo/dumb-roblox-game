-- Plays a cutscene made in Blender (art/scripts/cinema, exported to Shared/Cinema/Shots): the camera
-- flies its path, players' avatars (copies, on this screen only) walk their paths and act their clips,
-- props move and are held, and timed events show subtitles, cards and effects, play sounds.
--
--   ShotPlayer.play("IntroCampus", {
--       at = cue.at,                         -- the server time the shot starts
--       cast = { noticer = 123, ["everyone:1"] = 456 },
--       onCard = function(key, event) ... end, -- cards the caller fills in (the case card...)
--   })
--
-- play() blocks until the shot has finished (or was skipped), so call it from the presenter's own
-- thread. Every client plays the same shot from the same cue, so everyone sees the same thing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local ManualBook = require(Shared:WaitForChild("ManualBook"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Models = require(Shared:WaitForChild("Models"))
local Venues = require(Shared:WaitForChild("Venues"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)
local Mixer = require(script.Parent.Parent.Audio.Mixer)
local MusicController = require(script.Parent.Parent.Audio.MusicController)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.CameraDirector)
local Cinema = require(script.Parent.Cinema)
local DeathFx = require(script.Parent.DeathFx)
local Materialize = require(script.Parent.Materialize)
local Stage = require(script.Parent.Stage)
local Vfx = require(script.Parent.Vfx)

local ShotPlayer = {}

export type Options = {
	at: number?,
	cast: { [string]: number }?,
	onCard: ((key: string, event: any) -> (() -> ())?)?,
	onEvent: ((event: any) -> ())?,
	reducedViolence: boolean?,
	stop: (() -> boolean)?, -- ends the shot early once this returns true (the phase moved on...)
	-- How long this showing lasts, from the server (Shared/Cinema/CutLength): a voiced shot whose clip is longer than
	-- its line's time plays slower, everything in it by the same share (its line's words too), the voice at its own pace.
	length: number?,
}

-- What a showing has going: what closes when it ends, the sounds it started, its stretch, the motion
-- blur's pulses ({ started (os.clock), size, seconds }) and the heartbeats' push-ins ({ started, share of
-- the field of view, seconds }).
type Showing = {
	closers: { () -> () },
	sounds: { Sound },
	stretch: number,
	pulses: { { number } },
	punches: { { number } },
}

-- The motion blur: how much the camera's own speed blurs (size per degree a second turned, per stud a
-- second moved), its most, and a move in one frame that is a cut, not a move.
local BLUR_TURN, BLUR_MOVE, BLUR_MOST = 1 / 30, 1 / 14, 6
local CUT_TURN, CUT_MOVE = 20, 5

-- The data of a shot by name, or nil.
function ShotPlayer.get(name: string): any
	local folder = Shared:FindFirstChild("Cinema")
	local shots = if folder then folder:FindFirstChild("Shots") else nil
	local module = if shots then shots:FindFirstChild(name) else nil
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, data = pcall(require, module)
	return if ok then data else nil
end

function ShotPlayer.exists(name: string): boolean
	return ShotPlayer.get(name) ~= nil
end

local function origin(venue: string): Vector3
	if venue == "Meeting" then
		return Venues.MEETING
	elseif venue == "Sets" then
		return Venues.SETS
	end
	return Venues.MAP
end

-- The key index i with times[i] <= t < times[i + 1] (binary search).
local function find(times: { number }, t: number): number
	local low, high = 1, #times
	if t <= times[1] then
		return 1
	end
	if t >= times[high] then
		return high
	end
	while high - low > 1 do
		local middle = (low + high) // 2
		if times[middle] <= t then
			low = middle
		else
			high = middle
		end
	end
	return low
end

local function alphaAt(times: { number }, i: number, t: number): (number, number)
	local j = math.min(i + 1, #times)
	if i == j then
		return j, 0
	end
	local span = times[j] - times[i]
	return j, if span > 0 then math.clamp((t - times[i]) / span, 0, 1) else 0
end

-- A path's keys as CFrames (position, then yaw or x/y/z angles).
local function pathFrames(data: any): { CFrame }
	local frames = {}
	local p = data.p
	for i = 1, #data.t do
		local base = (i - 1) * 3
		local position = Vector3.new(p[base + 1], p[base + 2], p[base + 3])
		local rotation
		if data.yaw then
			rotation = CFrame.Angles(0, math.rad(data.yaw[i]), 0)
		else
			local r = data.r
			rotation = CFrame.Angles(math.rad(r[base + 1]), math.rad(r[base + 2]), math.rad(r[base + 3]))
		end
		frames[i] = CFrame.new(position) * rotation
	end
	return frames
end

local function samplePath(times: { number }, frames: { CFrame }, t: number): CFrame
	local i = find(times, t)
	local j, alpha = alphaAt(times, i, t)
	return frames[i]:Lerp(frames[j], alpha)
end

local function shown(range: { number }?, t: number): boolean
	return range == nil or (t >= range[1] and t <= range[2])
end

-- How open a held Manual is at t, from its keys ({ t, 0 closed .. 1 open }), smooth between them.
local function openAt(keys: { { number } }, t: number): number
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for k = 2, #keys do
		local a, b = keys[k - 1], keys[k]
		if t <= b[1] then
			local u = (t - a[1]) / math.max(1e-6, b[1] - a[1])
			return a[2] + (b[2] - a[2]) * u * u * (3 - 2 * u)
		end
	end
	return keys[#keys][2]
end

-- How high a body's root stands over the floor (R6: half the root and a leg).
local function lift(model: Model): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local leg = model:FindFirstChild("Right Leg")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid.HipHeight + root.Size.Y / 2 + (if leg and leg:IsA("BasePart") then leg.Size.Y else 2)
	end
	return 3
end

local function placeModel(model: Instance, cframe: CFrame)
	if model:IsA("Model") then
		model:PivotTo(cframe)
	elseif model:IsA("BasePart") then
		model.CFrame = cframe
	end
end

local function propModel(name: string): Instance?
	local model = ModelLibrary.get(name)
	if not model then
		return nil
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	if model:IsA("BasePart") then
		model.Anchored = false
		model.CanCollide = false
	end
	return model
end

-- Welds a prop to the end of an arm (offset and rotation from the arm's middle).
local function hold(actor: Model, spec: any): Instance?
	local arm = actor:FindFirstChild(spec.arm)
	-- (Death's Manual held open comes rigged: its board and leaves turn on their joints)
	local rigged = spec.model == ManualBook.KEY and type(spec.open) == "table"
	local model: Instance? = if rigged then Models.grimoire() else propModel(spec.model)
	if not arm or not arm:IsA("BasePart") or not model then
		if model then
			model:Destroy()
		end
		return nil
	end
	if rigged and model:IsA("Model") then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.Massless = true
			end
		end
		ManualBook.pose(model, spec.open[1][2], spec.open[1][2])
	end
	if type(spec.scale) == "number" and math.abs(spec.scale - 1) > 1e-3 and model:IsA("Model") then
		model:ScaleTo(model:GetScale() * spec.scale)
	end
	local o, r = spec.offset, spec.rot
	local target = arm.CFrame
		* CFrame.new(o[1], o[2], o[3])
		* CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
	placeModel(model, target)
	local anchor = if model:IsA("Model")
		then (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
		else model
	if anchor and anchor:IsA("BasePart") then
		if model:IsA("Model") then
			for _, item in ipairs(model:GetDescendants()) do
				-- (a rigged piece keeps its own joint, which ManualBook.pose turns)
				if item:IsA("BasePart") and item ~= anchor and not item:FindFirstChild("ManualJoint") then
					Create("WeldConstraint", { Part0 = anchor, Part1 = item, Parent = item })
				end
			end
		end
		Create("WeldConstraint", { Part0 = arm, Part1 = anchor, Parent = anchor })
	end
	if rigged then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				item.Anchored = false
			end
		end
	end
	return model
end

-- Red glowing eyes on an actor's head (the Deathsinger's deal).
local function eyes(actor: Model): { BasePart }
	local head = actor:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return {}
	end
	local parts = {}
	for _, side in ipairs({ -0.2, 0.2 }) do
		local part = Create("Part", {
			Name = "ShotEye",
			Size = Vector3.new(0.2, 0.12, 0.06),
			Color = Color3.fromRGB(255, 25, 25),
			Material = Enum.Material.Neon,
			Anchored = false,
			CanCollide = false,
			CanQuery = false,
			Massless = true,
			Transparency = 1,
			CFrame = head.CFrame * CFrame.new(side, 0.12, -head.Size.Z / 2 - 0.03),
			Parent = actor,
		})
		Create("WeldConstraint", { Part0 = head, Part1 = part, Parent = part })
		table.insert(parts, part)
	end
	Create(
		"PointLight",
		{ Color = Color3.fromRGB(255, 40, 40), Range = 8, Brightness = 3, Enabled = false, Parent = parts[1] }
	)
	return parts
end

type Live = {
	model: Model,
	data: any,
	times: { number },
	frames: { CFrame },
	lift: number,
	held: { { spec: any, model: Instance?, open: number? } },
	shadow: Highlight?,
	eyes: { BasePart },
}

-- Puts the cutscene face decal Face<name> (art/scripts/ui/faces.py) on an actor's head, or ("") its own back.
local function setFace(model: Model, name: string)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local decal = head:FindFirstChild("face")
	if not decal or not decal:IsA("Decal") then
		decal = Create("Decal", { Name = "face", Face = Enum.NormalId.Front, Parent = head }) :: Decal
	end
	local own = decal:GetAttribute("OwnTexture")
	if own == nil then
		own = decal.Texture
		decal:SetAttribute("OwnTexture", own)
	end
	local texture = if name ~= "" then ModelLibrary.carrierTexture("Face" .. name) else nil
	decal.Texture = texture or own
	-- (an avatar's own painted head, Services/DynamicHeads: its picture put away while the cutscene's face shows
	-- on its see-through decal, back after)
	local painted = head:GetAttribute("LHeadTexture")
	if head:IsA("MeshPart") and type(painted) == "string" then
		head.TextureID = if texture then "" else painted
		decal.Transparency = if texture then 0 else 1
	end
end

local function runEvent(event: any, base: Vector3, token: number, options: Options, showing: Showing)
	local closers = showing.closers
	local kind = event.kind
	if options.onEvent then
		options.onEvent(event)
	end
	if kind == "subtitle" then
		table.insert(closers, Cinema.subtitle(event.text or "", (event.dur or 2.5) * showing.stretch))
	elseif kind == "line" then
		table.insert(closers, Cinema.line(event.words or {}, event.dur or 3, showing.stretch))
	elseif kind == "title" then
		local lines = event.lines or {}
		local close = Cinema.card({ title = lines[1] or "", subtitle = lines[2], typewriter = true, y = 0.5 })
		table.insert(closers, close)
		task.delay(event.dur or 2.5, close)
	elseif kind == "card" then
		local close = if options.onCard then options.onCard(event.key or "", event) else nil
		if close then
			table.insert(closers, close)
			task.delay(event.dur or 2.5, close)
		end
	elseif kind == "sfx" then
		-- (a loop runs until the shot ends; every sound the shot started is stopped with it)
		local entry = Assets.sfx[event.slot or ""]
		local looped = event.loop == true
			or (entry ~= nil and string.find(string.lower(entry.ref), "loop", 1, true) ~= nil)
		local ok, sound = pcall(Sfx.play, event.slot, { looped = looped })
		if ok and sound then
			table.insert(showing.sounds, sound)
		end
	elseif kind == "fx" then
		local name = event.name
		local at = if event.pos then base + Vector3.new(event.pos[1], event.pos[2], event.pos[3]) else nil
		if name == "flash" then
			Cinema.flash(
				Color3.fromRGB(event.r or 255, event.g or 255, event.b or 255),
				event.strength or 0.6,
				event.dur or 0.4
			)
		elseif name == "impact" then
			Cinema.impact(
				Color3.fromRGB(event.r or 255, event.g or 255, event.b or 255),
				event.strength or 0.55,
				event.dur or 0.22
			)
		elseif name == "shake" then
			CameraDirector.shake(token, event.strength or 0.4, event.dur or 0.4)
		elseif name == "blur" then
			table.insert(showing.pulses, { os.clock(), event.strength or 12, event.dur or 0.35 })
		elseif name == "pulse" then
			-- a heartbeat: the edges thump in and the lens pushes in a touch
			Cinema.pulse(
				Color3.fromRGB(event.r or 110, event.g or 0, event.b or 10),
				event.strength or 0.6,
				event.dur or 0.6
			)
			if not Vfx.still() then
				table.insert(showing.punches, { os.clock(), event.punch or 0.05, event.dur or 0.6 })
			end
		elseif name == "drain" then
			-- the colour drains out of the picture over `dur` (back when the shot ends)
			table.insert(
				closers,
				Cinema.tint(
					{ Saturation = -(event.strength or 0.8), Contrast = event.contrast or 0.12 },
					event.dur or 4
				)
			)
		elseif name == "still" then
			Cinema.still(Color3.fromRGB(event.r or 255, event.g or 40, event.b or 50), event.dur or 0.3)
		elseif name == "black" then
			table.insert(closers, Cinema.black())
			if event.hush then -- (and silence: every sound the shot started stops on the cut)
				for _, playing in ipairs(showing.sounds) do
					playing:Stop()
				end
			end
		elseif name == "snowburst" and at then
			DeathFx.burst(at, Color3.fromRGB(235, 240, 248), 24)
		elseif name == "burst" and at then
			DeathFx.burst(at, Color3.fromRGB(event.r or 180, event.g or 20, event.b or 30), event.amount or 30)
		elseif name == "dip" then
			task.spawn(Cinema.dip, event.dur or 0.4)
		elseif name == "blood" and at and not options.reducedViolence then
			DeathFx.burst(at, Color3.fromRGB(110, 8, 12), event.amount or 18)
		end
	end
end

-- Plays the shot `name`; returns when it is over. Returns false if there is no such shot.
function ShotPlayer.play(name: string, options: Options?): boolean
	local shot = ShotPlayer.get(name)
	if not shot then
		return false
	end
	local opts: Options = options or {}
	local cast = opts.cast or {}
	local base = origin(shot.venue)
	local serverStart = opts.at or workspace:GetServerTimeNow()
	local startClock = os.clock() + (serverStart - workspace:GetServerTimeNow())
	local length = shot.length
	-- Debug: Players.LocalPlayer:SetAttribute("ShotRate", 0.25) plays shots in slow motion (from the command bar).
	local rateAttr = Players.LocalPlayer:GetAttribute("ShotRate")
	local rate = if type(rateAttr) == "number" and rateAttr > 0 then rateAttr else 1
	local stretch = if type(opts.length) == "number" and opts.length > length + 0.05 then opts.length / length else 1
	rate /= stretch

	-- The camera's keys as CFrames.
	local cam = shot.camera
	local camTimes = cam.t
	local camFrames = {}
	for i = 1, #camTimes do
		local p, q = (i - 1) * 3, (i - 1) * 4
		camFrames[i] = CFrame.new(
			base.X + cam.p[p + 1],
			base.Y + cam.p[p + 2],
			base.Z + cam.p[p + 3],
			cam.q[q + 1],
			cam.q[q + 2],
			cam.q[q + 3],
			cam.q[q + 4]
		)
	end

	-- Wait for the start (a cue arrives a little early).
	local wait = startClock - os.clock()
	if wait > 0 then
		task.wait(wait)
	end

	local stage = Stage.new()
	local actors: { Live } = {}
	local bySlot: { [string]: Live } = {}
	-- (the map intros show players in their own avatars, kept by the server from the lobby; the match suit
	-- when there is none, a test bot's)
	local ownLooks = if shot.own then ReplicatedStorage:FindFirstChild("LOwnLooks") else nil
	for _, data in ipairs(shot.actors) do
		local userId = cast[data.slot]
		local own = if userId and ownLooks then ownLooks:FindFirstChild(tostring(userId)) else nil
		local model
		if own and own:IsA("Model") then
			model = stage:cast(own, CFrame.new(0, -500, 0), nil, nil)
			local body = Characters.byUserId(userId :: number)
			if body then
				stage:hide(body)
			end
		elseif userId then
			model = stage:cast(userId, CFrame.new(0, -500, 0), nil, nil)
		elseif data.extra then
			-- (in Tokyo the commuters are the crowd's own civilians, never a suit; elsewhere a faceless stand-in)
			local crowd = if shot.venue == "Tokyo" then ReplicatedStorage:FindFirstChild("LCrowd") else nil
			local bodies = if crowd then crowd:GetChildren() else {}
			local number = tonumber(string.match(data.slot, "%d+")) or 1
			local civilian = bodies[(number * 5) % math.max(1, #bodies) + 1]
			model = stage:cast(
				if civilian and civilian:IsA("Model") then civilian else Stage.figure(),
				CFrame.new(0, -500, 0),
				nil,
				nil
			)
		end
		if model then
			local live: Live = {
				model = model,
				data = data,
				times = data.t,
				frames = pathFrames(data),
				lift = lift(model),
				held = {},
				shadow = nil,
				eyes = {},
			}
			if data.silhouette then
				live.shadow = Create("Highlight", {
					FillColor = Color3.new(0, 0, 0),
					FillTransparency = 0,
					OutlineTransparency = 1,
					DepthMode = Enum.HighlightDepthMode.Occluded,
					Enabled = false,
					Parent = model,
				})
			end
			if data.eyes then
				live.eyes = eyes(model)
			end
			for _, spec in ipairs(data.props or {}) do
				table.insert(live.held, { spec = spec, model = nil })
			end
			if data.clip then
				local clip, at = data.clip, data.at or 0
				task.spawn(function()
					PoseController.bindWhenReady(model, 2)
					PoseController.play(model, clip, { startAt = startClock + at / rate, fadeIn = 0, speed = rate })
				end)
			end
			table.insert(actors, live)
			bySlot[data.slot] = live
		end
	end

	local props = {}
	for _, data in ipairs(shot.props or {}) do
		-- Death's Manual comes rigged (its board and leaves turn), imported or part-built.
		local model: Instance? = if data.model == ManualBook.KEY then Models.grimoire() else propModel(data.model)
		if model then
			for _, item in ipairs(model:GetDescendants()) do
				if item:IsA("BasePart") then
					item.Anchored = true
				end
			end
			if model:IsA("BasePart") then
				model.Anchored = true
			end
			if model:IsA("Model") then
				if type(data.open) == "number" and data.model == ManualBook.KEY then
					ManualBook.pose(model, data.open, data.open)
				end
				if type(data.scale) == "number" and math.abs(data.scale - 1) > 1e-3 then
					model:ScaleTo(model:GetScale() * data.scale)
				end
			end
			table.insert(props, { model = model, data = data, times = data.t, frames = pathFrames(data) })
		end
	end

	local closers: { () -> () } = {}
	local showing: Showing = { closers = closers, sounds = {}, stretch = stretch, pulses = {}, punches = {} }
	-- Motion blur: the camera's own turning and moving blurs the frame a little, and a hit pulses it.
	local blur: BlurEffect? = nil
	if not Vfx.still() then
		local made = Create("BlurEffect", { Name = "ShotMotionBlur", Size = 0, Parent = workspace.CurrentCamera })
		blur = made
		table.insert(closers, function()
			made:Destroy()
		end)
	end
	local lastCamera: CFrame? = nil
	local lastClock = os.clock()
	local blurSize = 0
	-- With the debug rate set, the shot's own clock in a corner, so a screenshot says which moment it is.
	local clockLabel: TextLabel? = nil
	local probed = false
	if rateAttr ~= nil then
		local gui = Create("ScreenGui", {
			Name = "ShotClock",
			DisplayOrder = 1000,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
		clockLabel = Create("TextLabel", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.3,
			TextColor3 = Color3.new(1, 1, 0),
			Font = Enum.Font.Code,
			TextSize = 22,
			Position = UDim2.new(0.5, -90, 0, 6),
			Size = UDim2.fromOffset(180, 30),
			Parent = gui,
		})
		table.insert(closers, function()
			gui:Destroy()
		end)
	end
	local late = os.clock() - startClock
	if late > 0.25 then
		warn(string.format("[DeathsGambit] Shot %s started %.2f s late (its opening is skipped)", name, late))
	end
	local token = CameraDirector.take(length / rate + 2)
	if shot.letterbox then
		Cinema.letterbox(true)
	end
	local finished = false
	local skip: (() -> ())? = nil
	if shot.skippable then
		skip = Cinema.skipButton(function()
			finished = true
		end)
	end

	-- The shot's own sound: its music (a bed under the line, or the scene's own) for as long as it plays, and the voiced
	-- line on its mark. Without a bed, the game's music ducks under the voice.
	local sound = if type(shot.sound) == "table" then shot.sound else nil
	local ducked = false
	if sound and (sound.bed or sound.music) then
		MusicController.setScene(sound.bed or sound.music)
	end
	if sound and type(sound.voice) == "string" then
		task.delay(math.max(0, (tonumber(sound.voiceAt) or 0) * stretch - (os.clock() - startClock)), function()
			if finished then
				return
			end
			local voice = Sfx.play(sound.voice)
			if voice then
				table.insert(showing.sounds, voice)
				if not (sound.bed and Assets.audioId(Assets.music[sound.bed])) then
					ducked = true
					Mixer.duck("shotVoice", true)
				end
			end
		end)
	end

	local events = shot.events or {}
	local nextEvent = 1
	local bindName = "ShotPlayer_" .. name .. "_" .. tostring(token)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
		local t = (os.clock() - startClock) * rate
		if t >= length then
			finished = true
		end
		local tt = math.clamp(t, 0, length)
		if clockLabel then
			clockLabel.Text = string.format("%s %.2f", name, tt)
			if not probed and tt >= 2 then
				-- Where the bodies really are (set space), to compare with the Blender layout.
				probed = true
				for _, live in ipairs(actors) do
					local head = live.model:FindFirstChild("Head")
					local torso = live.model:FindFirstChild("Torso")
					if head and torso and head:IsA("BasePart") and torso:IsA("BasePart") then
						print(
							string.format(
								"[ShotProbe] %s t=%.2f %s head %s torso %s",
								name,
								tt,
								live.data.slot,
								tostring(head.Position - base),
								tostring(torso.Position - base)
							)
						)
						local root = live.model:FindFirstChild("HumanoidRootPart")
						local motor = if root then root:FindFirstChild("RootJoint") else nil
						local humanoid = live.model:FindFirstChildOfClass("Humanoid")
						print(
							string.format(
								"[ShotProbe]   lift %.2f hip %.2f root %s joint %s transform %s",
								live.lift,
								if humanoid then humanoid.HipHeight else -1,
								if root and root:IsA("BasePart") then tostring(root.Position - base) else "none",
								if motor then motor.ClassName else "none",
								if motor and motor:IsA("Motor6D") then tostring(motor.Transform.Position) else "-"
							)
						)
					end
				end
			end
		end
		-- camera
		local i = find(camTimes, tt)
		local j, alpha = alphaAt(camTimes, i, tt)
		local fov = cam.fov[i] + (cam.fov[j] - cam.fov[i]) * alpha
		local clock = os.clock()
		for k = #showing.punches, 1, -1 do
			local punch = showing.punches[k]
			local u = (clock - punch[1]) / punch[3]
			if u >= 1 then
				table.remove(showing.punches, k)
			else
				-- (in fast, out slow, like the vignette's thump)
				local shape = if u < 0.12 then u / 0.12 else 1 - (u - 0.12) / 0.88
				fov *= 1 - punch[2] * shape * shape
			end
		end
		local frameCamera = camFrames[i]:Lerp(camFrames[j], alpha)
		CameraDirector.cut(token, frameCamera, fov)
		if blur then
			local now = os.clock()
			local dt = math.max(1e-3, now - lastClock)
			local want = 0
			if lastCamera then
				local turn = math.deg(math.acos(math.clamp(lastCamera.LookVector:Dot(frameCamera.LookVector), -1, 1)))
				local move = (frameCamera.Position - lastCamera.Position).Magnitude
				if turn < CUT_TURN and move < CUT_MOVE then -- (a cut is not a move)
					want = math.min(BLUR_MOST, (turn / dt) * BLUR_TURN + (move / dt) * BLUR_MOVE)
				end
			end
			for k = #showing.pulses, 1, -1 do
				local pulse = showing.pulses[k]
				local u = (now - pulse[1]) / pulse[3]
				if u >= 1 then
					table.remove(showing.pulses, k)
				else
					want = math.max(want, pulse[2] * (1 - u) * (1 - u))
				end
			end
			-- (eased, so the blur breathes rather than flickers frame to frame)
			blurSize = if want > blurSize then want else blurSize + (want - blurSize) * math.min(1, dt * 10)
			blur.Size = blurSize
			lastCamera, lastClock = frameCamera, now
		end
		-- actors
		for _, live in ipairs(actors) do
			local visible = shown(live.data.show, tt)
			local place = CFrame.new(base) * samplePath(live.times, live.frames, tt) * CFrame.new(0, live.lift, 0)
			live.model:PivotTo(if visible then place else CFrame.new(0, -500, 0))
			if live.shadow then
				live.shadow.Enabled = visible and shown(live.data.silhouette, tt)
			end
			if #live.eyes > 0 then
				local lit = visible and shown(live.data.eyes, tt)
				for _, part in ipairs(live.eyes) do
					part.Transparency = if lit then 0 else 1
					local light = part:FindFirstChildOfClass("PointLight")
					if light then
						light.Enabled = lit
					end
				end
			end
			for _, item in ipairs(live.held) do
				local want = visible and shown(item.spec.show, tt)
				if want and not item.model then
					item.model = hold(live.model, item.spec)
					if item.model then
						item.model.Parent = live.model
					end
				elseif not want and item.model then
					item.model:Destroy()
					item.model = nil
				end
				local book = item.model
				if book and book:IsA("Model") and type(item.spec.open) == "table" then
					local open = openAt(item.spec.open, tt)
					if open ~= item.open then
						item.open = open
						ManualBook.pose(book, open, open)
					end
				end
			end
		end
		-- props
		for _, prop in ipairs(props) do
			if shown(prop.data.show, tt) then
				placeModel(prop.model, CFrame.new(base) * samplePath(prop.times, prop.frames, tt))
				if not prop.model.Parent then
					stage:add(prop.model)
					-- (one joining the shot partway through is drawn in over a moment, never popped out of thin air:
					-- the owner, 2026-10-25; one the shot draws in out of smoke itself is left to that)
					if tt > 0.1 and prop.model:IsA("Model") and not Vfx.still() then
						local drawn = false
						for _, event in ipairs(events) do
							if
								event.kind == "materialize"
								and event.model == prop.data.model
								and math.abs(event.t - tt) < 0.25
							then
								drawn = true
							end
						end
						if not drawn then
							Materialize.appear(prop.model, { seconds = 0.3, quiet = true })
						end
					end
				end
			elseif prop.model.Parent then
				prop.model.Parent = nil
			end
		end
		-- events
		while nextEvent <= #events and events[nextEvent].t <= tt do
			local event = events[nextEvent]
			nextEvent += 1
			if event.kind == "face" then
				local live = bySlot[event.slot or ""]
				if live then
					setFace(live.model, event.face or "")
				end
			elseif event.kind == "materialize" then
				-- a prop drawn into being out of smoke (Presentation/Materialize), not popped in or raised from the floor
				for _, prop in ipairs(props) do
					if prop.data.model == event.model and prop.model:IsA("Model") then
						Materialize.appear(prop.model, {
							seconds = event.dur or 1.5,
							color = Color3.fromRGB(event.r or 200, event.g or 30, event.b or 45),
						})
					end
				end
			else
				task.spawn(runEvent, event, base, token, opts, showing)
			end
		end
	end)

	while not finished and not (opts.stop and opts.stop()) do
		task.wait()
	end
	RunService:UnbindFromRenderStep(bindName)
	if skip then
		skip()
	end
	for _, close in ipairs(closers) do
		pcall(close)
	end
	-- (its sounds end with it, faded out rather than cut)
	for _, playing in ipairs(showing.sounds) do
		if playing.Parent then
			local fade = TweenService:Create(playing, TweenInfo.new(0.4), { Volume = 0 })
			fade.Completed:Once(function()
				playing:Destroy()
			end)
			fade:Play()
		end
	end
	if sound and (sound.bed or sound.music) then
		MusicController.setScene(nil)
	end
	if ducked then
		Mixer.duck("shotVoice", false)
	end
	for _, live in ipairs(actors) do
		PoseController.stop(live.model, nil, 0)
	end
	for _, prop in ipairs(props) do
		prop.model:Destroy()
	end
	stage:destroy()
	if shot.letterbox then
		Cinema.letterbox(false)
	end
	CameraDirector.release(token)
	return true
end

return ShotPlayer
