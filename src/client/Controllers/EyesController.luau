-- Staring, for Diavolo and the Muertos: pick the closest player in front of the camera (within
-- range) and ask the server to start a stare. The server breaks it if you move or lose sight; your
-- eyes glow for everyone while it lasts. A Muerto can also take the Oculus deal here, which makes a
-- read fast and far-reaching and costs their life a few minutes later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.UI.Kit)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Characters = require(script.Parent.Parent.Characters)

local EyesRequest = Net.event("EyesRequest")
local LocalPlayer = Players.LocalPlayer

local EyesController = {}

local MAX_ANGLE = math.rad(18)

local function range(): number
	return if ClientState.private.eyes then Config.OCULUS_RANGE else Config.STARE_RANGE
end

-- The best target: a living player close by, nearest to the aim direction.
local function findTarget(): number?
	local camera = workspace.CurrentCamera
	local myCharacter = LocalPlayer.Character
	local myHead = if myCharacter then myCharacter:FindFirstChild("Head") else nil
	if not camera or not myHead or not myHead:IsA("BasePart") then
		return nil
	end
	local aim: Vector3
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mouse = UserInputService:GetMouseLocation()
		aim = camera:ViewportPointToRay(mouse.X, mouse.Y).Direction.Unit
	else
		aim = camera.CFrame.LookVector
	end
	local best, bestAngle = nil, MAX_ANGLE
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			local character = Characters.byUserId(entry.userId)
			local head = if character then character:FindFirstChild("Head") else nil
			if head and head:IsA("BasePart") then
				local offset = head.Position - myHead.Position
				if offset.Magnitude <= range() then
					local toTarget = (head.Position - camera.CFrame.Position).Unit
					local angle = math.acos(math.clamp(aim:Dot(toTarget), -1, 1))
					if angle < bestAngle then
						best = entry.userId
						bestAngle = angle
					end
				end
			end
		end
	end
	return best
end

-- Whether staring makes sense for you right now (Diavolo or a Muerto, alive, in free roam).
-- Staring is the Oculus deal's: only a Muerto who took it can.
function EyesController.canStare(): boolean
	return ClientState.isLiving() and ClientState.phase() == "Investigation" and ClientState.private.eyes ~= nil
end

function EyesController.stare()
	if not EyesController.canStare() then
		return
	end
	local target = findTarget()
	if not target then
		Toasts.show("Look at a player within " .. range() .. " studs.", "bad")
		return
	end
	-- Turned to face them where you stand (the server counts only a stare at someone in front of you).
	local character = LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local other = Characters.byUserId(target)
	local head = if other then other:FindFirstChild("Head") else nil
	if root and root:IsA("BasePart") and head and head:IsA("BasePart") then
		local at = root.Position
		root.CFrame = CFrame.lookAt(at, Vector3.new(head.Position.X, at.Y, head.Position.Z))
	end
	EyesRequest:FireServer({ action = "stare", userId = target })
	Toasts.show(
		if ClientState.private.eyes then "Reading..." else "Staring... stand still and keep them in sight.",
		"secret"
	)
end

-- The deal costs the Muerto's life, so it asks first.
function EyesController.deal()
	local private = ClientState.private
	if ClientState.role() ~= "Follower" or not private.canDeal or ClientState.phase() ~= "Investigation" then
		return
	end
	Kit.confirm({
		title = Terms.f("Accept {eyes}?"),
		body = Terms.f(
			"A {ritual}-second ritual, eyes blazing, in plain sight. Then you read a name in {read} s from up to "
				.. "{range} studs. You die after {minutes} minutes of investigation.",
			{
				ritual = Config.OCULUS_RITUAL,
				read = Config.OCULUS_READ_TIME,
				range = Config.OCULUS_RANGE,
				minutes = math.floor(Config.OCULUS_LIFESPAN / 60 + 0.5),
			}
		),
		confirm = "Accept the deal",
		variant = "danger",
		onConfirm = function()
			EyesRequest:FireServer({ action = "deal" })
		end,
	})
end

function EyesController.init()
	Net.event("EyesName").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.failed == "moved" then
			Toasts.show("You moved: the stare broke.", "bad")
		elseif payload.failed == "lost" then
			Toasts.show("You lost sight of them: the stare broke.", "bad")
		end
	end)
end

return EyesController
