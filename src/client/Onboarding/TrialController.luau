-- The Trial on this client (rules and steps: Shared/Trial): the game taught by doing, in the lobby.
--
-- A player who has never played a case is offered it once, after the lobby has come in: the wisp waits at
-- the foot of the terrace's steps and a small panel in the top right corner says so, with Begin and Skip.
-- Nothing is locked: READY works all along, and walking away is fine. Anyone can begin it at the Academy's
-- gate ("Begin the Trial"), and a player who left it half done carries on from the same step next time.
--
-- While it runs, the panel (Onboarding/TrialObjective) shows ONE step: what to do and how; the wisp
-- (Onboarding/TrialWisp) walks you to where it is done. The steps go in order: a drill finished early counts
-- once its turn comes. The role card is the real one, with a practice identity, opened with the real control
-- (UI/RoleCard); the case file, the Manual and the warrant are the Academy's own drills (Controllers/
-- AcademyController says when one is finished; the Manual drill uses Dummy B); the last is READY. A leak of
-- letters is shown twice on the way (your own after the case file, Dummy B's before the Manual): that is the
-- thing the whole game turns on.
--
-- The server is told three things: how many steps are done (saved, for a rejoin), the offer was skipped, or
-- the Trial was finished (Services/ProfileService pays the Academy's reward once).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Trial = require(Shared:WaitForChild("Trial"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))

local ClientState = require(script.Parent.Parent.ClientState)
local AcademyController = require(script.Parent.Parent.Controllers.AcademyController)
local CoreGuiController = require(script.Parent.Parent.Controllers.CoreGuiController)
local TrialObjective = require(script.Parent.TrialObjective)
local TrialWisp = require(script.Parent.TrialWisp)
local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local LobbyIntro = require(UI.LobbyIntro)
local PracticePanel = require(UI.PracticePanel)
local RoleCard = require(UI.RoleCard)

local C = Kit.color

local LocalPlayer = Players.LocalPlayer
local ProfileRequest = Net.event("ProfileRequest")

local TrialController = {}

local TAG = "LTrialStart"
local DUMMY = "Dummy B" -- whose letters leak, and whose name is written in the Manual
-- From the lobby's spawn: the foot of the terrace's steps, and the middle of the plaza (the candle circle).
local AT_STEPS = Vector3.new(0, -7.4, -27)
local AT_PLAZA = Vector3.new(0, -6.4, -55)
local CARD_SECONDS = 1.5 -- how long the role card must be held open to count as read
local BEGIN_REACH = 7 -- walking this close to the waiting wisp is a yes

-- "idle", "offer" (the panel and the wisp wait for a yes) or "run".
local state = "idle"
local done: { [string]: boolean } = {}
local early: { [string]: boolean } = {} -- drills finished before their step came
local between = false -- a step was just done: its "why" is showing
local offeredThisSession = false
local cardOpenSince: number? = nil
local cardSeconds = 0
local sentStep = -1
local prompts: { [BasePart]: ProximityPrompt } = {}

local function inLobby(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching()
end

local function rootPart(): BasePart?
	local character = LocalPlayer.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if part and part:IsA("BasePart") then part else nil
end

local function spawnPosition(): Vector3?
	local lobby = workspace:FindFirstChild("LGameLobby")
	local spawn = if lobby then lobby:FindFirstChild("LobbySpawn", true) else nil
	return if spawn and spawn:IsA("BasePart") then spawn.Position else nil
end

local function isTouch(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

-- How to turn the role card, for the input in the player's hands.
local function cardKey(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Press and hold the button below"
	elseif string.find(last.Name, "Gamepad") then
		return "Hold LB"
	end
	return "Hold C"
end

local function current(): Trial.Step?
	return if state == "run" then Trial.next(done) else nil
end

-- Letters ------------------------------------------------------------------------------------------------

-- Three letters of a real name over someone's head for a moment: what a finished case file gives away.
local function leak(adornee: BasePart, name: string, height: number, seconds: number)
	local letters = {}
	for at = 1, #name do
		local letter = string.sub(name, at, at)
		if string.match(letter, "%a") then
			table.insert(letters, string.upper(letter))
		end
	end
	local picked = {}
	for _ = 1, math.min(3, #letters) do
		table.insert(picked, table.remove(letters, math.random(1, #letters)))
	end
	local gui = Create("BillboardGui", {
		Name = "TrialLeak",
		Adornee = adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromScale(6, 1.6),
		StudsOffset = Vector3.new(0, height, 0),
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = table.concat(picked, "   "),
		TextColor3 = C.white,
		TextStrokeTransparency = 0.3,
		TextScaled = true,
		FontFace = WorldFont.face(Enum.Font.GothamBlack),
		Parent = gui,
	})
	task.delay(seconds, function()
		gui:Destroy()
	end)
end

local function dummy(alias: string): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("LDummy")) do
		if part:IsA("BasePart") and part:GetAttribute("Alias") == alias and part:IsDescendantOf(workspace) then
			return part
		end
	end
	return nil
end

-- Dummy B gives letters away for as long as the Manual is the step.
local function leakWhileWriting()
	task.spawn(function()
		while true do
			local step = current()
			if not step or step.id ~= "write" then
				return
			end
			local target = dummy(DUMMY)
			local name = if target then target:GetAttribute("PracticeName") else nil
			if target and type(name) == "string" and inLobby() then
				leak(target, name, 4.2, 2)
			end
			task.wait(4)
		end
	end)
end

-- Saving progress ------------------------------------------------------------------------------------------

-- Tells the server how many steps are done, a moment later (one message for several quick steps).
local function saveProgress()
	task.delay(0.6, function()
		local count = Trial.count(done)
		if state == "run" and count ~= sentStep and count < #Trial.STEPS then
			sentStep = count
			ProfileRequest:FireServer({ action = "trialStep", step = count })
		end
	end)
end

-- The wisp ---------------------------------------------------------------------------------------------------

-- Where the wisp goes for the state and step we are in.
local function steerWisp()
	if state == "idle" or not inLobby() then
		TrialWisp.clear()
		return
	end
	local spawn = spawnPosition()
	if not spawn then
		return
	end
	if state == "offer" then
		TrialWisp.target("offer", spawn + AT_STEPS, "wait")
		return
	end
	local step = current()
	if not step then
		return
	end
	if step.id == "card" then
		-- Turned where the player stands: the wisp keeps them company.
		local part = rootPart()
		if part then
			TrialWisp.target("card", part.Position + part.CFrame.LookVector * 6 + Vector3.new(0, 3, 0), "wait")
		end
	elseif step.id == "ready" then
		TrialWisp.target("ready", spawn + AT_PLAZA, "lead")
	else
		local desk = if step.drill then AcademyController.deskOf(step.drill) else nil
		if desk then
			TrialWisp.target(step.id, desk.Position + Vector3.new(0, 5, 0), "lead")
		end
	end
end

-- Steps ------------------------------------------------------------------------------------------------------

local showStep: () -> ()

local function finish()
	state = "idle"
	between = false
	ProfileRequest:FireServer({ action = "trial", event = "done" })
	TrialObjective.finish("The Trial is done", Trial.text(Trial.BY_ID.ready.why))
	TrialWisp.clear()
	RoleCard.setPractice(nil)
	PracticePanel.prefer(nil)
	CoreGuiController.setTrialRunning(false)
end

local function completeStep(id: string)
	local step = current()
	if between or not step or step.id ~= id then
		return
	end
	done[id] = true
	if Trial.complete(done) then
		finish()
		return
	end
	between = true
	saveProgress()
	TrialObjective.done(Trial.text(step.why), function()
		between = false
		if state == "run" then
			showStep()
		end
	end)
end

function showStep()
	local step = current()
	if not step then
		finish()
		return
	end
	local index = Trial.count(done) + 1
	cardOpenSince, cardSeconds = nil, 0
	RoleCard.setPractice(
		if step.id == "card" then { role = "TaskForce", alias = Trial.ALIAS, realName = Trial.REAL_NAME } else nil
	)
	PracticePanel.prefer(if step.id == "write" then DUMMY else nil)
	TrialObjective.step(
		index,
		#Trial.STEPS,
		step.line,
		Trial.text(step.how, { cardKey = cardKey() }),
		step.id == "card" and isTouch()
	)
	steerWisp()
	if step.id == "write" then
		leakWhileWriting()
	end
	-- Already done ahead of its turn: it counts now.
	local lobby = ClientState.lobby
	if (step.drill and early[step.drill]) or (step.id == "ready" and lobby and lobby.ready == true) then
		task.delay(0.8, function()
			completeStep(step.id)
		end)
	end
end

local function begin()
	if state == "run" or not inLobby() then
		return
	end
	-- Carry on from where it was left (a finished Trial begun again at the gate starts over).
	local saved = if ClientState.profile then ClientState.profile.trial else nil
	local from = if type(saved) == "table" and saved.done ~= true then tonumber(saved.step) or 0 else 0
	state = "run"
	done = Trial.doneUpTo(from)
	early = {}
	between = false
	sentStep = Trial.count(done)
	CoreGuiController.setTrialRunning(true)
	showStep()
end

local function offer()
	state = "offer"
	offeredThisSession = true
	TrialObjective.offer(Trial.OFFER_TITLE, Trial.OFFER_LINE, begin, function()
		ProfileRequest:FireServer({ action = "trial", event = "skip" })
		state = "idle"
		TrialObjective.hide()
		TrialWisp.clear()
	end)
	steerWisp()
end

-- The panel's X: stop for now (the progress is kept; the gate starts it again).
local function leave()
	if state == "offer" then
		ProfileRequest:FireServer({ action = "trial", event = "skip" })
	end
	state = "idle"
	between = false
	TrialObjective.hide()
	TrialWisp.clear()
	RoleCard.setPractice(nil)
	PracticePanel.prefer(nil)
	CoreGuiController.setTrialRunning(false)
end

-- The role card: held open long enough, the first step is done.
local function cardShown(shown: boolean)
	local step = current()
	if not step or step.id ~= "card" then
		return
	end
	if shown then
		cardOpenSince = os.clock()
	elseif cardOpenSince then
		cardSeconds += os.clock() - cardOpenSince
		cardOpenSince = nil
	end
end

local function watchCard()
	local step = current()
	if not step or step.id ~= "card" or between then
		return
	end
	local open = cardSeconds + (if cardOpenSince then os.clock() - cardOpenSince else 0)
	if open >= CARD_SECONDS then
		completeStep("card")
	end
end

-- Starting ------------------------------------------------------------------------------------------------

local function setupPrompt(part: Instance)
	if not part:IsA("BasePart") or prompts[part] then
		return
	end
	local prompt = Create("ProximityPrompt", {
		Name = "LTrial",
		ActionText = "Begin the Trial",
		ObjectText = "The Academy",
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Parent = part,
	}) :: ProximityPrompt
	prompt.Triggered:Connect(begin)
	prompts[part] = prompt
end

local function refreshPrompts()
	for _, prompt in pairs(prompts) do
		prompt.Enabled = state ~= "run" and inLobby()
	end
end

-- Offers the Trial once the lobby has come in, to a profile that has never played (Trial.offered); one that
-- began it before carries straight on. It keeps looking until the profile is loaded far enough to tell.
local function watchForOffer()
	task.spawn(function()
		while not offeredThisSession and state == "idle" do
			task.wait(0.5)
			local profile = ClientState.profile
			if Trial.known(profile) and inLobby() and not LobbyIntro.isPlaying() and rootPart() then
				if not Trial.offered(profile) then
					return
				end
				-- Let the lobby's own entrance finish first.
				task.wait(2.5)
				if state == "idle" and inLobby() and Trial.offered(ClientState.profile) then
					offeredThisSession = true
					if (tonumber(ClientState.profile.trial.step) or 0) > 0 then
						begin()
					else
						offer()
					end
				end
				return
			end
		end
	end)
end

-- Where the Trial stands, for checks: its state and the step it waits for.
function TrialController.status(): (string, string?)
	local step = current()
	return state, if step then step.id else nil
end

-- Starts it now (as the gate's prompt does).
function TrialController.begin()
	begin()
end

-- Counts a step as done (what turning the card, finishing a drill or pressing READY does).
function TrialController.complete(id: string)
	if Trial.BY_ID[id] then
		completeStep(id)
	end
end

function TrialController.init()
	TrialObjective.init()
	TrialObjective.wire(leave, function(held: boolean)
		if held then
			RoleCard.show()
		else
			RoleCard.hide()
		end
	end)
	RoleCard.Changed:Connect(cardShown)
	AcademyController.DrillDone:Connect(function(drill: string)
		local step = Trial.stepForDrill(drill)
		if state ~= "run" or not step or done[step.id] then
			return
		end
		if step.id == "file" then
			-- Your own letters, as anyone near you would have seen them.
			local character = LocalPlayer.Character
			local head = if character then character:FindFirstChild("Head") else nil
			if head and head:IsA("BasePart") then
				leak(head, Trial.REAL_NAME, 2.6, 3.5)
			end
		end
		local now = current()
		if now and now.id == step.id and not between then
			completeStep(step.id)
		else
			-- Not its turn yet: it counts when its step comes.
			early[drill] = true
		end
	end)
	ClientState.LobbyChanged:Connect(function()
		local lobby = ClientState.lobby
		local step = current()
		if step and step.id == "ready" and lobby and lobby.ready == true then
			completeStep("ready")
		end
	end)
	local function sync()
		-- Called into a case (or back from one): the panel and the wisp go and come with the lobby.
		TrialObjective.setAllowed(inLobby())
		steerWisp()
		refreshPrompts()
	end
	ClientState.PublicChanged:Connect(sync)
	ClientState.PrivateChanged:Connect(sync)
	ClientState.WatchChanged:Connect(sync)
	UserInputService.LastInputTypeChanged:Connect(function()
		-- The role card's control follows the hands: C, LB, or the button on a touch screen.
		local step = current()
		if step and step.id == "card" and not between then
			TrialObjective.setHow(Trial.text(step.how, { cardKey = cardKey() }))
		end
	end)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(setupPrompt)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(part: Instance)
		prompts[part :: BasePart] = nil
	end)
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do
		setupPrompt(part)
	end
	RunService.Heartbeat:Connect(function()
		if state ~= "idle" and inLobby() then
			local step = current()
			if state == "offer" or (step and step.id == "card") then
				-- The waiting spot (the offer), or the spot in front of you (the role card), every frame.
				steerWisp()
			end
			if state == "offer" then
				local part, at = rootPart(), TrialWisp.position()
				if part and at then
					local reach = at - part.Position
					if Vector3.new(reach.X, 0, reach.Z).Magnitude < BEGIN_REACH then
						begin()
					end
				end
			end
			watchCard()
		end
		refreshPrompts()
	end)
	watchForOffer()
end

return TrialController
