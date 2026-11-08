--!strict
-- When things happen in each death, seconds from the start of its clip. Written by art/scripts/deaths.py and
-- fallen.py (do not edit by hand).
--   deaths  each collapse and custom death: when the body first hits the floor (`hit`), when its custom effect
--           starts (`fx`: Presentation/CustomDeaths), when it lies still (`still`), the clip's `length`
--   fallen  each fallen body's death-style clip (fallen<Style><Down|Up>): its `length` and its moments, which
--           Presentation/Styles.death times its effect by (strings: catch, lift, snap, heap; crows: lift, burst;
--           stone: climb, set, crumble; glass: glass, look, shatter; ash: effort, give, grey, crumble)

export type Timing = { hit: number, fx: number?, still: number, length: number }

return {
	deaths = {
		collapseAccident = { hit = 0.7, still = 2.3, length = 2.3 },
		collapseDisease = { hit = 2.887, still = 3.4, length = 3.4 },
		collapseHeart = { hit = 1.647, still = 2.7, length = 2.7 },
		deathBurn = { hit = 2.385, fx = 0.45, still = 3.1, length = 3.1 },
		deathChandelier = { hit = 0.95, fx = 0.45, still = 2.8, length = 2.8 },
		deathChip = { hit = 2.678, fx = 0.62, still = 3.3, length = 3.3 },
		deathClock = { hit = 3.25, fx = 0.9, still = 3.25, length = 3.8 },
		deathDark = { hit = 1.06, fx = 0.5, still = 3.1, length = 3.1 },
		deathDrown = { hit = 3.12, fx = 0.9, still = 3.7, length = 3.7 },
		deathFall = { hit = 0.948, fx = 0.698, still = 2.7, length = 2.7 },
		deathFrost = { hit = 2.453, fx = 0.9, still = 2.653, length = 2.9 },
		deathHeart = { hit = 2.582, fx = 0.9, still = 3.3, length = 3.3 },
		deathLightning = { hit = 1.782, fx = 0.55, still = 2.8, length = 2.8 },
		deathPages = { hit = 2.423, fx = 0.3, still = 3.1, length = 3.1 },
	} :: { [string]: Timing },
	fallen = {
		fallenAshDown = { crumble = 1.15, effort = 0.2, give = 0.92, grey = 0.6, length = 3 },
		fallenAshUp = { crumble = 1.15, effort = 0.2, give = 0.92, grey = 0.6, length = 3 },
		fallenCrowsDown = { burst = 1.68, length = 2.8, lift = 0.45 },
		fallenCrowsUp = { burst = 1.68, length = 2.8, lift = 0.45 },
		fallenGlassDown = { glass = 0, length = 2.8, look = 1.42, shatter = 1.86 },
		fallenGlassUp = { glass = 0, length = 2.8, look = 1.42, shatter = 1.86 },
		fallenStoneDown = { climb = 0, crumble = 2.3, length = 3.4, set = 1.34 },
		fallenStoneUp = { climb = 0, crumble = 2.3, length = 3.4, set = 1.34 },
		fallenStringsDown = { catch = 0.14, heap = 2.8, length = 3.6, lift = 0.42, snap = 2.5 },
		fallenStringsUp = { catch = 0.14, heap = 2.8, length = 3.6, lift = 0.42, snap = 2.5 },
	} :: { [string]: { [string]: number } },
}
