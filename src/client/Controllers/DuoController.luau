-- Duo emotes on this client (DuoService decides who and when):
--   asked     the "Join?" card (UI/DuoPanel); the answer goes back to the server
--   a walk    asked into a rally, this player walks to their spot facing the one who asked
--   a rally   Match Point on both bodies at once, on every screen from the same start (the server's clock):
--             each holds a racket (Anim/EmoteProps) on a ready loop, and the ball flies between them as
--             DuoService says; the player it goes to presses (F, ButtonX, the HIT button) as it reaches their
--             racket, a forehand meets it on every screen, and the first miss sends it past and ends the rally
--   a chain   Cuffed Together: while a body holds a "DuoChain" link, its chained arm hangs towards the other
--             (a clip on that arm only, so the walk goes on beneath) and a chain hangs between the wrists; the
--             player who follows walks after the leader by themselves, and a jump of either breaks it

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local EmoteProps = require(Shared:WaitForChild("Anim"):WaitForChild("EmoteProps"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))
local Bindings = require(Shared:WaitForChild("Bindings"))
local ClientState = require(script.Parent.Parent.ClientState)

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)
local EmoteController = require(script.Parent.EmoteController)
local DuoPanel = require(script.Parent.Parent.UI.DuoPanel)

local DuoRemote = Net.event("Duo")
local LocalPlayer = Players.LocalPlayer

local DuoController = {}

-- The rally's strokes (art/scripts/emotes/duos.py), laid over each player's ready loop: the serve hits at
-- SERVE_HIT into its clip, a forehand strikes at SWING_HIT into its own (so it is started that long before the
-- ball arrives).
local SERVE_HIT, SWING_HIT = 0.6, 0.55
local PAST = 0.7 -- seconds a missed ball takes to fly past and land

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

-- One rally on this screen (DuoService keeps the ball and says each hit and the miss, with the server times the
-- ball leaves one racket and reaches the other).
type Flight = { from: Model, to: Model, leave: number, arrive: number, toss: boolean, past: boolean }
type Rally = {
	a: Model,
	b: Model,
	flight: Flight,
	hits: number,
	ball: Model,
	label: TextLabel?,
	mine: boolean,
	pressedFor: number?,
	ended: boolean,
	prompt: ScreenGui?,
}
local rallies: { [Model]: Rally } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function stroke(character: Model, clip: string)
	if character.Parent then
		PoseController.play(character, clip, { fadeIn = 0.08, fadeOut = 0.2 })
	end
end

-- The forehand of the one the ball goes to, started so its strike meets the ball (a swing at nothing when it is
-- a miss: the server says so a moment later).
local function swingFor(flight: Flight)
	task.delay(math.max(0, flight.arrive - SWING_HIT - now()), function()
		stroke(flight.to, "matchPointSwing")
	end)
end

-- Where the ball is now: tossed up to the server's racket, flying racket to racket on an arc, or gone past the
-- one who missed and down on the floor.
local function ballAt(flight: Flight, t: number): Vector3?
	local from = if flight.toss then leftHand(flight.from) else racketHead(flight.from)
	local to = racketHead(flight.to)
	if not from or not to then
		return nil
	end
	if flight.toss and t < flight.leave then
		local u = math.clamp(1 - (flight.leave - t) / SERVE_HIT, 0, 1)
		local racket = racketHead(flight.from) or from
		return from:Lerp(racket, u) + Vector3.new(0, 2.2 * 4 * u * (1 - u), 0)
	end
	local start = if flight.toss then (racketHead(flight.from) or from) else from
	local u = (t - flight.leave) / math.max(0.05, flight.arrive - flight.leave)
	if u <= 1 or not flight.past then
		u = math.clamp(u, 0, 1)
		return start:Lerp(to, u) + Vector3.new(0, 2.4 * 4 * u * (1 - u), 0)
	end
	-- past the racket: on the same way, dropping to the floor and rolling a little
	local way = (to - start) * Vector3.new(1, 0, 1)
	way = if way.Magnitude > 0.01 then way.Unit else Vector3.new(0, 0, -1)
	local root = flight.to:FindFirstChild("HumanoidRootPart") :: BasePart?
	local floorY = if root then root.Position.Y - 2.85 else to.Y - 2
	local k = math.clamp((t - flight.arrive) / PAST, 0, 1)
	local ground = to + way * (6 * k + 1.5 * math.max(0, (t - flight.arrive - PAST)) ^ 0.5)
	return Vector3.new(ground.X, to.Y + (floorY - to.Y) * k * k, ground.Z)
