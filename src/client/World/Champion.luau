--!strict
-- Whoever has the most wins sits on the bone throne behind the title, in stone: a grey figure in the shape
-- of their avatar (its outline and accessories; no colours, no face), a little larger than life, looking out
-- over the plaza. The throne is empty until the board has someone on it. The seat is the server's mark
-- (Maps/LobbyFixtures, tag LThroneSeat); the name comes with the leaderboards every client is sent. Built
-- on this client only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))

local StoneFigures = require(script.Parent.StoneFigures)

local Champion = {}

local TAG = "LThroneSeat"
local SCALE = 1.5
-- Into the "sit" clip: a settled moment of it.
local SIT_AT = 1.0

local figure: StoneFigures.Figure? = nil
local seated: number? = nil
local wanted: number? = nil
local folder: Folder? = nil

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
	-- The hips rest on the seat: the feet of a standing figure would be two (scaled) studs lower; and a
	-- little back, against the throne's back.
	local feet = mark.CFrame * CFrame.new(0, -2 * SCALE, 0.6)
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
	StoneFigures.pose(made, "sit", SIT_AT, { travel = false })
	figure = made
	seated = userId
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
		Champion.set(if type(first) == "table" and type(first.userId) == "number" then first.userId else nil)
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
