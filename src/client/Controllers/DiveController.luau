--!strict
-- Last breath on this client: the dive into the lobby's rift (rules: Shared/LobbyGames/LastBreath; the
-- score is the server's, Services/LobbyRift).
--
-- Going over the rim starts it: once this player's character is inside the rift and under its rim, the
-- client takes the body (it owns it), tells the server, and flies the fall itself along the rules' curve,
-- so what the player sees is exactly what is scored. The body has no say in how it falls: it tumbles
-- (Anim/Tumble), down the rock throat, through the cloud the realm floats on and on over the night city,
-- ash streaming past, the view widening and shaking a little as the wind builds. A little steering is
-- allowed, and the rift's draught keeps divers over the landing roof. One press (jump, a click or a tap) is
-- the catch: a pale string drops from the cloud and snaps taut at the diver's back, and the body swings
-- from it, slowing to a stop; too late, and the body slams into the roof, limp, and settles there. Then the
-- rift gives the diver back at the rim. No numbers are shown on the way down: only the roof coming up.
--
-- Everyone else's dive is drawn from what the server puts on their character: attribute Dive ("fall",
-- "brake", "caught", "crash") and DiveSeed (so their tumble has the same character as on the diver's own
-- screen); DiveGap (the studs left) floats over the head of whoever hangs there, for all to read.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))
local Games = Shared:WaitForChild("LobbyGames")
local LastBreath = require(Games:WaitForChild("LastBreath"))
local Toss = require(Games:WaitForChild("Toss"))
local Limp = require(Shared:WaitForChild("Anim"):WaitForChild("Limp"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Tumble = require(script.Parent.Parent.Anim.Tumble)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local DiveController = {}

local LocalPlayer = Players.LocalPlayer
local request = Net.event("LobbyGame")

local TAG = "LRift"
local TRACK = "diveTumble" -- the tumble's procedural track (PoseController)
local ROOT_UP = 3 -- the root's middle above the soles
local STEER = 9 -- studs a second a diver can drift
local FUNNEL = 11 -- studs from the rift's axis beyond which the draught pulls a diver back in
local FOV_GAIN = 18 -- degrees the view widens by at the top speed
local STRING_COLOR = Color3.fromRGB(226, 230, 238)
local CLIPS = { "collapseAccident" }

type Rift = { rift: Toss.Rift, rimY: number, roofY: number, cloudY: number, height: number }

local rift: Rift? = nil

-- This player's dive.
local diving = false
local started = 0
local brakeAt: number? = nil
local outcome: LastBreath.Outcome? = nil
local rested = false
local confirmed = false
local spot = Vector2.zero
local facing = CFrame.identity
local savedFov: number? = nil
local wind: Sound? = nil
local tumble: Tumble.State? = nil
local unlimp: (() -> ())? = nil -- puts the joints back after the crash's ragdoll
local savedNeck: boolean? = nil
local ash: BasePart? = nil
local shakeUntil = 0 -- a jolt of the camera (the catch, the crash) lasts until then
local shakeStrength = 0

-- The strings: one for every body hanging from the cloud on this screen.
local strings: { [Model]: { beam: Beam, top: BasePart } } = {}
-- Everyone else's tumbles (the server says when each begins).
local others: { [Model]: { state: Tumble.State, startedAt: number, brakeAt: number? } } = {}

local function readRift()
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do
		local rimY, roofY = part:GetAttribute("RimY"), part:GetAttribute("RoofY")
		if part:IsDescendantOf(workspace) and type(rimY) == "number" and type(roofY) == "number" then
			local cloudY = part:GetAttribute("CloudY")
			rift = {
				rift = {
					cx = part:GetAttribute("Cx") :: number,
					cz = part:GetAttribute("Cz") :: number,
					rx = part:GetAttribute("Rx") :: number,
					rz = part:GetAttribute("Rz") :: number,
					turn = part:GetAttribute("Turn") :: number,
				},
				rimY = rimY,
				roofY = roofY,
				cloudY = if type(cloudY) == "number" then cloudY else rimY - 76,
				height = LastBreath.height(rimY, roofY),
			}
			return
		end
	end
	rift = nil
end

local function body(): (Model?, BasePart?, Humanoid?)
	local character = LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return character, if root and root:IsA("BasePart") then root else nil, humanoid
end

local function calm(): boolean
	return Settings.get("reduceMotion") == true
end

-- The view: wider the faster the fall (eased towards it each frame), back to what it was when the dive ends.
local function widen(extra: number, dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local base = savedFov or camera.FieldOfView
	savedFov = base
	camera.FieldOfView += (base + extra - camera.FieldOfView) * math.min(1, dt * 3)
end

local function restoreFov()
	local camera = workspace.CurrentCamera
	if camera and savedFov then
		TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { FieldOfView = savedFov }):Play()
	end
	savedFov = nil
end

local function jolt(strength: number, time: number)
	shakeStrength = strength
	shakeUntil = os.clock() + time
end

-- The string a caught body hangs from: from the cloud's underside straight down to its upper back.
local function hangString(character: Model, cloudY: number)
	if strings[character] then
		return
	end
	local torso = character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local back = Create("Attachment", { Name = "DiveString", CFrame = CFrame.new(0, 0.6, 0.45), Parent = torso })
	local top = Create("Part", {
		Name = "DiveStringTop",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		CFrame = CFrame.new(torso.Position.X, cloudY, torso.Position.Z),
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	local above = Create("Attachment", { Name = "DiveStringTop", Parent = top })
	local beam = Create("Beam", {
		Name = "DiveString",
		Attachment0 = above,
		Attachment1 = back,
		Width0 = 0.07,
		Width1 = 0.05,
		Segments = 1,
		FaceCamera = true,
		LightEmission = 0.7,
		LightInfluence = 0.2,
		Color = ColorSequence.new(STRING_COLOR),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.6, 0.25),
			NumberSequenceKeypoint.new(1, 0.05),
		}),
		Parent = top,
	}) :: Beam
	strings[character] = { beam = beam, top = top }
	Sfx.play("gameDiveString")
end

local function cutString(character: Model)
	local held = strings[character]
	if held then
		held.top:Destroy()
		local torso = character:FindFirstChild("Torso")
		local back = if torso then torso:FindFirstChild("DiveString") else nil
		if back then
			back:Destroy()
		end
		strings[character] = nil
	end
end

-- Ash on the way down: shed by the cloud and the rock, it hangs in the air and streams up past a diver (it is
-- the diver who moves). One box of it under this player while they fall.
local function makeAsh(): BasePart
	local holder = Create("Part", {
		Name = "DiveAsh",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(46, 1, 46),
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	Create("ParticleEmitter", {
		Name = "Ash",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(170, 172, 180), Color3.fromRGB(120, 122, 130)),
		LightEmission = 0,
		LightInfluence = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.1) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.6, 2.2),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-90, 90),
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 0,
		Parent = holder,
	})
	return holder
