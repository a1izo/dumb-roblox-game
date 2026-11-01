-- What a case-file station shows the room. Every station screen (tagged LStationScreen) gets a live
-- picture drawn on this client in place of the server's plain state line:
--   idle     the station's name, "Standby" and a blinking cursor, the clock, a dim screen light
--   working  plausible activity for its type, under a brighter light that plays on the worker's face:
--              Camera       four CCTV feeds with running timecodes, one picked out, the tape
--                           fast-forwarding, rewinding and pausing, a scrub bar
--              Fingerprint  a print with a scan line sweeping down it, marks lit as it passes, and a
--                           list of reference prints with their scores flickering (never a match)
--              Phone        a call log scrolling past, one call picked out, a voice waveform
--              Forensics    a microscope view drifting in and out of focus, a spectrum drawn sweep by sweep
--            and the small sounds of the work (keys, clicks, a pen, a focus knob), heard close by only.
-- It is driven only by the desk's public attributes: Busy and BusySince (CaseFileService.setScreen),
-- which a hack sets exactly as a case file does. Nothing on the glass comes from the puzzle or the
-- worker, so a hacked station looks like any other being worked, and every client draws the same
-- picture (it is seeded by the station and the moment it went busy).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local TaskTypes = require(Shared:WaitForChild("Tasks"):WaitForChild("TaskTypes"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Blackout = require(script.Parent.Blackout)

local StationFx = {}

local GUI_NAME = "LStationFx"
local DRAW_RANGE = 70 -- studs from the camera: drawn and lit
local HEAR_RANGE = 40 -- the work's sounds
local FPS = 15

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")
local MONO_BOLD = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local GLASS = Color3.fromRGB(8, 10, 14)
local BRIGHT = Color3.fromRGB(214, 218, 224)
local DIM = Color3.fromRGB(122, 128, 138)
local FAINT = Color3.fromRGB(46, 50, 58)

-- What the header says while the station is worked, per type.
local STATUS = {
	Camera = "Reviewing",
	Fingerprint = "Comparing",
	Phone = "Tracing",
	Forensics = "Analysing",
}

-- The work's sounds, per type: each a burst of `count` hits `gap` seconds apart, picked by weight,
-- one burst every `every` seconds or so. Only existing Assets.sfx keys (an empty slot plays nothing).
local SOUNDS = {
	Camera = {
		every = { 1.6, 4 },
		list = {
			{
				key = "typewriter",
				weight = 3,
				count = { 3, 7 },
				gap = { 0.08, 0.15 },
				volume = 0.16,
				pitch = { 1.35, 1.6 },
			},
			{ key = "uiClick", weight = 2, count = { 2, 5 }, gap = { 0.12, 0.2 }, volume = 0.3, pitch = { 0.8, 1 } },
		},
	},
	Fingerprint = {
		every = { 2, 4.5 },
		list = {
			{ key = "uiClick", weight = 2, count = { 1, 2 }, gap = { 0.3, 0.5 }, volume = 0.28, pitch = { 0.7, 0.85 } },
			{ key = "pageTurn", weight = 1, count = { 1, 1 }, gap = { 0, 0 }, volume = 0.2, pitch = { 1.1, 1.3 } },
			{
				key = "typewriter",
				weight = 1,
				count = { 2, 4 },
				gap = { 0.1, 0.16 },
				volume = 0.12,
				pitch = { 1.4, 1.6 },
			},
		},
	},
	Phone = {
		every = { 2, 5 },
		list = {
			{ key = "penScratch", weight = 3, count = { 1, 1 }, gap = { 0, 0 }, volume = 0.22, pitch = { 0.95, 1.1 } },
			{ key = "pageTurn", weight = 1, count = { 1, 1 }, gap = { 0, 0 }, volume = 0.18, pitch = { 1, 1.2 } },
			{
				key = "typewriter",
				weight = 1,
				count = { 3, 5 },
				gap = { 0.09, 0.14 },
				volume = 0.12,
				pitch = { 1.4, 1.6 },
			},
		},
	},
	Forensics = {
		every = { 1.8, 4 },
		list = {
			{
				key = "clockTick",
				weight = 3,
				count = { 2, 5 },
				gap = { 0.16, 0.28 },
				volume = 0.22,
				pitch = { 1.3, 1.6 },
			},
			{
				key = "uiClick",
				weight = 1,
				count = { 1, 2 },
				gap = { 0.25, 0.4 },
				volume = 0.25,
				pitch = { 0.75, 0.9 },
			},
			{ key = "penScratch", weight = 1, count = { 1, 1 }, gap = { 0, 0 }, volume = 0.18, pitch = { 1, 1.1 } },
		},
	},
}

-- A repeatable number in [0, 1) for (a, b): the same on every client.
local function hash(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function seedOf(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1000003
	end
	return h
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function clock(seconds: number): string
	seconds = math.floor(seconds) % 86400
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

local function box(parent: Instance, props: { [string]: any }): Frame
	props.BorderSizePixel = 0
	if props.BackgroundColor3 == nil then
		props.BackgroundTransparency = 1
	end
	props.Parent = parent
	return Create("Frame", props)
end

local function round(item: Instance, radius: UDim?)
	Create("UICorner", { CornerRadius = radius or UDim.new(0.5, 0), Parent = item })
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.FontFace = props.FontFace or MONO
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or DIM
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.Text = props.Text or ""
	props.Parent = parent
	return Create("TextLabel", props)
end

type Update = (t: number, seed: number, now: number) -> ()

-- Views ---------------------------------------------------------------------------------------

local function buildCamera(view: Frame, color: Color3): Update
	local feeds = {}
	for i = 1, 4 do
		local col, row = (i - 1) % 2, (i - 1) // 2
		local feed = box(view, {
			BackgroundColor3 = Color3.fromRGB(20, 22, 26),
			Position = UDim2.fromScale(0.02 + col * 0.375, 0.02 + row * 0.47),
			Size = UDim2.fromScale(0.36, 0.44),
			ClipsDescendants = true,
		})
		local shade = Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(150, 156, 164), Color3.fromRGB(40, 42, 46)),
			Parent = feed,
		})
		-- A room seen from a corner: the floor, a wall block, and figures crossing it.
		box(feed, {
			BackgroundColor3 = Color3.fromRGB(44, 46, 50),
			Position = UDim2.fromScale(0, 0.66),
			Size = UDim2.fromScale(1, 0.34),
		})
		box(feed, {
			BackgroundColor3 = Color3.fromRGB(30, 32, 36),
			Position = UDim2.fromScale(0.1 + 0.5 * (i % 2), 0.22),
			Size = UDim2.fromScale(0.28, 0.44),
		})
		local figures = {}
		for k = 1, 2 do
			local figure = box(feed, {
				BackgroundColor3 = Color3.fromRGB(12, 13, 15),
				AnchorPoint = Vector2.new(0.5, 1),
				Size = UDim2.fromScale(0.07, 0.34 + 0.08 * k),
			})
			round(box(figure, {
				BackgroundColor3 = Color3.fromRGB(12, 13, 15),
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.02),
				Size = UDim2.fromScale(1.1, 0.28),
			}))
			figures[k] = figure
		end
		text(feed, {
			Text = string.format("CAM %02d", i),
			Position = UDim2.fromScale(0.05, 0.04),
			Size = UDim2.fromScale(0.42, 0.14),
			TextColor3 = BRIGHT,
			TextTransparency = 0.15,
		})
		local stamp = text(feed, {
			Position = UDim2.fromScale(0.3, 0.83),
			Size = UDim2.fromScale(0.66, 0.13),
			TextColor3 = BRIGHT,
			TextTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local rec = box(feed, {
			BackgroundColor3 = Color3.fromRGB(220, 44, 40),
			Position = UDim2.fromScale(0.88, 0.06),
			Size = UDim2.fromScale(0.05, 0.09),
		})
		round(rec)
		local stroke = Create("UIStroke", { Color = color, Thickness = 2, Transparency = 1, Parent = feed })
		feeds[i] = { shade = shade, figures = figures, stamp = stamp, rec = rec, stroke = stroke }
	end
	local speed = text(view, {
		FontFace = MONO_BOLD,
		Position = UDim2.fromScale(0.78, 0.04),
		Size = UDim2.fromScale(0.2, 0.16),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local marks = {}
	for k = 1, 5 do
		marks[k] = text(view, {
			Position = UDim2.fromScale(0.79, 0.24 + (k - 1) * 0.12),
			Size = UDim2.fromScale(0.18, 0.09),
			TextColor3 = DIM,
		})
	end
	local bar = box(view, {
		BackgroundColor3 = FAINT,
		Position = UDim2.fromScale(0.02, 0.95),
		Size = UDim2.fromScale(0.735, 0.022),
	})
	local played = box(bar, { BackgroundColor3 = color, BackgroundTransparency = 0.45, Size = UDim2.fromScale(0, 1) })
	local head = box(bar, {
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 3, 4, 0),
	})
	local PHASE = 4.5
	return function(t, seed, now)
		local phase = math.floor(t / PHASE)
		local into = t % PHASE
		local mode = hash(seed, phase)
		local rate, mark
		if mode < 0.4 then
			rate, mark = 8, "x8"
		elseif mode < 0.65 then
			rate, mark = -4, "<< x4"
		elseif mode < 0.85 then
			rate, mark = 1, "x1"
		else
			rate, mark = 0, "||"
		end
		-- (each stretch is a fresh seek in the tape; within it the clock runs at the tape's speed)
		local tape = 19 * 3600 + hash(seed, phase + 0.5) * 5 * 3600 + rate * into
		local picked = 1 + math.floor(hash(seed + 3, phase) * 4)
		local blink = math.floor(now * 1.4) % 2 == 0
		for i, feed in ipairs(feeds) do
			local at = tape + i * 37
			feed.stamp.Text = clock(at)
			feed.stroke.Transparency = if i == picked then 0 else 1
			feed.rec.Visible = blink and rate ~= 0
			-- tape noise: the picture's light trembles a little, more while it winds
			local noise = (hash(i, math.floor(now * 10)) - 0.5) * (if rate == 1 or rate == 0 then 0.03 else 0.12)
			feed.shade.Offset = Vector2.new(0, noise)
			for k, figure in ipairs(feed.figures) do
				local dir = if k == 1 then 1 else -1
				local x = (hash(seed + i, k) + at * 0.004 * dir * (0.6 + 0.3 * k)) % 1.3 - 0.15
				figure.Position = UDim2.fromScale(x, 0.9 - 0.06 * k)
			end
		end
		speed.Text = mark
		for k, line in ipairs(marks) do
			local at = 19 * 3600 + hash(seed, phase * 7 + k) * 5 * 3600
			line.Text = string.sub(clock(at), 1, 5)
			line.TextColor3 = if k == 1 + (phase % 5) then color else DIM
		end
		local u = (tape % 900) / 900
		head.Position = UDim2.fromScale(u, 0.5)
		played.Size = UDim2.fromScale(u, 1)
	end
end

local function buildFingerprint(view: Frame, color: Color3): Update
	local plate = box(view, {
		BackgroundColor3 = Color3.fromRGB(16, 18, 22),
		Position = UDim2.fromScale(0.03, 0.04),
		Size = UDim2.fromScale(0.36, 0.9),
		ClipsDescendants = true,
	})
	-- A whorl: rings round a core that drifts as they grow.
	for k = 1, 9 do
		local size = 0.12 + k * 0.1
		local ring = box(plate, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + 0.012 * k, 0.48 - 0.008 * k),
			Size = UDim2.fromScale(size * 0.92, size * 0.78),
		})
		round(ring)
		Create("UIStroke", {
			Color = Color3.fromRGB(150, 156, 164),
			Thickness = 2,
			Transparency = 0.25 + k * 0.04,
			Parent = ring,
		})
	end
	local marks = {}
	for k = 1, 8 do
		local mark = box(plate, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.07, 0.05) })
		marks[k] = { frame = mark, stroke = Create("UIStroke", { Color = color, Thickness = 1.5, Parent = mark }) }
	end
	local trail = box(plate, {
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromScale(1, 0.16),
	})
	Create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0.8),
		Parent = trail,
	})
	local scan = box(plate, { BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 2) })
	text(view, {
		Text = "REF       SCORE",
		Position = UDim2.fromScale(0.45, 0.04),
		Size = UDim2.fromScale(0.5, 0.1),
		TextColor3 = FAINT,
	})
	local rows = {}
	for k = 1, 5 do
		local row = box(view, {
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.44, 0.17 + (k - 1) * 0.135),
			Size = UDim2.fromScale(0.53, 0.115),
		})
		local label = text(row, { Position = UDim2.fromScale(0.03, 0.1), Size = UDim2.fromScale(0.94, 0.8) })
		local meter = box(row, {
			BackgroundColor3 = DIM,
			BackgroundTransparency = 0.5,
			Position = UDim2.fromScale(0.03, 0.92),
			Size = UDim2.fromScale(0, 0.08),
		})
		rows[k] = { row = row, label = label, meter = meter }
	end
	local SWEEP = 3.2
	return function(t, seed, now)
		local sweep = math.floor(t / SWEEP)
		local y = (t % SWEEP) / SWEEP
		scan.Position = UDim2.fromScale(0, y)
		trail.Position = UDim2.fromScale(0, y)
		for k, mark in ipairs(marks) do
			local my = 0.15 + hash(seed + sweep, k) * 0.7
			mark.frame.Position = UDim2.fromScale(0.2 + hash(seed + sweep, k + 20) * 0.6, my)
			mark.stroke.Transparency = if my < y then 0.1 else 1
		end
		local picked = 1 + sweep % 5
		local tick = math.floor(now * 2.5)
		for k, row in ipairs(rows) do
			local base = 30 + hash(seed, k) * 45
			local score = math.floor(base + (hash(k, tick) - 0.5) * 6)
			row.label.Text = string.format("%04d      %2d%%", math.floor(hash(seed, k + 9) * 9000) + 1000, score)
			row.meter.Size = UDim2.fromScale(0.94 * score / 100, 0.08)
			local on = k == picked
			row.row.BackgroundTransparency = if on then 0.82 else 1
			row.label.TextColor3 = if on then BRIGHT else DIM
		end
	end
