-- Decides who acts what, from public events only:
--   Grimoire phase : every living player writes (never tied to who really writes)
--   vote cast      : that player raises a hand (who voted is public, not for whom)
--   death          : the collapse for the public cause of death; everyone else reacts
--   arrest         : hands cuffed behind the back; everyone else reacts
--   verdict        : the player voted out slumps and fades away; everyone else reacts
--   ending         : winners celebrate, losers hang their heads, the Hand laughs or kneels
-- Reactions and endings are picked from the cue and the user id (Presentation/Activities), so
-- every screen shows the same thing and nothing depends on roles.
--   station work   : a player working a case file (real or faked) types at the console

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Causes = require(Shared:WaitForChild("Anim"):WaitForChild("Causes"))
local Activities = require(Shared:WaitForChild("Presentation"):WaitForChild("Activities"))

local ClientState = require(script.Parent.Parent.ClientState)
local CueRouter = require(script.Parent.Parent.Presentation.CueRouter)
local DeathFx = require(script.Parent.Parent.Presentation.DeathFx)
local PoseController = require(script.Parent.PoseController)
local Characters = require(script.Parent.Parent.Characters)

local ActingController = {}

local writing: { [Model]: boolean } = {}
local voted: { [number]: boolean } = {}

local function characterOf(userId: number?): Model?
	if not userId then
		return nil
	end
	return Characters.byUserId(userId)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Converts a server time into os.clock() time, so a pose can start exactly on a cue.
local function localTime(serverTime: number): number
	return os.clock() + (serverTime - now())
end

local function refreshWriting()
	local want: { [Model]: boolean } = {}
	if ClientState.public.active and ClientState.phase() == "DeathNote" then
		for _, entry in ipairs(ClientState.living()) do
			local character = characterOf(entry.userId)
			if character then
				want[character] = true
			end
		end
	end
	for character in pairs(writing) do
		if not want[character] then
			PoseController.stop(character, "write")
			writing[character] = nil
		end
	end
	for character in pairs(want) do
		if not writing[character] or not PoseController.isPlaying(character, "write") then
			-- A small random offset so the table does not scribble in unison.
			PoseController.play(character, "write", { startAt = os.clock() - math.random() * 0.7, fadeIn = 0.5 })
			writing[character] = true
		end
	end
end

local function onVoteUpdate(payload)
	if type(payload) ~= "table" or type(payload.voted) ~= "table" then
		return
	end
	local current: { [number]: boolean } = {}
	for _, userId in ipairs(payload.voted) do
		if type(userId) == "number" then
			current[userId] = true
			if not voted[userId] then
				PoseController.play(characterOf(userId), "raiseHand", { duration = 1.4, fadeOut = 0.4 })
			end
		end
	end
	voted = current
end

-- Fades a character out on this screen (the server respawns them a moment later).
local function dissolve(character: Model, seconds: number)
	local started = os.clock()
	task.spawn(function()
		while character.Parent and os.clock() - started < seconds do
			local alpha = (os.clock() - started) / seconds
			for _, item in ipairs(character:GetDescendants()) do
				if item:IsA("BasePart") or item:IsA("Decal") then
					item.LocalTransparencyModifier = alpha
				end
			end
			task.wait()
		end
	end)
end

-- Every living player except `except` reacts, starting around `serverTime`.
local function reactAround(cue, except: number?, serverTime: number, duration: number)
	local seed = tonumber(cue.id) or 1
	for _, entry in ipairs(ClientState.public.players or {}) do
		if entry.alive and entry.userId ~= except then
			local character = characterOf(entry.userId)
			if character then
				local clip = Activities.pick(Activities.REACTIONS, seed, entry.userId)
				local jitter = Random.new(seed + entry.userId % 997):NextNumber(0.1, 0.6)
				PoseController.play(character, clip, {
					startAt = localTime(serverTime + jitter),
					fadeIn = 0.2,
					fadeOut = 0.6,
					duration = duration,
				})
			end
		end
	end
end

