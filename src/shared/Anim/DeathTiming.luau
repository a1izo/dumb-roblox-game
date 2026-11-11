--!strict
-- When things happen in each death, seconds from the start of its clip. Written by art/scripts/deaths.py
-- (do not edit by hand).
--   deaths  each collapse and custom death: when the body first hits the floor (`hit`), when its custom effect
--           starts (`fx`: Presentation/CustomDeaths), when it lies still (`still`), the clip's `length`

export type Timing = { hit: number, fx: number?, still: number, length: number }

return {
	deaths = {
		collapseAccident = { hit = 0.7, still = 2.3, length = 2.3 },
		collapseDisease = { hit = 2.887, still = 3.4, length = 3.4 },
		collapseHeart = { hit = 1.647, still = 2.7, length = 2.7 },
	} :: { [string]: Timing },
}
