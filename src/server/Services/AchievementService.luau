-- Roblox badges for achievements. Unlocking marks a badge as pending in the profile; the
-- award is tried at once and again on every join until Roblox accepts it.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"):WaitForChild("Achievements"))

local DataService = require(script.Parent.DataService)

local AchievementService = {}

local busy: { [Player]: boolean } = {}

local function award(player: Player, badgeId: number): boolean
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			if BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				return true
			end
			return BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if ok and result then
			return true
		end
		task.wait(attempt)
	end
	return false
end

function AchievementService.awardPending(player: Player)
	if busy[player] then
		return
	end
	local data = DataService.get(player)
	if not data or next(data.pendingBadges) == nil then
		return
	end
	busy[player] = true
	task.spawn(function()
		local changed = false
		for id in pairs(table.clone(data.pendingBadges)) do
			local achievement = Achievements.byId(id)
			-- Drop entries without a badge, and the ones Roblox has accepted.
			local done = not achievement or achievement.badgeId == 0 or award(player, achievement.badgeId)
			if done then
				data.pendingBadges[id] = nil
				changed = true
			end
		end
		busy[player] = nil
		if changed then
			DataService.saveSoon(player)
		end
	end)
end

function AchievementService.init()
	DataService.ProfileLoaded:Connect(function(player)
		AchievementService.awardPending(player)
	end)
end

return AchievementService
