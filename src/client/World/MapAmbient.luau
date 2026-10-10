--!strict
-- Life in a map, played on each client from markers the server's map builder leaves
-- (server Maps/SceneBuilder): screens looping made-up adverts, camera feeds, the night news, a
-- sector map or an old film; ambient sounds (silent while their Assets.sfx slot is empty); the
-- metro train, which pulls into its platform, opens its doors and leaves again on a timer;
-- aircraft lights blinking on the towers; rain on the glass and snow slipping off branches
-- (thinner on slower devices); the police helicopter that now and then sweeps its searchlight
-- across a tower's floors; and the campus clock tower, whose hands creep towards midnight as the
-- investigation runs out and whose bell tolls twelve when the Grimoire phase begins. Nothing
-- here collides with anyone.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("ModelCatalog")) :: any
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))

local ClientState = require(script.Parent.Parent.ClientState)
local Responsive = require(script.Parent.Parent.UI.Core.Responsive)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

local MapAmbient = {}

local SCREEN_TAG = "LMapScreen"
local SOUND_TAG = "LMapSound"
local TRAIN_TAG = "LMapTrain"
local BLINK_TAG = "LMapBlink"
local HELI_TAG = "LMapHeli"
local RAIN_GLASS_TAG = "LMapRainGlass"
local BRANCH_SNOW_TAG = "LMapBranchSnow"
local CLOCK_TAG = "LMapClock"
local FOG_TAG = "LMapFog"

-- Screens ------------------------------------------------------------------------------------------

local ADS = {
	{ "影ヶ丘 夜市", "NIGHT MARKET", Color3.fromRGB(255, 70, 160), Color3.fromRGB(60, 20, 120) },
	{ "新作 ソーダ", "NEW SODA", Color3.fromRGB(40, 200, 255), Color3.fromRGB(10, 40, 120) },
	{ "カラオケ 月光", "KARAOKE", Color3.fromRGB(255, 200, 60), Color3.fromRGB(140, 30, 60) },
	{ "影屋 セール", "KAGEYA SALE", Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 30, 40) },
	{ "夜のニュース", "NIGHT NEWS", Color3.fromRGB(220, 230, 255), Color3.fromRGB(20, 30, 60) },
}

