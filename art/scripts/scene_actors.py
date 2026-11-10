"""The actors' clips for the scene deaths, rebuilt 2026-11-08 from the frame-by-frame sheets in art/refs/deaths/
(the user's verdict on the first build: copy each reference 1 for 1, its POV, its extra characters, its length). Each
clip runs the whole length of its scene and is keyed to that sheet's times; Presentation/SceneDeaths stages the
actors, the cameras, the sets, the UI and the effects around them.

    requiem   sceneRequiemVictim (the lunge, the punch stopped, then rewound: looking back), sceneRequiemCopy (a
              copy in the rewound row, looking back), sceneRequiemKiller (the shadow that cannot be touched)
    blackwall sceneBlackwallVictim (arms crossed, hacked, burning, down), sceneBlackwallBystander
    sam       sceneSamVictim, sceneSamKiller (the blade)
    walrider  sceneWalriderSoldier (aiming, firing), sceneWalriderShooter (firing again and again), sceneWalriderSeated
              (the old man in the wheelchair); the victim is the camera
    sans      sceneSansVictim (asleep, the dodge, the shrug, the cut, hunched down)
    ironman   sceneIronVictim (on one knee, the gauntlet, the snap, sat against the wall), sceneIronKiller,
              sceneIronSoldier (the army behind, standing)
    patriot   scenePatriotSaluter (head bowed at the grave, the slow salute held)
    selection sceneSelectionVictim (staring at the board, drained)

Angles as in deathkit: root pitch negative leans forward, arms x 0 hangs / 90 ahead / 180 overhead, z out (right +),
legs x + forward."""

from animlib import J
from cinema.acting import alive, beat, soft, strike
from deathkit import (BACK_L, BACK_R, REST, SIDE_R, Feet, body, body_key, breaths, floor_key, kneel_key, mix, prone_key,
                      shiver, sit_key, stand)
from deaths import CLUTCH, HANG_L, HANG_R, OVER_L, crouch_legs, topple_forward
from emotes.kit import reach
from motion import Motion

CROSS_R = reach(1, (-0.55, 0.15, -0.72), direction=(-0.85, 0.1, -0.5))
CROSS_L = reach(-1, (0.55, 0.3, -0.78), direction=(0.85, 0.1, -0.5))
TEMPLE_R = reach(1, (0.78, 1.45, -0.32), direction=(-0.25, 0.92, -0.3))
TEMPLE_L = reach(-1, (-0.78, 1.42, -0.32), direction=(0.25, 0.92, -0.3))
AIM_R = reach(1, (0.25, 0.75, -1.6), direction=(-0.15, 0.1, -1.0))
AIM_L = reach(-1, (0.05, 0.7, -1.2), direction=(0.45, 0.05, -0.9))
BROW = reach(1, (0.8, 1.7, -0.45), direction=(-0.55, 0.65, -0.5))
SHRUG_R, SHRUG_L = J((28, 0, 46), (0, 0.12, 0)), J((28, 0, -46), (0, 0.12, 0))


def knees_go(m, t0, t1, lean, hips, turn=0.0, neck=(-14, 0, 0), **upper):
    """The knees go between t0 and t1 (no frame floats): the legs swing under, then fold back along the floor."""
    d = t1 - t0
    joints = dict(neck=neck, **upper)
    floor_key(m, t0 + 0.45 * d, "in", lean * 0.86, turn, 0, hips, dict(rHip=J((40, 0, 2)), lHip=J((40, 0, -2))), joints)
    floor_key(m, t0 + 0.76 * d, "in", lean * 0.95, turn, 0, hips,
              dict(rHip=J((6, 0, 2), (0, 0.06, 0.12)), lHip=J((6, 0, -2), (0, 0.06, 0.12))), joints)


# =====================================================================================================================
# This is... requiem (16.5 s; requiem.md)

LOOK_BACK = dict(neck=(10, 62, 4), rShoulder=J((86, 0, -12), (0, 0.1, -0.2)), lShoulder=J((26, 0, -34)))


def look_back_turn(m, t0, turn, t1, seed=0):
    """A copy in the rewound row (2026-11-10, the user: "looking back 1 by 1", not glitching): it stands facing the
    killer in the punch it was rewound out of, then at `turn` looks back over its shoulder at the lens (a dip, the head
    whipping round, a small overshoot, settled), then holds the growing dread (look_back_hold)."""
    v = (seed % 3) - 1
    body_key(m, t0, "smooth", -14, 10, 0, hips=(0, -0.5), drop=0.2, neck=(-2, -6, 0), rShoulder=BLOW["rShoulder"],
             lShoulder=BLOW["lShoulder"])
    body_key(m, turn - 0.14, "smooth", -13, 9, 0, hips=(0, -0.48), drop=0.2, neck=(-6, -10, 0),
             rShoulder=BLOW["rShoulder"], lShoulder=BLOW["lShoulder"])  # the dip before the turn
    body_key(m, turn + 0.22, "out", 5, -20, -3, hips=(0, 0.05), drop=0.04, neck=(12 + 2 * v, 70 + 3 * v, 5),
             rShoulder=LOOK_BACK["rShoulder"], lShoulder=LOOK_BACK["lShoulder"])  # round, a little past
    look_back_hold(m, turn + 0.5, t1, seed)


def look_back_hold(m, t0, t1, seed=0):
    """Rewound and frozen in it (requiem.md 3.5-16: "still"): twisted round to look back over the left shoulder at the
    lens, the punching arm still out at the killer. Not a stutter (2026-11-09, "choppy"): the dread grows instead,
    slowly, as the rewind drags on: the head turns on round, the chest sinks back, the free hand lifts in a half
    guard, the punching arm sags. Each copy (seed) holds its own version of the pose; Anim/Life breathes it."""
    v = (seed % 3) - 1  # -1, 0 or 1: the copies are not one pose
    neck0, neck1 = (10 + 2 * v, 60 + 3 * v, 4), (14 + 2 * v, 70 + 3 * v, 6 - v)
    body_key(m, t0, "out", 4, -18, -3, hips=(0, 0.05), drop=0.03, neck=neck0, rShoulder=LOOK_BACK["rShoulder"],
             lShoulder=LOOK_BACK["lShoulder"])
    mid = t0 + (t1 - t0) * (0.45 + 0.08 * v)
    body_key(m, mid, "smooth", 6, -21, -4, hips=(0, 0.08), drop=0.05, neck=(12 + 2 * v, 66 + 3 * v, 5),
             rShoulder=J((80, 0, -10), (0, 0.08, -0.18)), lShoulder=J((40, 0, -40)))
    body_key(m, t1, "smooth", 8, -24, -5, hips=(0, 0.1), drop=0.07, neck=neck1,
             rShoulder=J((74, 0, -8), (0, 0.06, -0.16)), lShoulder=J((52, 0, -44)))


