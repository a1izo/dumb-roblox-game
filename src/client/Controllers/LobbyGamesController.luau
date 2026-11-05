--!strict
-- The lobby mini-games on this client: prompts on the tagged objects the server built (Maps/LobbyGames) and
-- a small card at the top of the screen while you climb the Spire Ascent. Every rule and score is the server's
-- (Services/LobbyGameService); this only asks (start, leave) and shows what the server says. Nothing here runs for a
-- player who is in a case or watching one.
--
-- The dive into the rift has a controller of its own (Controllers/DiveController). The name duel's two stones get
-- their prompts here (step up, step down); its card is UI/DuelPanel's.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Parkour = require(Shared:WaitForChild("LobbyGames"):WaitForChild("Parkour"))

local DiveController = require(script.Parent.DiveController)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local ClientState = require(script.Parent.Parent.ClientState)
local Curtain = require(script.Parent.Parent.UI.Curtain)
local Kit = require(script.Parent.Parent.UI.Kit)
local Screens = require(script.Parent.Parent.UI.Screens)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local LobbyGamesController = {}

local request = Net.event("LobbyGame")

-- What each tagged object offers: prompt text, and what asking does.
type Offer = { action: string, object: string, distance: number }
local OFFERS: { [string]: Offer } = {
	LParkourStart = { action = "Start climb", object = "Spire Ascent", distance = 9 },
	LDuelStone = { action = "Step up", object = "Name duel", distance = 8 },
}

local prompts: { [BasePart]: { prompt: ProximityPrompt, tag: string } } = {}

-- The card.
local card: CanvasGroup
local notice: any -- the card (Kit/Notice)
local statusLabel: TextLabel

-- What the player is doing now.
local current: string? = nil -- "parkour"
-- Is this player in a name duel now (between its start and its end)?
local duelling = false
local run = { startedAt = 0, reached = 0, total = Parkour.CHECKPOINTS }
local hideAt = 0