local function playAds(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.Parent = part
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.ClipsDescendants = true -- the ticker scrolls in from off the screen's edge
	back.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 35
	gradient.Parent = back
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.9, 0.5)
	title.Position = UDim2.fromScale(0.05, 0.12)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = back
	local ticker = Instance.new("TextLabel")
	ticker.BackgroundTransparency = 1
	ticker.Size = UDim2.fromScale(2, 0.2)
	ticker.Position = UDim2.fromScale(0, 0.72)
	ticker.TextScaled = true
	ticker.Font = Enum.Font.GothamBold
	ticker.TextXAlignment = Enum.TextXAlignment.Left
	ticker.Parent = back
	task.spawn(function()
		local index = math.random(1, #ADS)
		while part.Parent do
			local ad = ADS[index]
			gradient.Color = ColorSequence.new(ad[4], ad[3])
			title.Text = ad[1]
			title.TextColor3 = Color3.new(1, 1, 1)
			ticker.Text = ad[2] .. "   ★   " .. ad[2] .. "   ★   " .. ad[2]
			ticker.TextColor3 = ad[3]
			if Settings.get("reduceMotion") then
				task.wait(8)
			else
				ticker.Position = UDim2.fromScale(0, 0.72)
				TweenService:Create(ticker, TweenInfo.new(8, Enum.EasingStyle.Linear), {
					Position = UDim2.fromScale(-1, 0.72),
				}):Play()
				gradient.Offset = Vector2.new(-0.5, 0)
				TweenService:Create(gradient, TweenInfo.new(8, Enum.EasingStyle.Sine), {
					Offset = Vector2.new(0.5, 0),
				}):Play()
				task.wait(8)
			end
			index = index % #ADS + 1
		end
	end)
end

-- A screen's face: a SurfaceGui on its front with a black backing frame.
local function face(part: BasePart, pixels: number): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.Parent = part
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.ClipsDescendants = true
	back.Parent = gui
	return back
end

local function box(parent: Instance, position: UDim2, size: UDim2, colour: Color3, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.Position = position
	frame.Size = size
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = colour
	frame.BackgroundTransparency = transparency or 0
	frame.Parent = parent
	return frame
end

local function label(parent: Instance, position: UDim2, size: UDim2, colour: Color3, font: Enum.Font?): TextLabel
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Position = position
	line.Size = size
	line.TextScaled = true
	line.Font = font or Enum.Font.Code
	line.TextColor3 = colour
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.Parent = parent
	return line
end

-- The night as the screens tell it: past two in the morning, ticking on from when the map loaded.
local nightStart = os.clock() - math.random(0, 3000)
local function nightClock(): string
	local seconds = math.floor(os.clock() - nightStart) + 2 * 3600 + 13 * 60
	return string.format("%02d:%02d:%02d", (seconds // 3600) % 24, (seconds // 60) % 60, seconds % 60)
end

-- What the building's cameras see: a few scenes as grey-green silhouettes (a corridor, the fire
-- stair, the lobby, the street far below, the archive), someone crossing now and then, the
-- camera's number, the time and a blinking REC.
local CCTV_SCENES = {
	{ "38F CORRIDOR", { { 0.3, 0, 0.4, 1, 0.12 }, { 0.42, 0.2, 0.16, 0.6, 0.05 }, { 0, 0.85, 1, 0.15, 0.2 } } },
	{ "FIRE STAIR", { { 0.1, 0.1, 0.3, 0.9, 0.16 }, { 0.5, 0.3, 0.4, 0.7, 0.1 }, { 0.45, 0, 0.1, 1, 0.22 } } },
	{ "LOBBY", { { 0, 0.7, 1, 0.3, 0.18 }, { 0.2, 0.2, 0.25, 0.5, 0.08 }, { 0.6, 0.25, 0.3, 0.45, 0.1 } } },
	{ "STREET", { { 0, 0.55, 1, 0.45, 0.1 }, { 0.05, 0.1, 0.2, 0.45, 0.2 }, { 0.7, 0.05, 0.25, 0.5, 0.18 } } },
	{ "ARCHIVE", { { 0.05, 0.1, 0.12, 0.9, 0.2 }, { 0.3, 0.1, 0.12, 0.9, 0.2 }, { 0.55, 0.1, 0.12, 0.9, 0.2 } } },
}

local function playCctv(part: BasePart)
	local back = face(part, 40)
	back.BackgroundColor3 = Color3.fromRGB(10, 14, 12)
	local tint = Color3.fromRGB(120, 150, 130)
	local shapes: { Frame } = {}
	for _ = 1, 3 do
		table.insert(shapes, box(back, UDim2.new(), UDim2.new(), tint, 0.8))
	end
	local figure = box(back, UDim2.fromScale(-0.1, 0.45), UDim2.fromScale(0.05, 0.3), Color3.fromRGB(20, 26, 22), 0.2)
	for k = 1, 6 do
		box(back, UDim2.fromScale(0, (k - 0.5) / 6), UDim2.new(1, 0, 0, 1), Color3.new(0, 0, 0), 0.7)
	end
	local camLabel = label(back, UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.6, 0.12), Color3.fromRGB(210, 230, 210))
	local clock = label(back, UDim2.fromScale(0.04, 0.84), UDim2.fromScale(0.5, 0.11), Color3.fromRGB(210, 230, 210))
	local rec = label(back, UDim2.fromScale(0.72, 0.04), UDim2.fromScale(0.24, 0.12), Color3.fromRGB(255, 60, 60))
	rec.Text = "● REC"
	task.spawn(function()
		local index = math.random(1, #CCTV_SCENES)
		local camera = math.random(1, 24)
		while part.Parent do
			local scene = CCTV_SCENES[index]
			camLabel.Text = string.format("CAM %02d  %s", camera, scene[1])
			for k, shape in ipairs(shapes) do
				local r = scene[2][k]
				shape.Position = UDim2.fromScale(r[1], r[2])
				shape.Size = UDim2.fromScale(r[3], r[4])
				shape.BackgroundTransparency = 1 - r[5] * 3
			end
			local crossing = math.random() < 0.4 and not Settings.get("reduceMotion")
			figure.Visible = crossing
			if crossing then
				figure.Position = UDim2.fromScale(-0.1, 0.45)
				TweenService:Create(figure, TweenInfo.new(6, Enum.EasingStyle.Linear), {
					Position = UDim2.fromScale(1.05, 0.45),
				}):Play()
			end
			for second = 1, 7 do
				clock.Text = nightClock()
				rec.Visible = second % 2 == 1
				task.wait(1)
				if not part.Parent then
					return
				end
			end
			index = index % #CCTV_SCENES + 1
			camera = camera % 24 + 1
		end
	end)
end

-- Kagegaoka's night news: the channel's bar, LIVE, the headline and a ticker along the foot.
local HEADLINES = {
	"THIRD SUDDEN DEATH THIS WEEK",
	"WITNESSES SOUGHT IN KAGEGAOKA",
	"THE BUREAU SAYS NOTHING",
	"RAIN ALL NIGHT OVER THE CITY",
	"EXPRESSWAY CLOSED AT EXIT 7",
}

local function playNews(part: BasePart)
	local back = face(part, 30)
	back.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
	local bar = box(back, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), Color3.fromRGB(150, 20, 30))
	local channel =
		label(bar, UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.7, 0.8), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	channel.Text = "影ヶ丘 NIGHT NEWS"
	local live =
		label(bar, UDim2.fromScale(0.8, 0.15), UDim2.fromScale(0.17, 0.7), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	live.Text = "● LIVE"
	local headline = label(
		back,
		UDim2.fromScale(0.04, 0.3),
		UDim2.fromScale(0.92, 0.36),
		Color3.fromRGB(236, 236, 244),
		Enum.Font.GothamBold
	)
	local strip = box(back, UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.18), Color3.fromRGB(230, 226, 214))
	strip.ClipsDescendants = true
	local ticker =
		label(strip, UDim2.fromScale(0, 0.1), UDim2.fromScale(3, 0.8), Color3.fromRGB(20, 20, 26), Enum.Font.GothamBold)
	ticker.Text = table.concat(HEADLINES, "   ◆   ")
	task.spawn(function()
		local index = math.random(1, #HEADLINES)
		while part.Parent do
			headline.Text = HEADLINES[index]
			if not Settings.get("reduceMotion") then
				ticker.Position = UDim2.fromScale(0, 0.1)
				TweenService:Create(ticker, TweenInfo.new(9, Enum.EasingStyle.Linear), {
					Position = UDim2.fromScale(-2, 0.1),
				}):Play()
			end
			task.wait(9)
			index = index % #HEADLINES + 1
		end
	end)
end

-- The operations room's map of the city: a street grid, the river, the tower, and red marks that
-- move from one place to the next as the night goes on, under a slow scan line.
local function playMap(part: BasePart)
	local back = face(part, 20)
	back.BackgroundColor3 = Color3.fromRGB(8, 14, 30)
	local line = Color3.fromRGB(40, 70, 120)
	for k = 1, 9 do
		box(back, UDim2.fromScale(k / 10, 0), UDim2.new(0, 2, 1, 0), line, 0.2)
		box(back, UDim2.fromScale(0, k / 10), UDim2.new(1, 0, 0, 2), line, 0.2)
	end
	local river = box(back, UDim2.fromScale(0, 0.72), UDim2.fromScale(1, 0.06), Color3.fromRGB(30, 60, 110))
	river.Rotation = -3
	box(back, UDim2.fromScale(0.48, 0.42), UDim2.fromScale(0.04, 0.07), Color3.fromRGB(230, 214, 170))
	local title = label(back, UDim2.fromScale(0.03, 0.03), UDim2.fromScale(0.6, 0.09), Color3.fromRGB(150, 190, 255))
	title.Text = "影ヶ丘  KAGEGAOKA  SECTOR 7"
	local stamp = label(back, UDim2.fromScale(0.72, 0.03), UDim2.fromScale(0.25, 0.09), Color3.fromRGB(150, 190, 255))
	local marks: { Frame } = {}
	for _ = 1, 4 do
		table.insert(
			marks,
			box(back, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.025, 0.04), Color3.fromRGB(255, 50, 60))
		)
	end
	local scan = box(back, UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 3), Color3.fromRGB(120, 180, 255), 0.4)
	task.spawn(function()
		while part.Parent do
			for _, mark in ipairs(marks) do
				local goal = UDim2.fromScale(0.05 + math.random() * 0.9, 0.12 + math.random() * 0.8)
				if Settings.get("reduceMotion") then
					mark.Position = goal
				else
					TweenService:Create(mark, TweenInfo.new(4, Enum.EasingStyle.Sine), { Position = goal }):Play()
				end
			end
			if not Settings.get("reduceMotion") then
				scan.Position = UDim2.fromScale(0, 0)
				TweenService
					:Create(scan, TweenInfo.new(8, Enum.EasingStyle.Linear), { Position = UDim2.fromScale(0, 1) })
					:Play()
			end
			for second = 1, 8 do
				stamp.Text = nightClock()
				for _, mark in ipairs(marks) do
					mark.BackgroundTransparency = if second % 2 == 0 then 0.5 else 0
				end
				task.wait(1)
				if not part.Parent then
					return
				end
			end
		end
	end)
end

-- The film club's winter screening: an old black-and-white reel on the projector's screen. The
-- leader counts down, the title card comes up, then a few silent scenes (a street in the snow, a
-- figure crossing it, a train going by) under flicker, dust and scratches, and the end card.
local FILM_SCENES = {
	-- { caption, { { x, y, w, h, shade } ... } }: shapes in a scene, 0 = black, 1 = white.
	{ "", { { 0, 0.62, 1, 0.38, 0.85 }, { 0.08, 0.1, 0.22, 0.55, 0.25 }, { 0.62, 0.2, 0.3, 0.45, 0.3 } } },
	{ "", { { 0, 0.7, 1, 0.3, 0.8 }, { 0, 0.35, 1, 0.12, 0.15 }, { 0.46, 0.05, 0.08, 0.3, 0.45 } } },
	{ "", { { 0, 0.55, 1, 0.45, 0.2 }, { 0.2, 0.15, 0.6, 0.35, 0.7 }, { 0.3, 0.6, 0.4, 0.05, 0.9 } } },
}
local FILM_CARDS = {
	title = "冬の上映会\nWINTER SCREENING",
	credit = "影ヶ丘大学 映画研究会\nKAGEGAOKA UNIV. FILM CLUB",
	finish = "終\nTHE END",
}

local function playFilm(part: BasePart)
	local back = face(part, 24)
	back.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	-- The picture, a little inside the screen, and what is on it.
	local picture = box(back, UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.9), Color3.fromRGB(128, 128, 124))
	picture.ClipsDescendants = true
	local shapes: { Frame } = {}
	for _ = 1, 3 do
		table.insert(shapes, box(picture, UDim2.new(), UDim2.new(), Color3.new(0, 0, 0)))
	end
	local walker = box(picture, UDim2.fromScale(-0.1, 0.42), UDim2.fromScale(0.05, 0.28), Color3.fromRGB(16, 16, 16))
	local card = label(picture, UDim2.fromScale(0.1, 0.25), UDim2.fromScale(0.8, 0.5), Color3.fromRGB(236, 234, 226))
	card.Font = Enum.Font.Antique
	card.TextXAlignment = Enum.TextXAlignment.Center
	-- Scratches and dust that come and go with the flicker.
	local scratches: { Frame } = {}
	for _ = 1, 3 do
		table.insert(scratches, box(picture, UDim2.fromScale(0.5, 0), UDim2.new(0, 2, 1, 0), Color3.new(1, 1, 1), 0.5))
	end
	local specks: { Frame } = {}
	for _ = 1, 5 do
		table.insert(
			specks,
			box(picture, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.012, 0.02), Color3.new(0, 0, 0), 0.3)
		)
	end
	local function shade(value: number): Color3
		return Color3.new(value, value, value * 0.97)
	end
	local function show(scene: { any }?)
		for index, shape in ipairs(shapes) do
			local spec = if scene then scene[2][index] else nil
			shape.Visible = spec ~= nil
			if spec then
				shape.Position = UDim2.fromScale(spec[1], spec[2])
				shape.Size = UDim2.fromScale(spec[3], spec[4])
				shape.BackgroundColor3 = shade(spec[5])
			end
		end
	end
	local function flicker()
		local still = Settings.get("reduceMotion")
		local level = if still then 0.5 else 0.42 + math.random() * 0.16
		picture.BackgroundColor3 = shade(level)
		for _, scratch in ipairs(scratches) do
			scratch.Visible = not still and math.random() < 0.3
			scratch.Position = UDim2.fromScale(math.random(), 0)
		end
		for _, speck in ipairs(specks) do
			speck.Visible = not still and math.random() < 0.4
			speck.Position = UDim2.fromScale(math.random(), math.random())
		end
	end
	local function hold(seconds: number): boolean
		local steps = math.floor(seconds / 0.12)
		for _ = 1, steps do
			flicker()
			task.wait(0.12)
			if not part.Parent then
				return false
			end
		end
		return true
	end
	task.spawn(function()
		task.wait(math.random() * 4)
		while part.Parent do
			-- The leader's countdown, then the cards.
			show(nil)
			walker.Visible = false
			for count = 5, 1, -1 do
				card.Text = tostring(count)
				if not hold(0.8) then
					return
				end
			end
			for _, text in ipairs({ FILM_CARDS.title, FILM_CARDS.credit }) do
				card.Text = text
				if not hold(3.5) then
					return
				end
			end
			card.Text = ""
			for index, scene in ipairs(FILM_SCENES) do
				show(scene)
				-- Someone crosses the snowy street in the first scene.
				walker.Visible = index == 1 and not Settings.get("reduceMotion")
				if walker.Visible then
					walker.Position = UDim2.fromScale(-0.1, 0.42)
					TweenService:Create(walker, TweenInfo.new(6, Enum.EasingStyle.Linear), {
						Position = UDim2.fromScale(1.05, 0.42),
					}):Play()
				end
				if not hold(6) then
					return
				end
			end
			show(nil)
			walker.Visible = false
			card.Text = FILM_CARDS.finish
			if not hold(3) then
				return
			end
		end
	end)