rv = Motion("sceneRequiemVictim", 16.5, note="Take this! The lunge and the punch stopped dead, then rewound: frozen "
            "looking back over the shoulder.", floor=True)
rv.key(0.0, **REST)
WIND = dict(neck=(6, 10, 0), rShoulder=J((150, 0, 52)), lShoulder=J((30, 0, -26)))
BLOW = dict(neck=(-4, -6, 0), rShoulder=J((92, 0, -14), (0, 0.1, -0.24)), lShoulder=J((-28, 0, -18)))
body_key(rv, 0.25, "out", 8, 14, 0, hips=(0, 0.1), drop=0.08, neck=(14, 0, 0), rShoulder=J((60, 0, 30)),
         lShoulder=J((30, 0, -20)))  # "Take this...": shouting, chest out
body_key(rv, 0.95, "in", 10, -26, 0, hips=(0, 0.12), drop=0.12, **WIND)
strike(rv, 1.3, body(10, -26, 0, hips=(0, 0.12), drop=0.12, **WIND),
       body(-18, 14, 0, hips=(0, -0.6), drop=0.22, **BLOW), antic=0.06, travel=0.05, over=0.22, settle=0.2)
body_key(rv, 2.25, "smooth", -18, 14, 0, hips=(0, -0.6), drop=0.22, **BLOW)  # stopped a hand short
# the shocked profile (2.5-3.0 "still, a slow push"): reached in the cut, then barely moving
body_key(rv, 2.45, "out", -14, 12, 0, hips=(0, -0.6), drop=0.2, neck=(-2, -14, 0), rShoulder=BLOW["rShoulder"],
         lShoulder=BLOW["lShoulder"])
body_key(rv, 3.245, "smooth", -13, 12, 0, hips=(0, -0.6), drop=0.21, neck=(0, -16, 0), rShoulder=BLOW["rShoulder"],
         lShoulder=J((-24, 0, -20)))
stand(rv, 0.0, 3.25, Feet(steps=[(1.05, 1.32, 1, 0.75)]), ramp=0)
# (the cut at 3.25 hides the jump into the rewound row's pose: its feet stand together again under it)
look_back_turn(rv, 3.26, 3.75, 16.5, seed=0)  # (the first of the row to look back)
stand(rv, 3.26, 16.5, Feet(), ramp=0)
soft(rv, head=3.6, arms=3.0)
rv.build()

rc = Motion("sceneRequiemCopy", 16.5, note="A copy in the rewound row: facing the killer, then looking back over the "
            "shoulder at 1 s, the dread growing.", floor=True)
rc.key(0.0, **REST)
look_back_turn(rc, 0.0, 1.0, 16.5, seed=2)  # (each copy from its own moment: Requiem.luau)
stand(rc, 0.0, 16.5, Feet())
soft(rc, head=3.0, arms=2.6)
rc.build()

rk = Motion("sceneRequiemKiller", 16.5, note="The shadow at the end of the row: tall and unhurried; the open hand comes "
            "up as the fist arrives and stays there, never touched; the head tips down at the row.", floor=True)
rk.key(0.0, **REST)
KILL = dict(neck=(-6, 0, 0), rShoulder=J((70, 0, 18)), lShoulder=J((8, 0, -14)))
body_key(rk, 0.0, "smooth", -2, 0, 0, neck=(-4, 0, 0), rShoulder=J((14, 0, 10)), lShoulder=J((8, 0, -14)))
beat(rk, 1.55, dur=0.5, antic=0.08, over=0.06, rShoulder=KILL["rShoulder"])  # the open hand, as the fist arrives
body_key(rk, 3.4, "smooth", -3, 0, 0, neck=(-8, 4, 2), rShoulder=KILL["rShoulder"], lShoulder=KILL["lShoulder"])
body_key(rk, 9.0, "smooth", -4, -4, 0, neck=(-12, 8, 4), rShoulder=J((66, 0, 16)), lShoulder=KILL["lShoulder"])
body_key(rk, 16.5, "smooth", -5, -6, 0, neck=(-14, 10, 5), rShoulder=J((62, 0, 14)), lShoulder=J((10, 0, -16)))
stand(rk, 0.0, 16.5, Feet(stance=0.18))
soft(rk, head=2.4, arms=2.0)
rk.build()

# =====================================================================================================================
# Blackwall gateway (23.3 s; blackwall.md)

bw = Motion("sceneBlackwallVictim", 23.3, note="Arms crossed, scanned and hacked; the glitch fire takes him: the "
            "pillar, burning, hands to the head, staggering, down.", floor=True)
CROSSED = dict(neck=(2, 0, 0), rShoulder=CROSS_R, lShoulder=CROSS_L)
bw.key(0.0, **REST)
# arms crossed, the weight on one hip, chin up (blackwall.md 0-9.5): a man who thinks he is safe
body_key(bw, 0.0, "smooth", 2, -6, -3, hips=(0.12, 0.0), drop=0.04, neck=(4, 6, -4), rShoulder=CROSS_R,
         lShoulder=CROSS_L)
body_key(bw, 5.6, "smooth", 2, -7, -3, hips=(0.12, 0.0), drop=0.04, neck=(6, 4, -5), rShoulder=CROSS_R,
         lShoulder=CROSS_L)
beat(bw, 6.4, dur=0.55, antic=0.1, over=0.08, neck=(2, -8, 3))  # a glance aside, bored
beat(bw, 7.6, dur=0.5, antic=0.1, over=0.06, neck=(6, 4, -4))
# 10.0-12.5 the upload: the glitch flickers on him; he looks down at himself, then up, uneasy
body_key(bw, 10.4, "smooth", 2, -6, -3, hips=(0.12, 0.0), drop=0.04, neck=(5, 4, -4), rShoulder=CROSS_R,
         lShoulder=CROSS_L)
