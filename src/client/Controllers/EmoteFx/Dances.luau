-- The dances' accents (S10): small effects each timed to its clip's beats, every turn of the loop; Jackpot
-- Shuffle's luck and the group dances. Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Fresh = require(script.Parent.Parent.Parent.Presentation.Vfx.Fresh)
local Palette = require(script.Parent.Parent.Parent.Presentation.Vfx.Palette)
local Pilot = require(script.Parent.Parent.Parent.Presentation.Vfx.Pilot)
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
-- On the new kit (stage 4b third batch, Pilot.on.bunnyEars; false = the old build below). One sentence: two hands up like ears flicking
-- a pink spark and a blue one on the beat, and a pastel ring opening round the head (motif: sugar-bright light; Penned = one accent).
-- The five moments, every other beat (165 bpm):
--   gather    none (an accent that comes twice a turn)
--   hit       the beat: a white-hot pink star at the right hand with its ring and a dark halo behind, a blue one at the left, sparks thrown (Fresh.tap, small)
--   body      the stars close and the sparks fall
--   break-up  the ring fades out
--   residue   the last pastel sparks falling for 0.5 s
local PINK_EAR = Palette.pair(Color3.fromRGB(255, 182, 220), Color3.fromRGB(255, 236, 246))
local BLUE_EAR = Palette.pair(Color3.fromRGB(170, 215, 255), Color3.fromRGB(236, 246, 255))
local bunnyFresh = accent(4 * 60 / 165, { 0.0, 2 * 60 / 165 }, function(character)
	for k, arm in ipairs({ "Right Arm", "Left Arm" }) do
		local part = character:FindFirstChild(arm)
		if part and part:IsA("BasePart") then
			local hand = (part.CFrame * CFrame.new(0, -1, 0)).Position + Vector3.new(0, 0.3, 0)
			Fresh.tap(hand, {
				ramp = if k == 1 then PINK_EAR else BLUE_EAR,
				scale = 0.5,
				lite = true,
				sparks = 3,
				light = false,
				lead = 0.02,
			})
		end
	end
	-- (fourth batch: the head's own moment. Two soft pastel ears, a pink one and a blue one, flick up off the crown on the beat, so
	-- the hands' stars have ears to be the tips of; the old ring is gone and so is the first build's ring of the hands' stars (a
	-- star and its sparks only now): the budget is six emitters)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") and not Motion.isReduced() then
		local crown = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.1, 0)
		local list: { any } = {}
		for side = 1, 2 do
			local lean = if side == 1 then 0.4 else -0.4
			local base = crown + head.CFrame.RightVector * lean * 1.5
			local way = head.CFrame:VectorToWorldSpace(Vector3.new(lean, 1, 0)).Unit
			table.insert(list, {
				{
					-- (an ear: a soft pastel leaf standing up off the head, flicked up and slowing, like an ear twitching; seen in the
					-- booth: the feather sheet reads as a long ear, a streak did not read at all)
					tex = "VfxFeather",
					color = if side == 1 then Color3.fromRGB(255, 120, 190) else Color3.fromRGB(110, 180, 255),
					size = { { 0, 0.8 }, { 0.3, 2.1 }, { 1, 1.6 } },
					alpha = { { 0, 0.5 }, { 0.5, 0.3 }, { 1, 1 } },
					life = 0.6,
					speed = { 3, 4 },
					drag = 4,
					spread = 4,
					rot = { -14, 14 },
					face = "up",
					light = 0.3,
					bright = 1,
					z = 1,
				},
				1,
				CFrame.lookAt(base, base + way) * CFrame.Angles(math.rad(-90), 0, 0),
			})
		end
		for _, one in ipairs(list) do
			Vfx.Emit.burst(one[3], { { one[1], one[2] } })
		end
	end
end)
local bunnyOld: Common.Fx
FX.bunnyEars = function(character, preview, phase)
	return (if Pilot.on.bunnyEars then bunnyFresh else bunnyOld)(character, preview, phase)
