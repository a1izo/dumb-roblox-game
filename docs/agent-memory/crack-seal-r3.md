---
name: crack-seal-r3
description: 2026-11-15 third crack pass in mesher.seal: joins matched along their line (T-junctions) and floor edges on a riser's top sealed down-and-in; bump the seal revision in export.mesh_digest or venues keep their old version
metadata:
  type: project
---

The user, 2026-11-15, the third time: "please for the love of GOD please fix the floor theres still cracks in them".

What was still open after r2 (in-plane joins with identical edges + floors at a wall's foot):
- **T-junctions**: a lip was only grown where two meshes' border edges were the same edge end for end. A long edge
  beside several short ones (a slab beside tiles, a kerb, a run of steps) matched nothing. `seal` now also indexes
  every border edge by its line (`_line`) and pairs any two running opposite ways that overlap by 0.05+ (`partner`).
- **Step noses / kerb tops / platform sides**: a floor's border edge lying on the TOP edge of an upright face below it
  (tread over riser in another mesh) opens a slit into the hollow under the floor. `_wall_feet` indexes upright faces'
  top edges too (`tops`) and gives such an edge a lip 0.3 down and 0.12 IN (under the floor, behind the riser), both
  sides drawn (seen from in front and from above).
- Counts after r3: Lobby 3890 lips, Campus 3468, Tokyo 9709, Agency 971, Meeting 886, Sets 317, Scenes 1634.

**Trap:** the lips are made after the mesh digest is taken, so `export.mesh_digest` stands in for them with the line
`seal:0.22:0.22:r3`. Change the sealing and NOT that revision, and every venue re-exports at its old version (the game
then never knows the import is newer). Bump it with every sealing change.

Not seen in the engine yet (2026-11-15: the user's Roblox and Studio were open, no harness pictures possible).
Related: [[lobby-hummocks-and-ruins]], [[lobby-ground-relief]], [[mesh-triangle-limit]].

2026-11-15 evening, SEEN in the place: the lobby's remaining crack was a bright arc round the bowl's rim. (1) the
backing sheet's holes were all grown 1.5 out (right for the rift and chasms, wrong for the bowl: ground.py grows the
bowl's hole a stud INWARD now); (2) the bowl's risers face in, so from outside a riser draws nothing and the hollow
under its terrace showed the sky (landmarks.bowl lays a stone floor under the whole bowl). Checked gone, Lobby v55.
Look for one-sided risers and walls seen from behind wherever a crack shows as a thin bright line at a step.