beat(bw, 10.9, dur=0.3, antic=0.12, over=0.1, neck=(-22, -6, 2))
beat(bw, 12.1, dur=0.45, antic=0.08, over=0.05, neck=(8, 10, -2))
body_key(bw, 14.5, "smooth", 3, -4, -1, hips=(0.08, 0.0), drop=0.06, neck=(10, 8, -2), rShoulder=CROSS_R,
         lShoulder=CROSS_L)
alive(bw, amount=0.35, seed=1, t0=0.0, t1=14.6)
# 14.75 the jolt; the fire climbs; hands to the head; 16.3 the pillar throws him rigid
strike(bw, 14.85, body(3, -4, -1, drop=0.06, **CROSSED),
       body(-6, 4, 5, drop=0.04, neck=J((-14, 10, 8)), rShoulder=J((40, 0, 50)), lShoulder=J((30, 0, -60))),
       antic=0.03, travel=0.04, over=0.3, settle=0.15)
body_key(bw, 15.5, "out", -4, 6, 4, drop=0.05, neck=(-10, 12, 8), rShoulder=TEMPLE_R, lShoulder=J((40, 0, -60)))
body_key(bw, 16.15, "in", 6, 0, 0, drop=0.0, neck=(10, 0, 0), rShoulder=TEMPLE_R, lShoulder=TEMPLE_L)
body_key(bw, 16.3, "snap", 16, 0, 0, hips=(0, 0.05), drop=-0.08, neck=(30, 0, 0), rShoulder=J((60, 0, 84)),
         lShoulder=J((60, 0, -84)))  # the pillar: thrown rigid
body_key(bw, 16.9, "out", 12, 0, 2, hips=(0, 0.05), drop=-0.04, neck=(24, 0, 4), rShoulder=J((54, 0, 80)),
         lShoulder=J((56, 0, -80)))
# 17.4-21.5 burning, hands to the head, staggering and turning (blackwall.md): lurches of their own size and timing,
# each thrown fast and dragged out, never a metronome
for t, pitch, yaw, roll, hips, neck in (
    (17.35, -12, -14, -6, (-0.12, 0.12), (-14, -14, -8)),
    (17.95, -18, 8, 3, (0.06, 0.2), (-22, 6, 4)),
    (18.8, -14, 24, 8, (0.18, 0.3), (-10, 18, 10)),
    (19.3, -22, 12, 2, (0.12, 0.36), (-26, 8, 2)),
    (20.25, -19, -18, -7, (-0.14, 0.46), (-16, -16, -8)),
    (20.75, -27, -6, 1, (-0.06, 0.52), (-28, -4, 0)),
    (21.5, -30, 14, 6, (0.1, 0.58), (-24, 10, 6)),
):
    body_key(bw, t, "out", pitch, yaw, roll, hips=hips, drop=0.16 - pitch * 0.004, neck=neck, rShoulder=TEMPLE_R,
             lShoulder=TEMPLE_L)
shiver(bw, 14.8, 15.6, {"root": (1.0, 0.8, 1.0), "neck": (2.0, 1.6, 1.2)}, amount=1.0, hz=6, decay=0.9)
shiver(bw, 16.3, 16.9, {"root": (0.8, 0.6, 0.8), "neck": (1.6, 1.2, 1.0)}, amount=1.0, hz=5, decay=0.9, seed=2)
stand(bw, 0.0, 21.8, Feet(start={1: (0.62, 0.05), -1: (-0.5, -0.12, -14)},
                            steps=[(17.3, 17.55, -1, (-0.62, 0.3, -20)), (18.7, 18.95, 1, (0.7, 0.42, 16)),
                                   (19.25, 19.45, -1, (-0.52, 0.5, -4)), (20.15, 20.45, 1, (0.5, 0.6, -18)),
                                   (21.4, 21.65, -1, (-0.66, 0.72, 10))]))
BW_HIPS = (0.0, 0.55)
knees_go(bw, 21.8, 22.25, -36, BW_HIPS, neck=(-20, 0, 0), rShoulder=TEMPLE_R, lShoulder=TEMPLE_L)
kneel_key(bw, 22.25, "in", lean=-36, head=-20, hips=BW_HIPS, rShoulder=TEMPLE_R, lShoulder=J((60, 0, -20)))
topple_forward(bw, 22.25, 36.0, BW_HIPS, spin0=2.2, arm="l", hold_r=TEMPLE_R, head0=-20.0, length=3.0)
soft(bw, head=3.2, arms=2.8)
bw.build()

bb = Motion("sceneBlackwallBystander", 23.3, note="Standing by; caught by the spread: burning, doubled over, down.",
            floor=True)
bb.key(0.0, **REST)
# standing by, idle: weight on the left leg, a hand at the hip, glancing about
POCKET_R = J((-8, 0, 26), (0, 0.04, 0))
body_key(bb, 0.0, "smooth", 0, 6, 2, hips=(-0.1, 0.0), neck=(0, -10, 0), rShoulder=POCKET_R, lShoulder=HANG_L)
beat(bb, 4.2, dur=0.5, antic=0.1, over=0.06, neck=(2, 14, -3))
beat(bb, 8.8, dur=0.5, antic=0.1, over=0.06, neck=(-4, -6, 2))
body_key(bb, 14.7, "smooth", 0, 4, 2, hips=(-0.1, 0.0), neck=(-2, -4, 2), rShoulder=POCKET_R, lShoulder=HANG_L)
alive(bb, amount=0.35, seed=4, t0=0.0, t1=14.7)
# 14.75 caught by the spread: a jolt; 16.5-17.5 doubled over, burning (blackwall.md)
strike(bb, 14.95, body(0, 4, 2, hips=(-0.1, 0.0), neck=J((-2, -4, 2)), rShoulder=POCKET_R, lShoulder=HANG_L),
       body(-8, -10, -6, hips=(-0.04, 0.05), drop=0.08, neck=J((-18, -10, -4)), rShoulder=J((70, 0, 50)),
            lShoulder=J((60, 0, -40))), antic=0.03, travel=0.05, over=0.3, settle=0.2)