end

local function buildPhone(view: Frame, color: Color3): Update
	text(view, {
		Text = "TIME   NUMBER          LENGTH",
		Position = UDim2.fromScale(0.04, 0.02),
		Size = UDim2.fromScale(0.92, 0.09),
		TextColor3 = FAINT,
	})
	local list = box(view, {
		Position = UDim2.fromScale(0.03, 0.13),
		Size = UDim2.fromScale(0.94, 0.56),
		ClipsDescendants = true,
	})
	local VISIBLE = 4
	local rows = {}
	for k = 1, VISIBLE + 1 do
		local row = box(list, {
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1 / VISIBLE),
		})
		rows[k] = {
			row = row,
			label = text(row, { Position = UDim2.fromScale(0.01, 0.15), Size = UDim2.fromScale(0.98, 0.7) }),
		}
	end
	local bars = {}
	local COUNT = 30
	for k = 1, COUNT do
		bars[k] = box(view, {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.05 + (k - 1) / (COUNT - 1) * 0.9, 0.84),
			Size = UDim2.fromScale(0.012, 0.02),
		})
	end
	local STEP = 1.8
	local function entry(seed: number, k: number): string
		local minutes = math.floor(hash(seed, k) * 1440)
		local length = math.floor(hash(seed, k + 0.3) * 600) + 8
		return string.format(
			"%02d:%02d  %02d %04d %04d   %dm%02ds",
			minutes // 60,
			minutes % 60,
			math.floor(hash(seed, k + 0.6) * 90) + 3,
			math.floor(hash(seed, k + 0.7) * 9000) + 1000,
			math.floor(hash(seed, k + 0.8) * 9000) + 1000,
			length // 60,
			length % 60
		)
	end
	return function(t, seed, now)
		local step = math.floor(t / STEP)
		local slide = smooth((t % STEP) / 0.45)
		for k, item in ipairs(rows) do
			local index = step + k
			item.row.Position = UDim2.fromScale(0, (k - 1 - slide) / VISIBLE)
			item.label.Text = entry(seed, index)
			local on = k == 2 + (if slide > 0.5 then 1 else 0)
			item.row.BackgroundTransparency = if on then 0.82 else 1
			item.label.TextColor3 = if on then BRIGHT else DIM
		end
		-- the line: a voice for a while, then a few seconds of nothing
		local talking = hash(seed, math.floor(t / 5)) > 0.25
		for k, bar in ipairs(bars) do
			local level = if talking then math.abs(math.noise(k * 0.31, now * 2.4, seed % 97)) * 2.2 else 0.02
			bar.Size = UDim2.fromScale(0.012, 0.02 + math.min(level, 1) * 0.22)
		end
	end
