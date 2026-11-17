--!strict
-- The VFX kit's envelope (the plan's Part 3, rule 1): every effect has its moments on purpose, so a recipe is built from
-- them and has them by construction. Moment.play runs the parts on the kit's clock (Clock) round one hit time:
--
--   gather   `lead` seconds BEFORE the hit (default 0.2): something drawn in, a dimming
--   hit      the beat: the largest and brightest layer, the light, the shake
--   body     just after the hit (default 0.05 s): what follows it, the lingering and the break-up
--   residue  later (default 0.4 s after the hit): what is left behind, which outlives the rest by seconds
--
-- Every part is optional and is called as part(at, moment) with the point the effect is at. The hit lands `lead` seconds
-- after play is called (the caller starts it early enough; with lead 0 the gather and the hit are the same moment). Parts
-- at the same moment run in this order: gather, hit, body, residue. A part that fails is warned about and the others go on.
-- The effect probe records an emitter's time as it is made, so each part's emitters land on its moment by construction.

local Clock = require(script.Parent.Clock)

local Moment = {}

Moment.LEAD = 0.2
Moment.BODY_AFTER = 0.05
Moment.RESIDUE_AFTER = 0.4

export type Part = (at: CFrame | Vector3, moment: string) -> ()
export type Parts = {
	gather: Part?,
	hit: Part?,
	body: Part?,
	residue: Part?,
	lead: number?, -- seconds from the start to the hit
	bodyAfter: number?, -- seconds from the hit to the body
	residueAfter: number?, -- seconds from the hit to the residue
}

-- One entry of the timeline: the moment's name and the seconds from the start at which it runs.
export type Entry = { name: string, at: number }

local ORDER = { "gather", "hit", "body", "residue" }

-- The moments `parts` has, in the order they run, each with its time from the start (the hit at `lead`). Pure.
function Moment.timeline(parts: Parts): { Entry }
	local lead = math.max(0, parts.lead or Moment.LEAD)
	local at = {
		gather = 0,
		hit = lead,
		body = lead + math.max(0, parts.bodyAfter or Moment.BODY_AFTER),
		residue = lead + math.max(0, parts.residueAfter or Moment.RESIDUE_AFTER),
	}
	local list: { Entry } = {}
	for _, name in ipairs(ORDER) do
		if (parts :: any)[name] ~= nil then
			table.insert(list, { name = name, at = at[name] })
		end
	end
	-- (a body or residue set earlier than the hit by odd options still never runs before it: keep the list in time order,
	-- ties in the order above; table.sort is not stable, so the position breaks them)
	local position: { [Entry]: number } = {}
	for index, entry in ipairs(list) do
		position[entry] = index
	end
	table.sort(list, function(a, b)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return position[a] < position[b]
	end)
	return list
end

-- Starts the moments round a hit `lead` seconds from now, at `at`. Returns a function that cancels what has not yet run.
function Moment.play(at: CFrame | Vector3, parts: Parts): () -> ()
	local list = Moment.timeline(parts)
	local cancelled = false
	local began = Clock.now()
	local nextIndex = 1

	local function run(entry: Entry)
		local part = (parts :: any)[entry.name]
		local ok, result = pcall(part, at, entry.name)
		if not ok then
			warn("[DeathsGambit] VFX moment " .. entry.name .. " failed: " .. tostring(result))
		end
	end

	-- (the moments due now, the gather and, with no lead, the hit too, run before play returns)
	while nextIndex <= #list and list[nextIndex].at <= 0 do
		run(list[nextIndex])
		nextIndex += 1
	end
	if nextIndex > #list then
		return function() end
	end
	local stopClock = Clock.every(function(_, now)
		if cancelled then
			return false
		end
		while nextIndex <= #list and now - began >= list[nextIndex].at do
			local entry = list[nextIndex]
			nextIndex += 1
			run(entry)
			if cancelled then
				return false
			end
		end
		return nextIndex <= #list
	end)
	return function()
		cancelled = true
		stopClock()
	end
end

return Moment