for t, pitch, yaw, roll, hips, neck, r in (
    (15.7, -16, 10, 6, (0.06, 0.1), (-22, 8, 2), J((80, 0, 50))),
    (16.15, -12, -4, -2, (0.0, 0.14), (-16, -4, 0), J((62, 0, 44))),
    (16.6, -28, 8, 4, (0.05, 0.2), (-26, 6, 2), J((76, 0, 46))),
    (17.15, -34, -6, -3, (-0.02, 0.24), (-24, -6, -2), J((70, 0, 40))),
):
    body_key(bb, t, "out", pitch, yaw, roll, hips=hips, drop=0.1 - pitch * 0.004, neck=neck, rShoulder=r,
             lShoulder=J((72, 0, -38)))
shiver(bb, 14.9, 15.6, {"root": (1.2, 0.8, 1.2)}, amount=1.0, hz=6, decay=0.9, seed=3)
stand(bb, 0.0, 17.3, Feet(start={1: (0.55, -0.1, 8), -1: (-0.6, 0.06)},
                          steps=[(15.6, 15.85, 1, (0.6, 0.12, 2)), (16.5, 16.75, -1, (-0.55, 0.2, -6))]))
BB_HIPS = (0.0, 0.25)
knees_go(bb, 17.3, 17.7, -40, BB_HIPS, neck=(-24, 0, 0), rShoulder=CLUTCH, lShoulder=OVER_L)
kneel_key(bb, 17.7, "in", lean=-40, head=-24, hips=BB_HIPS, rShoulder=CLUTCH, lShoulder=OVER_L)
topple_forward(bb, 17.7, 40.0, BB_HIPS, spin0=2.0, arm="l", hold_r=CLUTCH, head0=-24.0, length=3.0)
bb.build()

# =====================================================================================================================
# Let's dance! (14 s; sam.md)

GUARD_R = reach(1, (0.1, 0.1, -0.9), direction=(-0.6, 0.2, -0.75))
GUARD_L = reach(-1, (-0.2, -0.1, -0.85), direction=(0.5, 0.1, -0.85))
sv = Motion("sceneSamVictim", 14.0, note="In guard, cut by the combo; blade mode freezes him; cut, staggering, "
            "grabbed, run through, reeling, the blade out, staggering away, standing half turned.", floor=True)
sv.key(0.0, **REST)
body_key(sv, 0.0, "smooth", -10, 0, 0, hips=(0, 0.1), drop=0.32, neck=(4, 0, 0), rShoulder=GUARD_R, lShoulder=GUARD_L)
for t, s in ((0.45, 1), (0.8, -1), (1.1, 1)):
    strike(sv, t, body(-10, 0, 0, hips=(0, 0.1), drop=0.32, rShoulder=GUARD_R, lShoulder=GUARD_L),
           body(-4, 10 * s, 6 * s, hips=(0, 0.25), drop=0.3, neck=J((10, -8 * s, 0)), rShoulder=GUARD_R,
                lShoulder=GUARD_L), antic=0.02, travel=0.03, over=0.3, settle=0.12)
body_key(sv, 1.5, "out", -8, -6, 0, hips=(0, 0.3), drop=0.3, neck=(8, 0, 0), rShoulder=GUARD_R, lShoulder=GUARD_L)
body_key(sv, 3.15, "linear", -8.5, -6, 0, hips=(0, 0.3), drop=0.3, neck=(8, 0, 0), rShoulder=GUARD_R,
         lShoulder=GUARD_L)  # blade mode: all but frozen
strike(sv, 3.3, body(-8.5, -6, 0, hips=(0, 0.3), drop=0.3, rShoulder=GUARD_R, lShoulder=GUARD_L),
       body(10, 8, 6, hips=(0, 0.6), drop=0.22, neck=J((-16, 0, 6)), rShoulder=J((40, 0, 60)),
            lShoulder=J((30, 0, -50))), antic=0.02, travel=0.04, over=0.25, settle=0.2)
body_key(sv, 4.0, "sine", 6, 20, 4, hips=(0.3, 1.0), drop=0.25, neck=(-10, 10, 4), rShoulder=J((30, 0, 50)),
         lShoulder=CLUTCH)
body_key(sv, 4.75, "sine", 0, 60, 0, hips=(0.4, 1.1), drop=0.18, neck=(0, 10, 0), rShoulder=GUARD_R, lShoulder=HANG_L)
body_key(sv, 5.0, "smooth", -4, 0, 0, hips=(0.0, 0.0), drop=0.1, neck=(4, 0, 0), rShoulder=J((20, 0, 30)),
         lShoulder=J((20, 0, -30)))  # (the next shot: his back to us, grabbed; SceneDeaths turns him)
body_key(sv, 6.6, "linear", -4, 0, 0, hips=(0.0, 0.0), drop=0.1, neck=(6, 0, 0), rShoulder=J((24, 0, 30)),
         lShoulder=J((24, 0, -30)))
strike(sv, 6.85, body(-4, 0, 0, drop=0.1, rShoulder=J((24, 0, 30)), lShoulder=J((24, 0, -30))),
       body(14, 0, 0, hips=(0, -0.25), drop=0.15, neck=J((24, 0, 0)), rShoulder=J((50, 0, 70)),
            lShoulder=J((50, 0, -70))), antic=0.03, travel=0.05, over=0.3, settle=0.25)
# 7.25-11.0 run through: he rocks back and grits (sam.md), in his own uneven time: a heave, a sag, a twist against
# the blade, the hands clawing at the air
for t, pitch, yaw, roll, neck, r, l in (
    (7.55, 15, 3, 2, (24, 4, 0), J((50, 0, 72)), J((44, 0, -62))),
    (8.5, 10, -4, -3, (14, -6, -2), J((40, 0, 62)), J((52, 0, -70))),
    (9.05, 16, 5, 4, (26, 8, 2), J((56, 0, 74)), J((40, 0, -58))),
    (10.25, 11, -2, -1, (18, -2, 0), J((44, 0, 64)), J((48, 0, -66))),
    (10.85, 14, 1, 1, (22, 2, 0), J((48, 0, 68)), J((46, 0, -64))),
):
    body_key(sv, t, "out", pitch, yaw, roll, hips=(0, -0.25), drop=0.16, neck=neck, rShoulder=r, lShoulder=l)
