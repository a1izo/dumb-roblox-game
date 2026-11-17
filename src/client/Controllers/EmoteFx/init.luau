-- The emote pack's effects round a character while its emote plays (EmoteController starts them and clears
-- them when the emote ends; each returns a function that clears it away): a beam of light from above for
-- New World, signs rising round Menacing Pose, a battery running down over Low Battery's head, red eyes
-- for Reaper's Eyes. Everything is made on this client only, and what is put on the body is marked "DGEmote"
-- (a copy of the body leaves it out). A preview (the shop's copy in its 3D view)
-- gets only what a 3D view can show: no lights, no billboards.
--
-- Split by family (ticket V2.1, 2026-11-17): this file keeps the public API (play, rung, has, clips, thud, pock,
-- wisp) and merges the clip id -> effect tables of Godhood, Poses, Dances, Props, Older, Strolls, Duos and
-- Everyone; the helpers they share are in Shared. Code moved, not changed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))
local Aura = require(script.Parent.Parent.Presentation.Aura)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)
local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Governor = require(script.Parent.Parent.World.Governor)

local Common = require(script.Shared)
local EmoteFx = Common.EmoteFx
local nothing = Common.nothing
local floorUnder = Common.floorUnder
local mine = Common.mine
local burst = Common.burst
local GLINT = Common.GLINT
local hand = Common.hand

type Fx = Common.Fx

-- The clip id -> effect function tables, one module per family (a clip id is in exactly one of them).
local FX: { [string]: Fx } = {}
for _, family in ipairs({
	script.Godhood,
	script.Poses,
	script.Dances,
	script.Props,
	script.Older,
	script.Strolls,
	script.Duos,
	script.Everyone,
}) do
	for clip, fx in pairs(require(family)) do
		FX[clip] = fx
	end
end

-- Match Point: the ball pocks off the racket with a puff of white each time it is hit (DuoController's strokes
-- call this; the ready loop itself is still).
function EmoteFx.pock(character: Model)
	if Governor.low("emoteFx") then
		return
	end
	local at = hand(character, "Right")
	if at then
		burst(at + (character:GetPivot().LookVector * 1.4), {
			color = GLINT,
			count = 8,
			size = 0.3,
			speed = NumberRange.new(5, 9),
			life = NumberRange.new(0.12, 0.25),
			spread = 140,
			light = 1,
		})
	end
end

-- The rung each effect needs on the ladder (Shared/EmoteInfo `fx`): 1 one small accent, 2 a tailored effect with
-- light, 3 layered, 4 the cutscene emotes'. The four above keep their own looks; the rest come with each emote.
local RUNG: { [string]: number } = {
	menacingPose = 1,
	lowBattery = 1,
	reapersEyes = 1,
	newWorld = 2,
	justAsPlanned = 3,
	chipAndPen = 2,
	appleBite = 1,
	puppetDance = 1,
	writeAir = 2,
	aceCrouch = 2,
	twoLeggedBop = 1,
	ratDance = 1,
	bunnyEars = 1,
	jackpotShuffle = 1,
	boatAura = 1,
	officeParty = 1,
	glitchStep = 1,
	goalCelebration = 1,
	smilingLord = 1,
	excuseMeSirUp = 1,
	animatronicWelcome = 1,
	puppetPop = 1,
	menacingPose2 = 1,
	menacingPose3 = 1,
	menacingPose4 = 1,
	menacingPose5 = 1,
	menacingPose6 = 1,
	lowBatteryCharge = 1,
	preDawnBonk = 2,
	blindfoldLift = 2,
	blindfoldLiftUp = 2,
	chairPerch = 2,
	sugarTower = 2,
	sugarTowerAdd = 2,
	sugarTowerTopple = 2,
	diceTower = 2,
	diceTowerAdd = 2,
	diceTowerTopple = 2,
	strawberryOnTop = 2,
	twoFingerGrip = 1,
	furiousScribbling = 1,
	furiousScribblingSlash = 1,
	appleTossThrow = 1,
	chocolateSnap = 1,
	fortySeconds = 1,
	impossibleLean = 1,
	itsYou = 1,
	deducing = 1,
	reapersCackle = 1,
	finalBreakdown = 3,
	theLongClimb = 1,
	nahIdWin = 1,
}

-- How strong an emote's effects may be here, now: its own rung (Shared/EmoteInfo; in a case too, Shared/
-- EmotePolicy), at most one small accent on low graphics (World/Governor).
function EmoteFx.rung(clip: string): number
	local info = EmoteInfo.of(clip)
	local rung = EmotePolicy.fxRung(info, {
		inCase = ClientState.isParticipant(),
		phase = ClientState.phase(),
		deathsinger = ClientState.isSpecter(),
		cutscene = false,
	})
	if Governor.low("emoteFx") then
		rung = math.min(rung, 1)
	end
	return rung
