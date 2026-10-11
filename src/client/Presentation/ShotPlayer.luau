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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Venues = require(Shared:WaitForChild("Venues"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.CameraDirector)
local Cinema = require(script.Parent.Cinema)
local DeathFx = require(script.Parent.DeathFx)
local Stage = require(script.Parent.Stage)

local ShotPlayer = {}

export type Options = {
	at: number?,
	cast: { [string]: number }?,
	onCard: ((key: string, event: any) -> (() -> ())?)?,
	onEvent: ((event: any) -> ())?,
	reducedViolence: boolean?,
	stop: (() -> boolean)?, -- ends the shot early once this returns true (the phase moved on...)
}

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
	local model = propModel(spec.model)
	if not arm or not arm:IsA("BasePart") or not model then
		return nil
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
				if item:IsA("BasePart") and item ~= anchor then
					Create("WeldConstraint", { Part0 = anchor, Part1 = item, Parent = item })
				end
			end
		end
		Create("WeldConstraint", { Part0 = arm, Part1 = anchor, Parent = anchor })
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
	held: { { spec: any, model: Instance? } },
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
end

local function runEvent(event: any, base: Vector3, token: number, options: Options, closers: { () -> () })
	local kind = event.kind
	if options.onEvent then
		options.onEvent(event)
	end
	if kind == "subtitle" then
		table.insert(closers, Cinema.subtitle(event.text or "", event.dur or 2.5))
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
		pcall(Sfx.play, event.slot)
	elseif kind == "fx" then
		local name = event.name
		local at = if event.pos then base + Vector3.new(event.pos[1], event.pos[2], event.pos[3]) else nil
		if name == "flash" then
			Cinema.flash(
				Color3.fromRGB(event.r or 255, event.g or 255, event.b or 255),
				event.strength or 0.6,
				event.dur or 0.4
			)
		elseif name == "shake" then
			CameraDirector.shake(token, event.strength or 0.4, event.dur or 0.4)
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
	for _, data in ipairs(shot.actors) do
		local userId = cast[data.slot]
		local model = if userId
			then stage:cast(userId, CFrame.new(0, -500, 0), nil, nil)
			elseif data.extra then stage:cast(Stage.figure(), CFrame.new(0, -500, 0), nil, nil)
			else nil
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
		local model = propModel(data.model)
		if model then
			for _, item in ipairs(model:GetDescendants()) do
				if item:IsA("BasePart") then
					item.Anchored = true
				end
			end
			if model:IsA("BasePart") then
				model.Anchored = true
			end
			table.insert(props, { model = model, data = data, times = data.t, frames = pathFrames(data) })
		end
	end

	local closers: { () -> () } = {}
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
		CameraDirector.cut(token, camFrames[i]:Lerp(camFrames[j], alpha), fov)
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
			end
		end
		-- props
		for _, prop in ipairs(props) do
			if shown(prop.data.show, tt) then
				placeModel(prop.model, CFrame.new(base) * samplePath(prop.times, prop.frames, tt))
				if not prop.model.Parent then
					stage:add(prop.model)
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
			else
				task.spawn(runEvent, event, base, token, opts, closers)
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
