--!strict
-- Where each place is built in the world. The server builds at these origins; clients use
-- them to know which venue the camera is in (for lighting, rain and music).

local Venues = {}

Venues.LOBBY = Vector3.new(0, 0.2, 0)
Venues.MAP = Vector3.new(0, 0, 1000)
Venues.MEETING = Vector3.new(700, 0, 0)

-- Half-size of the meeting room around its origin (the room is 60 x 60).
local MEETING_HALF = 45

-- Where Specters may fly, relative to each venue's origin: a map's outer walls up to its
-- ceiling (the highest rooftop on the outdoor maps), and the meeting room itself. They pass
-- through everything inside, but never out of the place.
local SPECTER_BOUNDS = {
	TaskForceHQ = { Vector3.new(-80, 0, -60), Vector3.new(80, 14, 60) },
	UniversityCampus = { Vector3.new(-110, 0, -90), Vector3.new(110, 30, 90) },
	TokyoDistrict = { Vector3.new(-110, 0, -90), Vector3.new(110, 40, 90) },
	meeting = { Vector3.new(-30, 0, -30), Vector3.new(30, 18, 30) },
	-- A map with no entry of its own.
	fallback = { Vector3.new(-125, 0, -105), Vector3.new(125, 60, 105) },
}

-- "lobby", "map" or "meeting" for a world position.
function Venues.at(position: Vector3): string
	local offset = position - Venues.MEETING
	if math.abs(offset.X) <= MEETING_HALF and math.abs(offset.Z) <= MEETING_HALF then
		return "meeting"
	end
	if position.Z > Venues.MAP.Z - 300 then
		return "map"
	end
	return "lobby"
end

-- The box Specters are kept inside at a venue ("map" or "meeting"; maps need their id), as
-- world-space corners.
function Venues.specterBounds(venue: string, mapId: string?): (Vector3, Vector3)
	if venue == "meeting" then
		local box = SPECTER_BOUNDS.meeting
		return Venues.MEETING + box[1], Venues.MEETING + box[2]
	end
	local box = SPECTER_BOUNDS[mapId or ""] or SPECTER_BOUNDS.fallback
	return Venues.MAP + box[1], Venues.MAP + box[2]
end

-- The nearest point to `position` inside a box shrunk by `inset` on every side.
function Venues.clampInto(position: Vector3, min: Vector3, max: Vector3, inset: number?): Vector3
	local pad = Vector3.one * (inset or 0)
	local low, high = min + pad, max - pad
	return Vector3.new(
		math.clamp(position.X, low.X, math.max(low.X, high.X)),
		math.clamp(position.Y, low.Y, math.max(low.Y, high.Y)),
		math.clamp(position.Z, low.Z, math.max(low.Z, high.Z))
	)
end

return Venues
