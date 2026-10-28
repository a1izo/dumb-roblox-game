--!strict
-- The lobby mini-games on this client: prompts on the tagged objects the server built (Maps/LobbyGames),
-- a small card at the top of the screen while you are playing, the rune tiles lit for you alone, and the
-- thrown pebble's flight. Every rule and score is the server's (Services/LobbyGameService); this only
-- asks (start, throw, leave) and shows what the server says. Nothing here runs for a player
-- who is in a case or watching one.
--
-- Also here: the bell of Death's mark (join or leave at it; the card says who carries the mark and when
-- the bell tolls next; what shows on the characters is Controllers/MarkController's) and the seven grey
-- apples (a prompt on each; the ones this player has found are hidden on this screen). The dive into the
-- rift has a controller of its own (Controllers/DiveController). The name duel's two stones get their
-- prompts here (step up, step down); its card is UI/DuelPanel's.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Parkour = require(Shared:WaitForChild("LobbyGames"):WaitForChild("Parkour"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local ClientState = require(script.Parent.Parent.ClientState)
local Curtain = require(script.Parent.Parent.UI.Curtain)
local Kit = require(script.Parent.Parent.UI.Kit)
local Screens = require(script.Parent.Parent.UI.Screens)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local LobbyGamesController = {}

local request = Net.event("LobbyGame")

local GLOW_ON = Color3.fromRGB(206, 224, 255)
local GLOW_DIM = Color3.fromRGB(74, 82, 100)

-- What each tagged object offers: prompt text, and what asking does.
type Offer = { action: string, object: string, distance: number }
local OFFERS: { [string]: Offer } = {
	LParkourStart = { action = "Start climb", object = "Spire Ascent", distance = 9 },
	LRuneStart = { action = "Start runes", object = "Rune courtyard", distance = 8 },
	LTossCairn = { action = "Throw a stone", object = "Aim higher to throw farther", distance = 10 },
	LMarkBell = { action = "Take the mark", object = "Death's mark", distance = 10 },
	LApple = { action = "Take", object = "A grey apple", distance = 7 },
	LDuelStone = { action = "Step up", object = "Name duel", distance = 8 },
}

local prompts: { [BasePart]: { prompt: ProximityPrompt, tag: string } } = {}
local glyphs: { [number]: { BasePart } } = {}

-- The card.
local card: CanvasGroup
local notice: any -- the card (Kit/Notice)
local statusLabel: TextLabel

-- What the player is doing now.
local current: string? = nil -- "parkour", "runes", "spirit", "mark"
-- Is this player in a name duel now (between its start and its end)?
local duelling = false
-- Death's mark, as the server last told it.
local mark = { tollAt = nil :: number?, line = "" }
local run = { startedAt = 0, reached = 0, total = Parkour.CHECKPOINTS }
local showToken = 0
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

-- The apples this player has found already are not there for them: unseen, and nothing to take.
local function hideFoundApples()
	local profile = ClientState.profile
	local games = if profile then profile.lobbyGames else nil
	local found = if type(games) == "table" then math.floor(tonumber(games.apples) or 0) else 0
	for object, entry in pairs(prompts) do
		if entry.tag == "LApple" then
			local index = object:GetAttribute("Index")
			local has = type(index) == "number" and bit32.band(found, bit32.lshift(1, index - 1)) ~= 0
			if has then
				entry.prompt.Enabled = false
			end
			object.LocalTransparencyModifier = if has then 1 else 0
			for _, item in ipairs(object:GetDescendants()) do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = if has then 1 else 0
				elseif item:IsA("Light") then
					item.Enabled = not has
				end
			end
		end
	end
end

local function refresh()
	local ok = usable()
	local me = Players.LocalPlayer.UserId
	for object, entry in pairs(prompts) do
		-- A Deathsinger waiting here (hidden) plays the solo games only, not the ones played with others.
		local stone = entry.tag == "LDuelStone"
		local shared = stone or entry.tag == "LMarkBell"
		local enabled = ok and not (shared and ClientState.isAway())
		if stone then
			-- A stone someone else stands at offers nothing; your own lets you step down, but not by a slip
			-- of the key in the middle of a duel (the card has a button for giving up).
			local holder = object:GetAttribute("Holder")
			enabled = enabled and (holder == nil or (holder == me and not duelling))
			entry.prompt.ActionText = if holder == me then "Step down" else OFFERS.LDuelStone.action
		end
		entry.prompt.Enabled = enabled
		if entry.tag == "LMarkBell" then
			entry.prompt.ActionText = if current == "mark" then "Leave the game" else OFFERS.LMarkBell.action
		end
	end
	hideFoundApples()
	if not ok and card.Visible then
		hideCard()
	end
