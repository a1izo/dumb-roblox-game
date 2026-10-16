--!strict
-- Whoever has the most wins sits on the bone throne in front of the title, in stone: a grey figure in the
-- shape of their avatar (its outline and accessories; no colours, no face), a little larger than life,
-- enthroned (back to the backrest, chin up, one arm along the throne's arm, the other hand loose) and
-- looking down the plaza at the spawn. The throne is empty until the board has someone on it. The plaque at
-- its foot carries their name and wins, cut pale into the dark slate. The seat and the plaque are the
-- server's marks (Maps/LobbyFixtures, tags LThroneSeat and LThronePlaque); the name comes with the
-- leaderboards every client is sent. Built on this client only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))

local StoneFigures = require(script.Parent.StoneFigures)

local Champion = {}

local TAG = "LThroneSeat"
local PLAQUE_TAG = "LThronePlaque"
local SCALE = 1.5
-- Into the "enthroned" clip: a settled moment of it.
local POSE = "enthroned"
local POSE_AT = 1.0
-- From the seat's mark to where a standing figure's feet would be: the hips 0.87 over the seat, so the level legs
-- (three quarters of a stud to their middle at this scale) rest on it, and 0.8 back, so the leaning torso's
-- back meets the backrest (1.75 behind the seat's middle).
local SEATED = CFrame.new(0, -2 * SCALE + 0.87, 0.8)
local CUT = Color3.fromRGB(206, 200, 186) -- the letters, cut pale into the slate
local EMPTY = "UNCLAIMED"

local figure: StoneFigures.Figure? = nil
local seated: number? = nil
local wanted: number? = nil
local folder: Folder? = nil
local plaqueText: { name: string, wins: string } = { name = EMPTY, wins = "" }
local plaqueLabels: { [BasePart]: { name: TextLabel, wins: TextLabel } } = {}

local function seat(): BasePart?
	for _, item in ipairs(CollectionService:GetTagged(TAG)) do
		if item:IsA("BasePart") and item:IsDescendantOf(workspace) then
			return item
		end
	end
	return nil
end

local function clear()
	if figure then
		StoneFigures.destroy(figure)
		figure = nil
	end
	seated = nil
end

local function avatar(userId: number): Model?
	local ok, model = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserId(userId)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	return if ok and model then model else nil
end

local function build(userId: number)
	local mark = seat()
	local parent = folder
	if not mark or not parent then
		return
	end
	local feet = mark.CFrame * SEATED
	local made: StoneFigures.Figure? = nil
	local body = avatar(userId)
	if wanted ~= userId then
		if body then
			body:Destroy()
		end
		return
	end
	if body then
		body.Name = "Champion"
		made = StoneFigures.adopt(body, parent, feet, SCALE, false)
		if not made then
			body:Destroy()
		end
	end
	if not made then
		made = StoneFigures.new({ parent = parent, feet = feet, scale = SCALE, name = "Champion" })
	end
	clear()
	StoneFigures.pose(made, POSE, POSE_AT, { travel = false })
	figure = made
	seated = userId
end

-- The plaque's face: a thin part at the slate, its two lines of cut letters.
local function plaqueOn(mark: BasePart)
	if plaqueLabels[mark] or not folder then
		return
	end
	local w = tonumber(mark:GetAttribute("W")) or 4.6
	local h = tonumber(mark:GetAttribute("H")) or 1.3
	local face = Create("Part", {
		Name = "ThronePlaque",
		Size = Vector3.new(w, h, 0.05),
		CFrame = mark.CFrame,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	}) :: BasePart
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 60,
		LightInfluence = 1,
		MaxDistance = 90,
		Parent = face,
	})
	local function line(name: string, y: number, height: number, weight: Enum.Font): TextLabel
		return Create("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.04, y),
			Size = UDim2.fromScale(0.92, height),
			TextColor3 = CUT,
			TextScaled = true,
			FontFace = WorldFont.face(weight),
			Parent = gui,
		}) :: TextLabel
	end
	local labels =
		{ name = line("Name", 0.06, 0.52, Enum.Font.GothamBlack), wins = line("Wins", 0.62, 0.3, Enum.Font.GothamBold) }
	labels.name.Text = plaqueText.name
	labels.wins.Text = plaqueText.wins
	plaqueLabels[mark] = labels
	mark.Destroying:Connect(function()
		plaqueLabels[mark] = nil
		face:Destroy()
	end)
end

local function writePlaque(name: string, wins: string)
	plaqueText = { name = name, wins = wins }
	for _, labels in pairs(plaqueLabels) do
		labels.name.Text = name
		labels.wins.Text = wins
	end
end

-- What the plaque says now (the name, the wins line).
function Champion.plaque(): (string, string)
	return plaqueText.name, plaqueText.wins
end

-- Seats this player (by user id) on the throne; nil or 0 leaves it empty.
function Champion.set(userId: number?)
	local id = if userId and userId > 0 then userId else nil
	if id == wanted and (id == nil or seated == id) then
		return
	end
	wanted = id
	if not id then
		clear()
		return
	end
	task.spawn(build, id)
end

-- Who sits there now (nil while it is empty or still being made).
function Champion.seated(): number?
	return seated
end

function Champion.init()
	folder = Create("Folder", { Name = "DeathsGambitChampion", Parent = workspace })
	Net.event("Leaderboard").OnClientEvent:Connect(function(boards)
		local wins = if type(boards) == "table" then boards.wins else nil
		local first = if type(wins) == "table" then wins[1] else nil
		local ok = type(first) == "table" and type(first.userId) == "number" and first.userId > 0
		Champion.set(if ok then first.userId else nil)
		if ok then
			local count = tonumber(first.value) or 0
			writePlaque(
				string.upper(tostring(first.name or "")),
				string.format("%d %s", count, if count == 1 then "WIN" else "WINS")
			)
		else
			writePlaque(EMPTY, "")
		end
	end)
	for _, item in ipairs(CollectionService:GetTagged(PLAQUE_TAG)) do
		if item:IsA("BasePart") then
			plaqueOn(item)
		end
	end
	CollectionService:GetInstanceAddedSignal(PLAQUE_TAG):Connect(function(item)
		if item:IsA("BasePart") then
			plaqueOn(item)
		end
	end)
	-- The lobby is put up again now and then (a rebuild): the figure follows its seat.
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function()
		local id = wanted
		if id then
			wanted = nil
			clear()
			Champion.set(id)
		end
	end)
end

return Champion
