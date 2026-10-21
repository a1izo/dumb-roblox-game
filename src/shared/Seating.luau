--!strict
-- Sitting at the war table (shop overhaul, 2026-10-21; the owner's call: everyone sits for a meeting and the
-- vote). Each living player keeps one place round the table all match (MeetingService); for a meeting they sit in
-- the chair behind it: their root stands over the chair, a little behind its middle, and the seat clip they wear
-- (the "Seat" attribute, read by LocomotionController as the body's base layer) drops the body onto the cushion.
--
-- Every chair a body can sit in shares the war chair's seat as the war room places it: the WarChair at 1.3 (so an
-- R6 body, four studs across with its arms, fits between its arms; art/scripts/maps/venues/meeting/furnish.py),
-- the cushion's top 2.56 high, and every chair skin (Cosmetics kind "chair") built to the same seat
-- (art/scripts/props_seats.py). The seat clips are made for that seat (art/scripts/emotes/seats.py).

local ModelLibrary = require(script.Parent.ModelLibrary)

local Seating = {}

Seating.ATTRIBUTE = "Seat" -- on a character: the seat clip it sits in
Seating.DEFAULT = "seatPlain" -- everyone's seat (the item seat_plain)
Seating.SCALE = 1.3 -- the war room's chairs
-- A chair stands this far behind its place at the table (the places round the table at radius 17, the chairs at
-- 19.6, on the same lines out from the middle).
Seating.CHAIR_BEHIND = 2.6
-- Where the body's root stands, behind the chair's middle (so the torso's back meets the chair's back).
Seating.ROOT_BEHIND = 0.32
Seating.STAND_TIME = 0.5 -- seconds a body takes to get up out of its chair and step to its place

-- The chair behind a place at the table (its floor, facing the table like the place does).
function Seating.chair(place: CFrame): CFrame
	return place * CFrame.new(0, 0, Seating.CHAIR_BEHIND)
end

-- Where a body sitting in that chair stands (the floor under its root; CharacterService.placeAt lifts it).
function Seating.body(place: CFrame): CFrame
	return Seating.chair(place) * CFrame.new(0, 0, Seating.ROOT_BEHIND)
end

-- A chair to sit a body in, for a preview: the chair skin `item` (Cosmetics kind "chair") when the imported Core set
-- has it, else the war chair at the war room's scale; nil when neither is imported. Facing -Z, its pivot on the
-- floor under the chair's middle.
function Seating.chairModel(item: any?): Model?
	if item and type(item.model) == "string" and ModelLibrary.version("ModelsCore") >= (item.core or 0) then
		local skin = ModelLibrary.get(item.model)
		if skin then
			return skin
		end
	end
	local chair = ModelLibrary.get("WarChair")
	if chair then
		chair:ScaleTo(chair:GetScale() * Seating.SCALE)
	end
	return chair
end

-- Where a chair stands under a body whose root is at `root` (a preview: the root standing over the floor, as
-- CharacterService.placeAt leaves it, `rootHeight` above it).
function Seating.chairUnder(root: CFrame, rootHeight: number): CFrame
	return root * CFrame.new(0, -rootHeight, -Seating.ROOT_BEHIND)
end

return Seating