end

-- The rally's hit keys: F and ButtonX unless the player set their own (Shared/Bindings "rallyHit").
local function hitKeys(): { Enum.KeyCode }
	local profile = ClientState.profile
	local saved = profile and profile.keybinds or nil
	local keys = {}
	for _, platform in ipairs(Bindings.PLATFORMS) do
		for _, name in ipairs(Bindings.keys("rallyHit", platform, saved)) do
			local ok, key = pcall(function()
				return (Enum.KeyCode :: any)[name]
			end)
			if ok and key then
				table.insert(keys, key)
			end
		end
	end
	return keys
end

local function hidePrompt(rally: Rally)
	if rally.prompt then
		rally.prompt:Destroy()
		rally.prompt = nil
	end
end

-- For the player the ball is coming to: a ring closing on the moment to press, and the key.
local function showPrompt(rally: Rally)
	hidePrompt(rally)
	local gui = Create("ScreenGui", { Name = "RallyPrompt", ResetOnSpawn = false, IgnoreGuiInset = true }) :: ScreenGui
	local ring = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(240, 240),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ring })
	Create("UIStroke", { Color = Color3.fromRGB(236, 232, 222), Thickness = 3, Parent = ring })
	local target = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(70, 70),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = target })
	Create("UIStroke", { Color = Color3.fromRGB(206, 224, 74), Thickness = 4, Parent = target })
	Create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(160, 40),
		BackgroundTransparency = 1,
		Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			then "HIT"
			else "HIT  [" .. (hitKeys()[1] or Enum.KeyCode.F).Name .. "]",
		TextColor3 = Color3.fromRGB(236, 232, 222),
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		Parent = gui,
	})
	gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	rally.prompt = gui
	local flight = rally.flight
	task.spawn(function()
		while rally.prompt == gui and gui.Parent do
			local left = flight.arrive - now()
			local size = 70 + math.max(0, left) * 170
			ring.Size = UDim2.fromOffset(size, size)
			if left < -0.2 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function bindPress(rally: Rally)
	ContextActionService:BindActionAtPriority("DGRallyHit", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local flight = rally.flight
		local me = LocalPlayer.Character
		if rally.ended or flight.to ~= me or rally.pressedFor == flight.arrive then
			return Enum.ContextActionResult.Sink
		end
		rally.pressedFor = flight.arrive
		hidePrompt(rally)
		DuoRemote:FireServer({ action = "hit", t = now() })
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value + 10, table.unpack(hitKeys()))
	ContextActionService:SetTitle("DGRallyHit", "HIT")
end

local function aimed(rally: Rally)
	swingFor(rally.flight)
	if rally.mine and rally.flight.to == LocalPlayer.Character then
		showPrompt(rally)
	end
	if rally.label then
		rally.label.Text = "RALLY " .. rally.hits
	end
end

local function rally(payload)
	local a, b = payload.a, payload.b
	if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" or type(payload.at) ~= "number" then
		return
	end
	if type(payload.serve) ~= "number" or type(payload.arrive) ~= "number" then
		return
	end
	local old = rallies[a]
	if old then
		old.ended = true
		old.ball:Destroy()
	end
	-- the ready loops (with the rackets), from the same start on every screen
	for _, pair in ipairs({ { a, "matchPointServe" }, { b, "matchPointReturn" } }) do
		local character, clip = pair[1], pair[2]
		PoseController.stopEmotes(character, "replaced")
		EmoteController.start(character, clip, {
			at = payload.at,
			own = Players:GetPlayerFromCharacter(character) == LocalPlayer,
		})
	end
	task.delay(math.max(0, payload.at - now()), function()
		stroke(a, "matchPointServing")
	end)
	local ball = ballModel()
	ball.Parent = workspace.CurrentCamera
	local label: TextLabel? = nil
	if ball.PrimaryPart then
		local board = Create("BillboardGui", {
			Size = UDim2.fromOffset(140, 34),
			StudsOffset = Vector3.new(0, 1.2, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Adornee = ball.PrimaryPart,
			Parent = ball,
		})
		label = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Color3.fromRGB(236, 232, 222),
			TextStrokeTransparency = 0.3,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			Parent = board,
		}) :: TextLabel
	end
	local mine = a == LocalPlayer.Character or b == LocalPlayer.Character
	local state: Rally = {
		a = a,
		b = b,
		flight = { from = a, to = b, leave = payload.serve, arrive = payload.arrive, toss = true, past = false },
		hits = 1,
		ball = ball,
		label = label,
		mine = mine,
		pressedFor = nil,
		ended = false,
		prompt = nil,
	}
	rallies[a] = state
	if mine then
		bindPress(state)
	end
	aimed(state)
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = now()
		if not a.Parent or not b.Parent or not ball.Parent then
			connection:Disconnect()
			return
		end
		local at = ballAt(state.flight, t)
		if at then
			ball:PivotTo(CFrame.new(at) * CFrame.Angles(t * 9, t * 7, 0))
		end
	end)
