--!strict
-- The case-file station types and the puzzles each one can give. Every list of station types
-- in the game (the map contract, station colours, the Academy drills, How to Play) reads from
-- here, so a new type is added in one place.
--
-- The server picks a puzzle from the station's pool for every task and sends it as an id and a
-- seed; both sides build the same puzzle from them (Tasks/Puzzles), so the server can check
-- the answer.

local TaskTypes = {}

export type Info = {
	id: string,
	label: string, -- shown on the station screen and the task window
	color: Color3,
	icon: string, -- an icon name (Shared/UI/Icons)
	puzzles: { string }, -- puzzle ids (Tasks/Puzzles/<id>)
	drill: string, -- the Academy drill id
	drillTitle: string,
	blurb: string, -- what its clue tells you (How to Play)
}

TaskTypes.LIST = { "Camera", "Fingerprint", "Phone", "Forensics" }

TaskTypes.INFO = {
	Camera = {
		id = "Camera",
		label = "Camera footage",
		color = Color3.fromRGB(96, 150, 235),
		icon = "camera",
		puzzles = { "Timeline", "Enhance", "VSync", "Rewind" },
		drill = "camera",
		drillTitle = "CAMERA FOOTAGE",
		blurb = "who was seen where, and when",
	},
	Fingerprint = {
		id = "Fingerprint",
		label = "Fingerprints",
		color = Color3.fromRGB(96, 200, 150),
		icon = "fingerprint",
		puzzles = { "PrintMatch", "Dust", "Overlay", "Minutiae" },
		drill = "fingerprint",
		drillTitle = "FINGERPRINTS",
		blurb = "who handled a note or worked a station",
	},
	Phone = {
		id = "Phone",
		label = "Phone records",
		color = Color3.fromRGB(230, 170, 70),
		icon = "phone",
		puzzles = { "Dial", "Wiretap", "CallLog", "Cipher" },
		drill = "phone",
		drillTitle = "PHONE RECORDS",
		blurb = "the length of the Hand's names and where a burner phone pinged",
	},
	Forensics = {
		id = "Forensics",
		label = "Forensics",
		color = Color3.fromRGB(200, 90, 200),
		icon = "forensics",
		puzzles = { "Chromatography", "Microscope", "Handwriting", "Autopsy" },
		drill = "forensics",
		drillTitle = "FORENSICS",
		blurb = "whose ink wrote the last name in the Grimoire",
	},
} :: { [string]: Info }

-- Each station type needs at least this many stations on a map.
TaskTypes.MIN_PER_MAP = 2
-- Stations on every map.
TaskTypes.STATIONS_PER_MAP = 10

function TaskTypes.exists(id: any): boolean
	return type(id) == "string" and TaskTypes.INFO[id] ~= nil
end

-- The type's info. Unknown types are a bug in a map's layout, so they fail loudly.
function TaskTypes.get(id: string): Info
	local info = TaskTypes.INFO[id]
	if not info then
		error("unknown station type " .. tostring(id), 2)
	end
	return info
end

-- A puzzle id for a task at a station of this type.
function TaskTypes.pickPuzzle(id: string, rng: Random): string
	local pool = TaskTypes.get(id).puzzles
	return pool[rng:NextInteger(1, #pool)]
end

-- The station type an Academy drill practises, or nil.
function TaskTypes.forDrill(drill: string): string?
	for _, id in ipairs(TaskTypes.LIST) do
		if TaskTypes.INFO[id].drill == drill then
			return id
		end
	end
	return nil
end

return TaskTypes
