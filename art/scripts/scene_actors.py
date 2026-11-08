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
from cinema.acting import alive, soft, strike
from deathkit import (BACK_L, BACK_R, REST, SIDE_R, Feet, body, body_key, floor_key, kneel_key, mix, prone_key, shiver,
                      sit_key, stand)
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


def look_back_hold(m, t0, t1, seed=0):
    """Rewound and frozen in it: twisted round to look back over the left shoulder, the punching arm still out at the
    killer; a stutter now and then as the rewind catches."""
    body_key(m, t0, "out", 4, -18, -3, hips=(0, 0.05), drop=0.03, **LOOK_BACK)
    body_key(m, t1, "linear", 5, -19, -3, hips=(0, 0.05), drop=0.03, **LOOK_BACK)
    k = 0
    t = t0 + 0.9 + 0.31 * seed
    while t < t1 - 0.5:
        s = 1 if k % 2 else -1
        body_key(m, t - 0.04, "linear", 4.5, -18.5, -3, hips=(0, 0.05), drop=0.03, **LOOK_BACK)
        body_key(m, t, "snap", 6, -18 + 3 * s, -3 + 2 * s, hips=(0, 0.05 + 0.06), drop=0.03,
                 neck=(13, 62 + 4 * s, 4), rShoulder=LOOK_BACK["rShoulder"], lShoulder=LOOK_BACK["lShoulder"])
        body_key(m, t + 0.08, "in", 4.5, -18.5, -3, hips=(0, 0.05), drop=0.03, **LOOK_BACK)
        k += 1
        t += 1.7 + 0.37 * ((k + seed) % 3)
    shiver(m, t0, t1, {"neck": (1.2, 1.5, 0.6), "root": (0.4, 0.6, 0.3)}, amount=1.0, hz=7, seed=seed)


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
body_key(rv, 2.6, "sine", -14, 12, 0, hips=(0, -0.6), drop=0.2, neck=(-2, -14, 0), rShoulder=BLOW["rShoulder"],
         lShoulder=BLOW["lShoulder"])  # the shocked profile
stand(rv, 0.0, 3.2, Feet(steps=[(1.05, 1.32, 1, 0.75)]))
look_back_hold(rv, 3.3, 16.5, seed=0)
soft(rv, head=3.6, arms=3.0)
rv.build()

rc = Motion("sceneRequiemCopy", 16.5, note="A copy in the rewound row: frozen looking back over the shoulder, "
            "stuttering.", floor=True)
rc.key(0.0, **REST)
look_back_hold(rc, 0.0, 16.5, seed=2)
rc.build()

rk = Motion("sceneRequiemKiller", 16.5, note="The shadow at the end of the row: tall, still, one hand up, never "
            "touched.", floor=True)
rk.key(0.0, **REST)
KILL = dict(neck=(-6, 0, 0), rShoulder=J((70, 0, 18)), lShoulder=J((8, 0, -14)))
body_key(rk, 0.0, "smooth", -2, **KILL)
body_key(rk, 16.5, "linear", -2, **KILL)
alive(rk, amount=0.35, seed=5)
rk.build()

# =====================================================================================================================
# Blackwall gateway (23.3 s; blackwall.md)

bw = Motion("sceneBlackwallVictim", 23.3, note="Arms crossed, scanned and hacked; the glitch fire takes him: the "
            "pillar, burning, hands to the head, staggering, down.", floor=True)
CROSSED = dict(neck=(2, 0, 0), rShoulder=CROSS_R, lShoulder=CROSS_L)
bw.key(0.0, **REST)
body_key(bw, 0.0, "smooth", 2, **CROSSED)
body_key(bw, 14.6, "linear", 2, **CROSSED)
alive(bw, amount=0.5, seed=1, t0=0.0, t1=14.6)
strike(bw, 14.85, body(2, **CROSSED), body(-6, roll=5, drop=0.04, neck=J((-14, 10, 8)), rShoulder=J((40, 0, 50)),
                                            lShoulder=J((30, 0, -60))), antic=0.03, travel=0.04, over=0.3, settle=0.15)
