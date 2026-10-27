-- The Trial on this client (rules and steps: Shared/Trial): the game taught by doing, in the lobby.
--
-- A player who has never played a case is offered it once, after the lobby has come in: the wisp waits at
-- the foot of the terrace's steps and a small panel in the top right corner says so, with Begin and Skip.
-- Nothing is locked: READY works all along, and walking away is fine. Anyone can begin it at the Academy's
-- gate ("Begin the Trial"), and a player who left it half done carries on from the same step next time. Being
-- called into a case ends it for good: it is not offered again (only the gate begins it).
--
-- While it runs, the panel (Onboarding/TrialObjective) shows ONE step: what to do and how; the wisp
-- (Onboarding/TrialWisp) walks you to where it is done. The steps go in order: a drill finished early counts
-- once its turn comes. The role card is the real one, with a practice identity, opened with the real control
-- (UI/RoleCard); the case file, the Manual and the arrest are the Academy's own drills (Controllers/
-- AcademyController says when one is finished); the last is READY. Before the Manual comes the thing the whole
-- game turns on: the player stares at Dummy B (the stare key, standing still, close by) with their eyes
-- glowing red, and its real name shows over its head as a stare shows it in a case (UI/WorldFx). Only then
-- does the Manual drill count, and it lists the name learned (UI/PracticePanel.prefer).
--
-- The server is told three things: how many steps are done (saved, for a rejoin), the offer was skipped, or
-- the Trial was finished (Services/ProfileService pays the Academy's reward once).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared:WaitForChild("Bindings"))
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Trial = require(Shared:WaitForChild("Trial"))

local ClientState = require(script.Parent.Parent.ClientState)
local Keys = require(script.Parent.Parent.Input.Keys)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local AcademyController = require(script.Parent.Parent.Controllers.AcademyController)
local CoreGuiController = require(script.Parent.Parent.Controllers.CoreGuiController)
local Cinema = require(script.Parent.Parent.Presentation.Cinema)
local Puppets = require(script.Parent.Parent.World.Puppets)
local TrialObjective = require(script.Parent.TrialObjective)
local TrialWisp = require(script.Parent.TrialWisp)
local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local LobbyIntro = require(UI.LobbyIntro)
local Motion = require(UI.Core.Motion)
local PracticePanel = require(UI.PracticePanel)
local RoleCard = require(UI.RoleCard)
local Toasts = require(UI.Toasts)

local C = Kit.color

local LocalPlayer = Players.LocalPlayer
local ProfileRequest = Net.event("ProfileRequest")

local TrialController = {}

local TAG = "LTrialStart"
local DUMMY = "Dummy B" -- whose real name is learned by staring, then written in the Manual
-- From the lobby's spawn: the foot of the terrace's steps, and the middle of the plaza (the candle circle).
local AT_STEPS = Vector3.new(0, -7.4, -27)
local AT_PLAZA = Vector3.new(0, -6.4, -55)
local CARD_SECONDS = 1.5 -- how long the role card must be held open to count as read
local BEGIN_REACH = 7 -- walking this close to the waiting wisp is a yes
local STARE_ACTION = "DeathsGambit_TrialStare"
local STILL_SPEED = 2.5 -- faster than this (studs per second, flat) and a stare breaks, as in a case
local NAME_SECONDS = Config.EYES_DURATION + 1 -- the learned name stays a moment longer than in a case

-- "idle", "offer" (the panel and the wisp wait for a yes) or "run".
local state = "idle"
local done: { [string]: boolean } = {}
-- Steps done before their turn (a drill finished ahead, or the next step done while the last one's "why"
-- still shows), by step id: each counts as soon as it comes up.
local early: { [string]: boolean } = {}
local between = false -- a step was just done: its "why" is showing
local offeredThisSession = false
local cardOpenSince: number? = nil
local cardSeconds = 0
local sentStep = -1
local prompts: { [BasePart]: ProximityPrompt } = {}
-- The Manual's step: Dummy B's name learned by staring (this run), the stare going on, the stare key bound.
local stared = false
local staring: { since: number, stop: () -> () }? = nil
local stareBound = false

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

-- How to turn the role card, for the input in the player's hands (their own key: Input/Keys).
local function cardKey(): string
	if Keys.input() == "touch" then
		return "Press and hold the button below"
	end
	local key = Keys.text("roleCard")
	return if key ~= "" then "Hold " .. key else "Hold your role card's key"
end

-- The stare's control, for the input in the player's hands (their own key where they rebound it).
local function stareKey(): string
	if Keys.input() == "touch" then
		return "the Stare button"
	end
	local key = Keys.text("eyesRead")
	return if key ~= "" then key else "the stare's key"
end

-- What a step's "how" line fills in.
local function howVars(): { [string]: any }
	return { cardKey = cardKey(), stareKey = stareKey() }
end

local function current(): Trial.Step?
	return if state == "run" then Trial.next(done) else nil
end

-- The stare --------------------------------------------------------------------------------------------------

local function dummy(alias: string): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("LDummy")) do
		if part:IsA("BasePart") and part:GetAttribute("Alias") == alias and part:IsDescendantOf(workspace) then
			return part
		end
	end
	return nil
