-- Emotes. The player asks the server, which checks the emote (owned from the shop, or the Emote Pack
-- pass) and tells every client that may see it; each client then plays the Blender clip on that
-- character, ending the emote it was doing. Moving stops the emote (LocomotionController). A looping
-- emote starts on a beat shared by every client (the server's clock), so players doing the same dance
-- move together. Emotes with props hold them, wear them or set them down while they play (Anim/EmoteProps:
-- the Core models, plain parts until they are imported). An emote with a sound in Shared/EmoteMedia plays it around the dancer
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
local EmoteProps = require(Shared:WaitForChild("Anim"):WaitForChild("EmoteProps"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))

local LocomotionController = require(script.Parent.Parent.Anim.LocomotionController)
local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)
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

-- Calls `done` once the clip stops playing on the character (it ended, was stopped, or the body went), or,
-- with `alive`, once that says it is over (a stroll lasts as long as its attribute).
export type Alive = (() -> boolean)?
local function watch(character: Model, clip: string, done: () -> (), alive: Alive)
	task.spawn(function()
		task.wait(0.3)
		while character.Parent and (if alive then alive() else PoseController.isPlaying(character, clip)) do
			task.wait(0.2)
		end
		done()
	end)
end

-- One prop of an emote: the Core model scaled to its size, or its stand-in part (a Roblox cylinder runs
-- along X, the models along Y: the stand-in is turned to match through its pivot).
local function build(spec: EmoteProps.Prop): Model
	local model = ModelLibrary.get(spec.model)
	if model then
		local _, size = model:GetBoundingBox()
		local biggest = math.max(size.X, size.Y, size.Z)
		if biggest > 0 then
			model:ScaleTo(model:GetScale() * spec.size / biggest)
		end
		return model
	end
	local holder = Create("Model", { Name = spec.model }) :: Model
	local part = Create("Part", {
		Size = spec.stand.size,
		Shape = (Enum.PartType :: any)[spec.stand.shape] or Enum.PartType.Block,
		Color = spec.stand.color,
		Material = Enum.Material.SmoothPlastic,
		Parent = holder,
	}) :: BasePart
	if spec.stand.shape == "Cylinder" then
		part.PivotOffset = CFrame.Angles(0, 0, math.rad(-90))
	elseif spec.mount == "floor" then
		part.PivotOffset = CFrame.new(0, -spec.stand.size.Y / 2, 0)
	end
	holder.PrimaryPart = part
	return holder
end
EmoteController.propModel = build

-- Where a prop goes on a body: a part's middle, or for "floor" the floor under the root (an R6 root stands
-- 3 studs up), turned the way the body faces.
local function placeOn(character: Model, mount: string, at: CFrame): (CFrame?, BasePart?)
	if mount == "floor" then
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return nil, nil
		end
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		return CFrame.new(root.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, yaw, 0) * at, nil
	end
	local part = character:FindFirstChild(mount)
	if not part or not part:IsA("BasePart") then
		return nil, nil
	end
	return part.CFrame * at, part
end

local function weld(model: Model, to: BasePart)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			Create("WeldConstraint", { Name = "Held", Part0 = to, Part1 = part, Parent = part })
		end
	end
end

-- Lets go of a prop (it stays where it is, anchored).
local function loose(model: Model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("WeldConstraint") and item.Name == "Held" then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
end

-- Runs fn(t) with t from 0 to 1 over `seconds`, then done().
local function over(seconds: number, fn: (number) -> (), done: () -> ())
	local value = Instance.new("NumberValue")
	value.Changed:Connect(fn)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Value = 1 })
	tween.Completed:Once(function()
		value:Destroy()
		done()
	end)
	tween:Play()
end

