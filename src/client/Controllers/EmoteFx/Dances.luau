-- The dances' accents (S10): small effects each timed to its clip's beats, every turn of the loop; Jackpot
-- Shuffle's luck and the group dances. Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)

local Common = require(script.Parent.Shared)
local EmoteFx = Common.EmoteFx
local nothing = Common.nothing
local floorUnder = Common.floorUnder
local onBeats = Common.onBeats
local burst = Common.burst
local lowerSole = Common.lowerSole
local stepDust = Common.stepDust
local accent = Common.accent
local chest = Common.chest
local GOLD = Common.GOLD
local PAPER = Common.PAPER

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

-- The dances' accents (S10): small, each timed to its clip's beats, every turn of the loop -------------------------

-- Two-Legged Bop: dust under each little step (a step every beat at 200 bpm).
FX.twoLeggedBop = accent(2.4, { 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4 - 0.001 }, function(character)
	stepDust(character, 0.9)
end)

-- The Rat Dance: dust under the cross-steps.
FX.ratDance = accent(2 * 60 / 106, { 0.0, 60 / 106 }, function(character)
	stepDust(character, 1.0)
end)

-- Bunny Ears: pastel sparkles flicked off the hands on the head, every other beat.
local PASTEL = ColorSequence.new(Color3.fromRGB(255, 182, 220), Color3.fromRGB(170, 215, 255))
FX.bunnyEars = accent(4 * 60 / 165, { 0.0, 2 * 60 / 165 }, function(character)
	for k, arm in ipairs({ "Right Arm", "Left Arm" }) do
		local part = character:FindFirstChild(arm)
		if part and part:IsA("BasePart") then
			local hand = (part.CFrame * CFrame.new(0, -1, 0)).Position
			burst(hand, {
				color = PASTEL,
				count = 5,
				size = 0.22,
				speed = NumberRange.new(2, 4),
				life = NumberRange.new(0.4, 0.7),
				gravity = 4,
			})
			-- (2026-11-15, "100x better": a twinkle at each fingertip, pink and blue)
			Vfx.Recipes.twinkle(hand + Vector3.new(0, 0.3, 0), {
				color = if k == 1 then Color3.fromRGB(255, 182, 220) else Color3.fromRGB(170, 215, 255),
				scale = 0.6,
			})
		end
	end
	-- and a soft pastel ring opening round the head
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		Vfx.Emit.burst(head.Position, {
			tex = "VfxRing",
			color = PASTEL,
			size = { { 0, 0.8 }, { 1, 4.5 } },
			alpha = { { 0, 0.3 }, { 0.6, 0.6 }, { 1, 1 } },
			life = 0.4,
			bright = 1.4,
			z = 1,
		}, 1)
	end
end)

-- Jackpot Shuffle: luck rising off the dancer (Hakari's jackpot; the user's call of 2026-10-27: a green aura, never
-- flames): a soft green haze round the body and its light, green sparks drifting up it, card suits floating off the
-- shoulders three times a turn, and a spray of gold coins up from the floor once a turn.

local LUCK = Color3.fromRGB(70, 230, 120)
local LUCK_LIGHT = Color3.fromRGB(196, 255, 210)
local JACKPOT_TURN = 7 * 60 / 150
-- (the four suits, DRAWN from plain shapes: typed, ♠ ♥ ♣ ♦ come out as coloured emoji, and the user's rule of
-- 2026-11-12 is no emojis anywhere)
local SUITS = { "spade", "heart", "club", "diamond" }
local jackpotCoins = accent(JACKPOT_TURN, { 0.0 }, function(character)
	local sole = lowerSole(character)
	if sole then
		burst(sole + Vector3.new(0, 0.2, 0), {
			color = GOLD,
			count = 18,
			size = 0.3,
			speed = NumberRange.new(9, 14),
			life = NumberRange.new(0.8, 1.2),
			spread = 35,
			gravity = 30,
			light = 0.7,
		})
		-- (2026-11-15, "100x better": the jackpot lands each turn: a green wave out over the floor, a gold glint in
		-- the spray, its light)
		Vfx.Beams.wave(CFrame.new(sole + Vector3.new(0, 0.08, 0)), 0.6, 7, 0.8, {
			tex = "VfxRingBand",
			color = LUCK,
			width = 0.8,
			bright = 2,
		})
		Vfx.Recipes.twinkle(sole + Vector3.new(0.4, 2.2, 0), { color = Color3.fromRGB(255, 226, 120), scale = 1.1 })
		Vfx.Light.flash(sole + Vector3.new(0, 1.5, 0), LUCK, 12, 2.5, 0.4)
	end
end)