end

-- A karaoke room's screen: the song's title card, then its lyrics two lines at a time, the sung part
-- filling in colour left to right, over a slow drifting backdrop. The songs are the house's own.
local KARAOKE_SONGS = {
	{
		title = "雨の交差点  RAIN AT THE CROSSING",
		lines = {
			"信号が変わるまで  until the light turns",
			"傘の中で名前を  I hold your name",
			"誰にも言えない  under my umbrella",
			"夜明けの前に  before the dawn comes",
		},
	},
	{
		title = "最終電車  THE LAST TRAIN",
		lines = {
			"ホームの端で  at the platform's end",
			"君を待ってた  I waited for you",
			"ドアが閉まる  the doors are closing",
			"さよならを言えず  and no goodbye",
		},
	},
	{
		title = "黒いノート  THE BLACK NOTEBOOK",
		lines = {
			"ページをめくる  turning the pages",
			"指が震える  my fingers shake",
			"書かない名前  the name I won't write",
			"今夜だけは  just for tonight",
		},
	},
}

local function playKaraoke(part: BasePart)
	local back = face(part, 18)
	back.BackgroundColor3 = Color3.fromRGB(28, 10, 46)
	local glowA = box(back, UDim2.fromScale(-0.2, -0.3), UDim2.fromScale(0.8, 0.9), Color3.fromRGB(120, 30, 120), 0.6)
	local glowB = box(back, UDim2.fromScale(0.5, 0.4), UDim2.fromScale(0.8, 0.9), Color3.fromRGB(30, 60, 140), 0.6)
	local title = label(
		back,
		UDim2.fromScale(0.05, 0.08),
		UDim2.fromScale(0.9, 0.16),
		Color3.fromRGB(255, 220, 120),
		Enum.Font.GothamBlack
	)
	local rows = {}
	for k = 1, 2 do
		local holder =
			box(back, UDim2.fromScale(0.06, 0.42 + (k - 1) * 0.22), UDim2.fromScale(0.88, 0.16), Color3.new(0, 0, 0), 1)
		holder.ClipsDescendants = true
		local plain = label(
			holder,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			Color3.fromRGB(240, 240, 250),
			Enum.Font.GothamBold
		)
		local fill = box(holder, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), Color3.new(0, 0, 0), 1)
		fill.ClipsDescendants = true
		local sung = label(
			fill,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			Color3.fromRGB(80, 220, 255),
			Enum.Font.GothamBold
		)
		rows[k] = { plain = plain, fill = fill, sung = sung, holder = holder }
	end
	task.spawn(function()
		local song = math.random(1, #KARAOKE_SONGS)
		while part.Parent do
			local current = KARAOKE_SONGS[song]
			title.Text = current.title
			for _, row in ipairs(rows) do
				row.plain.Text = ""
				row.sung.Text = ""
			end
			task.wait(3)
			for index = 1, #current.lines, 2 do
				for k = 1, 2 do
					local text = current.lines[index + k - 1] or ""
					local row = rows[k]
					row.plain.Text = text
					row.sung.Text = text
					row.fill.Size = UDim2.fromScale(0, 1)
					-- The sung label keeps the row's full width inside the growing fill.
					row.sung.Size = UDim2.fromScale(1, 1)
				end
				for k = 1, 2 do
					local row = rows[k]
					local start = os.clock()
					while part.Parent and os.clock() - start < 4 do
						local t = (os.clock() - start) / 4
						row.fill.Size = UDim2.fromScale(t, 1)
						row.sung.Size = UDim2.fromScale(1 / math.max(t, 0.01), 1)
						task.wait(0.05)
					end
					row.fill.Size = UDim2.fromScale(1, 1)
					row.sung.Size = UDim2.fromScale(1, 1)
				end
				if not Settings.get("reduceMotion") then
					glowA.Position = UDim2.fromScale(-0.2 + math.random() * 0.2, -0.3 + math.random() * 0.2)
					glowB.Position = UDim2.fromScale(0.4 + math.random() * 0.2, 0.3 + math.random() * 0.2)
				end
			end
			song = song % #KARAOKE_SONGS + 1
		end
	end)
end

local function playScreen(part: BasePart)
	local loop = part:GetAttribute("Loop")
	if loop == "cctv" then
		playCctv(part)
	elseif loop == "news" then
		playNews(part)
	elseif loop == "map" then
		playMap(part)
	elseif loop == "film" then
		playFilm(part)
	elseif loop == "karaoke" then
		playKaraoke(part)
	else
		playAds(part)
	end
end

-- Sounds ------------------------------------------------------------------------------------------

-- The sounds heard from outside (muffled indoors, see Audio/Muffle); the rest are room tones.
local OUTDOOR_SOUNDS = {
	mapRiver = true,
	mapCityHum = true,
	mapCrossingChirp = true,
	mapLanternCreak = true,
	mapSirenFar = true,
	mapHelicopter = true,
	mapWindSnow = true,
	mapTowerBell = true,
	mapRainGlass = true,
}

-- The looping sounds by key, and the keys a map's mechanic has silenced for now (the crossing's
-- chirp only sounds on the walk lamp).
local looping: { [Sound]: { key: string, volume: number } } = {}
local silenced: { [string]: boolean } = {}

