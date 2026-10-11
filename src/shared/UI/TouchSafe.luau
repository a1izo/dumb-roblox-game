--!strict
-- On a touch screen Roblox draws its jump button at the bottom right, under our HUD: anything of ours that
-- sits there takes the tap meant for it. This is the arithmetic for staying off it. The client reads where
-- the button really is (UI/Core/TouchControls); `defaultJump` is the engine's own placement, for the moments
-- before the button exists.

local TouchSafe = {}

-- The space kept between the button and anything of ours, in screen pixels.
TouchSafe.GAP = 10

-- Where the engine puts the jump button on a screen of this size (the screen's top left is 0, 0): 70 px on
-- a screen whose short side is 500 px or less, 120 px on a larger one.
function TouchSafe.defaultJump(screen: Vector2): Rect
	local small = math.min(screen.X, screen.Y) <= 500
	local size = if small then 70 else 120
	local left = screen.X - (size * 1.5 - 10)
	local top = if small then screen.Y - size - 20 else screen.Y - size * 1.75
	return Rect.new(left, top, left + size, top + size)
end

-- Do two rectangles share any area (touching edges do not count)?
function TouchSafe.overlaps(a: Rect, b: Rect): boolean
	return a.Min.X < b.Max.X and b.Min.X < a.Max.X and a.Min.Y < b.Max.Y and b.Min.Y < a.Max.Y
end

-- The lowest y the bottom edge of a HUD element may reach to sit clear above the button.
function TouchSafe.floorAbove(jump: Rect, gap: number?): number
	return jump.Min.Y - (gap or TouchSafe.GAP)
end

return TouchSafe
