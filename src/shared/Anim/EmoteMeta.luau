-- What each emote clip needs besides its keyframes, in plain data: the props it holds or sets down and when
-- (Anim/EmoteProps turns these into CFrames for EmoteController). The art scripts read this file too
-- (art/scripts/emotemeta.py: the prop checks and the preview renders put the same props on the same hands),
-- so it holds only numbers, strings, booleans and tables: no CFrames, Vector3s or calls.
--
-- props, per prop:
--   model   the Core model's key (ModelLibrary)
--   size    its biggest side in studs (the model is scaled to it)
--   stand   the stand-in until an import has the model: shape ("Block", "Ball", "Cylinder"), size, color
--   mount   the body part it goes on ("Right Arm", "Left Arm", "Head", "Torso"), or "floor" (on the floor
--           under the body, turned with it)
--   at      where it sits from the middle of that part (or from that point on the floor): steps applied in
--           order, { p = { x, y, z } } a move in studs, { r = { x, y, z } } a turn in degrees (CFrame.Angles)
--   show    seconds into the clip it appears (at the start when nil); hide: when it goes (at the end when nil)
--   moves   carried somewhere else at a time: { at = seconds, mount = part?, to = steps }
--   tosses  thrown up off the hand and caught: { at, back, height, spin (turns) }
--   stack   copies set one on another: { step = steps, times = { seconds, ... } } (one at each time)
--   core    the Core import the hold is made for (a remodelled mesh): an older import shows the stand-in

local GRIP = { { p = { 0, -1.05, -0.25 } } }
local RACKET = {
	model = "Racket",
	size = 2.1,
	stand = { shape = "Block", size = { 0.8, 2.1, 0.08 }, color = { 150, 112, 72 } },
	mount = "Right Arm",
	at = { { p = { 0, -1.8, 0 } }, { r = { 180, -62.22, 0 } } }, -- hold: matchPointServe/Racket
}
local NOTEBOOK = {
	model = "Grimoire",
	size = 1.3,
	stand = { shape = "Block", size = { 1.3, 0.14, 0.95 }, color = { 22, 22, 26 } },
	mount = "Torso",
	at = { { p = { 0, -0.35, -1.05 } }, { r = { 35, 0, 0 } } },
}
local PEN = {
	model = "Pen",
	size = 1.07,
	stand = { shape = "Cylinder", size = { 0.9, 0.09, 0.09 }, color = { 14, 14, 16 } },
	mount = "Right Arm",
	at = { { p = { 0, -0.35, -0.2 } }, { r = { -55, 0, 0 } } },
}

