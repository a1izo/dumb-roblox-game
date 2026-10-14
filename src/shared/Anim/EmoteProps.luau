--!strict
-- What emotes hold or set down, by clip (EmoteController.dress puts them on, on every client that sees the
-- emote, and takes them away when it ends). Each is a Core model (art/scripts/props_shop.py and
-- props_emotes.py), or a plain stand-in part until an import has it. The timings go with the clips in
-- art/scripts/anims_emotes.py.
--
--   model   the Core model's key (ModelLibrary)
--   size    its biggest side in studs (the model is scaled to it)
--   stand   the stand-in: a part's shape ("Block", "Ball" or "Cylinder"), size and colour
--   mount   the body part it goes on ("Right Arm", "Left Arm", "Head", "Torso"), or "floor": standing on the
--           floor under the body, turned with it (3 studs under the root: an R6 body's height)
--   at      where it sits, from the middle of that part (or from that point on the floor)
--   show    seconds into the clip it appears (at the start when nil); hide: when it goes (at the end when nil)
--   moves   carried somewhere else at a time: { at = seconds, mount = part?, to = CFrame }
--   tosses  thrown up off the hand and caught: { at, back, height, spin (turns) }
--   stack   copies set one on another: { step = CFrame, times = { seconds, ... } } (one at each time)

local EmoteProps = {}

export type Move = { at: number, mount: string?, to: CFrame }
export type Toss = { at: number, back: number, height: number, spin: number }
export type Stack = { step: CFrame, times: { number } }
export type Stand = { shape: string, size: Vector3, color: Color3 }
export type Prop = {
	model: string,
	size: number,
	stand: Stand,
	mount: string,
	at: CFrame,
	show: number?,
	hide: number?,
	moves: { Move }?,
	tosses: { Toss }?,
	stack: Stack?,
}

local rad = math.rad

-- In the right hand, from the arm's middle (its hand is a stud below).
local GRIP = CFrame.new(0, -1.05, -0.25)
local LEFT_GRIP = CFrame.new(0, -1.05, -0.25)
-- Held out of the fist pointing forward, like a club (its middle `reach` studs ahead of the hand).
local function forward(reach: number): CFrame
	return CFrame.new(0, -1.0, -reach) * CFrame.Angles(rad(-90), 0, 0)
end

-- The notebook everyone holds when writing (CharacterService.setWriting), and its pen.
local NOTEBOOK = CFrame.new(0, -0.35, -1.05) * CFrame.Angles(rad(35), 0, 0)
local PEN = CFrame.new(0, -0.35, -0.2) * CFrame.Angles(rad(-55), 0, 0)

local function stand(shape: string, x: number, y: number, z: number, r: number, g: number, b: number): Stand
	return { shape = shape, size = Vector3.new(x, y, z), color = Color3.fromRGB(r, g, b) }
end

local NOTEBOOK_STAND = stand("Block", 1.3, 0.14, 0.95, 22, 22, 26)
local PEN_STAND = stand("Cylinder", 0.9, 0.09, 0.09, 14, 14, 16)

local CLIPS: { [string]: { Prop } } = {
	coinFlip = {
		{
			model = "Coin",
			size = 0.5,
			stand = stand("Cylinder", 0.08, 0.5, 0.5, 176, 142, 74),
			mount = "Right Arm",
			at = GRIP,
			-- Off the thumb at 0.55 s, up and spinning, back in the hand at 1.35 s.
			tosses = { { at = 0.55, back = 1.35, height = 3.2, spin = 4 } },
		},
	},
	appleBite = {
		{
			model = "Apple",
			size = 0.8,
			stand = stand("Ball", 0.7, 0.7, 0.7, 150, 20, 26),
			mount = "Right Arm",
			at = GRIP,
		},
	},
	preDawnBonk = {
		{
			model = "Bat",
			size = 2.6,
			stand = stand("Cylinder", 2.6, 0.32, 0.32, 140, 100, 64),
			mount = "Right Arm",
			at = forward(1.1),
		},
	},
	blindfoldLift = {
		{
			model = "Blindfold",
			size = 1.5,
			stand = stand("Block", 1.3, 0.3, 1.3, 14, 14, 16),
			mount = "Head",
			at = CFrame.new(0, 0.04, 0),
			-- Pushed up onto the brow by two fingers.
			moves = { { at = 1.15, to = CFrame.new(0, 0.44, 0.05) * CFrame.Angles(rad(-12), 0, 0) } },
		},
	},
	chairPerch = {
		{
			model = "Chair",
			size = 3.9,
			stand = stand("Block", 1.8, 1.75, 1.8, 82, 45, 32),
			mount = "floor",
			at = CFrame.new(0, 0, 0.15),
		},
	},
	twoFingerGrip = {
		{
			model = "Phone",
			size = 1.05,
			stand = stand("Block", 0.5, 1.05, 0.12, 20, 20, 22),
			mount = "Right Arm",
			-- Hanging straight down from two fingertips: turned back against the raised arm and the lean.
			at = CFrame.new(0, -1.08, -0.05) * CFrame.Angles(rad(-108), 0, rad(8)) * CFrame.new(0, -0.52, 0),
		},
	},
	sugarTower = {
		{
			model = "SugarCube",
			size = 0.42,
			stand = stand("Block", 0.42, 0.42, 0.42, 240, 238, 232),
			mount = "floor",
			at = CFrame.new(0, 0, -1.5),
			stack = { step = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, rad(7), 0), times = { 1.0, 1.8, 2.6, 3.4, 4.4 } },
		},
	},
	chipAndPen = {
		{ model = "Notebook", size = 1.3, stand = NOTEBOOK_STAND, mount = "Torso", at = NOTEBOOK, hide = 4.4 },
		{ model = "Pen", size = 1.07, stand = PEN_STAND, mount = "Right Arm", at = PEN, hide = 2.0 },
		{
			model = "Chip",
			size = 0.5,
			stand = stand("Block", 0.5, 0.05, 0.42, 222, 178, 86),
			mount = "Right Arm",
			at = GRIP * CFrame.Angles(rad(70), 0, 0),
			show = 2.05,
			hide = 3.32,
		},
	},
	furiousScribbling = {
		{ model = "Notebook", size = 1.3, stand = NOTEBOOK_STAND, mount = "Torso", at = NOTEBOOK },
		{ model = "Pen", size = 1.07, stand = PEN_STAND, mount = "Right Arm", at = PEN },
	},
	furiousScribblingSlash = {
		{ model = "Notebook", size = 1.3, stand = NOTEBOOK_STAND, mount = "Torso", at = NOTEBOOK },
		{ model = "Pen", size = 1.07, stand = PEN_STAND, mount = "Right Arm", at = PEN },
	},
	appleToss = {
		{
			model = "Apple",
			size = 0.8,
			stand = stand("Ball", 0.7, 0.7, 0.7, 150, 20, 26),
			mount = "Right Arm",
			at = GRIP,
			tosses = {
				{ at = 0.5, back = 1.25, height = 3.6, spin = 1 },
				{ at = 1.55, back = 2.3, height = 3.6, spin = 1 },
			},
		},
	},
	strawberryOnTop = {
		{
			model = "CakeSlice",
			size = 1.1,
			stand = stand("Block", 0.9, 0.45, 0.5, 240, 230, 210),
			mount = "Left Arm",
			-- The plate held level on the hand: turned back against the raised arm.
			at = LEFT_GRIP * CFrame.Angles(rad(-70), 0, 0) * CFrame.new(0, 0.05, -0.2),
		},
		{
			model = "Strawberry",
			size = 0.32,
			stand = stand("Ball", 0.3, 0.3, 0.3, 190, 30, 36),
			mount = "Left Arm",
			at = LEFT_GRIP * CFrame.Angles(rad(-70), 0, 0) * CFrame.new(0.12, 0.66, -0.2),
			-- Plucked off the top into the right hand's fingertips, then eaten.
			moves = { { at = 1.0, mount = "Right Arm", to = CFrame.new(0, -1.15, -0.12) } },
			hide = 2.78,
		},
	},
	diceTower = {
		{
			model = "Die",
			size = 0.42,
			stand = stand("Block", 0.42, 0.42, 0.42, 236, 234, 228),
			mount = "floor",
			at = CFrame.new(0, 0, -1.3),
			stack = {
				step = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, rad(-9), 0),
				times = { 0.9, 1.6, 2.3, 3.0, 3.7, 4.6 },
			},
		},
	},
	chocolateSnap = {
		{
			model = "ChocolateBar",
			size = 0.95,
			stand = stand("Block", 0.45, 0.95, 0.12, 70, 40, 26),
			mount = "Right Arm",
			-- Upright in the fist when it is up at the mouth: turned back against the raised arm.
			at = CFrame.new(0, -1.05, -0.1) * CFrame.Angles(rad(-124), 0, 0) * CFrame.new(0, 0.35, 0),
		},
	},
	mushroomStroll = {
		{
			model = "WalkingStick",
			size = 4.0,
			stand = stand("Cylinder", 4.0, 0.2, 0.2, 90, 66, 46),
			mount = "Torso",
			-- Over the right shoulder, pointing back and up, its foot in the raised hand.
			at = CFrame.new(0.72, 1.35, 0.55) * CFrame.Angles(rad(54), 0, 0),
		},
	},
	fortySeconds = {
		{
			model = "Wristwatch",
			size = 1.25,
			stand = stand("Block", 0.4, 0.22, 0.12, 190, 190, 196),
			mount = "Left Arm",
			at = CFrame.new(0, -0.62, 0),
		},
	},
}

-- What a clip holds (an empty list for one that holds nothing).
function EmoteProps.of(clip: string): { Prop }
	return CLIPS[clip] or {}
end

-- Every clip that holds something (for checks).
function EmoteProps.clips(): { string }
	local list = {}
	for clip in pairs(CLIPS) do
		table.insert(list, clip)
	end
	table.sort(list)
	return list
end

return EmoteProps
