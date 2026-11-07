--!strict
-- The shop's death scenes (written by art/scripts/cinema/deathcuts.py: do not edit by hand): a Preview for every
-- custom death and death style, starring the player, played by Presentation/WinCinema like the win cutscenes'.
-- The WinCuts format, plus: clipAt (when the star's clip starts) and the death's events: book (Death's Manual,
-- the name written in it: "$name" is the star's), lifeless (the star's life layer off: it is acted to the end),
-- deathFx (a custom death's effect, Presentation/CustomDeaths), fallen (a death style's acting on the fallen body,
-- Presentation/Fallen), card (the cause of death across the screen). Keyed by the cosmetic's id.

return {
	reason_fall = {
		kind = "death",
		item = "reason_fall",
		clip = "deathFall",
		clipAt = 2.7,
		length = 7.1,
		grade = {
			saturation = -0.3,
			contrast = 0.18,
			brightness = -0.04,
			tint = { 210, 216, 236 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 22, 1, 26 },
				at = { 0, -0.5, -4 },
				color = { 34, 33, 38 },
				name = "Floor",
				material = "Marble",
			},
			{
				size = { 22, 16, 1 },
				at = { 0, 8, -17.5 },
				color = { 26, 25, 30 },
				material = "Limestone",
			},
			{
				size = { 22, 16, 1 },
				at = { 0, 8, 9.5 },
				color = { 26, 25, 30 },
				material = "Limestone",
			},
			{
				size = { 1, 16, 26 },
				at = { -11.5, 8, -4 },
				color = { 26, 25, 30 },
				material = "Limestone",
			},
			{
				size = { 1, 16, 26 },
				at = { 11.5, 8, -4 },
				color = { 26, 25, 30 },
				material = "Limestone",
			},
			{
				size = { 24, 1, 28 },
				at = { 0, 16.5, -4 },
				color = { 26, 25, 30 },
				material = "Limestone",
			},
			{
				size = { 2.2, 16, 2.2 },
				at = { -6.5, 8, -9 },
				color = { 46, 44, 50 },
				material = "Marble",
				shape = "Cylinder",
				rot = { 0, 0, 90 },
			},
			{
				size = { 2.2, 16, 2.2 },
				at = { 6.5, 8, -9 },
				color = { 46, 44, 50 },
				material = "Marble",
				shape = "Cylinder",
				rot = { 0, 0, 90 },
			},
			{
				size = { 4, 6, 0.4 },
				at = { 0, 11, -17.2 },
				color = { 150, 170, 200 },
				glow = true,
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 13, -10 },
				color = { 170, 190, 230 },
				name = "Shaft",
				alpha = 1,
				light = {
					color = { 170, 190, 230 },
					range = 24,
					brightness = 2.2,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 4, 4, 6 },
				color = { 120, 120, 150 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 120, 120, 150 },
					range = 14,
					brightness = 0.5,
				},
			},
			{
				size = { 5, 0.05, 9 },
				at = { 0, 0.03, -4 },
				color = { 60, 62, 72 },
				material = "Marble",
				alpha = 0.4,
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.44, 5.13, -8.73 },
				look = { -0.02, 3.83, -0.34 },
				fov = 46,
				to = {
					eye = { 2.9, 4.73, -7.58 },
					fov = 44,
				},
			},
			{
				at = 2.85,
				eye = { 8.04, 1.68, -5.14 },
				look = { -0.03, 2.08, -2.51 },
				fov = 50,
				to = {
					eye = { 4.88, 0.42, -6.88 },
					look = { -0.05, 0.62, -4.68 },
				},
			},
			{
				at = 4.4,
				eye = { 2.25, 5.62, -8.67 },
				look = { -0.05, 0.62, -4.68 },
				fov = 44,
				to = {
					eye = { 2.07, 4.42, -7.59 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "A long fall",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.4,
				act = "deathFx",
				reason = "fall",
				hit = 0.25,
			},
			{
				at = 3.95,
				act = "card",
				kicker = "Cause of death: A long fall",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 3.65,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 4,
				slot = "flatline",
			},
		},
	},
	reason_heart = {
		kind = "death",
		item = "reason_heart",
		clip = "deathHeart",
		clipAt = 2.7,
		length = 7.7,
		grade = {
			saturation = -0.2,
			contrast = 0.2,
			brightness = -0.05,
			tint = { 240, 212, 212 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {
			{
				key = "LampPost",
				at = { -3.2, 0, -2.4 },
				color = { 30, 30, 34 },
				turn = -90,
				size = 12.2,
			},
		},
		parts = {
			{
				size = { 26, 1, 26 },
				at = { 0, -0.5, 0 },
				color = { 22, 22, 26 },
				name = "Floor",
				material = "Asphalt",
			},
			{
				size = { 26, 20, 1 },
				at = { 0, 10, -13.5 },
				color = { 14, 14, 18 },
				material = "Brick",
			},
			{
				size = { 26, 20, 1 },
				at = { 0, 10, 13.5 },
				color = { 14, 14, 18 },
				material = "Brick",
			},
			{
				size = { 1, 20, 26 },
				at = { -13.5, 10, 0 },
				color = { 14, 14, 18 },
				material = "Brick",
			},
			{
				size = { 1, 20, 26 },
				at = { 13.5, 10, 0 },
				color = { 14, 14, 18 },
				material = "Brick",
			},
			{
				size = { 26, 0.4, 3 },
				at = { 0, 0.2, -10 },
				color = { 70, 68, 66 },
				material = "Concrete",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { -2.6, 11, -2 },
				color = { 255, 214, 160 },
				name = "Lamp",
				alpha = 1,
				light = {
					color = { 255, 214, 160 },
					range = 22,
					brightness = 2.4,
				},
			},
			{
				size = { 0.8, 0.6, 0.8 },
				at = { -2.6, 11.2, -2.3 },
				color = { 255, 220, 170 },
				name = "Glow",
				glow = true,
				light = {
					color = { 255, 214, 160 },
					range = 4,
					brightness = 0.5,
				},
			},
			{
				size = { 18, 1, 18 },
				at = { 0, 18, 0 },
				color = { 40, 40, 44 },
				name = "Rain",
				alpha = 1,
				emit = "rain",
			},
			{
				size = { 5, 1.2, 0.2 },
				at = { -8, 6, -11 },
				color = { 220, 40, 60 },
				name = "Sign",
				glow = true,
				light = {
					color = { 220, 40, 60 },
					range = 16,
					brightness = 1.2,
				},
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.16, -8.49 },
				look = { 0, 3.86, -0.1 },
				fov = 46,
				to = {
					eye = { 2.92, 4.76, -7.34 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.45, 4.66, -4.54 },
				look = { 0, 4.46, -0.13 },
				fov = 42,
				to = {
					eye = { 3.74, 4.76, -3.74 },
					look = { -0.23, 3.69, 0.82 },
				},
			},
			{
				at = 4.73,
				eye = { 7.33, 1.87, -1.47 },
				look = { -0.01, 2.27, 0.92 },
				fov = 50,
				to = {
					eye = { 4.91, 0.77, -0.26 },
					look = { -0.02, 0.97, 1.94 },
				},
			},
			{
				at = 6.03,
				eye = { 2.28, 5.97, -2.05 },
				look = { -0.02, 0.97, 1.94 },
				fov = 44,
				to = {
					eye = { 2.1, 4.77, -0.98 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "A broken heart",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.6,
				act = "deathFx",
				reason = "heart",
				hit = 1.68,
			},
			{
				at = 5.58,
				act = "card",
				kicker = "Cause of death: A broken heart",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 5.28,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 5.63,
				slot = "flatline",
			},
		},
	},
	reason_frost = {
		kind = "death",
		item = "reason_frost",
		clip = "deathFrost",
		clipAt = 2.7,
		length = 7.05,
		grade = {
			saturation = -0.25,
			contrast = 0.14,
			brightness = -0.02,
			tint = { 214, 232, 246 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 30, 1, 30 },
				at = { 0, -0.5, 0 },
				color = { 220, 228, 236 },
				name = "Floor",
				material = "Snow",
			},
			{
				size = { 30, 22, 1 },
				at = { 0, 11, -15.5 },
				color = { 24, 30, 44 },
				material = "SmoothPlastic",
			},
			{
				size = { 30, 22, 1 },
				at = { 0, 11, 15.5 },
				color = { 24, 30, 44 },
				material = "SmoothPlastic",
			},
			{
				size = { 1, 22, 30 },
				at = { -15.5, 11, 0 },
				color = { 24, 30, 44 },
				material = "SmoothPlastic",
			},
			{
				size = { 1, 22, 30 },
				at = { 15.5, 11, 0 },
				color = { 24, 30, 44 },
				material = "SmoothPlastic",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { -10, 18, -14 },
				color = { 190, 214, 255 },
				name = "Moon",
				alpha = 1,
				light = {
					color = { 190, 214, 255 },
					range = 40,
					brightness = 1.6,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 6, 4, 6 },
				color = { 150, 180, 230 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 150, 180, 230 },
					range = 16,
					brightness = 0.6,
				},
			},
			{
				size = { 16, 1, 16 },
				at = { 0, 0.6, -2 },
				color = { 220, 230, 240 },
				name = "Mist",
				alpha = 1,
				emit = "fog",
			},
			{
				size = { 0.6, 9, 0.6 },
				at = { -7, 4.5, -10 },
				color = { 14, 14, 18 },
				material = "Wood",
			},
			{
				size = { 0.4, 4, 0.4 },
				at = { -6.2, 7, -10 },
				color = { 14, 14, 18 },
				material = "Wood",
				rot = { 0, 0, -35 },
			},
			{
				size = { 0.7, 11, 0.7 },
				at = { 8, 5.5, -12 },
				color = { 14, 14, 18 },
				material = "Wood",
			},
			{
				size = { 0.4, 5, 0.4 },
				at = { 9, 8, -12 },
				color = { 14, 14, 18 },
				material = "Wood",
				rot = { 0, 0, 40 },
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.45, 4.55, -4.88 },
				look = { 0, 4.35, -0.47 },
				fov = 42,
				to = {
					eye = { 3.74, 4.65, -4.08 },
					look = { -0.09, 4.33, -1.48 },
				},
			},
			{
				at = 4.6,
				eye = { 7.81, 2.09, -4.58 },
				look = { -0.03, 2.49, -2.03 },
				fov = 50,
				to = {
					eye = { 4.87, 1.18, -6.25 },
					look = { -0.07, 1.38, -4.05 },
				},
			},
			{
				at = 5.9,
				eye = { 2.23, 6.38, -8.04 },
				look = { -0.07, 1.38, -4.05 },
				fov = 44,
				to = {
					eye = { 2.05, 5.18, -6.97 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Frozen where they stood",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.6,
				act = "deathFx",
				reason = "frost",
				hit = 1.55,
			},
			{
				at = 5.45,
				act = "card",
				kicker = "Cause of death: Frozen where they stood",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 5.15,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 5.5,
				slot = "flatline",
			},
		},
	},
	reason_chandelier = {
		kind = "death",
		item = "reason_chandelier",
		clip = "deathChandelier",
		clipAt = 2.7,
		length = 7.2,
		grade = {
			saturation = -0.15,
			contrast = 0.16,
			brightness = -0.03,
			tint = { 244, 226, 206 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 24, 1, 24 },
				at = { 0, -0.5, 0 },
				color = { 40, 26, 22 },
				name = "Floor",
				material = "Marble",
			},
			{
				size = { 24, 22, 1 },
				at = { 0, 11, -12.5 },
				color = { 52, 36, 30 },
				material = "Wood",
			},
			{
				size = { 24, 22, 1 },
				at = { 0, 11, 12.5 },
				color = { 52, 36, 30 },
				material = "Wood",
			},
			{
				size = { 1, 22, 24 },
				at = { -12.5, 11, 0 },
				color = { 52, 36, 30 },
				material = "Wood",
			},
			{
				size = { 1, 22, 24 },
				at = { 12.5, 11, 0 },
				color = { 52, 36, 30 },
				material = "Wood",
			},
			{
				size = { 26, 1, 26 },
				at = { 0, 22.5, 0 },
				color = { 30, 22, 18 },
				material = "Wood",
			},
			{
				size = { 1.2, 1.6, 1.2 },
				at = { 0, 10.5, -0.4 },
				color = { 200, 160, 70 },
				name = "Ch_body",
				material = "Metal",
				shape = "Ball",
			},
			{
				size = { 0.25, 4.2, 4.2 },
				at = { 0, 10, -0.4 },
				color = { 210, 170, 80 },
				name = "Ch_ring",
				material = "Metal",
				shape = "Cylinder",
				rot = { 0, 0, 90 },
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { 2, 9.55, -0.4 },
				color = { 255, 236, 190 },
				name = "Ch_drop0",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { 1.414, 9.55, 1.014 },
				color = { 255, 236, 190 },
				name = "Ch_drop1",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { 0, 9.55, 1.6 },
				color = { 255, 236, 190 },
				name = "Ch_drop2",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { -1.414, 9.55, 1.014 },
				color = { 255, 236, 190 },
				name = "Ch_drop3",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { -2, 9.55, -0.4 },
				color = { 255, 236, 190 },
				name = "Ch_drop4",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { -1.414, 9.55, -1.814 },
				color = { 255, 236, 190 },
				name = "Ch_drop5",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { -0, 9.55, -2.4 },
				color = { 255, 236, 190 },
				name = "Ch_drop6",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.35, 0.6, 0.35 },
				at = { 1.414, 9.55, -1.814 },
				color = { 255, 236, 190 },
				name = "Ch_drop7",
				shape = "Ball",
				glow = true,
			},
			{
				size = { 0.18, 8, 0.18 },
				at = { 0, 15.1, -0.4 },
				color = { 120, 100, 60 },
				name = "Ch_chain",
				material = "Metal",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 9.3, -0.4 },
				color = { 255, 220, 160 },
				name = "Ch_light",
				alpha = 1,
				light = {
					color = { 255, 220, 160 },
					range = 20,
					brightness = 2.2,
				},
			},
			{
				size = { 0.5, 0.8, 0.5 },
				at = { -11, 7, -6 },
				color = { 255, 210, 150 },
				name = "Sconce1",
				glow = true,
				light = {
					color = { 255, 200, 140 },
					range = 12,
					brightness = 1,
				},
			},
			{
				size = { 0.5, 0.8, 0.5 },
				at = { 11, 7, -6 },
				color = { 255, 210, 150 },
				name = "Sconce2",
				glow = true,
				light = {
					color = { 255, 200, 140 },
					range = 12,
					brightness = 1,
				},
			},
			{
				size = { 24, 4, 0.3 },
				at = { 0, 2, -11.8 },
				color = { 70, 44, 34 },
				material = "Wood",
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
				},
			},
			{
				at = 2.8,
				eye = { 2.68, 1.4, -6.03 },
				look = { 0, 6.2, -0.4 },
				fov = 68,
				to = {
					eye = { 2.05, 1.6, -5.64 },
				},
			},
			{
				at = 3.68,
				eye = { 6.44, 3.57, -3.56 },
				look = { 0, 2.93, -1.25 },
				fov = 50,
				to = {
					eye = { 5.27, 3.17, -3.81 },
					look = { -0.03, 0.57, -1.45 },
				},
			},
			{
				at = 4.55,
				eye = { 2.27, 5.57, -5.44 },
				look = { -0.03, 0.57, -1.45 },
				fov = 44,
				to = {
					eye = { 2.08, 4.37, -4.37 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "A chandelier, from above",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 2.8,
				act = "flash",
				targets = {
					"Ch_light",
				},
				brightness = 3.2,
				seconds = 0.25,
			},
			{
				at = 3.15,
				act = "deathFx",
				reason = "chandelier",
				hit = 0.5,
			},
			{
				at = 3.23,
				act = "fling",
				targets = {
					"Ch_body",
					"Ch_ring",
					"Ch_drop0",
					"Ch_drop1",
					"Ch_drop2",
					"Ch_drop3",
					"Ch_drop4",
					"Ch_drop5",
					"Ch_drop6",
					"Ch_drop7",
					"Ch_light",
				},
				to = { 0, 0.6, -0.9 },
				seconds = 0.42,
				fall = true,
				arc = 0,
				spin = { 0.05, 0.1, 0.03 },
			},
			{
				at = 3.7,
				act = "dim",
				target = "Ch_light",
				to = 0.25,
				seconds = 0.5,
			},
			{
				at = 3.95,
				act = "card",
				kicker = "Cause of death: A chandelier, from above",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 3.65,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 4,
				slot = "flatline",
			},
		},
	},
	reason_drown = {
		kind = "death",
		item = "reason_drown",
		clip = "deathDrown",
		clipAt = 2.7,
		length = 8.1,
		grade = {
			saturation = -0.25,
			contrast = 0.14,
			brightness = -0.02,
			tint = { 214, 232, 246 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 18, 1, 22 },
				at = { 0, -0.5, -2 },
				color = { 150, 186, 196 },
				name = "Floor",
				material = "CeramicTiles",
			},
			{
				size = { 18, 14, 1 },
				at = { 0, 7, -13.5 },
				color = { 120, 160, 172 },
				material = "CeramicTiles",
			},
			{
				size = { 18, 14, 1 },
				at = { 0, 7, 9.5 },
				color = { 120, 160, 172 },
				material = "CeramicTiles",
			},
			{
				size = { 1, 14, 22 },
				at = { -9.5, 7, -2 },
				color = { 120, 160, 172 },
				material = "CeramicTiles",
			},
			{
				size = { 1, 14, 22 },
				at = { 9.5, 7, -2 },
				color = { 120, 160, 172 },
				material = "CeramicTiles",
			},
			{
				size = { 18, 0.3, 0.4 },
				at = { 0, 0.15, -6 },
				color = { 40, 60, 120 },
				material = "CeramicTiles",
			},
			{
				size = { 0.2, 0.2, 22 },
				at = { -4, 0.02, -2 },
				color = { 30, 50, 110 },
				material = "CeramicTiles",
			},
			{
				size = { 0.2, 0.2, 22 },
				at = { 4, 0.02, -2 },
				color = { 30, 50, 110 },
				material = "CeramicTiles",
			},
			{
				size = { 1.6, 1, 0.2 },
				at = { 0, 1.6, -12.7 },
				color = { 150, 220, 255 },
				name = "PoolLight",
				glow = true,
				light = {
					color = { 110, 200, 255 },
					range = 20,
					brightness = 2,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 6, 16, 8 },
				color = { 180, 200, 240 },
				name = "Moon",
				alpha = 1,
				light = {
					color = { 180, 200, 240 },
					range = 30,
					brightness = 0.9,
				},
			},
			{
				size = { 0.25, 6, 0.25 },
				at = { -6.4, 3, -12.6 },
				color = { 200, 204, 210 },
				material = "Metal",
			},
			{
				size = { 0.25, 6, 0.25 },
				at = { -5.2, 3, -12.6 },
				color = { 200, 204, 210 },
				material = "Metal",
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.45, 4.66, -3.8 },
				look = { 0, 4.46, 0.62 },
				fov = 42,
				to = {
					eye = { 3.74, 4.76, -3 },
					look = { 0, 3, 1.18 },
				},
			},
			{
				at = 5.27,
				eye = { 7.42, 1.81, -1.36 },
				look = { 0.01, 2.21, 1.05 },
				fov = 50,
				to = {
					eye = { 4.95, 0.62, -0.1 },
					look = { 0.01, 0.82, 2.09 },
				},
			},
			{
				at = 6.57,
				eye = { 2.31, 5.82, -1.89 },
				look = { 0.01, 0.82, 2.09 },
				fov = 44,
				to = {
					eye = { 2.13, 4.62, -0.82 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Drowned on dry land",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.6,
				act = "deathFx",
				reason = "drown",
				hit = 2.22,
			},
			{
				at = 6.12,
				act = "card",
				kicker = "Cause of death: Drowned on dry land",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 5.82,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 6.17,
				slot = "flatline",
			},
		},
	},
	reason_lightning = {
		kind = "death",
		item = "reason_lightning",
		clip = "deathLightning",
		clipAt = 2.7,
		length = 7.2,
		grade = {
			saturation = -0.3,
			contrast = 0.18,
			brightness = -0.04,
			tint = { 210, 216, 236 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 30, 1, 30 },
				at = { 0, -0.5, 0 },
				color = { 44, 44, 48 },
				name = "Floor",
				material = "Concrete",
			},
			{
				size = { 30, 8, 1 },
				at = { 0, 4, -15.5 },
				color = { 36, 36, 40 },
				material = "Concrete",
			},
			{
				size = { 30, 8, 1 },
				at = { 0, 4, 15.5 },
				color = { 36, 36, 40 },
				material = "Concrete",
			},
			{
				size = { 1, 8, 30 },
				at = { -15.5, 4, 0 },
				color = { 36, 36, 40 },
				material = "Concrete",
			},
			{
				size = { 1, 8, 30 },
				at = { 15.5, 4, 0 },
				color = { 36, 36, 40 },
				material = "Concrete",
			},
			{
				size = { 30, 1.6, 1 },
				at = { 0, 0.8, -12 },
				color = { 60, 60, 64 },
				material = "Concrete",
			},
			{
				size = { 0.3, 12, 0.3 },
				at = { -7, 6, -9 },
				color = { 120, 120, 128 },
				material = "Metal",
			},
			{
				size = { 3.4, 0.2, 0.2 },
				at = { -7, 10.5, -9 },
				color = { 120, 120, 128 },
				material = "Metal",
			},
			{
				size = { 4.2, 5, 4.2 },
				at = { 8, 4.5, -10 },
				color = { 70, 60, 52 },
				material = "WoodPlanks",
				shape = "Cylinder",
				rot = { 0, 0, 90 },
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 22, -6 },
				color = { 150, 170, 220 },
				name = "Sky",
				alpha = 1,
				light = {
					color = { 150, 170, 220 },
					range = 40,
					brightness = 0.8,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { -5, 3, 6 },
				color = { 140, 150, 190 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 140, 150, 190 },
					range = 14,
					brightness = 0.5,
				},
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.29, -8.02 },
				look = { 0, 3.99, 0.37 },
				fov = 46,
				to = {
					eye = { 2.92, 4.89, -6.86 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.45, 4.79, -3.97 },
				look = { 0, 4.59, 0.45 },
				fov = 42,
				to = {
					eye = { 3.74, 4.89, -3.16 },
					look = { -0.04, 4.14, 1.06 },
				},
			},
			{
				at = 3.93,
				eye = { 7.35, 1.82, -1.21 },
				look = { -0.02, 2.22, 1.18 },
				fov = 50,
				to = {
					eye = { 4.9, 0.54, -0.21 },
					look = { -0.03, 0.74, 1.99 },
				},
			},
			{
				at = 5.23,
				eye = { 2.27, 5.74, -1.99 },
				look = { -0.03, 0.74, 1.99 },
				fov = 44,
				to = {
					eye = { 2.08, 4.54, -0.92 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Struck by lightning",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.25,
				act = "deathFx",
				reason = "lightning",
				hit = 1.23,
			},
			{
				at = 4.78,
				act = "card",
				kicker = "Cause of death: Struck by lightning",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 4.48,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 4.83,
				slot = "flatline",
			},
		},
	},
	reason_pages = {
		kind = "death",
		item = "reason_pages",
		clip = "deathPages",
		clipAt = 2.7,
		length = 7.5,
		grade = {
			saturation = -0.15,
			contrast = 0.16,
			brightness = -0.03,
			tint = { 244, 226, 206 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {
			{
				key = "Bookshelf",
				at = { -6.5, 0, -10.6 },
				color = { 60, 50, 40 },
				size = 8.1,
			},
			{
				key = "Bookshelf",
				at = { -3.2, 0, -10.6 },
				color = { 60, 50, 40 },
				size = 8.1,
			},
			{
				key = "Bookshelf",
				at = { 0, 0, -10.6 },
				color = { 60, 50, 40 },
				size = 8.1,
			},
			{
				key = "Bookshelf",
				at = { 3.2, 0, -10.6 },
				color = { 60, 50, 40 },
				size = 8.1,
			},
			{
				key = "Bookshelf",
				at = { 6.5, 0, -10.6 },
				color = { 60, 50, 40 },
				size = 8.1,
			},
			{
				key = "Bookshelf",
				at = { -8.4, 0, -4 },
				color = { 60, 50, 40 },
				turn = -90,
				size = 8.1,
			},
			{
				key = "Bookshelf",
				at = { 8.4, 0, -4 },
				color = { 60, 50, 40 },
				turn = 90,
				size = 8.1,
			},
			{
				key = "Desk",
				at = { 4.2, 0, -7.8 },
				color = { 60, 50, 40 },
				size = 6,
			},
		},
		parts = {
			{
				size = { 18, 1, 20 },
				at = { 0, -0.5, -2 },
				color = { 60, 46, 34 },
				name = "Floor",
				material = "WoodPlanks",
			},
			{
				size = { 18, 12, 1 },
				at = { 0, 6, -12.5 },
				color = { 40, 32, 26 },
				material = "Wood",
			},
			{
				size = { 18, 12, 1 },
				at = { 0, 6, 8.5 },
				color = { 40, 32, 26 },
				material = "Wood",
			},
			{
				size = { 1, 12, 20 },
				at = { -9.5, 6, -2 },
				color = { 40, 32, 26 },
				material = "Wood",
			},
			{
				size = { 1, 12, 20 },
				at = { 9.5, 6, -2 },
				color = { 40, 32, 26 },
				material = "Wood",
			},
			{
				size = { 20, 1, 22 },
				at = { 0, 12.5, -2 },
				color = { 40, 32, 26 },
				material = "Wood",
			},
			{
				size = { 0.6, 0.4, 0.6 },
				at = { 4, 5, -7 },
				color = { 255, 226, 170 },
				name = "Lamp",
				glow = true,
				light = {
					color = { 255, 220, 160 },
					range = 18,
					brightness = 1.6,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { -3, 6, 5 },
				color = { 200, 170, 140 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 200, 170, 140 },
					range = 14,
					brightness = 0.5,
				},
			},
			{
				size = { 1.1, 0.05, 1.5 },
				at = { -2.5, 0.03, -3 },
				color = { 226, 218, 198 },
				rot = { 0, 20, 0 },
			},
			{
				size = { 1.1, 0.05, 1.5 },
				at = { 1.8, 0.03, -4.5 },
				color = { 226, 218, 198 },
				rot = { 0, -35, 0 },
			},
			{
				size = { 1.1, 0.05, 1.5 },
				at = { 3.2, 0.03, 1.5 },
				color = { 226, 218, 198 },
				rot = { 0, 60, 0 },
			},
			{
				size = { 1.1, 0.05, 1.5 },
				at = { -3.4, 0.03, 2.2 },
				color = { 226, 218, 198 },
				rot = { 0, -10, 0 },
			},
			{
				size = { 1.1, 0.05, 1.5 },
				at = { 0.6, 0.03, -6.5 },
				color = { 226, 218, 198 },
				rot = { 0, 80, 0 },
			},
			{
				size = { 1.1, 0.05, 1.5 },
				at = { -1.2, 0.03, 3.8 },
				color = { 226, 218, 198 },
				rot = { 0, 45, 0 },
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.45, 4.7, -4.41 },
				look = { 0, 4.5, 0 },
				fov = 42,
				to = {
					eye = { 3.74, 4.8, -3.61 },
					look = { -0.34, 4.09, 1.44 },
				},
			},
			{
				at = 4.57,
				eye = { 7.28, 1.71, -1.34 },
				look = { -0.23, 2.11, 1.09 },
				fov = 50,
				to = {
					eye = { 4.47, 0.41, -0.01 },
					look = { -0.46, 0.61, 2.19 },
				},
			},
			{
				at = 5.87,
				eye = { 1.84, 5.61, -1.79 },
				look = { -0.46, 0.61, 2.19 },
				fov = 44,
				to = {
					eye = { 1.66, 4.41, -0.72 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "A thousand paper cuts",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3,
				act = "deathFx",
				reason = "pages",
				hit = 2.12,
			},
			{
				at = 5.42,
				act = "card",
				kicker = "Cause of death: A thousand paper cuts",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 5.12,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 5.47,
				slot = "flatline",
			},
		},
	},
	reason_burn = {
		kind = "death",
		item = "reason_burn",
		clip = "deathBurn",
		clipAt = 2.7,
		length = 7.5,
		grade = {
			saturation = -0.15,
			contrast = 0.16,
			brightness = -0.03,
			tint = { 244, 226, 206 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {
			{
				key = "Sofa",
				at = { -5.5, 0, -2 },
				color = { 60, 50, 40 },
				turn = 90,
				size = 7.4,
			},
			{
				key = "Plant",
				at = { 6.5, 0, -8 },
				color = { 60, 50, 40 },
				size = 4,
			},
		},
		parts = {
			{
				size = { 20, 1, 20 },
				at = { 0, -0.5, -2 },
				color = { 54, 34, 28 },
				name = "Floor",
				material = "Carpet",
			},
			{
				size = { 20, 12, 1 },
				at = { 0, 6, -12.5 },
				color = { 34, 24, 22 },
				material = "Plaster",
			},
			{
				size = { 20, 12, 1 },
				at = { 0, 6, 8.5 },
				color = { 34, 24, 22 },
				material = "Plaster",
			},
			{
				size = { 1, 12, 20 },
				at = { -10.5, 6, -2 },
				color = { 34, 24, 22 },
				material = "Plaster",
			},
			{
				size = { 1, 12, 20 },
				at = { 10.5, 6, -2 },
				color = { 34, 24, 22 },
				material = "Plaster",
			},
			{
				size = { 22, 1, 22 },
				at = { 0, 12.5, -2 },
				color = { 34, 24, 22 },
				material = "Plaster",
			},
			{
				size = { 6, 5, 1.6 },
				at = { 0, 2.5, -11.2 },
				color = { 60, 44, 40 },
				material = "Brick",
			},
			{
				size = { 3.2, 2.2, 0.8 },
				at = { 0, 1.3, -10.6 },
				color = { 20, 12, 10 },
				name = "Hearth",
				emit = "fire",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 1.8, -9.6 },
				color = { 255, 140, 60 },
				name = "FireLight",
				alpha = 1,
				light = {
					color = { 255, 140, 60 },
					range = 18,
					brightness = 1.4,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 5, 6, 4 },
				color = { 160, 120, 110 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 160, 120, 110 },
					range = 14,
					brightness = 0.4,
				},
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.45, 4.08, -5.75 },
				look = { 0, 3.88, -1.33 },
				fov = 42,
				to = {
					eye = { 3.74, 4.18, -4.94 },
					look = { -0.13, 4.22, -1.31 },
				},
			},
			{
				at = 4.54,
				eye = { 7.36, 1.7, -3.2 },
				look = { -0.02, 2.1, -0.8 },
				fov = 50,
				to = {
					eye = { 4.88, 0.4, -3.81 },
					look = { -0.05, 0.6, -1.61 },
				},
			},
			{
				at = 5.83,
				eye = { 2.25, 5.6, -5.59 },
				look = { -0.05, 0.6, -1.61 },
				fov = 44,
				to = {
					eye = { 2.07, 4.4, -4.52 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Burned from within",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.15,
				act = "deathFx",
				reason = "burn",
				hit = 1.93,
			},
			{
				at = 3.15,
				act = "ignite",
				targets = {
					"Hearth",
				},
				scale = 1.6,
				flare = true,
			},
			{
				at = 3.15,
				act = "flash",
				targets = {
					"FireLight",
				},
				brightness = 4,
				seconds = 1.2,
			},
			{
				at = 5.38,
				act = "card",
				kicker = "Cause of death: Burned from within",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 5.08,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 5.43,
				slot = "flatline",
			},
		},
	},
	reason_chip = {
		kind = "death",
		item = "reason_chip",
		clip = "deathChip",
		clipAt = 2.7,
		length = 7.7,
		grade = {
			saturation = -0.3,
			contrast = 0.18,
			brightness = -0.04,
			tint = { 210, 216, 236 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {
			{
				key = "Desk",
				at = { 1.6, 0, -6.2 },
				color = { 60, 50, 40 },
				size = 6,
			},
			{
				key = "CRTTelevision",
				at = { -2.6, 0, -7 },
				color = { 60, 50, 40 },
				size = 4.2,
			},
			{
				key = "ChipBag",
				at = { 2.4, 4.58, -6 },
				color = { 60, 50, 40 },
				turn = 20,
				size = 1.3,
			},
			{
				key = "ChairOffice",
				at = { 1.2, 0, -3.6 },
				color = { 60, 50, 40 },
				turn = 180,
				size = 5.3,
			},
		},
		parts = {
			{
				size = { 18, 1, 18 },
				at = { 0, -0.5, -2 },
				color = { 52, 50, 56 },
				name = "Floor",
				material = "Carpet",
			},
			{
				size = { 18, 11, 1 },
				at = { 0, 5.5, -11.5 },
				color = { 40, 44, 52 },
				material = "Plaster",
			},
			{
				size = { 18, 11, 1 },
				at = { 0, 5.5, 7.5 },
				color = { 40, 44, 52 },
				material = "Plaster",
			},
			{
				size = { 1, 11, 18 },
				at = { -9.5, 5.5, -2 },
				color = { 40, 44, 52 },
				material = "Plaster",
			},
			{
				size = { 1, 11, 18 },
				at = { 9.5, 5.5, -2 },
				color = { 40, 44, 52 },
				material = "Plaster",
			},
			{
				size = { 20, 1, 20 },
				at = { 0, 11.5, -2 },
				color = { 40, 44, 52 },
				material = "Plaster",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { -2.6, 4.2, -6.4 },
				color = { 150, 190, 255 },
				name = "TV",
				alpha = 1,
				light = {
					color = { 150, 190, 255 },
					range = 16,
					brightness = 1.6,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 3.4, 5, -5.2 },
				color = { 255, 226, 170 },
				name = "Desk",
				alpha = 1,
				light = {
					color = { 255, 226, 170 },
					range = 10,
					brightness = 0.8,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 4, 6, 6 },
				color = { 130, 130, 160 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 130, 130, 160 },
					range = 14,
					brightness = 0.4,
				},
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.45, 5.2, -8.32 },
				look = { -0.01, 3.9, 0.07 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.16 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.44, 4.7, -4.32 },
				look = { -0.01, 4.5, 0.1 },
				fov = 42,
				to = {
					eye = { 3.73, 4.8, -3.52 },
					look = { -0.09, 3.85, 1.11 },
				},
			},
			{
				at = 4.83,
				eye = { 7.51, 1.84, -1.1 },
				look = { 0.01, 2.24, 1.33 },
				fov = 50,
				to = {
					eye = { 4.95, 0.67, 0.4 },
					look = { 0.02, 0.87, 2.59 },
				},
			},
			{
				at = 6.13,
				eye = { 2.32, 5.87, -1.39 },
				look = { 0.02, 0.87, 2.59 },
				fov = 44,
				to = {
					eye = { 2.14, 4.67, -0.32 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Choked on a potato chip",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.32,
				act = "deathFx",
				reason = "chip",
				hit = 2.06,
			},
			{
				at = 5.68,
				act = "card",
				kicker = "Cause of death: Choked on a potato chip",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 5.38,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 5.73,
				slot = "flatline",
			},
		},
	},
	reason_clock = {
		kind = "death",
		item = "reason_clock",
		clip = "deathClock",
		clipAt = 2.7,
		length = 7.65,
		grade = {
			saturation = -0.15,
			contrast = 0.16,
			brightness = -0.03,
			tint = { 244, 226, 206 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 18, 1, 20 },
				at = { 0, -0.5, -2 },
				color = { 44, 36, 30 },
				name = "Floor",
				material = "WoodPlanks",
			},
			{
				size = { 18, 15, 1 },
				at = { 0, 7.5, -12.5 },
				color = { 36, 30, 26 },
				material = "Wood",
			},
			{
				size = { 18, 15, 1 },
				at = { 0, 7.5, 8.5 },
				color = { 36, 30, 26 },
				material = "Wood",
			},
			{
				size = { 1, 15, 20 },
				at = { -9.5, 7.5, -2 },
				color = { 36, 30, 26 },
				material = "Wood",
			},
			{
				size = { 1, 15, 20 },
				at = { 9.5, 7.5, -2 },
				color = { 36, 30, 26 },
				material = "Wood",
			},
			{
				size = { 20, 1, 22 },
				at = { 0, 15.5, -2 },
				color = { 36, 30, 26 },
				material = "Wood",
			},
			{
				size = { 0.4, 9, 9 },
				at = { 0, 7, -11.3 },
				color = { 226, 218, 196 },
				material = "SmoothPlastic",
				shape = "Cylinder",
				rot = { 0, 90, 0 },
			},
			{
				size = { 0.3, 9.6, 9.6 },
				at = { 0, 7, -11.5 },
				color = { 60, 46, 30 },
				material = "Wood",
				shape = "Cylinder",
				rot = { 0, 90, 0 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { 0, 10.8, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, 0 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { 1.9, 10.291, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -30 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { 3.291, 8.9, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -60 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { 3.8, 7, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -90 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { 3.291, 5.1, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -120 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { 1.9, 3.709, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -150 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { 0, 3.2, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -180 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { -1.9, 3.709, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -210 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { -3.291, 5.1, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -240 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { -3.8, 7, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -270 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { -3.291, 8.9, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -300 },
			},
			{
				size = { 0.25, 0.9, 0.12 },
				at = { -1.9, 10.291, -11.05 },
				color = { 30, 26, 22 },
				rot = { 0, 0, -330 },
			},
			{
				size = { 0.18, 3.6, 0.1 },
				at = { -1.386, 6.2, -10.95 },
				color = { 160, 20, 30 },
				rot = { 0, 0, -240 },
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 7, -8.5 },
				color = { 255, 230, 190 },
				name = "Clock",
				alpha = 1,
				light = {
					color = { 255, 230, 190 },
					range = 16,
					brightness = 1.4,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { -4, 5, 5 },
				color = { 170, 150, 130 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 170, 150, 130 },
					range = 14,
					brightness = 0.5,
				},
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.18, -8.46 },
				look = { 0, 3.88, -0.07 },
				fov = 46,
				to = {
					eye = { 2.92, 4.78, -7.3 },
					fov = 44,
				},
			},
			{
				at = 2.95,
				eye = { 3.45, 4.66, -4.66 },
				look = { 0, 4.46, -0.25 },
				fov = 42,
				to = {
					eye = { 3.74, 4.76, -3.86 },
					look = { -0.17, 2.32, -1.59 },
				},
			},
			{
				at = 5.4,
				eye = { 7.29, 1.72, -3.16 },
				look = { -0.03, 2.12, -0.78 },
				fov = 50,
				to = {
					eye = { 4.88, 0.46, -3.68 },
					look = { -0.06, 0.66, -1.49 },
				},
			},
			{
				at = 6.7,
				eye = { 2.24, 5.66, -5.47 },
				look = { -0.06, 0.66, -1.49 },
				fov = 44,
				to = {
					eye = { 2.06, 4.46, -4.4 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Their time ran out",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.6,
				act = "deathFx",
				reason = "clock",
				hit = 2.35,
			},
			{
				at = 6.25,
				act = "card",
				kicker = "Cause of death: Their time ran out",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 5.95,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 6.3,
				slot = "flatline",
			},
		},
	},
	reason_dark = {
		kind = "death",
		item = "reason_dark",
		clip = "deathDark",
		clipAt = 2.7,
		length = 7.5,
		grade = {
			saturation = -0.2,
			contrast = 0.2,
			brightness = -0.05,
			tint = { 240, 212, 212 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 8, 1, 34 },
				at = { 0, -0.5, 2 },
				color = { 40, 36, 34 },
				name = "Floor",
				material = "WoodPlanks",
			},
			{
				size = { 8, 9, 1 },
				at = { 0, 4.5, -15.5 },
				color = { 52, 46, 42 },
				material = "Plaster",
			},
			{
				size = { 8, 9, 1 },
				at = { 0, 4.5, 19.5 },
				color = { 52, 46, 42 },
				material = "Plaster",
			},
			{
				size = { 1, 9, 34 },
				at = { -4.5, 4.5, 2 },
				color = { 52, 46, 42 },
				material = "Plaster",
			},
			{
				size = { 1, 9, 34 },
				at = { 4.5, 4.5, 2 },
				color = { 52, 46, 42 },
				material = "Plaster",
			},
			{
				size = { 10, 1, 36 },
				at = { 0, 9.5, 2 },
				color = { 52, 46, 42 },
				material = "Plaster",
			},
			{
				size = { 1.2, 0.3, 1.2 },
				at = { 0, 8.6, -8 },
				color = { 255, 230, 190 },
				name = "Lamp0",
				glow = true,
				light = {
					color = { 255, 226, 180 },
					range = 12,
					brightness = 1.4,
				},
			},
			{
				size = { 1.2, 0.3, 1.2 },
				at = { 0, 8.6, -2 },
				color = { 255, 230, 190 },
				name = "Lamp1",
				glow = true,
				light = {
					color = { 255, 226, 180 },
					range = 12,
					brightness = 1.4,
				},
			},
			{
				size = { 1.2, 0.3, 1.2 },
				at = { 0, 8.6, 4 },
				color = { 255, 230, 190 },
				name = "Lamp2",
				glow = true,
				light = {
					color = { 255, 226, 180 },
					range = 12,
					brightness = 1.4,
				},
			},
			{
				size = { 1.2, 0.3, 1.2 },
				at = { 0, 8.6, 10 },
				color = { 255, 230, 190 },
				name = "Lamp3",
				glow = true,
				light = {
					color = { 255, 226, 180 },
					range = 12,
					brightness = 1.4,
				},
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.26, 5.16, 7.33 },
				look = { 0.01, 3.86, -0.03 },
				fov = 46,
				to = {
					eye = { 4.64, 4.76, 5.48 },
				},
			},
			{
				at = 3.32,
				eye = { 7.1, 3.96, -1.28 },
				look = { 0, 2.24, -0.3 },
				fov = 50,
				to = {
					eye = { 6.15, 1.12, -2.34 },
					look = { 0, 0.92, -0.57 },
				},
			},
			{
				at = 4.11,
				eye = { 0.4, 1.82, -3.97 },
				look = { 0, 1.02, -0.57 },
				fov = 50,
				to = {
					eye = { 0.3, 1.72, -3.57 },
					look = { -0.03, 0.78, 3.06 },
					fov = 40,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Taken by the dark",
						small = true,
					},
				},
			},
			{
				at = 2.65,
				act = "lifeless",
			},
			{
				at = 3.2,
				act = "deathFx",
				reason = "dark",
				hit = 0.56,
			},
			{
				at = 3.3,
				act = "out",
				targets = {
					"Lamp3",
				},
			},
			{
				at = 3.62,
				act = "out",
				targets = {
					"Lamp2",
				},
			},
			{
				at = 3.94,
				act = "out",
				targets = {
					"Lamp1",
				},
			},
			{
				at = 4.06,
				act = "card",
				kicker = "Cause of death: Taken by the dark",
				subtitle = "is dead.",
			},
		},
		beats = {
			{
				at = 3.76,
				kind = "shake",
				strength = 0.12,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.7,
				slot = "heartbeat",
			},
			{
				at = 3.5,
				slot = "heartbeat",
			},
			{
				at = 4.11,
				slot = "flatline",
			},
		},
	},
	death_ash = {
		kind = "death",
		item = "death_ash",
		clip = "collapseHeart",
		clipAt = 2.6,
		length = 9.4,
		grade = {
			saturation = -0.15,
			contrast = 0.16,
			brightness = -0.03,
			tint = { 244, 226, 206 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 18, 1, 18 },
				at = { 0, -0.5, -2 },
				color = { 34, 30, 28 },
				name = "Floor",
				material = "Slate",
			},
			{
				size = { 18, 12, 1 },
				at = { 0, 6, -11.5 },
				color = { 24, 20, 18 },
				material = "Slate",
			},
			{
				size = { 18, 12, 1 },
				at = { 0, 6, 7.5 },
				color = { 24, 20, 18 },
				material = "Slate",
			},
			{
				size = { 1, 12, 18 },
				at = { -9.5, 6, -2 },
				color = { 24, 20, 18 },
				material = "Slate",
			},
			{
				size = { 1, 12, 18 },
				at = { 9.5, 6, -2 },
				color = { 24, 20, 18 },
				material = "Slate",
			},
			{
				size = { 20, 1, 20 },
				at = { 0, 12.5, -2 },
				color = { 24, 20, 18 },
				material = "Slate",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 1, -3 },
				color = { 255, 120, 60 },
				name = "Ember",
				alpha = 1,
				light = {
					color = { 255, 120, 60 },
					range = 14,
					brightness = 0.9,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 10, -1 },
				color = { 220, 200, 180 },
				name = "Top",
				alpha = 1,
				light = {
					color = { 220, 200, 180 },
					range = 16,
					brightness = 1,
				},
			},
			{
				size = { 5, 0.3, 3.6 },
				at = { -4.5, 0.15, -6 },
				color = { 60, 56, 52 },
				material = "Sand",
			},
			{
				size = { 3, 0.25, 2.4 },
				at = { 5, 0.12, -5 },
				color = { 60, 56, 52 },
				material = "Sand",
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.85,
				eye = { 3.24, 4.53, -4.84 },
				look = { -0.21, 4.33, -0.42 },
				fov = 42,
				to = {
					eye = { 3.53, 4.63, -4.03 },
					look = { -0.18, 3.88, -1.93 },
				},
			},
			{
				at = 3.8,
				eye = { 6.14, 0.41, -4.1 },
				look = { -0.03, 2.1, -0.92 },
				fov = 50,
				to = {
					eye = { 4.79, 0.81, -4.64 },
					look = { -0.06, 0.61, -1.84 },
				},
			},
			{
				at = 5.5,
				eye = { 4.14, 3.61, -8.06 },
				look = { -0.06, 1.41, -1.84 },
				fov = 48,
				to = {
					eye = { 3.14, 3.01, -7.39 },
					look = { -0.04, 1.3, -1.85 },
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Heart attack",
						small = true,
					},
				},
			},
			{
				at = 2.55,
				act = "lifeless",
			},
			{
				at = 4.55,
				act = "card",
				kicker = "Cause of death: Heart attack",
				subtitle = "is dead.",
			},
			{
				at = 5.8,
				act = "fallen",
				style = "ash",
				from = "collapseHeart",
			},
		},
		beats = {
			{
				at = 4.25,
				kind = "shake",
				strength = 0.1,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.6,
				slot = "heartbeat",
			},
			{
				at = 3.4,
				slot = "heartbeat",
			},
			{
				at = 4.6,
				slot = "flatline",
			},
		},
	},
	death_strings = {
		kind = "death",
		item = "death_strings",
		clip = "collapseHeart",
		clipAt = 2.6,
		length = 10,
		grade = {
			saturation = -0.15,
			contrast = 0.16,
			brightness = -0.03,
			tint = { 244, 226, 206 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 26, 1, 22 },
				at = { 0, -0.5, -2 },
				color = { 70, 46, 30 },
				name = "Floor",
				material = "WoodPlanks",
			},
			{
				size = { 26, 18, 1 },
				at = { 0, 9, -13.5 },
				color = { 14, 10, 12 },
				material = "Fabric",
			},
			{
				size = { 26, 18, 1 },
				at = { 0, 9, 9.5 },
				color = { 14, 10, 12 },
				material = "Fabric",
			},
			{
				size = { 1, 18, 22 },
				at = { -13.5, 9, -2 },
				color = { 14, 10, 12 },
				material = "Fabric",
			},
			{
				size = { 1, 18, 22 },
				at = { 13.5, 9, -2 },
				color = { 14, 10, 12 },
				material = "Fabric",
			},
			{
				size = { 28, 1, 24 },
				at = { 0, 18.5, -2 },
				color = { 14, 10, 12 },
				material = "Fabric",
			},
			{
				size = { 4, 16, 0.6 },
				at = { -8, 8, -8 },
				color = { 120, 16, 24 },
				material = "Fabric",
			},
			{
				size = { 4, 16, 0.6 },
				at = { 8, 8, -8 },
				color = { 120, 16, 24 },
				material = "Fabric",
			},
			{
				size = { 26, 16, 0.6 },
				at = { 0, 8, -12.4 },
				color = { 96, 12, 20 },
				material = "Fabric",
			},
			{
				size = { 26, 3, 0.6 },
				at = { 0, 15.5, -8 },
				color = { 120, 16, 24 },
				material = "Fabric",
			},
			{
				size = { 0.8, 0.3, 0.3 },
				at = { -6, 0.4, 4.6 },
				color = { 255, 226, 170 },
				name = "Foot0",
				glow = true,
				light = {
					color = { 255, 220, 160 },
					range = 10,
					brightness = 0.9,
				},
			},
			{
				size = { 0.8, 0.3, 0.3 },
				at = { -3, 0.4, 4.6 },
				color = { 255, 226, 170 },
				name = "Foot1",
				glow = true,
				light = {
					color = { 255, 220, 160 },
					range = 10,
					brightness = 0.9,
				},
			},
			{
				size = { 0.8, 0.3, 0.3 },
				at = { 0, 0.4, 4.6 },
				color = { 255, 226, 170 },
				name = "Foot2",
				glow = true,
				light = {
					color = { 255, 220, 160 },
					range = 10,
					brightness = 0.9,
				},
			},
			{
				size = { 0.8, 0.3, 0.3 },
				at = { 3, 0.4, 4.6 },
				color = { 255, 226, 170 },
				name = "Foot3",
				glow = true,
				light = {
					color = { 255, 220, 160 },
					range = 10,
					brightness = 0.9,
				},
			},
			{
				size = { 0.8, 0.3, 0.3 },
				at = { 6, 0.4, 4.6 },
				color = { 255, 226, 170 },
				name = "Foot4",
				glow = true,
				light = {
					color = { 255, 220, 160 },
					range = 10,
					brightness = 0.9,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 15, 2 },
				color = { 255, 236, 200 },
				name = "Spot",
				alpha = 1,
				light = {
					color = { 255, 236, 200 },
					range = 26,
					brightness = 1.8,
				},
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.85,
				eye = { 3.24, 4.53, -4.84 },
				look = { -0.21, 4.33, -0.42 },
				fov = 42,
				to = {
					eye = { 3.53, 4.63, -4.03 },
					look = { -0.18, 3.88, -1.93 },
				},
			},
			{
				at = 3.8,
				eye = { 6.14, 0.41, -4.1 },
				look = { -0.03, 2.1, -0.92 },
				fov = 50,
				to = {
					eye = { 4.79, 0.81, -4.64 },
					look = { -0.06, 0.61, -1.84 },
				},
			},
			{
				at = 5.5,
				eye = { 2.45, 3.12, -9.5 },
				look = { -0.05, 1.21, -1.85 },
				fov = 52,
				to = {
					eye = { 2.89, 2.82, -8.27 },
					look = { -0.2, 4.72, -1.32 },
				},
			},
			{
				at = 8.62,
				eye = { 3.86, 3.69, -7.47 },
				look = { -0.26, 1.29, -2.56 },
				fov = 46,
				to = {
					eye = { 2.76, 3.29, -7.04 },
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Heart attack",
						small = true,
					},
				},
			},
			{
				at = 2.55,
				act = "lifeless",
			},
			{
				at = 4.55,
				act = "card",
				kicker = "Cause of death: Heart attack",
				subtitle = "is dead.",
			},
			{
				at = 5.8,
				act = "fallen",
				style = "strings",
				from = "collapseHeart",
			},
		},
		beats = {
			{
				at = 4.25,
				kind = "shake",
				strength = 0.1,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.6,
				slot = "heartbeat",
			},
			{
				at = 3.4,
				slot = "heartbeat",
			},
			{
				at = 4.6,
				slot = "flatline",
			},
		},
	},
	death_crows = {
		kind = "death",
		item = "death_crows",
		clip = "collapseHeart",
		clipAt = 2.6,
		length = 9.2,
		grade = {
			saturation = -0.3,
			contrast = 0.18,
			brightness = -0.04,
			tint = { 210, 216, 236 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {
			{
				key = "Tree",
				at = { -9, 0, -11 },
				color = { 20, 20, 22 },
				size = 13.7,
			},
		},
		parts = {
			{
				size = { 30, 1, 30 },
				at = { 0, -0.5, 0 },
				color = { 30, 34, 28 },
				name = "Floor",
				material = "Ground",
			},
			{
				size = { 30, 22, 1 },
				at = { 0, 11, -15.5 },
				color = { 20, 22, 26 },
				material = "SmoothPlastic",
			},
			{
				size = { 30, 22, 1 },
				at = { 0, 11, 15.5 },
				color = { 20, 22, 26 },
				material = "SmoothPlastic",
			},
			{
				size = { 1, 22, 30 },
				at = { -15.5, 11, 0 },
				color = { 20, 22, 26 },
				material = "SmoothPlastic",
			},
			{
				size = { 1, 22, 30 },
				at = { 15.5, 11, 0 },
				color = { 20, 22, 26 },
				material = "SmoothPlastic",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 8, 18, -12 },
				color = { 190, 205, 240 },
				name = "Moon",
				alpha = 1,
				light = {
					color = { 190, 205, 240 },
					range = 40,
					brightness = 1.4,
				},
			},
			{
				size = { 18, 1, 18 },
				at = { 0, 0.5, -2 },
				color = { 200, 210, 220 },
				name = "Fog",
				alpha = 1,
				emit = "fog",
			},
			{
				size = { 1.6, 2.6, 0.5 },
				at = { -5, 1.2, -7 },
				color = { 90, 92, 96 },
				material = "Slate",
				rot = { 0, 8, 6 },
			},
			{
				size = { 1.6, 2.6, 0.5 },
				at = { -1.5, 1.2, -9 },
				color = { 90, 92, 96 },
				material = "Slate",
				rot = { 0, -4, -4 },
			},
			{
				size = { 1.6, 2.6, 0.5 },
				at = { 3, 1.2, -7.5 },
				color = { 90, 92, 96 },
				material = "Slate",
				rot = { 0, 12, 3 },
			},
			{
				size = { 1.6, 2.6, 0.5 },
				at = { 6.5, 1.2, -9.5 },
				color = { 90, 92, 96 },
				material = "Slate",
				rot = { 0, -10, 8 },
			},
			{
				size = { 1.6, 2.6, 0.5 },
				at = { -7.5, 1.2, -3 },
				color = { 90, 92, 96 },
				material = "Slate",
				rot = { 0, 20, -6 },
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.85,
				eye = { 3.24, 4.53, -4.84 },
				look = { -0.21, 4.33, -0.42 },
				fov = 42,
				to = {
					eye = { 3.53, 4.63, -4.03 },
					look = { -0.18, 3.88, -1.93 },
				},
			},
			{
				at = 3.8,
				eye = { 6.14, 0.41, -4.1 },
				look = { -0.03, 2.1, -0.92 },
				fov = 50,
				to = {
					eye = { 4.79, 0.81, -4.64 },
					look = { -0.06, 0.61, -1.84 },
				},
			},
			{
				at = 5.5,
				eye = { 3.77, 2.14, -9.99 },
				look = { -0.09, 3.14, -1.31 },
				fov = 54,
				to = {
					eye = { 2.56, 2.54, -9.49 },
					look = { -0.09, 3.74, -1.31 },
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Heart attack",
						small = true,
					},
				},
			},
			{
				at = 2.55,
				act = "lifeless",
			},
			{
				at = 4.55,
				act = "card",
				kicker = "Cause of death: Heart attack",
				subtitle = "is dead.",
			},
			{
				at = 5.8,
				act = "fallen",
				style = "crows",
				from = "collapseHeart",
			},
		},
		beats = {
			{
				at = 4.25,
				kind = "shake",
				strength = 0.1,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.6,
				slot = "heartbeat",
			},
			{
				at = 3.4,
				slot = "heartbeat",
			},
			{
				at = 4.6,
				slot = "flatline",
			},
		},
	},
	death_stone = {
		kind = "death",
		item = "death_stone",
		clip = "collapseHeart",
		clipAt = 2.6,
		length = 9.8,
		grade = {
			saturation = -0.25,
			contrast = 0.14,
			brightness = -0.02,
			tint = { 214, 232, 246 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 28, 1, 28 },
				at = { 0, -0.5, 0 },
				color = { 96, 94, 90 },
				name = "Floor",
				material = "Cobblestone",
			},
			{
				size = { 28, 22, 1 },
				at = { 0, 11, -14.5 },
				color = { 40, 42, 48 },
				material = "Limestone",
			},
			{
				size = { 28, 22, 1 },
				at = { 0, 11, 14.5 },
				color = { 40, 42, 48 },
				material = "Limestone",
			},
			{
				size = { 1, 22, 28 },
				at = { -14.5, 11, 0 },
				color = { 40, 42, 48 },
				material = "Limestone",
			},
			{
				size = { 1, 22, 28 },
				at = { 14.5, 11, 0 },
				color = { 40, 42, 48 },
				material = "Limestone",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { -8, 18, -10 },
				color = { 190, 205, 240 },
				name = "Moon",
				alpha = 1,
				light = {
					color = { 190, 205, 240 },
					range = 40,
					brightness = 1.5,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 6, 4, 6 },
				color = { 150, 160, 190 },
				name = "Fill",
				alpha = 1,
				light = {
					color = { 150, 160, 190 },
					range = 16,
					brightness = 0.5,
				},
			},
			{
				size = { 2.4, 1.2, 2.4 },
				at = { -7, 0.6, -9 },
				color = { 110, 108, 104 },
				material = "Limestone",
			},
			{
				size = { 1.6, 5, 1.2 },
				at = { -7, 3.7, -9 },
				color = { 120, 118, 112 },
				material = "Limestone",
			},
			{
				size = { 1.2, 1.2, 1.2 },
				at = { -7, 6.8, -9 },
				color = { 120, 118, 112 },
				material = "Limestone",
				shape = "Ball",
			},
			{
				size = { 2.4, 1.2, 2.4 },
				at = { 7, 0.6, -10 },
				color = { 110, 108, 104 },
				material = "Limestone",
			},
			{
				size = { 1.6, 4.6, 1.2 },
				at = { 7, 3.5, -10 },
				color = { 120, 118, 112 },
				material = "Limestone",
				rot = { 0, 0, 8 },
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.85,
				eye = { 3.24, 4.53, -4.84 },
				look = { -0.21, 4.33, -0.42 },
				fov = 42,
				to = {
					eye = { 3.53, 4.63, -4.03 },
					look = { -0.18, 3.88, -1.93 },
				},
			},
			{
				at = 3.8,
				eye = { 6.14, 0.41, -4.1 },
				look = { -0.03, 2.1, -0.92 },
				fov = 50,
				to = {
					eye = { 4.79, 0.81, -4.64 },
					look = { -0.06, 0.61, -1.84 },
				},
			},
			{
				at = 5.5,
				eye = { -4.47, 2.9, -6.65 },
				look = { -0.1, 2.1, -1.44 },
				fov = 46,
				to = {
					eye = { -3.23, 2.5, -6.09 },
					look = { -0.1, 2.3, -1.44 },
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Heart attack",
						small = true,
					},
				},
			},
			{
				at = 2.55,
				act = "lifeless",
			},
			{
				at = 4.55,
				act = "card",
				kicker = "Cause of death: Heart attack",
				subtitle = "is dead.",
			},
			{
				at = 5.8,
				act = "fallen",
				style = "stone",
				from = "collapseHeart",
			},
		},
		beats = {
			{
				at = 4.25,
				kind = "shake",
				strength = 0.1,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.6,
				slot = "heartbeat",
			},
			{
				at = 3.4,
				slot = "heartbeat",
			},
			{
				at = 4.6,
				slot = "flatline",
			},
		},
	},
	death_glass = {
		kind = "death",
		item = "death_glass",
		clip = "collapseHeart",
		clipAt = 2.6,
		length = 9.2,
		grade = {
			saturation = -0.25,
			contrast = 0.14,
			brightness = -0.02,
			tint = { 214, 232, 246 },
		},
		vignette = {
			strength = 0.5,
		},
		props = {},
		parts = {
			{
				size = { 20, 1, 20 },
				at = { 0, -0.5, -2 },
				color = { 24, 26, 30 },
				name = "Floor",
				material = "Marble",
			},
			{
				size = { 20, 14, 1 },
				at = { 0, 7, -12.5 },
				color = { 16, 18, 22 },
				material = "SmoothPlastic",
			},
			{
				size = { 20, 14, 1 },
				at = { 0, 7, 8.5 },
				color = { 16, 18, 22 },
				material = "SmoothPlastic",
			},
			{
				size = { 1, 14, 20 },
				at = { -10.5, 7, -2 },
				color = { 16, 18, 22 },
				material = "SmoothPlastic",
			},
			{
				size = { 1, 14, 20 },
				at = { 10.5, 7, -2 },
				color = { 16, 18, 22 },
				material = "SmoothPlastic",
			},
			{
				size = { 22, 1, 22 },
				at = { 0, 14.5, -2 },
				color = { 16, 18, 22 },
				material = "SmoothPlastic",
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 12, -2 },
				color = { 200, 220, 240 },
				name = "Top",
				alpha = 1,
				light = {
					color = { 200, 220, 240 },
					range = 20,
					brightness = 1.6,
				},
			},
			{
				size = { 0.2, 0.2, 0.2 },
				at = { 0, 5, -10 },
				color = { 160, 200, 255 },
				name = "Rim",
				alpha = 1,
				light = {
					color = { 160, 200, 255 },
					range = 14,
					brightness = 0.8,
				},
			},
			{
				size = { 3.4, 10, 0.2 },
				at = { -6, 5, -11.5 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
			{
				size = { 3.4, 10, 0.2 },
				at = { -2, 5, -11.5 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
			{
				size = { 3.4, 10, 0.2 },
				at = { 2, 5, -11.5 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
			{
				size = { 3.4, 10, 0.2 },
				at = { 6, 5, -11.5 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
			{
				size = { 0.2, 10, 3.4 },
				at = { -9.5, 5, -6 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
			{
				size = { 0.2, 10, 3.4 },
				at = { -9.5, 5, -1 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
			{
				size = { 0.2, 10, 3.4 },
				at = { 9.5, 5, -6 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
			{
				size = { 0.2, 10, 3.4 },
				at = { 9.5, 5, -1 },
				color = { 170, 190, 210 },
				material = "Glass",
				alpha = 0.45,
			},
		},
		shots = {
			{
				at = 1.6,
				eye = { 4.46, 5.2, -8.39 },
				look = { 0, 3.9, 0 },
				fov = 46,
				to = {
					eye = { 2.92, 4.8, -7.23 },
					fov = 44,
				},
			},
			{
				at = 2.85,
				eye = { 3.24, 4.53, -4.84 },
				look = { -0.21, 4.33, -0.42 },
				fov = 42,
				to = {
					eye = { 3.53, 4.63, -4.03 },
					look = { -0.18, 3.88, -1.93 },
				},
			},
			{
				at = 3.8,
				eye = { 6.14, 0.41, -4.1 },
				look = { -0.03, 2.1, -0.92 },
				fov = 50,
				to = {
					eye = { 4.79, 0.81, -4.64 },
					look = { -0.06, 0.61, -1.84 },
				},
			},
			{
				at = 5.5,
				eye = { 3.47, 3.51, -6.4 },
				look = { 0.07, 1.91, -0.51 },
				fov = 46,
				to = {
					eye = { 1.17, 3.09, -5.13 },
					look = { 0.06, 2.39, -0.67 },
					fov = 42,
				},
			},
		},
		events = {
			{
				at = 0,
				act = "book",
				seconds = 1.6,
				lines = {
					{
						text = "$name",
					},
					{
						text = "Heart attack",
						small = true,
					},
				},
			},
			{
				at = 2.55,
				act = "lifeless",
			},
			{
				at = 4.55,
				act = "card",
				kicker = "Cause of death: Heart attack",
				subtitle = "is dead.",
			},
			{
				at = 5.8,
				act = "fallen",
				style = "glass",
				from = "collapseHeart",
			},
		},
		beats = {
			{
				at = 4.25,
				kind = "shake",
				strength = 0.1,
				seconds = 0.25,
			},
		},
		sounds = {
			{
				at = 2.6,
				slot = "heartbeat",
			},
			{
				at = 3.4,
				slot = "heartbeat",
			},
			{
				at = 4.6,
				slot = "flatline",
			},
		},
	},
} :: { [string]: any }
