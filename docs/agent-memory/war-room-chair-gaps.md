---
name: war-room-chair-gaps
description: Geometry for walking people into the war room's ring (2026-11-17): chairs are 3.2 stud boxes at 19.6, the gaps are 6.4 to 7.4 studs wide, a body with its arms is 4 wide, so walk the gap's middle and the lane at radius 15.8; footwork walkers cost about 20k characters of acting each
metadata:
  type: reference
---

For any scene that brings people to the war room's places (maps/venues/meeting, `run_cinema --clear` treats a chair as its whole
3.2 x 6.9 x 3.2 box, `WarChair` 2.46 scaled 1.3):

- Gaps between chairs are at the odd multiples of 15 degrees and **6.4 to 7.4 studs wide** (not 1.9: the chord of 30 degrees at
  19.6 is 10.1). An R6 body with its arms hanging is **4 wide**, so it passes down the gap's middle with 1.2 to 1.7 to spare.
- A walker heading along the ring has its arms 2 studs out radially: the lane just inside the chairs' fronts is **radius 15.8**
  (outer arm at 17.8, chair fronts at 18.0, table at 13.05). Turn to the table and step back (0.5 s) into the place at 17;
  curving from the lane out to 17 while turning put an arm 0.5 studs into the chair at every arrival.
- Two walkers through one gap need about **1.3 s** between them (a hurried stride and the second one's different path length
  overlapped the legs at 0.9 to 1.05 s).
- A walker costs about **20,000 characters** of Acting file for 7 s (the footwork plan); ten walkers and two standing seats went
  to 201,605, past Roblox's 200k, eight walkers and four standing gave 181k. Standing seats are about 3k each.
- The records door in the east wall is closed double doors (static boxes), so nobody can walk through it: arrivals start in
  the dark at radius 25 and are shown from there.
