-- Emotes. The player asks the server, which checks the emote (owned from the shop, or the Emote Pack
-- pass) and tells every client that may see it; each client then plays the Blender clip on that
-- character, ending the emote it was doing. Moving stops the emote (LocomotionController). A looping
-- emote starts on a beat shared by every client (the server's clock), so players doing the same dance
-- move together. Two shop emotes hold something in the right hand while they play: Coin Flip a coin
-- (thrown up and caught on the clip's beats), Apple Bite an apple (the Core models' Coin and Apple, plain
-- parts until they are imported). An emote with a sound in Shared/EmoteMedia plays it around the dancer
-- while it lasts (others' can be muted in Settings; never in a meeting or a cutscene); one with a `face`
-- puts that drawn expression on the head while it plays (once the owner has uploaded it); a few have an
-- effect round the body (EmoteFx).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteMedia = require(Shared:WaitForChild("EmoteMedia"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local ClientState = require(script.Parent.Parent.ClientState)
local EmoteFx = require(script.Parent.EmoteFx)
local Mixer = require(script.Parent.Parent.Audio.Mixer)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local EmoteRemote = Net.event("Emote")

local EmoteController = {}

-- How long a one-shot emote holds its last pose before easing back.
local HOLD = 0.6

function EmoteController.play(emoteId: string)
	EmoteRemote:FireServer(emoteId)
end

-- Calls `done` once the clip stops playing on the character (it ended, was stopped, or the body went).
local function watch(character: Model, clip: string, done: () -> ())
	task.spawn(function()
		task.wait(0.3)
		while character.Parent and PoseController.isPlaying(character, clip) do
			task.wait(0.2)
		end
		done()
	end)
end

local GRIP = CFrame.new(0, -1.05, -0.25) -- in the right hand, from the arm's middle
local PROP_FOR = { coinFlip = "Coin", appleBite = "Apple" }

-- The thing an emote holds: the Core model scaled to `height`, or a plain stand-in.
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

-- Puts an emote's prop in the character's right hand for as long as the clip plays (the coin is thrown
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
	-- Moving stops the emote (and the prop goes with it).
	task.spawn(function()
		task.wait(0.3)
		while not gone and character.Parent and PoseController.isPlaying(character, clip) do
			task.wait(0.2)
		end
		remove()
	end)
	return remove
end

-- Phases of a case in which emote sounds stay quiet: the meeting (people are talking) and the cutscenes.
local QUIET_PHASES = { Meeting = true, Intro = true, Verdict = true, Outro = true, Reveal = true }

-- An emote's sound around the dancer, for as long as the emote plays. Returns a function that stops it.
function EmoteController.sound(character: Model, clip: string, own: boolean): () -> ()
	local id = EmoteMedia.sound(clip)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not id or not root then
		return function() end
	end
	if not own and Settings.get("emoteMusic") == false then
		return function() end
	end
	if ClientState.isParticipant() and QUIET_PHASES[ClientState.phase()] then
		return function() end
	end
	-- One emote sound a character at a time.
	local playing = root:FindFirstChild("EmoteSound")
	if playing then
		playing:Destroy()
	end
	local prepared = ClipPlayer.get(clip)
	local sound = Instance.new("Sound")
	sound.Name = "EmoteSound"
	sound.SoundId = id
	sound.Volume = EmoteMedia.VOLUME
	sound.Looped = prepared ~= nil and prepared.loop
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = EmoteMedia.RANGE
	sound.SoundGroup = Mixer.group("Music")
	sound.Parent = root
	sound:Play()
	local gone = false
	local function stop()
		if not gone then
			gone = true
			sound:Destroy()
		end
	end
	watch(character, clip, stop)
	return stop
end

-- Puts an emote's face (a drawn expression, Shared/EmoteMedia FACES) on the head while it plays; the head's
-- own face comes back after. Nothing while that face has no picture, or on a head with no face decal.
-- Returns a function that puts the own face back.
function EmoteController.face(character: Model, clip: string): () -> ()
	local item = Cosmetics.emote(clip)
	local id = EmoteMedia.face(if item then item.face else nil)
	local head = character:FindFirstChild("Head")
	local decal = if head then head:FindFirstChild("face") else nil
	if not id or not decal or not decal:IsA("Decal") then
		return function() end
	end
	if decal:GetAttribute("OwnFace") == nil then
		decal:SetAttribute("OwnFace", decal.Texture)
	end
	local token = ((decal:GetAttribute("EmoteFace") :: number?) or 0) + 1
	decal:SetAttribute("EmoteFace", token)
	decal.Texture = id
	local done = false
	local function undo()
		if done then
			return
		end
		done = true
		-- (a later emote's face stays; it puts the own face back itself)
		if decal.Parent and decal:GetAttribute("EmoteFace") == token then
			decal.Texture = (decal:GetAttribute("OwnFace") :: string?) or decal.Texture
			decal:SetAttribute("OwnFace", nil)
		end
	end
	watch(character, clip, undo)
	return undo
end

-- An emote's effect round the body (EmoteFx) for as long as it plays. Returns a function that clears it.
function EmoteController.effect(character: Model, clip: string, preview: boolean?): () -> ()
	local clear = EmoteFx.play(character, clip, preview)
	local done = false
	local function stop()
		if not done then
			done = true
			clear()
		end
	end
	watch(character, clip, stop)
	return stop
end

-- An emote's sound for the shop's preview: heard as it is (no distance), for `seconds`. Returns a function
-- that stops it.
function EmoteController.previewSound(clip: string, seconds: number): () -> ()
	local id = EmoteMedia.sound(clip)
	if not id then
		return function() end
	end
	local sound = Instance.new("Sound")
	sound.Name = "EmotePreview"
	sound.SoundId = id
	sound.Volume = EmoteMedia.VOLUME
	sound.SoundGroup = Mixer.group("Music")
	sound.Parent = SoundService
	sound:Play()
	local gone = false
	local function stop()
		if not gone then
			gone = true
			sound:Destroy()
		end
	end
	task.delay(seconds, stop)
	return stop
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
	PoseController.stopEmotes(character)
	PoseController.play(character, payload.emote, {
		emote = true,
		fadeIn = 0.15,
		fadeOut = 0.3,
		duration = if clip.loop then nil else clip.length + HOLD,
		-- A loop starts on the shared beat, so everyone doing it is in step.
		phase = if clip.loop and clip.length > 0 then workspace:GetServerTimeNow() % clip.length else nil,
	})
	EmoteController.dress(character, payload.emote)
	EmoteController.sound(character, payload.emote, player == Players.LocalPlayer)
	EmoteController.face(character, payload.emote)
	EmoteController.effect(character, payload.emote)
end

function EmoteController.init()
	EmoteRemote.OnClientEvent:Connect(onEmote)
end

return EmoteController