local function playSound(source: BasePart)
	if source:GetAttribute("Looped") ~= true then
		return -- one-shots (the station chime, the train) are played by the train
	end
	local key = source:GetAttribute("Key") :: string
	local sound = Sfx.play(key, {
		group = if OUTDOOR_SOUNDS[key] then "Outdoor" else "Ambience",
		parent = source,
		looped = true,
		volume = (source:GetAttribute("Volume") :: number?) or 0.5,
	})
	if sound then
		sound.RollOffMaxDistance = (source:GetAttribute("Radius") :: number?) or 40
		sound.RollOffMinDistance = 6
		looping[sound] = { key = key, volume = sound.Volume }
		sound.Destroying:Once(function()
			looping[sound] = nil
		end)
		if silenced[key] then
			sound.Volume = 0
		end
		sound:Play()
	end
end

-- Lets a looping map sound be heard or not (it keeps playing, silently, so it stays in step).
function MapAmbient.setAudible(key: string, audible: boolean)
	if (silenced[key] == true) == not audible then
		return
	end
	silenced[key] = if audible then nil else true
	for sound, entry in pairs(looping) do
		if entry.key == key then
			sound.Volume = if audible then entry.volume else 0
		end
	end
end

local function oneShot(folder: Instance?, key: string)
	if not folder then
		return
	end
	for _, source in ipairs(CollectionService:GetTagged(SOUND_TAG)) do
		if source:IsA("BasePart") and source:GetAttribute("Key") == key and source:IsDescendantOf(folder) then
			local sound = Sfx.play(key, {
				group = "Ambience",
				parent = source,
				volume = (source:GetAttribute("Volume") :: number?) or 0.5,
			})
			if sound then
				sound.RollOffMaxDistance = (source:GetAttribute("Radius") :: number?) or 60
			end
		end
	end