end

local function stopClips(character: Model?)
	for _, clip in ipairs(CLIPS) do
		PoseController.stop(character, clip, 0.25)
	end
	PoseController.stop(character, TRACK, 0.25)
end

-- Puts the body's joints back after the crash's ragdoll.
local function standUp()
	if unlimp then
		unlimp()
		unlimp = nil
	end
	local _, _, humanoid = body()
	if humanoid and savedNeck ~= nil then
		humanoid.RequiresNeck = savedNeck
	end
	savedNeck = nil
end

-- Lets the body go (the dive is over, or was refused).
local function release()
	if not diving then
		return
	end
	diving = false
	local character, root, humanoid = body()
	standUp()
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.CameraOffset = Vector3.zero
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if character then
		stopClips(character)
		cutString(character)
	end
	tumble = nil
	restoreFov()
	if wind then
		wind:Destroy()
		wind = nil
	end
	if ash then
		ash:Destroy()
		ash = nil
	end
end

local function begin(root: BasePart, humanoid: Humanoid, character: Model)
	diving = true
	started = os.clock()
	brakeAt = nil
	outcome = nil
	rested = false
	confirmed = false
	spot = Vector2.new(root.Position.X, root.Position.Z)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	facing = if flat.Magnitude > 0.01 then CFrame.lookAt(Vector3.zero, flat) else CFrame.identity
	humanoid.PlatformStand = true
	local seed = math.random(1, 2 ^ 24)
	request:FireServer({ game = "rift", action = "enter", seed = seed })
	local state = Tumble.new(seed)
	tumble = state
	PoseController.playProcedural(character, TRACK, function(elapsed: number)
		return Tumble.sample(state, elapsed)
	end, { fadeIn = 0.25, fadeOut = 0.3 })
	wind = Sfx.play("gameDiveFall", { volume = 0.8 }) or Sfx.play("gameDiveWind", { volume = 0.8, looped = true })
	ash = makeAsh()
