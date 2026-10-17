-- Duo emotes on this client (DuoService decides who and when):
--   asked     the "Join?" card (UI/DuoPanel); the answer goes back to the server
--   a rally   Match Point on both bodies at once, on every screen from the same start (the server's clock):
--             each holds a racket (Anim/EmoteProps) and a ball flies between them on RALLY, the timetable of
--             the clips' swings, until the smash sends it past the second player
--   a chain   Cuffed Together: while a body holds a "DuoChain" link, its chained arm hangs towards the other
--             (a clip on that arm only, so the walk goes on beneath) and a chain hangs between the wrists; the
--             player who follows walks after the leader by themselves, and a jump of either breaks it

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteProps = require(Shared:WaitForChild("Anim"):WaitForChild("EmoteProps"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)
local EmoteController = require(script.Parent.EmoteController)
local DuoPanel = require(script.Parent.Parent.UI.DuoPanel)

local DuoRemote = Net.event("Duo")
local LocalPlayer = Players.LocalPlayer

local DuoController = {}

-- The rally's timetable (seconds into the clips): who hits the ball when. The first player serves, the
-- last hit is the smash; then the ball flies past the second player and lies where it falls.
DuoController.RALLY = {
	{ at = 0.35, by = "a" },
	{ at = 1.15, by = "b" },
	{ at = 1.95, by = "a" },
	{ at = 2.75, by = "b" },
	{ at = 3.55, by = "a" },
	{ at = 4.35, by = "b" },
	{ at = 5.15, by = "a" },
}
local PAST = 0.55 -- seconds the smash takes to fly past
local LENGTH = 6.2

-- Where the racket's strings are, on a body holding it in the right hand: the racket's hold (Anim/EmoteProps)
-- and the strings' middle on the model (0.52 studs up from its pivot once scaled; art/scripts/emotes/duos.py).
local held = EmoteProps.of("matchPointServe")[1]
local STRINGS = (if held then held.at else CFrame.new(0, -1.05, 0)) * CFrame.new(0, 0.52, 0)
local function racketHead(character: Model): Vector3?
	local arm = character:FindFirstChild("Right Arm")
	return if arm and arm:IsA("BasePart") then (arm.CFrame * STRINGS).Position else nil
end

local function leftHand(character: Model): Vector3?
	local arm = character:FindFirstChild("Left Arm")
	return if arm and arm:IsA("BasePart") then (arm.CFrame * CFrame.new(0, -1.1, 0)).Position else nil
end

local function ballModel(): Model
	local model = ModelLibrary.get("TennisBall")
	if model then
		local _, size = model:GetBoundingBox()
		local biggest = math.max(size.X, size.Y, size.Z)
		if biggest > 0 then
			model:ScaleTo(model:GetScale() * 0.35 / biggest)
		end
	else
		model = Create("Model", { Name = "TennisBall" }) :: Model
		local part = Create("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.35, 0.35),
			Color = Color3.fromRGB(206, 224, 74),
			Material = Enum.Material.Fabric,
			Parent = model,
		})
		model.PrimaryPart = part
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model.Name = "RallyBall"
	return model
end

-- Where the ball is `t` seconds into the rally.
function DuoController.ballAt(t: number, a: Model, b: Model): Vector3?
	local rally = DuoController.RALLY
	local who = { a = a, b = b }
	if t < rally[1].at then
		-- The toss: up out of the left hand and down onto the racket.
		local from, to = leftHand(a), racketHead(a)
		if not from or not to then
			return nil
		end
		local u = t / rally[1].at
		return from:Lerp(to, u) + Vector3.new(0, 2.2 * 4 * u * (1 - u), 0)
	end
	for index = 1, #rally - 1 do
		local hit, next = rally[index], rally[index + 1]
		if t < next.at then
			local from, to = racketHead(who[hit.by]), racketHead(who[next.by])
			if not from or not to then
				return nil
			end
			local u = (t - hit.at) / (next.at - hit.at)
			return from:Lerp(to, u) + Vector3.new(0, 2.4 * 4 * u * (1 - u), 0)
		end
	end
	-- The smash: low and hard, past the second player, then on the floor.
	local last = rally[#rally]
	local from = racketHead(a)
	local rootB = b:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootA = a:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not from or not rootB or not rootA then
		return nil
	end
	local away = (rootB.Position - rootA.Position) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, -1)
	local to = rootB.Position + away * 7 + rootB.CFrame.RightVector * 2 - Vector3.new(0, 2.8, 0)
	local u = math.clamp((t - last.at) / PAST, 0, 1)
	return from:Lerp(to, u) + Vector3.new(0, 0.5 * 4 * u * (1 - u), 0)
end

local function rally(payload)
	local a, b = payload.a, payload.b
	if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" or type(payload.at) ~= "number" then
		return
	end
	-- Everyone starts from the same moment, however late the message came.
	local late = math.max(0, workspace:GetServerTimeNow() - payload.at)
	local startAt = os.clock() - late
	for _, pair in ipairs({ { a, "matchPointServe" }, { b, "matchPointReturn" } }) do
		local character, clip = pair[1], pair[2]
		PoseController.stopEmotes(character)
		PoseController.play(character, clip, {
			emote = true,
			fadeIn = 0.15,
			fadeOut = 0.3,
			startAt = startAt,
			duration = ClipPlayer.length(clip) + 0.6 - late,
		})
		EmoteController.dress(character, clip)
	end
	EmoteController.sound(a, "matchPointServe", Players:GetPlayerFromCharacter(a) == LocalPlayer)
	local ball = ballModel()
	ball.Parent = workspace.CurrentCamera
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startAt
		local playing = PoseController.isPlaying(a, "matchPointServe")
			and PoseController.isPlaying(b, "matchPointReturn")
		if t > LENGTH + 0.6 or not a.Parent or not b.Parent or (t > 0.5 and not playing) then
			connection:Disconnect()
			ball:Destroy()
			return
		end
		local at = DuoController.ballAt(t, a, b)
		if at then
			ball:PivotTo(CFrame.new(at) * CFrame.Angles(t * 9, t * 7, 0))
		end
	end)
