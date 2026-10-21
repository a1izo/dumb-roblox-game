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

local RACKET = {
	model = "Racket",
	-- (the Core v10 racket, its handle long enough for a whole fist; the head as big as before)
	size = 2.54,
	core = 10,
	stand = { shape = "Block", size = { 0.8, 2.1, 0.08 }, color = { 150, 112, 72 } },
	mount = "Right Arm",
	at = { { p = { 0, -1.95, 0 } }, { r = { 180, -62.22, 0 } } }, -- hold: matchPointServe/Racket
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
				hide = 1.02,
			},
			-- bitten at the crunch, shown as it comes away from the mouth (the Core v10 mesh; the plain apple on an older import), the bite turned out
			-- to the right where it shows
			{
				model = "AppleBitten",
				size = 0.8,
				core = 10,
				fallback = "Apple",
				stand = { shape = "Ball", size = { 0.7, 0.7, 0.7 }, color = { 150, 20, 26 } },
				mount = "Right Arm",
				at = { { p = { 0.044, -1.203, -0.178 } }, { r = { 88.5, 83.38, -178.81 } } }, -- hold: appleBite/AppleBitten
				show = 1.02,
			},
		},
		-- the crunch: the head lunges into the apple (touching the lips, its middle is about its radius from the mouth)
		contacts = { { at = 0.95, prop = 1, to = "mouth", within = 0.45 } },
		allow = {
			{ prop = 1, part = "Head", from = 0.83, to = 1.05 },
			{ prop = 2, part = "Head", from = 1.0, to = 1.08 },
		},
	},
	-- LOOK UP, any time in the swagger: the face tipped back to the sky with the grin (the meme's panel)
	excuseMeSir = { context = { label = "LOOK UP", from = 0, to = 1.6, branch = "excuseMeSirUp" } },
	-- NEXT POSE, any time: the three JoJo poses round and round (the second and third are not items: their effect
	-- is the first one's, Sealed)
	menacingPose = { context = { label = "NEXT POSE", from = 0, to = 4, branch = "menacingPose2" } },
	menacingPose2 = { fx = 2, context = { label = "NEXT POSE", from = 0, to = 4, branch = "menacingPose3" } },
	menacingPose3 = { fx = 2, context = { label = "NEXT POSE", from = 0, to = 4, branch = "menacingPose" } },
	lowBatteryCharge = { fx = 1 },
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
	-- LIFT, any time: the blindfold pushed up into the hair, the eyes open
	blindfoldLift = {
		props = {
			{
				model = "Blindfold",
				size = 1.5,
				stand = { shape = "Block", size = { 1.3, 0.3, 1.3 }, color = { 14, 14, 16 } },
				mount = "Head",
				at = { { p = { 0, 0.04, 0 } } },
			},
		},
		context = { label = "LIFT", from = 0, to = 4, branch = "blindfoldLiftUp" },
	},
	blindfoldLiftUp = {
		fx = 2,
		props = {
			{
				model = "Blindfold",
				size = 1.5,
				stand = { shape = "Block", size = { 1.3, 0.3, 1.3 }, color = { 14, 14, 16 } },
				mount = "Head",
				at = { { p = { 0, 0.04, 0 } } },
				-- pushed up into the hair by two fingers
				moves = {
					{
						at = 0.7,
						to = { { p = { 0, 0.5, 0.08 } }, { r = { -14, 0, 0 } } },
					},
				},
			},
		},
		-- the fingers at it as they push it up
		allow = { { prop = 1, part = "Right Arm", from = 0.35, to = 1.55 } },
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
	-- L's tower: cube after cube off the pile by the right hip, carried, set on the tower beside the right knee;
	-- ADD ONE pushes his luck (one time in two it comes down)
	sugarTowerAdd = {
		fx = 2,
		props = {
			{
				model = "SugarCube",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 240, 238, 232 } },
				mount = "floor",
				at = { { p = { 1.45, 0, -0.7 } } },
				stack = {
					step = { { p = { 0, 0.42, 0 } }, { r = { 0, 7, 0 } } },
					times = { 0, 0, 0, 0, 0, 1.3 },
					carry = { mount = "Right Arm", at = { { p = { 0, -1.15, -0.05 } } }, lead = 0.5 },
				},
			},
			-- the pile it is taken from, by the right hip
			{
				model = "SugarCube",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 240, 238, 232 } },
				mount = "floor",
				at = { { p = { 1.75, 0, 0.05 } } },
				stack = { step = { { p = { 0, 0.42, 0 } }, { r = { 0, 31, 0 } } }, times = { 0, 0 } },
			},
		},
		allow = {
			{ prop = 1, part = "Right Arm", from = 0, to = 3.4 },
			{ prop = 2, part = "Right Arm", from = 0, to = 3.4 },
		},
	},
	sugarTowerTopple = {
		fx = 2,
		props = {
			{
				model = "SugarCube",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 240, 238, 232 } },
				mount = "floor",
				at = { { p = { 1.45, 0, -0.7 } } },
				stack = {
					step = { { p = { 0, 0.42, 0 } }, { r = { 0, 7, 0 } } },
					times = { 0, 0, 0, 0, 0, 1.3 },
					carry = { mount = "Right Arm", at = { { p = { 0, -1.15, -0.05 } } }, lead = 0.5 },
					topple = 1.6,
				},
			},
			-- the pile it is taken from, by the right hip
			{
				model = "SugarCube",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 240, 238, 232 } },
				mount = "floor",
				at = { { p = { 1.75, 0, 0.05 } } },
				stack = { step = { { p = { 0, 0.42, 0 } }, { r = { 0, 31, 0 } } }, times = { 0, 0 } },
			},
		},
		allow = {
			{ prop = 1, part = "Right Arm", from = 0, to = 3.4 },
			{ prop = 2, part = "Right Arm", from = 0, to = 3.4 },
		},
	},
	sugarTower = {
		props = {
			{
				model = "SugarCube",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 240, 238, 232 } },
				mount = "floor",
				at = { { p = { 1.45, 0, -0.7 } } },
				stack = {
					step = { { p = { 0, 0.42, 0 } }, { r = { 0, 7, 0 } } },
					times = { 1.0, 1.8, 2.6, 3.4, 4.6 },
					carry = { mount = "Right Arm", at = { { p = { 0, -1.15, -0.05 } } }, lead = 0.5 },
				},
			},
			-- the pile it is taken from, by the right hip
			{
				model = "SugarCube",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 240, 238, 232 } },
				mount = "floor",
				at = { { p = { 1.75, 0, 0.05 } } },
				stack = { step = { { p = { 0, 0.42, 0 } }, { r = { 0, 31, 0 } } }, times = { 0, 0 } },
			},
		},
		context = {
			label = "ADD ONE",
			from = 4.8,
			to = 6,
			branch = "sugarTowerAdd",
			alt = "sugarTowerTopple",
			altChance = 0.5,
		},
		-- (the fist rests on the pile as it takes a cube)
		-- (the fist at the pile and on the tower's top as it sets each one)
		allow = {
			{ prop = 1, part = "Right Arm", from = 0, to = 6 },
			{ prop = 2, part = "Right Arm", from = 0, to = 6 },
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
	-- WRITE IT: the last name written huge and slashed across
	furiousScribbling = {
		props = {
			-- Death's Manual held open on the left hand (opened by the game), tilted up to his face
			{
				model = "Grimoire",
				size = 1.7,
				open = 0,
				stand = { shape = "Block", size = { 1.6, 0.14, 1.2 }, color = { 22, 22, 26 } },
				mount = "Left Arm",
				at = { { p = { 0.147, -0.898, -0.538 } }, { r = { -27.52, 13.58, -24.27 } } }, -- hold: furiousScribbling/Grimoire
			},
			{
				model = "Pen",
				size = 1.07,
				stand = { shape = "Cylinder", size = { 0.9, 0.09, 0.09 }, color = { 14, 14, 16 } },
				mount = "Right Arm",
				at = { { p = { 0.059, -1.196, 0.07 } }, { r = { -28.17, -34.21, 36.39 } } }, -- hold: furiousScribbling/Pen
			},
		},
		context = { label = "WRITE IT", from = 0, to = 2.4, branch = "furiousScribblingSlash" },
		-- the pen's tip on the page, the left hand under the book
		allow = {
			{ prop = 1, part = "Left Arm", from = 0, to = 2.4 },
			{ prop = 1, part = "Right Arm", from = 0, to = 2.4 },
			{ prop = 2, part = "Right Arm", from = 0, to = 2.4 },
		},
	},
	furiousScribblingSlash = {
		props = {
			-- Death's Manual held open on the left hand (opened by the game), tilted up to his face
			{
				model = "Grimoire",
				size = 1.7,
				open = 0,
				hide = 1.7,
				stand = { shape = "Block", size = { 1.6, 0.14, 1.2 }, color = { 22, 22, 26 } },
				mount = "Left Arm",
				at = { { p = { 0.147, -0.898, -0.538 } }, { r = { -27.52, 13.58, -24.27 } } }, -- hold: furiousScribbling/Grimoire2
			},
			{
				model = "Pen",
				size = 1.07,
				stand = { shape = "Cylinder", size = { 0.9, 0.09, 0.09 }, color = { 14, 14, 16 } },
				mount = "Right Arm",
				at = { { p = { 0.059, -1.196, 0.07 } }, { r = { -28.17, -34.21, 36.39 } } }, -- hold: furiousScribbling/Pen2
				hide = 1.7,
			},
		},
		-- (the slash crosses the book over the hand that holds it)
		allow = {
			{ prop = 1, part = "Left Arm", from = 0, to = 2.4 },
			{ prop = 1, part = "Right Arm", from = 0, to = 2.4 },
			{ prop = 2, part = "Right Arm", from = 0, to = 2.4 },
			{ prop = 2, part = "Left Arm", from = 0, to = 1.4 },
		},
	},
	-- TOSS, once it is held out: thrown up over the shoulder to an unseen death god
	appleToss = {
		props = {
			{
				model = "Apple",
				size = 0.8,
				stand = { shape = "Ball", size = { 0.7, 0.7, 0.7 }, color = { 150, 20, 26 } },
				mount = "Right Arm",
				at = { { p = { 0.05, -1.141, -0.222 } }, { r = { -100.6, -15.39, -2.85 } } }, -- hold: appleToss/Apple
				tosses = {
					{ at = 0.5, back = 1.25, height = 3.6, spin = 1 },
					{ at = 1.55, back = 2.3, height = 3.6, spin = 1 },
				},
			},
		},
		context = { label = "TOSS", from = 2.6, to = 3.6, branch = "appleTossThrow" },
	},
	appleTossThrow = {
		fx = 1,
		props = {
			{
				model = "Apple",
				size = 0.8,
				stand = { shape = "Ball", size = { 0.7, 0.7, 0.7 }, color = { 150, 20, 26 } },
				mount = "Right Arm",
				at = { { p = { 0.05, -1.141, -0.222 } }, { r = { -100.6, -15.39, -2.85 } } }, -- hold: appleToss/Apple2
				-- thrown up off the hand at the throw; taken at the top (it never comes back down)
				tosses = { { at = 0.55, back = 1.75, height = 7, spin = 2 } },
				hide = 1.15,
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
				-- on its plate on the left hand, held up level
				at = { { p = { -0.08, -1.322, -0.471 } }, { r = { -89.8, 21.78, -0.08 } } }, -- hold: strawberryOnTop/CakeSlice
			},
			{
				model = "Strawberry",
				size = 0.32,
				stand = { shape = "Ball", size = { 0.3, 0.3, 0.3 }, color = { 190, 30, 36 } },
				mount = "Left Arm",
				at = { { p = { 0.06, -1.376, -1.001 } }, { r = { -89.8, 21.78, -0.08 } } }, -- hold: strawberryOnTop/Strawberry
				-- picked off the top into the right hand's fingertips, then eaten
				moves = {
					{
						at = 0.95,
						mount = "Right Arm",
						to = { { p = { 0, -1.15, -0.12 } } },
					},
				},
				hide = 2.85,
			},
		},
		contacts = { { at = 2.75, prop = 2, to = "mouth", within = 0.45 } },
		allow = {
			{ prop = 1, part = "Right Arm", from = 0.6, to = 1.6 },
			{ prop = 2, part = "Head", from = 2.6, to = 2.9 },
			{ prop = 2, part = "Right Arm", from = 0.8, to = 2.9 },
		},
	},
	-- Near's tower: die after die off the pile by the right hip, carried, set on the tower between his legs;
	-- ADD ONE pushes his luck (one time in two it comes down)
	diceTowerAdd = {
		fx = 2,
		props = {
			{
				model = "Die",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 236, 234, 228 } },
				mount = "floor",
				at = { { p = { -0.05, 0, -1.35 } } },
				stack = {
					step = { { p = { 0, 0.42, 0 } }, { r = { 0, -9, 0 } } },
					times = { 0, 0, 0, 0, 0, 0, 1.3 },
					carry = { mount = "Right Arm", at = { { p = { 0, -1.15, -0.05 } } }, lead = 0.5 },
				},
			},
			-- the pile it is taken from, by the right hip
			{
				model = "Die",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 236, 234, 228 } },
				mount = "floor",
				at = { { p = { 1.75, 0, 0.35 } } },
				stack = { step = { { p = { 0, 0.42, 0 } }, { r = { 0, 31, 0 } } }, times = { 0, 0 } },
			},
		},
		allow = {
			{ prop = 1, part = "Right Arm", from = 0, to = 3.4 },
			{ prop = 2, part = "Right Arm", from = 0, to = 3.4 },
		},
	},
	diceTowerTopple = {
		fx = 2,
		props = {
			{
				model = "Die",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 236, 234, 228 } },
				mount = "floor",
				at = { { p = { -0.05, 0, -1.35 } } },
				stack = {
					step = { { p = { 0, 0.42, 0 } }, { r = { 0, -9, 0 } } },
					times = { 0, 0, 0, 0, 0, 0, 1.3 },
					carry = { mount = "Right Arm", at = { { p = { 0, -1.15, -0.05 } } }, lead = 0.5 },
					topple = 1.6,
				},
			},
			-- the pile it is taken from, by the right hip
			{
				model = "Die",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 236, 234, 228 } },
				mount = "floor",
				at = { { p = { 1.75, 0, 0.35 } } },
				stack = { step = { { p = { 0, 0.42, 0 } }, { r = { 0, 31, 0 } } }, times = { 0, 0 } },
			},
		},
		allow = {
			{ prop = 1, part = "Right Arm", from = 0, to = 3.4 },
			{ prop = 2, part = "Right Arm", from = 0, to = 3.4 },
		},
	},
	diceTower = {
		props = {
			{
				model = "Die",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 236, 234, 228 } },
				mount = "floor",
				at = { { p = { -0.05, 0, -1.35 } } },
				stack = {
					step = { { p = { 0, 0.42, 0 } }, { r = { 0, -9, 0 } } },
					times = { 0.9, 1.6, 2.3, 3.0, 3.7, 4.6 },
					carry = { mount = "Right Arm", at = { { p = { 0, -1.15, -0.05 } } }, lead = 0.5 },
				},
			},
			-- the pile it is taken from, by the right hip
			{
				model = "Die",
				size = 0.42,
				stand = { shape = "Block", size = { 0.42, 0.42, 0.42 }, color = { 236, 234, 228 } },
				mount = "floor",
				at = { { p = { 1.75, 0, 0.35 } } },
				stack = { step = { { p = { 0, 0.42, 0 } }, { r = { 0, 31, 0 } } }, times = { 0, 0 } },
			},
		},
		context = {
			label = "ADD ONE",
			from = 4.8,
			to = 6,
			branch = "diceTowerAdd",
			alt = "diceTowerTopple",
			altChance = 0.5,
		},
		-- (the fist at the pile and on the tower's top as it sets each one)
		allow = {
			{ prop = 1, part = "Right Arm", from = 0, to = 6 },
			{ prop = 2, part = "Right Arm", from = 0, to = 6 },
		},
	},
	chocolateSnap = {
		props = {
			{
				model = "ChocolateBar",
				size = 0.95,
				stand = { shape = "Block", size = { 0.45, 0.95, 0.12 }, color = { 70, 40, 26 } },
				mount = "Right Arm",
				-- upright in the fist up by the mouth
				at = { { p = { 0.122, -1.11, -0.237 } }, { r = { -131.27, -33.4, -25.78 } } }, -- hold: chocolateSnap/ChocolateBar
			},
		},
		contacts = {
			{ at = 0.75, prop = 1, to = "mouth", within = 0.5 },
			{ at = 1.95, prop = 1, to = "mouth", within = 0.5 },
		},
		allow = {
			{ prop = 1, part = "Head", from = 0.6, to = 0.95 },
			{ prop = 1, part = "Head", from = 1.8, to = 2.15 },
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
				-- Over the right shoulder (outside the head's width), pointing back and up, its foot in the raised hand.
				at = { { p = { 1.55, 1.35, 0.55 } }, { r = { 54, 0, -6 } } },
			},
		},
		-- (the stick runs out of the fist over the arm to the shoulder)
		allow = { { prop = 1, part = "Right Arm", from = 0, to = 3 } },
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
	--   cinema     a cinematic one's private cutscene (Presentation/EmoteCinema), timed to the clip:
	--              grade { saturation, contrast, brightness, tint = { r, g, b } } and vignette { color, strength }
	--              for the whole of it; shots: from `at` s into the clip the camera at `eye` looking at `look` (in
	--              the body's own frame as the emote begins, studs: x to its right, y up from its middle, z behind
	--              it), `fov` degrees; a cut, or with `glide` s it eases there from the shot before; `to` (any of
	--              eye, look, fov) it then drifts to until the next shot; `focus` studs kept sharp round `look`.
	--              beats: flash, impact (colour, strength, seconds), shake (strength, seconds) and vignette (on
	--              from then) at `at` s
	-- CHARGE, once slumped on the floor: plugged in, jolted back up
	lowBattery = { lowBody = true, context = { label = "CHARGE", from = 3, to = 4.6, branch = "lowBatteryCharge" } },
	-- the free duos (no shop item): the one asked walks up to face the one asking, and both play it
	highFive = { duo = true, lobbyOnly = true },
	handshake = { duo = true, lobbyOnly = true },
	footScratch = { lowBody = true },
	-- the office trend is danced in rows: up to five join in, two beside the first dancer and three behind
	officeParty = { formation = { { -5, 1 }, { 5, 1 }, { -7.5, 6 }, { 0, 6 }, { 7.5, 6 } } },
	hairTwirl = { lowBody = true },
	goalCelebration = { lowBody = true },
	aceCrouch = { lowBody = true },
	takeTheL = { lowBody = true },
	-- New World: close on the bowed head; from the front-left as the arm rises, tilting up after it; the white flash as it
	-- closes and the view from low in front, up at the fist against the sky; back as it comes down.
	newWorld = {
		cinematic = true,
		fx = 4,
		cinema = {
			grade = { saturation = -0.25, contrast = 0.22, brightness = 0, tint = { 255, 244, 226 } },
			vignette = { color = { 0, 0, 0 }, strength = 0.3 },
			shots = {
				{
					at = 0,
					eye = { 0.5, 0.7, -3.8 },
					look = { 0, 1.35, 0 },
					fov = 34,
					to = { eye = { 0.35, 0.85, -3.1 } },
					focus = 3,
				},
				{
					at = 1.45,
					eye = { -2.6, 0.6, -6.4 },
					look = { 0.2, 0.9, 0 },
					fov = 46,
					to = { eye = { -2.2, 0.4, -5.6 }, look = { 0.4, 1.3, 0 } },
				},
				{
					at = 2.42,
					eye = { 2.6, -1.3, -3.9 },
					look = { 0.6, 1.2, 0 },
					fov = 55,
					to = { eye = { 2, -1.5, -3.3 }, look = { 0.8, 1.6, 0 } },
				},
				{ at = 3.75, glide = 0.6, eye = { -1.2, 1.3, -8.2 }, look = { 0, 1.2, 0 }, fov = 42 },
			},
			beats = {
				{ at = 2.42, kind = "flash", color = { 255, 252, 240 }, strength = 0.85, seconds = 0.7 },
				{ at = 2.42, kind = "shake", strength = 0.08, seconds = 0.3 },
			},
		},
	},
	-- Final Breakdown, Light in the warehouse: low and close on the held-in laugh; very low and wide as he is
	-- thrown back, turning round him; from high in front as he folds over; back.
	finalBreakdown = {
		cinematic = true,
		fx = 4,
		cinema = {
			grade = { saturation = -0.5, contrast = 0.25, brightness = -0.04, tint = { 236, 238, 214 } },
			vignette = { color = { 0, 0, 0 }, strength = 0.38 },
			shots = {
				{
					at = 0,
					eye = { 1.4, -0.9, -5.4 },
					look = { 0.1, 0.6, -0.5 },
					fov = 40,
					to = { eye = { 1.1, -0.8, -4.5 } },
					focus = 4,
				},
				{
					at = 2.2,
					eye = { 0, -2, -5.6 },
					look = { 0, 1.6, 0 },
					fov = 54,
					to = { eye = { 2.4, -1.9, -5 } },
				},
				{
					at = 3.95,
					eye = { 2.5, 6, -4.5 },
					look = { 0, 0, -0.6 },
					fov = 44,
					to = { eye = { 2.2, 6.6, -4 } },
				},
				{ at = 4.85, glide = 0.5, eye = { -1.6, 1, -6.4 }, look = { 0, 1, 0 }, fov = 40 },
			},
			beats = {
				{ at = 2.25, kind = "impact", color = { 235, 232, 220 }, strength = 0.45, seconds = 0.25 },
				{ at = 2.25, kind = "shake", strength = 0.14, seconds = 0.5 },
				{ at = 4.2, kind = "flash", color = { 0, 0, 0 }, strength = 0.35, seconds = 0.4 },
			},
		},
	},
	-- Reaper's Eyes: pushing in as the head turns round under the hand; the red reveal right on the eyes; back.
	reapersEyes = {
		cinematic = true,
		fx = 4,
		cinema = {
			grade = { saturation = -0.6, contrast = 0.25, brightness = -0.05, tint = { 222, 226, 240 } },
			vignette = { color = { 0, 0, 0 }, strength = 0.35 },
			shots = {
				{
					at = 0,
					eye = { -0.7, 1.4, -6.2 },
					look = { 0, 1.35, 0 },
					fov = 38,
					to = { eye = { -0.35, 1.5, -3.4 }, fov = 34 },
				},
				{
					at = 1.75,
					eye = { 0, 1.45, -3.2 },
					look = { 0, 1.4, -0.3 },
					fov = 30,
					to = { eye = { 0, 1.45, -2.8 } },
					focus = 2,
				},
				{ at = 2.8, glide = 0.5, eye = { 0, 1.2, -6.5 }, look = { 0, 1.2, 0 }, fov = 40 },
			},
			beats = {
				{ at = 1.75, kind = "impact", color = { 163, 25, 47 }, strength = 0.45, seconds = 0.25 },
				{ at = 1.75, kind = "vignette", color = { 120, 12, 24 }, strength = 0.4 },
			},
		},
	},
	-- Just As Planned: the stand; close from the side he turns to for the stare and the glint; from his right as
	-- the hand closes on the plan; under the chin for the grin; wide and low for the laugh, pulling back; the tie; close
	-- over the left shoulder for the last look; wider as he comes to rest.
	justAsPlanned = {
		cinematic = true,
		fx = 4,
		cinema = {
			grade = { saturation = -0.35, contrast = 0.2, brightness = -0.03, tint = { 232, 226, 226 } },
			vignette = { color = { 0, 0, 0 }, strength = 0.32 },
			shots = {
				{
					at = 0,
					eye = { -3.2, 1.4, -7.5 },
					look = { 0, 1, 0 },
					fov = 40,
					to = { eye = { -2.4, 1.5, -5.8 }, look = { 0, 1.2, 0 } },
				},
				{
					at = 1.95,
					eye = { 3.2, 1.7, -3.2 },
					look = { 0, 1.45, 0 },
					fov = 34,
					to = { eye = { 2.8, 1.65, -2.8 } },
					focus = 3,
				},
				{ at = 2.95, eye = { 3.8, 1.3, -1.6 }, look = { 0.4, 1, -0.7 }, fov = 40 },
				{
					at = 3.85,
					eye = { 0.25, 0.1, -3.8 },
					look = { 0, 1.45, 0 },
					fov = 34,
					to = { eye = { 0.2, 0.25, -3.2 } },
					focus = 3,
				},
				{
					at = 4.92,
					eye = { 0, -1.5, -7.5 },
					look = { 0, 1, 0 },
					fov = 46,
					to = { eye = { -1.2, -0.9, -9.5 } },
				},
				{ at = 6.6, eye = { -1.4, 1.1, -5.6 }, look = { 0, 1, 0 }, fov = 38 },
				{
					at = 7.55,
					eye = { -3.2, 1.75, -3 },
					look = { 0, 1.45, 0 },
					fov = 34,
					to = { eye = { -2.8, 1.7, -2.6 } },
					focus = 3,
				},
				{ at = 8.6, glide = 0.6, eye = { -0.8, 1.2, -7.5 }, look = { 0, 1, 0 }, fov = 42 },
			},
			beats = {
				{ at = 2.05, kind = "flash", color = { 163, 25, 47 }, strength = 0.22, seconds = 0.35 },
				{ at = 3.55, kind = "impact", color = { 10, 10, 12 }, strength = 0.35, seconds = 0.18 },
				{ at = 4.95, kind = "impact", color = { 163, 25, 47 }, strength = 0.5, seconds = 0.3 },
				{ at = 4.95, kind = "shake", strength = 0.12, seconds = 0.45 },
				{ at = 7.75, kind = "flash", color = { 163, 25, 47 }, strength = 0.22, seconds = 0.35 },
			},
		},
	},
}