end

local function buildForensics(view: Frame, color: Color3): Update
	local scope = box(view, {
		BackgroundColor3 = Color3.fromRGB(14, 18, 20),
		Position = UDim2.fromScale(0.03, 0.04),
		Size = UDim2.fromScale(0.3, 0.92),
		ClipsDescendants = true,
	})
	Create("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = scope })
	round(scope)
	Create("UIStroke", { Color = DIM, Thickness = 2, Transparency = 0.4, Parent = scope })
	local blobs = {}
	for k = 1, 7 do
		local blob = box(scope, {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
		})
		round(blob)
		blobs[k] = { frame = blob, stroke = Create("UIStroke", { Color = BRIGHT, Thickness = 1, Parent = blob }) }
	end
	box(scope, {
		BackgroundColor3 = DIM,
		BackgroundTransparency = 0.6,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
	})
	box(scope, {
		BackgroundColor3 = DIM,
		BackgroundTransparency = 0.6,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 1, 1, 0),
	})
	local name = text(view, {
		Position = UDim2.fromScale(0.42, 0.03),
		Size = UDim2.fromScale(0.4, 0.1),
		TextColor3 = DIM,
	})
	local chart = box(view, { Position = UDim2.fromScale(0.42, 0.16), Size = UDim2.fromScale(0.55, 0.66) })
	box(chart, { BackgroundColor3 = FAINT, Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1) })
	local bars = {}
	local COUNT = 24
	for k = 1, COUNT do
		bars[k] = box(chart, {
			BackgroundColor3 = DIM,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale((k - 1) / COUNT, 1),
			Size = UDim2.fromScale(0.7 / COUNT, 0),
		})
	end
	local readout = text(view, {
		Position = UDim2.fromScale(0.42, 0.86),
		Size = UDim2.fromScale(0.55, 0.1),
		TextColor3 = DIM,
	})
	local SWEEP = 5
	return function(t, seed, now)
		name.Text = string.format(
			"SAMPLE %02d-%s",
			math.floor(hash(seed, 1) * 90) + 10,
			string.char(65 + math.floor(hash(seed, 2) * 6))
		)
		-- focus: slowly through sharp and back, as the knob turns
		local focus = 0.5 + 0.5 * math.sin(t * 0.8 + hash(seed, 3) * 6)
		for k, blob in ipairs(blobs) do
			local x = 0.5 + 0.34 * math.noise(k * 1.7, t * 0.05, seed % 89)
			local y = 0.5 + 0.34 * math.noise(k * 2.3, t * 0.05 + 4, seed % 89)
			local size = (0.08 + hash(seed, k + 4) * 0.12) * (1.25 - 0.25 * focus)
			blob.frame.Position = UDim2.fromScale(x, y)
			blob.frame.Size = UDim2.fromScale(size, size * (0.7 + hash(seed, k + 11) * 0.5))
			blob.frame.BackgroundTransparency = 0.75 - 0.4 * focus
			blob.stroke.Transparency = 1 - focus * 0.7
		end
		local sweep = math.floor(t / SWEEP)
		local reveal = (t % SWEEP) / SWEEP * 1.15
		local peaks = {}
		for p = 1, 3 do
			peaks[p] = {
				at = hash(seed + sweep, p),
				width = 0.04 + hash(seed + sweep, p + 3) * 0.08,
				height = 0.4 + hash(seed + sweep, p + 6) * 0.6,
			}
		end
		for k, bar in ipairs(bars) do
			local u = (k - 0.5) / COUNT
			local h = 0.06 + 0.04 * hash(seed + sweep, k + 20)
			for _, peak in ipairs(peaks) do
				h += peak.height * math.exp(-((u - peak.at) / peak.width) ^ 2)
			end
			local shown = u < reveal
			bar.Size = UDim2.fromScale(0.7 / COUNT, if shown then math.min(h, 1) else 0)
			bar.BackgroundColor3 = if shown and u > reveal - 1 / COUNT then color else DIM
		end
		readout.Text = string.format(
			"%4d nm   %3d",
			380 + math.floor(math.min(reveal, 1) * 400),
			math.floor(hash(seed, math.floor(now * 3)) * 900) + 100
		)
	end