-- One suit drawn into `holder` (a square frame) from circles and turned squares, in `colour`; returns its pieces.
local function drawSuit(holder: Frame, kind: string, colour: Color3): { Frame }
	local pieces = {}
	local function piece(x: number, y: number, w: number, h: number, round: boolean, turn: number?)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = colour
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = turn or 0
		if round then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = f
		end
		f.Parent = holder
		table.insert(pieces, f)
	end
	if kind == "diamond" then
		piece(0.5, 0.5, 0.5, 0.5, false, 45)
	elseif kind == "heart" then
		piece(0.34, 0.38, 0.4, 0.4, true)
		piece(0.66, 0.38, 0.4, 0.4, true)
		piece(0.5, 0.56, 0.46, 0.46, false, 45)
	elseif kind == "spade" then
		piece(0.34, 0.56, 0.4, 0.4, true)
		piece(0.66, 0.56, 0.4, 0.4, true)
		piece(0.5, 0.4, 0.46, 0.46, false, 45)
		piece(0.5, 0.82, 0.1, 0.3, false)
	else
		piece(0.5, 0.3, 0.36, 0.36, true)
		piece(0.3, 0.56, 0.36, 0.36, true)
		piece(0.7, 0.56, 0.36, 0.36, true)
		piece(0.5, 0.8, 0.1, 0.32, false)
	end
	return pieces
end

