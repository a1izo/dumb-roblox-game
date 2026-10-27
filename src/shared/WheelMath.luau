--!strict
-- The emote wheel's arithmetic (UI/Wheel draws it): which of its slots a pointer, a stick or a finger points at,
-- and where each slot sits round the middle. Pure, so the specs pin it.
-- Directions are in screen axes (x to the right, y down); angles are degrees clockwise from straight up, so
-- slot 1 is at the top and the rest follow clockwise, like the keys 1 to 4.

local WheelMath = {}

WheelMath.SLOTS = 4

-- The angle of a direction, 0 to 360, clockwise from straight up.
function WheelMath.angle(dx: number, dy: number): number
	return math.deg(math.atan2(dx, -dy)) % 360
end

-- The slot a direction points at (1 at the top, then clockwise), or nil inside the dead zone (as far from the
-- middle as `deadZone`, in the same units as the direction).
function WheelMath.slot(dx: number, dy: number, deadZone: number, count: number?): number?
	local n = count or WheelMath.SLOTS
	if math.sqrt(dx * dx + dy * dy) < deadZone then
		return nil
	end
	local step = 360 / n
	return math.floor(((WheelMath.angle(dx, dy) + step / 2) % 360) / step) + 1
end

-- Where a slot's middle is round the wheel: a unit direction in screen axes.
function WheelMath.place(index: number, count: number?): Vector2
	local n = count or WheelMath.SLOTS
	local radians = math.rad((index - 1) * 360 / n)
	return Vector2.new(math.sin(radians), -math.cos(radians))
end

return WheelMath