end
bunnyOld = accent(4 * 60 / 165, { 0.0, 2 * 60 / 165 }, function(character)
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

-- The fourth batch, on the new kit (stage 4b): every Penned dance below keeps its idea, colour and beat, each behind its own flag
-- in Vfx/Pilot (false = the old build above, which stays as it was). Penned is an accent: 60 particles, 2 big sprites, 6 emitters,
-- 1 light. The five moments of each are the recipe's own (gather, hit, body, break-up, residue); what differs is named here.
local flag = Common.flag
local beats = Common.beats
local soleFrame = Common.soleFrame
local throwing = Common.throwing

-- Two-Legged Bop and The Rat Dance: a little puff of dust off each landing foot (a step every beat at 200 bpm; the rat's two
-- cross-steps), a quick puff of dust and a few sparks, both gone inside 0.6 s (Fresh.scuff).
FX.twoLeggedBop = flag(
	"twoLeggedBop",
	beats(2.4, { 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4 - 0.001 }, 0.04, function(character, lead)
		local at = soleFrame(character)
		if at then
			Fresh.scuff(at, { scale = 0.8, lead = lead })
		end
	end),
	FX.twoLeggedBop
)
FX.ratDance = flag(
	"ratDance",
	beats(2 * 60 / 106, { 0.0, 60 / 106 }, 0.04, function(character, lead)
		local at = soleFrame(character)
		if at then
			Fresh.scuff(at, { scale = 1, lead = lead })
		end
	end),
	FX.ratDance
)

-- Boat Aura: spray flung up off the bow on every surge. The surge is a flat ring of spray on the floor, pale blue-white, spray
-- thrown up and falling, and a thin mist of it (motif: cold water, white spray).
local SPRAY_RAMP = Palette.pair(Color3.fromRGB(150, 200, 235), Color3.fromRGB(230, 244, 255))
FX.boatAura = flag(
	"boatAura",
	beats(6.4, { 0.0, 1.6, 3.2, 4.8 }, 0.05, function(character, lead)
		local sole = lowerSole(character)
		if sole then
			local bow = sole + Vector3.new(0, 0.1, -1.2)
			Fresh.tap(
				CFrame.new(bow),
				{ ramp = SPRAY_RAMP, scale = 0.9, flat = true, sparks = 9, lite = false, lead = lead }
			)
		end
	end),
	FX.boatAura
)

-- Office Party: a flurry of loose paper thrown up off the chest as the turn comes round (Fresh.scatter, paper, small).
FX.officeParty = flag(
	"officeParty",
	beats(6.4, { 3.9 }, 0.2, function(character, lead)
		local at = chest(character)
		if at then
			Fresh.scatter(throwing(at + Vector3.new(0, 1.5, 0), Vector3.yAxis), {
				kind = "paper",
				scale = 0.7,
				count = 9,
				flash = true,
				lead = lead,
			})
		end
	end),
	FX.officeParty
)

-- Glitch Step: the tape stutters and throws off a cyan spark and a magenta one, the magenta a hair late (a stutter).
local CYAN_RAMP = Palette.pair(Color3.fromRGB(0, 255, 240), Color3.fromRGB(214, 255, 252))
local MAGENTA_RAMP = Palette.pair(Color3.fromRGB(255, 0, 200), Color3.fromRGB(255, 214, 244))
FX.glitchStep = flag(
	"glitchStep",
	beats(2.4, { 0.6, 1.6 }, 0.04, function(character, lead)
		local at = chest(character)
		local root = character:FindFirstChild("HumanoidRootPart")
		if at and root and root:IsA("BasePart") then
			local right = root.CFrame.RightVector * 0.5
			Fresh.tap(
				at - right,
				{ ramp = CYAN_RAMP, scale = 0.8, lite = false, sparks = 6, light = false, lead = lead }
			)
			Fresh.tap(
				at + right,
				{ ramp = MAGENTA_RAMP, scale = 0.8, lite = true, sparks = 6, light = true, lead = lead + 0.07 }
			)
		end
	end),
	FX.glitchStep
)

-- Goal Celebration: the landing kicks a ring of dust out along the floor and a spray of gold goes up off the chest with the shout.
local GOLD_RAMP = Palette.pair(Color3.fromRGB(255, 214, 90), Color3.fromRGB(255, 244, 200))
FX.goalCelebration = flag(
	"goalCelebration",
	beats(3.0, { 1.26 }, 0.08, function(character, lead)
		local at = soleFrame(character)
		if at then
			Fresh.stepDust(at, { scale = 2.2, lead = lead })
		end
		local top = chest(character)
		if top then
			Fresh.tap(top, { ramp = GOLD_RAMP, scale = 0.8, lite = true, sparks = 10, light = false, lead = lead })
		end
	end),
	FX.goalCelebration
)

-- The Smiling Lord: a gold glint off the brim as the hat is touched.
FX.smilingLord = flag(
	"smilingLord",
	beats(4.8, { 0.3 }, 0.1, function(character, lead)
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			Fresh.glint(
				(head.CFrame * CFrame.new(0.4, 0.7, -0.3)).Position,
				{ ramp = GOLD_RAMP, scale = 0.6, lead = lead }
			)
		end
	end),
	FX.smilingLord
)

-- Excuse Me, Sir, LOOK UP: a glint of sky on the upturned face.
local SKY_RAMP = Palette.pair(Color3.fromRGB(255, 244, 214), Color3.fromRGB(255, 252, 240))
FX.excuseMeSirUp = flag(
	"excuseMeSirUp",
	beats(2.8, { 0.75 }, 0.1, function(character, lead)
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			Fresh.glint(
				(head.CFrame * CFrame.new(0, 0.9, -0.4)).Position,
				{ ramp = SKY_RAMP, scale = 0.7, lead = lead }
			)
		end
	end),
	FX.excuseMeSirUp
)

-- Animatronic Welcome: the stage robot's eyes lit, a pale gold shine. The eye parts and the lamp are the old build's; the shine
-- is a slow pulsing star on each eye (a bulb on a dimmer) and pale gold dust turning in the light in front of the face.
local EYE_RAMP = Palette.pair(Color3.fromRGB(255, 226, 150), Color3.fromRGB(255, 244, 214))
local animatronicOld: Common.Fx = FX.animatronicWelcome
FX.animatronicWelcome = function(character, preview, phase)
	if not Pilot.on.animatronicWelcome then
		return animatronicOld(character, preview, phase)
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nothing
	end
	-- (the eyes themselves: the old build's two lit parts, its lamp and none of its emitters)
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
	local loops: { { stop: () -> (), destroy: () -> () } } = {}
	if not preview then
		Create("PointLight", { Color = Color3.fromRGB(255, 230, 160), Range = 5, Brightness = 1.5, Parent = parts[1] })
		for _, eye in ipairs(parts) do
			table.insert(
				loops,
				Fresh.Small.loop(eye, {
					{
						-- (the bulb: a hard star that dims and swells, the white-hot core of the eye)
						tex = "VfxGlint",
						ramp = { Color3.new(1, 1, 1), EYE_RAMP[2], EYE_RAMP[3] },
						size = { { 0, 0.3 }, { 0.5, 0.9 }, { 1, 0.3 } },
						alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.3 }, { 1, 1 } },
						life = 1.1,
						rate = 1.1,
						locked = true,
						bright = 2.2,
						z = 1,
					},
				})
			)
		end
		table.insert(
			loops,
			Fresh.Small.loop(parts[1], {
				{
					-- (the glow of the eyes in the air in front of the face, laid soft)
					tex = "VfxMist",
					ramp = EYE_RAMP,
					size = { { 0, 1.2 }, { 1, 2 } },
					alpha = { { 0, 1 }, { 0.3, 0.55 }, { 0.7, 0.65 }, { 1, 1 } },
					life = { 1.4, 1.8 },
					speed = 0.05,
					rate = 0.8,
					light = 0.8,
					lit = 0.1,
					locked = true,
					z = -1,
				},
				{
					-- (gold dust turning in the light of the eyes)
					tex = "VfxSparks",
					ramp = EYE_RAMP,
					size = { { 0, 0.18 }, { 1, 0.06 } },
					alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.4 }, { 1, 1 } },
					life = { 1.4, 2 },
					speed = { 0.2, 0.7 },
					spread = 60,
					rot = { 0, 360 },
					rate = 3,
					bright = 1.2,
				},
			})
		)
	end
	return function()
		for _, loop in ipairs(loops) do
			loop.destroy()
		end
		for _, part in ipairs(parts) do
			part:Destroy()
		end
	end
