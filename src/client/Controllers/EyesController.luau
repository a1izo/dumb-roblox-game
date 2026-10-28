-- Staring, for Diavolo and the Muertos: pick the closest player in front of the camera (within
-- range) and ask the server to start a stare. The server breaks it if you move or lose sight; your
-- eyes glow for everyone while it lasts. A Muerto can also take the Oculus deal here, which makes a
-- read fast and far-reaching and costs their life a few minutes later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
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
	Toasts.show(if ClientState.private.eyes then "Reading" else "Staring. Stand still.", "secret")
end

-- The deal costs the Muerto's life, so it takes two presses: the first lays a white sheen over your
-- own character (on your screen only) that fades in CONFIRM_TIME seconds; pressing again before it
-- is gone makes the deal. No window, so the locked mouse never gets in the way. Everyone else only
-- ever sees the ritual itself.
local CONFIRM_TIME = 1.5
local armedUntil = 0
local sent = false
local sheen: Highlight? = nil

local function clearSheen()
	if sheen then
		sheen:Destroy()
		sheen = nil
	end
end

local function showSheen()
	clearSheen()
	local character = LocalPlayer.Character
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "LDealSheen"
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = LocalPlayer:WaitForChild("PlayerGui")
	sheen = highlight
	TweenService:Create(
		highlight,
		TweenInfo.new(CONFIRM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
	task.delay(CONFIRM_TIME, function()
		if sheen == highlight then
			clearSheen()
		end
	end)
end

function EyesController.deal()
	local private = ClientState.private
	if ClientState.role() ~= "Follower" or not private.canDeal or ClientState.phase() ~= "Investigation" then
		return
	end
	if sent then
		return -- already asked; waiting for the server
	end
	if os.clock() < armedUntil then
		armedUntil = 0
		sent = true
		clearSheen()
		EyesRequest:FireServer({ action = "deal" })
		-- Let it be asked again if the server turned it down (a meeting began, say).
		task.delay(Config.OCULUS_RITUAL + 2, function()
			sent = false
		end)
		return
	end
	armedUntil = os.clock() + CONFIRM_TIME
	showSheen()
end

function EyesController.init()
	Net.event("EyesName").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.failed == "moved" then
			Toasts.show("You moved. Try again.", "bad")
		elseif payload.failed == "lost" then
			Toasts.show("Lost sight. Try again.", "bad")
		end
	end)
end

return EyesController
