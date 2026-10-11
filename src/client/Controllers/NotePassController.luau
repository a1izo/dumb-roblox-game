-- Passing a written note hand to hand: a "Pass note" prompt (X, LB on a gamepad, a tap on touch)
-- on every other living player within reach, shown only while you hold a written note during the
-- investigation and have no offer out. The other player decides on their NoteOfferSlip; the server
-- checks everything again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))

local Characters = require(script.Parent.Parent.Characters)
local ClientState = require(script.Parent.Parent.ClientState)
local NoteOfferSlip = require(script.Parent.Parent.UI.NoteOfferSlip)

local NoteRequest = Net.event("NoteRequest")
local LocalPlayer = Players.LocalPlayer

local NotePassController = {}

local prompts: { [Model]: ProximityPrompt } = {}

local function userIdOf(character: Model): number?
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player.UserId
	end
	local bot = character:GetAttribute("BotUserId")
	return if type(bot) == "number" then bot else nil
end

local function isLivingUser(userId: number?): boolean
	if not userId then
		return false
	end
	for _, entry in ipairs(ClientState.public.players or {}) do
		if entry.userId == userId then
			return entry.alive == true
		end
	end
	return false
end

local function refresh()
	local can = ClientState.isLiving()
		and ClientState.phase() == "Investigation"
		and ClientState.private.carrying == "note"
		and not NoteOfferSlip.pending
	for character, prompt in pairs(prompts) do
		if not character.Parent then
			prompt:Destroy()
			prompts[character] = nil
		else
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			prompt.ObjectText = if humanoid then string.upper(humanoid.DisplayName) else ""
			prompt.Enabled = can
				and isLivingUser(userIdOf(character))
				and character:GetAttribute("Specter") == nil
				and character:GetAttribute("Spectator") == nil
		end
	end
end

local function watch(character: Model)
	if character == LocalPlayer.Character or prompts[character] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not character.Parent then
		return
	end
	local prompt = Create("ProximityPrompt", {
		Name = "LPassNote",
		ActionText = "Pass note",
		ObjectText = "",
		KeyboardKeyCode = Enum.KeyCode.X,
		GamepadKeyCode = Enum.KeyCode.ButtonL1,
		HoldDuration = 0,
		MaxActivationDistance = Config.PASS_RANGE + 0.5,
		RequiresLineOfSight = false,
		Enabled = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Parent = root,
	})
	prompt.Triggered:Connect(function()
		local userId = userIdOf(character)
		if userId then
			NoteRequest:FireServer({ action = "offer", toUserId = userId })
		end
	end)
	prompts[character] = prompt
	refresh()
end

function NotePassController.init()
	Characters.each(function(character)
		task.spawn(watch, character)
	end)
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(refresh)
	Net.event("NoteOffer").OnClientEvent:Connect(function()
		task.defer(refresh)
	end)
	-- Specters and spectators are marked on their characters; catch those changes too.
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return NotePassController