end

-- The train -----------------------------------------------------------------------------------------

local function carLights(model: Model, key: string)
	local info = Catalog[key]
	local primary = model.PrimaryPart
	if not info or not info.lights or not primary then
		return
	end
	local pivot = model:GetPivot()
	for _, spec in ipairs(info.lights) do
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = pivot * CFrame.new(spec.at[1], spec.at[2], spec.at[3])
		anchor.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		light.Range = spec.range
		light.Brightness = spec.brightness
		light.Parent = anchor
	end
end

local function runTrain(run: Instance)
	local cars = string.split((run:GetAttribute("Cars") :: string?) or "", ",")
	local models: { Model } = {}
	local length = (run:GetAttribute("CarLength") :: number?) or 50
	for index, key in ipairs(cars) do
		local model = ModelLibrary.get(key)
		if not model then
			return -- not imported: no train (the platform still works)
		end
		model.Name = "Train_" .. key
		carLights(model, key)
		model:SetAttribute("Offset", (index - 1) * length)
		table.insert(models, model)
	end
	local turn = CFrame.Angles(0, math.rad((run:GetAttribute("Rot") :: number?) or 90), 0)
	local enter = run:GetAttribute("EnterAt") :: Vector3
	local stop = run:GetAttribute("StopAt") :: Vector3
	local leave = run:GetAttribute("LeaveAt") :: Vector3
	local every = (run:GetAttribute("Every") :: number?) or 120
	local dwell = (run:GetAttribute("Dwell") :: number?) or 15
	-- The cars follow the head, strung out behind it (the way it came from).
	local back = (enter - stop).Unit
	local driver = Instance.new("CFrameValue")
	local function place()
		for _, model in ipairs(models) do
			local offset = model:GetAttribute("Offset") :: number
			model:PivotTo(CFrame.new(driver.Value.Position + back * offset) * turn)
		end
	end
	driver.Changed:Connect(place)
	local folder = run.Parent
	task.spawn(function()
		task.wait(math.random() * 20)
		while run.Parent do
			driver.Value = CFrame.new(enter)
			for _, model in ipairs(models) do
				model.Parent = folder
			end
			place()
			local arrive =
				TweenService:Create(driver, TweenInfo.new(9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Value = CFrame.new(stop),
				})
			arrive:Play()
			oneShot(folder, "mapTrainArrive")
			arrive.Completed:Wait()
			oneShot(folder, "mapStationChime")
			task.wait(dwell)
			local depart =
				TweenService:Create(driver, TweenInfo.new(9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Value = CFrame.new(leave + (leave - stop).Unit * #models * length),
				})
			depart:Play()
			depart.Completed:Wait()
			for _, model in ipairs(models) do
				model.Parent = nil
			end
			task.wait(math.max(10, every - 18 - dwell))
		end
		for _, model in ipairs(models) do
			model:Destroy()
		end
	end)
end

-- Aircraft lights -------------------------------------------------------------------------------------
-- Every lamp tagged by the map blinks on its own period and phase: on for a third of it.

local blinkers: { [BasePart]: { period: number, phase: number } } = {}
local lastBlink = 0

local function stepBlinkers()
	local now = os.clock()
	if now - lastBlink < 0.1 then
		return
	end
	lastBlink = now
	for lamp, timing in pairs(blinkers) do
		if not lamp.Parent then
			blinkers[lamp] = nil
			continue
		end
		local on = (now + timing.phase) % timing.period < timing.period * 0.35
		lamp.Transparency = if on then 0 else 0.85
	end
end

-- Rain on the glass ------------------------------------------------------------------------------------
-- The map sets how hard it rains on each pane; phones, Reduce motion and Low graphics get less.

local RAIN_SCALE = { phone = 0.3, tablet = 0.5, console = 0.8, desktop = 1 }
local rainGlass: { [ParticleEmitter]: boolean } = {}

local function rainFactor(): number
	local factor = RAIN_SCALE[Responsive.class()] or 1
	if Settings.get("reduceMotion") then
		factor *= 0.5
	end
	if Settings.get("lowGraphics") then
		factor *= 0.4
	end
	return factor
end

local function refreshRainGlass()
	local factor = rainFactor()
	for emitter in pairs(rainGlass) do
		if emitter.Parent then
			emitter.Rate = ((emitter:GetAttribute("BaseRate") :: number?) or 10) * factor
		else
			rainGlass[emitter] = nil
		end
	end
end

-- Mist, cloud and dust ----------------------------------------------------------------------------------
-- The mood of each map is made of slow soft particles (ground mist, the tower's cloud sea, dust in
-- the light, a feather now and then). Slower devices get fewer of them; Low graphics keeps the mist
-- only as fewer particles (the atmosphere's haze stays off there).

local FOG_SCALE = { phone = 0.35, tablet = 0.55, console = 0.85, desktop = 1 }
local fog: { [ParticleEmitter]: boolean } = {}

local function fogFactor(): number
	local factor = FOG_SCALE[Responsive.class()] or 1
	if Settings.get("reduceMotion") then
		factor *= 0.6
	end
	if Settings.get("lowGraphics") then
		factor *= 0.45
	end
	return factor
end

local function refreshFog()
	local factor = fogFactor()
	for emitter in pairs(fog) do
		if emitter.Parent then
			emitter.Rate = ((emitter:GetAttribute("BaseRate") :: number?) or 2) * factor
		else
			fog[emitter] = nil
		end
	end
end

-- Snow off the branches ---------------------------------------------------------------------------------
-- Now and then a clump of snow slips off a tree near the camera. Slower devices get smaller
-- clumps, further apart.

local branchSnow: { [ParticleEmitter]: boolean } = {}
local BRANCH_REACH = 110

local function branchSnowLoop()
	while true do
		task.wait(2.5 + math.random() * 4)
		local camera = workspace.CurrentCamera
		if not camera or Settings.get("reduceMotion") then
			continue
		end
		local near = {}
		for emitter in pairs(branchSnow) do
			local anchor = emitter.Parent
			if not anchor then
				branchSnow[emitter] = nil
			elseif anchor:IsA("BasePart") and (anchor.Position - camera.CFrame.Position).Magnitude < BRANCH_REACH then
				table.insert(near, emitter)
			end
		end
		if #near > 0 then
			local emitter = near[math.random(1, #near)]
			local burst = (emitter:GetAttribute("Burst") :: number?) or 20
			emitter:Emit(math.max(4, math.floor(burst * rainFactor())))
		end
	end
end

-- The clock tower -----------------------------------------------------------------------------------------
-- Its hands stand at 23:00 until the investigation starts, then creep to midnight as it runs out
-- (a rough timer anyone can read from across the campus), and stay at midnight from the Grimoire
-- phase on; a new round's investigation sends them back to eleven. Twelve strokes of the bell mark
-- the Grimoire phase.

type Clock = { dial: BasePart, hour: BasePart, minute: BasePart }

local clocks: { [Instance]: Clock } = {}
local shownMinutes = 0 -- minutes past 23:00 the hands show (0 to 60)
local AFTER_MIDNIGHT = { DeathNote = true, Meeting = true, Vote = true, Verdict = true, Reveal = true, Outro = true }
local BELL_STROKES = 12
local BELL_GAP = 2.4

-- Minutes past 23:00 the hands should show now.
local function towerMinutes(): number
	local public = ClientState.public
	if not public.active then
		return 0
	end
	if public.phase == "Investigation" then
		local startedAt = tonumber(public.startedAt) or 0
		local span = (tonumber(public.endsAt) or 0) - startedAt
		if span <= 0 then
			return 0
		end
		return math.clamp((workspace:GetServerTimeNow() - startedAt) / span, 0, 1) * 60
	end
	return if AFTER_MIDNIGHT[public.phase] then 60 else 0
end

local function placeHand(dial: BasePart, hand: BasePart, angle: number)
	local reach = (hand:GetAttribute("Reach") :: number?) or 0
	local lift = (hand:GetAttribute("Lift") :: number?) or 0.2
	hand.CFrame = dial.CFrame * CFrame.Angles(0, 0, angle) * CFrame.new(0, reach, -lift)
end

local function stepClocks(dt: number)
	if next(clocks) == nil then
		return
	end
	local target = towerMinutes()
	-- The hands run back or forward in a few seconds when they jump (a new round, a late join).
	if math.abs(target - shownMinutes) > 1 then
		shownMinutes += (target - shownMinutes) * math.min(1, dt * 1.5)
	else
		shownMinutes = target
	end
	local minutes = 23 * 60 + shownMinutes
	local hourAngle = ((minutes / 60) % 12) / 12 * math.pi * 2
	local minuteAngle = (minutes % 60) / 60 * math.pi * 2
	for model, clock in pairs(clocks) do
		if not model.Parent then
			clocks[model] = nil
			continue
		end
		placeHand(clock.dial, clock.hour, hourAngle)
		placeHand(clock.dial, clock.minute, minuteAngle)
	end
end

local function tollMidnight()
	for _, source in ipairs(CollectionService:GetTagged(SOUND_TAG)) do
		if source:IsA("BasePart") and source:GetAttribute("Key") == "mapTowerBell" then
			task.spawn(function()
				for _ = 1, BELL_STROKES do
					if not source.Parent then
						return
					end
					local sound = Sfx.play("mapTowerBell", {
						group = "Outdoor",
						parent = source,
						volume = (source:GetAttribute("Volume") :: number?) or 0.8,
					})
					if not sound then
						return -- the slot is empty
					end
					sound.RollOffMaxDistance = (source:GetAttribute("Radius") :: number?) or 600
					sound.RollOffMinDistance = 40
					task.wait(BELL_GAP)
				end
			end)
		end
	end
end

-- The helicopter ----------------------------------------------------------------------------------------
-- Now and then a police helicopter flies the map's path past the tower, its searchlight following
-- the target points in step (so it sweeps across the floors), nav lights blinking, rotor turning.

local function decode(value: any): { Vector3 }
	local points = {}
	if type(value) ~= "string" then
		return points
	end
	for chunk in string.gmatch(value, "[^;]+") do
		local x, y, z = string.match(chunk, "^([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
		if x then
			table.insert(points, Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number))
		end
	end
	return points
end

-- The point `t` (0 to 1) along a smooth curve through points (Catmull-Rom, even time per span).
local function along(points: { Vector3 }, t: number): Vector3
	local spans = #points - 1
	local f = math.clamp(t, 0, 1) * spans
	local i = math.min(spans, math.floor(f) + 1)
	local u = f - (i - 1)
	local p0 = points[math.max(1, i - 1)]
	local p1 = points[i]
	local p2 = points[i + 1]
	local p3 = points[math.min(#points, i + 2)]
	return 0.5
		* (2 * p1 + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (3 * p1 - p0 - 3 * p2 + p3) * u * u * u)
end

local function heliPart(model: Model, size: Vector3, colour: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = colour
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

local function fly(run: Instance, path: { Vector3 }, target: { Vector3 }, duration: number)
	local model = Instance.new("Model")
	model.Name = "PoliceHelicopter"
	local dark = Color3.fromRGB(24, 26, 32)
	local body = heliPart(model, Vector3.new(3.4, 3.2, 8), dark)
	local tail = heliPart(model, Vector3.new(0.8, 0.8, 7), dark)
	local fin = heliPart(model, Vector3.new(0.2, 2.2, 1.4), dark)
	local rotor = heliPart(model, Vector3.new(13, 0.12, 0.7), Color3.fromRGB(12, 12, 14))
	local rotor2 = heliPart(model, Vector3.new(0.7, 0.12, 13), Color3.fromRGB(12, 12, 14))
	local red = heliPart(model, Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	local green = heliPart(model, Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(40, 255, 90), Enum.Material.Neon)
	local strobe = heliPart(model, Vector3.new(0.35, 0.35, 0.35), Color3.new(1, 1, 1), Enum.Material.Neon)
	local lamp = heliPart(model, Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Angle = 26
	beam.Range = 60
	beam.Brightness = 7
	beam.Shadows = true
	beam.Color = Color3.fromRGB(240, 244, 255)
	beam.Parent = lamp
	model.Parent = run
	local sound = Sfx.play("mapHelicopter", { group = "Outdoor", parent = body, looped = true, volume = 0.6 })
	if sound then
		sound.RollOffMinDistance = 30
		sound.RollOffMaxDistance = 500
	end
	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - began
		local t = elapsed / duration
		if t >= 1 or not run.Parent then
			connection:Disconnect()
			if sound then
				sound:Stop()
				sound:Destroy()
			end
			model:Destroy()
			return
		end
		local at = along(path, t)
		local ahead = along(path, math.min(1, t + 0.01))
		local heading = if (ahead - at).Magnitude > 0.01 then CFrame.lookAt(at, ahead) else CFrame.new(at)
		local tilt = heading * CFrame.Angles(math.rad(-8), 0, 0)
		body.CFrame = tilt
		tail.CFrame = tilt * CFrame.new(0, 0.6, 6.5)
		fin.CFrame = tilt * CFrame.new(0, 1.6, 9.6)
		local spin = CFrame.Angles(0, elapsed * 30, 0)
		rotor.CFrame = tilt * CFrame.new(0, 2.0, 0) * spin
		rotor2.CFrame = tilt * CFrame.new(0, 2.0, 0) * spin
		red.CFrame = tilt * CFrame.new(-1.8, 0, 0)
		green.CFrame = tilt * CFrame.new(1.8, 0, 0)
		strobe.CFrame = tilt * CFrame.new(0, 1.8, 3)
		strobe.Transparency = if elapsed % 1.2 < 0.12 then 0 else 1
		local nose = (tilt * CFrame.new(0, -1.8, -3.5)).Position
		lamp.CFrame = CFrame.lookAt(nose, along(target, t))
	end)
end

local function runHeli(run: Instance)
	local path = decode(run:GetAttribute("Path"))
	local target = decode(run:GetAttribute("Target"))
	if #path < 2 or #target ~= #path then
		return
	end
	local every = (run:GetAttribute("Every") :: number?) or 90
	local duration = (run:GetAttribute("Duration") :: number?) or 18
	task.wait(15 + math.random() * every * 0.5)
	while run.Parent do
		if not Settings.get("reduceMotion") then
			fly(run, path, target, duration)
		end
		task.wait(every * (0.8 + math.random() * 0.4))
	end
end

local function watch(tag: string, handler: (Instance) -> ())
	for _, item in ipairs(CollectionService:GetTagged(tag)) do
		task.spawn(handler, item)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(item)
		task.spawn(handler, item)
	end)
end

function MapAmbient.init()
	watch(SCREEN_TAG, function(item)
		if item:IsA("BasePart") then
			playScreen(item)
		end
	end)
	watch(SOUND_TAG, function(item)
		if item:IsA("BasePart") then
			playSound(item)
		end
	end)
	watch(TRAIN_TAG, runTrain)
	watch(BLINK_TAG, function(item)
		if item:IsA("BasePart") then
			blinkers[item] = {
				period = math.max(0.2, (item:GetAttribute("Period") :: number?) or 2),
				phase = (item:GetAttribute("Phase") :: number?) or 0,
			}
		end
	end)
	RunService.Heartbeat:Connect(stepBlinkers)
	watch(RAIN_GLASS_TAG, function(item)
		if item:IsA("ParticleEmitter") then
			rainGlass[item] = true
			refreshRainGlass()
		end
	end)
	Responsive.Changed:Connect(refreshRainGlass)
	Settings.Changed:Connect(function(key)
		if key == "reduceMotion" or key == "lowGraphics" then
			refreshRainGlass()
		end
	end)
	watch(FOG_TAG, function(item)
		if item:IsA("ParticleEmitter") then
			fog[item] = true
			refreshFog()
		end
	end)
	Responsive.Changed:Connect(refreshFog)
	Settings.Changed:Connect(function(key)
		if key == "reduceMotion" or key == "lowGraphics" then
			refreshFog()
		end
	end)
	watch(HELI_TAG, runHeli)
	watch(BRANCH_SNOW_TAG, function(item)
		if item:IsA("ParticleEmitter") then
			branchSnow[item] = true
		end
	end)
	task.spawn(branchSnowLoop)
	watch(CLOCK_TAG, function(item)
		local dial = item:FindFirstChild("Dial")
		local hour = item:FindFirstChild("Hour")
		local minute = item:FindFirstChild("Minute")
		if dial and dial:IsA("BasePart") and hour and hour:IsA("BasePart") and minute and minute:IsA("BasePart") then
			clocks[item] = { dial = dial, hour = hour, minute = minute }
			shownMinutes = towerMinutes()
		end
	end)
	RunService.Heartbeat:Connect(stepClocks)
	ClientState.PhaseChanged:Connect(function(phase, previous)
		-- (Only as the investigation ends: not for someone joining in the middle of the phase.)
		if phase == "DeathNote" and previous == "Investigation" and next(clocks) ~= nil then
			tollMidnight()
		end
	end)
end

return MapAmbient