end

-- Jackpot Shuffle: luck rising off the dancer, green, never flames. A soft green bank of mist and green sparks drift up the body
-- (two loop emitters, one light); each turn the jackpot lands: a flat green ring and sparks on the floor and a few gold coins
-- thrown up; the card suits float off the shoulders as before.
local LUCK_RAMP = Palette.pair(LUCK, LUCK_LIGHT)
local jackpotCoinsFresh = beats(JACKPOT_TURN, { 0.0 }, 0.06, function(character, lead)
	local at = soleFrame(character)
	if not at then
		return
	end
	local pos = at.Position + Vector3.new(0, 0.2, 0)
	-- (the jackpot's wave: a green ring out over the floor, white-hot at its core)
	Vfx.Clock.after(lead, function()
		Vfx.Emit.burst(CFrame.new(pos), {
			{
				{
					tex = "VfxShock",
					ramp = LUCK_RAMP,
					size = { { 0, 0.6 }, { 0.5, 6 }, { 1, 7 } },
					alpha = { { 0, 0.5 }, { 0.5, 0.65 }, { 1, 1 } },
					life = 0.7,
					face = "flat",
					speed = 0.001,
					bright = 2.2,
					z = 1,
				},
				1,
			},
		})
	end)
	Fresh.flecks(
		CFrame.new(pos),
		{ tex = "VfxShards", ramp = GOLD_RAMP, scale = 0.8, count = 7, fall = 30, lead = lead }
	)
end)
local jackpotOld: Common.Fx = FX.jackpotShuffle
local function jackpotFresh(character: Model, preview: boolean, phase: number?): () -> ()
	local stopCoins = jackpotCoinsFresh(character, preview, phase)
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
	local loop = Fresh.Small.loop(holder, {
		{
			-- (the bank: soft green mist swelling round the body)
			tex = "VfxMist",
			ramp = LUCK_RAMP,
			size = { { 0, 3 }, { 1, 4.6 } },
			alpha = { { 0, 1 }, { 0.3, 0.45 }, { 0.7, 0.55 }, { 1, 1 } },
			life = { 1.6, 2.2 },
			speed = { 0, 0.2 },
			spread = 180,
			rate = 2.5,
			light = 0.8,
			lit = 0.1,
			z = -1,
			locked = true,
		},
		{
			-- (sparks of luck rising through the body)
			tex = "VfxSparks",
			ramp = LUCK_RAMP,
			size = { { 0, 0.3 }, { 1, 0.08 } },
			alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.3 }, { 1, 1 } },
			life = { 1.1, 1.8 },
			speed = { 0.5, 1.2 },
			spread = 25,
			accel = Vector3.new(0, 2.4, 0),
			rate = if reduced then 4 else 10,
			bright = 1.6,
			shape = Enum.ParticleEmitterShape.Box,
		},
	})
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
		loop.stop()
		light:Destroy()
		task.delay(2.2, function()
			loop.destroy()
			holder:Destroy()
		end)
	end
end
FX.jackpotShuffle = flag("jackpotShuffle", jackpotFresh, jackpotOld)

return FX