body_key(bw, 15.5, "sine", -4, 6, 4, drop=0.05, neck=(-10, 12, 8), rShoulder=TEMPLE_R, lShoulder=J((40, 0, -60)))
body_key(bw, 16.15, "in", 6, 0, 0, drop=0.0, neck=(10, 0, 0), rShoulder=TEMPLE_R, lShoulder=TEMPLE_L)
body_key(bw, 16.3, "snap", 16, 0, 0, hips=(0, 0.05), drop=-0.08, neck=(30, 0, 0), rShoulder=J((60, 0, 84)),
         lShoulder=J((60, 0, -84)))  # the pillar: thrown rigid
body_key(bw, 16.9, "out", 12, 0, 2, hips=(0, 0.05), drop=-0.04, neck=(24, 0, 4), rShoulder=J((54, 0, 80)),
         lShoulder=J((56, 0, -80)))
for k, t in enumerate((17.4, 17.9, 18.4, 18.9, 19.4, 19.9, 20.4, 20.9, 21.4)):
    s = 1 if k % 2 else -1
    body_key(bw, t, "sine", -14 - 2 * k, 16 * s, 6 * s, hips=(0.15 * s, 0.1 + 0.05 * k), drop=0.14 + 0.02 * k,
             neck=(-18, 16 * s, 10 * s), rShoulder=TEMPLE_R, lShoulder=TEMPLE_L)
shiver(bw, 15.0, 21.8, {"root": (1.2, 1.0, 1.2), "neck": (2.4, 2.0, 1.5)}, amount=1.0, hz=14)
stand(bw, 0.0, 21.8, Feet(steps=[(17.5, 17.8, -1, -0.3), (18.3, 18.6, 1, -0.45), (19.2, 19.5, -1, -0.55),
                                 (20.1, 20.4, 1, -0.6), (21.0, 21.3, -1, -0.7)]))
BW_HIPS = (0.0, 0.55)
knees_go(bw, 21.8, 22.25, -36, BW_HIPS, neck=(-20, 0, 0), rShoulder=TEMPLE_R, lShoulder=TEMPLE_L)
kneel_key(bw, 22.25, "in", lean=-36, head=-20, hips=BW_HIPS, rShoulder=TEMPLE_R, lShoulder=J((60, 0, -20)))
topple_forward(bw, 22.25, 36.0, BW_HIPS, spin0=2.2, arm="l", hold_r=TEMPLE_R, head0=-20.0, length=3.0)
soft(bw, head=3.2, arms=2.8)
bw.build()

bb = Motion("sceneBlackwallBystander", 23.3, note="Standing by; caught by the spread: burning, doubled over, down.",
            floor=True)