end

-- Rune tiles --------------------------------------------------------------------------------------------

local function lightTile(tile: number, on: boolean)
	for _, glyph in ipairs(glyphs[tile] or {}) do
		glyph.Color = if on then GLOW_ON else GLOW_DIM
		glyph.Transparency = if on then 0 else 0.35
	end
end

local function dimAll()
	for tile = 1, 9 do
		lightTile(tile, false)
	end
end

local function flashTile(tile: number, hold: number)
	lightTile(tile, true)
	task.delay(hold, function()
		lightTile(tile, false)
	end)
end

local function showSequence(seq: { number }, step: number)
	showToken += 1
	local token = showToken
	task.spawn(function()
		task.wait(0.6)
		for _, tile in ipairs(seq) do
			if token ~= showToken then
				return
			end
			lightTile(tile, true)
			Sfx.play("gameRune", { pitch = 0.75 + tile * 0.07, volume = 0.8 })
			task.wait(step * 0.8)
			lightTile(tile, false)
			task.wait(step * 0.2)
		end
	end)
end

-- The stone-toss: the pebble's flight, then its fall into the rift ---------------------------------------------------

local function flyPebble(from: Vector3, land: Vector3, flight: number, hit: boolean, echo: number)
	local pebble = Create("Part", {
		Name = "Pebble",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.7, 0.7, 0.7),
		Color = Color3.fromRGB(120, 118, 116),
		Material = Enum.Material.Slate,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	}) :: BasePart
	Sfx.play("gameThrow", { volume = 0.7 })
	local start = from + Vector3.new(0, 1.8, 0)
	local ground = Vector3.new(land.X, 0.5, land.Z)
	local peak = 10 + (ground - start).Magnitude * 0.12
	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local u = math.clamp((os.clock() - began) / flight, 0, 1)
		pebble.Position = start:Lerp(ground, u) + Vector3.new(0, 4 * peak * u * (1 - u), 0)
		if u >= 1 then
			connection:Disconnect()
			if hit then
				Sfx.play("gameFall", { volume = 0.9 })
				TweenService:Create(
					pebble,
					TweenInfo.new(math.max(echo * 0.8, 0.5), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						Position = ground - Vector3.new(0, 260, 0),
						Transparency = 1,
					}
				):Play()
				task.delay(echo + 0.5, function()
					pebble:Destroy()
				end)
			else
				task.delay(1.2, function()
					pebble:Destroy()
				end)
			end
		end
	end)
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

-- The spirit trial (a Deathsinger waiting in the lobby): its rings exist on this screen only.
local spiritRings: { BasePart } = {}

local function clearSpirit()
	for _, ring in ipairs(spiritRings) do
		ring:Destroy()
	end
	table.clear(spiritRings)
end

local function lightRing(index: number)
	for i, ring in ipairs(spiritRings) do
		ring.Transparency = if i == index then 0.25 elseif i > index then 0.75 else 1
	end
end

