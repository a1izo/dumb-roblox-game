--!strict
-- What everyone sees of a name going into the Manual (2026-10-27, the user's call): while a writer stands with the
-- book open (the server marks the body LManualOpen for the writing time: Services/DeathNoteService), a scrawl runs
-- across its open page line after line, in a hand nobody can read. Never the name: who wrote what is secret while
-- the case runs (the writer's own screen shows the name in its close-up, Presenters/ManualWrite). The page is the
-- held book's own (Services/CharacterService.setWriting makes its ManualPage).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ManualScrawl = {}

local LINES = 4
local LETTERS = "mnuwvrnmeciaolsthnmuuw" -- (cursive humps: a hand at speed, not words)
local INK = Color3.fromRGB(26, 20, 22)
local FONT = Font.fromEnum(Enum.Font.IndieFlower)
local PIXELS = 320 -- per stud on the page

local open: { [Model]: { gui: SurfaceGui, started: number, labels: { TextLabel } } } = {}
local random = Random.new()

local function gibberish(): string
	local words = {}
	for _ = 1, random:NextInteger(2, 4) do
		local word = {}
		for _ = 1, random:NextInteger(3, 7) do
			local k = random:NextInteger(1, #LETTERS)
			table.insert(word, string.sub(LETTERS, k, k))
		end
		table.insert(words, table.concat(word))
	end
	return table.concat(words, " ")
end

local function page(character: Model): BasePart?
	local held = character:FindFirstChild("LWriting")
	local found = if held then held:FindFirstChild("ManualPage", true) else nil
	return if found and found:IsA("BasePart") then found else nil
end

local function begin(character: Model)
	local sheet = page(character)
	if not sheet then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DGScrawl"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS
	gui.LightInfluence = 0.7
	gui.MaxDistance = 45
	gui.Adornee = sheet
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.04, 0)
	list.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.1, 0)
	pad.PaddingRight = UDim.new(0.08, 0)
	pad.Parent = gui
	local labels = {}
	for index = 1, LINES do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. index
		label.LayoutOrder = index
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(random:NextNumber(0.7, 1), 0.15)
		label.FontFace = FONT
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = INK
		label.Rotation = random:NextNumber(-3, 2)
		label.Text = gibberish()
		label.MaxVisibleGraphemes = 0
		label.Parent = gui
		table.insert(labels, label)
	end
	gui.Parent = sheet
	open[character] = { gui = gui, started = os.clock(), labels = labels }
end

local function finish(character: Model)
	local entry = open[character]
	open[character] = nil
	if entry and entry.gui.Parent then
		entry.gui:Destroy()
	end
end

local function characters(): { Model }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, bot in ipairs(CollectionService:GetTagged("LBotCharacter")) do
		if bot:IsA("Model") then
			table.insert(list, bot)
		end
	end
	return list
end

local function step()
	local seen: { [Model]: boolean } = {}
	for _, character in ipairs(characters()) do
		seen[character] = true
		local writing = character:GetAttribute("LManualOpen") == true
		if writing and not open[character] then
			begin(character)
		elseif not writing and open[character] then
			finish(character)
		end
	end
	for character in pairs(open) do
		if not seen[character] then
			finish(character)
		end
	end
	-- (each line writes itself in its share of the writing time, letter by letter)
	local share = Config.MANUAL_WRITE_TIME / LINES
	for _, entry in pairs(open) do
		local elapsed = os.clock() - entry.started
		for index, label in ipairs(entry.labels) do
			local t = math.clamp((elapsed - (index - 1) * share) / share, 0, 1)
			label.MaxVisibleGraphemes = math.floor(t * utf8.len(label.Text) :: number + 0.5)
		end
	end
end

function ManualScrawl.init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.05 then
			acc = 0
			step()
		end
	end)
end

return ManualScrawl