end

local function rallyHit(payload)
	local state = rallies[payload.a]
	if not state or state.ended or type(payload.at) ~= "number" or type(payload.arrive) ~= "number" then
		return
	end
	local from = if payload.by == "a" then state.a else state.b
	local to = if payload.by == "a" then state.b else state.a
	state.flight = { from = from, to = to, leave = payload.at, arrive = payload.arrive, toss = false, past = false }
	state.hits = if type(payload.hits) == "number" then payload.hits else state.hits + 1
	hidePrompt(state)
	aimed(state)
end

local function rallyMiss(payload)
	local state = rallies[payload.a]
	if not state or state.ended then
		return
	end
	state.ended = true
	state.flight.past = true
	hidePrompt(state)
	if state.mine then
		ContextActionService:UnbindAction("DGRallyHit")
	end
	local loser = if payload.by == "a" then state.a else state.b
	local winner = if payload.by == "a" then state.b else state.a
	if state.label then
		state.label.Text = "RALLY " .. (if type(payload.hits) == "number" then payload.hits else state.hits)
	end
	task.delay(math.max(0, state.flight.arrive - now()), function()
		stroke(loser, "matchPointLost")
		stroke(winner, "matchPointWin")
		task.delay(1.6, function()
			for _, character in ipairs({ state.a, state.b }) do
				PoseController.stopEmotes(character, "finished")
			end
		end)
		task.delay(2.4, function()
			if rallies[state.a] == state then
				rallies[state.a] = nil
			end
			state.ball:Destroy()
		end)
	end)
end

-- The chain between two cuffed wrists, while the link lasts.
local chains: { [Model]: () -> () } = {}
-- Where the chain hangs from on a left wrist: the ring on the cuff's outer side (Anim/EmoteMeta cuffedLead; the
-- right wrist's is mirrored).
local CUFF_RING = Vector3.new(-0.68, -0.75, 0)

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
		-- A cuff on the chained wrist (Anim/EmoteMeta), for as long as the link lasts.
		local linked = true
		local removeCuff = EmoteController.dress(character, clip, function(): boolean
			return linked
		end)
		local parts: { Instance } = {}
		local arm = character:FindFirstChild(if lead then "Left Arm" else "Right Arm")
		local otherArm = partner and (partner :: Model):FindFirstChild(if lead then "Right Arm" else "Left Arm")
		-- The leader's body draws the chain, so it is drawn once: from the ring on each cuff's outer side.
		if lead and arm and otherArm then
			local a0 = Create("Attachment", { Name = "ChainEnd", Position = CUFF_RING, Parent = arm })
			local a1 = Create(
				"Attachment",
				{ Name = "ChainEnd", Position = CUFF_RING * Vector3.new(-1, 1, 1), Parent = otherArm }
			)
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
			for _, item in ipairs({ a0, a1, beam }) do
				item:SetAttribute("DGEmote", true) -- (a copy of the body leaves it out)
				table.insert(parts, item)
			end
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
			linked = false
			removeCuff()
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

-- Asked into a rally: this player walks to their spot and turns to face the one who asked (the server checks
-- they got there in time; pressing a move key takes the walk back, and the rally is called off).
local function walk(payload)
	if typeof(payload.to) == "Vector3" then
		EmoteController.walkTo(
			payload.to,
			if typeof(payload.face) == "Vector3" then payload.face else nil,
			tonumber(payload.seconds)
		)
	end
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
	elseif payload.kind == "rallyHit" then
		rallyHit(payload)
	elseif payload.kind == "rallyMiss" then
		rallyMiss(payload)
	elseif payload.kind == "walk" then
		walk(payload)
	end
end

function DuoController.init()
	DuoRemote.OnClientEvent:Connect(onEvent)
	Characters.each(watchChain)
end

return DuoController