shiver(sv, 6.85, 7.7, {"root": (0.8, 0.6, 0.8), "neck": (1.5, 1.0, 1.0)}, amount=1.0, hz=6, decay=0.85)
shiver(sv, 9.0, 9.5, {"neck": (1.2, 0.8, 0.8)}, amount=1.0, hz=5, decay=0.9, seed=4)
strike(sv, 11.1, body(12, 0, 0, hips=(0, -0.25), drop=0.16, rShoulder=J((46, 0, 66)), lShoulder=J((44, 0, -64))),
       body(-16, 0, 0, hips=(0, -0.45), drop=0.24, neck=J((-12, 0, 0)), rShoulder=CLUTCH, lShoulder=J((30, 0, -40))),
       antic=0.03, travel=0.05, over=0.2, settle=0.2)
body_key(sv, 12.2, "sine", -12, 30, 0, hips=(0.6, 1.2), drop=0.2, neck=(-6, 10, 0), rShoulder=CLUTCH,
         lShoulder=J((60, 0, -80)))
body_key(sv, 13.0, "sine", -6, 40, 0, hips=(0.9, 1.5), drop=0.12, neck=(-4, 20, 0), rShoulder=J((40, 0, -30)),
         lShoulder=HANG_L)
body_key(sv, 14.0, "linear", -6, 40, 0, hips=(0.9, 1.5), drop=0.12, neck=(-6, 20, 0), rShoulder=J((40, 0, -30)),
         lShoulder=HANG_L)
stand(sv, 0.0, 14.0, Feet(stance=0.25, steps=[(3.35, 3.6, 1, -0.4), (3.65, 3.95, -1, -0.9), (11.7, 12.0, 1, (0.9, 1.2, 20)),
                                              (12.1, 12.4, -1, (0.1, 1.6, 30)), (12.6, 12.9, 1, (1.2, 1.7, 40))]))
soft(sv, head=3.2, arms=2.8)
sv.build()

SWORD_UP = J((176, 0, 20))
SWING_END = J((40, 0, -60))
sk = Motion("sceneSamKiller", 14.0, note="The blade: a combo of cuts, the vertical cut, raised in blade mode, the cut "
            "through, the overhead swing, the grab and the thrust, held in, pulled out, the overhead again, at rest.",
            floor=True)
sk.key(0.0, **REST)
READY = dict(neck=(0, 0, 0), rShoulder=J((60, 0, 40)), lShoulder=J((40, 0, -20)))
body_key(sk, 0.0, "smooth", -8, -10, 0, drop=0.2, **READY)
for t, a in ((0.4, -1), (0.75, 1), (1.05, -1)):
    strike(sk, t, body(-8, -10 * a, 0, drop=0.2, rShoulder=J((110, 0, 70 * a)), lShoulder=J((40, 0, -20))),
           body(-14, 14 * a, 0, drop=0.24, rShoulder=J((70, 0, -60 * a)), lShoulder=J((40, 0, -20))), antic=0.04,
           travel=0.04, over=0.2, settle=0.08)
strike(sk, 1.3, body(-6, drop=0.2, rShoulder=SWORD_UP, lShoulder=J((60, 0, -10))),
       body(-20, drop=0.3, rShoulder=J((30, 0, 0)), lShoulder=J((40, 0, -20))), antic=0.08, travel=0.05, over=0.2,
       settle=0.1)
body_key(sk, 2.4, "out", 2, -20, 0, drop=0.12, neck=(6, 0, 0), rShoulder=SWORD_UP, lShoulder=J((90, 0, -30)))
body_key(sk, 3.15, "linear", 3, -20, 0, drop=0.12, neck=(6, 0, 0), rShoulder=SWORD_UP, lShoulder=J((90, 0, -30)))
strike(sk, 3.3, body(3, -20, 0, drop=0.12, rShoulder=SWORD_UP), body(-24, 20, 0, hips=(0, -0.4), drop=0.35,
                                                                     rShoulder=SWING_END), antic=0.02,
       travel=0.04, over=0.2, settle=0.3)
strike(sk, 4.55, body(0, -10, 0, drop=0.15, rShoulder=SWORD_UP), body(-20, 16, 0, drop=0.3, rShoulder=SWING_END),
       antic=0.2, travel=0.05, over=0.15, settle=0.3)
GRAB = dict(neck=(-4, 0, 0), rShoulder=J((40, 0, 30)), lShoulder=reach(-1, (0.2, 0.9, -1.4), direction=(0.3, 0.1, -1)))
body_key(sk, 5.0, "smooth", -6, 0, 0, hips=(0, 0.0), drop=0.12, **GRAB)
body_key(sk, 6.55, "linear", -6, 0, 0, drop=0.12, **GRAB)
THRUST = dict(neck=(-6, 0, 0), rShoulder=reach(1, (0.1, 0.4, -1.7), direction=(-0.2, 0.0, -1.0)),
              lShoulder=GRAB["lShoulder"])
strike(sk, 6.85, body(-6, drop=0.12, **GRAB), body(-16, hips=(0, -0.35), drop=0.2, **THRUST), antic=0.1, travel=0.05,
       over=0.15, settle=0.2)
# held in: leaning his weight on the blade, twisting it once as the victim heaves (9.05)
body_key(sk, 8.4, "smooth", -18, 2, 0, hips=(0, -0.38), drop=0.24, **THRUST)
body_key(sk, 9.1, "out", -20, -5, -2, hips=(0, -0.4), drop=0.26, neck=(-10, -4, 0), rShoulder=THRUST["rShoulder"],
         lShoulder=GRAB["lShoulder"])
body_key(sk, 10.9, "smooth", -16, -2, 0, hips=(0, -0.36), drop=0.22, **THRUST)
strike(sk, 11.1, body(-15, hips=(0, -0.35), drop=0.2, **THRUST),
       body(4, -10, 0, hips=(0, 0.3), drop=0.12, rShoulder=J((60, 0, 60)), lShoulder=J((30, 0, -30))),
       antic=0.03, travel=0.06, over=0.2, settle=0.2)
strike(sk, 12.65, body(0, -10, 0, hips=(0, 0.3), drop=0.12, rShoulder=SWORD_UP),
       body(-18, 14, 0, hips=(0, 0.2), drop=0.25, rShoulder=SWING_END), antic=0.25, travel=0.05, over=0.15, settle=0.3)
body_key(sk, 13.4, "sine", -2, 0, 0, hips=(0, 0.2), drop=0.05, neck=(2, 0, 0), rShoulder=J((10, 0, 20)),
         lShoulder=HANG_L)
body_key(sk, 14.0, "linear", -2, 0, 0, hips=(0, 0.2), drop=0.05, neck=(2, 0, 0), rShoulder=J((10, 0, 20)),
         lShoulder=HANG_L)
