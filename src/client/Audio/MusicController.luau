-- Picks the music for what this player is doing and crossfades to it. Each client chooses on
-- its own, so at the end of a match winners and losers hear different tracks. Nothing here
-- depends on hidden information the player does not already have (their own role only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Parent.UI.Core.Router)
local Mixer = require(script.Parent.Mixer)

local MusicController = {}

local FADE = 2

local current: { slot: string, sound: Sound }? = nil
local outcomeSlot: string? = nil
local debugSlot: string? = nil

local function stop(entry: { slot: string, sound: Sound }, fade: number)
	local sound = entry.sound
	local tween = TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 })
	tween.Completed:Once(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function play(slot: string?)
	if current and current.slot == slot then
		return
	end
	local id = if slot then Assets.audioId(Assets.music[slot]) else nil
	if current then
		stop(current, FADE)
		current = nil
	end
	if not slot or not id then
		return
	end
	local entry = Assets.music[slot]
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. slot
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = Mixer.group("Music")
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FADE), { Volume = entry.volume or 1 }):Play()
	current = { slot = slot, sound = sound }
end

-- The slot for right now.
local function pick(): string?
	if debugSlot then
		return if debugSlot == "none" then nil else debugSlot
	end
	local phase = ClientState.phase()
	if not ClientState.isParticipant() then
		if Router.isOpen("shop") then
			return "shop"
		elseif Router.isOpen("practice") then
			return "training"
		end
		return "lobby"
	end
	if phase == "Outro" then
		return outcomeSlot or "results"
	elseif phase == "Reveal" then
		return "results"
	elseif phase == "Intro" then
		return "intro"
	elseif phase == "Briefing" then
		return if ClientState.isKiraSide() then "revealHand" else "intro"
	end
	if not ClientState.isLiving() then
		return "specter"
	end
	if phase == "Investigation" then
		local mapId = ClientState.public.mapId
		return if type(mapId) == "string" then "inv_" .. mapId else "inv_TaskForceHQ"
	elseif phase == "DeathNote" then
		return "grimoire"
	elseif phase == "Meeting" then
		return "meeting"
	elseif phase == "Vote" or phase == "Verdict" then
		return "vote"
	end
	return nil
end

function MusicController.refresh()
	play(pick())
end

-- Set by the ending cutscene: your side's win theme, or the defeat theme.
function MusicController.setOutcome(slot: string?)
	outcomeSlot = slot
	MusicController.refresh()
end

-- Debug panel: plays this slot whatever is happening ("none" for silence, nil to go back).
function MusicController.setDebugSlot(slot: string?)
	debugSlot = slot
	MusicController.refresh()
end

function MusicController.current(): string?
	return if current then current.slot else nil
end

function MusicController.init()
	ClientState.PhaseChanged:Connect(function(phase)
		if phase ~= "Outro" then
			outcomeSlot = nil
		end
		MusicController.refresh()
	end)
	ClientState.PublicChanged:Connect(MusicController.refresh)
	ClientState.PrivateChanged:Connect(MusicController.refresh)
	Router.Changed:Connect(MusicController.refresh)
	MusicController.refresh()
end

return MusicController