-- Puts an emote's props on the character for as long as the clip plays (Anim/EmoteProps: held in a hand,
-- worn, set on the floor; carried from hand to hand, thrown up and caught, stacked). Returns a function that
-- takes them away (they also go by themselves). Your look uses it too.
function EmoteController.dress(character: Model, clip: string, alive: Alive): () -> ()
	local specs = EmoteProps.of(clip)
	if #specs == 0 then
		return function() end
	end
	local made: { Instance } = {}
	local gone = false
	local function remove()
		if gone then
			return
		end
		gone = true
		for _, item in ipairs(made) do
			item:Destroy()
		end
		table.clear(made)
	end
	-- Floor props stand in the world (or in the view's world for Your look), never in the body.
	local floorHolder: Instance = if character:IsDescendantOf(workspace)
		then workspace.CurrentCamera
		else (character.Parent or character)
	local function after(seconds: number?, fn: () -> ())
		if not seconds or seconds <= 0 then
			fn()
		else
			task.delay(seconds, function()
				if not gone and character.Parent then
					fn()
				end
			end)
		end
	end
	for _, spec in ipairs(specs) do
		local function put(at: CFrame, onFloor: boolean): Model?
			local cf, part = placeOn(character, spec.mount, at)
			if not cf then
				return nil
			end
			local prop = build(spec)
			prop.Name = "EmoteProp"
			prop:PivotTo(cf)
			if onFloor or not part then
				loose(prop)
				prop.Parent = floorHolder
			else
				weld(prop, part)
				prop.Parent = character
			end
			table.insert(made, prop)
			return prop
		end
		local stack = spec.stack
		if stack then
			local at = spec.at
			for _, t in ipairs(stack.times) do
				local here = at
				after(t, function()
					put(here, true)
				end)
				at = at * stack.step
			end
			continue
		end
		after(spec.show, function()
			local prop = put(spec.at, spec.mount == "floor")
			if not prop then
				return
			end
			local mount, at = spec.mount, spec.at
			for _, move in ipairs(spec.moves or {}) do
				after(move.at - (spec.show or 0), function()
					local toMount = move.mount or mount
					local fromCf = prop:GetPivot()
					loose(prop)
					over(0.18, function(t: number)
						local target = placeOn(character, toMount, move.to)
						if target and not gone then
							prop:PivotTo(fromCf:Lerp(target, t))
						end
					end, function()
						local target, part = placeOn(character, toMount, move.to)
						if target and part and not gone then
							prop:PivotTo(target)
							weld(prop, part)
						end
					end)
					mount, at = toMount, move.to
				end)
			end
			for _, toss in ipairs(spec.tosses or {}) do
				after(toss.at - (spec.show or 0), function()
					local from = prop:GetPivot()
					loose(prop)
					over(toss.back - toss.at, function(t: number)
						local home = placeOn(character, mount, at)
						if home and not gone then
							local up = 4 * t * (1 - t) * toss.height
							prop:PivotTo(
								CFrame.new(from.Position:Lerp(home.Position, t) + Vector3.new(0, up, 0))
									* CFrame.Angles(t * math.pi * 2 * toss.spin, 0, 0)
							)
						end
					end, function()
						local home, part = placeOn(character, mount, at)
						if home and part and not gone then
							prop:PivotTo(home)
							weld(prop, part)
						end
					end)
				end)
			end
			if spec.hide then
				after(spec.hide - (spec.show or 0), function()
					local index = table.find(made, prop)
					if index then
						table.remove(made, index)
					end
					prop:Destroy()
				end)
			end
		end)
	end
	local prepared = ClipPlayer.get(clip)
	if prepared and not prepared.loop and not alive then
		task.delay(prepared.length + HOLD, remove)
	end
	-- Moving stops the emote (and the props go with it).
	watch(character, clip, remove, alive)
	return remove
end

-- Phases of a case in which emote sounds stay quiet: the meeting (people are talking) and the cutscenes.
local QUIET_PHASES = { Meeting = true, Intro = true, Verdict = true, Outro = true, Reveal = true }

-- An emote's sound around the dancer, for as long as the emote plays. Returns a function that stops it.
function EmoteController.sound(character: Model, clip: string, own: boolean, alive: Alive): () -> ()
	local item = Cosmetics.emote(clip)
	local id = EmoteMedia.sound(if item then item.emote else clip)
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
	watch(character, clip, stop, alive)
	return stop
end

-- Puts an emote's face (a drawn expression, Shared/EmoteMedia FACES) on the head while it plays; the head's
-- own face comes back after. Nothing while that face has no picture, or on a head with no face decal.
-- Returns a function that puts the own face back.
function EmoteController.face(character: Model, clip: string, alive: Alive): () -> ()
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
	watch(character, clip, undo, alive)
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

-- A stroll (the server's "Stroll" attribute; LocomotionController walks the body in it) carries its props,
-- face and sound for as long as it lasts.
local function watchStrolls(character: Model)
	local function changed()
		local clip = character:GetAttribute("Stroll")
		if type(clip) ~= "string" then
			return
		end
		local function alive(): boolean
			return character.Parent ~= nil and character:GetAttribute("Stroll") == clip
		end
		PoseController.stopEmotes(character)
		local player = Players:GetPlayerFromCharacter(character)
		EmoteController.dress(character, clip, alive)
		EmoteController.sound(character, clip, player == Players.LocalPlayer, alive)
		EmoteController.face(character, clip, alive)
	end
	character:GetAttributeChangedSignal("Stroll"):Connect(changed)
	changed()
end

function EmoteController.init()
	EmoteRemote.OnClientEvent:Connect(onEmote)
	Characters.each(watchStrolls)
	-- A stance settled into holds its props and wears its face (no sound: it is how you stand).
	LocomotionController.Settled:Connect(function(character: Model, clip: string)
		EmoteController.dress(character, clip)
		EmoteController.face(character, clip)
	end)
end

return EmoteController