stand(sk, 0.0, 14.0, Feet(stance=0.3, steps=[(3.25, 3.45, -1, 0.5), (6.75, 6.95, 1, 0.4), (11.05, 11.3, 1, -0.2)]))
soft(sk, head=3.2, arms=3.4, arm_damp=0.7)  # (the blade arm only trails a little: its cuts land where acted)
sk.build()

# =====================================================================================================================
# Walrider (19.5 s; walrider.md): the victim is the camera; these are the men in the doorway.

AIM = dict(neck=(-4, 0, 0), rShoulder=AIM_R, lShoulder=AIM_L)
LOW_R, LOW_L = J((34, 0, 18)), J((46, 0, -22))  # low ready: the rifle across the body, muzzle down
# Walrider.luau's shots: the first (7.28) is soldier 3's alone, "a soldier at the right raises his rifle"; then the
# volley (VOLLEY there, shot i by soldier (i % 4) + 1). Each soldier recoils on its own shots only.
VOLLEY = (15.55, 15.8, 15.95, 16.15, 16.3, 16.5, 16.62, 16.8, 16.95, 17.1)
SOLDIER_SHOTS = {n: [t for i, t in enumerate(VOLLEY, 1) if i % 4 + 1 == n] for n in (1, 2, 3, 4)}
SOLDIER_SHOTS[3] = [7.28] + SOLDIER_SHOTS[3]
SOLDIER_RAISE = {1: 14.75, 2: 14.5, 3: 5.7, 4: 15.0}  # the right one early; the others as they come in
SOLDIER_CLIPS = []
for n in (1, 2, 3, 4):
    ws = Motion(f"sceneWalriderSoldier{n}", 19.5, note=f"Soldier {n} in the doorway: low ready, the rifle up at the "
                "victim, its own shots.", floor=True)
    ws.key(0.0, **REST)
    turn = (-6, 4, 8, -3)[n - 1]
    body_key(ws, 0.0, "smooth", -4, turn, 0, hips=(0.06 * (n % 2), 0.0), drop=0.1, neck=(-2, -turn * 0.6, 0),
             rShoulder=LOW_R, lShoulder=LOW_L)
    beat(ws, 2.2 + 0.9 * n, dur=0.6, antic=0.1, over=0.06, neck=(0, -turn * 0.6 + (6 if n % 2 else -6), 0))
    raise_at = SOLDIER_RAISE[n]
    body_key(ws, raise_at - 0.55, "smooth", -4, turn, 0, hips=(0.06 * (n % 2), 0.0), drop=0.1, neck=(-2, 0, 0),
             rShoulder=LOW_R, lShoulder=LOW_L)
    body_key(ws, raise_at, "out", -7, 0, 0, drop=0.15, **AIM)  # shouldered fast, settled on the sights
    body_key(ws, raise_at + 0.3, "smooth", -6, 0, 0, drop=0.14, **AIM)
    for t in SOLDIER_SHOTS[n]:
        strike(ws, t, body(-6, drop=0.14, **AIM), body(3, hips=(0, 0.08), drop=0.12, neck=J((-1, 0, 0)),
                                                       rShoulder=AIM_R, lShoulder=AIM_L),
               antic=0.01, travel=0.03, over=0.4, settle=0.16)
    body_key(ws, 19.5, "smooth", -6, 0, 0, drop=0.14, **AIM)
    stand(ws, 0.0, 19.5, Feet(stance=0.2, start={-1: (-0.55, -0.35, -10)}))
    soft(ws, head=2.8, arms=2.4)
    ws.build()
    SOLDIER_CLIPS.append(ws)

wo = Motion("sceneWalriderSeated", 19.5, note="The old man in the wheelchair among the soldiers: sat, watching.",
            floor=False)
SEATED = dict(root=(0, 0, 0), neck=(-8, 0, 0), rShoulder=J((40, 0, 8)), lShoulder=J((40, 0, -8)),
              rHip=J((90, 0, 6)), lHip=J((90, 0, -6)))
wo.key(0.0, offset=(0, -1.0, 0), **SEATED)
wo.key(19.5, offset=(0, -1.0, 0), **SEATED)
alive(wo, amount=0.25, seed=8)
wo.build()

# =====================================================================================================================
# heh, didja really think- (30 s; sans.md)

sn = Motion("sceneSansVictim", 30.0, note="Asleep on his feet for 24 s; the dodge aside; the shrug while he talks; the "
            "cut; standing wounded; hunched down holding it.", floor=True)
sn.key(0.0, **REST)
ASLEEP = dict(neck=(-26, 0, 6), rShoulder=J((4, 0, 6)), lShoulder=J((4, 0, -6)))
# asleep on his feet (sans.md 0-23.75): slow heavy breaths, the head sinking lower and lower until it nods and
# catches itself, then sinking again; each nod its own size and time
body_key(sn, 0.0, "smooth", -4, 0, 2, drop=0.05, **ASLEEP)
for nod, depth in ((4.6, 10), (11.3, 14), (16.2, 8), (21.4, 12)):
    body_key(sn, nod - 0.25, "smooth", -6, 0, 3, drop=0.07, neck=(-26 - depth, 0, 8), rShoulder=ASLEEP["rShoulder"],
             lShoulder=ASLEEP["lShoulder"])
    body_key(sn, nod, "out", -3, 0, 1, drop=0.04, neck=(-20, 0, 4), rShoulder=J((6, 0, 7)), lShoulder=J((6, 0, -7)))
    body_key(sn, nod + 0.6, "smooth", -4, 0, 2, drop=0.05, **ASLEEP)
for k, t in enumerate((1.7, 6.9, 9.0, 13.6, 18.4, 20.0)):
    body_key(sn, t, "smooth", -4 - (k % 2), 0, 2, drop=0.05 + 0.01 * (k % 2), neck=(-27 - 3 * (k % 3), 0, 6),
             rShoulder=ASLEEP["rShoulder"], lShoulder=ASLEEP["lShoulder"])
