-- Per-player cooldowns for remote requests. Weak keys drop players who left.

local RateLimit = {}

local lastUse = setmetatable({}, { __mode = "k" })

function RateLimit.allow(player: Player, key: string, cooldown: number): boolean
	local now = os.clock()
	local times = lastUse[player]
	if not times then
		times = {}
		lastUse[player] = times
	end
	local last = times[key]
	if last and now - last < cooldown then
		return false
	end
	times[key] = now
	return true
end

return RateLimit
