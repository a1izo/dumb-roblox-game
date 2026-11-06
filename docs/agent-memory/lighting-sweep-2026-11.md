---
name: lighting-sweep-2026-11
description: Room-by-room light sweep of every venue (2026-11-06): how it was measured (art/scripts/maps/room_light.py), the outliers found and evened out, and the dark spots kept on purpose
metadata:
  type: project
---

The user, 2026-11-06: "a full sweep of the lighting system ... so random rooms arent darker than others, but keep
the mysterious vibe". Measured from the exported scene data with `art/scripts/maps/room_light.py <Venue>` (Blender's
Python, after an export): per named zone (HQ: per room of plan.ROOMS_L1/L2 and the open plans) the lamps, the area and
an estimated eye-height level (spots within their cones, b x (1 - d/r)^2, no walls since Roblox lamps cast no
shadows), compared with the median of the same kind. Under 0.5x = DARK. The model is relative only: Roblox's falloff
is not physical, so never read its numbers as absolute brightness.

Found and fixed (each confirmed in a Studio play test at QL21):
- University: the old rooms lit by brass pendants alone (Law & Letters' hall, the library's circulation desk and rare
  books room, the clock tower's foot) used `kit.pendant` at brightness 1.0 beside rooms whose panels are noir pools
  (8.5x gain): 0.2-0.3x their peers. Now `campus.fit.PENDANT_ROOM = 3.5` for all of them (0.64-0.90x); the gallery's
  two wall lamps 0.7 -> 1.5. Law & Letters' hall had sat dark beside the lit student affairs office behind its glass.
- Tokyo: yokocho alleys y_a, y_b, y_c had one, none and none of the wall lamps y_cross and y_dead have; they now get
  the same `lamps_on_walls` (y_c 0.02x -> 0.68x). The minami street had power poles and no street light (kita, its
  peer, has one): one added. The department store's upper floor had four pools at 1.3 where the ground floor has five
  at 1.4: a fifth (by the escalators' head; the south-west corner has no upper floor) and 1.4.
- HQ: no outliers (its rooms all use fit.ceiling_lights over what matters); the training room and analysts' floor are
  the dimmest at ~0.6x, by having fewer things to light.

Kept dark on purpose: the film club (a screening room lit by its screen), the University's pond bridge and Tokyo's
footbridge (between lit ends, over water), the lobby (lit by the realm's own light, not lamps: the lamp model means
nothing there; it read evenly grey live), dead fittings, the warehouse set, blackouts. The meeting room is one room.
The cutscene sets were not changed: their committed scene is older than the 2026-11-02 rollout (the locker set still
has round tube lights; an export would turn them into pools), so leave Sets until someone looks at them live.

Parking Studio off screen: ShowWindow(SW_SHOWNOACTIVATE) on a window minimised from maximised brings it back
MAXIMISED on the user's screen. Use SetWindowPlacement (flags 0, showCmd 4) and then SetWindowPos to (-1960, 0).

Related: [[lighting-rework-2026-11]].