end

-- The aura (Presentation/Aura, the owner's three tutorials of 2026-10-24) burns round a body, so only the emotes
-- about power wear it, under their own effect (2026-10-26: on nearly every emote, a Griddy or a sugar tower on fire
-- made no sense): Menacing Pose and its poses, Gojo's blindfold, Write in the Air and the four Godhood emotes, each
-- in its own colours (colour, accent). Its level follows the emote's rung (glow, flames, specks and flares; the
-- ground, wisps and smoke too; the spiral beams, a halo and lightning too); LEVEL lifts a showpiece a rung.
local AURAS: { [string]: { Color3 } } = {
	writeAir = { Color3.fromRGB(240, 226, 190), Color3.fromRGB(255, 250, 236) },
	menacingPose = { Color3.fromRGB(150, 92, 205), Color3.fromRGB(232, 206, 255) },
	menacingPose2 = { Color3.fromRGB(214, 190, 120), Color3.fromRGB(255, 244, 210) },
	menacingPose3 = { Color3.fromRGB(110, 120, 220), Color3.fromRGB(210, 216, 255) },
	menacingPose4 = { Color3.fromRGB(196, 24, 44), Color3.fromRGB(255, 170, 170) },
	menacingPose5 = { Color3.fromRGB(120, 170, 232), Color3.fromRGB(220, 236, 255) },
	menacingPose6 = { Color3.fromRGB(214, 180, 96), Color3.fromRGB(255, 236, 190) },
	blindfoldLift = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(220, 240, 255) },
	blindfoldLiftUp = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(220, 240, 255) },
	justAsPlanned = { Color3.fromRGB(210, 30, 40), Color3.fromRGB(255, 200, 200) },
	finalBreakdown = { Color3.fromRGB(230, 60, 40), Color3.fromRGB(255, 210, 170) },
	newWorld = { Color3.fromRGB(255, 236, 180), Color3.fromRGB(255, 255, 255) },
	reapersEyes = { Color3.fromRGB(255, 30, 50), Color3.fromRGB(255, 160, 160) },
}
local LEVEL: { [string]: number } = {
	menacingPose = 2,
	menacingPose2 = 2,
	menacingPose3 = 2,
	menacingPose4 = 2,
	menacingPose5 = 2,
	menacingPose6 = 2,
	blindfoldLift = 2,
	blindfoldLiftUp = 2,
	writeAir = 2,
}

local function auraFor(clip: string, rung: number): Aura.Spec?
	local tint = AURAS[clip]
	local level = math.max(LEVEL[clip] or 0, rung - 1)
	if not tint or rung < 2 or level < 1 then
		return nil
	end
	return {
		colour = tint[1],
		accent = tint[2],
		level = level,
	}
end