return {
	coinFlip = {
		props = {
			{
				model = "Coin",
				size = 0.5,
				stand = { shape = "Cylinder", size = { 0.08, 0.5, 0.5 }, color = { 176, 142, 74 } },
				mount = "Right Arm",
				at = { { p = { 0.126, -1.058, -0.068 } }, { r = { 7.51, 4.52, 30.84 } } }, -- hold: coinFlip/Coin
				-- Off the thumb at 0.55 s, up and spinning, back in the fist at 1.35 s; slapped onto the back of the
				-- left hand at 1.55 s, picked back up at 2.5 s.
				tosses = { { at = 0.55, back = 1.35, height = 3.2, spin = 4 } },
				moves = {
					{
						at = 1.55,
						mount = "Left Arm",
						to = { { p = { -0.018, -0.825, -0.54 } }, { r = { -86.27, 42.37, -2.52 } } }, -- hold: coinFlip/CoinBack
					},
					{
						at = 2.5,
						mount = "Right Arm",
						to = { { p = { 0.126, -1.058, -0.068 } }, { r = { 7.51, 4.52, 30.84 } } }, -- hold: coinFlip/CoinUp
					},
				},
			},
		},
		context = { label = "FLIP", from = 2.55, to = 3.0, branch = "coinFlip" },
		-- the coin goes under the slapping hand, and is picked up from under it
		allow = {
			{ prop = 1, part = "Left Arm", from = 1.42, to = 1.58 },
			{ prop = 1, part = "Right Arm", from = 1.45, to = 1.95 },
			{ prop = 1, part = "Right Arm", from = 2.38, to = 2.6 },
		},
	},
	appleBite = {
		props = {
			{
				model = "Apple",
				size = 0.8,
				stand = { shape = "Ball", size = { 0.7, 0.7, 0.7 }, color = { 150, 20, 26 } },
				mount = "Right Arm",
				at = { { p = { 0.044, -1.203, -0.178 } }, { r = { -90.38, -23.38, -0.15 } } }, -- hold: appleBite/Apple
			},
		},
		-- the crunch: the head lunges into the apple (touching the lips, its middle is about its radius from the mouth)
		contacts = { { at = 0.95, prop = 1, to = "mouth", within = 0.45 } },
		allow = { { prop = 1, part = "Head", from = 0.83, to = 1.05 } },
	},
	-- LOOK UP, any time in the swagger: the face tipped back to the sky with the grin (the meme's panel)
	excuseMeSir = { context = { label = "LOOK UP", from = 0, to = 1.6, branch = "excuseMeSirUp" } },
	-- (the branch is not an item of its own: its effect takes the emote's rarity, Inked)
	excuseMeSirUp = { fx = 1 },
	preDawnBonk = {
		props = {
			{
				model = "Bat",
				size = 2.6,
				stand = { shape = "Cylinder", size = { 2.6, 0.32, 0.32 }, color = { 140, 100, 64 } },
				mount = "Right Arm",
				-- Held out of the fist pointing forward, like a club.
				at = { { p = { 0, -1.0, -1.1 } }, { r = { -90, 0, 0 } } },
			},
		},
	},
	blindfoldLift = {
		props = {
			{
				model = "Blindfold",
				size = 1.5,
				stand = { shape = "Block", size = { 1.3, 0.3, 1.3 }, color = { 14, 14, 16 } },
				mount = "Head",
				at = { { p = { 0, 0.04, 0 } } },
				-- Pushed up onto the brow by two fingers.
				moves = { { at = 1.15, to = { { p = { 0, 0.44, 0.05 } }, { r = { -12, 0, 0 } } } } },
			},
		},
	},
	chairPerch = {
		props = {
			{
				model = "Chair",
				size = 3.9,
				stand = { shape = "Block", size = { 1.8, 1.75, 1.8 }, color = { 82, 45, 32 } },
				mount = "floor",
				at = { { p = { 0, 0, 0.15 } } },
			},
		},
	},
	twoFingerGrip = {
		props = {
			{
				model = "Phone",
				size = 1.05,
				stand = { shape = "Block", size = { 0.5, 1.05, 0.12 }, color = { 20, 20, 22 } },
				mount = "Right Arm",
				-- Hanging straight down from two fingertips: turned back against the raised arm and the lean.
				at = { { p = { 0, -1.08, -0.05 } }, { r = { -108, 0, 8 } }, { p = { 0, -0.52, 0 } } },
			},
		},
	},
	sugarTower = {
		props = {
			{
				model = "SugarCube",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 240, 238, 232 } },
				mount = "floor",
				at = { { p = { 0, 0, -1.5 } } },
				stack = { step = { { p = { 0, 0.42, 0 } }, { r = { 0, 7, 0 } } }, times = { 1.0, 1.8, 2.6, 3.4, 4.4 } },
			},
		},
	},
	-- Diavolo's Potato Chip: the desk falls from the sky (the table in front, the chair behind, then the radio on
	-- the right, the open notebook with the pen on it and the bag of crisps on the left), he sits, takes the pen
	-- and the bag, writes through the bag's mouth, puts the pen back, takes a crisp out of the bag, raises it and
	-- bites it, sets the bag down, stands, and it all sinks into the floor. Floor places from the floor under the
	-- body (forward -z); hand holds solved from the clip's key poses (art/scripts/emotes/props.py).
	chipAndPen = {
		props = {
			{
				model = "Table",
				size = 5,
				stand = { shape = "Block", size = { 5, 2.75, 3 }, color = { 72, 50, 32 } },
				mount = "floor",
				at = { { p = { 0, 0, -2.05 } } },
				show = 0.35,
				drop = { height = 26, time = 0.65 },
				sink = { at = 9.1, time = 1.0 },
			},
			{
				model = "Chair",
				size = 3.9,
				stand = { shape = "Block", size = { 1.8, 1.75, 1.8 }, color = { 82, 45, 32 } },
				mount = "floor",
				at = { { p = { 0, 0, 1.4 } } },
				show = 0.6,
				drop = { height = 26, time = 0.65 },
				sink = { at = 9.15, time = 1.0 },
			},
			{
				model = "Radio",
				size = 1.5,
				stand = { shape = "Block", size = { 1.1, 0.67, 0.4 }, color = { 160, 162, 168 } },
				mount = "floor",
				at = { { p = { 1.5, 2.75, -2.2 } }, { r = { 0, -20, 0 } } },
				show = 0.95,
				drop = { height = 22, time = 0.55 },
				sink = { at = 9.1, time = 0.9 },
				core = 9,
			},
			{
				model = "NotebookOpen",
				size = 2.0,
				stand = { shape = "Block", size = { 2.0, 0.08, 0.8 }, color = { 226, 222, 210 } },
				mount = "floor",
				at = { { p = { -0.35, 2.75, -1.15 } }, { r = { 0, 8, 0 } } },
				show = 1.05,
				drop = { height = 22, time = 0.55 },
				sink = { at = 9.1, time = 0.9 },
			},
			{
				model = "Pen",
				size = 0.8,
				stand = { shape = "Cylinder", size = { 0.8, 0.08, 0.08 }, color = { 14, 14, 16 } },
				mount = "floor",
				at = { { p = { 0.05, 2.82, -0.95 } }, { r = { 0, 60, 0 } }, { r = { 90, 0, 0 } } },
				show = 1.05,
				drop = { height = 22, time = 0.55 },
				moves = {
					{
						at = 2.85,
						mount = "Right Arm",
						to = { { p = { -0.103, -1.057, 0.099 } }, { r = { -86.6, -52.78, -5.29 } } }, -- hold: chipAndPen/Pen
					},
					{
						at = 4.75,
						mount = "floor",
						to = { { p = { 0.05, 2.82, -0.95 } }, { r = { 0, 60, 0 } }, { r = { 90, 0, 0 } } },
					},
				},
				sink = { at = 9.1, time = 0.9 },
			},
			{
				model = "ChipBag",
				size = 1.25,
				stand = { shape = "Block", size = { 0.7, 1.0, 0.32 }, color = { 170, 28, 32 } },
				mount = "floor",
				at = { { p = { -1.5, 2.75, -1.0 } }, { r = { 0, 15, 0 } } },
				show = 1.15,
				drop = { height = 22, time = 0.55 },
				moves = {
					{
						at = 3.05,
						mount = "Left Arm",
						to = { { p = { -0.062, -0.977, 0.552 } }, { r = { -74.17, 24.86, -6.8 } } }, -- hold: chipAndPen/ChipBag
					},
					{ at = 8.05, mount = "floor", to = { { p = { -1.5, 2.75, -1.0 } }, { r = { 0, 15, 0 } } } },
				},
				sink = { at = 9.1, time = 0.9 },
			},
			{
				model = "Chip",
				size = 0.5,
				stand = { shape = "Block", size = { 0.5, 0.05, 0.42 }, color = { 222, 178, 86 } },
				mount = "Right Arm",
				at = { { p = { 0.029, -1.144, -0.147 } }, { r = { -49.49, -1.37, 1.17 } } }, -- hold: chipAndPen/Chip
				show = 5.3,
				hide = 7.08,
			},
		},
		contacts = { { at = 7.05, prop = 7, to = "mouth", within = 0.3 } },
		-- the right hand writes at the bag's mouth and goes into it for the crisp; seated, the body rests on the
		-- chair and the legs go under the table
		allow = {
			{ prop = 6, part = "Right Arm", from = 3.2, to = 5.4 },
			{ prop = 2, part = "Torso", from = 2.2, to = 8.9 },
			{ prop = 2, part = "Right Leg", from = 2.2, to = 8.9 },
			{ prop = 2, part = "Left Leg", from = 2.2, to = 8.9 },
			{ prop = 1, part = "Right Leg", from = 2.2, to = 8.9 },
			{ prop = 1, part = "Left Leg", from = 2.2, to = 8.9 },
		},
	},
	-- Light's potato chip, standing: the bag at the left hip, a chip taken from it and held up; EAT bites it.
	chip = {
		props = {
			{
				model = "ChipBag",
				size = 1.25,
				stand = { shape = "Block", size = { 0.7, 1.0, 0.32 }, color = { 170, 28, 32 } },
				mount = "Left Arm",
				at = { { p = { 0.091, -1.038, -0.677 } }, { r = { -18.73, 12.88, -2.62 } } }, -- hold: chip/ChipBag
			},
			{
				model = "Chip",
				size = 0.5,
				stand = { shape = "Block", size = { 0.5, 0.05, 0.42 }, color = { 222, 178, 86 } },
				mount = "Right Arm",
				at = { { p = { 0.023, -1.14, -0.157 } }, { r = { -47.58, -0.5, 0.45 } } }, -- hold: chip/Chip
				show = 0.88,
			},
		},
		context = { label = "EAT", from = 1.3, to = 2.4, branch = "chipEat" },
		-- the right hand goes into the bag for the chip
		allow = { { prop = 1, part = "Right Arm", from = 0.55, to = 1.1 } },
	},
	chipEat = {
		props = {
			{
				model = "ChipBag",
				size = 1.25,
				stand = { shape = "Block", size = { 0.7, 1.0, 0.32 }, color = { 170, 28, 32 } },
				mount = "Left Arm",
				at = { { p = { 0.091, -1.038, -0.677 } }, { r = { -18.73, 12.88, -2.62 } } }, -- hold: chipEat/ChipBag
			},
			{
				model = "Chip",
				size = 0.5,
				stand = { shape = "Block", size = { 0.5, 0.05, 0.42 }, color = { 222, 178, 86 } },
				mount = "Right Arm",
				at = { { p = { 0.023, -1.14, -0.157 } }, { r = { -47.58, -0.5, 0.45 } } }, -- hold: chipEat/Chip
				hide = 0.34,
			},
		},
		-- (the arm's follow-through brings the chip in at 0.3 s, where it goes)
		contacts = { { at = 0.3, prop = 2, to = "mouth", within = 0.35 } },
		-- the chip goes into the mouth
		allow = { { prop = 2, part = "Head", from = 0.26, to = 0.34 } },
	},
	furiousScribbling = { props = { NOTEBOOK, PEN } },
	furiousScribblingSlash = { props = { NOTEBOOK, PEN } },
	appleToss = {
		props = {
			{
				model = "Apple",
				size = 0.8,
				stand = { shape = "Ball", size = { 0.7, 0.7, 0.7 }, color = { 150, 20, 26 } },
				mount = "Right Arm",
				at = GRIP,
				tosses = {
					{ at = 0.5, back = 1.25, height = 3.6, spin = 1 },
					{ at = 1.55, back = 2.3, height = 3.6, spin = 1 },
				},
			},
		},
	},
	strawberryOnTop = {
		props = {
			{
				model = "CakeSlice",
				size = 1.1,
				stand = { shape = "Block", size = { 0.9, 0.45, 0.5 }, color = { 240, 230, 210 } },
				mount = "Left Arm",
				-- The plate held level on the hand: turned back against the raised arm.
				at = { { p = { 0, -1.05, -0.25 } }, { r = { -70, 0, 0 } }, { p = { 0, 0.05, -0.2 } } },
			},
			{
				model = "Strawberry",
				size = 0.32,
				stand = { shape = "Ball", size = { 0.3, 0.3, 0.3 }, color = { 190, 30, 36 } },
				mount = "Left Arm",
				at = { { p = { 0, -1.05, -0.25 } }, { r = { -70, 0, 0 } }, { p = { 0.12, 0.66, -0.2 } } },
				-- Plucked off the top into the right hand's fingertips, then eaten.
				moves = { { at = 1.0, mount = "Right Arm", to = { { p = { 0, -1.15, -0.12 } } } } },
				hide = 2.78,
			},
		},
	},
	diceTower = {
		props = {
			{
				model = "Die",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 236, 234, 228 } },
				mount = "floor",
				at = { { p = { 0, 0, -1.3 } } },
				stack = {
					step = { { p = { 0, 0.42, 0 } }, { r = { 0, -9, 0 } } },
					times = { 0.9, 1.6, 2.3, 3.0, 3.7, 4.6 },
				},
			},
		},
	},
	chocolateSnap = {
		props = {
			{
				model = "ChocolateBar",
				size = 0.95,
				stand = { shape = "Block", size = { 0.45, 0.95, 0.12 }, color = { 70, 40, 26 } },
				mount = "Right Arm",
				-- Upright in the fist when it is up at the mouth: turned back against the raised arm.
				at = { { p = { 0, -1.05, -0.1 } }, { r = { -124, 0, 0 } }, { p = { 0, 0.35, 0 } } },
			},
		},
	},
	matchPointServe = { props = { RACKET } },
	matchPointReturn = { props = { RACKET } },
	smilingLord = {
		props = {
			{
				model = "Cane",
				size = 2.2,
				stand = { shape = "Cylinder", size = { 2.2, 0.12, 0.12 }, color = { 14, 14, 16 } },
				mount = "Left Arm",
				-- A walking cane, down from the fist to the floor.
				at = { { p = { 0, -1.05, -0.1 } }, { p = { 0, -1.05, 0 } } },
			},
		},
	},
	mushroomStroll = {
		props = {
			{
				model = "WalkingStick",
				size = 4.0,
				stand = { shape = "Cylinder", size = { 4.0, 0.2, 0.2 }, color = { 90, 66, 46 } },
				mount = "Torso",
				-- Over the right shoulder, pointing back and up, its foot in the raised hand.
				at = { { p = { 0.72, 1.35, 0.55 } }, { r = { 54, 0, 0 } } },
			},
		},
	},
	fortySeconds = {
		props = {
			{
				model = "Wristwatch",
				-- (the Core v8 watch: its strap square round the wrist, at full size so it sits just clear)
				size = 1.265,
				core = 8,
				stand = { shape = "Block", size = { 0.4, 0.22, 0.12 }, color = { 190, 190, 196 } },
				mount = "Left Arm",
				at = { { p = { 0, -0.62, 0 } } },
			},
		},
	},
	-- Cuffed Together: a cuff on each chained wrist (the leader's left, the follower's right), its ring on the
	-- arm's outer side where the chain hangs from (Controllers/DuoController).
	cuffedLead = {
		props = {
			{
				model = "Cuff",
				size = 1.372,
				core = 8,
				stand = { shape = "Block", size = { 1.2, 0.22, 1.2 }, color = { 120, 122, 128 } },
				mount = "Left Arm",
				at = { { p = { 0, -0.75, 0 } } },
			},
		},
	},
	cuffedFollow = {
		props = {
			{
				model = "Cuff",
				size = 1.372,
				core = 8,
				stand = { shape = "Block", size = { 1.2, 0.22, 1.2 }, color = { 120, 122, 128 } },
				mount = "Right Arm",
				at = { { p = { 0, -0.75, 0 } }, { r = { 0, 180, 0 } } },
			},
		},
	},

	-- What else a clip is (Shared/EmoteInfo, Shared/EmotePolicy):
	--   lowBody    its legs are the point (a collapse, a crouch, a leap): never while seated at a meeting
	--   cinematic  its owner sees it as a private cutscene (in the lobby)
	--   fx         how strong its effects are, 0..4, when its rarity's default is not right
	--   loud       its sound would carry over a case: kept quiet there
	--   context    a press-to-do moment: { label = "LOOK UP", from = s, to = s, branch = clip } (the button shows
	--              between from and to; one press plays the branch, the same on every screen)
	--   formation  a group dance's places for those who join in: { { x, z }, ... } studs round the first dancer
	--              (x to their right, z behind them), at most 5
	lowBattery = { lowBody = true },
	footScratch = { lowBody = true },
	hairTwirl = { lowBody = true },
	goalCelebration = { lowBody = true },
	aceCrouch = { lowBody = true },
	takeTheL = { lowBody = true },
	newWorld = { cinematic = true, fx = 4 },
	finalBreakdown = { cinematic = true, fx = 4 },
	reapersEyes = { cinematic = true, fx = 4 },
	justAsPlanned = { cinematic = true, fx = 4 },
}
