--!strict
-- The paid win cutscenes (shop overhaul, 2026-10-21; the owner's Q35): four small sets each built on every screen that
-- plays them (Presentation/WinCinema), starring a copy of the winner, 8 seconds each. Plain data, so the art scripts
-- read it too (art/scripts/review_win.py renders a set through its shots): numbers, strings, booleans and tables only.
--
-- Everything is in the star's floor frame: x to its right, y up, z behind it; the star's mark is the origin, facing -z.
-- What the star does is its clip (art/scripts/emotes/wins.py); what it holds is the clip's EmoteMeta props.
--
--   side      "coven" or "bureau" (the cosmetic's side: Cosmetics kind "win")
--   clip      the star's clip; length: seconds
--   grade     the screen's colour while it plays (saturation, contrast, brightness, tint)
--   vignette  its strength and colour
--   props     Core models: key, at (their pivot), turn (degrees about y), size (the biggest side; the model is scaled
--             to it), name (for the events), color (a stand-in's, until the import has the model), stand (dressing
--             for the stand-in room only)
--   room      the cut's room in the cutscene sets (art/scripts/maps/venues/sets: name, at = its mark's x and z there):
--             where it is built (a case's map is loaded) the cut plays in it; elsewhere (the lobby's shop) on its parts
--   parts     plain parts: name, shape (Block, Cylinder: along x, Ball), size, at (the middle), rot (degrees, x y z),
--             color, material, alpha (transparency), glow (Neon), light ({ color, range, brightness }), emit (an
--             effect: "flame", "rain", "fog", "dust"), text ({ text, face, color, size }) on a face of it, hidden,
--             stand (a stand-in for the room: walls, a floor, built only where the room is not)
--   city      the skyline below a roof: rows of buildings with lit windows (WinCinema.city, review_win.py city)
--   board     a chessboard: middle, squares across, square size, the two colours
--   shots     the camera, as EmoteCinema's: at, eye, look, fov, glide (seconds of easing from the shot before), to
--   beats     screen beats: flash, impact (color, strength, seconds), shake (strength, seconds)
--   events    what happens on the set and when: at, act, and the act's own fields (WinCinema.ACTS)
--   sounds    cue slots at times (Shared/EmoteMedia.CUES style: the ids are the owner's)

return {
	-- The Coven's Sealed one: a desk by a tall rain-streaked window at night. The last name is written, the Manual
	-- snaps shut, the candles bend towards the writer and go out one by one; a silhouette in a lightning flash.
	finalPage = {
		side = "coven",
		clip = "winFinalPage",
		length = 8,
		room = { name = "writer", at = { 0, 70 } },
		grade = { saturation = -0.35, contrast = 0.12, brightness = -0.02, tint = { 208, 214, 236 } },
		vignette = { strength = 0.55 },
		props = {
			-- (stand-ins: the room has its own books, a sofa and a plant where it is not built)
			{
				key = "Bookshelf",
				stand = true,
				at = { -7.35, 0, -3.2 },
				turn = -90,
				size = 8.1,
				color = { 60, 42, 30 },
			},
			{ key = "Bookshelf", stand = true, at = { -7.35, 0, 1.4 }, turn = -90, size = 8.1, color = { 60, 42, 30 } },
			{ key = "Bookshelf", stand = true, at = { 7.35, 0, -3.2 }, turn = 90, size = 8.1, color = { 60, 42, 30 } },
			{ key = "Bookshelf", stand = true, at = { 7.35, 0, 1.4 }, turn = 90, size = 8.1, color = { 60, 42, 30 } },
			{ key = "Sofa", stand = true, at = { 0, 0, 6.4 }, size = 7.4, color = { 70, 30, 30 } },
			{ key = "Plant", stand = true, at = { -6.4, 0, 6.2 }, size = 4, color = { 40, 70, 40 } },
			{ key = "Table", at = { 0, 0, -2.05 }, size = 5, color = { 72, 50, 32 } },
			{ key = "Chair", at = { 0, 0, 1.4 }, size = 3.9, color = { 82, 45, 32 } },
			-- Death's Manual lies open on the table (closed by the "close" event)
			{
				key = "Grimoire",
				name = "Manual",
				at = { 0.25, 2.965, -2.05 },
				size = 3.0,
				open = true,
				color = { 22, 22, 26 },
			},
			{
				key = "Pen",
				name = "PenDown",
				at = { 0.85, 2.8, -1.65 },
				turn = 70,
				size = 0.9,
				hidden = true,
				color = { 14, 14, 16 },
			},
		},
		parts = {
			{
				name = "Floor",
				stand = true,
				size = { 18, 0.5, 18 },
				at = { 0, -0.25, -1 },
				color = { 38, 29, 23 },
				material = "WoodPlanks",
			},
			{
				name = "BackWall",
				stand = true,
				size = { 18, 13, 0.5 },
				at = { 0, 6.5, 8.2 },
				color = { 30, 29, 33 },
				material = "Plaster",
			},
			{
				name = "LeftWall",
				stand = true,
				size = { 0.5, 13, 18 },
				at = { -8.5, 6.5, -1 },
				color = { 32, 31, 35 },
				material = "Plaster",
			},
			{
				name = "RightWall",
				stand = true,
				size = { 0.5, 13, 18 },
				at = { 8.5, 6.5, -1 },
				color = { 32, 31, 35 },
				material = "Plaster",
			},
			-- the window wall: a tall window in the middle, its glass running with rain
			{
				stand = true,
				size = { 6.3, 13, 0.5 },
				at = { -5.35, 6.5, -6.5 },
				color = { 34, 32, 36 },
				material = "Plaster",
			},
			{
				stand = true,
				size = { 6.3, 13, 0.5 },
				at = { 5.35, 6.5, -6.5 },
				color = { 34, 32, 36 },
				material = "Plaster",
			},
			{
				stand = true,
				size = { 4.4, 2.4, 0.5 },
				at = { 0, 1.2, -6.5 },
				color = { 34, 32, 36 },
				material = "Plaster",
			},
			{
				stand = true,
				size = { 4.4, 3.6, 0.5 },
				at = { 0, 11.2, -6.5 },
				color = { 34, 32, 36 },
				material = "Plaster",
			},
			{
				stand = true,
				size = { 4.6, 0.3, 0.7 },
				at = { 0, 2.35, -6.4 },
				color = { 22, 20, 20 },
				material = "Wood",
			},
			{ stand = true, size = { 0.22, 7, 0.3 }, at = { 0, 5.9, -6.5 }, color = { 22, 20, 20 }, material = "Wood" },
			{
				stand = true,
				size = { 4.4, 0.22, 0.3 },
				at = { 0, 6.4, -6.5 },
				color = { 22, 20, 20 },
				material = "Wood",
			},
			{
				name = "Glass",
				stand = true,
				size = { 4.4, 7, 0.08 },
				at = { 0, 5.9, -6.45 },
				color = { 70, 84, 104 },
				material = "Glass",
				alpha = 0.55,
			},
			{ name = "Rain", stand = true, size = { 4.4, 0.2, 0.2 }, at = { 0, 9.5, -6.75 }, alpha = 1, emit = "rain" },
			-- the night outside, lit by the lightning ("flash" events)
			{ name = "Sky", size = { 40, 30, 1 }, at = { 0, 8, -16 }, color = { 16, 20, 34 }, glow = true },
			{
				name = "Lightning",
				size = { 1, 1, 1 },
				at = { 0, 12, -10 },
				alpha = 1,
				light = { color = { 210, 220, 255 }, range = 40, brightness = 0 },
			},
			-- three candles on the table's far side; their flames bend towards the writer and go out
			{
				name = "Candle1",
				shape = "Cylinder",
				size = { 0.9, 0.3, 0.3 },
				rot = { 0, 0, 90 },
				at = { -1.9, 3.2, -3.1 },
				color = { 226, 214, 188 },
				material = "SmoothPlastic",
			},
			{
				name = "Flame1",
				shape = "Ball",
				size = { 0.16, 0.3, 0.16 },
				at = { -1.9, 3.8, -3.1 },
				color = { 255, 196, 120 },
				glow = true,
				light = { color = { 255, 186, 110 }, range = 9, brightness = 1.3 },
				emit = "flame",
			},
			{
				name = "Candle2",
				shape = "Cylinder",
				size = { 0.7, 0.3, 0.3 },
				rot = { 0, 0, 90 },
				at = { 1.6, 3.1, -3.2 },
				color = { 226, 214, 188 },
				material = "SmoothPlastic",
			},
			{
				name = "Flame2",
				shape = "Ball",
				size = { 0.16, 0.3, 0.16 },
				at = { 1.6, 3.6, -3.2 },
				color = { 255, 196, 120 },
				glow = true,
				light = { color = { 255, 186, 110 }, range = 9, brightness = 1.3 },
				emit = "flame",
			},
			{
				name = "Candle3",
				shape = "Cylinder",
				size = { 1.1, 0.3, 0.3 },
				rot = { 0, 0, 90 },
				at = { 2.15, 3.3, -2.2 },
				color = { 226, 214, 188 },
				material = "SmoothPlastic",
			},
			{
				name = "Flame3",
				shape = "Ball",
				size = { 0.16, 0.3, 0.16 },
				at = { 2.15, 4.0, -2.2 },
				color = { 255, 196, 120 },
				glow = true,
				light = { color = { 255, 186, 110 }, range = 9, brightness = 1.3 },
				emit = "flame",
			},
			-- the Manual's pages light the face from below (dimmed when it shuts)
			{
				name = "PageGlow",
				size = { 0.2, 0.2, 0.2 },
				at = { 0.3, 3.4, -2.0 },
				alpha = 1,
				light = { color = { 255, 178, 96 }, range = 6, brightness = 1.1 },
			},
		},
		shots = {
			{
				at = 0,
				eye = { 2.4, 5.8, 0.4 },
				look = { 0.25, 2.9, -2.1 },
				fov = 42,
				to = { eye = { 2.0, 5.5, 0.0 }, fov = 40 },
			},
			{
				at = 2.55,
				eye = { 0.35, 8.2, -1.9 },
				look = { 0.25, 2.9, -2.05 },
				fov = 36,
				to = { eye = { 0.3, 7.6, -1.95 } },
			},
			{
				at = 3.3,
				eye = { 0.6, 3.35, -4.6 },
				look = { 0, 4.55, 0.65 },
				fov = 44,
				to = { eye = { 0.35, 3.7, -3.6 }, fov = 36 },
			},
			{
				at = 5.6,
				eye = { 2.6, 4.3, 5.0 },
				look = { 0, 5.0, -6.5 },
				fov = 52,
				to = { eye = { 3.1, 4.6, 6.5 }, fov = 48 },
			},
		},
		beats = {
			{ at = 3.0, kind = "impact", color = { 20, 16, 24 }, strength = 0.35, seconds = 0.12 },
			{ at = 3.0, kind = "shake", strength = 0.08, seconds = 0.25 },
			{ at = 5.95, kind = "flash", color = { 225, 232, 255 }, strength = 0.55, seconds = 0.3 },
			{ at = 7.25, kind = "flash", color = { 225, 232, 255 }, strength = 0.35, seconds = 0.25 },
		},
		events = {
			{ at = 2.3, act = "show", target = "PenDown" },
			{ at = 2.88, act = "close", target = "Manual", seconds = 0.12 },
			{ at = 3.0, act = "dim", target = "PageGlow", to = 0.35, seconds = 0.4 },
			{ at = 3.4, act = "lean", targets = { "Flame1", "Flame2", "Flame3" }, seconds = 0.8 },
			{ at = 4.0, act = "out", target = "Flame3" },
			{ at = 4.6, act = "out", target = "Flame1" },
			{ at = 5.2, act = "out", target = "Flame2" },
			{
				at = 5.9,
				act = "flash",
				targets = { "Sky", "Lightning" },
				seconds = 0.35,
				brightness = 7,
				color = { 200, 210, 255 },
			},
			{
				at = 7.2,
				act = "flash",
				targets = { "Sky", "Lightning" },
				seconds = 0.3,
				brightness = 5,
				color = { 180, 192, 240 },
			},
		},
		sounds = {
			{ at = 0, slot = "winRain" },
			{ at = 3.0, slot = "winBookShut" },
			{ at = 4.0, slot = "winCandleOut" },
			{ at = 4.6, slot = "winCandleOut" },
			{ at = 5.2, slot = "winCandleOut" },
			{ at = 6.2, slot = "winThunder" },
		},
	},

	-- The Coven's Godhood one: a rooftop over a night city under a red sky. The winner walks to the edge, opens the
	-- Manual and its pages tear loose and spiral round them while the city's lights die block by block; it ends with
	-- the arms spread over the dark city, in Godhood's crimson.
	newWorld = {
		side = "coven",
		clip = "winNewWorld",
		length = 8,
		room = { name = "rooftop", at = { 900, 0 } },
		grade = { saturation = -0.15, contrast = 0.18, brightness = -0.03, tint = { 255, 206, 206 } },
		vignette = { strength = 0.5, color = { 60, 6, 14 } },
		props = {
			-- (stand-ins: crates by the stair hut where the roof is not built)
			{ key = "Crate", stand = true, at = { 14.5, 0, 12.5 }, size = 4, color = { 90, 70, 44 } },
			{ key = "Crate", stand = true, at = { 15.6, 0, 8.2 }, turn = 20, size = 3.2, color = { 90, 70, 44 } },
		},
		parts = {
			{
				name = "Roof",
				stand = true,
				size = { 40, 1, 36 },
				at = { 0, -0.5, -1 },
				color = { 66, 66, 70 },
				material = "Concrete",
			},
			{
				stand = true,
				size = { 40, 1.4, 0.7 },
				at = { 0, 0.7, -6.9 },
				color = { 74, 73, 76 },
				material = "Concrete",
			},
			{
				stand = true,
				size = { 0.7, 1.4, 36 },
				at = { -19.65, 0.7, -1 },
				color = { 74, 73, 76 },
				material = "Concrete",
			},
			{
				stand = true,
				size = { 0.7, 1.4, 36 },
				at = { 19.65, 0.7, -1 },
				color = { 74, 73, 76 },
				material = "Concrete",
			},
			-- a water tank on legs, the radio mast with its red light, the stair hut
			{
				stand = true,
				shape = "Cylinder",
				size = { 5, 4, 4 },
				rot = { 0, 0, 90 },
				at = { -9, 4, 7 },
				color = { 40, 42, 46 },
				material = "Metal",
			},
			{
				stand = true,
				size = { 0.3, 1.5, 0.3 },
				at = { -10.4, 0.75, 5.6 },
				color = { 30, 30, 34 },
				material = "Metal",
			},
			{
				stand = true,
				size = { 0.3, 1.5, 0.3 },
				at = { -7.6, 0.75, 5.6 },
				color = { 30, 30, 34 },
				material = "Metal",
			},
			{
				stand = true,
				size = { 0.3, 1.5, 0.3 },
				at = { -10.4, 0.75, 8.4 },
				color = { 30, 30, 34 },
				material = "Metal",
			},
			{
				stand = true,
				size = { 0.3, 1.5, 0.3 },
				at = { -7.6, 0.75, 8.4 },
				color = { 30, 30, 34 },
				material = "Metal",
			},
			{
				stand = true,
				shape = "Cylinder",
				size = { 14, 0.25, 0.25 },
				rot = { 0, 0, 90 },
				at = { 8, 7, 5 },
				color = { 50, 50, 56 },
				material = "Metal",
			},
			{
				name = "Beacon",
				shape = "Ball",
				size = { 0.4, 0.4, 0.4 },
				at = { 8, 14.1, 5 },
				color = { 190, 20, 34 },
				glow = true,
				light = { color = { 255, 40, 50 }, range = 10, brightness = 1.2 },
			},
			{ stand = true, size = { 5, 7, 4 }, at = { 11, 3.5, 10 }, color = { 54, 54, 58 }, material = "Concrete" },
			-- the red sky behind the city, a glow along its horizon
			{ name = "Sky", size = { 2200, 700, 2 }, at = { 0, 120, -620 }, color = { 54, 6, 12 }, glow = true },
			{ name = "Horizon", size = { 2200, 60, 2 }, at = { 0, -40, -610 }, color = { 120, 18, 30 }, glow = true },
			-- the crimson rim from the sky's side, a cold fill from the roof's
			{
				name = "Rim",
				size = { 1, 1, 1 },
				at = { 0, 7, -10 },
				alpha = 1,
				light = { color = { 255, 60, 70 }, range = 22, brightness = 2.2 },
			},
			{
				name = "Fill",
				size = { 1, 1, 1 },
				at = { 4, 6, 6 },
				alpha = 1,
				light = { color = { 170, 180, 210 }, range = 18, brightness = 0.5 },
			},
		},
		-- the city: rows of buildings from 40 to 240 studs out, their tops from 30 below the roof to 25 above it
		city = { near = 40, far = 240, width = 240, ground = -70, low = 30, high = 95, seed = 7 },
		shots = {
			{
				at = 0,
				eye = { 3.2, 2.4, 8.5 },
				look = { 0, 3.2, -6 },
				fov = 48,
				to = { eye = { 2.0, 2.3, 4.2 }, fov = 46 },
			},
			{
				at = 2.6,
				eye = { 2.6, 1.6, -7.8 },
				look = { 0, 5.2, -4.4 },
				fov = 50,
				to = { eye = { 2.1, 1.7, -7.5 }, fov = 47 },
			},
			{
				at = 3.9,
				eye = { 3.0, 6.6, -1.2 },
				look = { -2, -6, -48 },
				fov = 46,
				to = { eye = { 2.4, 6.8, -2.0 }, fov = 44 },
			},
			{
				at = 6.0,
				eye = { 0.7, 1.1, 2.0 },
				look = { 0, 6.5, -12 },
				fov = 62,
				to = { eye = { 1.4, 2.4, 8.0 }, fov = 54 },
			},
		},
		beats = {
			{ at = 3.1, kind = "flash", color = { 255, 70, 80 }, strength = 0.3, seconds = 0.25 },
			{ at = 6.05, kind = "impact", color = { 163, 25, 47 }, strength = 0.4, seconds = 0.14 },
			{ at = 6.05, kind = "shake", strength = 0.06, seconds = 0.3 },
		},
		events = {
			{ at = 3.1, act = "pages", around = { 0, 4, -4.5 }, count = 26, seconds = 4.6 },
			{ at = 3.6, act = "cityOut", seconds = 2.4 },
		},
		sounds = {
			{ at = 0, slot = "winWind" },
			{ at = 3.1, slot = "winPagesTear" },
			{ at = 3.6, slot = "winCityDie" },
			{ at = 6.0, slot = "winGodhood" },
		},
	},

	-- The Bureau's Sealed one: the Bureau's office at night. Crouched on the chair, the winner watches the evidence
	-- board's strings snap one by one towards a single photo; the stamp slams CLOSED on the case file; a side profile
	-- with a sugar cube at the lip.
	caseClosed = {
		side = "bureau",
		clip = "winCaseClosed",
		length = 8,
		room = { name = "office", at = { 120, 70 } },
		grade = { saturation = -0.3, contrast = 0.1, brightness = -0.02, tint = { 214, 226, 220 } },
		vignette = { strength = 0.5 },
		props = {
			-- (stand-ins: a bookshelf, the second cabinet and a plant where the room is not built)
			{ key = "Bookshelf", stand = true, at = { 7.35, 0, 1.8 }, turn = 90, size = 8.1, color = { 60, 42, 30 } },
			{
				key = "FilingCabinet",
				stand = true,
				at = { 6.6, 0, -6.8 },
				turn = 180,
				size = 5,
				color = { 75, 79, 76 },
			},
			{ key = "Plant", stand = true, at = { -6.4, 0, -5.2 }, size = 3.2, color = { 40, 70, 40 } },
			{ key = "Chair", at = { 0, 0, 0.15 }, size = 3.9, color = { 82, 45, 32 } },
			{ key = "Table", at = { 0, 0, -3.3 }, size = 5, color = { 72, 50, 32 } },
			{ key = "EvidenceBoard", at = { 0, 5.6, -7.9 }, turn = 180, size = 12.6, color = { 72, 54, 43 } },
			{ key = "Teacup", name = "Bowl", at = { 1.55, 2.75, -2.35 }, size = 0.76, color = { 143, 138, 132 } },
			{ key = "SugarCube", at = { 1.5, 2.82, -2.33 }, size = 0.3, color = { 240, 238, 232 } },
			{ key = "SugarCube", at = { 1.63, 2.85, -2.4 }, turn = 30, size = 0.3, color = { 240, 238, 232 } },
			{ key = "FilingCabinet", at = { -6.6, 0, -6.9 }, turn = 180, size = 5, color = { 75, 79, 76 } },
		},
		parts = {
			{
				name = "Floor",
				stand = true,
				size = { 18, 0.5, 18 },
				at = { 0, -0.25, -1 },
				color = { 42, 44, 50 },
				material = "Fabric",
			},
			{
				name = "Wall",
				stand = true,
				size = { 18, 12, 0.5 },
				at = { 0, 6, -8.4 },
				color = { 56, 58, 62 },
				material = "Plaster",
			},
			{
				stand = true,
				size = { 0.5, 12, 18 },
				at = { -8.5, 6, -1 },
				color = { 52, 54, 58 },
				material = "Plaster",
			},
			{ stand = true, size = { 0.5, 12, 18 }, at = { 8.5, 6, -1 }, color = { 52, 54, 58 }, material = "Plaster" },
			{ stand = true, size = { 18, 12, 0.5 }, at = { 0, 6, 8 }, color = { 52, 54, 58 }, material = "Plaster" },
			-- the lamp hanging over the desk
			{
				shape = "Cylinder",
				size = { 0.5, 1.4, 1.4 },
				rot = { 0, 0, 90 },
				at = { 0.4, 7.6, -3.0 },
				color = { 30, 32, 30 },
				material = "Metal",
			},
			{ size = { 0.06, 4.2, 0.06 }, at = { 0.4, 9.9, -3.0 }, color = { 20, 20, 20 } },
			{
				name = "Lamp",
				shape = "Ball",
				size = { 0.5, 0.5, 0.5 },
				at = { 0.4, 7.25, -3.0 },
				color = { 240, 244, 255 },
				glow = true,
				light = { color = { 230, 236, 255 }, range = 13, brightness = 1.3 },
			},
			-- the case file on the desk, and the stamp beside it
			{
				name = "File",
				size = { 2.0, 0.07, 1.5 },
				at = { 0.05, 2.79, -2.5 },
				rot = { 0, -6, 0 },
				color = { 176, 150, 104 },
				material = "SmoothPlastic",
				text = { text = "CLOSED", face = "Top", color = { 168, 22, 34 }, size = 0.42, hidden = true },
			},
			{
				size = { 1.8, 0.03, 1.3 },
				at = { 0.1, 2.83, -2.5 },
				rot = { 0, -3, 0 },
				color = { 226, 222, 210 },
				material = "SmoothPlastic",
			},
			{
				name = "Stamp",
				size = { 0.5, 0.22, 0.34 },
				at = { 0.85, 2.86, -2.25 },
				color = { 30, 26, 24 },
				material = "Wood",
			},
			{
				name = "StampHandle",
				shape = "Cylinder",
				size = { 0.42, 0.14, 0.14 },
				rot = { 0, 0, 90 },
				at = { 0.85, 3.18, -2.25 },
				color = { 54, 34, 22 },
				material = "Wood",
			},
			{
				name = "StampKnob",
				shape = "Ball",
				size = { 0.26, 0.26, 0.26 },
				at = { 0.85, 3.42, -2.25 },
				color = { 54, 34, 22 },
				material = "Wood",
			},
			-- the one photo every string ends at
			{
				name = "Photo",
				size = { 1.2, 1.5, 0.05 },
				at = { 0.6, 6.0, -7.62 },
				color = { 232, 230, 226 },
				material = "SmoothPlastic",
			},
		},
		-- the strings: from pin to pin across the board; each "snap" whips its far end to the photo
		strings = {
			{ from = { -5.2, 8.4, -7.6 }, to = { 3.6, 3.6, -7.6 } },
			{ from = { -4.4, 3.2, -7.6 }, to = { 5.0, 8.2, -7.6 } },
			{ from = { -2.0, 8.9, -7.6 }, to = { -5.4, 4.6, -7.6 } },
			{ from = { 2.6, 9.0, -7.6 }, to = { -1.6, 2.9, -7.6 } },
			{ from = { 5.6, 5.6, -7.6 }, to = { -3.4, 6.3, -7.6 } },
			{ from = { -0.4, 2.8, -7.6 }, to = { 4.4, 2.9, -7.6 } },
			{ from = { 1.2, 9.2, -7.6 }, to = { -5.6, 7.0, -7.6 } },
		},
		shots = {
			{
				at = 0,
				eye = { -2.4, 6.2, 2.6 },
				look = { 0.3, 5.6, -7.6 },
				fov = 46,
				to = { eye = { -2.0, 6.2, 1.8 } },
			},
			{
				at = 2.4,
				eye = { 1.8, 5.9, -3.4 },
				look = { 0, 5.7, -7.6 },
				fov = 42,
				to = { eye = { 1.2, 5.8, -3.9 }, fov = 40 },
			},
			{
				at = 4.4,
				eye = { 0.45, 7.8, -1.9 },
				look = { 0.3, 2.8, -2.45 },
				fov = 36,
				to = { eye = { 0.4, 7.4, -2.0 } },
			},
			{
				at = 5.6,
				eye = { -4.6, 5.2, -1.6 },
				look = { 0, 4.8, 0.1 },
				fov = 34,
				to = { eye = { -4.2, 5.1, -1.5 }, fov = 32 },
			},
		},
		beats = {
			{ at = 4.8, kind = "impact", color = { 255, 255, 255 }, strength = 0.35, seconds = 0.1 },
			{ at = 4.8, kind = "shake", strength = 0.1, seconds = 0.25 },
		},
		events = {
			{ at = 2.5, act = "snap", index = 1, toward = "Photo" },
			{ at = 2.8, act = "snap", index = 2, toward = "Photo" },
			{ at = 3.05, act = "snap", index = 3, toward = "Photo" },
			{ at = 3.3, act = "snap", index = 4, toward = "Photo" },
			{ at = 3.55, act = "snap", index = 5, toward = "Photo" },
			{ at = 3.75, act = "snap", index = 6, toward = "Photo" },
			{ at = 3.95, act = "snap", index = 7, toward = "Photo" },
			-- the stamp: off the desk into the hand, slammed on the file, back on the desk where it struck
			{
				at = 4.45,
				act = "hold",
				targets = { "Stamp", "StampHandle", "StampKnob" },
				part = "Right Arm",
				grip = { 0, -1.3, -0.05 },
			},
			{ at = 4.8, act = "stamp", target = "File" },
			{ at = 5.3, act = "drop", targets = { "Stamp", "StampHandle", "StampKnob" }, place = { 0.1, 2.86, -2.45 } },
		},
		sounds = {
			{ at = 0, slot = "winOfficeHum" },
			{ at = 2.5, slot = "winStringSnap" },
			{ at = 3.05, slot = "winStringSnap" },
			{ at = 3.55, slot = "winStringSnap" },
			{ at = 3.95, slot = "winStringSnap" },
			{ at = 4.8, slot = "winStamp" },
		},
	},

	-- The Bureau's Godhood one: a vast chessboard in fog. The winner walks up to a giant black king and tips it over with
	-- one finger; it falls slowly, shatters into crimson shards, and the white pieces behind light up row by row.
	checkmate = {
		side = "bureau",
		clip = "winCheckmate",
		length = 8,
		room = { name = "hall", at = { 720, 0 } },
		grade = { saturation = -0.4, contrast = 0.22, brightness = -0.02, tint = { 226, 230, 240 } },
		vignette = { strength = 0.45 },
		props = {
			{ key = "ChessKing", name = "King", at = { 0, 0, -9 }, size = 12.5, color = { 23, 24, 21 } },
		},
		parts = {
			{
				name = "Ground",
				stand = true,
				size = { 400, 1, 400 },
				at = { 0, -1.5, -9 },
				color = { 12, 12, 14 },
				material = "SmoothPlastic",
			},
			{ stand = true, size = { 50, 0.6, 1 }, at = { 0, -0.3, 15.5 }, color = { 36, 26, 20 }, material = "Wood" },
			{ stand = true, size = { 50, 0.6, 1 }, at = { 0, -0.3, -33.5 }, color = { 36, 26, 20 }, material = "Wood" },
			{
				stand = true,
				size = { 1, 0.6, 50 },
				at = { -24.5, -0.3, -9 },
				color = { 36, 26, 20 },
				material = "Wood",
			},
			{ stand = true, size = { 1, 0.6, 50 }, at = { 24.5, -0.3, -9 }, color = { 36, 26, 20 }, material = "Wood" },
			{
				name = "Key",
				size = { 1, 1, 1 },
				at = { 0, 30, -6 },
				alpha = 1,
				light = { color = { 220, 228, 255 }, range = 60, brightness = 1.4 },
			},
			{
				name = "KingRim",
				size = { 1, 1, 1 },
				at = { 0, 8, -16 },
				alpha = 1,
				light = { color = { 200, 40, 56 }, range = 18, brightness = 1.0 },
			},
			{ name = "Fog1", size = { 46, 0.2, 10 }, at = { 0, 0.4, 6 }, alpha = 1, emit = "fog" },
			{ name = "Fog2", size = { 46, 0.2, 10 }, at = { 0, 0.4, -10 }, alpha = 1, emit = "fog" },
			{ name = "Fog3", size = { 46, 0.2, 10 }, at = { 0, 0.4, -26 }, alpha = 1, emit = "fog" },
		},
		-- the board: 8 by 8 squares of 6 studs, the star's square near its near edge
		board = { at = { 0, -0.25, -9 }, squares = 8, square = 6, light = { 222, 220, 214 }, dark = { 26, 26, 28 } },
		-- the white pieces behind the star (two rows: they light up in the "glow" events), black ones beyond the king
		pieces = {
			{ kind = "pawn", row = 1, color = "white", z = 6, xs = { -21, -15, -9, -3, 3, 9, 15, 21 } },
			{ kind = "back", row = 2, color = "white", z = 12, xs = { -21, -15, -9, -3, 3, 9, 15, 21 } },
			{ kind = "pawn", color = "black", z = -21, xs = { -21, -15, -9, 9, 15, 21 } },
		},
		shots = {
			{ at = 0, eye = { 0, 2.2, 17 }, look = { 0, 3.4, -1 }, fov = 40, to = { eye = { 0, 2.0, 9.5 } } },
			{ at = 2.0, eye = { 9, 10, -19 }, look = { 0, 3.2, -2.5 }, fov = 44, to = { eye = { 7.5, 9, -18 } } },
			{ at = 3.4, eye = { 5.4, 4.4, -4.8 }, look = { 0.2, 4.2, -4.8 }, fov = 38 },
			{ at = 4.25, eye = { 0.6, 36, -9 }, look = { 0, 0, -9.5 }, fov = 48, to = { eye = { 0.6, 38, -9 } } },
			{
				at = 6.15,
				eye = { 2.6, 0.9, -16 },
				look = { 0, 4.6, -2.6 },
				fov = 56,
				to = { eye = { 2.0, 1.1, -13.5 }, fov = 52 },
			},
		},
		beats = {
			{ at = 6.0, kind = "flash", color = { 163, 25, 47 }, strength = 0.5, seconds = 0.3 },
			{ at = 6.0, kind = "impact", color = { 163, 25, 47 }, strength = 0.35, seconds = 0.12 },
			{ at = 6.0, kind = "shake", strength = 0.12, seconds = 0.35 },
		},
		events = {
			{ at = 4.15, act = "tip", target = "King", seconds = 1.85 },
			{ at = 6.0, act = "shatter", target = "King", count = 48, color = { 163, 25, 47 } },
			{ at = 6.3, act = "glow", row = 1 },
			{ at = 6.8, act = "glow", row = 2 },
		},
		sounds = {
			{ at = 0, slot = "winVoid" },
			{ at = 4.15, slot = "winKingFall" },
			{ at = 6.0, slot = "winShatter" },
			{ at = 6.3, slot = "winPiecesLight" },
		},
	},
}