end

local BUILDERS = {
	Camera = buildCamera,
	Fingerprint = buildFingerprint,
	Phone = buildPhone,
	Forensics = buildForensics,
}

-- Screens -------------------------------------------------------------------------------------

type Record = {
	screen: BasePart,
	desk: BasePart,
	kind: string,
	color: Color3,
	seed: number,
	gui: SurfaceGui,
	glass: Frame,
	content: Frame,
	idle: Frame,
	work: Frame,
	status: TextLabel,
	clockLabel: TextLabel,
	cursor: Frame,
	roll: Frame,
	flash: Frame,
	light: SurfaceLight,
	update: Update,
	busy: boolean?,
	nextSound: number,
}

local records: { [BasePart]: Record } = {}

local function deskFor(stationId: any): BasePart?
	for _, desk in ipairs(CollectionService:GetTagged("LStation")) do
		if desk:IsA("BasePart") and desk:GetAttribute("StationId") == stationId then
			return desk
		end
	end
	return nil
end

-- The server's own state line goes quiet on this client (it is the fallback where this does not run).
local function hideServerGui(item: Instance)
	if item:IsA("SurfaceGui") and item.Name ~= GUI_NAME then
		item.Enabled = false
	end
end

local function build(screen: BasePart, desk: BasePart)
	local kind = tostring(desk:GetAttribute("StationType") or "Camera")
	if not BUILDERS[kind] then
		kind = "Camera"
	end
	local color = TaskTypes.get(kind).color
	local name = tostring(desk:GetAttribute("StationName") or "")
	for _, child in ipairs(screen:GetChildren()) do
		hideServerGui(child)
	end
	screen.ChildAdded:Connect(hideServerGui)
	local gui = Create("SurfaceGui", {
		Name = GUI_NAME,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 80,
		LightInfluence = 0,
		Brightness = 1.4,
		Parent = screen,
	})
	local glass = box(gui, { BackgroundColor3 = GLASS, Size = UDim2.fromScale(1, 1), ClipsDescendants = true })
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 160)),
		Rotation = 90,
		Parent = glass,
	})
	text(glass, {
		Text = string.upper(name),
		Position = UDim2.fromScale(0.04, 0.035),
		Size = UDim2.fromScale(0.6, 0.085),
		TextColor3 = DIM,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local status = text(glass, {
		Position = UDim2.fromScale(0.6, 0.035),
		Size = UDim2.fromScale(0.36, 0.085),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	box(glass, {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.4,
		Position = UDim2.fromScale(0.04, 0.14),
		Size = UDim2.new(0.92, 0, 0, 2),
	})
	local content = box(glass, { Position = UDim2.fromScale(0.03, 0.17), Size = UDim2.fromScale(0.94, 0.8) })

	local idle = box(content, { Size = UDim2.fromScale(1, 1) })
	text(idle, {
		Text = "Standby",
		FontFace = MONO_BOLD,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.71, 0.42),
		Size = UDim2.fromScale(0.5, 0.2),
		TextColor3 = color,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local cursor = box(idle, {
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.725, 0.42),
		Size = UDim2.fromScale(0.025, 0.16),
	})
	local clockLabel = text(idle, {
		Position = UDim2.fromScale(0.02, 0.84),
		Size = UDim2.fromScale(0.3, 0.12),
		TextColor3 = DIM,
	})
	text(idle, {
		Text = string.upper(TaskTypes.get(kind).label),
		Position = UDim2.fromScale(0.4, 0.84),
		Size = UDim2.fromScale(0.58, 0.12),
		TextColor3 = FAINT,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local work = box(content, { Size = UDim2.fromScale(1, 1), Visible = false })
	local update = BUILDERS[kind](work, color)

	-- A soft bright band rolling down the glass, as on an old monitor, and a flash when it changes state.
	local roll = box(glass, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.96,
		Size = UDim2.fromScale(1, 0.14),
	})
	local flash = box(glass, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local light = Create("SurfaceLight", {
		Face = Enum.NormalId.Front,
		Angle = 110,
		Range = 9,
		Brightness = 0.3,
		Color = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Shadows = false,
		Parent = screen,
	})
	records[screen] = {
		screen = screen,
		desk = desk,
		kind = kind,
		color = color,
		seed = seedOf(tostring(desk:GetAttribute("StationId") or name)),
		gui = gui,
		glass = glass,
		content = content,
		idle = idle,
		work = work,
		status = status,
		clockLabel = clockLabel,
		cursor = cursor,
		roll = roll,
		flash = flash,
		light = light,
		update = update,
		busy = nil,
		nextSound = 0,
	}
end

local function attach(screen: Instance)
	if records[screen :: any] or not screen:IsA("BasePart") then
		return
	end
	local desk = deskFor(screen:GetAttribute("StationId"))
	if desk then
		build(screen, desk)
	end
end

local function drop(screen: BasePart)
	local record = records[screen]
	records[screen] = nil
	if record then
		record.gui:Destroy()
		record.light:Destroy()
	end
end

local function pick(list, roll: number)
	local total = 0
	for _, item in ipairs(list) do
		total += item.weight
	end
	local at = roll * total
	for _, item in ipairs(list) do
		at -= item.weight
		if at <= 0 then
			return item
		end
	end
	return list[1]
end

local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- One burst of the work's small sounds from the desk.
local function burst(record: Record)
	local list = SOUNDS[record.kind]
	local item = pick(list.list, math.random())
	local count = math.random(item.count[1], item.count[2])
	task.spawn(function()
		for _ = 1, count do
			if not record.busy or not record.desk.Parent then
				return
			end
			local sound =
				Sfx.play(item.key, { volume = item.volume, pitch = between(item.pitch), parent = record.desk })
			if sound then
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = 4
				sound.RollOffMaxDistance = HEAR_RANGE
			end
			task.wait(between(item.gap))
		end
	end)
	record.nextSound = os.clock() + between(list.every)
end

local function setBusy(record: Record, busy: boolean)
	local first = record.busy == nil
	record.busy = busy
	record.idle.Visible = not busy
	record.work.Visible = busy
	record.status.Text = if busy then STATUS[record.kind] or "" else ""
	if not first then
		record.flash.BackgroundTransparency = 0.7
		TweenService:Create(record.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		local sound = Sfx.play("uiClick", { volume = 0.35, pitch = if busy then 1 else 0.8, parent = record.desk })
		if sound then
			sound.RollOffMaxDistance = HEAR_RANGE
		end
		record.nextSound = os.clock() + 0.8
	end
end

local function draw(record: Record, now: number, dark: boolean)
	local busy = record.desk:GetAttribute("Busy") == true
	if busy ~= record.busy then
		setBusy(record, busy)
	end
	-- In a blackout the screens have no power: the glass is black and gives no light.
	record.content.Visible = not dark
	record.status.Visible = not dark
	if dark then
		record.light.Enabled = false
		return
	end
	record.light.Enabled = true
	record.roll.Position = UDim2.fromScale(0, (now / 7) % 1.3 - 0.15)
	if busy then
		local since = record.desk:GetAttribute("BusySince")
		local t = math.max(0, now - (if type(since) == "number" then since else now))
		record.update(t, record.seed + (if type(since) == "number" then math.floor(since) % 9973 else 0), now)
		record.light.Brightness = 0.95 + 0.12 * math.noise(now * 0.9, record.seed % 53)
	else
		record.cursor.Visible = math.floor(now * 1.6) % 2 == 0
		record.clockLabel.Text = string.sub(clock(now), 1, 5)
		record.light.Brightness = 0.3
	end
end

function StationFx.init()
	CollectionService:GetInstanceAddedSignal("LStationScreen"):Connect(attach)
	CollectionService:GetInstanceRemovedSignal("LStationScreen"):Connect(function(screen)
		drop(screen :: any)
	end)
	-- (a screen can stream in before its desk: try it again when the desk comes)
	CollectionService:GetInstanceAddedSignal("LStation"):Connect(function()
		for _, screen in ipairs(CollectionService:GetTagged("LStationScreen")) do
			attach(screen)
		end
	end)
	for _, screen in ipairs(CollectionService:GetTagged("LStationScreen")) do
		attach(screen)
	end
	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < 1 / FPS then
			return
		end
		waited = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local now = workspace:GetServerTimeNow()
		local dark = Blackout.isActive()
		for screen, record in pairs(records) do
			if not screen.Parent or not record.desk.Parent then
				drop(screen)
				continue
			end
			local distance = (screen.Position - eye).Magnitude
			local near = distance < DRAW_RANGE
			record.gui.Enabled = distance < DRAW_RANGE * 1.5
			if not near then
				record.light.Enabled = false
				continue
			end
			draw(record, now, dark)
			if record.busy and not dark and distance < HEAR_RANGE and os.clock() >= record.nextSound then
				burst(record)
			end
		end
	end)
end

return StationFx