local function onSpirit(p: any)
	local kind = p.kind
	if kind == "start" and type(p.rings) == "table" then
		current = "spirit"
		run.startedAt = tonumber(p.at) or workspace:GetServerTimeNow()
		run.reached = 0
		run.total = #p.rings
		clearSpirit()
		for index, position in ipairs(p.rings) do
			if typeof(position) == "Vector3" then
				local nextSpot = p.rings[index % #p.rings + 1]
				-- A thin glowing disc standing upright, its face turned along the loop.
				local facing = if typeof(nextSpot) == "Vector3" and (nextSpot - position).Magnitude > 0.1
					then CFrame.lookAt(position, Vector3.new(nextSpot.X, position.Y, nextSpot.Z))
					else CFrame.new(position)
				local ring = Create("Part", {
					Name = "SpiritRing",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.4, 9, 9),
					Material = Enum.Material.Neon,
					Color = GLOW_ON,
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					CastShadow = false,
					CFrame = facing * CFrame.Angles(0, math.rad(90), 0),
					Parent = workspace.CurrentCamera,
				})
				table.insert(spiritRings, ring)
			end
		end
		lightRing(1)
		setStatus("SPIRIT TRIAL", "Ring 0/" .. run.total .. "   0:00.0")
	elseif kind == "ring" then
		run.reached = tonumber(p.reached) or run.reached
		lightRing(run.reached + 1)
		Sfx.play("gameCheckpoint", { volume = 0.8 })
	elseif kind == "finish" then
		current = nil
		clearSpirit()
		Sfx.play("gameFinish")
		local text = "Spirit trial: " .. Parkour.format(tonumber(p.time) or 0)
		Toasts.show(text .. (if p.newBest then "  New best!" else ""), "good")
		setStatus("SPIRIT TRIAL", text .. "\nBest " .. Parkour.format(tonumber(p.best) or 0))
		hideAt = os.clock() + 7
	elseif kind == "end" then
		clearSpirit()
		if p.why == "wandered" then
			Toasts.show("Too far from the rings. Trial over.")
		end
		hideCard()
	end
end