end

-- What a stare looks at: the puppet's head, or the grey stand-in itself.
local function lookAt(target: BasePart): BasePart
	return Puppets.headOf(target) or target
end

local function myHead(): BasePart?
	local character = LocalPlayer.Character
	local head = if character then character:FindFirstChild("Head") else nil
	return if head and head:IsA("BasePart") then head else nil
end

-- Red eyes on your own head for as long as the stare lasts (as CharacterService.glowEyes shows them in a
-- case), and a red edge round the screen, since the camera sits behind you. Returns a remover.
local function glowEyes(): () -> ()
	local head = myHead()
	local eyes = {}
	if head then
		for _, side in ipairs({ -0.2, 0.2 }) do
			local eye = Create("Part", {
				Name = "TrialEye",
				Size = Vector3.new(0.2, 0.12, 0.06),
				Color = Color3.fromRGB(255, 25, 25),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Massless = true,
				CFrame = head.CFrame * CFrame.new(side, 0.12, -head.Size.Z / 2 - 0.03),
				Parent = head,
			})
			Create("WeldConstraint", { Part0 = head, Part1 = eye, Parent = eye })
			table.insert(eyes, eye)
		end
		Create("PointLight", { Color = Color3.fromRGB(255, 40, 40), Range = 8, Brightness = 4, Parent = eyes[1] })
	end
	local unvignette = Cinema.vignette(C.danger, 0.22)
	return function()
		for _, eye in ipairs(eyes) do
			eye:Destroy()
		end
		unvignette()
	end
end

