-- How sheltered the player is from the weather, and where the shelter is: the boxes the map
-- builder tagged as cover (awnings, a tree's crown) in an index the rain and snow ask, and one
-- number for the camera's focus: 0 in the open, about 0.5 under a roof or a crown with its sides
-- open (an arcade, an awning, a bridge), 1 inside a building. The rain loop, the thunder and the
-- muffling of everything heard from outside follow it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoverIndex = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"):WaitForChild("CoverIndex"))

local ClientState = require(script.Parent.Parent.ClientState)
local LightingController = require(script.Parent.LightingController)

local COVER_TAG = "LRainCover"
local BOT_TAG = "LBotCharacter"
local UPDATE = 0.15 -- seconds between looks at where the camera is
local RAY_UP = 90
-- Maps whose every room is inside a building with the weather behind glass (the tower).
local ALWAYS_INSIDE = { TaskForceHQ = true }

local Shelter = {}

local index = CoverIndex.new()
local boxes: { [BasePart]: CoverIndex.Box } = {}
local level = 0
local cover = 0 -- how much the camera's spot is covered, 0 to 1 (without the room it is in)
local lastUpdate = 0

function Shelter.index(): CoverIndex.Index
	return index
end

-- The shelter at the camera's focus: 0 open, 0.5 under a roof, 1 inside.
function Shelter.level(): number
	return level
end

-- How much is over the camera's spot (0 to 1), whatever room it is in.
function Shelter.cover(): number
	return cover
end

-- True when the player is inside a building (the rain does not fall there, thunder is far off).
function Shelter.indoors(): boolean
	return level >= 0.95
end

local function track(part: Instance)
	if not part:IsA("BasePart") or boxes[part] then
		return
	end
	local amount = part:GetAttribute("Cover")
	boxes[part] = index:add(part.CFrame, part.Size, if type(amount) == "number" then amount else 1)
end

local function untrack(part: Instance)
	local box = boxes[part :: BasePart]
	if box then
		index:remove(box)
		boxes[part :: BasePart] = nil
	end
end

-- Everything a ray from the camera should not count as a roof: people.
local function excluded(): { Instance }
	local list: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, bot in ipairs(CollectionService:GetTagged(BOT_TAG)) do
		table.insert(list, bot)
	end
	return list
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- The raycast filter for the weather's rays (people excluded), refreshed now and then.
function Shelter.rayParams(): RaycastParams
	return rayParams
end

local function mapId(): string?
	local id = ClientState.public.mapId
	if type(id) == "string" and id ~= "" then
		return id
	end
	local model = workspace:FindFirstChild("LGameMap")
	local built = if model then model:GetAttribute("MapId") else nil
	return if type(built) == "string" then built else nil
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	rayParams.FilterDescendantsInstances = excluded()
	local subject = camera.CameraSubject
	local focus = if subject
			and subject:IsA("Humanoid")
			and subject.RootPart
		then subject.RootPart.Position
		else camera.Focus.Position
	-- A few spots round the focus, so the edge of a roof shelters a little, not all at once.
	local sheltered, count = 0, 0
	for _, offset in ipairs({ Vector3.zero, Vector3.new(1.6, 0, 0), Vector3.new(-1.6, 0, 0), Vector3.new(0, 0, 1.6) }) do
		local at = focus + offset + Vector3.new(0, 1, 0)
		local amount = if workspace:Raycast(at, Vector3.new(0, RAY_UP, 0), rayParams) then 1 else 0
		sheltered += math.max(amount, index:above(at))
		count += 1
	end
	cover = sheltered / count
	local zone = LightingController.zone()
	local inside = if zone and string.sub(zone, -7) == "_Inside" then 1 else 0
	local id = mapId()
	if id and ALWAYS_INSIDE[id] and LightingController.venue() == "map" then
		inside = 1
	end
	-- Under a roof is half way in; the room's own look (a shop, a hall) is all the way.
	local target = math.max(inside, 0.5 * cover)
	level = target
end

function Shelter.init()
	for _, part in ipairs(CollectionService:GetTagged(COVER_TAG)) do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal(COVER_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(COVER_TAG):Connect(untrack)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastUpdate >= UPDATE then
			lastUpdate = now
			update()
		end
	end)
end

return Shelter