local function usable(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching()
end

local function setStatus(title: string, status: string)
	notice:setEyebrow(title)
	statusLabel.Text = status
	card.Visible = true
end

local function hideCard()
	current = nil
	card.Visible = false
end

local function refresh()
	local ok = usable()
	local me = Players.LocalPlayer.UserId
	for object, entry in pairs(prompts) do
		-- A Deathsinger waiting here (hidden) plays the solo games only, not the ones played with others.
		local stone = entry.tag == "LDuelStone"
		local enabled = ok and not (stone and ClientState.isAway())
		if stone then
			-- A stone someone else stands at offers nothing; your own lets you step down, but not by a slip
			-- of the key in the middle of a duel (the card has a button for giving up).
			local holder = object:GetAttribute("Holder")
			enabled = enabled and (holder == nil or (holder == me and not duelling))
			entry.prompt.ActionText = if holder == me then "Step down" else OFFERS.LDuelStone.action
		end
		entry.prompt.Enabled = enabled
	end
	if not ok and card.Visible then
		hideCard()
	end
end

-- What the server tells us ----------------------------------------------------------------------------------------

local function onParkour(p: any)
	local kind = p.kind
	if kind == "start" then
		current = "parkour"
		run.startedAt = tonumber(p.at) or workspace:GetServerTimeNow()
		run.reached = 0
		run.total = tonumber(p.total) or Parkour.CHECKPOINTS
		setStatus("SPIRE ASCENT", "Stone 0/" .. run.total .. "   0:00.0")
	elseif kind == "checkpoint" then
		run.reached = tonumber(p.index) or run.reached
		Sfx.play("gameCheckpoint", { volume = 0.8 })
		Toasts.show(string.format("Stone %d of %d", run.reached, run.total))
	elseif kind == "fall" then
		Toasts.show(
			if (tonumber(p.index) or 0) > 0
				then "You fell. Back to stone " .. p.index .. "."
				else "You fell. Back to the start."
		)
	elseif kind == "finish" then
		current = nil
		Sfx.play("gameFinish")
		local text = "Ascent complete: " .. Parkour.format(tonumber(p.time) or 0)
		Toasts.show(text .. (if p.newBest then "  New best!" else ""), "good")
		setStatus("SPIRE ASCENT", text .. "\nBest " .. Parkour.format(tonumber(p.best) or 0))
		hideAt = os.clock() + 7
	elseif kind == "end" then
		hideCard()
	end
end

-- The fall into a chasm (or off the world's edge): the screen goes to black as the body drops away under the ash,
-- the server sets it back on the terrace, and the screen comes back up there (the user's call of 2026-10-27: it had
-- cut from the dark straight to the terrace). Never for a diver (the rift's own fall) or anywhere but the lobby.
local PIT_DEPTH = 30 -- studs under the lobby's floor a falling body must be before the screen goes
local PIT_OUT = 0.35 -- seconds to black
local PIT_IN = 0.6 -- seconds back from it
local PIT_GIVE_UP = 4 -- seconds black with no catch before the screen comes back anyway

local pitDarkAt: number? = nil

local function pitLift()
	if pitDarkAt then
		pitDarkAt = nil
		Curtain.open(PIT_IN)
	end
end

local function watchPit()
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local lobby = workspace:FindFirstChild("LGameLobby")
	local spawn = if lobby then lobby:FindFirstChild("LobbySpawn", true) else nil
	if not character or not root or not root:IsA("BasePart") or not spawn or not spawn:IsA("BasePart") then
		return
	end
	if pitDarkAt then
		if os.clock() - pitDarkAt > PIT_GIVE_UP then
			pitLift()
		end
		return
	end
	local falling = root.AssemblyLinearVelocity.Y < -12
	local deep = root.Position.Y < spawn.Position.Y - PIT_DEPTH
	-- (a diver, also in the moment before the server's word reaches the character and just after the rift gives them
	-- back: this screen's own dive says so at once, so the screen is never put out over the rift)
	local diving = character:GetAttribute("Dive") ~= nil or DiveController.busy()
	if deep and falling and not diving and not ClientState.isParticipant() then
		pitDarkAt = os.clock()
		Curtain.close(PIT_OUT)
	end
end

local function onState(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.game == "parkour" then
		onParkour(payload)
	elseif payload.game == "duel" then
		if payload.kind == "start" then
			duelling = true
		elseif payload.kind == "over" or payload.kind == "left" then
			duelling = false
		end
		refresh()
	elseif payload.game == "lobby" and payload.kind == "caught" then
		-- Set back on the terrace after falling out of the world: without the speed of the fall.
		local character = Players.LocalPlayer.Character
		local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if part and part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
		-- (back on the terrace: the screen comes up from black, a moment later so the new place is drawn first)
		task.delay(0.1, pitLift)
	end
end

-- Prompts ------------------------------------------------------------------------------------------------------------

local function trigger(tag: string, object: BasePart)
	if not usable() then
		return
	end
	if tag == "LParkourStart" then
		request:FireServer({ game = "parkour", action = "start" })
	elseif tag == "LDuelStone" then
		local mine = object:GetAttribute("Holder") == Players.LocalPlayer.UserId
		request:FireServer({
			game = "duel",
			action = if mine then "leave" else "stand",
			stone = object:GetAttribute("Index"),
		})
	end
end

local function setup(tag: string, object: Instance)
	if not object:IsA("BasePart") or prompts[object] then
		return
	end
	local offer = OFFERS[tag]
	local prompt = Create("ProximityPrompt", {
		Name = "L" .. tag,
		ActionText = offer.action,
		ObjectText = offer.object,
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		MaxActivationDistance = offer.distance,
		RequiresLineOfSight = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Parent = object,
	}) :: ProximityPrompt
	prompt:SetAttribute("Binding", "interact") -- the player's own key (Input/PromptKeys)
	prompt.Triggered:Connect(function()
		trigger(tag, object)
	end)
	prompts[object] = { prompt = prompt, tag = tag }
	if tag == "LDuelStone" then
		object:GetAttributeChangedSignal("Holder"):Connect(refresh)
	end
	refresh()
end

-- The card ---------------------------------------------------------------------------------------------------------

local function build()
	-- A notice (Kit/Notice): the game's name as its eyebrow, the running status as its text, then Leave.
	notice = Kit.notice({
		Name = "LobbyGameCard",
		kind = "info",
		icon = "flag",
		body = " ",
		Visible = false,
		actions = {
			{
				text = "Leave",
				variant = "ghost",
				onClick = function()
					if current then
						request:FireServer({ game = current, action = "leave" })
					end
					hideCard()
				end,
			},
		},
		Parent = Screens.hud,
	})
	card = notice.group
	Kit.Layout.place(card, "topCenter", Vector2.new(0, 96))
	statusLabel = notice.bodyLabel
end

function LobbyGamesController.init()
	build()
	for tag in pairs(OFFERS) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(object)
			setup(tag, object)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(object)
			prompts[object :: BasePart] = nil
		end)
		for _, object in ipairs(CollectionService:GetTagged(tag)) do
			setup(tag, object)
		end
	end
	Net.event("LobbyGameState").OnClientEvent:Connect(onState)
	RunService.Heartbeat:Connect(watchPit)
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(refresh)
	ClientState.WatchChanged:Connect(refresh)
	-- The Spire Ascent's clock, and the card's goodbye a few seconds after a run ends.
	task.spawn(function()
		while true do
			task.wait(0.1)
			if current == "parkour" then
				statusLabel.Text = string.format(
					"Stone %d/%d   %s",
					run.reached,
					run.total,
					Parkour.format(workspace:GetServerTimeNow() - run.startedAt)
				)
			elseif current == nil and card.Visible and hideAt > 0 and os.clock() > hideAt then
				hideAt = 0
				hideCard()
			end
		end
	end)
end

return LobbyGamesController
