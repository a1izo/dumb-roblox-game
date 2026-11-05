---
name: tokyo-station-2026-11
description: Tokyo's ticket gates rebuilt inside their kept box (KEPT is empty now) and the metro platform dressed around the intro's staging (2026-11-05); where the intro lives and what may stand there
metadata:
  type: project
---

Second slice of the 2026-11-05 "lobby quality everywhere" pass (after [[agency-interiors-2026-11]]): Maps Tokyo v41,
Models Tokyo v23.

- **TicketGate** was the last prop on a kept mesh (`build_props.KEPT`, a near-blank white slab). It is built now by
  `props_tokyo_transit.ticket_gate` inside the kept box (`FIT_TO_KEPT["TicketGate"] = (2.8, 5.1, 3.47)`): a 2.2-wide
  enamel cabinet whose flaps reach the box's width, so the gate lines and lanes in the station hall hold. 3,792
  triangles, 512 px. `KEPT` is an empty set; `reskin_one` stays for any future kept prop. The Agency's SecurityGate
  stands for TicketGate (`base`), and stays within 0.1 of the new box (the own-furniture spec's rule).
- **The platform** (`maps/venues/tokyo/station.py` `dressing`): framed ad posters (the district's print sheet) in pairs
  between the station names on both track walls; the stairwell housing has a black skirting, a lit "GATES" sign over
  the way up, a clock and a framed notice; two StationSignHanging hung across the east end, back-to-back
  PlatformBenches, bins and a poster on the end wall. `framed_poster` hangs any sheet poster in a frame 0.04 clear.
- **The intro (cinema/shots/intro_tokyo.py) is staged on the platform from x -110 to -62** (actors, the walker along
  z -63.2 from the stairs, a crane from x -110 high over the west end). Keep that stretch's floor and air clear; dress
  its walls and the east end. `run_cinema.py -- IntroTokyo --clear` reported 0 problems after this.
- `finders.HANGING` now holds StationSignHanging (it hangs on rods to the ceiling; place it with its pivot at the
  ceiling minus 2.15, half its height, or check_v2 calls it floating).
- Preview view 3 ("inside the station hall") had its camera inside a ticket machine; it stands by the east doors now.

Still bare, for a later slice: the station hall's tiled walls and ceiling (only signs and machines on them), the
platform's ceiling.

**Why:** the user asked for the remade lobby's finish everywhere; the gates were the "white plain shapes" of the audit.
**How to apply:** before dressing the platform again, read the intro's WAITING, WALK_FROM/WALK_TO and shot.cam lines and
run the clearance check. Related: [[station-props-2026-11]], [[own-furniture-2026-11]], [[map-remake-project]].
