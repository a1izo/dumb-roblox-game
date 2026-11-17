-- Everyone's emotes, the Scrawl ones and the Penned ones: one small touch each, timed to its clip. Moved
-- unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local Common = require(script.Parent.Shared)
local EmoteFx = Common.EmoteFx
local floorUnder = Common.floorUnder
local burst = Common.burst
local stepDust = Common.stepDust
local accent = Common.accent
local GOLD = Common.GOLD
local PAPER = Common.PAPER
local THOUGHT = Common.THOUGHT
local GLINT = Common.GLINT
local hand = Common.hand
local onHead = Common.onHead
local glint = Common.glint
local floatSign = Common.floatSign

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

local CRUMBS = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(222, 170, 80))

local BREATH = ColorSequence.new(Color3.fromRGB(226, 226, 230))

-- Everyone's emotes ---------------------------------------------------------------------------------------------

-- Wave: the waving hand catches the light at each turn of the wave.
FX.wave = accent(2.4, { 0.63, 0.93, 1.2 }, function(character)
	glint(hand(character, "Right"), 3, 0.22)
end)
-- Point: a small crack of light off the fingertip as the arm comes out.
FX.point = accent(1.6, { 0.55 }, function(character)
	glint(hand(character, "Left"), 6, 0.26)
end)
-- Cheer: scraps of paper thrown up at the top of the jump.
FX.cheer = accent(2.2, { 0.73 }, function(character)
	local at = onHead(character, Vector3.new(0, 1.4, 0))
	if at then
		burst(at, {
			color = PAPER,
			count = 10,
			size = 0.28,
			speed = NumberRange.new(3, 6),
			life = NumberRange.new(1.0, 1.5),
			spread = 70,
			gravity = 4,
			light = 0,
		})
	end
end)
-- Laugh: a little breath of laughter from the mouth with each burst.
FX.laugh = accent(1.2, { 0.37 }, function(character)
	local at = onHead(character, Vector3.new(0, -0.2, -0.7))
	if at then
		burst(at, {
			color = BREATH,
			count = 3,
			size = 0.3,
			speed = NumberRange.new(0.6, 1.2),
			life = NumberRange.new(0.35, 0.55),
			spread = 30,
			gravity = -1,
			light = 0,
			direction = Enum.NormalId.Front,
		})
	end
end)
-- Dance: dust under each step.
FX.dance = accent(1.6, { 0.13, 0.67, 0.9, 1.23 }, function(character)
	stepDust(character, 0.8)
end)
-- Salute: a glint off the hand as it snaps to the brow.
FX.salute = accent(2.0, { 0.77 }, function(character)
	glint(hand(character, "Right"), 4, 0.24)
end)
-- Bow: a breath of dust round the feet at the bottom of the bow.
FX.bow = accent(2.6, { 1.33 }, function(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		EmoteFx.thud(CFrame.new(floorUnder(root.Position, character)), 2.4)
	end
end)
-- Shrug: a question mark floats up off the head as the shoulders come up.
FX.shrug = accent(2.0, { 1.0 }, function(character)
	floatSign(character, "?", 1)
end)
-- Facepalm: a little star of light where the palm meets the face.
FX.facepalm = accent(2.4, { 0.73 }, function(character)
	glint(onHead(character, Vector3.new(0, 0.1, -0.7)), 6, 0.3)
end)
-- High Five and Handshake: the hands meet with a burst of light (a duo's contact beat).
FX.highFive = accent(2.0, { 0.73 }, function(character)
	local at = hand(character, "Right")
	if at then
		burst(at, {
			color = GLINT,
			count = 12,
			size = 0.32,
			speed = NumberRange.new(4, 8),
			life = NumberRange.new(0.15, 0.3),
			spread = 180,
			light = 1,
		})
	end
end)
FX.handshake = accent(2.4, { 1.0 }, function(character)
	glint(hand(character, "Right"), 5, 0.24)
end)

-- Scrawl ---------------------------------------------------------------------------------------------------------

-- Bounce Pump: dust on every other beat of the bounce (16 beats to the loop).
FX.bouncePump = accent(6.4865, { 0, 0.81, 1.62, 2.43, 3.24, 4.05, 4.86, 5.68 }, function(character)
	stepDust(character, 1.0)
end)
-- Potato Chip: crumbs off the bite.
FX.chip = accent(3.4, { 1.4 }, function(character)
	local at = onHead(character, Vector3.new(0, -0.25, -0.65))
	if at then
		burst(at, {
			color = CRUMBS,
			count = 8,
			size = 0.22,
			speed = NumberRange.new(2, 4),
			life = NumberRange.new(0.4, 0.7),
			spread = 60,
			gravity = 18,
			light = 0.4,
		})
	end
end)
-- Coin Flip: the coin flashes at the top of its toss, and again as it is slapped down.
FX.coinFlip = accent(3.0, { 0.95, 1.55 }, function(character, at)
	local fist = hand(character, if at < 1.5 then "Right" else "Left")
	if fist then
		burst(fist + Vector3.new(0, if at < 1.5 then 3.0 else 0.2, 0), {
			color = GOLD,
			count = 4,
			size = 0.3,
			speed = NumberRange.new(0.5, 1),
			life = NumberRange.new(0.2, 0.35),
			spread = 180,
			light = 1,
		})
	end
end)
-- Dance 2 and Dance 3: dust under the steps.
FX.dance2 = accent(2.1667, { 0.7, 1.73 }, function(character)
	stepDust(character, 0.9)
end)
FX.dance3 = accent(1.6, { 0.4, 1.2 }, function(character)
	stepDust(character, 0.9)
end)
-- Foot Scratch: dust kicked up by the scratching foot.
FX.footScratch = accent(2.0, { 0.5, 1.5 }, function(character)
	stepDust(character, 0.6)
end)
-- Hair Twirl: a few motes of light off the twirling fingers.
FX.hairTwirl = accent(2.4, { 0.93 }, function(character)
	glint(hand(character, "Right"), 3, 0.18)
end)
-- Jawline Check: the anime "ting" of light down the jaw at the flick.
FX.jawlineCheck = accent(3.2, { 1.8 }, function(character)
	glint(onHead(character, Vector3.new(0.35, -0.45, -0.45)), 7, 0.36)
end)
-- Take the L: dust under the hops.
FX.takeTheL = accent(1.6, { 0.33, 1.13 }, function(character)
	stepDust(character, 0.9)
end)
-- The Classic: dust under each step of the routine.
FX.theClassic = accent(6.0, { 0.5, 1.1, 1.7, 2.33, 3.73, 4.3, 4.8 }, function(character)
	stepDust(character, 0.9)
end)
-- The Eyebrow: a glint off the raised brow.
FX.theEyebrow = accent(3.4, { 0.8 }, function(character)
	glint(onHead(character, Vector3.new(0.3, 0.3, -0.62)), 4, 0.26)
end)
-- Think: a faint spark of an idea by the temple now and then.
FX.think = accent(4.0, { 0.63, 2.6 }, function(character)
	local at = onHead(character, Vector3.new(0.6, 0.5, -0.2))
	if at then
		burst(at, {
			color = THOUGHT,
			count = 4,
			size = 0.16,
			speed = NumberRange.new(0.6, 1.2),
			life = NumberRange.new(0.3, 0.5),
			spread = 60,
			light = 1,
		})
	end
end)
-- Two Weeks' Notice: the resignation thrown up in a scatter of paper.
FX.twoWeeksNotice = accent(3.2, { 2.23 }, function(character)
	local at = onHead(character, Vector3.new(0, 1.6, 0))
	if at then
		burst(at, {
			color = PAPER,
			count = 12,
			size = 0.36,
			speed = NumberRange.new(3, 6),
			life = NumberRange.new(1.2, 1.8),
			spread = 75,
			gravity = 3,
			light = 0,
		})
	end
end)

-- Penned ---------------------------------------------------------------------------------------------------------

-- Apple Toss: the apple catches the light as it leaves the hand, and as it is caught.
FX.appleToss = accent(3.6, { 0.5, 2.9 }, function(character)
	glint(hand(character, "Right"), 4, 0.26)
end)
-- Excuse Me, Sir: a polite little cough into the air before the look up.
FX.excuseMeSir = accent(1.6, { 0.4 }, function(character)
	local at = onHead(character, Vector3.new(0, -0.25, -0.7))
	if at then
		burst(at, {
			color = BREATH,
			count = 2,
			size = 0.25,
			speed = NumberRange.new(0.5, 1),
			life = NumberRange.new(0.3, 0.5),
			spread = 25,
			gravity = -1,
			light = 0,
			direction = Enum.NormalId.Front,
		})
	end
end)

return FX
