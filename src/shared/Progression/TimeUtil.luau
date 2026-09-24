--!strict
-- UTC day and week numbers for streaks, quests, the shop rotation and weekly boards.
-- Weeks start on Monday. offset (seconds) lets Studio tests jump ahead (/day +1).

local TimeUtil = {}

local DAY = 86400
local offset = 0

function TimeUtil.setOffset(seconds: number)
	offset = seconds
end

function TimeUtil.offset(): number
	return offset
end

-- The current unix time, with the test offset.
function TimeUtil.now(): number
	return os.time() + offset
end

function TimeUtil.day(unixTime: number): number
	return math.floor(unixTime / DAY)
end

-- 1970-01-01 was a Thursday, so shift by 3 days to start weeks on Monday.
function TimeUtil.week(unixTime: number): number
	return math.floor((unixTime / DAY + 3) / 7)
end

function TimeUtil.secondsToNextDay(unixTime: number): number
	return DAY - (unixTime % DAY)
end

function TimeUtil.secondsToNextWeek(unixTime: number): number
	local days = unixTime / DAY + 3
	local nextWeekStart = (math.floor(days / 7) + 1) * 7
	return math.max(0, math.floor((nextWeekStart - days) * DAY))
end

return TimeUtil
