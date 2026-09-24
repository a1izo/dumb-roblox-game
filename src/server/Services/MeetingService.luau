-- The Task Force meeting: living players gather around the table and free chat opens.
-- L speaks through the anonymous screen, which never shows who is typing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent.CharacterService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local RagdollService = require(script.Parent.RagdollService)
local RateLimit = require(script.Parent.RateLimit)
local TextFilter = require(script.Parent.TextFilter)

local LScreenRemote = Net.event("LScreen")
local LScreenMsgRemote = Net.event("LScreenMsg")

local MeetingService = {}

local screenLabel: TextLabel? = nil
local seats = {}

function MeetingService.onMatchStart(map)
	screenLabel = map.meeting.screenLabel
	seats = map.meeting.seats
	if screenLabel then
		screenLabel.Text = Terms.f("{Zero} is watching.")
	end
end

function MeetingService.onMatchEnd()
	screenLabel = nil
	seats = {}
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

local function onScreen(player: Player, text)
	if type(text) ~= "string" then
		return
	end
	local l = Match.getLiving(player)
	if not l or l.role ~= "L" then
		return
	end
	if Match.phase ~= "Meeting" and Match.phase ~= "Vote" then
		Match.notify(player, "The screen only works during meetings.", "bad")
		return
	end
	local cleaned = Util.cleanText(text, Config.L_SCREEN_MAX_LENGTH)
	if #cleaned == 0 then
		return
	end
	if not RateLimit.allow(player, "lscreen", Config.L_SCREEN_COOLDOWN) then
		Match.notify(player, "Wait a moment before sending again.", "bad")
		return
	end
	for _, ps in ipairs(Match.living()) do
		if NameUtil.containsFullName(cleaned, ps.first, ps.last) then
			Match.notify(player, "Blocked: messages may not contain a living player's full real name.", "bad")
			return
		end
	end
	local filtered = TextFilter.broadcast(cleaned, player.UserId)
	if not filtered then
		Match.notify(player, "The screen could not display that message.", "bad")
		return
	end
	if screenLabel then
		screenLabel.Text = filtered
	end
	LScreenMsgRemote:FireAllClients({ text = filtered, clock = Match.clock() })
	EventLog.add('L on the screen: "' .. filtered .. '"', "l")
end

function MeetingService.init()
	LScreenRemote.OnServerEvent:Connect(onScreen)
end

return MeetingService
