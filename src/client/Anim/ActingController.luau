-- Decides who acts what, from public events only:
--   Grimoire phase : every living player writes (never tied to who really writes)
--   vote cast      : that player raises a hand (who voted is public, not for whom)
--   death          : the collapse for the public cause of death
--   arrest         : hands cuffed behind the back
--   verdict        : the player voted out slumps and fades away
--   ending         : winners celebrate, losers hang their heads, the Hand laughs or kneels
--   station work   : a player working a case file (real or faked) types at the console

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Poses = require(Shared:WaitForChild("Anim"):WaitForChild("Poses"))

local ClientState = require(script.Parent.Parent.ClientState)
local CueRouter = require(script.Parent.Parent.Presentation.CueRouter)
local PoseController = require(script.Parent.PoseController)

local ActingController = {}

local writing: { [Model]: boolean } = {}
local voted: { [number]: boolean } = {}

local function characterOf(userId: number?): Model?
	if not userId then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	if character and character.Parent then
		return character
	end
	return nil
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

local function onDeath(cue)
	local character = characterOf(tonumber(cue.data.userId))
	if not character then
		return
	end
	PoseController.stop(character, "write", 0.1)
	local cause = if type(cue.data.cause) == "string" then cue.data.cause else ""
	local poseId = Poses.FOR_CAUSE[cause] or "collapseHeart"
	PoseController.play(
		character,
		poseId,
		{ startAt = localTime(cue.at), fadeIn = 0.15, duration = 1.5, fadeOut = 0.1 }
	)
end

local function onArrest(cue)
	local character = characterOf(tonumber(cue.data.userId))
	PoseController.play(character, "cuffed", { startAt = localTime(cue.at), fadeIn = 0.4, duration = 4 })
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
	task.wait(0.8)
	if character.Parent then
		dissolve(character, 1.6)
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
				poseId = if handWon then "laugh" else "kneel"
			elseif winners[entry.userId] then
				-- The winner's victory pose cosmetic, if they have one.
				local player = Players:GetPlayerByUserId(entry.userId)
				local chosen = if player then player:GetAttribute("LVictoryPose") else nil
				poseId = if type(chosen) == "string" and PoseController.exists(chosen) then chosen else "victory"
			else
				poseId = "defeat"
			end
			PoseController.play(character, poseId, {
				startAt = os.clock() - math.random() * 0.4,
				fadeIn = 0.5,
				duration = length,
			})
		end
	end
end

-- Station work: follows the LWorking attribute the server sets on the character.
local function watchWorking(character: Model)
	local function update()
		if character:GetAttribute("LWorking") then
			PoseController.play(character, "taskWork", { fadeIn = 0.25, startAt = os.clock() - math.random() })
		else
			PoseController.stop(character, "taskWork", 0.3)
		end
	end
	character:GetAttributeChangedSignal("LWorking"):Connect(update)
	if character:GetAttribute("LWorking") then
		task.defer(update)
	end
end

function ActingController.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(watchWorking)
		if player.Character then
			watchWorking(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
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
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(refreshWriting)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			task.defer(refreshWriting)
		end)
	end
end

return ActingController
