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
    selection sceneSelectionVictim (reading the phone, lowering it, the head up to the stars, the phone let go)

Angles as in deathkit: root pitch negative leans forward, arms x 0 hangs / 90 ahead / 180 overhead, z out (right +),
legs x + forward."""

from animlib import J
from cinema.acting import alive, beat, soft, strike
from deathkit import (AHEAD_L, AHEAD_R, BACK_L, BACK_R, REST, SIDE_L, SIDE_R, Feet, body, body_key, breaths, floor_key,
                      kneel_key, mix, prone_key, shiver, sit_key, stand)
from deaths import (CLUTCH, HANG_L, HANG_R, MOUTH_R, OVER_L, THROAT_L, THROAT_R, crouch_legs, topple_back,
                    topple_forward)
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
# Walrider (21.5 s; walrider.md; reworked 2026-11-12): the victim is the camera; these are the men in the doorway.
# The user: "the soldiers arent supposed to walk forward. Theyre supposed to each be doing their own thing, and only the
# soldier in front takes up his gun and starts shooting"; and the shooting: "shot once, then theres a little slowmo
# scene of about 8 seconds and THEN he gets shot completely". So: each man at his own business in the doorway, never
# stepping in; soldier 3 (the front one, at the right) shoulders his rifle (6.5), fires once (SHOT), holds his aim
# through the slow motion (everything he does there drawn out), then empties it (VOLLEY). The rest only flinch.

AIM = dict(neck=(-4, 0, 0), rShoulder=AIM_R, lShoulder=AIM_L)
LOW_R, LOW_L = J((34, 0, 18)), J((46, 0, -22))  # low ready: the rifle across the body, muzzle down
SLUNG_R, SLUNG_L = J((14, 0, 10)), J((26, 0, -14))  # the rifle hanging, the hands resting on it
RADIO_L = reach(-1, (-0.62, 1.5, -0.12), direction=(0.45, 0.85, -0.2))  # the left hand up at the helmet's radio
# (Walrider.luau's SHOT and VOLLEY; the slow motion runs between them)
SHOT = 7.3
VOLLEY = (15.3, 15.42, 15.53, 15.66, 15.78, 15.9, 16.03, 16.15, 16.28, 16.4)
SLOW_FROM, SLOW_TO = 7.4, 15.2
WAL_LEN = 21.5
SOLDIER_CLIPS = []
for n in (1, 2, 3, 4):
    ws = Motion(f"sceneWalriderSoldier{n}", WAL_LEN, note=f"Soldier {n} in the doorway, at his own business; only "
                "soldier 3 shoulders his rifle and fires.", floor=True)
    ws.key(0.0, **REST)
    turn = (-6, 4, 8, -3)[n - 1]
    if n == 1:
        # talking to the man beside him, the rifle low; the head turned to him, a nod; through the slow motion his
        # head comes round to the shot, slow; at the volley a flinch
        body_key(ws, 0.0, "smooth", -3, -14, 0, hips=(0.05, 0.0), drop=0.08, neck=(-2, 22, 0), rShoulder=LOW_R,
                 lShoulder=LOW_L)
        beat(ws, 2.6, dur=0.5, antic=0.1, over=0.05, neck=(6, 24, 0))
        beat(ws, 3.4, dur=0.5, antic=0.1, over=0.05, neck=(-4, 20, 0))
        beat(ws, 4.8, dur=0.6, antic=0.1, over=0.05, neck=(0, 26, 4))
        body_key(ws, SHOT, "smooth", -3, -12, 0, hips=(0.05, 0.0), drop=0.08, neck=(-2, 18, 0), rShoulder=LOW_R,
                 lShoulder=LOW_L)
        body_key(ws, 11.5, "sine", -2, -4, 0, hips=(0.05, 0.0), drop=0.1, neck=(-4, -6, 0), rShoulder=LOW_R,
                 lShoulder=LOW_L)
        body_key(ws, SLOW_TO, "sine", -2, -2, 0, hips=(0.05, 0.0), drop=0.1, neck=(-6, -10, 0), rShoulder=LOW_R,
                 lShoulder=LOW_L)
    elif n == 2:
        # on the radio: the left hand up at his helmet, the head down to listen, the rifle in the right hand
        body_key(ws, 0.0, "smooth", -2, 4, 0, hips=(0.0, 0.0), drop=0.06, neck=(-12, -10, -6), rShoulder=LOW_R,
                 lShoulder=RADIO_L)
        beat(ws, 3.1, dur=0.5, antic=0.08, over=0.04, neck=(-6, -16, -8))
        beat(ws, 5.0, dur=0.6, antic=0.08, over=0.04, neck=(-14, -6, -4))
        body_key(ws, SHOT, "smooth", -2, 4, 0, drop=0.06, neck=(-10, -8, -4), rShoulder=LOW_R, lShoulder=RADIO_L)
        # (slow: the hand comes down from the helmet, the head up)
        body_key(ws, 12.0, "sine", -3, 2, 0, drop=0.08, neck=(-4, 4, 0), rShoulder=LOW_R, lShoulder=LOW_L)
        body_key(ws, SLOW_TO, "sine", -3, 2, 0, drop=0.08, neck=(-3, 6, 0), rShoulder=LOW_R, lShoulder=LOW_L)
    elif n == 4:
        # watching the old man in the chair beside him, the rifle hanging, the weight on one leg, a glance round
        body_key(ws, 0.0, "smooth", -1, -22, 0, hips=(-0.08, 0.0), drop=0.05, neck=(-10, -18, 0),
                 rShoulder=SLUNG_R, lShoulder=SLUNG_L)
        beat(ws, 4.2, dur=0.7, antic=0.1, over=0.05, neck=(-4, 14, 0))
        beat(ws, 5.6, dur=0.7, antic=0.1, over=0.05, neck=(-10, -16, 0))
        body_key(ws, SHOT, "smooth", -1, -20, 0, hips=(-0.08, 0.0), drop=0.05, neck=(-6, 2, 0), rShoulder=SLUNG_R,
                 lShoulder=SLUNG_L)
        body_key(ws, 12.5, "sine", -2, -8, 0, hips=(-0.06, 0.0), drop=0.07, neck=(-4, 10, 0), rShoulder=LOW_R,
                 lShoulder=LOW_L)
        body_key(ws, SLOW_TO, "sine", -2, -6, 0, hips=(-0.06, 0.0), drop=0.07, neck=(-4, 12, 0), rShoulder=LOW_R,
                 lShoulder=LOW_L)
    else:
        # the front man: low ready, watching the victim come; shoulders his rifle; one shot; the aim held through the
        # slow motion (drawn out: the recoil coming back down over seconds); then he empties it
        body_key(ws, 0.0, "smooth", -4, turn, 0, hips=(0.06, 0.0), drop=0.1, neck=(-2, -turn * 0.6, 0),
                 rShoulder=LOW_R, lShoulder=LOW_L)
        beat(ws, 4.6, dur=0.6, antic=0.1, over=0.06, neck=(0, -turn * 0.6 + 6, 0))
        body_key(ws, 5.95, "smooth", -4, turn, 0, hips=(0.06, 0.0), drop=0.1, neck=(-2, 0, 0), rShoulder=LOW_R,
                 lShoulder=LOW_L)
        body_key(ws, 6.5, "out", -7, 0, 0, drop=0.15, **AIM)  # shouldered fast, settled on the sights
        body_key(ws, 6.8, "smooth", -6, 0, 0, drop=0.14, **AIM)
        strike(ws, SHOT, body(-6, drop=0.14, **AIM), body(3, hips=(0, 0.08), drop=0.12, neck=J((-1, 0, 0)),
                                                         rShoulder=AIM_R, lShoulder=AIM_L),
               antic=0.01, travel=0.03, over=0.3, settle=0.2)
        body_key(ws, 9.0, "sine", 1, 0, 0, hips=(0, 0.05), drop=0.13, **AIM)
        body_key(ws, SLOW_TO, "sine", -6, 0, 0, drop=0.14, **AIM)
        for t in VOLLEY:
            strike(ws, t, body(-6, drop=0.14, **AIM), body(2, hips=(0, 0.06), drop=0.12, neck=J((-1, 0, 0)),
                                                       rShoulder=AIM_R, lShoulder=AIM_L),
                   antic=0.01, travel=0.025, over=0.04, settle=0.05)
        body_key(ws, 17.0, "smooth", -5, 0, 0, drop=0.14, **AIM)
        body_key(ws, 18.5, "smooth", -8, 0, 0, drop=0.16, neck=(-14, 0, 0), rShoulder=AIM_R, lShoulder=AIM_L)
    if n != 3:
        # (the volley: a flinch, the head turning to it; then still)
        beat(ws, 15.45, dur=0.15, antic=0.02, over=0.08, neck=(-6, (8 if n % 2 else -8), 0))
        body_key(ws, 17.0, "smooth", -3, 0, 0, drop=0.08, neck=(-8, 0, 0), rShoulder=LOW_R, lShoulder=LOW_L)
    body_key(ws, WAL_LEN, "smooth", -4, 0, 0, drop=0.1, neck=(-10, 0, 0),
             rShoulder=AIM_R if n == 3 else LOW_R, lShoulder=AIM_L if n == 3 else LOW_L)
    stand(ws, 0.0, WAL_LEN, Feet(stance=0.2, start={-1: (-0.55, -0.35, -10)}))
    alive(ws, amount=0.35, seed=30 + n)
    soft(ws, head=2.8, arms=2.4)
    ws.build()
    SOLDIER_CLIPS.append(ws)

wo = Motion("sceneWalriderSeated", WAL_LEN, note="The old man in the wheelchair among the soldiers: sat, watching.",
            floor=False)
SEATED = dict(root=(0, 0, 0), neck=(-8, 0, 0), rShoulder=J((40, 0, 8)), lShoulder=J((40, 0, -8)),
              rHip=J((90, 0, 6)), lHip=J((90, 0, -6)))
wo.key(0.0, offset=(0, -1.0, 0), **SEATED)
wo.key(WAL_LEN, offset=(0, -1.0, 0), **SEATED)
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
ARM_HELD = J((62, 0, 26), (0, 0.06, -0.1))  # (the left hand across to the burnt arm)
# (2026-11-12, the user: the falls were "extremely stiff": weight first, then the body follows, then it settles)
floor_key(iv, 13.4, "smooth", 18, 4, 2, (0.0, 0.25), crouch_legs(62, 0.35),
          dict(neck=(-20, 0, 4), rShoulder=BURNT, lShoulder=ARM_HELD))
floor_key(iv, 13.7, "smooth", 6, 8, 6, (0.0, 0.55), crouch_legs(70, 0.42),
          dict(neck=(-8, 10, 6), rShoulder=BURNT, lShoulder=ARM_HELD))
floor_key(iv, 13.92, "in", -8, 6, 4, (0.0, 0.85), crouch_legs(58, 0.48),
          dict(neck=(6, 4, 2), rShoulder=BURNT, lShoulder=J((-10, 0, -40))))
sit_key(iv, 14.25, "in", lean=12, turn=6, roll=6, neck=(4, 0, 6), hips=IV_SIT, rShoulder=BURNT,
        lShoulder=J((-24, 0, -34), (0, 0.06, 0)))
sit_key(iv, 14.7, "out", lean=30, turn=6, roll=4, neck=(-22, 0, 8), hips=IV_SIT, rShoulder=BURNT,
        lShoulder=J((-20, 0, -30), (0, 0.06, 0)))
sit_key(iv, 15.6, "sine", lean=26, turn=6, roll=6, neck=(-24, 0, 10), hips=IV_SIT, rShoulder=BURNT,
        lShoulder=J((-16, 0, -28), (0, 0.06, 0)))
sit_key(iv, 18.0, "sine", lean=28, turn=6, roll=8, neck=(-34, 10, 16), hips=IV_SIT, rShoulder=BURNT,
        lShoulder=J((-14, 0, -26), (0, 0.06, 0)))
alive(iv, amount=0.35, seed=12)
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
body_key(ik, 9.0, "snap", -7, -4, 0, drop=0.04, neck=(-2, -6, 0), rShoulder=J((46, 0, 30)),
         lShoulder=J((42, 0, -30)))
body_key(ik, 9.55, "out", 3, -10, -2, drop=0.08, neck=(-14, -22, 0), rShoulder=J((34, 0, 22)),
         lShoulder=J((30, 0, -22)))
body_key(ik, 10.3, "smooth", 2, 8, 2, drop=0.06, neck=(-12, 26, 0), rShoulder=J((26, 0, 16)),
         lShoulder=J((30, 0, -18)))
body_key(ik, 11.0, "sine", 9, 0, 0, drop=0.08, neck=(-30, 0, 0), rShoulder=J((40, 0, 10)),
         lShoulder=J((40, 0, -10)))
stand(ik, 0.0, 11.0, Feet(stance=0.25))
IK_HIPS = (0.0, 1.0)
floor_key(ik, 11.55, "in", 16, 0, 0, (0.0, 0.45), crouch_legs(40, 0.35),
          dict(neck=(-26, 0, 0), rShoulder=J((24, 0, 24)), lShoulder=J((24, 0, -24))))
floor_key(ik, 11.95, "smooth", 20, 0, 0, (0.0, 0.8), crouch_legs(62, 0.5),
          dict(neck=(-22, 0, 0), rShoulder=J((10, 0, 26)), lShoulder=J((10, 0, -26))))
sit_key(ik, 12.35, "in", lean=24, head=-24, hips=IK_HIPS, rShoulder=J((16, 0, 18)), lShoulder=J((16, 0, -18)))
sit_key(ik, 12.8, "out", lean=8, head=-18, hips=IK_HIPS, rShoulder=J((12, 0, 18)), lShoulder=J((12, 0, -18)))
sit_key(ik, 14.0, "sine", lean=12, head=-26, hips=IK_HIPS, rShoulder=J((10, 0, 18)), lShoulder=J((10, 0, -18)))
sit_key(ik, 18.0, "linear", lean=16, head=-34, hips=IK_HIPS, rShoulder=J((8, 0, 16)), lShoulder=J((8, 0, -16)))
alive(ik, amount=0.5, seed=21)
soft(ik, head=2.6, arms=2.2)
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
# Dead by selection (14 s; selection.md, redone 2026-11-10: the phone, then the sky)

# The reading hand: the phone held up before the chest, the forearm up and in (scene_costumes solves the phone on it).
PHONE_R = reach(1, (0.32, 0.45, -0.95), direction=(-0.12, 0.62, -0.78))
PHONE_SCROLL = reach(1, (0.32, 0.41, -0.97), direction=(-0.12, 0.6, -0.8))
PHONE_SAG = reach(1, (0.34, 0.3, -0.9), direction=(-0.1, 0.5, -0.85))
PHONE_LOW = J((12, 0, 7), (0, 0.02, 0))

dv = Motion("sceneSelectionVictim", 14.0, note="Reading the phone, head down, weight on one leg; it lands, the breath "
            "goes out; the phone comes down; the head comes up to the stars, a slow shake of it, chin high; the hand "
            "opens and the phone is let go; standing so to the end.", floor=True)
dv.key(0.0, **REST)
# reading: the head down to the phone, the thumb's scroll (the hand dips and comes back), twice
body_key(dv, 0.0, "smooth", -5, 5, 0, hips=(0.06, 0), neck=(-25, -8, 0), rShoulder=PHONE_R, lShoulder=HANG_L)
body_key(dv, 1.2, "sine", -5, 5, 0, hips=(0.06, 0), neck=(-26, -8, 0), rShoulder=PHONE_SCROLL, lShoulder=HANG_L)
body_key(dv, 1.5, "out", -5, 5, 0, hips=(0.06, 0), neck=(-25, -8, 0), rShoulder=PHONE_R, lShoulder=HANG_L)
body_key(dv, 2.9, "sine", -6, 5, 0, hips=(0.06, 0), neck=(-27, -7, 0), rShoulder=PHONE_SCROLL, lShoulder=HANG_L)
body_key(dv, 3.2, "out", -6, 5, 0, hips=(0.06, 0), neck=(-27, -7, 0), rShoulder=PHONE_R, lShoulder=HANG_L)
# it lands: still, then the breath goes out of them and the hand sinks
body_key(dv, 4.5, "sine", -6, 5, 0, hips=(0.06, 0), neck=(-27, -7, 0), rShoulder=PHONE_R, lShoulder=HANG_L)
body_key(dv, 5.5, "smooth", -9, 4, 0, hips=(0.04, 0), drop=0.05, neck=(-31, -5, 0), rShoulder=PHONE_SAG,
         lShoulder=HANG_L)
# the phone comes down to the side
body_key(dv, 6.5, "smooth", -6, 2, 0, hips=(0.02, 0), drop=0.03, neck=(-22, -2, 0), rShoulder=PHONE_LOW,
         lShoulder=HANG_L)
# the head comes up to the sky: the chest opens, the weight goes back onto the heels
body_key(dv, 7.7, "smooth", 5, 0, 0, hips=(0, 0.05), neck=(36, 0, 0), rShoulder=J((8, 0, 8), (0, 0.02, 0)),
         lShoulder=J((4, 0, -7)))
# contempt: a slow shake of the head, the chin high
body_key(dv, 8.4, "sine", 6, 0, 0, hips=(0, 0.05), neck=(37, -10, 0), rShoulder=J((8, 0, 8), (0, 0.02, 0)),
         lShoulder=J((4, 0, -7)))
body_key(dv, 9.0, "sine", 6, 0, 0, hips=(0, 0.05), neck=(38, 8, 0), rShoulder=J((8, 0, 8), (0, 0.02, 0)),
         lShoulder=J((4, 0, -7)))
body_key(dv, 9.5, "sine", 6, 0, 0, hips=(0, 0.05), neck=(37, -3, 0), rShoulder=J((8, 0, 9), (0, 0.02, 0)),
         lShoulder=J((4, 0, -7)))
# the hand opens (Selection.luau drops the phone at 9.7) and the arm falls dead
body_key(dv, 9.72, "out", 6, 0, 0, hips=(0, 0.05), neck=(37, -2, 0), rShoulder=J((10, 0, 13)), lShoulder=J((4, 0, -7)))
body_key(dv, 10.4, "smooth", 7, 0, 0, hips=(0, 0.05), neck=(38, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(dv, 14.0, "sine", 8, 0, 0, hips=(0, 0.06), neck=(40, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
stand(dv, 0.0, 14.0, Feet())
alive(dv, amount=0.4, seed=11, t0=0.0, t1=11.0)
soft(dv, head=3.0, arms=2.4)
dv.build()


# =====================================================================================================================
# The six custom deaths remade as scene deaths (2026-11-11; the user's word of 2026-11-10: their "scenarios, camera
# work, vfx, animation and everything SUCKS"). Each clip runs its scene's whole length; Presentation/SceneDeaths
# stages the set, the cameras and the effects round it.

# A broken heart (12 s): at the bridge's parapet in the rain, reading a letter held in both hands; it lands: the first
# beat a jolt, a hand flying to the chest; the second an arch back, the letter hand flung out (the letter let go); the
# crack: doubled over both hands at the heart, a step back; the knees go; over onto the face; the last breaths.
LETTER_R = reach(1, (0.22, 0.52, -0.86), direction=(-0.25, 0.5, -0.8))
LETTER_L = reach(-1, (-0.16, 0.48, -0.9), direction=(0.25, 0.5, -0.8))
LETTER_LOW = reach(1, (0.3, 0.25, -0.8), direction=(-0.2, 0.3, -0.9))
HEART_HIPS = (0.0, 0.24)

hv = Motion("sceneHeartVictim", 12.0, note="A broken heart: reading a letter in the rain; two beats, the crack; down.",
            floor=True)
hv.key(0.0, **REST)
body_key(hv, 0.0, "smooth", -6, neck=(-22, 0, 0), rShoulder=LETTER_R, lShoulder=LETTER_L)
body_key(hv, 1.8, "sine", -7, neck=(-24, -5, 0), rShoulder=LETTER_R, lShoulder=LETTER_L)
body_key(hv, 3.2, "sine", -6, neck=(-20, 3, 0), rShoulder=LETTER_R, lShoulder=LETTER_L)
body_key(hv, 4.1, "smooth", -4, neck=(-12, 0, 0), rShoulder=LETTER_LOW, lShoulder=mix(LETTER_L, HANG_L, 0.5))
# the first beat: a jolt, the left hand flying to the heart
strike(hv, 4.5, body(-4, neck=J((-12, 0, 0)), rShoulder=LETTER_LOW, lShoulder=mix(LETTER_L, HANG_L, 0.5)),
       body(-13, roll=2, drop=0.05, neck=J((-4, 6, 0)), rShoulder=LETTER_LOW, lShoulder=OVER_L),
       antic=0.06, travel=0.05, over=0.18, settle=0.3)
body_key(hv, 5.3, "sine", -11, roll=2, drop=0.05, neck=(-8, 4, 0), rShoulder=LETTER_LOW, lShoulder=OVER_L)
# the second: an arch back, the letter hand flung out (the letter goes)
strike(hv, 5.75, body(-11, drop=0.05, neck=J((-8, 4, 0)), rShoulder=LETTER_LOW, lShoulder=OVER_L),
       body(7, roll=-2, drop=0.02, neck=J((18, 0, -4)), rShoulder=J((38, 0, 46)), lShoulder=OVER_L),
       antic=0.08, travel=0.05, over=0.22, settle=0.3)
# the crack: doubled over, both hands at the heart, a step back
body_key(hv, 6.6, "in", -24, roll=3, hips=(0, 0.1), drop=0.14, neck=(-18, 0, 2), rShoulder=CLUTCH, lShoulder=OVER_L)
body_key(hv, 7.2, "out", -27, roll=4, hips=HEART_HIPS, drop=0.2, neck=(-14, -4, 3), rShoulder=CLUTCH,
         lShoulder=OVER_L)
stand(hv, 0.0, 7.5, Feet(steps=[(6.75, 7.15, -1, -0.45)]))
# the knees go
floor_key(hv, 7.75, "in", -30, 0, 3, HEART_HIPS, dict(rHip=J((40, 0, 2)), lHip=J((40, 0, -2))),
          dict(neck=(-20, 0, 2), rShoulder=CLUTCH, lShoulder=OVER_L))
floor_key(hv, 7.92, "in", -32, 0, 3, HEART_HIPS,
          dict(rHip=J((6, 0, 2), (0, 0.06, 0.12)), lHip=J((6, 0, -2), (0, 0.06, 0.12))),
          dict(neck=(-24, 0, 3), rShoulder=CLUTCH, lShoulder=OVER_L))
kneel_key(hv, 8.1, "out", lean=-30, head=-24, hips=HEART_HIPS, rShoulder=CLUTCH, lShoulder=OVER_L)
kneel_key(hv, 9.0, "sine", lean=-22, head=-10, hips=HEART_HIPS, rShoulder=CLUTCH, lShoulder=mix(OVER_L, HANG_L, 0.4))
kneel_key(hv, 9.5, "in", lean=-34, head=-26, hips=HEART_HIPS, rShoulder=CLUTCH, lShoulder=J((60, 0, -6)))
hit = topple_forward(hv, 9.5, 34.0, HEART_HIPS, spin0=1.2, arm="l", hold_r=CLUTCH, head0=-26.0)
breaths(hv, hit + 0.4, 11.9, every=0.85, depth=1.8)
alive(hv, amount=0.35, seed=21, t0=0.0, t1=4.3)
soft(hv, head=3.0, arms=2.6, arm_damp=0.58)
hv.build()

# Frozen where they stood (12 s): the last two slow steps onto the ice; a look down (the frost climbing their boots);
# a foot that will not come up, twice, harder; hugging themselves, shaking; the shaking slowing as a hand reaches out
# ahead; then nothing at all: frozen solid in the reach.
HUG_R = reach(1, (-0.5, 0.3, -0.6), direction=(-0.85, 0.15, -0.45))
HUG_L = reach(-1, (0.52, 0.42, -0.64), direction=(0.85, 0.15, -0.45))
REACH_R = reach(1, (0.42, 0.95, -1.55), direction=(0.1, 0.25, -1.0))
FHIPS = (0.0, -0.7)

fv = Motion("sceneFrostVictim", 12.0, note="Frozen where they stood: steps onto the ice, the feet held, shaking, a "
            "reach, frozen solid.", floor=True)
fv.key(0.0, **REST)
body_key(fv, 0.0, "smooth", -5, neck=(-4, 0, 0), rShoulder=J((-6, 0, 8)), lShoulder=J((12, 0, -8)))
body_key(fv, 0.85, "smooth", -7, hips=(0, -0.35), neck=(-6, 0, 0), rShoulder=J((14, 0, 8)), lShoulder=J((-8, 0, -8)))
body_key(fv, 1.7, "out", -4, hips=FHIPS, neck=(-2, 0, 0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
# a look down: the frost is climbing the boots
body_key(fv, 2.7, "smooth", -12, hips=FHIPS, neck=(-36, 0, 0), rShoulder=J((16, 0, 16)), lShoulder=J((16, 0, -16)))
# a foot that will not come: the body heaves, twice, the arms out for balance
body_key(fv, 3.45, "in", -16, roll=-5, hips=(0.08, -0.7), drop=0.06, neck=(-30, 8, 0), rShoulder=J((42, 0, 46)),
         lShoulder=J((30, 0, -36)))
body_key(fv, 3.9, "out", -8, roll=3, hips=FHIPS, drop=0.02, neck=(-26, 0, 0), rShoulder=J((26, 0, 34)),
         lShoulder=J((22, 0, -30)))
body_key(fv, 4.4, "in", -19, roll=-6, hips=(0.1, -0.7), drop=0.08, neck=(-22, 10, 2), rShoulder=J((56, 0, 52)),
         lShoulder=J((40, 0, -44)))
body_key(fv, 4.95, "out", -9, roll=2, hips=FHIPS, drop=0.04, neck=(-14, 0, 0), rShoulder=J((20, 0, 26)),
         lShoulder=J((18, 0, -24)))
shiver(fv, 3.3, 5.2, {"root": (0.8, 0.4, 1.4), "neck": (1.0, 0.6, 0.6)}, amount=0.8, hz=7.0, seed=4)
# hugging themselves, shaking hard, the head coming up
body_key(fv, 5.8, "smooth", -6, hips=FHIPS, drop=0.1, neck=(-8, 0, 0), rShoulder=HUG_R, lShoulder=HUG_L)
body_key(fv, 7.0, "sine", -5, hips=FHIPS, drop=0.11, neck=(-2, -4, 0), rShoulder=HUG_R, lShoulder=HUG_L)
shiver(fv, 5.6, 8.7, {"root": (1.4, 0.6, 1.2), "neck": (2.0, 1.2, 1.0), "rShoulder": (3.0, 0, 2.0),
                      "lShoulder": (3.0, 0, 2.0)}, amount=1.0, hz=11.0, decay=0.85, seed=6)
# the reach: one hand out ahead, slower and slower; then frozen in it
body_key(fv, 8.3, "out", -9, hips=FHIPS, drop=0.1, neck=(4, 0, 0), rShoulder=REACH_R, lShoulder=HUG_L)
body_key(fv, 8.75, "out", -9.4, hips=FHIPS, drop=0.1, neck=(5, 0, 0), rShoulder=REACH_R, lShoulder=HUG_L)
body_key(fv, 12.0, "linear", -9.4, hips=FHIPS, drop=0.1, neck=(5, 0, 0), rShoulder=REACH_R, lShoulder=HUG_L)
# (the feet step only while walking: frozen, the legs stay straight under the body, the soles where they stopped)
stand(fv, 0.0, 2.2, Feet(steps=[(0.1, 0.8, 1, 0.7), (0.8, 1.55, -1, 0.7)]))
alive(fv, amount=0.3, seed=7, t0=0.0, t1=2.6)
soft(fv, head=2.6, arms=2.2)
fv.build()

# Struck by lightning (10 s): on the hilltop in the storm looking out; the head comes up to the sky, a hand lifting palm
# up (the air prickling); the bolt: thrown rigid, arched, up on the toes, arms flung out and up, shaking; limp at
# once, the knees gone, sat down hard and over onto the back; a last twitch.
lv = Motion("sceneLightningVictim", 10.0, note="Struck by lightning: looking up into the storm, the bolt, rigid and "
            "shaking, down on the back.", floor=True)
lv.key(0.0, **REST)
body_key(lv, 0.0, "smooth", -3, neck=(2, 0, 0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
body_key(lv, 1.6, "sine", -4, neck=(4, -10, 0), rShoulder=J((6, 0, 8)), lShoulder=J((4, 0, -8)))
body_key(lv, 2.6, "smooth", 3, neck=(30, 4, 0), rShoulder=reach(1, (0.5, 0.6, -0.85), direction=(0.2, 0.3, -1.0)),
         lShoulder=J((8, 0, -10)))
body_key(lv, 3.5, "sine", 4, drop=-0.03, neck=(34, 0, 0), rShoulder=reach(1, (0.55, 0.75, -0.8),
                                                                           direction=(0.25, 0.4, -0.9)),
         lShoulder=J((14, 0, -18)))
STRUCK = 3.85
strike(lv, STRUCK, body(4, drop=-0.03, neck=J((34, 0, 0)), rShoulder=J((60, 0, 30)), lShoulder=J((14, 0, -18))),
       body(16, drop=-0.14, neck=J((38, 0, 0)), rShoulder=J((148, 0, 64)), lShoulder=J((148, 0, -64))),
       antic=0.02, travel=0.04, over=0.1, settle=0.2)
body_key(lv, 5.4, "linear", 15, drop=-0.12, neck=(36, 0, 0), rShoulder=J((144, 0, 62)), lShoulder=J((144, 0, -62)))
shiver(lv, STRUCK + 0.02, 5.5, {"root": (2.5, 1.2, 2.0), "neck": (4.0, 3.0, 2.0), "rShoulder": (6.0, 2.0, 5.0),
                               "lShoulder": (6.0, 2.0, 5.0)}, amount=1.0, hz=17.0, decay=0.35, seed=11)
# limp: the arms drop, the knees go, sat down hard
body_key(lv, 5.75, "in", -4, drop=0.25, neck=(-10, 0, 0), rShoulder=J((10, 0, 14)), lShoulder=J((10, 0, -14)))
stand(lv, 0.0, 5.9, Feet())
LHIPS = (0.0, 0.42)
sit_key(lv, 6.25, "in", lean=22, hips=LHIPS, neck=(-16, 0, 0), rShoulder=J((-10, 0, 24)), lShoulder=J((-10, 0, -24)))
hit = topple_back(lv, 6.25, 22.0, LHIPS, spin0=1.4, head0=-16.0)
shiver(lv, hit + 0.9, hit + 1.25, {"rShoulder": (6, 0, 4), "root": (1.2, 0, 0.6)}, amount=1.0, hz=13.0, seed=12)
alive(lv, amount=0.45, seed=13, t0=0.0, t1=3.6)
soft(lv, head=3.0, arms=2.4)
lv.build()

# Choked on a potato chip (11 s): behind the desk, a hand into the bag; the chip held up; the flourish (Light's: the arm
# sweeping out wide and up, the body turning with it); "and EAT IT": the hand to the mouth, the head back; the crunch;
# frozen; hands to the throat; staggering back, a hand out; the knees; over onto the face.
BAG_R = reach(1, (0.5, -0.05, -1.25), direction=(0.1, -0.5, -0.85))
HELD_R = reach(1, (0.35, 0.55, -0.8), direction=(0.0, 0.5, -0.85))
SWEEP_R = J((118, 0, 78))
CHIP_HIPS = (0.0, 0.55)

cv = Motion("sceneChipVictim", 11.0, note="Choked on a potato chip: the chip, the flourish, the bite, the crunch, "
            "choking, down.", floor=True)
cv.key(0.0, **REST)
body_key(cv, 0.0, "smooth", -8, neck=(-26, 0, 0), rShoulder=J((10, 0, 10)), lShoulder=J((8, 0, -8)))
body_key(cv, 0.9, "smooth", -16, neck=(-30, 6, 0), rShoulder=BAG_R, lShoulder=J((8, 0, -8)))
body_key(cv, 1.6, "out", -6, neck=(-14, 0, 0), rShoulder=HELD_R, lShoulder=J((8, 0, -8)))
# the flourish
body_key(cv, 2.35, "in", -2, yaw=18, neck=(-4, -14, 4), rShoulder=SWEEP_R, lShoulder=J((26, 0, -30)))
body_key(cv, 2.75, "smooth", 2, yaw=22, neck=(8, -18, 6), rShoulder=J((140, 0, 64)), lShoulder=J((30, 0, -36)))
# "and EAT IT": the hand snaps to the mouth, the head back
strike(cv, 3.15, body(2, yaw=22, neck=J((8, -18, 6)), rShoulder=J((140, 0, 64)), lShoulder=J((30, 0, -36))),
       body(10, yaw=-8, neck=J((20, 6, -2)), rShoulder=MOUTH_R, lShoulder=J((20, 0, -26))),
       antic=0.1, travel=0.05, over=0.2, settle=0.22)
CRUNCH = 3.38
body_key(cv, CRUNCH, "in", 8, yaw=-6, drop=0.02, neck=(16, 4, -2), rShoulder=MOUTH_R, lShoulder=J((20, 0, -26)))
body_key(cv, 4.7, "linear", 7, yaw=-6, drop=0.03, neck=(15, 4, -2), rShoulder=MOUTH_R, lShoulder=J((20, 0, -26)))
shiver(cv, CRUNCH + 0.05, 4.7, {"neck": (0.6, 0.4, 0.4), "root": (0.3, 0, 0.3)}, amount=1.0, hz=9.0, seed=14)
# hands to the throat
strike(cv, 5.0, body(7, yaw=-6, neck=J((15, 4, -2)), rShoulder=MOUTH_R, lShoulder=J((20, 0, -26))),
       body(-12, drop=0.08, neck=J((10, 0, 0)), rShoulder=THROAT_R, lShoulder=THROAT_L),
       antic=0.05, travel=0.06, over=0.2, settle=0.3)
# staggering back, a hand out
body_key(cv, 5.9, "smooth", -18, roll=-4, hips=(0, 0.25), drop=0.12, neck=(-2, -8, 0), rShoulder=THROAT_R,
         lShoulder=THROAT_L)
body_key(cv, 6.7, "smooth", -14, roll=5, hips=(0.1, 0.5), drop=0.14, neck=(6, 10, 0), rShoulder=THROAT_R,
         lShoulder=reach(-1, (-0.3, 0.6, -1.4), direction=(-0.1, 0.2, -1.0)))
body_key(cv, 7.4, "in", -26, roll=2, hips=CHIP_HIPS, drop=0.2, neck=(-10, 4, 0), rShoulder=THROAT_R,
         lShoulder=reach(-1, (-0.25, 0.4, -1.35), direction=(-0.1, 0.0, -1.0)))
stand(cv, 0.0, 7.7, Feet(steps=[(5.4, 5.8, 1, -0.4), (6.0, 6.45, -1, -0.5), (6.8, 7.2, 1, -0.15)]))
floor_key(cv, 7.95, "in", -32, 0, 2, CHIP_HIPS, dict(rHip=J((40, 0, 2)), lHip=J((40, 0, -2))),
          dict(neck=(-18, 0, 0), rShoulder=THROAT_R, lShoulder=J((70, 0, -8))))
floor_key(cv, 8.1, "in", -34, 0, 2, CHIP_HIPS,
          dict(rHip=J((6, 0, 2), (0, 0.06, 0.12)), lHip=J((6, 0, -2), (0, 0.06, 0.12))),
          dict(neck=(-22, 0, 0), rShoulder=THROAT_R, lShoulder=J((80, 0, -8))))
kneel_key(cv, 8.25, "in", lean=-36, head=-22, hips=CHIP_HIPS, rShoulder=THROAT_R, lShoulder=J((90, 0, -8)))
hit = topple_forward(cv, 8.25, 36.0, CHIP_HIPS, spin0=1.4, arm="l", hold_r=THROAT_R, head0=-22.0)
breaths(cv, hit + 0.4, 10.9, every=0.6, depth=2.0)
alive(cv, amount=0.35, seed=15, t0=0.0, t1=1.8)
soft(cv, head=3.0, arms=2.8, arm_damp=0.55)
cv.build()

# Their time ran out (11 s): a look at the wrist; the head up, round at the ticking; then they try to walk ahead, but
# time moves only in ticks: each tick jumps them into the next moment and holds them there, the ticks further and
# further apart; at the last, they are stopped dead mid-stride, reaching.
WRIST_L = reach(-1, (-0.15, 0.62, -0.72), direction=(0.3, 0.4, -0.85))
TICKS = [2.7, 3.25, 3.9, 4.65, 5.55, 6.6]
STRIDE = [  # (pitch, hips z, neck, right arm, left arm) at each tick: a walk forward, slower and leaning more
    (-6, -0.25, (-2, 0, 0), J((-18, 0, 8)), J((20, 0, -8))),
    (-8, -0.55, (-4, 0, 0), J((22, 0, 8)), J((-16, 0, -8))),
    (-9, -0.85, (-2, 0, 0), J((-20, 0, 8)), J((24, 0, -8))),
    (-10, -1.15, (0, 0, 0), J((26, 0, 8)), J((-18, 0, -8))),
    (-11, -1.45, (2, 0, 0), J((-14, 0, 8)), J((40, 0, -8))),
    (-12, -1.7, (6, 0, 0), reach(1, (0.4, 0.9, -1.5), direction=(0.1, 0.25, -1.0)), J((-14, 0, -10))),
]

kv = Motion("sceneClockVictim", 11.0, note="Their time ran out: a look at the wrist; walking in ticks, slower and "
            "slower; stopped dead mid-stride.", floor=True)
kv.key(0.0, **REST)
body_key(kv, 0.0, "smooth", -6, neck=(-24, 12, 0), rShoulder=J((6, 0, 8)), lShoulder=WRIST_L)
body_key(kv, 1.2, "sine", -6, neck=(-26, 14, 0), rShoulder=J((6, 0, 8)), lShoulder=WRIST_L)
body_key(kv, 1.8, "smooth", -2, neck=(10, -22, 0), rShoulder=J((6, 0, 8)), lShoulder=J((10, 0, -8)))
body_key(kv, 2.35, "smooth", -2, neck=(8, 20, 0), rShoulder=J((6, 0, 8)), lShoulder=J((8, 0, -8)))
prev = (-2, 0.0, (8, 20, 0), J((6, 0, 8)), J((8, 0, -8)))
for k, (t, pose) in enumerate(zip(TICKS, STRIDE)):
    pitch, hz, neck, ra, la = prev
    body_key(kv, t - 0.001, "linear", pitch, hips=(0, hz), neck=neck, rShoulder=ra, lShoulder=la)
    pitch, hz, neck, ra, la = pose
    body_key(kv, t + 0.07, "out", pitch, hips=(0, hz), neck=neck, rShoulder=ra, lShoulder=la)
    prev = pose
pitch, hz, neck, ra, la = prev
body_key(kv, 11.0, "linear", pitch, hips=(0, hz), neck=neck, rShoulder=ra, lShoulder=la)
steps = []
for k, t in enumerate(TICKS):
    side = 1 if k % 2 == 0 else -1
    steps.append((t, t + 0.07, side, 0.62 if k else 0.4))
stand(kv, 0.0, 11.0, Feet(steps=steps, lift_h=0.0), ramp=0.0)
alive(kv, amount=0.35, seed=16, t0=0.0, t1=2.6)
soft(kv, head=2.4, arms=2.0)
kv.build()

# Taken by the dark (11 s): walking the hall under the bulb; a sound behind: a look back over the shoulder, held,
# staring into the black; the head round again, walking on, faster; the flinch as the bulb fails, looking back again;
# running; the legs yanked out from behind, down on the face; dragged back along the floor in pulls, clawing at the
# boards, into the black.
kd = Motion("sceneDarkVictim", 11.0, note="Taken by the dark: a look back, walking on, the flinch, the run, yanked "
            "down, dragged back into the black.", floor=True)
kd.key(0.0, **REST)
body_key(kd, 0.0, "smooth", -3, neck=(-2, 0, 0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
body_key(kd, 1.5, "sine", -3, neck=(-4, 6, 0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
# a sound behind: the head whips round over the right shoulder, the shoulders after it; held, staring
strike(kd, 1.9, body(-3, neck=J((-4, 6, 0)), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8))),
       body(-1, yaw=-30, neck=J((2, -64, 0)), rShoulder=J((14, 0, 14)), lShoulder=J((20, 0, -14))),
       antic=0.05, travel=0.07, over=0.16, settle=0.3)
body_key(kd, 3.0, "sine", 0, yaw=-32, drop=0.02, neck=(4, -66, 0), rShoulder=J((16, 0, 16)), lShoulder=J((22, 0, -16)))
# round again, walking on, faster
body_key(kd, 3.45, "smooth", -6, yaw=0, hips=(0, -0.3), neck=(-2, 6, 0), rShoulder=J((-16, 0, 8)),
         lShoulder=J((20, 0, -8)))
body_key(kd, 3.95, "smooth", -8, hips=(0, -0.9), neck=(-2, 0, 0), rShoulder=J((22, 0, 8)), lShoulder=J((-18, 0, -8)))
body_key(kd, 4.45, "smooth", -9, hips=(0, -1.55), neck=(-2, -4, 0), rShoulder=J((-20, 0, 8)),
         lShoulder=J((24, 0, -8)))
# the bulb fails: the flinch, a look back again
strike(kd, 4.9, body(-9, hips=(0, -1.55), neck=J((-2, -4, 0)), rShoulder=J((-20, 0, 8)), lShoulder=J((24, 0, -8))),
       body(-4, yaw=-34, hips=(0, -1.75), drop=0.1, neck=J((-6, -58, 0)), rShoulder=J((96, 0, 30)),
            lShoulder=J((60, 0, -20))),
       antic=0.04, travel=0.06, over=0.18, settle=0.25)
# running
body_key(kd, 5.55, "in", -18, yaw=-6, hips=(0, -2.4), drop=0.06, neck=(0, 10, 0), rShoulder=J((50, 0, 10)),
         lShoulder=J((-40, 0, -10)))
body_key(kd, 5.95, "out", -22, hips=(0, -3.4), drop=0.08, neck=(4, 0, 0), rShoulder=J((-40, 0, 8)),
         lShoulder=J((54, 0, -8)))
stand(kd, 0.0, 6.1, Feet(steps=[(3.3, 3.65, 1, 0.6), (3.7, 4.05, -1, 1.2), (4.1, 4.45, 1, 1.85),
                                (5.15, 5.45, -1, 2.6), (5.5, 5.8, 1, 3.6)]))
# the legs yanked out: down on the face, the arms thrown out ahead
YANK = 6.15
body_key(kd, YANK + 0.18, "in", -55, hips=(0, -3.2), drop=0.7, neck=(14, 0, 0), rShoulder=J((150, 0, 12)),
         lShoulder=J((150, 0, -12)))
prone_key(kd, YANK + 0.42, "in", hips=(0, -2.8), neck=(28, 0, 0), rShoulder=AHEAD_R, lShoulder=AHEAD_L)
# dragged back in pulls, clawing at the boards: each pull a hard slide back, the hands raking after it
z = -2.8
for k, t in enumerate((6.9, 7.55, 8.2, 8.8, 9.35, 9.85, 10.3, 10.7)):
    pull = 1.3 + 0.35 * k
    reach_r = J((166, 0, 14)) if k % 2 else J((150, 0, 22))
    reach_l = J((150, 0, -22)) if k % 2 else J((166, 0, -14))
    prone_key(kd, t - 0.25, "sine", hips=(0, z), neck=(30, 0, 4 * (1 if k % 2 else -1)), rShoulder=reach_r,
              lShoulder=reach_l)
    z += pull
    prone_key(kd, t, "in", hips=(0, z), neck=(20, 0, 0), rShoulder=AHEAD_R, lShoulder=AHEAD_L)
alive(kd, amount=0.4, seed=17, t0=0.0, t1=1.8)
soft(kd, head=2.6, arms=2.6)
kd.build()

REMADE_CLIPS = [m.name for m in (hv, fv, lv, cv, kv, kd)]

SCENE_CLIPS = [m.name for m in (rv, rc, rk, bw, bb, sv, sk, *SOLDIER_CLIPS, wo, sn, iv, ik, isd, ps, dv,
                                hv, fv, lv, cv, kv, kd)]