-- A card suit floating up off a shoulder and fading, green with a dark edge.
local function luckSign(root: BasePart, kind: string, side: number)
	local start = Vector3.new(1.3 * side, 1.4 + math.random() * 0.8, 0)
	local gui = Create("BillboardGui", {
		Name = "EmoteSign",
		Adornee = root,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 80,
		Size = UDim2.fromScale(0.8, 0.8),
		StudsOffset = start,
		Parent = root,
	}) :: BillboardGui
	gui:SetAttribute("DGEmote", true)
	local tilt = (6 + math.random() * 10) * side
	local pieces = {}
	-- (the dark edge: the same shape a little larger behind, then the suit itself)
	for _, layer in ipairs({ { 1.16, Color3.fromRGB(8, 40, 20) }, { 1.0, LUCK_LIGHT } }) do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(layer[1] * 0.8, layer[1] * 0.8)
		holder.Rotation = tilt
		holder.Parent = gui
		for _, f in ipairs(drawSuit(holder, kind, layer[2])) do
			f.BackgroundTransparency = 0.15
			table.insert(pieces, f)
		end
	end
	local info = TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = start + Vector3.new(0.3 * side, 1.4, 0) }):Play()
	for _, f in ipairs(pieces) do
		TweenService:Create(f, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
	end
	task.delay(1.4, function()
		gui:Destroy()
	end)
end

FX.jackpotShuffle = function(character, preview, phase)
	local stopCoins = jackpotCoins(character, preview, phase)
	local torso = character:FindFirstChild("Torso")
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not torso or not torso:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return stopCoins
	end
	local reduced = Motion.isReduced()
	local holder = Create("Attachment", { Name = "DGJackpot", Parent = torso }) :: Attachment
	holder:SetAttribute("DGEmote", true)
	local light = Create("PointLight", {
		Color = LUCK,
		Brightness = 0.9,
		Range = 9,
		Shadows = false,
		Parent = holder,
	})
	light:SetAttribute("DGEmote", true)
	-- the haze: big soft rounds of green that swell and fade where the body is, barely moving (no tongues of flame)
	local haze, stopHaze = Vfx.Emit.hold(holder, {
		tex = "VfxGlow",
		color = LUCK,
		size = { { 0, 3.4 }, { 0.5, 4.4 }, { 1, 3.8 } },
		alpha = { { 0, 1 }, { 0.35, 0.64 }, { 0.7, 0.72 }, { 1, 1 } },
		life = { 1.4, 2.0 },
		speed = { 0, 0.15 },
		spread = 180,
		light = 1,
		bright = 1.2,
		rate = 4,
		z = -1,
		locked = true,
	})
	haze:SetAttribute("DGEmote", true)
	-- (2026-11-15) a ring of green light on the floor round the dancer, breathing with the turn
	local floorAt = floorUnder(root.Position, character) + Vector3.new(0, 0.06, 0)
	local setRing, stopRing =
		Vfx.Beams.ring(CFrame.new(floorAt), 2.6, { tex = "VfxRingBand", color = LUCK, width = 0.45, bright = 1.6 })
	local ringClock = RunService.Heartbeat:Connect(function()
		local u = (os.clock() % JACKPOT_TURN) / JACKPOT_TURN
		setRing(2.6 + 0.35 * math.sin(u * math.pi * 2), 0.45 + 0.15 * math.cos(u * math.pi * 2))
	end)
	-- sparks drifting up through the body
	local sparks, stopSparks = Vfx.Emit.hold(torso, {
		tex = "VfxEmber",
		color = { { 0, LUCK_LIGHT }, { 1, LUCK } },
		size = { { 0, 0.16 }, { 0.6, 0.1 }, { 1, 0 } },
		alpha = { { 0, 0.15 }, { 1, 1 } },
		life = { 1.1, 1.8 },
		speed = { 0.5, 1.2 },
		spread = 25,
		accel = Vector3.new(0, 2.4, 0),
		light = 1,
		bright = 1.4,
		rate = if reduced then 6 else 16,
		shape = Enum.ParticleEmitterShape.Box,
	})
	sparks:SetAttribute("DGEmote", true)
	local gone = false
	local suit = 0
	if not reduced then
		onBeats(
			root,
			function()
				return gone
			end,
			JACKPOT_TURN,
			{ 0.7, 1.5, 2.3 },
			phase,
			function()
				suit = suit % #SUITS + 1
				luckSign(root, SUITS[suit], if suit % 2 == 0 then 1 else -1)
			end
		)
	end
	return function()
		gone = true
		stopCoins()
		stopHaze()
		stopSparks()
		ringClock:Disconnect()
		stopRing()
		light:Destroy()
		task.delay(2.2, function()
			holder:Destroy()
		end)
	end
end

-- Boat Aura: spray off the bow on every surge (each four beats).
local SPRAY = ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(150, 200, 235))
FX.boatAura = accent(6.4, { 0.0, 1.6, 3.2, 4.8 }, function(character)
	local sole = lowerSole(character)
	if sole then
		burst(sole + Vector3.new(0, 0.1, -1.2), {
			color = SPRAY,
			count = 16,
			size = 0.25,
			speed = NumberRange.new(5, 9),
			life = NumberRange.new(0.5, 0.9),
			spread = 70,
			gravity = 22,
			light = 0.3,
		})
	end
end)

-- Office Party: a flurry of loose paper as the turn comes round.

FX.officeParty = accent(6.4, { 3.9 }, function(character)
	local at = chest(character)
	if at then
		burst(at + Vector3.new(0, 1.5, 0), {
			color = PAPER,
			count = 14,
			size = 0.35,
			speed = NumberRange.new(4, 7),
			life = NumberRange.new(1.2, 1.8),
			spread = 80,
			gravity = 3,
			light = 0,
		})
	end
end)

-- Glitch Step: the tape's stutters throw off cyan and magenta squares.
local GLITCH = ColorSequence.new(Color3.fromRGB(0, 255, 240), Color3.fromRGB(255, 0, 200))
FX.glitchStep = accent(2.4, { 0.6, 1.6 }, function(character)
	local at = chest(character)
	if at then
		burst(at, {
			color = GLITCH,
			count = 12,
			size = 0.3,
			speed = NumberRange.new(2, 5),
			life = NumberRange.new(0.12, 0.3),
			spread = 180,
			light = 1,
		})
	end
end)