-- Starts an emote's effect on a character, and its aura (nothing for emotes without them, or when their rung is
-- out of reach here; a preview always shows the effect, never the aura). Returns a function that clears it away.
function EmoteFx.play(character: Model, clip: string, preview: boolean?, phase: number?): () -> ()
	local fx = FX[clip]
	local rung = if preview then 0 else EmoteFx.rung(clip)
	local stops: { () -> () } = {}
	-- (another player's emote: its effects and its aura only if the settings allow them, 2026-10-25)
	local owner = Players:GetPlayerFromCharacter(character)
	local other = not preview and owner ~= nil and owner ~= Players.LocalPlayer
	if fx and (preview or rung >= (RUNG[clip] or 1)) and not (other and Settings.get("otherEmoteFx") == false) then
		table.insert(stops, fx(character, preview == true, phase))
	end
	local spec = if preview or (other and Settings.get("otherAuras") == false) then nil else auraFor(clip, rung)
	if spec then
		spec.own = mine(character)
		table.insert(stops, Aura.start(character, spec))
	end
	if #stops == 0 then
		return nothing
	end
	return function()
		for _, stop in ipairs(stops) do
			stop()
		end
	end
end

-- Clip ids that have an effect (for checks).
function EmoteFx.has(clip: string): boolean
	return FX[clip] ~= nil
end

-- A thud where something dropped from above lands (EmoteProps `drop`): a ring of dark dust thrown out low along
-- the floor, wider for bigger things (nothing on low graphics or under reduced motion).
function EmoteFx.thud(at: CFrame, size: number)
	if Governor.low("emoteFx") or Motion.isReduced() then
		return
	end
	-- dust thrown out low along the floor: anime puffs, and real smoke under them for a heavier landing; a ring rolling
	-- out over the floor from a big one, and for the biggest the floor cracks and bits of it jump
	local pos = at.Position + Vector3.new(0, 0.12, 0)
	local list: { any } = {
		{
			{
				tex = "VfxDust",
				grid = 4,
				mode = "OneShot",
				color = Color3.fromRGB(122, 120, 118),
				light = 0,
				lit = 0.6,
				size = { { 0, 0.45 + size * 0.14 }, { 1, 1.1 + size * 0.34 } },
				alpha = { { 0, 0.05 }, { 0.7, 0.3 }, { 1, 1 } },
				life = { 0.55, 0.95 },
				speed = { 3 + size, 5 + size * 1.8 },
				drag = 4,
				spread = { 86, 86 },
				rot = { 0, 360 },
				spin = { -40, 40 },
			},
			math.clamp(math.floor(size * 3), 6, 20),
		},
	}
	if size >= 1.5 then
		table.insert(list, {
			{
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = Color3.fromRGB(60, 58, 60),
				light = 0,
				lit = 0.5,
				size = { { 0, 0.8 + size * 0.2 }, { 1, 2 + size * 0.5 } },
				alpha = { { 0, 0.4 }, { 0.6, 0.55 }, { 1, 1 } },
				life = { 0.9, 1.4 },
				speed = { 2 + size * 0.8, 4 + size * 1.2 },
				drag = 3,
				spread = { 80, 80 },
				rot = { 0, 360 },
				spin = { -25, 25 },
			},
			math.clamp(math.floor(size * 1.5), 3, 10),
		})
	end
	Vfx.Emit.burst(CFrame.new(pos), list)
	if size >= 2.5 then
		Vfx.Beams.wave(CFrame.new(pos), size * 0.3, size * 1.4, 0.45, {
			tex = "VfxRingBand",
			color = Color3.fromRGB(190, 186, 180),
			width = size * 0.18,
			light = 0.4,
			bright = 1,
		})
	end
	if size >= 4 then
		Vfx.Ground.mark(at.Position, Vector3.yAxis, "VfxCrack", size * 1.6, Color3.fromRGB(140, 140, 145), 2.2)
		Vfx.Ground.debris(
			at.Position,
			math.floor(size),
			{ size = 0.35 + size * 0.06, speed = 14 + size * 2, life = 1.6 }
		)
	end
end

-- The wisp: every emote begins and ends in a little breath of pale grey dust round the feet, rising and gone
-- (the Core set's smoke, else Roblox's own; nothing on low graphics or under reduced motion).
function EmoteFx.wisp(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or Governor.low("emoteFx") or Motion.isReduced() then
		return
	end
	local at = Create("Attachment", { Name = "EmoteWisp", Position = Vector3.new(0, -2.6, 0), Parent = root })
	at:SetAttribute("DGEmote", true)
	local emitter = Vfx.Emit.make(at, {
		name = "EmoteWisp",
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(176, 174, 178),
		light = 0,
		lit = 0.55,
		size = { { 0, 0.6 }, { 1, 1.9 } },
		alpha = { { 0, 0.45 }, { 0.6, 0.6 }, { 1, 1 } },
		life = { 0.8, 1.2 },
		speed = { 1.4, 2.6 },
		spread = { 75, 75 },
		accel = Vector3.new(0, 1.5, 0),
		drag = 1.5,
		rot = { 0, 360 },
		spin = { -40, 40 },
	})
	emitter:Emit(8)
	-- (2026-11-14: a pale ring rolls out over the floor from the feet, and a few motes lift off it: an emote begins and
	-- ends on a beat you can see)
	local floor = floorUnder(root.Position, character)
	Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.08, 0)), 0.6, 4.2, 0.55, {
		tex = "VfxRingBand",
		color = Color3.fromRGB(214, 212, 218),
		width = 0.35,
		light = 0.6,
		bright = 1,
	})
	Vfx.Emit.burst(CFrame.new(floor + Vector3.new(0, 0.2, 0)), {
		tex = "VfxEmber",
		color = Color3.fromRGB(236, 234, 240),
		size = { { 0, 0.1 }, { 0.6, 0.07 }, { 1, 0 } },
		alpha = { { 0, 0.3 }, { 1, 1 } },
		life = { 0.8, 1.4 },
		speed = { 1, 2.4 },
		spread = 40,
		accel = Vector3.new(0, 2, 0),
		drag = 1.5,
		light = 1,
		bright = 1,
		shape = Enum.ParticleEmitterShape.Disc,
	}, 7, Vector3.new(3, 0.1, 3))
	task.delay(1.7, function()
		at:Destroy()
	end)
end

-- Every clip id that has an effect, sorted (the debug booth's catalogue, Presentation/Vfx/Catalog, lists them all).
function EmoteFx.clips(): { string }
	local list: { string } = {}
	for clip in pairs(FX) do
		table.insert(list, clip)
	end
	table.sort(list)
	return list
end

return EmoteFx
