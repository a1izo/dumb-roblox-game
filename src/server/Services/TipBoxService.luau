-- The anonymous tip box at headquarters. Anyone may drop a typed note; only L reads
-- them and never sees who sent them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))

local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)
local TextFilter = require(script.Parent.TextFilter)

local TipRemote = Net.event("Tip")
local LInboxRemote = Net.event("LInbox")

local TipBoxService = {}

local function onTip(player: Player, text)
	if type(text) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	local map = Match.map
	if not ps or not map or Match.phase ~= "Investigation" then
		return
	end
	local position = Match.position(ps)
	if not position or (position - map.tipBox.position).Magnitude > Config.INTERACT_RANGE + 2 then
		Match.notify(player, "Walk up to the tip box first.", "bad")
		return
	end
	local cleaned = Util.cleanText(text, Config.TIP_MAX_LENGTH)
	if #cleaned == 0 then
		return
	end
	if not RateLimit.allow(player, "tip", Config.TIP_COOLDOWN) then
		Match.notify(player, "The slot is jammed. Try again in a few seconds.", "bad")
		return
	end
	EventLog.add(string.format("%s (%s) dropped a tip in the box.", ps.alias, Terms.role(ps.role)), "tip")
	Match.notify(player, "Your tip dropped into the box.", "info")
	local l = Match.findRole("L")
	if not l or not l.alive then
		return
	end
	local filtered = TextFilter.forUser(cleaned, player.UserId, l.userId)
	if filtered then
		LInboxRemote:FireClient(l.player, {
			kind = "tip",
			text = filtered,
			round = Match.round,
			clock = Match.clock(),
		})
	end
end

function TipBoxService.init()
	TipRemote.OnServerEvent:Connect(onTip)
end

return TipBoxService
