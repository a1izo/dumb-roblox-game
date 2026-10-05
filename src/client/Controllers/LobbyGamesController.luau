--!strict
-- The lobby mini-games on this client: prompts on the tagged objects the server built (Maps/LobbyGames),
-- a small card at the top of the screen while you are playing, the rune tiles lit for you alone, and the
-- thrown pebble's flight. Every rule and score is the server's (Services/LobbyGameService); this only
-- asks (start, sit, roll, throw, leave) and shows what the server says. Nothing here runs for a player
-- who is in a case or watching one.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Parkour = require(Shared:WaitForChild("LobbyGames"):WaitForChild("Parkour"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.UI.Kit)
local Screens = require(script.Parent.Parent.UI.Screens)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local LobbyGamesController = {}

local T = Kit.Tokens

local request = Net.event("LobbyGame")

local GLOW_ON = Color3.fromRGB(206, 224, 255)
local GLOW_DIM = Color3.fromRGB(74, 82, 100)

-- What each tagged object offers: prompt text, and what asking does.
type Offer = { action: string, object: string, distance: number }
local OFFERS: { [string]: Offer } = {
	LParkourStart = { action = "Begin the climb", object = "Spire Ascent", distance = 9 },
	LRuneStart = { action = "Begin the runes", object = "Rune courtyard", distance = 8 },
	LDiceSeat = { action = "Sit", object = "Bone dice", distance = 6 },
	LTossCairn = { action = "Throw a stone", object = "Look at the rift; aim higher to throw farther", distance = 10 },
}

local prompts: { [BasePart]: { prompt: ProximityPrompt, tag: string } } = {}
local glyphs: { [number]: { BasePart } } = {}

-- The card.
local card: Frame
local titleLabel: TextLabel
local statusLabel: TextLabel
local rollButton: TextButton

-- What the player is doing now.
local current: string? = nil -- "parkour", "runes", "dice"
local run = { startedAt = 0, reached = 0, total = Parkour.CHECKPOINTS }
local showToken = 0
local hideAt = 0

local function usable(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching()
end

local function setStatus(title: string, status: string)
	titleLabel.Text = title
	statusLabel.Text = status
	card.Visible = true
end

local function hideCard()
	current = nil
	card.Visible = false
	rollButton.Visible = false
end

local function refresh()
	local ok = usable()
	for _, entry in pairs(prompts) do
		entry.prompt.Enabled = ok and not (entry.tag == "LDiceSeat" and current == "dice")
	end
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
		rollButton.Visible = false
		setStatus("SPIRE ASCENT", "Stone 0/" .. run.total .. "   0:00.0")
	elseif kind == "checkpoint" then
		run.reached = tonumber(p.index) or run.reached
		Sfx.play("gameCheckpoint", { volume = 0.8 })
		Toasts.show(string.format("Stone %d of %d", run.reached, run.total))
	elseif kind == "fall" then
		Toasts.show(
			if (tonumber(p.index) or 0) > 0
				then "You fell. Back to stone " .. p.index .. "."
				else "You fell. Back to the pad."
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

local function onRunes(p: any)
	local kind = p.kind
	if kind == "start" then
		current = "runes"
		rollButton.Visible = false
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
		local text = if p.why == "perfect" then "A perfect run." else "Run over."
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

local function onDice(p: any)
	local kind = p.kind
	if kind == "seated" then
		current = "dice"
		rollButton.Visible = true
		setStatus("BONE DICE", "Seated. Roll the bones.   Streak " .. tostring(p.streak or 0))
		refresh()
	elseif kind == "rolled" then
		Sfx.play("gameDice")
		statusLabel.Text = string.format("You rolled %d + %d = %d.", p.d1, p.d2, p.d1 + p.d2)
	elseif kind == "result" then
		local line = if p.house
			then string.format("You %d  ·  the realm %d", p.total, p.house)
			else string.format("You %d", p.total)
		local result = if p.result == "win" then "You win." elseif p.result == "lose" then "You lose." else "A tie."
		setStatus(
			"BONE DICE",
			string.format(
				"%s\n%s  Streak %d  Best %d%s",
				line,
				result,
				p.streak,
				p.best,
				if p.newBest then "  New best!" else ""
			)
		)
	elseif kind == "left" then
		hideCard()
		refresh()
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
				string.format(
					"The stone falls for %.1f s.%s  Best %.1f s.",
					p.echo,
					if p.newBest then "  New best!" else "",
					p.best
				),
				if p.newBest then "good" else nil
			)
		else
			Toasts.show("It skips across the ash. Look at the rift, and aim higher to throw farther.")
		end
	end)
end

local function onState(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.game == "parkour" then
		onParkour(payload)
	elseif payload.game == "runes" then
		onRunes(payload)
	elseif payload.game == "dice" then
		onDice(payload)
	elseif payload.game == "toss" then
		onToss(payload)
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
	elseif tag == "LDiceSeat" then
		request:FireServer({ game = "dice", action = "sit", seat = object:GetAttribute("Seat") })
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
	prompt.Triggered:Connect(function()
		trigger(tag, object)
	end)
	prompts[object] = { prompt = prompt, tag = tag }
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
	card = Kit.card({
		Name = "LobbyGameCard",
		tone = "raised",
		padding = T.space.s,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false,
		Parent = Screens.hud,
	})
	card.BackgroundTransparency = T.alpha.glass
	Kit.Layout.place(card, "topCenter", Vector2.new(0, 96))
	Kit.list(card, T.space.xs)
	titleLabel = Kit.label({
		font = "label",
		size = "small",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = 1,
		Parent = card,
	})
	statusLabel = Kit.label({
		font = "bodyBold",
		size = "small",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = 2,
		Parent = card,
	})
	local row = Kit.frame({
		Name = "Row",
		Size = UDim2.fromOffset(0, T.touch),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Parent = card,
	})
	Kit.list(row, T.space.s, true)
	rollButton = Kit.button(
		{ text = "Roll", variant = "primary", size = "s", Visible = false, LayoutOrder = 1, Parent = row },
		function()
			request:FireServer({ game = "dice", action = "roll" })
		end
	)
	Kit.button({ text = "Leave", variant = "ghost", size = "s", LayoutOrder = 2, Parent = row }, function()
		if current then
			request:FireServer({ game = current, action = "leave" })
			if current ~= "dice" then
				hideCard()
			end
		else
			hideCard()
		end
	end)
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
	ClientState.PublicChanged:Connect(refresh)
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
