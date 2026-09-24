--!strict
-- Private-server settings the owner can change with the Director pass, and their ranges.
-- clamp() turns anything a client sends into valid settings.

local SettingsSchema = {}

export type Settings = {
	rounds: number,
	investigation: number,
	grimoire: number,
	meeting: number,
	vote: number,
	maps: { string },
}

SettingsSchema.RANGES = {
	rounds = { min = 3, max = 7, step = 1, default = 5, label = "Rounds" },
	investigation = { min = 60, max = 180, step = 10, default = 100, label = "Investigation (s)" },
	grimoire = { min = 15, max = 40, step = 5, default = 20, label = "Grimoire phase (s)" },
	meeting = { min = 30, max = 120, step = 10, default = 60, label = "Meeting (s)" },
	vote = { min = 15, max = 40, step = 5, default = 20, label = "Vote (s)" },
}

SettingsSchema.ORDER = { "rounds", "investigation", "grimoire", "meeting", "vote" }

SettingsSchema.MAPS = { "TaskForceHQ", "UniversityCampus", "TokyoDistrict" }

function SettingsSchema.defaults(): Settings
	local R = SettingsSchema.RANGES
	return {
		rounds = R.rounds.default,
		investigation = R.investigation.default,
		grimoire = R.grimoire.default,
		meeting = R.meeting.default,
		vote = R.vote.default,
		maps = table.clone(SettingsSchema.MAPS),
	}
end

local function clampNumber(value: any, range): number
	local n = tonumber(value) or range.default
	if n ~= n then
		n = range.default
	end
	n = math.clamp(n, range.min, range.max)
	return range.min + math.floor((n - range.min) / range.step + 0.5) * range.step
end

function SettingsSchema.clamp(input: any): Settings
	local result = SettingsSchema.defaults()
	if type(input) ~= "table" then
		return result
	end
	for key, range in pairs(SettingsSchema.RANGES) do
		(result :: any)[key] = clampNumber(input[key], range)
	end
	if type(input.maps) == "table" then
		local maps = {}
		for _, id in ipairs(SettingsSchema.MAPS) do
			if table.find(input.maps, id) then
				table.insert(maps, id)
			end
		end
		if #maps > 0 then
			result.maps = maps
		end
	end
	return result
end

-- True when the settings differ from the defaults (then only participation rewards pay out).
function SettingsSchema.isCustom(settings: Settings): boolean
	local defaults = SettingsSchema.defaults()
	for key in pairs(SettingsSchema.RANGES) do
		if (settings :: any)[key] ~= (defaults :: any)[key] then
			return true
		end
	end
	return #settings.maps ~= #defaults.maps
end

return SettingsSchema
