-- The Trial on this client (rules and steps: Shared/Trial): the game taught by doing, in the lobby.
--
-- A player who has never played a case is offered it once, after the lobby has come in: a wisp of pale
-- light waits at the foot of the terrace's steps and a small card says so, with Skip. Nothing is locked:
-- READY works all along, and walking away is fine. Anyone can begin it at the Academy's gate ("Begin the
-- Trial").
--
-- While it runs, the card lists the five steps and the wisp flies ahead to where the next one is done:
-- the role card is turned on the card itself; the case file, the Manual and the warrant are the Academy's
-- own drills (Controllers/AcademyController says when one is finished); the last is READY. A leak of
-- letters is shown twice on the way (your own after the case file, a dummy's before the Manual): that is
-- the thing the whole game turns on.
--
-- The server is told two things: the offer was skipped, or the Trial was finished (Services/ProfileService
-- pays the Academy's reward once).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Trial = require(Shared:WaitForChild("Trial"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))

local ClientState = require(script.Parent.Parent.ClientState)
local AcademyController = require(script.Parent.Parent.Controllers.AcademyController)
local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local LobbyIntro = require(UI.LobbyIntro)
local Screens = require(UI.Screens)

local C = Kit.color
local T = Kit.Tokens

local LocalPlayer = Players.LocalPlayer

local TrialController = {}

local TAG = "LTrialStart"
local LEAD = 14 -- how far ahead of the player the wisp flies
local PALE = Color3.fromRGB(205, 222, 245)
-- From the lobby's spawn: the foot of the terrace's steps, and the middle of the plaza (where the wisp hangs).
local AT_STEPS = Vector3.new(0, -7.4, -27)
local AT_PLAZA = Vector3.new(0, -6.4, -55)

-- "idle", "offer" (the card and the wisp wait for a yes) or "run".
local state = "idle"
local done: { [string]: boolean } = {}
local offeredThisSession = false
local cardTurned = false

local card: Frame
local progressLabel: TextLabel
local bodyLabel: TextLabel
local revealLabel: TextLabel
local checklist: Frame
local rows: { [string]: { mark: Frame, label: TextLabel } } = {}
local holdRow: Frame
local mainButton: TextButton
local leaveButton: TextButton
local wisp: BasePart? = nil
local prompts: { [BasePart]: ProximityPrompt } = {}
local closeToken = 0

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

-- How to see your role card again, for the input in the player's hands.
local function cardHint(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "press and hold your role badge"
	elseif string.find(last.Name, "Gamepad") then
		return "hold LB"
	end
	return "hold C"
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

-- The wisp -----------------------------------------------------------------------------------------------

local function makeWisp(at: Vector3): BasePart
	local part = Create("Part", {
		Name = "TrialWisp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		Position = at,
		Color = PALE,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	}) :: BasePart
	Create("PointLight", { Color = PALE, Range = 16, Brightness = 1.2, Shadows = false, Parent = part })
	return part
end

local function dropWisp()
	if wisp then
		wisp:Destroy()
		wisp = nil
	end
end

-- Where the next thing is done.
local function goal(): Vector3?
	local spawn = spawnPosition()
	if not spawn then
		return nil
	end
	if state == "offer" then
		return spawn + AT_STEPS
	end
	local step = Trial.next(done)
	if not step or step.id == "ready" then
		return spawn + AT_PLAZA
	elseif step.id == "card" then
		-- Turned where the player stands: the wisp keeps them company.
		local part = rootPart()
		return if part then part.Position + part.CFrame.LookVector * 6 + Vector3.new(0, 3, 0) else spawn + AT_STEPS
	end
	local desk = if step.drill then AcademyController.deskOf(step.drill) else nil
	return if desk then desk.Position + Vector3.new(0, 5, 0) else spawn + AT_STEPS
end

local function moveWisp(dt: number)
	if state == "idle" or not inLobby() then
		dropWisp()
		return
	end
	local target = goal()
	if not target then
		return
	end
	local part = rootPart()
	if part and state == "run" then
		local flat = Vector3.new(target.X - part.Position.X, 0, target.Z - part.Position.Z)
		if flat.Magnitude > LEAD + 4 then
			target = part.Position + flat.Unit * LEAD + Vector3.new(0, 4, 0)
		end
	end
	local bob = Vector3.new(0, math.sin(os.clock() * 2.2) * 0.35, 0)
	local current = wisp
	if not current then
		wisp = makeWisp(target)
		return
	end
	current.Position = current.Position:Lerp(target + bob, 1 - math.exp(-dt * 3.5))
	-- Walking up to the waiting wisp is a yes.
	if state == "offer" and part then
		local reach = current.Position - part.Position
		if Vector3.new(reach.X, 0, reach.Z).Magnitude < 7 then
			TrialController.begin()
		end
	end
end

-- The card -----------------------------------------------------------------------------------------------

local function showCard(on: boolean)
	closeToken += 1
	card.Visible = on and inLobby()
end

local function paintRows()
	local current = Trial.next(done)
	local count = 0
	for _, step in ipairs(Trial.STEPS) do
		local row = rows[step.id]
		local isDone = done[step.id] == true
		if isDone then
			count += 1
		end
		row.mark.BackgroundTransparency = if isDone then 0 else 1
		row.label.TextColor3 = if current and current.id == step.id then C.white elseif isDone then C.dim else C.g5
	end
	progressLabel.Text = string.format("%d / %d", count, #Trial.STEPS)
end

local function finish()
	state = "idle"
	Net.event("ProfileRequest"):FireServer({ action = "trial", event = "done" })
	bodyLabel.Text = "The Trial is done. The rest is learnt in a case."
	revealLabel.Visible = false
	holdRow.Visible = false
	mainButton.Visible = false
	leaveButton.Visible = false
	paintRows()
	local token = closeToken
	task.delay(6, function()
		if closeToken == token and state == "idle" then
			card.Visible = false
		end
	end)
end

local refresh: () -> ()

local function completeStep(id: string)
	if state ~= "run" or done[id] then
		return
	end
	done[id] = true
	refresh()
end

function refresh()
	if state ~= "run" then
		return
	end
	local step = Trial.next(done)
	if not step then
		finish()
		return
	end
	paintRows()
	revealLabel.Visible = false
	holdRow.Visible = false
	mainButton.Visible = false
	leaveButton.Visible = true
	Kit.setText(leaveButton, "Leave")
	if step.id == "card" then
		bodyLabel.Text = "In a case you have an alias everyone sees, and a real name nobody may learn. Turn your card."
		holdRow.Visible = not cardTurned
		if cardTurned then
			revealLabel.Visible = true
		end
	elseif step.id == "file" then
		bodyLabel.Text = Terms.f(
			"Follow the wisp to the Academy and work the fingerprint file. In a case, every finished file posts a clue for {agency}."
		)
	elseif step.id == "write" then
		bodyLabel.Text = Terms.f(
			"{Hand} kills by writing a real name, in full, in {grimoire}. Dummy B is giving letters away: then go to the altar and write a name."
		)
		local target = dummy("Dummy B")
		local name = if target then target:GetAttribute("PracticeName") else nil
		if target and type(name) == "string" then
			task.spawn(function()
				for _ = 1, 3 do
					if state ~= "run" or Trial.next(done) ~= step then
						return
					end
					leak(target, name, 4.2, 1.6)
					task.wait(2.4)
				end
			end)
		end
	elseif step.id == "warrant" then
		bodyLabel.Text =
			Terms.f("{Zero} can arrest {hand} once, with the full real name. Go to the warrant's altar and serve one.")
	else
		bodyLabel.Text = string.format(
			"That is the game: learn real names, guard your own. Press READY when you want a case; %d players open one.",
			Config.MIN_PLAYERS
		)
		mainButton.Visible = true
		Kit.setText(mainButton, "Done")
	end
end

local function begin()
	if state == "run" or not inLobby() then
		return
	end
	state = "run"
	done = {}
	cardTurned = false
	checklist.Visible = not Kit.Layout.isPhone()
	showCard(true)
	refresh()
end

local function offer()
	state = "offer"
	offeredThisSession = true
	done = {}
	paintRows()
	checklist.Visible = false
	revealLabel.Visible = false
	holdRow.Visible = false
	bodyLabel.Text =
		string.format("Follow the wisp. Two minutes, and you know the game.  +%d coins.", Config.TRAINING_REWARD)
	mainButton.Visible = true
	Kit.setText(mainButton, "Begin")
	leaveButton.Visible = true
	Kit.setText(leaveButton, "Skip")
	showCard(true)
end

local function leave()
	if state == "offer" then
		Net.event("ProfileRequest"):FireServer({ action = "trial", event = "skip" })
	end
	state = "idle"
	showCard(false)
end

local function onCardTurned()
	cardTurned = true
	holdRow.Visible = false
	revealLabel.Text = string.format(
		"Alias: %s.  Real name: %s.  In a case, %s to see yours again.",
		Trial.ALIAS,
		Trial.REAL_NAME,
		cardHint()
	)
	revealLabel.Visible = true
	task.delay(4.5, function()
		completeStep("card")
	end)
end

local function build()
	local page, content = Kit.page({
		Name = "Trial",
		tone = "raised",
		glass = true,
		padding = T.space.m,
		autoHeight = true,
		Size = UDim2.fromOffset(400, 0),
		Visible = false,
		Parent = Screens.hud,
	})
	card = page
	Kit.Layout.place(card, "topCenter", Vector2.new(0, 96))
	Kit.list(content, T.space.xs)
	local header = Kit.frame({ Name = "Header", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = content })
	Kit.text({ face = "Head", text = "The Trial", size = 22, color = C.white, Parent = header })
	progressLabel = Kit.label({
		font = "label",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 80, 1, 0),
		Parent = header,
	})
	bodyLabel = Kit.label({ size = "body", color = C.bone, LayoutOrder = 2, Parent = content })
	revealLabel = Kit.label({
		font = "bodyBold",
		size = "body",
		color = C.white,
		Visible = false,
		LayoutOrder = 3,
		Parent = content,
	})
	checklist = Kit.frame({
		Name = "Steps",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = content,
	})
	Kit.list(checklist, T.space.xxs)
	for order, step in ipairs(Trial.STEPS) do
		local row =
			Kit.frame({ Name = step.id, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order, Parent = checklist })
		-- A small square: filled once the step is done.
		local mark = Kit.Base.make("Frame", {
			Name = "Mark",
			BackgroundColor3 = C.white,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(9, 9),
			Parent = row,
		})
		Kit.Base.stroke(mark, C.white, 1, 0.3)
		local label = Kit.label({
			Text = step.line,
			size = "small",
			color = C.g5,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -22, 1, 0),
			Parent = row,
		})
		rows[step.id] = { mark = mark, label = label }
	end
	holdRow =
		Kit.frame({ Name = "Card", Size = UDim2.new(1, 0, 0, 52), Visible = false, LayoutOrder = 5, Parent = content })
	Kit.hold(
		{ text = "Hold to turn your card", variant = "primary", Size = UDim2.new(1, 0, 0, 48), Parent = holdRow },
		1,
		onCardTurned
	)
	local actions =
		Kit.frame({ Name = "Actions", Size = UDim2.new(1, 0, 0, T.touch), LayoutOrder = 6, Parent = content })
	Kit.list(actions, T.space.s, true)
	mainButton = Kit.button(
		{ text = "Begin", variant = "primary", size = "s", LayoutOrder = 1, Parent = actions },
		function()
			if state == "offer" then
				begin()
			elseif state == "run" then
				completeStep("ready")
			end
		end
	)
	leaveButton = Kit.button({ text = "Skip", variant = "ghost", size = "s", LayoutOrder = 2, Parent = actions }, leave)
	Kit.Layout.watch(function(class: string)
		local phone = class == "phone"
		card.Size = UDim2.fromOffset(if phone then 320 else 400, card.Size.Y.Offset)
		-- A phone has no room for the list: the count in the corner says where you are.
		checklist.Visible = state == "run" and not phone
	end)
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

-- Offers the Trial once the lobby has come in, to a profile that has never played (Trial.offered).
local function watchForOffer()
	task.spawn(function()
		while not offeredThisSession do
			task.wait(0.5)
			local profile = ClientState.profile
			if profile and state == "idle" and inLobby() and not LobbyIntro.isPlaying() and rootPart() then
				if not Trial.offered(profile) then
					return
				end
				-- Let the lobby's own entrance finish first.
				task.wait(2.5)
				if state == "idle" and inLobby() and Trial.offered(ClientState.profile) then
					offer()
				end
			end
		end
	end)
end

-- Where the Trial stands, for checks: its state and the step it waits for.
function TrialController.status(): (string, string?)
	local step = if state == "run" then Trial.next(done) else nil
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
	build()
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
		completeStep(step.id)
	end)
	ClientState.LobbyChanged:Connect(function()
		local lobby = ClientState.lobby
		local step = if state == "run" then Trial.next(done) else nil
		if step and step.id == "ready" and lobby and lobby.ready == true then
			completeStep("ready")
		end
	end)
	local function sync()
		-- Called into a case (or back from one): the card and the wisp go and come with the lobby.
		card.Visible = state ~= "idle" and inLobby()
		refreshPrompts()
	end
	ClientState.PublicChanged:Connect(sync)
	ClientState.PrivateChanged:Connect(sync)
	ClientState.WatchChanged:Connect(sync)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(setupPrompt)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(part: Instance)
		prompts[part :: BasePart] = nil
	end)
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do
		setupPrompt(part)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		moveWisp(dt)
		refreshPrompts()
	end)
	watchForOffer()
end

return TrialController
