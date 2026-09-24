-- The Task Force meeting: living players gather around the table and free chat opens.
-- L speaks through the anonymous screen, which never shows who is typing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent.CharacterService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
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
		screenLabel.Text = "L is watching."
	end
end

function MeetingService.onMatchEnd()
	screenLabel = nil
	seats = {}
	for _, ps in ipairs(Match.list) do
		ps.seatCFrame = nil
	end
end

-- Moves every living player to a seat around the table and freezes them there.
function MeetingService.gather()
	if #seats == 0 then
		return
	end
	for i, ps in ipairs(Match.living()) do
		ps.seatCFrame = seats[((i - 1) % #seats) + 1]
		CharacterService.placeAt(ps.player, ps.seatCFrame)
		CharacterService.setFrozen(ps.player, true)
	end
end

function MeetingService.release()
	for _, ps in ipairs(Match.list) do
		ps.seatCFrame = nil
	end
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
	EventLog.add("L on the screen: \"" .. filtered .. "\"", "l")
end

function MeetingService.init()
	LScreenRemote.OnServerEvent:Connect(onScreen)
end

return MeetingService