bb.key(0.0, **REST)
body_key(bb, 0.0, "smooth", 0, neck=(0, -10, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(bb, 14.7, "linear", 0, neck=(0, -10, 0), rShoulder=HANG_R, lShoulder=HANG_L)
alive(bb, amount=0.6, seed=4, t0=0.0, t1=14.7)
for k, t in enumerate((15.0, 15.5, 16.0, 16.5, 17.0)):
    s = 1 if k % 2 else -1
    body_key(bb, t, "sine", -10 - 4 * k, 12 * s, 8 * s, hips=(0.1 * s, 0.05 * k), drop=0.1 + 0.03 * k,
             neck=(-20, 10 * s, 0), rShoulder=J((60 + 20 * (k % 2), 0, 50)), lShoulder=J((70, 0, -40)))
shiver(bb, 14.8, 17.4, {"root": (1.5, 1.0, 1.5)}, amount=1.0, hz=12, seed=3)
stand(bb, 0.0, 17.3, Feet())
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
for k, t in enumerate((7.6, 8.4, 9.2, 10.0, 10.8)):
    s = 1 if k % 2 else -1
    body_key(sv, t, "sine", 12 + 2 * s, 4 * s, 3 * s, hips=(0, -0.25), drop=0.16, neck=(20 + 4 * s, 6 * s, 0),
             rShoulder=J((46, 0, 66 + 6 * s)), lShoulder=J((44, 0, -64 - 6 * s)))
shiver(sv, 7.0, 11.0, {"root": (0.8, 0.6, 0.8), "neck": (1.5, 1.0, 1.0)}, amount=1.0, hz=10)
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
body_key(sk, 10.9, "linear", -15, hips=(0, -0.35), drop=0.2, **THRUST)
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
sk.build()

# =====================================================================================================================
# Walrider (19.5 s; walrider.md): the victim is the camera; these are the men in the doorway.

ws = Motion("sceneWalriderSoldier", 19.5, note="In the doorway: rifle up at the victim; the shot; firing again and "
            "again from 15.5.", floor=True)
ws.key(0.0, **REST)
AIM = dict(neck=(-4, 0, 0), rShoulder=AIM_R, lShoulder=AIM_L)
body_key(ws, 0.0, "smooth", -4, 0, 0, drop=0.1, neck=(0, 0, 0), rShoulder=J((30, 0, 20)), lShoulder=J((40, 0, -20)))
body_key(ws, 5.4, "linear", -4, 0, 0, drop=0.1, neck=(0, 0, 0), rShoulder=J((30, 0, 20)), lShoulder=J((40, 0, -20)))
body_key(ws, 6.2, "out", -6, 0, 0, drop=0.14, **AIM)
for t in (7.3, 15.55, 15.9, 16.25, 16.6, 16.95):
    strike(ws, t, body(-6, drop=0.14, **AIM), body(2, hips=(0, 0.06), drop=0.12, neck=J((-2, 0, 0)), rShoulder=AIM_R,
                                                       lShoulder=AIM_L), antic=0.01, travel=0.03, over=0.4,
           settle=0.18)
body_key(ws, 19.5, "linear", -6, drop=0.14, **AIM)
alive(ws, amount=0.3, seed=6)
ws.build()

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
for k in range(16):
    t = k * 1.5
    body_key(sn, t, "sine", -4, 0, 2, drop=0.05, neck=(-24 - 4 * (k % 2), 0, 6), rShoulder=ASLEEP["rShoulder"],
             lShoulder=ASLEEP["lShoulder"])
body_key(sn, 23.8, "sine", -4, 0, 2, drop=0.05, **ASLEEP)
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
floor_key(iv, 8.4, "linear", -2, 0, 0, IV_HIPS, ONE_KNEE, dict(neck=(12, 6, 0), rShoulder=FIST_UP,
                                                               lShoulder=J((10, 0, -16))))
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
body_key(ik, 10.2, "linear", 0, neck=(-14, -24, 0), rShoulder=J((30, 0, 6)), lShoulder=J((6, 0, -12)))
stand(ik, 0.0, 10.4, Feet(stance=0.25))
IK_HIPS = (0.0, 1.0)
floor_key(ik, 11.4, "in", 6, 0, 0, (0.0, 0.7), crouch_legs(50, 0.5),
          dict(neck=(-20, 0, 0), rShoulder=J((20, 0, 20)), lShoulder=J((20, 0, -20))))
sit_key(ik, 12.4, "in", lean=12, head=-22, hips=IK_HIPS, rShoulder=J((10, 0, 18)), lShoulder=J((10, 0, -18)))
sit_key(ik, 18.0, "linear", lean=14, head=-26, hips=IK_HIPS, rShoulder=J((10, 0, 18)), lShoulder=J((10, 0, -18)))
ik.build()

isd = Motion("sceneIronSoldier", 18.0, note="One of the army behind the warlord: standing ready.", floor=True)
isd.key(0.0, **REST)
body_key(isd, 0.0, "smooth", -6, drop=0.15, neck=(-4, 0, 0), rShoulder=J((50, 0, 20)), lShoulder=J((50, 0, -20)))
body_key(isd, 18.0, "linear", -6, drop=0.15, neck=(-4, 0, 0), rShoulder=J((50, 0, 20)), lShoulder=J((50, 0, -20)))
alive(isd, amount=0.4, seed=9)
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

SCENE_CLIPS = [m.name for m in (rv, rc, rk, bw, bb, sv, sk, ws, wo, sn, iv, ik, isd, ps, dv)]
