--!strict
-- Who plays which part in a cutscene (art/scripts/cinema shots). The server casts; every client is
-- sent the same cast, so everyone sees the same thing.
--
-- A shot's actors have slots: named parts ("noticer", "victim", "self"...) and crowd places
-- ("everyone:1", "everyone:2"..., filled in order, the most visible first). `fixed` gives some
-- named parts to particular players (the victim, a role cutscene's own player); the other named
-- parts are drawn at random from the rest, never by role. Extras (faceless stand-ins) need no one.

local Casting = {}

local function crowdIndex(slot: string): number?
	local n = string.match(slot, "^everyone:(%d+)$")
	return if n then tonumber(n) else nil
end

-- The slots of a shot, named parts first (in the shot's order), then the crowd in order.
function Casting.slots(shot: any): ({ string }, { string })
	local named, crowd = {}, {}
	for _, actor in ipairs(shot.actors or {}) do
		if not actor.extra then
			if crowdIndex(actor.slot) then
				table.insert(crowd, actor.slot)
			elseif not table.find(named, actor.slot) then
				table.insert(named, actor.slot)
			end
		end
	end
	table.sort(crowd, function(a, b)
		return (crowdIndex(a) :: number) < (crowdIndex(b) :: number)
	end)
	return named, crowd
end

-- slot -> userId. `players` are the user ids that may appear; `fixed` pins named parts; named parts
-- not in `fixed` and not in `random` stay empty (they are filled by the caller or shown empty).
function Casting.cast(
	shot: any,
	players: { number },
	rng: Random,
	fixed: { [string]: number }?,
	randomParts: { string }?
): { [string]: number }
	local cast: { [string]: number } = {}
	local used: { [number]: boolean } = {}
	for slot, userId in pairs(fixed or {}) do
		cast[slot] = userId
		used[userId] = true
	end
	local pool = {}
	for _, userId in ipairs(players) do
		if not used[userId] then
			table.insert(pool, userId)
		end
	end
	-- shuffle, so who stands where says nothing about anyone
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local named, crowd = Casting.slots(shot)
	for _, slot in ipairs(named) do
		if not cast[slot] and (randomParts == nil or table.find(randomParts, slot)) and #pool > 0 then
			cast[slot] = table.remove(pool, 1) :: number
		end
	end
	for _, slot in ipairs(crowd) do
		if #pool == 0 then
			break
		end
		cast[slot] = table.remove(pool, 1) :: number
	end
	return cast
end

return Casting