local function onDeath(cue)
	local character = characterOf(tonumber(cue.data.userId))
	if not character then
		return
	end
	PoseController.stop(character, "write", 0.1)
	local cause = if type(cue.data.cause) == "string" then cue.data.cause else ""
	local poseId = Causes.clipFor(cause)
	PoseController.play(
		character,
		poseId,
		-- Holds the last frame until the server locks the pose into the body (LPoseBaked).
		{ startAt = localTime(cue.at), fadeIn = 0.15 }
	)
	reactAround(cue, tonumber(cue.data.userId), cue.at + 0.3, 3.4)
end

local function onArrest(cue)
	local character = characterOf(tonumber(cue.data.userId))
	PoseController.play(character, "cuffed", { startAt = localTime(cue.at), fadeIn = 0.4, duration = 4 })
	reactAround(cue, tonumber(cue.data.userId), cue.at + 0.8, 3)
end

local function onVerdict(cue)
	local climax = tonumber(cue.data.climax) or 0
	local character = characterOf(tonumber(cue.data.removedUserId))
	if climax <= 0 or not character then
		return
	end
	local wait = cue.at + climax - now()
	if wait > 0 then
		task.wait(wait)
	end
	PoseController.play(character, "slump", { fadeIn = 0.3, duration = 3 })
	reactAround(cue, tonumber(cue.data.removedUserId), now() + 0.2, 3)
	task.wait(0.8)
	if character.Parent then
		dissolve(character, 1.6)
		DeathFx.dissolve(character, 1.4)
	end
end

local function onOutro(cue)
	local data = cue.data
	local winners: { [number]: boolean } = {}
	if type(data.winners) == "table" then
		for _, userId in ipairs(data.winners) do
			winners[userId] = true
		end
	end
	local handId = tonumber(data.handUserId)
	local handWon = data.winner ~= "Team"
	local wait = cue.at - now()
	if wait > 0 then
		task.wait(wait)
	end
	local length = math.max(1, (tonumber(data.duration) or 10) - 0.3)
	for _, entry in ipairs(ClientState.public.players) do
		local character = characterOf(entry.userId)
		if character and entry.alive then
			local poseId
			if entry.userId == handId then
				poseId = if handWon then "laugh" else "slump"
			elseif winners[entry.userId] then
				poseId = Activities.pick(Activities.VICTORY, tonumber(cue.id) or 1, entry.userId)
			else
				poseId = Activities.pick(Activities.DEFEAT, tonumber(cue.id) or 1, entry.userId)
			end
			PoseController.play(character, poseId, {
				startAt = os.clock() - math.random() * 0.4,
				fadeIn = 0.5,
				duration = length,
			})
		end
	end
end

-- Station work: follows the LWorking attribute the server sets on the character, which holds the
-- station type; each type has its own working clip (workCamera, workFingerprint, ...).
local WORK_FALLBACK = "workCamera"

local function watchWorking(character: Model)
	local playing: string? = nil
	local function update()
		local working = character:GetAttribute("LWorking")
		if playing then
			PoseController.stop(character, playing, 0.3)
			playing = nil
		end
		if working then
			local id = if type(working) == "string" then "work" .. working else WORK_FALLBACK
			if not PoseController.exists(id) then
				id = WORK_FALLBACK
			end
			playing = id
			PoseController.play(character, id, { fadeIn = 0.25, startAt = os.clock() - math.random() })
		end
	end
	character:GetAttributeChangedSignal("LWorking"):Connect(update)
	if character:GetAttribute("LWorking") then
		task.defer(update)
	end
end

function ActingController.init()
	Characters.each(watchWorking)
	ClientState.PhaseChanged:Connect(function(phase)
		refreshWriting()
		if phase ~= "Vote" then
			voted = {}
		end
	end)
	ClientState.PublicChanged:Connect(refreshWriting)
	Net.event("VoteUpdate").OnClientEvent:Connect(onVoteUpdate)
	CueRouter.register("death", onDeath)
	CueRouter.register("arrest", onArrest)
	CueRouter.register("verdict", onVerdict)
	CueRouter.register("outro", onOutro)
	Characters.each(function()
		task.defer(refreshWriting)
	end)
end

return ActingController
