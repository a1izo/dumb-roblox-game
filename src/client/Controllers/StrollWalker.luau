-- Strolls walk by themselves (the owner's Q7/Q25, 2026-10-20/21): while this player's body has a stroll (the
-- server's "Stroll" attribute), it walks on its own along the way it faced when the stroll began, at the stroll's
-- pace (Cosmetics `pace`), its stroll's walk playing (LocomotionController). It slides along walls, turns back at a
-- ledge or a wall met head-on, and keeps going until the player steers (the keys, the stick, the touch pad), jumps,
-- uses a game action (Input/InputRouter: a note, a sabotage, the Eyes, an arrest) or a prompt, or another emote
-- takes over. Chat, Escape, shift lock, the camera, clicks and menus never end it. Only this player's own body:
-- Roblox replicates its walk to everyone.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local Net = require(Shared:WaitForChild("Net"))

local InputRouter = require(script.Parent.Parent.Input.InputRouter)
local StockControls = require(script.Parent.Parent.Input.StockControls)

local StrollWalker = {}

local EmoteRemote = Net.event("Emote")
local BIND = "DeathsGambit_StrollWalker"
local DEFAULT_PACE = 7
local STEER = 0.15 -- the player's own steering past this ends the stroll
local AHEAD = 2.6 -- studs ahead of the root the ground is looked for (a ledge: none within DROP)
local DROP = 6
local WALL = 2.0 -- studs ahead of the root a wall is looked for
local HEAD_ON = -0.8 -- a wall this square to the way (its normal against it) turns the walk back
local TURN = 0.4 -- seconds to turn back
-- Actions that are menus, not the game: they never end a stroll.
local MENUS = { quickChat = true, help = true, scratchpad = true, privateScreen = true }

type Walk = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	heading: Vector3,
	turning: { from: Vector3, to: Vector3, began: number }?,
	speed: number,
	oldSpeed: number,
	connections: { RBXScriptConnection },
	asked: boolean,
}

local walk: Walk? = nil

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false

-- The body stops walking by itself (its speed as it was).
local function stop()
	local w = walk
	if not w then
		return
	end
	walk = nil
	RunService:UnbindFromRenderStep(BIND)
	for _, connection in ipairs(w.connections) do
		connection:Disconnect()
	end
	if w.humanoid.Parent then
		w.humanoid:Move(Vector3.zero, false)
		if w.humanoid.WalkSpeed == w.speed then
			w.humanoid.WalkSpeed = w.oldSpeed
		end
	end
end

-- The player ended it: the server is asked (once) to end the stroll on every screen, and it stops here at once.
local function cancel()
	local w = walk
	if not w then
		return
	end
	if not w.asked then
		w.asked = true
		EmoteRemote:FireServer({ stop = true })
	end
	stop()
end

local function ground(w: Walk, from: Vector3): boolean
	params.FilterDescendantsInstances = { w.character, workspace.CurrentCamera }
	return workspace:Raycast(from, Vector3.new(0, -(DROP + 3.5), 0), params) ~= nil
end

local function step(w: Walk)
	if not w.root.Parent or not w.humanoid.Parent or w.humanoid.Health <= 0 then
		stop()
		return
	end
	-- the player's own steering, or a jump: the stroll ends (StockControls reads Roblox's own controls)
	if StockControls.moveVector().Magnitude > STEER or w.humanoid.Jump then
		cancel()
		return
	end
	local now = os.clock()
	if w.turning then
		local u = math.clamp((now - w.turning.began) / TURN, 0, 1)
		-- (half round to the right, so it never passes through the way it came)
		local right = Vector3.new(-w.turning.from.Z, 0, w.turning.from.X)
		local angle = u * math.pi
		w.heading = flat(w.turning.from * math.cos(angle) + right * math.sin(angle))
		if u >= 1 then
			w.heading = w.turning.to
			w.turning = nil
		end
	else
		local at = w.root.Position
		local ledge = not ground(w, at + w.heading * AHEAD)
		params.FilterDescendantsInstances = { w.character, workspace.CurrentCamera }
		local hit = workspace:Raycast(at, w.heading * WALL, params)
		local headOn = hit ~= nil and hit.Normal:Dot(w.heading) < HEAD_ON
		if ledge or headOn then
			w.turning = { from = w.heading, to = -w.heading, began = now }
		end
	end
	w.humanoid:Move(w.heading, false)
end

local function begin(character: Model, clip: string)
	stop()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local item = EmoteInfo.of(clip).item
	local pace = if item and type(item.pace) == "number" then item.pace else DEFAULT_PACE
	local w: Walk = {
		character = character,
		humanoid = humanoid,
		root = root,
		heading = flat(root.CFrame.LookVector),
		turning = nil,
		speed = pace,
		oldSpeed = humanoid.WalkSpeed,
		connections = {},
		asked = false,
	}
	-- (frozen, as at a meeting: it does not walk)
	if humanoid.WalkSpeed <= 0 or root.Anchored then
		return
	end
	humanoid.WalkSpeed = pace
	walk = w
	table.insert(w.connections, UserInputService.JumpRequest:Connect(cancel))
	table.insert(
		w.connections,
		InputRouter.Ran:Connect(function(id: string)
			if not MENUS[id] then
				cancel()
			end
		end)
	)
	table.insert(w.connections, ProximityPromptService.PromptTriggered:Connect(cancel))
	-- (after Roblox's controls have moved the body for this frame: this move wins)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Character.Value + 5, function()
		if walk == w then
			step(w)
		end
	end)
end

local function watch(character: Model)
	local function changed()
		local clip = character:GetAttribute("Stroll")
		if type(clip) == "string" then
			begin(character, clip)
		elseif walk and walk.character == character then
			stop()
		end
	end
	character:GetAttributeChangedSignal("Stroll"):Connect(changed)
	changed()
end

-- (for the harness: the way the stroll walks now, or nil when it is not walking)
function StrollWalker.heading(): Vector3?
	return if walk then walk.heading else nil
end

function StrollWalker.init()
	local player = Players.LocalPlayer
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		stop()
		watch(character)
	end)
end

return StrollWalker
