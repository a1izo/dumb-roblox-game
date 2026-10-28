-- The Bureau meeting. Free roam stops for one when someone dies, when a living player rings the
-- map's emergency bell (once each per match), or when the free-roam timer runs out. Living players
-- gather around the table in the meeting room, sit down in their chairs (Shared/Seating: the seat they wear),
-- talk, then vote. Each player's place keeps the chair they wear (a chair skin) all match, for everyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Models = require(Shared:WaitForChild("Models"))
local Net = require(Shared:WaitForChild("Net"))
local Seating = require(Shared:WaitForChild("Seating"))
local Terms = require(Shared:WaitForChild("Terms"))

local CharacterService = require(script.Parent.CharacterService)
local CosmeticsService = require(script.Parent.CosmeticsService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local RagdollService = require(script.Parent.RagdollService)
local RateLimit = require(script.Parent.RateLimit)

local BellRemote = Net.event("Bell")

local MeetingService = {}

local screenLabel: TextLabel? = nil
local seats = {}
local bell: BasePart? = nil

-- Everyone keeps the same place at the table all match, so the places of the dead stay empty.
local function seatFor(index: number): CFrame
	return seats[((index - 1) % #seats) + 1]
end

-- Each player's chair skin (Cosmetics kind "chair") takes the place of the war chair behind their place, for
-- everyone, all match. A skin newer than the imported Core set keeps the war chair.
local function dressChairs(map)
	if #seats == 0 or not map.model then
		return
	end
	local warChairs = {}
	for _, item in ipairs(map.model:GetDescendants()) do
		if item:IsA("Model") and item.Name == "WarChair" then
			table.insert(warChairs, item)
		end
	end
	for i, ps in ipairs(Match.list) do
		local skin = if ps.player and i <= #seats then CosmeticsService.chairOf(ps.player) else nil
		local model = if skin and ModelLibrary.version("ModelsCore") >= (skin.core or 0)
			then ModelLibrary.get(skin.model)
			else nil
		if model then
			local at = Seating.chair(seatFor(i))
			for _, chair in ipairs(warChairs) do
				if chair.Parent and (chair:GetPivot().Position - at.Position).Magnitude < 1.5 then
					chair:Destroy()
				end
			end
			model.Name = "ChairSkin"
			model:SetAttribute("Owner", ps.userId)
			model:PivotTo(at)
			model.Parent = map.model
		end
	end
end

function MeetingService.onMatchStart(map)
	screenLabel = map.meeting.screenLabel
	seats = map.meeting.seats
	bell = if map.bell then map.bell.part else nil
	if screenLabel then
		screenLabel.Text = Terms.f("{Meeting}")
	end
	dressChairs(map)
end

local function clearSeat(ps)
	ps.seatClip = nil
	local character = ps.player and ps.player.Character
	if character then
		character:SetAttribute(Seating.ATTRIBUTE, nil)
	end
end

function MeetingService.onMatchEnd()
	screenLabel = nil
	seats = {}
	bell = nil
	for _, ps in ipairs(Match.list) do
		ps.seatCFrame = nil
		clearSeat(ps)
	end
end

-- Moves every living player to their place around the table and freezes them there: standing at it (the meeting
-- intro, the ending), or with `seated` sitting in the chair behind it, in the seat they wear (the meeting and the
-- vote; Shared/Seating).
function MeetingService.gather(seated: boolean?)
	if #seats == 0 then
		return
	end
	for i, ps in ipairs(Match.list) do
		if ps.alive then
			local place = seatFor(i)
			if seated and ps.player then
				ps.seatCFrame = Seating.body(place)
				ps.seatClip = CosmeticsService.seatClip(ps.player)
			else
				ps.seatCFrame = place
				clearSeat(ps)
			end
			CharacterService.placeAt(ps.player, ps.seatCFrame)
			CharacterService.setFrozen(ps.player, true)
			local character = ps.player and ps.player.Character
			if character and ps.seatClip then
				character:SetAttribute(Seating.ATTRIBUTE, ps.seatClip)
			end
		end
	end
end

-- A seated player gets up out of their chair and steps to their place at the table (voted out, or arrested):
-- the seat clip lets go on every screen while the root glides forward (Seating.STAND_TIME).
function MeetingService.standUp(ps)
	if not ps.seatClip then
		return
	end
	local index = table.find(Match.list, ps)
	clearSeat(ps)
	if not index or #seats == 0 then
		return
	end
	local place = seatFor(index)
	ps.seatCFrame = place
	local character = ps.player and ps.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and root.Anchored then
		local goal = root.CFrame - root.Position + (place.Position + (root.Position - Seating.body(place).Position))
		TweenService:Create(
			root,
			TweenInfo.new(Seating.STAND_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = goal }
		):Play()
	else
		CharacterService.placeAt(ps.player, place)
	end
end

-- A card with the alias stands at the place of each player who died.
local function placeMemorials()
	local map = Match.map
	if not map or not map.model or #seats == 0 then
		return
	end
	local folder = map.model:FindFirstChild("Memorials") or Create("Folder", { Name = "Memorials", Parent = map.model })
	for i, ps in ipairs(Match.list) do
		if ps.status == "dead" and not folder:FindFirstChild(tostring(ps.userId)) then
			local memorial = Models.memorial(ps.alias)
			memorial.Name = tostring(ps.userId)
			memorial:PivotTo(seatFor(i))
			memorial.Parent = folder
		end
	end
end

-- The meeting is over: everyone gets up, bodies are taken away and the empty places are marked.
function MeetingService.release()
	for _, ps in ipairs(Match.list) do
		ps.seatCFrame = nil
		clearSeat(ps)
	end
	RagdollService.clearBodies()
	placeMemorials()
end

-- What the meeting room's screen says while the meeting runs (why it was called).
function MeetingService.setScreen(text: string)
	if screenLabel then
		screenLabel.Text = text
	end
end

-- Why this player cannot ring the bell right now (nil: they can).
function MeetingService.bellProblem(ps): string?
	if not bell then
		return "missing"
	elseif Match.phase ~= "Investigation" or Match.meetingCall ~= nil then
		return "phase"
	elseif ps.bellUsed then
		return "used"
	end
	local at = Match.position(ps)
	if not at or (at - bell.Position).Magnitude > Config.BELL_RANGE + 2 then
		return "far"
	end
	-- (and in sight of it: no ringing it through a wall)
	local eye = Match.eyePosition(ps)
	if not eye or not Match.hasLineOfSight(eye, bell.Position, bell.Parent) then
		return "far"
	end
	return nil
end

-- Rings the bell for this player: a meeting is called at once.
function MeetingService.ring(ps): boolean
	if MeetingService.bellProblem(ps) then
		return false
	end
	ps.bellUsed = true
	EventLog.add(string.format("%s rang the emergency bell.", ps.alias), "bell")
	Match.announce(Terms.f("{Meeting} called"), ps.alias .. " rang the emergency bell.", "neutral")
	Match.requestMeeting("bell", ps)
	Match.pushPrivate(ps)
	return true
end

local function onBell(player: Player)
	local ps = Match.getLiving(player)
	if not ps or not RateLimit.allow(player, "bell", 1) then
		return
	end
	local problem = MeetingService.bellProblem(ps)
	if problem == "used" then
		Match.notify(player, "You already rang the bell.", "bad")
	elseif problem == "far" then
		Match.notify(player, "Get closer to the bell.", "bad")
	elseif problem == nil then
		MeetingService.ring(ps)
	end
end

function MeetingService.init()
	BellRemote.OnServerEvent:Connect(onBell)
end

return MeetingService