end

-- The chain between two cuffed wrists, while the link lasts.
local chains: { [Model]: () -> () } = {}

local function watchChain(character: Model)
	local function changed()
		local link = character:FindFirstChild("DuoChain")
		local stop = chains[character]
		if stop and not (link and link:IsA("ObjectValue")) then
			chains[character] = nil
			stop()
			return
		end
		if not link or not link:IsA("ObjectValue") or stop then
			return
		end
		local partner = link.Value
		local lead = link:GetAttribute("Role") == "lead"
		local clip = if lead then "cuffedLead" else "cuffedFollow"
		PoseController.play(character, clip, { fadeIn = 0.3, fadeOut = 0.3 })
		local parts: { Instance } = {}
		local arm = character:FindFirstChild(if lead then "Left Arm" else "Right Arm")
		local otherArm = partner and (partner :: Model):FindFirstChild(if lead then "Right Arm" else "Left Arm")
		-- The leader's body draws the chain, so it is drawn once.
		if lead and arm and otherArm then
			local a0 = Create("Attachment", { Name = "ChainEnd", Position = Vector3.new(0, -0.8, 0), Parent = arm })
			local a1 =
				Create("Attachment", { Name = "ChainEnd", Position = Vector3.new(0, -0.8, 0), Parent = otherArm })
			local beam = Create("Beam", {
				Name = "DuoChainBeam",
				Attachment0 = a0,
				Attachment1 = a1,
				Color = ColorSequence.new(Color3.fromRGB(150, 152, 160)),
				Width0 = 0.12,
				Width1 = 0.12,
				Segments = 12,
				CurveSize0 = -1.2,
				CurveSize1 = 1.2,
				FaceCamera = true,
				LightInfluence = 1,
				Parent = arm,
			})
			table.insert(parts, a0)
			table.insert(parts, a1)
			table.insert(parts, beam)
		end
		local follow: RBXScriptConnection? = nil
		local jump: RBXScriptConnection? = nil
		local jumpAsked: RBXScriptConnection? = nil
		if character == LocalPlayer.Character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- A jump (asked for, or happening) lets go.
				jump = humanoid.StateChanged:Connect(function(_, state)
					if state == Enum.HumanoidStateType.Jumping then
						DuoRemote:FireServer({ action = "break" })
					end
				end)
				jumpAsked = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
					if humanoid.Jump then
						DuoRemote:FireServer({ action = "break" })
					end
				end)
				if not lead then
					-- Walk after the leader, a step to their left (where the chain reaches).
					local nextMove = 0
					follow = RunService.Heartbeat:Connect(function()
						local leaderRoot = partner and (partner :: Model):FindFirstChild("HumanoidRootPart")
						local root = character:FindFirstChild("HumanoidRootPart")
						if not leaderRoot or not root or os.clock() < nextMove then
							return
						end
						nextMove = os.clock() + 0.15
						local spot = ((leaderRoot :: BasePart).CFrame * CFrame.new(-2.6, 0, 0.6)).Position
						if ((root :: BasePart).Position - spot).Magnitude > 1.2 then
							humanoid:MoveTo(spot)
						end
					end)
				end
			end
		end
		chains[character] = function()
			PoseController.stop(character, clip)
			for _, item in ipairs(parts) do
				item:Destroy()
			end
			if follow then
				follow:Disconnect()
			end
			if jump then
				jump:Disconnect()
			end
			if jumpAsked then
				jumpAsked:Disconnect()
			end
		end
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "DuoChain" then
			changed()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "DuoChain" then
			changed()
		end
	end)
	character.Destroying:Once(function()
		local stop = chains[character]
		chains[character] = nil
		if stop then
			stop()
		end
	end)
	changed()
end

local function onEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "ask" then
		DuoPanel.ask(
			tostring(payload.from),
			tostring(payload.emote),
			tonumber(payload.seconds) or 15,
			function(yes: boolean)
				DuoRemote:FireServer({ action = if yes then "accept" else "decline" })
			end
		)
	elseif payload.kind == "rally" then
		rally(payload)
	end
end

function DuoController.init()
	DuoRemote.OnClientEvent:Connect(onEvent)
	Characters.each(watchChain)
end

return DuoController
