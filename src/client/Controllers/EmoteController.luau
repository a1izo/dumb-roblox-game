-- Emotes. The player asks the server, which checks the emote (owned, and allowed where the player is:
-- Shared/EmotePolicy) and tells every client that may see it, with the time it started; each client then plays
-- it on that character as one session (below), ending the one before. Moving stops an emote
-- (LocomotionController). A looping emote plays on a beat shared by every client (the server's clock), so
-- players doing the same dance move together, and Join in is just the same dance. Emotes with props hold them,
-- wear them or set them down while they play (Anim/EmoteProps: the Core models, plain parts until they are
-- imported). An emote with a sound in Shared/EmoteMedia plays it around the dancer while it lasts, a loop on the
-- same beat as the dance (others' can be muted in Settings; never in a meeting or a cutscene); one with a `face`
-- puts that drawn expression on the head while it plays (once the owner has uploaded it); some have an effect
-- round the body (EmoteFx).
--
-- A session is everything one emote put on one body: its pose track, props, sound, face and effect. It ends,
-- and takes all of them away at once, when the track ends (finished, moved, replaced), the server stops it (a
-- cutscene, the meeting), a stroll or a stance it belongs to ends, or the body goes. Starting another emote on
-- the same body ends the one before first, so nothing of it is left over.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmoteMedia = require(Shared:WaitForChild("EmoteMedia"))
local EmoteProps = require(Shared:WaitForChild("Anim"):WaitForChild("EmoteProps"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local LocomotionController = require(script.Parent.Parent.Anim.LocomotionController)
local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)
local ClientState = require(script.Parent.Parent.ClientState)
local EmoteFx = require(script.Parent.EmoteFx)
local Mixer = require(script.Parent.Parent.Audio.Mixer)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local EmoteRemote = Net.event("Emote")

local EmoteController = {}

-- Fired as (character, session) when an emote starts on a body, and (character, clip, reason) when it ends.
EmoteController.Started = Signal.new()
EmoteController.Ended = Signal.new()
-- Fired as (reason, clip) when the server turned down one of this player's emotes.
EmoteController.Refused = Signal.new()

-- How long a one-shot emote holds its last pose before easing back.
local HOLD = 0.6

export type Session = {
	character: Model,
	clip: string,
	started: number, -- os.clock() when it began here
	at: number?, -- server time it began (the server's)
	alive: boolean,
	joined: number?, -- the userId of the dancer it joined
	owned: boolean?, -- false: joined in on a dance this player does not own (the lobby lets anyone)
	from: string?, -- the emote whose press-to-do moment played it (EmoteInfo `context`)
	handle: PoseController.Handle?,
	cleanups: { () -> () },
	connections: { RBXScriptConnection },
}

local sessions: { [Model]: Session } = {}

function EmoteController.play(emoteId: string)
	EmoteRemote:FireServer(emoteId)
end

-- The emote's press-to-do moment (Shared/EmoteInfo `context`), for this player's own emote.
function EmoteController.press()
	EmoteRemote:FireServer({ press = true })
end

-- Joins in on another player's looping dance, on its beat.
function EmoteController.joinIn(userId: number)
	EmoteRemote:FireServer({ join = userId })
end

-- The emote playing on a body now, if any.
function EmoteController.session(character: Model?): Session?
	return if character then sessions[character] else nil
end

-- Calls `done` once the clip stops playing on the character (it ended, was stopped, or the body went), or,
-- with `alive`, once that says it is over (a stroll lasts as long as its attribute). Only for things played
-- outside a session (the shop window's figure, an ending's pose): a session ends its parts itself.
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
-- along X, the models along Y: the stand-in is turned to match through its pivot). A prop whose hold is made
-- for a newer Core mesh (`core`) keeps its stand-in until that import is in.
local function build(spec: EmoteProps.Prop): Model
	local current = spec.core == nil or ModelLibrary.version("Core") >= spec.core
	local model = if current then ModelLibrary.get(spec.model) else nil
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

-- The floor under a body: what is really under the root (a step, a slope, a raised plinth), or 3 studs
-- down (where an R6 root's floor is) when nothing is found.
local function floorUnder(character: Model, root: BasePart): Vector3
	-- (in its own world: the game's, or a 3D view's for Your look)
	local world = character:FindFirstAncestorWhichIsA("WorldRoot")
	if not world then
		return root.Position - Vector3.new(0, 3, 0)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	local hit = world:Raycast(root.Position, Vector3.new(0, -8, 0), params)
	return if hit then hit.Position else root.Position - Vector3.new(0, 3, 0)
end

-- Where a prop goes on a body: a part's middle, or for "floor" the floor under the root, turned the way the
-- body faces.
local function placeOn(character: Model, mount: string, at: CFrame): (CFrame?, BasePart?)
	if mount == "floor" then
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return nil, nil
		end
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		return CFrame.new(floorUnder(character, root)) * CFrame.Angles(0, yaw, 0) * at, nil
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
-- takes them away. `managed`: a session takes them away; otherwise they also go by themselves when the clip
-- stops (or `alive` says so). Your look uses it too. Every prop carries the attribute "DGEmote", so a copy of
-- the body (a cutscene's double) can leave them out.
function EmoteController.dress(character: Model, clip: string, alive: Alive, managed: boolean?): () -> ()
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
				if not gone and character.Parent and (alive == nil or alive()) then
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
			prop:SetAttribute("DGEmote", true)
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
							-- spun in its own frame from where it left the hand
							prop:PivotTo(
								CFrame.new(from.Position:Lerp(home.Position, t) + Vector3.new(0, up, 0))
									* (from - from.Position)
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
	if not managed then
		local prepared = ClipPlayer.get(clip)
		if prepared and not prepared.loop and not alive then
			task.delay(prepared.length + HOLD, remove)
		end
		-- Moving stops the emote (and the props go with it).
		watch(character, clip, remove, alive)
	end
	return remove
end

-- Phases of a case in which emote sounds stay quiet: the briefing, the meeting and the vote (people are
-- talking), and the cutscenes.
local QUIET_PHASES = {
	Briefing = true,
	Meeting = true,
	Vote = true,
	Intro = true,
	Verdict = true,
	Outro = true,
	Reveal = true,
}

-- An emote's sound around the dancer, for as long as the emote plays: a loop starts where the dance is on the
-- shared beat (`phase` seconds in), so the music and the moves line up. Returns a function that stops it.
function EmoteController.sound(
	character: Model,
	clip: string,
	own: boolean,
	alive: Alive,
	managed: boolean?,
	phase: number?
): () -> ()
	local item = Cosmetics.emote(clip)
	local id = EmoteMedia.sound(if item then item.emote else clip)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not id or not root then
		return function() end
	end
	if not own and Settings.get("emoteMusic") == false then
		return function() end
	end
	if ClientState.isParticipant() and (QUIET_PHASES[ClientState.phase()] or EmoteInfo.of(clip).loud) then
		return function() end
	end
	-- One emote sound a character at a time.
	local playing = root:FindFirstChild("EmoteSound")
	if playing then
		playing:Destroy()
	end
	local prepared = ClipPlayer.get(clip)
	local looped = prepared ~= nil and prepared.loop
	local sound = Instance.new("Sound")
	sound.Name = "EmoteSound"
	sound.SoundId = id
	sound.Volume = EmoteMedia.VOLUME
	sound.Looped = looped
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = EmoteMedia.RANGE
	sound.SoundGroup = Mixer.group("Music")
	sound.Parent = root
	local began = os.clock()
	local function start()
		if looped and phase and sound.TimeLength > 0 then
			sound.TimePosition = (phase + os.clock() - began) % sound.TimeLength
		end
		sound:Play()
	end
	if sound.IsLoaded then
		start()
	else
		sound.Loaded:Once(start)
	end
	local gone = false
	local function stop()
		if not gone then
			gone = true
			sound:Destroy()
		end
	end
	if not managed then
		watch(character, clip, stop, alive)
	end
	return stop
end

-- Fired as (character, clip, cue index, sound) each time one of an emote's sound cues goes off (for checks).
EmoteController.CueFired = Signal.new()

-- An emote's sound cues (Shared/EmoteMedia CUES) round the dancer, each at its moment of the clip counted from
-- where the emote is (`phase` seconds in when it started here), again on every turn of a loop, for as long as
-- `alive` says. The same quiet rules as the music; a loud cue is never heard in a case, an `own` one only by the
-- dancer. Returns a function that stops them (and any still sounding).
function EmoteController.cues(
	character: Model,
	clip: string,
	own: boolean,
	alive: () -> boolean,
	phase: number?
): () -> ()
	local list = EmoteMedia.cues(clip)
	local root = character:FindFirstChild("HumanoidRootPart")
	if #list == 0 or not root then
		return function() end
	end
	if not own and Settings.get("emoteMusic") == false then
		return function() end
	end
	local participant = ClientState.isParticipant()
	if participant and QUIET_PHASES[ClientState.phase()] then
		return function() end
	end
	local prepared = ClipPlayer.get(clip)
	local length = if prepared then prepared.length else 0
	local looped = prepared ~= nil and prepared.loop and length > 0
	local began = os.clock() - (phase or 0) -- when the clip's own 0 s was, here
	local sounding: { Sound } = {}
	local gone = false
	local function fire(index: number, cue: EmoteMedia.Cue)
		if (cue.own and not own) or (cue.loud and participant) then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = "EmoteCue"
		sound.SoundId = cue.id
		sound.Volume = EmoteMedia.VOLUME * (cue.volume or 1)
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = EmoteMedia.RANGE
		sound.SoundGroup = Mixer.group("Sfx")
		sound.Parent = root
		table.insert(sounding, sound)
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
		EmoteController.CueFired:Fire(character, clip, index, sound)
	end
	task.spawn(function()
		local turn = 0
		while not gone do
			for index, cue in ipairs(list) do
				local due = began + turn * length + cue.at
				-- (a cue already behind where the emote started here is skipped, not played late)
				if due >= began + (phase or 0) - 0.05 then
					local wait = due - os.clock()
					if wait > 0 then
						task.wait(wait)
					end
					if gone or not alive() or not character.Parent then
						return
					end
					fire(index, cue)
				end
			end
			if not looped then
				return
			end
			turn += 1
		end
	end)
	return function()
		gone = true
		for _, sound in ipairs(sounding) do
			sound:Destroy()
		end
		table.clear(sounding)
	end
end

-- Puts an emote's face (a drawn expression, Shared/EmoteMedia FACES) on the head while it plays; the head's
-- own face comes back after. Nothing while that face has no picture, or on a head with no face decal.
-- Returns a function that puts the own face back.
function EmoteController.face(character: Model, clip: string, alive: Alive, managed: boolean?): () -> ()
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
	if not managed then
		watch(character, clip, undo, alive)
	end
	return undo
end

-- An emote's effect round the body (EmoteFx) for as long as it plays. Returns a function that clears it.
function EmoteController.effect(character: Model, clip: string, preview: boolean?, managed: boolean?): () -> ()
	local clear = EmoteFx.play(character, clip, preview)
	local done = false
	local function stop()
		if not done then
			done = true
			clear()
		end
	end
	if not managed then
		watch(character, clip, stop)
	end
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

-- Sessions ---------------------------------------------------------------------------------------------------

local function finish(session: Session, reason: string)
	if not session.alive then
		return
	end
	session.alive = false
	if sessions[session.character] == session then
		sessions[session.character] = nil
	end
	for _, connection in ipairs(session.connections) do
		connection:Disconnect()
	end
	for _, cleanup in ipairs(session.cleanups) do
		task.spawn(cleanup)
	end
	local handle = session.handle
	if handle and handle.playing() then
		handle.stop(0.3, reason)
	end
	-- This player walked out of an emote the server started: it forgets it (no Join in on a dance that stopped).
	if
		session.at
		and (reason == "moved" or reason == "stopped")
		and session.character == Players.LocalPlayer.Character
	then
		EmoteRemote:FireServer({ ended = true })
	end
	EmoteController.Ended:Fire(session.character, session.clip, reason)
end

-- Ends whatever emote a body is in (reason: "replaced", "stopped", "server", "stroll", "stance", "gone"...).
function EmoteController.stopOn(character: Model, reason: string?)
	local session = sessions[character]
	if session then
		finish(session, reason or "stopped")
	end
end

export type StartOptions = {
	pose: boolean?, -- false: the body is posed by someone else (a stroll's walk, a stance), only the rest is put on
	at: number?, -- the server time it began (a one-shot catches up with it)
	catchUp: number?, -- how far a one-shot may catch up (seconds; a beat by default, all of it for a rally)
	mask: string?, -- "upper": the waist up only (PoseController)
	own: boolean?, -- this player's own body (their emote music plays whatever the setting)
	joined: number?,
	owned: boolean?,
	from: string?,
	silent: boolean?, -- no music, no cues (a stance: it is how you stand)
}

-- Starts an emote on a body as one session (ending the one before). Returns the session.
function EmoteController.start(character: Model, clip: string, options: StartOptions?): Session
	local opts: StartOptions = options or {}
	EmoteController.stopOn(character, "replaced")
	local session: Session = {
		character = character,
		clip = clip,
		started = os.clock(),
		at = opts.at,
		alive = true,
		joined = opts.joined,
		owned = opts.owned,
		from = opts.from,
		cleanups = {},
		connections = {},
	}
	sessions[character] = session
	local function alive(): boolean
		return session.alive
	end
	local prepared = ClipPlayer.get(clip)
	local phase: number? = nil
	if prepared and prepared.loop and prepared.length > 0 then
		-- the shared beat: everyone doing this dance is at the same place in it
		phase = workspace:GetServerTimeNow() % prepared.length
	elseif prepared and opts.at then
		-- a one-shot catches up a little with when it began (never more than a beat, unless told)
		phase = math.clamp(workspace:GetServerTimeNow() - opts.at, 0, opts.catchUp or 0.25)
	end
	if opts.pose ~= false and prepared then
		session.handle = PoseController.play(character, clip, {
			emote = true,
			fadeIn = 0.2,
			fadeOut = 0.35,
			duration = if prepared.loop then nil else math.max(0.1, prepared.length + HOLD - (phase or 0)),
			phase = phase,
			mask = opts.mask,
			onEnd = function(reason: string)
				finish(session, reason)
			end,
		})
	end
	table.insert(session.cleanups, EmoteController.dress(character, clip, alive, true))
	if not opts.silent then
		local own = opts.own == true
		table.insert(
			session.cleanups,
			EmoteController.sound(character, clip, own, alive, true, if prepared and prepared.loop then phase else nil)
		)
		table.insert(session.cleanups, EmoteController.cues(character, clip, own, alive, phase))
	end
	table.insert(session.cleanups, EmoteController.face(character, clip, alive, true))
	table.insert(session.cleanups, EmoteController.effect(character, clip, false, true))
	table.insert(
		session.connections,
		character.Destroying:Once(function()
			finish(session, "gone")
		end)
	)
	EmoteController.Started:Fire(character, session)
	return session
end

-- Walks this player's own body to a spot and turns it to face a point (a duo's spot, a place in a group's
-- formation; the server checks it got there in time). A move key pressed meanwhile takes the walk back.
function EmoteController.walkTo(to: Vector3, face: Vector3?, seconds: number?)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	EmoteController.stopOn(character, "moved")
	humanoid:MoveTo(to)
	local connection: RBXScriptConnection
	connection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		connection:Disconnect()
		if reached and face and root.Parent then
			local flat = Vector3.new(face.X, root.Position.Y, face.Z)
			if (flat - root.Position).Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(root.Position, flat)
			end
		end
	end)
	task.delay((seconds or 4) + 0.5, function()
		if connection.Connected then
			connection:Disconnect()
		end
	end)
end

-- (a player's body, or in Studio a test bot's)
local function characterOf(userId: any): Model?
	return Characters.byUserId(if type(userId) == "number" then userId else nil)
end

local function onEmote(payload)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.refused) == "string" then
		EmoteController.Refused:Fire(payload.refused, payload.emote)
		return
	end
	-- Joining a group's dance: this player walks to their place in its formation first.
	local walk = payload.walk
	if type(walk) == "table" and typeof(walk.to) == "Vector3" then
		EmoteController.walkTo(
			walk.to,
			if typeof(walk.face) == "Vector3" then walk.face else nil,
			tonumber(walk.seconds)
		)
		return
	end
	local character = characterOf(payload.userId)
	if not character then
		return
	end
	if payload.stop then
		EmoteController.stopOn(character, "server")
		PoseController.stopEmotes(character, "server")
		return
	end
	if type(payload.emote) ~= "string" or not ClipPlayer.get(payload.emote) then
		return
	end
	PoseController.stopEmotes(character, "replaced")
	EmoteController.start(character, payload.emote, {
		at = if type(payload.at) == "number" then payload.at else nil,
		mask = if payload.mask == "upper" then "upper" else nil,
		own = payload.userId == Players.LocalPlayer.UserId,
		joined = if type(payload.joined) == "number" then payload.joined else nil,
		owned = if payload.owned == false then false else nil,
		from = if type(payload.from) == "string" then payload.from else nil,
	})
end

-- A stroll (the server's "Stroll" attribute; LocomotionController walks the body in it) is a session that
-- lasts as long as the attribute: its props, face and sound.
local function watchStrolls(character: Model)
	local function changed()
		local clip = character:GetAttribute("Stroll")
		local now = sessions[character]
		-- (a Specter is unseen by the living: its stroll's props and sound would give it away)
		local mine = Players.LocalPlayer.Character
		local hidden = character:GetAttribute("Specter") ~= nil and not (mine and mine:GetAttribute("Specter") ~= nil)
		if type(clip) ~= "string" or hidden then
			if now and EmoteInfo.of(now.clip).stroll then
				EmoteController.stopOn(character, "stroll")
			end
			return
		end
		PoseController.stopEmotes(character, "replaced")
		EmoteController.start(character, clip, {
			pose = false,
			own = Players:GetPlayerFromCharacter(character) == Players.LocalPlayer,
		})
	end
	character:GetAttributeChangedSignal("Stroll"):Connect(changed)
	changed()
end

function EmoteController.init()
	EmoteRemote.OnClientEvent:Connect(onEmote)
	Characters.each(watchStrolls)
	-- A stance settled into holds its props and wears its face (no sound: it is how you stand) until it ends.
	LocomotionController.Settled:Connect(function(character: Model, clip: string)
		EmoteController.start(character, clip, { pose = false, silent = true })
	end)
	LocomotionController.Unsettled:Connect(function(character: Model, clip: string)
		local session = sessions[character]
		if session and session.clip == clip and session.handle == nil then
			EmoteController.stopOn(character, "stance")
		end
	end)
end

return EmoteController
