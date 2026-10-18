-- The Bureau meeting. Free roam stops for one when someone dies, when a living player rings the
-- map's emergency bell (once each per match), or when the free-roam timer runs out. Living players
-- gather around the table in the meeting room, talk, then vote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local CharacterService = require(script.Parent.CharacterService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local RagdollService = require(script.Parent.RagdollService)
local RateLimit = require(script.Parent.RateLimit)

local BellRemote = Net.event("Bell")

local MeetingService = {}

local screenLabel: TextLabel? = nil
local seats = {}
local bell: BasePart? = nil

function MeetingService.onMatchStart(map)
	screenLabel = map.meeting.screenLabel
	seats = map.meeting.seats
	bell = if map.bell then map.bell.part else nil
	if screenLabel then
		screenLabel.Text = Terms.f("{Meeting}")
	end
end

function MeetingService.onMatchEnd()
	screenLabel = nil
	seats = {}
	bell = nil
	for _, ps in ipairs(Match.list) do
		ps.seatCFrame = nil
	end
end

-- Everyone keeps the same place at the table all match, so the places of the dead stay empty.
local function seatFor(index: number): CFrame
	return seats[((index - 1) % #seats) + 1]
end

-- Moves every living player to their place around the table and freezes them there.
function MeetingService.gather()
	if #seats == 0 then
		return
	end
	for i, ps in ipairs(Match.list) do
		if ps.alive then
			ps.seatCFrame = seatFor(i)
			CharacterService.placeAt(ps.player, ps.seatCFrame)
			CharacterService.setFrozen(ps.player, true)
		end
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

-- The meeting is over: bodies are taken away and the empty places are marked.
function MeetingService.release()
	for _, ps in ipairs(Match.list) do
		ps.seatCFrame = nil
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
		Match.notify(player, "You have already rung the bell this match.", "bad")
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