-- Starts a lap of the spirit trial (the haunt bar's button).
function LobbyGamesController.startSpiritTrial()
	request:FireServer({ game = "spirit", action = "start" })
end

local function onRunes(p: any)
	local kind = p.kind
	if kind == "start" then
		current = "runes"
		dimAll()
	elseif kind == "show" then
		setStatus("RUNES", "Round " .. tostring(p.round) .. "   Watch the stones.")
		showSequence(p.seq or {}, tonumber(p.step) or 0.75)
	elseif kind == "input" then
		showToken += 1
		dimAll()
		statusLabel.Text = (string.gsub(statusLabel.Text, "Watch the stones%.", "Your turn."))
	elseif kind == "step" then
		if p.ok then
			Sfx.play("gameRune", { pitch = 0.75 + (tonumber(p.tile) or 1) * 0.07, volume = 0.6 })
			flashTile(tonumber(p.tile) or 1, 0.25)
		else
			Sfx.play("gameWrong")
			dimAll()
		end
	elseif kind == "over" then
		showToken += 1
		dimAll()
		current = nil
		local text = if p.why == "perfect" then "Perfect run." else "Run over."
		Toasts.show(
			string.format(
				"%s %d round%s cleared.%s",
				text,
				p.rounds,
				if p.rounds == 1 then "" else "s",
				if p.newBest then "  New best!" else ""
			),
			"good"
		)
		setStatus("RUNES", string.format("%d cleared   Best %d", p.rounds, p.best))
		hideAt = os.clock() + 6
	elseif kind == "end" then
		showToken += 1
		dimAll()
		hideCard()
	end
end

local function onToss(p: any)
	if p.kind ~= "result" then
		return
	end
	local from = Vector3.new(p.from.x, p.from.y, p.from.z)
	local land = Vector3.new(p.land.x, 0, p.land.z)
	flyPebble(from, land, tonumber(p.flight) or 1, p.hit == true, tonumber(p.echo) or 0)
	task.delay((tonumber(p.flight) or 1) + (if p.hit then (tonumber(p.echo) or 0) * 0.8 else 0.3), function()
		if p.hit then
			Toasts.show(
				string.format("%.1fs.%s  Best %.1fs.", p.echo, if p.newBest then "  New best!" else "", p.best),
				if p.newBest then "good" else nil
			)
		else
			Toasts.show("Aim higher to throw farther.")
		end
	end)
end

-- Death's mark: the card says who carries it and counts down to the bell.
local function onMark(p: any)
	local me = Players.LocalPlayer.UserId
	if p.kind == "joined" then
		current = "mark"
		mark.tollAt = nil
		mark.line = "Waiting for a second player."
		setStatus("DEATH'S MARK", mark.line)
		refresh()
	elseif p.kind == "state" then
		current = "mark"
		mark.tollAt = if type(p.tollAt) == "number" then p.tollAt else nil
		if p.carrier == nil then
			mark.line = "Waiting for a second player."
		elseif p.carrier == me then
			mark.line = "You have it. Tag someone before the bell."
		else
			mark.line = string.format("%s carries it.   Streak %d", tostring(p.carrierName), p.streak or 0)
		end
		setStatus("DEATH'S MARK", mark.line)
		refresh()
	elseif p.kind == "toll" then
		Sfx.play("gameBellToll")
		if p.down == me then
			Toasts.show("The bell tolls for you.", "bad")
		else
			Toasts.show(
				string.format("The bell tolls for %s. Survived: %d.", tostring(p.downName), p.streak or 0),
				if p.newBest then "good" else nil
			)
		end
	elseif p.kind == "pass" then
		Sfx.play("gameWrong", { volume = 0.7 })
		if p.to == me then
			Toasts.show("You have the mark.", "bad")
		end
	elseif p.kind == "left" then
		mark.tollAt = nil
		if current == "mark" then
			hideCard()
		end
		refresh()
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
	local diving = character:GetAttribute("Dive") ~= nil
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
	elseif payload.game == "spirit" then
		onSpirit(payload)
	elseif payload.game == "runes" then
		onRunes(payload)
	elseif payload.game == "toss" then
		onToss(payload)
	elseif payload.game == "mark" then
		onMark(payload)
	elseif payload.game == "duel" then
		if payload.kind == "start" then
			duelling = true
		elseif payload.kind == "over" or payload.kind == "left" then
			duelling = false
		end
		refresh()
	elseif payload.game == "apples" and payload.kind == "took" then
		Sfx.play("gameCheckpoint", { volume = 0.8 })
		Toasts.show(string.format("A grey apple.  %d of %d.", payload.count or 0, payload.total or 7), "good")
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
	elseif tag == "LRuneStart" then
		request:FireServer({ game = "runes", action = "start" })
	elseif tag == "LMarkBell" then
		request:FireServer({ game = "mark", action = if current == "mark" then "leave" else "join" })
	elseif tag == "LApple" then
		request:FireServer({ game = "apples", action = "take", index = object:GetAttribute("Index") })
	elseif tag == "LDuelStone" then
		local mine = object:GetAttribute("Holder") == Players.LocalPlayer.UserId
		request:FireServer({
			game = "duel",
			action = if mine then "leave" else "stand",
			stone = object:GetAttribute("Index"),
		})
	elseif tag == "LTossCairn" then
		local camera = workspace.CurrentCamera
		if camera then
			request:FireServer({ game = "toss", action = "throw", look = camera.CFrame.LookVector })
		end
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

local function collectGlyph(object: Instance)
	local tile = object:GetAttribute("Tile")
	if object:IsA("BasePart") and type(tile) == "number" then
		glyphs[tile] = glyphs[tile] or {}
		if not table.find(glyphs[tile], object) then
			table.insert(glyphs[tile], object)
		end
	end
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
	CollectionService:GetInstanceAddedSignal("LRuneGlyph"):Connect(collectGlyph)
	for _, object in ipairs(CollectionService:GetTagged("LRuneGlyph")) do
		collectGlyph(object)
	end
	Net.event("LobbyGameState").OnClientEvent:Connect(onState)
	RunService.Heartbeat:Connect(watchPit)
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(refresh)
	ClientState.WatchChanged:Connect(refresh)
	ClientState.ProfileChanged:Connect(hideFoundApples)
	-- The Spire Ascent's clock, and the card's goodbye a few seconds after a run ends.
	task.spawn(function()
		while true do
			task.wait(0.1)
			if current == "spirit" then
				statusLabel.Text = string.format(
					"Ring %d/%d   %s",
					run.reached,
					run.total,
					Parkour.format(workspace:GetServerTimeNow() - run.startedAt)
				)
			elseif current == "parkour" then
				statusLabel.Text = string.format(
					"Stone %d/%d   %s",
					run.reached,
					run.total,
					Parkour.format(workspace:GetServerTimeNow() - run.startedAt)
				)
			elseif current == "mark" then
				local tollAt = mark.tollAt
				local left = if tollAt then math.max(0, tollAt - workspace:GetServerTimeNow()) else nil
				statusLabel.Text = if left
					then string.format("%s   Bell in %d", mark.line, math.ceil(left))
					else mark.line
			elseif current == nil and card.Visible and hideAt > 0 and os.clock() > hideAt then
				hideAt = 0
				hideCard()
			end
		end
	end)
end

return LobbyGamesController
