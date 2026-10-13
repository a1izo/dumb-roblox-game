-- Emotes. The player asks the server, which checks the emote (owned from the shop, or the Emote Pack
-- pass) and tells every client that may see it; each client then plays the Blender clip on that
-- character. Moving stops the emote (LocomotionController). Two shop gestures hold something in the
-- right hand while they play: Coin Flip a coin (thrown up and caught on the clip's beats), Apple Bite
-- an apple (the Core models' Coin and Apple, plain parts until they are imported).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)

local EmoteRemote = Net.event("Emote")

local EmoteController = {}

-- How long a one-shot emote holds its last pose before easing back.
local HOLD = 0.6

function EmoteController.play(emoteId: string)
	EmoteRemote:FireServer(emoteId)
end

local GRIP = CFrame.new(0, -1.05, -0.25) -- in the right hand, from the arm's middle
local PROP_FOR = { coinFlip = "Coin", appleBite = "Apple" }

-- The thing a gesture holds: the Core model scaled to `height`, or a plain stand-in.
local function heldProp(key: string): Model
	local model = ModelLibrary.get(key)
	if model then
		local _, size = model:GetBoundingBox()
		local want = if key == "Coin" then 0.5 else 0.8
		local biggest = math.max(size.X, size.Y, size.Z)
		if biggest > 0 then
			model:ScaleTo(model:GetScale() * want / biggest)
		end
		return model
	end
	local holder = Create("Model", { Name = key }) :: Model
	local part = Create("Part", {
		Size = if key == "Coin" then Vector3.new(0.5, 0.08, 0.5) else Vector3.new(0.7, 0.7, 0.7),
		Shape = if key == "Coin" then Enum.PartType.Cylinder else Enum.PartType.Ball,
		Color = if key == "Coin" then Color3.fromRGB(176, 142, 74) else Color3.fromRGB(150, 20, 26),
		Material = if key == "Coin" then Enum.Material.Metal else Enum.Material.SmoothPlastic,
		Parent = holder,
	})
	holder.PrimaryPart = part
	return holder
end

local function weld(model: Model, arm: BasePart)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			Create("WeldConstraint", { Name = "Held", Part0 = arm, Part1 = part, Parent = part })
		end
	end
end

local function unweld(model: Model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("WeldConstraint") and item.Name == "Held" then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
		end
	end
end

-- Puts a gesture's prop in the character's right hand for as long as the clip plays (the coin is thrown
-- and caught). Returns a function that takes it away (it also goes by itself). Your look uses it too.
function EmoteController.dress(character: Model, clip: string): () -> ()
	local key = PROP_FOR[clip]
	local arm = character:FindFirstChild("Right Arm")
	if not key or not arm or not arm:IsA("BasePart") then
		return function() end
	end
	local prop = heldProp(key)
	prop.Name = "EmoteProp"
	prop:PivotTo(arm.CFrame * GRIP)
	weld(prop, arm)
	prop.Parent = character
	local gone = false
	local function remove()
		if not gone then
			gone = true
			prop:Destroy()
		end
	end
	if clip == "coinFlip" then
		-- Off the thumb at 0.55 s, up and spinning, back in the hand at 1.35 s.
		task.delay(0.55, function()
			if gone or not arm.Parent then
				return
			end
			unweld(prop)
			local from = arm.CFrame * GRIP
			local value = Instance.new("NumberValue")
			value.Changed:Connect(function(t: number)
				if not gone then
					local up = 4 * t * (1 - t) * 3.2
					local home = arm.CFrame * GRIP
					prop:PivotTo(
						CFrame.new(from.Position:Lerp(home.Position, t) + Vector3.new(0, up, 0))
							* CFrame.Angles(t * math.pi * 8, 0, 0)
					)
				end
			end)
			local tween = TweenService:Create(value, TweenInfo.new(0.8, Enum.EasingStyle.Linear), { Value = 1 })
			tween.Completed:Once(function()
				value:Destroy()
				if not gone and arm.Parent then
					prop:PivotTo(arm.CFrame * GRIP)
					weld(prop, arm)
				end
			end)
			tween:Play()
		end)
	end
	local length = (ClipPlayer.get(clip) or { length = 3 }).length
	task.delay(length + HOLD, remove)
	-- Moving stops the gesture (and the prop goes with it).
	task.spawn(function()
		task.wait(0.3)
		while not gone and character.Parent and PoseController.isPlaying(character, clip) do
			task.wait(0.2)
		end
		remove()
	end)
	return remove
end

local function onEmote(payload)
	if type(payload) ~= "table" or type(payload.emote) ~= "string" or type(payload.userId) ~= "number" then
		return
	end
	local player = Players:GetPlayerByUserId(payload.userId)
	local character = if player then player.Character else nil
	local clip = ClipPlayer.get(payload.emote)
	if not character or not clip then
		return
	end
	PoseController.play(character, payload.emote, {
		emote = true,
		fadeIn = 0.15,
		fadeOut = 0.3,
		duration = if clip.loop then nil else clip.length + HOLD,
	})
	EmoteController.dress(character, payload.emote)
end

function EmoteController.init()
	EmoteRemote.OnClientEvent:Connect(onEmote)
end

return EmoteController