end

local function press()
	local info = rift
	if not diving or brakeAt or not info then
		return
	end
	local t = os.clock() - started
	if t < LastBreath.MIN_BRAKE or t >= LastBreath.timeToFall(info.height) then
		return
	end
	brakeAt = t
	outcome = LastBreath.outcome(info.height, t)
	request:FireServer({ game = "rift", action = "brake" })
	local character = LocalPlayer.Character
	if tumble then
		Tumble.catch(tumble)
	end
	if character then
		hangString(character, info.cloudY)
	end
	if not calm() then
		jolt(0.35, 0.45)
	end
end

-- The body slams into the roof: limp (a real ragdoll, this client's own), with what speed it had.
local function crash(character: Model, root: BasePart, humanoid: Humanoid, speed: number)
	PoseController.stop(character, TRACK, 0)
	savedNeck = humanoid.RequiresNeck
	humanoid.RequiresNeck = false
	unlimp = Limp.apply(character, true)
	local rng = Random.new()
	local down = math.clamp(speed, 25, 55)
	root.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-3, 3), -down, rng:NextNumber(-3, 3))
	root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-2, 2), rng:NextNumber(-6, 6))
	if not calm() then
		jolt(0.8, 0.5)
	end
	if not Sfx.play("gameDiveImpact") then
		Sfx.play("gameDiveCrash")
	end
end

local function rest(result: LastBreath.Outcome, speed: number)
	rested = true
	if wind then
		wind:Destroy()
		wind = nil
	end
	if ash then
		ash:Destroy()
		ash = nil
	end
	restoreFov()
	local character, root, humanoid = body()
	if result.crashed and character and root and humanoid then
		crash(character, root, humanoid, speed)
	end
end

