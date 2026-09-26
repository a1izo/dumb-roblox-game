-- Specter's Eyes for the Cultist who accepted the deal: pick the closest player in front of
-- the camera (within range) and ask the server to read their name.

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
				if offset.Magnitude <= Config.EYES_RANGE then
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

function EyesController.read()
	local private = ClientState.private
	if not private.eyes or not ClientState.isLiving() or ClientState.phase() ~= "Investigation" then
		return
	end
	if (private.eyes.readsLeft or 0) <= 0 then
		Toasts.show("Your eyes have no reads left.", "bad")
		return
	end
	local target = findTarget()
	if not target then
		Toasts.show("Look at a player within " .. Config.EYES_RANGE .. " studs.", "bad")
		return
	end
	EyesRequest:FireServer({ action = "read", userId = target })
end

-- The deal costs the Cultist's life, so it asks for confirmation first.
function EyesController.deal()
	local private = ClientState.private
	if ClientState.role() ~= "Follower" or not private.canDeal or ClientState.phase() ~= "Investigation" then
		return
	end
	-- It costs your life, so the confirm button has to be held.
	Kit.confirm({
		title = Terms.f("Accept {eyes}?"),
		body = Terms.f(
			"Up close, you can read up to {reads} real names ({small} on servers under {below} players). "
				.. "Your eyes glow red while reading, and you die at the end of the next round.",
			{
				reads = Config.EYES_READS,
				small = Config.EYES_READS_SMALL_SERVER,
				below = Config.EYES_SMALL_SERVER_BELOW,
			}
		),
		confirm = "Accept the deal",
		variant = "danger",
		hold = 1,
		onConfirm = function()
			EyesRequest:FireServer({ action = "deal" })
		end,
	})
end

return EyesController
