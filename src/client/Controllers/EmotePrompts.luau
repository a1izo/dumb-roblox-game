-- The prompts that come with emotes, drawn like every other prompt in the game (UI/PromptView: a keycap, the
-- action, the object; on touch screens the keycap is the button):
--   a press-to-do moment  over this player's head while their emote's window is open (Shared/EmoteInfo
--                         `context`: "LOOK UP", "EAT"...): one press plays its branch, the same on every screen
--   Join in               over anyone near who is doing a looping dance (not a stroll, a stance or a duo): this
--                         player joins it, on its beat. In the lobby anyone may; in a case only a dancer who owns
--                         it (the server checks both, and the reach)
--   Get it                over this player's head after joining a dance they do not own: opens the shop on it
-- Every prompt is made on this client only, and marked "DGEmote" (a copy of the body leaves it out).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local ClientState = require(script.Parent.Parent.ClientState)
local EmoteController = require(script.Parent.EmoteController)
local ShopPanel = require(script.Parent.Parent.UI.ShopPanel)

local LocalPlayer = Players.LocalPlayer

local EmotePrompts = {}

EmotePrompts.CONTEXT_KEY = Enum.KeyCode.F
EmotePrompts.CONTEXT_PAD = Enum.KeyCode.ButtonX
EmotePrompts.JOIN_KEY = Enum.KeyCode.J
EmotePrompts.JOIN_PAD = Enum.KeyCode.ButtonY

local JOIN_REACH = 10 -- studs (the server allows a little more, for a step taken while the press travels)
local GET_IT_SECONDS = 8 -- how long "Get it" stays after a joined dance ends
local CUTSCENE_PHASES = { Intro = true, Verdict = true, Outro = true, Reveal = true }

local function make(
	parent: Instance,
	name: string,
	key: Enum.KeyCode,
	pad: Enum.KeyCode,
	reach: number
): ProximityPrompt
	local prompt = Create("ProximityPrompt", {
		Name = name,
		KeyboardKeyCode = key,
		GamepadKeyCode = pad,
		HoldDuration = 0,
		MaxActivationDistance = reach,
		RequiresLineOfSight = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Enabled = false,
		Parent = parent,
	}) :: ProximityPrompt
	prompt:SetAttribute("DGEmote", true)
	return prompt
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Where an emote is now, seconds into its clip (a loop on the shared beat, as every screen plays it).
local function into(session: EmoteController.Session): number?
	local prepared = ClipPlayer.get(session.clip)
	if prepared and prepared.loop and prepared.length > 0 then
		return workspace:GetServerTimeNow() % prepared.length
	end
	return if session.at then workspace:GetServerTimeNow() - session.at else nil
end
EmotePrompts.into = into

-- May this player emote where they are now (the server decides each emote; this only hides prompts that
-- could never work: watching a case from the lobby, waiting hidden, a cutscene)?
local function canEmote(): boolean
	if ClientState.isParticipant() then
		return (ClientState.isLiving() or ClientState.isSpecter()) and not CUTSCENE_PHASES[ClientState.phase()]
	end
	return not ClientState.isWatching() and not ClientState.isAway()
end

-- A dance others may join: an emote of the wheel that loops, not walked (a stroll), stood in (a stance) or
-- played by two.
local function joinable(clip: string): boolean
	local prepared = ClipPlayer.get(clip)
	if not prepared or not prepared.loop or not QuickChat.emote(clip) then
		return false
	end
	local info = EmoteInfo.of(clip)
	return not info.stroll and not info.stance and not info.duo
end
EmotePrompts.joinable = joinable

-- The press-to-do moment ----------------------------------------------------------------------------------------

