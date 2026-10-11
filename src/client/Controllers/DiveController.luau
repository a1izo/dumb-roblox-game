--!strict
-- Last breath on this client: the dive into the lobby's rift (rules: Shared/LobbyGames/LastBreath; the
-- score is the server's, Services/LobbyRift).
--
-- Going over the rim starts it: once this player's character is inside the rift and under its rim, the
-- client takes the body (it owns it), tells the server, and flies the fall itself along the rules' curve,
-- so what the player sees is exactly what is scored. A little steering is allowed, and the rift's draught
-- keeps divers over the landing roof. One press brakes (jump, a click or a tap): the body flares, slows and
-- hangs there, or was too late and lands on the roof. Then the rift gives the diver back at the rim. No
-- numbers are shown on the way down: only the roof coming up.
--
-- Everyone else's dive is drawn from what the server puts on their character: attribute Dive ("fall",
-- "brake", "caught", "crash") poses the body, and DiveGap (the studs left) floats over the head of whoever
-- hangs there, for all to read.

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

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local ClientState = require(script.Parent.Parent.ClientState)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local DiveController = {}

local LocalPlayer = Players.LocalPlayer
local request = Net.event("LobbyGame")

local TAG = "LRift"
local ROOT_UP = 3 -- the root's middle above the soles
local STEER = 9 -- studs a second a diver can drift
local FUNNEL = 11 -- studs from the rift's axis beyond which the draught pulls a diver back in
local FALL_FOV = 84
local CLIPS = { "dive", "diveBrake", "diveCaught", "collapseAccident" }

type Rift = { rift: Toss.Rift, rimY: number, roofY: number, height: number }

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

local function readRift()
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do
		local rimY, roofY = part:GetAttribute("RimY"), part:GetAttribute("RoofY")
		if part:IsDescendantOf(workspace) and type(rimY) == "number" and type(roofY) == "number" then
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

local function setFov(value: number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if value then
		savedFov = savedFov or camera.FieldOfView
		TweenService:Create(camera, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { FieldOfView = value }):Play()
	elseif savedFov then
		TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { FieldOfView = savedFov }):Play()
		savedFov = nil
	end
end

local function stopClips(character: Model?)
	for _, clip in ipairs(CLIPS) do
		PoseController.stop(character, clip, 0.25)
	end
end

-- Lets the body go (the dive is over, or was refused).
local function release()
	if not diving then
		return
	end
	diving = false
	local character, root, humanoid = body()
	if humanoid then
		humanoid.PlatformStand = false
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	stopClips(character)
	setFov(nil)
	if wind then
		wind:Destroy()
		wind = nil
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
	request:FireServer({ game = "rift", action = "enter" })
	PoseController.play(character, "dive", { fadeIn = 0.3 })
	setFov(FALL_FOV)
	wind = Sfx.play("gameDiveWind", { volume = 0.8 })
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
	PoseController.stop(character, "dive", 0.15)
	PoseController.play(character, "diveBrake", { fadeIn = 0.1 })
	setFov(nil)
end

local function rest(result: LastBreath.Outcome)
	rested = true
	local character = LocalPlayer.Character
	if wind then
		wind:Destroy()
		wind = nil
	end
	setFov(nil)
	if result.crashed then
		stopClips(character)
		PoseController.play(character, "collapseAccident", { fadeIn = 0.05 })
		Sfx.play("gameDiveCrash")
	else
		PoseController.stop(character, "diveBrake", 0.3)
		PoseController.play(character, "diveCaught", { fadeIn = 0.3 })
	end
end

local function usable(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching() and not ClientState.isAway()
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
	local move = humanoid.MoveDirection
	if not rested and move.Magnitude > 0.05 then
		spot += Vector2.new(move.X, move.Z) * STEER * dt
	end
	local off = spot - Vector2.new(info.rift.cx, info.rift.cz)
	if off.Magnitude > FUNNEL then
		spot -= off.Unit * (off.Magnitude - FUNNEL) * math.min(1, dt * 1.5)
	end
	local height, speed = LastBreath.at(info.height, t, brakeAt)
	root.CFrame = CFrame.new(spot.X, info.roofY + height + ROOT_UP, spot.Y) * facing
	root.AssemblyLinearVelocity = Vector3.new(0, -speed, 0)
	root.AssemblyAngularVelocity = Vector3.zero
	if not rested then
		local result = outcome
		if not result and not brakeAt and t >= LastBreath.timeToFall(info.height) then
			result = LastBreath.outcome(info.height, nil)
			outcome = result
		end
		if result and t >= result.restAt then
			rest(result)
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
	if state == "fall" then
		PoseController.play(character, "dive", { fadeIn = 0.3 })
	elseif state == "brake" then
		PoseController.stop(character, "dive", 0.15)
		PoseController.play(character, "diveBrake", { fadeIn = 0.1 })
	elseif state == "caught" then
		PoseController.stop(character, "diveBrake", 0.3)
		PoseController.play(character, "diveCaught", { fadeIn = 0.3 })
	elseif state == "crash" then
		stopClips(character)
		PoseController.play(character, "collapseAccident", { fadeIn = 0.05 })
	else
		stopClips(character)
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

-- Is this player in a dive now (for checks)?
function DiveController.diving(): boolean
	return diving
end

function DiveController.init()
	readRift()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(readRift)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(readRift)
	Net.event("LobbyGameState").OnClientEvent:Connect(onState)
	-- One press brakes: jump (a key, the jump button, a gamepad), a click, or a tap anywhere.
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
end

return DiveController