local function usable(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching() and not ClientState.isAway()
end

-- The camera: wider with speed, a tremble in the wind, and the jolts.
local function camera(humanoid: Humanoid, speed: number, dt: number)
	local fast = math.clamp(speed / Tumble.TOP_SPEED, 0, 1)
	if not rested then
		widen(FOV_GAIN * fast, dt)
	end
	if calm() then
		humanoid.CameraOffset = Vector3.zero
		return
	end
	local now = os.clock()
	local tremble = (if rested then 0 else 0.03 + 0.12 * fast * fast)
	if now < shakeUntil then
		tremble += shakeStrength * (shakeUntil - now) / 0.5
	end
	humanoid.CameraOffset = Vector3.new(
		math.noise(now * 9, 0.3) * tremble,
		math.noise(now * 9, 1.7) * tremble,
		math.noise(now * 9, 3.1) * tremble * 0.5
	)
end

local function step(dt: number)
	local info = rift
	local character, root, humanoid = body()
	if not info or not character or not root or not humanoid then
		release()
		return
	end
	if not diving then
		-- Over the rim and in the rift: the dive begins.
		local at = root.Position
		if
			usable()
			and humanoid.Health > 0
			and at.Y < info.rimY - LastBreath.DROP
			and at.Y > info.rimY - 40
			and Toss.depth(Vector2.new(at.X, at.Z), info.rift) < 1
		then
			begin(root, humanoid, character)
		end
		return
	end
	if not usable() then
		release()
		return
	end
	local t = os.clock() - started
	-- The server never said yes (or never gave the diver back): let go rather than hang there.
	local rests = outcome
	if (not confirmed and t > 2.5) or (rests and t > rests.restAt + LastBreath.HOLD + 4) then
		release()
		return
	end
	if unlimp then
		-- Lying on the roof: physics has the body now.
		camera(humanoid, 0, dt)
		return
	end
	local move = humanoid.MoveDirection
	local steer = Vector3.zero
	if not rested and move.Magnitude > 0.05 then
		spot += Vector2.new(move.X, move.Z) * STEER * dt
		steer = facing:VectorToObjectSpace(Vector3.new(move.X, 0, move.Z))
	end
	local off = spot - Vector2.new(info.rift.cx, info.rift.cz)
	if off.Magnitude > FUNNEL then
		spot -= off.Unit * (off.Magnitude - FUNNEL) * math.min(1, dt * 1.5)
	end
	local height, speed = LastBreath.at(info.height, t, brakeAt)
	local state = tumble
	if state then
		state.speed = speed
		state.steer = steer
	end
	root.CFrame = CFrame.new(spot.X, info.roofY + height + ROOT_UP, spot.Y) * facing
	root.AssemblyLinearVelocity = Vector3.new(0, -speed, 0)
	root.AssemblyAngularVelocity = Vector3.zero
	local held = strings[character]
	if held then
		held.top.CFrame = CFrame.new(spot.X, info.cloudY, spot.Y)
	end
	local cloud = ash
	if cloud then
		cloud.CFrame = CFrame.new(spot.X, root.Position.Y - 40, spot.Y)
		local emitter = cloud:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			local fast = math.clamp(speed / Tumble.TOP_SPEED, 0, 1)
			emitter.Rate = (if Settings.get("lowGraphics") then 0.5 else 1) * (30 + 150 * fast)
		end
	end
	camera(humanoid, speed, dt)
	if not rested then
		local result = outcome
		if not result and not brakeAt and t >= LastBreath.timeToFall(info.height) then
			result = LastBreath.outcome(info.height, nil)
			outcome = result
		end
		if result and t >= result.restAt then
			-- (The speed the body had a moment before it stopped: what it slams into the roof with.)
			local _, before = LastBreath.at(info.height, math.max(0, result.restAt - 0.05), brakeAt)
			rest(result, before)
		end
	end
end

local function onState(payload: any)
	if type(payload) ~= "table" or payload.game ~= "rift" then
		return
	end
	local info = rift
	if payload.kind == "start" then
		confirmed = true
	elseif payload.kind == "refused" or payload.kind == "end" then
		-- Not a dive after all, or the rift is giving the diver back: the body is let go.
		release()
	elseif payload.kind == "brake" and diving and info and type(payload.at) == "number" then
		-- The server's moment is the one that counts: the rest of the dive is drawn from it.
		brakeAt = payload.at
		outcome = LastBreath.outcome(info.height, payload.at)
	elseif payload.kind == "rest" then
		if payload.crashed then
			Toasts.show("Too late.", "bad")
		else
			Toasts.show(
				string.format(
					"%s studs above the roof.%s",
					LastBreath.format(payload.gap or 0),
					if payload.newBest then "  Your closest yet." else ""
				),
				if payload.newBest then "good" else nil
			)
		end
	elseif payload.kind == "wave" and type(payload.rows) == "table" then
		local parts = {}
		for place, row in ipairs(payload.rows) do
			table.insert(
				parts,
				string.format(
					"%d. %s %s",
					place,
					tostring(row.name),
					if row.crashed then "fell" else LastBreath.format(row.gap or 0)
				)
			)
		end
		Toasts.show(table.concat(parts, "    "), if payload.place == 1 then "good" else nil)
	end
end

-- Everyone's dive, as the server marks it on their character -----------------------------------------------------

local labels: { [Model]: BillboardGui } = {}

local function showGap(character: Model)
	local gap = character:GetAttribute("DiveGap")
	local old = labels[character]
	if old then
		old:Destroy()
		labels[character] = nil
	end
	local head = character:FindFirstChild("Head")
	if type(gap) ~= "number" or not head or not head:IsA("BasePart") then
		return
	end
	local gui = Create("BillboardGui", {
		Name = "DiveGap",
		Adornee = head,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 400,
		Size = UDim2.fromScale(5, 1.5),
		StudsOffset = Vector3.new(0, 2.6, 0),
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	}) :: BillboardGui
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = LastBreath.format(gap),
		TextColor3 = Color3.fromRGB(235, 238, 244),
		TextStrokeTransparency = 0.3,
		TextScaled = true,
		FontFace = WorldFont.face(Enum.Font.GothamBlack),
		Parent = gui,
	})
	labels[character] = gui