-- The real name over the dummy's head, as a stare shows it in a case (UI/WorldFx): a red pulse, the dummy
-- outlined for you alone, the name glitching into place.
local function showName(target: BasePart, name: string)
	local head = Puppets.headOf(target)
	local model = if head then head:FindFirstAncestorOfClass("Model") else target.Parent
	local gui = Create("BillboardGui", {
		Name = "TrialStareName",
		Adornee = head or target,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 80,
		Size = UDim2.fromScale(8, 1.4),
		StudsOffset = Vector3.new(0, if head then 1.6 else 3.6, 0),
		ResetOnSpawn = false,
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
	local finalText = string.upper(name)
	local label = Kit.label({
		font = "document",
		TextScaled = true,
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = C.danger,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = finalText,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	Sfx.play("eyesOpen", { volume = 0.6 })
	Cinema.flash(C.danger, 0.35, 0.4)
	if model then
		Cinema.outline(model, C.danger, NAME_SECONDS)
	end
	if not Motion.isReduced() then
		task.spawn(function()
			local glyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#%&"
			for step = 1, 8 do
				if not label.Parent then
					return
				end
				local chars = {}
				for i = 1, #finalText do
					local c = string.sub(finalText, i, i)
					if c ~= " " and math.random() > step / 8 then
						local r = math.random(1, #glyphs)
						c = string.sub(glyphs, r, r)
					end
					table.insert(chars, c)
				end
				label.Text = table.concat(chars)
				task.wait(0.05)
			end
			label.Text = finalText
		end)
	end
	task.delay(NAME_SECONDS, function()
		gui:Destroy()
	end)
end

local function stopStare(why: string?)
	local now = staring
	if not now then
		return
	end
	staring = nil
	now.stop()
	if why then
		Toasts.show(why, "bad")
	end
end

-- The stare key: Dummy B close by and on the screen, the stare begins.
local function startStare()
	local step = current()
	if not step or step.id ~= "write" or stared or staring or between or not inLobby() then
		return
	end
	local target, head, camera = dummy(DUMMY), myHead(), workspace.CurrentCamera
	if not target or not head or not camera then
		return
	end
	local at = lookAt(target).Position
	local _, onScreen = camera:WorldToViewportPoint(at)
	if (at - head.Position).Magnitude > Config.STARE_RANGE or not onScreen then
		Toasts.show(string.format("Look at %s from within %d studs.", DUMMY, Config.STARE_RANGE), "bad")
		return
	end
	staring = { since = os.clock(), stop = glowEyes() }
	Toasts.show("Staring... stand still and keep them in sight.", "secret")
end

-- Binds the stare's keys (and a Stare button on a touch screen) while the stare is the thing to do.
local function bindStare(on: boolean)
	if on == stareBound then
		return
	end
	stareBound = on
	if not on then
		ContextActionService:UnbindAction(STARE_ACTION)
		return
	end
	local saved = if ClientState.profile then ClientState.profile.keybinds else nil
	local inputs = Bindings.keyCodes("eyesRead", "keyboard", saved)
	for _, key in ipairs(Bindings.keyCodes("eyesRead", "gamepad", saved)) do
		table.insert(inputs, key)
	end
	ContextActionService:BindAction(STARE_ACTION, function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		startStare()
		return Enum.ContextActionResult.Sink
	end, true, table.unpack(inputs))
	ContextActionService:SetTitle(STARE_ACTION, "Stare")
end

local steerWisp: () -> ()

-- Every frame: the stare keys are bound while they are wanted, and a stare going on breaks or finishes.
local function watchStare()
	local step = current()
	local wanted = step ~= nil and step.id == "write" and not stared and not between and inLobby()
	bindStare(wanted)
	local now = staring
	if not now then
		return
	end
	local target, head, root = dummy(DUMMY), myHead(), rootPart()
	if not wanted or not target or not head or not root then
		stopStare(nil)
		return
	end
	local v = root.AssemblyLinearVelocity
	if Vector3.new(v.X, 0, v.Z).Magnitude > STILL_SPEED then
		stopStare("You moved: the stare broke.")
	elseif (lookAt(target).Position - head.Position).Magnitude > Config.STARE_RANGE then
		stopStare("You lost sight of them: the stare broke.")
	elseif os.clock() - now.since >= Config.STARE_TIME then
		stopStare(nil)
		stared = true
		local name = target:GetAttribute("PracticeName")
		if type(name) == "string" then
			showName(target, name)
		end
		-- The Manual drill now lists the name learned, and the wisp goes on to the Manual.
		PracticePanel.prefer(DUMMY, true)
		if step and step.howNext then
			TrialObjective.setHow(Trial.text(step.howNext, howVars()))
		end
		steerWisp()
	end
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
function steerWisp()
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
	elseif step.id == "write" and not stared then
		-- First the dummy to stare at; the Manual's altar once its name is learned.
		local target = dummy(DUMMY)
		if target then
			TrialWisp.target("stare", target.Position + Vector3.new(0, 4, 0), "lead")
		end
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
	if not step or step.id ~= id then
		return
	end
	if between then
		-- Done while the last step's "why" still shows: it counts the moment it comes up.
		early[id] = true
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
	if step.id == "write" then
		PracticePanel.prefer(DUMMY, stared)
	else
		PracticePanel.prefer(nil)
	end
	local how = if step.id == "write" and stared and step.howNext then step.howNext else step.how
	TrialObjective.step(index, #Trial.STEPS, step.line, Trial.text(how, howVars()), step.id == "card" and isTouch())
	steerWisp()
	-- Already done ahead of its turn: it counts now.
	local lobby = ClientState.lobby
	if early[step.id] or (step.id == "ready" and lobby and lobby.ready == true) then
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
	stared = false
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
	stopStare(nil)
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
	prompt:SetAttribute("Binding", "interact") -- the player's own key (Input/PromptKeys)
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
		if step.id == "write" and not stared then
			-- The Manual only counts with a name learned by staring (this run): never ahead of its turn.
			return
		end
		local now = current()
		if now and now.id == step.id then
			completeStep(step.id)
		else
			-- Not its turn yet: it counts when its step comes.
			early[step.id] = true
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
		-- Called into a case: the Trial ends for good (the server marks it so); never a wisp pointing at the
		-- lobby's desks from the map.
		if state ~= "idle" and ClientState.public.active and ClientState.me() ~= nil then
			leave()
			offeredThisSession = true
		end
		TrialObjective.setAllowed(inLobby())
		steerWisp()
		refreshPrompts()
	end
	ClientState.PublicChanged:Connect(sync)
	ClientState.PrivateChanged:Connect(sync)
	ClientState.WatchChanged:Connect(sync)
	UserInputService.LastInputTypeChanged:Connect(function()
		-- The role card's and the stare's controls follow the hands: C or R, LB or RB, or a button on a touch
		-- screen.
		local step = current()
		if step and (step.id == "card" or (step.id == "write" and not stared)) and not between then
			TrialObjective.setHow(Trial.text(step.how, howVars()))
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
		watchStare()
		refreshPrompts()
	end)
	watchForOffer()
end

return TrialController