body_key(sn, 23.8, "smooth", -4, 0, 2, drop=0.05, **ASLEEP)
breaths(sn, 0.0, 23.8, every=2.6, depth=1.8, joint="root")
body_key(sn, 24.0, "snap", 0, 0, 0, hips=(1.4, 0.0), drop=0.0, neck=(4, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(sn, 24.35, "out", 2, 0, 0, hips=(1.4, 0.0), drop=0.0, neck=(6, -6, 6), rShoulder=SHRUG_R, lShoulder=SHRUG_L)
body_key(sn, 25.75, "linear", 2, 0, 0, hips=(1.4, 0.0), drop=0.0, neck=(6, -6, 8), rShoulder=SHRUG_R,
         lShoulder=SHRUG_L)
strike(sn, 25.85, body(2, hips=(1.4, 0.0), rShoulder=SHRUG_R, lShoulder=SHRUG_L),
       body(-10, hips=(1.4, 0.06), drop=0.06, neck=J((-10, 0, 0)), rShoulder=J((30, 0, 20)), lShoulder=J((30, 0, -20))),
       antic=0.02, travel=0.03, over=0.3, settle=0.2)
body_key(sn, 27.3, "linear", -8, hips=(1.4, 0.06), drop=0.05, neck=(-8, 0, 0), rShoulder=J((26, 0, 18)),
         lShoulder=J((26, 0, -18)))
stand(sn, 0.0, 27.45, Feet(steps=[(23.95, 24.05, 1, (1.95, 0.0)), (24.0, 24.12, -1, (0.85, 0.0))]))
SN_HIPS = (1.4, 0.35)
floor_key(sn, 27.65, "in", -6, 0, 0, (1.4, 0.2), crouch_legs(50, 0.5),
          dict(neck=(-16, 0, 0), rShoulder=CLUTCH, lShoulder=OVER_L))
sit_key(sn, 27.8, "in", lean=-18, head=-18, hips=SN_HIPS, rShoulder=CLUTCH, lShoulder=OVER_L)
sit_key(sn, 30.0, "sine", lean=-20, head=-20, hips=SN_HIPS, rShoulder=CLUTCH, lShoulder=OVER_L)
soft(sn, head=2.6, arms=2.4)
sn.build()

# =====================================================================================================================
# and I.. am.. (18 s; ironman.md)

ONE_KNEE = dict(rHip=J((88, 0, 6), (0, 0.4, 0)), lHip=J((-70, 0, -4), (0, 0.15, 0.3)))
FIST_UP = reach(1, (0.55, 1.2, -1.1), direction=(-0.1, 0.8, -0.55))
iv = Motion("sceneIronVictim", 18.0, note="On one knee before the warlord; the gauntlet raised and filled with the "
            "stones; the look up, the line, the snap; staggering back, sat against the wall, gone.", floor=True)
IV_HIPS = (0.0, 0.0)
floor_key(iv, 0.0, "smooth", -6, 0, 0, IV_HIPS, ONE_KNEE, dict(neck=(-6, 0, 0), rShoulder=J((20, 0, 10)),
                                                               lShoulder=J((10, 0, -16))))
floor_key(iv, 2.0, "sine", -4, 0, 0, IV_HIPS, ONE_KNEE, dict(neck=(-4, 0, 0), rShoulder=J((60, 0, 10)),
                                                             lShoulder=J((10, 0, -16))))
floor_key(iv, 3.4, "out", -2, 0, 0, IV_HIPS, ONE_KNEE, dict(neck=(8, 4, 0), rShoulder=FIST_UP, lShoulder=J((10, 0, -16))))
# 5.0-8.5 looking up at the warlord, the gauntlet raised and straining, the line said slowly: "And I..." (a breath,
# the chin up), "am..." (the jaw set, the fist squeezed higher)
floor_key(iv, 5.0, "smooth", -3, 4, 0, IV_HIPS, ONE_KNEE, dict(neck=(14, 8, 2), rShoulder=FIST_UP,
                                                               lShoulder=J((14, 0, -18))))
floor_key(iv, 6.3, "smooth", -1, 3, 1, IV_HIPS, ONE_KNEE, dict(neck=(18, 6, 0), rShoulder=FIST_UP,
                                                               lShoulder=J((16, 0, -20))))
floor_key(iv, 7.4, "out", -4, 5, 0, IV_HIPS, ONE_KNEE, dict(neck=(10, 8, 3), rShoulder=FIST_UP,
                                                            lShoulder=J((18, 0, -22))))
floor_key(iv, 8.4, "smooth", -2, 4, 0, IV_HIPS, ONE_KNEE, dict(neck=(14, 6, 0), rShoulder=FIST_UP,
                                                               lShoulder=J((16, 0, -20))))
shiver(iv, 3.4, 8.5, {"rShoulder": (0.7, 0.4, 0.7)}, amount=1.0, hz=4.5, seed=6)  # the strain of the stones
strike(iv, 8.6, dict(rShoulder=FIST_UP), dict(rShoulder=reach(1, (0.6, 1.3, -1.0), direction=(-0.1, 0.85, -0.5)),
                                              neck=J((14, 6, 0))), antic=0.06, travel=0.03, over=0.4, settle=0.2)
BURNT = J((8, 0, 22), (0, 0.04, 0))
floor_key(iv, 10.0, "sine", -2, 0, 0, IV_HIPS, ONE_KNEE, dict(neck=(6, 0, 0), rShoulder=J((90, 0, 30)),
                                                              lShoulder=J((10, 0, -16))))
floor_key(iv, 12.9, "linear", -4, 0, 0, IV_HIPS, ONE_KNEE, dict(neck=(-4, 0, 0), rShoulder=BURNT,
                                                                lShoulder=J((20, 0, -20))))
IV_SIT = (0.0, 1.4)
floor_key(iv, 13.8, "in", 10, 6, 4, (0.0, 0.8), crouch_legs(50, 0.5),
          dict(neck=(-16, 0, 6), rShoulder=BURNT, lShoulder=J((10, 0, -30))))
sit_key(iv, 14.4, "in", lean=24, turn=6, roll=4, neck=(-14, 0, 8), hips=IV_SIT, rShoulder=BURNT,
        lShoulder=J((-20, 0, -30), (0, 0.06, 0)))
sit_key(iv, 15.6, "sine", lean=26, turn=6, roll=6, neck=(-24, 0, 10), hips=IV_SIT, rShoulder=BURNT,
        lShoulder=J((-16, 0, -28), (0, 0.06, 0)))
sit_key(iv, 18.0, "sine", lean=28, turn=6, roll=8, neck=(-34, 10, 16), hips=IV_SIT, rShoulder=BURNT,
        lShoulder=J((-14, 0, -26), (0, 0.06, 0)))
soft(iv, head=2.4, arms=2.0)
iv.build()

ik = Motion("sceneIronKiller", 18.0, note="The warlord: towering, the empty fist clenched, the turn, sitting down slow "
            "as he goes to ash.", floor=True)
ik.key(0.0, **REST)
body_key(ik, 0.0, "smooth", -4, neck=(-10, 0, 0), rShoulder=J((50, 0, 10)), lShoulder=J((6, 0, -12)))
body_key(ik, 1.8, "out", -4, neck=(-12, 0, 0), rShoulder=J((70, 0, -6)), lShoulder=J((6, 0, -12)))
body_key(ik, 3.6, "sine", -2, neck=(-10, 0, 0), rShoulder=J((60, 0, -6)), lShoulder=J((6, 0, -12)))
body_key(ik, 4.6, "out", 0, neck=(-14, -24, 0), rShoulder=J((40, 0, 6)), lShoulder=J((6, 0, -12)))
# he sees the stones on the gauntlet: the head comes round to it; at "am..." a half step's lean in, too late
body_key(ik, 6.2, "smooth", -2, -6, 0, neck=(-18, -12, -2), rShoulder=J((36, 0, 6)), lShoulder=J((10, 0, -14)))
body_key(ik, 7.8, "out", -6, -8, 0, drop=0.06, neck=(-20, -8, 0), rShoulder=J((58, 0, 12)),
         lShoulder=J((14, 0, -16)))
body_key(ik, 9.0, "snap", 2, -4, 0, drop=0.02, neck=(-8, -6, 0), rShoulder=J((30, 0, 20)), lShoulder=J((20, 0, -24)))
body_key(ik, 10.2, "smooth", 0, -2, 0, drop=0.02, neck=(-10, -4, 0), rShoulder=J((26, 0, 10)),
         lShoulder=J((10, 0, -14)))
stand(ik, 0.0, 10.4, Feet(stance=0.25))
IK_HIPS = (0.0, 1.0)
floor_key(ik, 11.4, "in", 6, 0, 0, (0.0, 0.7), crouch_legs(50, 0.5),
          dict(neck=(-20, 0, 0), rShoulder=J((20, 0, 20)), lShoulder=J((20, 0, -20))))
sit_key(ik, 12.4, "in", lean=12, head=-22, hips=IK_HIPS, rShoulder=J((10, 0, 18)), lShoulder=J((10, 0, -18)))
sit_key(ik, 18.0, "linear", lean=14, head=-26, hips=IK_HIPS, rShoulder=J((10, 0, 18)), lShoulder=J((10, 0, -18)))
ik.build()

isd = Motion("sceneIronSoldier", 18.0, note="One of the army behind the warlord: standing ready, the spear grounded; "
             "each soldier plays it from its own moment (IronMan.luau), so the ranks never move as one.", loop=True,
             floor=True)
isd.key(0.0, **REST)
body_key(isd, 0.0, "smooth", -6, 3, 0, hips=(0.05, 0.0), drop=0.15, neck=(-4, 0, 0), rShoulder=J((50, 0, 20)),
         lShoulder=J((30, 0, -16)))
body_key(isd, 5.0, "smooth", -7, -2, -1, hips=(-0.04, 0.0), drop=0.16, neck=(-6, -8, 0), rShoulder=J((48, 0, 18)),
         lShoulder=J((26, 0, -14)))
body_key(isd, 9.5, "smooth", -5, 4, 1, hips=(0.06, 0.0), drop=0.14, neck=(-2, 6, 2), rShoulder=J((52, 0, 20)),
         lShoulder=J((32, 0, -18)))
body_key(isd, 14.0, "smooth", -6, 0, 0, hips=(0.0, 0.0), drop=0.15, neck=(-5, -3, 0), rShoulder=J((50, 0, 19)),
         lShoulder=J((28, 0, -15)))
stand(isd, 0.0, 18.0, Feet(stance=0.22))
isd.build()

# =====================================================================================================================
# A true patriot (25 s; patriot.md): the grave only.

ps = Motion("scenePatriotSaluter", 25.0, note="At the grave: head bowed at the name; the head comes up; the salute "
            "rises at 8.5 s and holds to the end, the head dipping once.")
body_key(ps, 0.0, "smooth", -3, neck=(-26, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(ps, 6.4, "sine", -3, neck=(-24, 2, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(ps, 8.2, "sine", 0, neck=(-6, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(ps, 8.5, "smooth", 0, neck=(-6, 0, 0), rShoulder=J((6, 0, 10)), lShoulder=HANG_L)
body_key(ps, 9.15, "out", 1, neck=(-8, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
body_key(ps, 13.0, "sine", 1, neck=(-10, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
body_key(ps, 16.5, "sine", 1, neck=(-4, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
body_key(ps, 25.0, "linear", 1, neck=(-2, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
stand(ps, 0.0, 25.0, Feet(stance=0.12))
alive(ps, amount=0.4, seed=3)
soft(ps, head=2.0, arms=2.0)
ps.build()

# =====================================================================================================================
# Dead by selection (12 s; selection.md)

dv = Motion("sceneSelectionVictim", 12.0, note="Staring up at the chart; the lines pass them by; drained, sagging.",
            floor=True)
dv.key(0.0, **REST)
body_key(dv, 0.0, "smooth", 0, neck=(8, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(dv, 8.2, "sine", 0, neck=(10, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(dv, 9.2, "out", -2, neck=(14, -6, 0), rShoulder=J((10, 0, 8)), lShoulder=J((10, 0, -8)))
body_key(dv, 10.5, "sine", -12, drop=0.12, neck=(-20, 0, 0), rShoulder=J((0, 0, 2)), lShoulder=J((0, 0, -2)))
body_key(dv, 12.0, "linear", -14, drop=0.16, neck=(-26, 0, 0), rShoulder=J((0, 0, 2)), lShoulder=J((0, 0, -2)))
stand(dv, 0.0, 12.0, Feet())
alive(dv, amount=0.4, seed=11, t0=0.0, t1=9.0)
dv.build()

SCENE_CLIPS = [m.name for m in (rv, rc, rk, bw, bb, sv, sk, *SOLDIER_CLIPS, wo, sn, iv, ik, isd, ps, dv)]