local context: ProximityPrompt? = nil
local pressed: { [EmoteController.Session]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function updateContext()
	local character = LocalPlayer.Character
	local session = EmoteController.session(character)
	local window = if session
			and session.alive
			and session.from == nil
			and not pressed[session]
		then EmoteInfo.of(session.clip).context
		else nil
	local open = false
	if session and window then
		local t = into(session)
		open = t ~= nil and t >= window.from and t <= window.to
	end
	local root = rootOf(character)
	if not open or not root or not session or not window then
		if context then
			context.Enabled = false
		end
		return
	end
	local prompt = context
	if not prompt or prompt.Parent ~= root then
		if prompt then
			prompt:Destroy()
		end
		local made = make(root, "LEmoteContext", EmotePrompts.CONTEXT_KEY, EmotePrompts.CONTEXT_PAD, 8)
		made.Triggered:Connect(function()
			local now = EmoteController.session(LocalPlayer.Character)
			if now then
				pressed[now] = true
			end
			made.Enabled = false
			EmoteController.press()
		end)
		context = made
		prompt = made
	end
	prompt.ActionText = window.label
	prompt.ObjectText = EmoteInfo.of(session.clip).name
	prompt.Enabled = true
end

-- Join in -------------------------------------------------------------------------------------------------------

type Join = { prompt: ProximityPrompt, clip: string, userId: number }
local joins: { [Model]: Join } = {}

local function dropJoin(character: Model)
	local join = joins[character]
	if join then
		joins[character] = nil
		join.prompt:Destroy()
	end
end

local function offerJoin(character: Model, session: EmoteController.Session)
	dropJoin(character)
	-- (a player's body, or in Studio a test bot's)
	local player = Players:GetPlayerFromCharacter(character)
	local userId = if player then player.UserId else character:GetAttribute("BotUserId")
	local root = rootOf(character)
	if type(userId) ~= "number" or player == LocalPlayer or not root or not joinable(session.clip) then
		return
	end
	local prompt = make(root, "LEmoteJoin", EmotePrompts.JOIN_KEY, EmotePrompts.JOIN_PAD, JOIN_REACH)
	prompt.ActionText = "Join in"
	prompt.ObjectText = EmoteInfo.of(session.clip).name
	prompt.Triggered:Connect(function()
		EmoteController.joinIn(userId)
	end)
	joins[character] = { prompt = prompt, clip = session.clip, userId = userId }
end

local function updateJoins()
	local allowed = canEmote()
	local mine = EmoteController.session(LocalPlayer.Character)
	for character, join in pairs(joins) do
		if not character.Parent then
			dropJoin(character)
			continue
		end
		local show = allowed and not (mine and mine.alive and mine.clip == join.clip)
		if show and ClientState.isParticipant() then
			-- in a case, only your own dances
			local emote = QuickChat.emote(join.clip)
			show = emote ~= nil and EmoteWheel.owns(ClientState.profile, emote)
		end
		join.prompt.Enabled = show
	end
end

-- Get it --------------------------------------------------------------------------------------------------------

local getIt: ProximityPrompt? = nil
local getItToken = 0

local function offerGetIt(session: EmoteController.Session)
	local item = EmoteInfo.of(session.clip).item
	local root = rootOf(session.character)
	if not item or not root then
		return
	end
	if getIt then
		getIt:Destroy()
	end
	local prompt = make(root, "LEmoteGetIt", EmotePrompts.JOIN_KEY, EmotePrompts.JOIN_PAD, 8)
	prompt.ActionText = "Get it"
	prompt.ObjectText = item.name
	prompt.Enabled = true
	prompt.Triggered:Connect(function()
		prompt:Destroy()
		ShopPanel.focus(item.id)
	end)
	getIt = prompt
	getItToken += 1
end

local function endGetIt(token: number)
	task.delay(GET_IT_SECONDS, function()
		if getItToken == token and getIt then
			getIt:Destroy()
			getIt = nil
		end
	end)
end

-- For checks: the prompts showing now.
function EmotePrompts.state(): { context: ProximityPrompt?, joins: { [Model]: ProximityPrompt }, getIt: ProximityPrompt? }
	local list = {}
	for character, join in pairs(joins) do
		list[character] = join.prompt
	end
	return {
		context = if context and context.Parent and context.Enabled then context else nil,
		joins = list,
		getIt = if getIt and getIt.Parent then getIt else nil,
	}
end

function EmotePrompts.init()
	EmoteController.Started:Connect(function(character: Model, session: EmoteController.Session)
		if character == LocalPlayer.Character then
			if session.joined and session.owned == false then
				offerGetIt(session)
			end
		elseif session.handle then
			offerJoin(character, session)
		end
	end)
	EmoteController.Ended:Connect(function(character: Model, clip: string)
		local join = joins[character]
		if join and join.clip == clip then
			dropJoin(character)
		end
		if character == LocalPlayer.Character and getIt then
			endGetIt(getItToken)
		end
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		updateContext()
		local now = os.clock()
		if now - last >= 0.2 then
			last = now
			updateJoins()
		end
	end)
end

return EmotePrompts