end

local function showPose(character: Model)
	-- This player's own body is posed as it flies (above), a beat ahead of the server's word.
	if character == LocalPlayer.Character then
		return
	end
	local state = character:GetAttribute("Dive")
	local info = rift
	if state == "fall" then
		local seed = character:GetAttribute("DiveSeed")
		local tumbling = Tumble.new(if type(seed) == "number" then seed else 1)
		local entry = { state = tumbling, startedAt = os.clock(), brakeAt = nil :: number? }
		others[character] = entry
		PoseController.playProcedural(character, TRACK, function(elapsed: number)
			-- (Their speed, from the same curve: close enough to the diver's own.)
			local height = if info then info.height else 650
			local _, speed = LastBreath.at(height, os.clock() - entry.startedAt, entry.brakeAt)
			tumbling.speed = speed
			return Tumble.sample(tumbling, elapsed)
		end, { fadeIn = 0.25 })
	elseif state == "brake" or state == "caught" then
		local entry = others[character]
		if entry and not entry.brakeAt then
			entry.brakeAt = os.clock() - entry.startedAt
			Tumble.catch(entry.state)
		end
		if info then
			hangString(character, info.cloudY)
		end
	elseif state == "crash" then
		cutString(character)
		PoseController.stop(character, TRACK, 0.05)
		PoseController.play(character, "collapseAccident", { fadeIn = 0.05 })
		others[character] = nil
	else
		cutString(character)
		stopClips(character)
		others[character] = nil
	end
end

local function watch(character: Model)
	character:GetAttributeChangedSignal("Dive"):Connect(function()
		showPose(character)
	end)
	character:GetAttributeChangedSignal("DiveGap"):Connect(function()
		showGap(character)
	end)
	character.Destroying:Once(function()
		local gui = labels[character]
		if gui then
			gui:Destroy()
			labels[character] = nil
		end
		cutString(character)
		others[character] = nil
	end)
	showPose(character)
	showGap(character)
end

local function follow(player: Player)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

-- Keeps everyone else's string over their body (they hang where their client flies them).
local function keepStrings()
	local info = rift
	if not info then
		return
	end
	for character, held in pairs(strings) do
		if character ~= LocalPlayer.Character then
			local torso = character:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				held.top.CFrame = CFrame.new(torso.Position.X, info.cloudY, torso.Position.Z)
			end
		end
	end
end

-- Is this player in a dive now (for checks)?
function DiveController.diving(): boolean
	return diving
end

-- The catch, as a press would ask for it (for checks).
function DiveController.brake()
	press()
end

function DiveController.init()
	readRift()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(readRift)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(readRift)
	Net.event("LobbyGameState").OnClientEvent:Connect(onState)
	-- One press is the catch: jump (a key, the jump button, a gamepad), a click, or a tap anywhere.
	UserInputService.JumpRequest:Connect(press)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			press()
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
	-- After the simulation step, so the body is where the dive puts it when the frame is drawn.
	RunService.PostSimulation:Connect(step)
	RunService.RenderStepped:Connect(keepStrings)
end

return DiveController
