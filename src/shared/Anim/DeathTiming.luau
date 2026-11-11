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
		deathChip = { hit = 2.678, fx = 0.62, still = 3.3, length = 3.3 },
		deathClock = { hit = 3.25, fx = 0.9, still = 3.25, length = 3.8 },
		deathDark = { hit = 1.06, fx = 0.5, still = 3.1, length = 3.1 },
		deathFrost = { hit = 2.453, fx = 0.9, still = 2.653, length = 2.9 },
		deathHeart = { hit = 2.582, fx = 0.9, still = 3.3, length = 3.3 },
		deathLightning = { hit = 1.782, fx = 0.55, still = 2.8, length = 2.8 },
	} :: { [string]: Timing },
}