-- Goal Celebration: the landing kicks up a ring of dust, and a spray of gold off the chest with the shout.
FX.goalCelebration = accent(3.0, { 1.26 }, function(character)
	local sole = lowerSole(character)
	if sole then
		EmoteFx.thud(CFrame.new(sole), 4)
	end
	local at = chest(character)
	if at then
		burst(at, {
			color = GOLD,
			count = 16,
			size = 0.28,
			speed = NumberRange.new(5, 9),
			life = NumberRange.new(0.5, 0.9),
			spread = 70,
			gravity = 10,
			light = 0.8,
		})
	end
end)

-- The Smiling Lord: a glint off the brim as the hat is touched.
FX.smilingLord = accent(4.8, { 0.3 }, function(character)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		burst((head.CFrame * CFrame.new(0.4, 0.7, -0.3)).Position, {
			color = GOLD,
			count = 4,
			size = 0.5,
			speed = NumberRange.new(0.5, 1),
			life = NumberRange.new(0.3, 0.5),
			spread = 180,
			light = 1,
		})
	end
end)

-- Excuse Me, Sir, LOOK UP: a glint of sky on the upturned face.
FX.excuseMeSirUp = accent(2.8, { 0.75 }, function(character)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		burst((head.CFrame * CFrame.new(0, 0.9, -0.4)).Position, {
			color = ColorSequence.new(Color3.fromRGB(255, 250, 235)),
			count = 3,
			size = 0.9,
			speed = NumberRange.new(0.2, 0.5),
			life = NumberRange.new(0.5, 0.8),
			spread = 180,
			light = 1,
		})
	end
end)

-- Animatronic Welcome: the stage robot's eyes lit, a pale gold shine.
FX.animatronicWelcome = function(character, preview)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nothing
	end
	local parts: { BasePart } = {}
	for _, side in ipairs({ -0.2, 0.2 }) do
		local part = Create("Part", {
			Name = "EmoteEyes",
			Size = Vector3.new(0.14, 0.14, 0.05),
			Shape = Enum.PartType.Block,
			Color = Color3.fromRGB(255, 236, 170),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			CastShadow = false,
			CFrame = head.CFrame * CFrame.new(side, 0.12, -head.Size.Z / 2 - 0.03),
			Parent = character,
		}) :: BasePart
		part:SetAttribute("DGEmote", true)
		Create("WeldConstraint", { Part0 = head, Part1 = part, Parent = part })
		table.insert(parts, part)
	end
	if not preview then
		Create("PointLight", { Color = Color3.fromRGB(255, 230, 160), Range = 5, Brightness = 1.5, Parent = parts[1] })
		-- (each eye a lamp: a glow round it and a hard star that flickers like an old bulb)
		for _, eye in ipairs(parts) do
			Vfx.Emit.make(eye, {
				tex = "VfxGlow",
				color = Color3.fromRGB(255, 226, 150),
				size = { { 0, 0.9 }, { 0.5, 1.1 }, { 1, 0.9 } },
				alpha = { { 0, 1 }, { 0.1, 0.35 }, { 0.9, 0.35 }, { 1, 1 } },
				life = 0.9,
				rate = 2.4,
				locked = true,
				light = 1,
				bright = 1.1,
				z = 0.5,
			})
			Vfx.Emit.make(eye, {
				tex = "VfxFlare",
				color = Color3.fromRGB(255, 240, 200),
				size = { { 0, 0.5 }, { 0.5, 0.65 }, { 1, 0.5 } },
				alpha = { { 0, 1 }, { 0.1, 0.2 }, { 0.5, 0.45 }, { 0.6, 0.15 }, { 0.9, 0.3 }, { 1, 1 } },
				life = 0.5,
				rate = 4,
				locked = true,
				light = 1,
				bright = 1.2,
				z = 0.6,
			})
		end
	end
	return function()
		for _, part in ipairs(parts) do
			part:Destroy()
		end
	end
end

return FX
