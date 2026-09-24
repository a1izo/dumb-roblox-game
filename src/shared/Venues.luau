--!strict
-- Where each place is built in the world. The server builds at these origins; clients use
-- them to know which venue the camera is in (for lighting, rain and music).

local Venues = {}

Venues.LOBBY = Vector3.new(0, 0.2, 0)
Venues.MAP = Vector3.new(0, 0, 1000)
Venues.MEETING = Vector3.new(700, 0, 0)

-- Half-size of the meeting room around its origin (the room is 60 x 60).
local MEETING_HALF = 45

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

return Venues
