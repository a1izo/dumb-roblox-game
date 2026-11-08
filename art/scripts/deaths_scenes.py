"""The second batch of custom deaths (asked 2026-11-07/08): each re-acts a famous scene the user named, from the clips
they sent (watched frame by frame; what each shows is in docs/agent-memory/deaths-batch2.md), on our own R6 body with
our own effects (Presentation/DeathVfx, CustomDeaths). Built like deaths.py's (deathkit: gravity falls, hips placement, real steps) and
recorded in its TIMING, so Shared/Anim/DeathTiming has them. anims.py imports this after deaths.py.

  deathRequiem    "This is... requiem": a lunge whose blow stops dead and rewinds to zero in stutters, the hands
                  held up in disbelief, then an unseen barrage and a blow that throws them down; a twitch, again.
  deathBlackwall  "Blackwall gateway": the scan's twitch, hands clutching the head as the red takes the brain,
                  thrown rigid in the burst, down onto the face, glitching.
  deathGod        "A GOD.. IS NOT... AFRAID OF...": risen defiant with the arms spread, shaking as it tears them
                  apart, onto the knees and down.
  deathIronMan    "and I.. am..": the fist raised and looked at, the look up, the snap; staggering back with the
                  burnt arm hanging, sat down, slumped, gone.
  deathSam        "Let's dance!": braced at the draw, time all but stopped while the cuts are drawn, the cuts
                  landing in four jolts, falling apart.
  deathWalrider   "Walrider": shot four times, stumbling back, down on the back, a hand reaching up at them; the
                  swarm tearing out of the chest; limp.
  deathSans       "heh, didja really think-": asleep on their feet; awake, a lazy sidestep past the first slash, a
                  smug shrug cut off by the second; a hand on the wound, a shrug, a few steps aside, down.
  deathPatriot    "A true patriot": one shot, a hand to the chest, a slow step back looking up at who fired, sat
                  down and laid back in the flowers (the grave and the salute follow in the cutscene)."""

from animlib import J
from deathkit import (BACK_L, BACK_R, OUT_L, OUT_R, REST, SIDE_R, Feet, body, body_key, floor_key, kneel_key, mix,
                      prone_key, shiver, sit_key, stand, supine_key)
from deaths import CLUTCH, HANG_L, HANG_R, OVER_L, crouch_legs, record, topple_back, topple_forward
from cinema.acting import alive, soft, strike
from emotes.kit import reach
from motion import Motion

TEMPLE_R = reach(1, (0.78, 1.45, -0.32), direction=(-0.25, 0.92, -0.3))
TEMPLE_L = reach(-1, (-0.78, 1.42, -0.32), direction=(0.25, 0.92, -0.3))
LOOK_HANDS_R = reach(1, (0.4, 0.55, -1.25), direction=(-0.3, 0.3, -0.9))
LOOK_HANDS_L = reach(-1, (-0.4, 0.55, -1.25), direction=(0.3, 0.3, -0.9))


def knees_go(m, t0, t1, lean, hips, turn=0.0, neck=(-14, 0, 0), **upper):
    """The knees go between t0 (still standing, the feet let go) and t1 (kneeling at `hips`, leaning `lean`, negative
    forward), as the heart attack's: the body drops onto the knees with the legs swung forward under it, then the
    shins fold back along the floor (no frame floats)."""
    d = t1 - t0
    joints = dict(neck=neck, **upper)
    floor_key(m, t0 + 0.45 * d, "in", lean * 0.86, turn, 0, hips, dict(rHip=J((40, 0, 2)), lHip=J((40, 0, -2))),
              joints)
    floor_key(m, t0 + 0.76 * d, "in", lean * 0.95, turn, 0, hips,
              dict(rHip=J((6, 0, 2), (0, 0.06, 0.12)), lHip=J((6, 0, -2), (0, 0.06, 0.12))), joints)

# =====================================================================================================================
# This is... requiem.

rq = Motion("deathRequiem", 4.4, note="A blow that rewinds to zero, disbelief, an unseen barrage, thrown down, again.",
            floor=True)
rq.key(0.0, **REST)
WIND = dict(neck=(4, 8, 0), rShoulder=J((140, 0, 46)), lShoulder=J((24, 0, -22)))
BLOW = dict(neck=(-2, -6, 0), rShoulder=J((92, 0, -14), (0, 0.1, -0.22)), lShoulder=J((-24, 0, -16)))
body_key(rq, 0.2, "in", 6, -12, 0, hips=(0, 0.06), drop=0.1, **WIND)
body_key(rq, 0.42, "snap", -16, 12, 0, hips=(0, -0.5), drop=0.2, **BLOW)
body_key(rq, 0.62, "hold", -16, 12, 0, hips=(0, -0.5), drop=0.2, **BLOW)
# rewound: back through the blow in stutters, to where it began
for t, u in ((0.74, 0.35), (0.84, 0.15), (0.98, 0.6), (1.08, 0.45), (1.22, 0.85), (1.34, 1.0)):
    body_key(rq, t, "snap", -16 + 22 * u, 12 - 24 * u, 0, hips=(0, -0.5 + 0.56 * u), drop=0.2 - 0.1 * u,
             neck=(-2 + 6 * u, -6 + 14 * u, 0), rShoulder=mix(BLOW["rShoulder"], WIND["rShoulder"], u),
             lShoulder=mix(BLOW["lShoulder"], WIND["lShoulder"], u))
# what is this: the hands held up and looked at, the head darting
body_key(rq, 1.62, "sine", -4, 0, 0, hips=(0, 0.04), drop=0.08, neck=(-22, 0, 0), rShoulder=LOOK_HANDS_R,
         lShoulder=LOOK_HANDS_L)
body_key(rq, 1.86, "snap", -4, 6, 0, hips=(0, 0.04), drop=0.08, neck=(-6, 26, 0), rShoulder=LOOK_HANDS_R,
         lShoulder=LOOK_HANDS_L)
body_key(rq, 2.06, "snap", -4, -6, 0, hips=(0, 0.04), drop=0.08, neck=(-4, -28, 0), rShoulder=LOOK_HANDS_R,
         lShoulder=LOOK_HANDS_L)
# the barrage: blow after blow, thrown back a little more each time, the arms knocked about
for k, t in enumerate((2.22, 2.3, 2.38, 2.46, 2.54, 2.62, 2.7, 2.78)):
    s = 1 if k % 2 else -1
    body_key(rq, t, "snap", 6 + 2 * k, 8 * s, 6 * s, hips=(0.04 * s, 0.1 + 0.05 * k), drop=0.1, neck=(10 + k, -10 * s, 0),
             rShoulder=J((40 + 30 * (k % 3), 0, 50)), lShoulder=J((50 + 25 * ((k + 1) % 3), 0, -50)))
stand(rq, 0.0, 2.84, Feet(steps=[(0.2, 0.42, 1, 0.7), (0.98, 1.32, 1, 0.0)]))
# the last blow throws them through the air onto their back
body_key(rq, 2.92, "snap", 30, 0, 0, hips=(0, 0.9), drop=-0.15, neck=(-20, 0, 0), rShoulder=J((100, 0, 30)),
         lShoulder=J((100, 0, -30)), rHip=J((40, 0, 4)), lHip=J((30, 0, -4)))
body_key(rq, 3.18, "in", 66, 0, 0, hips=(0, 2.3), drop=1.1, neck=(-24, 0, 0), rShoulder=J((120, 0, 40)),
         lShoulder=J((120, 0, -40)), rHip=J((60, 0, 4)), lHip=J((50, 0, -4)))
HIT_RQ = 3.36
RQ_HIPS = (0.0, 2.9)
supine_key(rq, HIT_RQ, "in", neck=(30, 0, 0), hips=RQ_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
supine_key(rq, 3.55, "out", neck=(14, 0, 6), hips=RQ_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
# and again: dying over and over (a jolt through the chest, twice)
for t in (3.78, 4.06):
    supine_key(rq, t - 0.03, "smooth", neck=(14, 0, 6), hips=RQ_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
    supine_key(rq, t, "snap", lean=74, neck=(-6, 0, 6), hips=RQ_HIPS, rShoulder=J((40, 0, 70)), lShoulder=J((40, 0, -70)))
    supine_key(rq, t + 0.16, "in", neck=(14, 0, 6), hips=RQ_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
supine_key(rq, 4.4, "smooth", neck=(14, 4, 8), hips=RQ_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
soft(rq, head=4.0, arms=3.6, arm_damp=0.5)
rq.build()
record(rq, HIT_RQ, fx=0.62)

# =====================================================================================================================
# Blackwall gateway.

bw = Motion("deathBlackwall", 3.6, note="The scan's twitch, hands clutching the head, thrown rigid in the burst, down.",
            floor=True)
bw.key(0.0, **REST)
strike(bw, 0.3, body(0), body(-2, roll=6, drop=0.02, neck=J((6, 0, 16))), antic=0.05, travel=0.04, over=0.2, settle=0.1)
for k, t in enumerate((0.52, 0.66, 0.8, 0.94, 1.08, 1.2)):
    s = 1 if k % 2 else -1
    body_key(bw, t, "snap", -10 - k, 6 * s, 6 * s, hips=(0.03 * s, 0.05), drop=0.1 + 0.02 * k, neck=(-12, 14 * s, 12 * s),
             rShoulder=TEMPLE_R, lShoulder=TEMPLE_L)
shiver(bw, 0.5, 1.3, {"root": (1.5, 1.0, 1.5), "neck": (2.5, 2.0, 1.5)}, amount=1.0, hz=16)
body_key(bw, 1.32, "snap", 14, 0, 0, hips=(0, 0.1), drop=-0.06, neck=(26, 0, 0), rShoulder=J((60, 0, 82)),
         lShoulder=J((60, 0, -82)))
body_key(bw, 1.5, "smooth", 12, 0, 2, hips=(0, 0.1), drop=-0.04, neck=(22, 0, 4), rShoulder=J((54, 0, 80)),
         lShoulder=J((56, 0, -80)))
stand(bw, 0.0, 1.55, Feet())
BW_HIPS = (0.0, 0.0)
knees_go(bw, 1.55, 1.9, -36, BW_HIPS, neck=(-16, 0, 4), rShoulder=J((30, 0, 30)), lShoulder=J((30, 0, -30)))
kneel_key(bw, 1.9, "in", lean=-36, head=-20, hips=BW_HIPS, rShoulder=J((20, 0, 12)), lShoulder=J((22, 0, -12)))
hit = topple_forward(bw, 1.9, 36.0, BW_HIPS, spin0=1.6, arm="l", hold_r=J((20, 0, 12)), head0=-20.0)
for t, side in ((hit + 0.55, 1), (hit + 0.85, -1)):
    prone_key(bw, t - 0.03, "smooth", hips=BW_HIPS, lShoulder=J((180, 0, -8)))
    prone_key(bw, t, "snap", neck=(18, 0, 10 * side), hips=BW_HIPS, rShoulder=J((26, 0, 20)) if side > 0 else SIDE_R,
              lShoulder=J((168, 0, -20)))
    prone_key(bw, t + 0.12, "in", hips=BW_HIPS, lShoulder=J((180, 0, -8)))
prone_key(bw, 3.6, "smooth", neck=(12, 0, 14), hips=BW_HIPS, lShoulder=J((180, 0, -8)))
soft(bw, head=3.6, arms=3.2, arm_damp=0.5)
bw.build()
record(bw, hit, fx=0.3)

# =====================================================================================================================
# A GOD.. IS NOT... AFRAID OF...

gd = Motion("deathGod", 4.2, note="Risen defiant, arms spread, shaking as it tears them apart, onto the knees, down.",
            floor=True)
gd.key(0.0, **REST)
DEFY = dict(neck=(26, 0, 0), rShoulder=J((124, 0, 64)), lShoulder=J((124, 0, -64)))
body_key(gd, 0.35, "in", -6, 0, 0, drop=0.08, neck=(-10, 0, 0), rShoulder=J((30, 0, 30)), lShoulder=J((30, 0, -30)))
body_key(gd, 0.8, "out", 12, 0, 0, hips=(0, 0.06), drop=-0.1, **DEFY)
body_key(gd, 2.0, "sine", 14, 0, 0, hips=(0, 0.06), drop=-0.18, **DEFY)
shiver(gd, 0.85, 2.3, {"root": (1.2, 0.8, 1.6), "neck": (2.0, 1.5, 1.0), "rShoulder": (3.0, 0, 3.0),
                       "lShoulder": (3.0, 0, 3.0)}, amount=1.0, hz=13)
body_key(gd, 2.28, "snap", 4, 0, 0, hips=(0, 0.06), drop=-0.1, neck=(10, 0, 0), rShoulder=J((96, 0, 70)),
         lShoulder=J((96, 0, -70)))
stand(gd, 0.0, 2.35, Feet(stance=0.12))
GD_HIPS = (0.0, 0.05)
knees_go(gd, 2.35, 2.62, -12, GD_HIPS, neck=(-4, 0, 0), rShoulder=J((80, 0, 62)), lShoulder=J((80, 0, -62)))
kneel_key(gd, 2.62, "in", lean=-12, head=-10, hips=GD_HIPS, rShoulder=J((60, 0, 50)), lShoulder=J((60, 0, -50)))
kneel_key(gd, 2.82, "sine", lean=-30, head=-18, hips=GD_HIPS, rShoulder=J((40, 0, 30)), lShoulder=J((40, 0, -30)))
hit = topple_forward(gd, 2.82, 30.0, GD_HIPS, spin0=1.4, arm="r", hold_l=J((40, 0, -30)), head0=-18.0)
prone_key(gd, 4.2, "smooth", neck=(12, 0, -14), hips=GD_HIPS, rShoulder=J((180, 0, 8)))
soft(gd, head=3.0, arms=2.6)
gd.build()
record(gd, hit, fx=0.8)

# =====================================================================================================================
# and I.. am..

im = Motion("deathIronMan", 5.4, note="The fist raised and looked at, the look up, the snap, staggering back burnt, "
            "sat down, slumped back.", floor=True)
FIST = reach(1, (0.3, 0.85, -1.45), direction=(-0.2, 0.45, -0.85))
im.key(0.0, **REST)
body_key(im, 0.7, "sine", -4, 0, 0, drop=0.05, neck=(-14, 12, 0), rShoulder=FIST, lShoulder=HANG_L)
body_key(im, 1.25, "sine", -2, 0, 0, drop=0.04, neck=(4, 4, 0), rShoulder=FIST, lShoulder=HANG_L)
body_key(im, 1.6, "smooth", -2, 0, 0, drop=0.04, neck=(6, 0, 0), rShoulder=FIST, lShoulder=HANG_L)
SNAP = 1.7
strike(im, SNAP, dict(rShoulder=reach(1, (0.36, 0.95, -1.4), direction=(-0.2, 0.5, -0.8))),
       body(-6, drop=0.08, rShoulder=reach(1, (0.26, 0.78, -1.5), direction=(-0.25, 0.4, -0.88)), neck=J((2, 0, 0))),
       antic=0.08, travel=0.04, over=0.3, settle=0.12)
BURNT = J((8, 0, 22), (0, 0.04, 0))
body_key(im, 2.05, "sine", 6, 4, 4, hips=(0, 0.3), drop=0.14, neck=(-10, 0, 6), rShoulder=BURNT,
         lShoulder=J((20, 0, -20)))
body_key(im, 2.45, "sine", 4, 8, 6, hips=(0.05, 0.62), drop=0.3, neck=(-16, 0, 8), rShoulder=BURNT,
         lShoulder=J((30, 0, -24)))
stand(im, 0.0, 2.55, Feet(steps=[(1.86, 2.1, 1, -0.42), (2.18, 2.44, -1, -0.78)]))
IM_HIPS = (0.05, 1.05)
floor_key(im, 2.8, "in", 10, 8, 6, (0.05, 0.85), crouch_legs(50, 0.5),
          dict(neck=(-18, 0, 8), rShoulder=BURNT, lShoulder=J((10, 0, -30))))
sit_key(im, 3.1, "in", lean=20, turn=8, roll=4, neck=(-16, 0, 10), hips=IM_HIPS, rShoulder=BURNT,
        lShoulder=J((-20, 0, -30), (0, 0.06, 0)))
sit_key(im, 3.9, "sine", lean=24, turn=8, roll=6, neck=(-30, 0, 14), hips=IM_HIPS, rShoulder=BURNT,
        lShoulder=J((-16, 0, -28), (0, 0.06, 0)))
hit = topple_back(im, 4.2, 24.0, IM_HIPS, spin0=0.6, length=3.4, turn=8,
                  arms=lambda u: dict(rShoulder=mix(BURNT, BACK_R, u), lShoulder=mix(J((-16, 0, -28)), BACK_L, u)),
                  head0=-30.0)
supine_key(im, 5.4, "sine", turn=8, neck=(14, 18, -8), hips=IM_HIPS, rShoulder=BACK_R, lShoulder=BACK_L)
soft(im, head=2.4, arms=2.0)
im.build()
record(im, hit, fx=SNAP)

# =====================================================================================================================
# Let's dance!

sm = Motion("deathSam", 3.8, note="Braced at the draw, time all but stopped while the cuts are drawn, four cuts, "
            "falling apart.", floor=True)
DRAW_R = reach(1, (-0.55, -0.55, -0.55), direction=(-0.7, -0.3, -0.6))
DRAW_L = reach(-1, (-0.75, -0.75, -0.25), direction=(0.1, -0.9, -0.3))
sm.key(0.0, **REST)
body_key(sm, 0.35, "out", -12, -20, 0, hips=(0, 0.1), drop=0.32, neck=(10, 18, 0), rShoulder=DRAW_R, lShoulder=DRAW_L)
# blade mode: all but frozen while the cuts are drawn on them
body_key(sm, 1.55, "sine", -13, -21, 1, hips=(0, 0.1), drop=0.33, neck=(8, 16, 2), rShoulder=DRAW_R, lShoulder=DRAW_L)
for k, t in enumerate((1.62, 1.72, 1.82, 1.92)):
    s = 1 if k % 2 else -1
    body_key(sm, t, "snap", -14 + 4 * s, -20 + 10 * s, 6 * s, hips=(0.03 * s, 0.12), drop=0.34, neck=(4, 10 * s, 8 * s),
             rShoulder=mix(DRAW_R, HANG_R, 0.3 * (k + 1)), lShoulder=mix(DRAW_L, HANG_L, 0.3 * (k + 1)))
stand(sm, 0.0, 2.0, Feet(stance=0.25, steps=[(0.1, 0.32, -1, (-0.85, 0.35))]))
SM_HIPS = (0.0, 0.1)
knees_go(sm, 2.0, 2.3, -28, SM_HIPS, turn=-8, neck=(-8, 0, 8), rShoulder=J((10, 0, 14)), lShoulder=J((12, 0, -14)))
kneel_key(sm, 2.3, "in", lean=-28, turn=-8, head=-16, hips=SM_HIPS, rShoulder=J((10, 0, 14)), lShoulder=J((12, 0, -14)))
hit = topple_forward(sm, 2.3, 28.0, SM_HIPS, spin0=1.7, arm="l", hold_r=J((10, 0, 14)), head0=-16.0, turn=-8)
prone_key(sm, 3.8, "smooth", turn=-8, neck=(12, 0, 16), hips=SM_HIPS, lShoulder=J((180, 0, -8)))
soft(sm, head=3.4, arms=3.0)
sm.build()
record(sm, hit, fx=0.4)

# =====================================================================================================================
# Walrider.

wr = Motion("deathWalrider", 4.8, note="Shot four times, stumbling back, down on the back, a hand reaching up, the "
            "swarm tearing out, limp.", floor=True)
wr.key(0.0, **REST)
for k, t in enumerate((0.25, 0.5, 0.72, 0.98)):
    s = 1 if k % 2 else -1
    strike(wr, t, body(-2 + 2 * k, hips=(0, 0.1 + 0.25 * k), drop=0.06 + 0.04 * k),
           body(8 + 3 * k, 6 * s, 4 * s, hips=(0.04 * s, 0.22 + 0.25 * k), drop=0.08 + 0.05 * k,
                neck=J((-8 - 2 * k, -8 * s, 0)), rShoulder=CLUTCH if k >= 1 else J((30, 0, 40)),
                lShoulder=J((30 + 10 * k, 0, -40))), antic=0.03, travel=0.04, over=0.2, settle=0.1)
stand(wr, 0.0, 1.1, Feet(steps=[(0.28, 0.48, 1, -0.4), (0.55, 0.75, -1, -0.7), (0.8, 1.0, 1, -1.0)]))
WR_HIPS = (0.0, 1.35)
floor_key(wr, 1.25, "in", 14, 0, 2, (0.0, 1.2), crouch_legs(46, 0.5),
          dict(neck=(-16, 0, 4), rShoulder=CLUTCH, lShoulder=J((30, 0, -30))))
sit_key(wr, 1.42, "in", lean=24, neck=(-14, 0, 4), hips=WR_HIPS, rShoulder=CLUTCH, lShoulder=J((20, 0, -26)))
hit = topple_back(wr, 1.42, 24.0, WR_HIPS, spin0=1.5, length=3.0,
                  arms=lambda u: dict(rShoulder=mix(CLUTCH, BACK_R, u), lShoulder=mix(J((20, 0, -26)), BACK_L, u)),
                  head0=-14.0)
# the hand reaching up at them, shaking
REACH_UP = J((150, 0, 18))
supine_key(wr, hit + 0.6, "sine", neck=(4, 0, 0), hips=WR_HIPS, rShoulder=BACK_R, lShoulder=BACK_L)
supine_key(wr, 2.9, "sine", neck=(-8, 0, 0), hips=WR_HIPS, rShoulder=REACH_UP, lShoulder=BACK_L)
shiver(wr, 2.3, 3.15, {"rShoulder": (3.0, 0, 2.0)}, amount=1.0, hz=9)
# the swarm tears out of the chest: arched off the floor, the arms flung out; then limp
supine_key(wr, 3.2, "snap", lean=76, neck=(-20, 0, 0), hips=WR_HIPS, rShoulder=J((60, 0, 80)), lShoulder=J((60, 0, -80)))
supine_key(wr, 3.55, "in", neck=(20, 0, 0), hips=WR_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
supine_key(wr, 4.8, "smooth", neck=(14, 10, 4), hips=WR_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
soft(wr, head=3.4, arms=3.0, arm_damp=0.5)
wr.build()
record(wr, hit, fx=0.25)

# =====================================================================================================================
# heh, didja really think-

# As the fight's end goes (the reference): asleep on their feet; woken by the swing, a lazy sidestep and the first slash
# cuts the air where they stood; a smug shrug while the line starts ("heh, didja really think-", Presentation/DeathVfx
# types it) and the second slash cuts it off; a look down at the wound, a shrug, a few steps aside, down (to dust).
sn = Motion("deathSans", 6.4, note="Dozing on their feet; awake, a lazy sidestep past the first slash; a smug shrug "
            "cut off by the second; a hand on the wound, a shrug, a few steps aside, down.", floor=True)
sn.key(0.0, **REST)
for t, nod in ((0.3, -22), (0.62, -10), (0.95, -26), (1.15, -14)):
    body_key(sn, t, "sine", -4, 0, 2, drop=0.06, neck=(nod, 0, 4), rShoulder=HANG_R, lShoulder=HANG_L)
strike(sn, 1.26, body(-4, drop=0.06, neck=J((-14, 0, 4))), body(2, drop=0.0, neck=J((8, 0, 0))), antic=0.04,
       travel=0.05, over=0.2, settle=0.08)
DODGE = (-0.9, 0.0)
body_key(sn, 1.48, "out", -2, 12, -6, hips=DODGE, drop=0.02, neck=(6, -14, 0), rShoulder=HANG_R, lShoulder=HANG_L)
SHRUG_R, SHRUG_L = J((24, 0, 30), (0, 0.12, 0)), J((24, 0, -30), (0, 0.12, 0))
body_key(sn, 1.9, "sine", 2, 6, 3, hips=DODGE, drop=0.04, neck=(4, -8, 8), rShoulder=SHRUG_R, lShoulder=SHRUG_L)
body_key(sn, 2.42, "sine", 2, 6, 3, hips=DODGE, drop=0.04, neck=(6, -6, 10), rShoulder=SHRUG_R, lShoulder=SHRUG_L)
SLASH = 2.56
WOUND = reach(1, (0.05, 0.25, -0.72), direction=(-0.55, 0.15, -0.82))
CUT = (DODGE[0], 0.06)
strike(sn, SLASH, body(2, 6, 3, hips=DODGE, drop=0.04, rShoulder=SHRUG_R, lShoulder=SHRUG_L),
       body(-16, 8, 0, hips=CUT, drop=0.12, neck=J((-14, 0, 0)), rShoulder=WOUND, lShoulder=HANG_L), antic=0.03,
       travel=0.04, over=0.25, settle=0.18)
body_key(sn, 3.1, "sine", -10, 8, 0, hips=CUT, drop=0.1, neck=(-26, 0, 0), rShoulder=WOUND, lShoulder=HANG_L)
body_key(sn, 3.4, "out", -6, 8, 0, hips=CUT, drop=0.02, neck=(8, -6, 8), rShoulder=WOUND,
         lShoulder=J((20, 0, -26), (0, 0.12, 0)))
body_key(sn, 3.62, "sine", -8, 8, 0, hips=CUT, drop=0.08, neck=(2, -6, 4), rShoulder=WOUND, lShoulder=HANG_L)
# a few steps aside, to its left, holding the wound
SN_HIPS = (-2.6, 0.12)
body_key(sn, 4.7, "sine", -12, 40, 0, hips=SN_HIPS, drop=0.12, neck=(-6, -30, 0), rShoulder=WOUND, lShoulder=HANG_L)
stand(sn, 0.0, 4.8, Feet(steps=[(1.3, 1.46, -1, (-1.5, 0.0)), (1.4, 1.56, 1, (-0.4, 0.0)),
                                 (3.7, 3.98, -1, (-2.1, 0.05, 30)), (4.0, 4.28, 1, (-1.6, 0.1, 40)),
                                 (4.3, 4.6, -1, (-3.1, 0.15, 40))]))
knees_go(sn, 4.8, 5.1, -30, SN_HIPS, turn=40, neck=(-14, 0, 0), rShoulder=WOUND, lShoulder=J((30, 0, -14)))
kneel_key(sn, 5.1, "in", lean=-30, turn=40, head=-20, hips=SN_HIPS, rShoulder=WOUND, lShoulder=J((30, 0, -10)))
hit = topple_forward(sn, 5.1, 30.0, SN_HIPS, spin0=1.3, arm="l", hold_r=WOUND, head0=-20.0, turn=40)
soft(sn, head=3.0, arms=2.6)
sn.build()
record(sn, hit, fx=SLASH)

# =====================================================================================================================
# A true patriot.

pt = Motion("deathPatriot", 3.8, note="One shot, a hand to the chest, a slow step back looking up at who fired, sat "
            "down and laid back in the flowers.", floor=True)
pt.key(0.0, **REST)
SHOT = 0.32
strike(pt, SHOT, body(0, neck=J((2, 0, 0))), body(8, hips=(0, 0.12), drop=0.04, neck=J((-10, 0, 0)), rShoulder=CLUTCH),
       antic=0.03, travel=0.04, over=0.25, settle=0.2)
body_key(pt, 1.0, "sine", 4, 0, 0, hips=(0, 0.3), drop=0.08, neck=(-18, 0, 0), rShoulder=CLUTCH, lShoulder=OVER_L)
body_key(pt, 1.55, "sine", 6, 0, 2, hips=(0, 0.4), drop=0.14, neck=(10, 0, 0), rShoulder=CLUTCH,
         lShoulder=mix(OVER_L, HANG_L, 0.6))
stand(pt, 0.0, 1.6, Feet(steps=[(0.62, 0.95, 1, -0.45)]))
PT_HIPS = (0.0, 0.75)
floor_key(pt, 1.9, "sine", 12, 0, 2, (0.0, 0.6), crouch_legs(44, 0.48),
          dict(neck=(4, 0, 0), rShoulder=CLUTCH, lShoulder=J((10, 0, -24))))
sit_key(pt, 2.15, "sine", lean=22, neck=(2, 0, 0), hips=PT_HIPS, rShoulder=CLUTCH, lShoulder=J((-10, 0, -26)))
hit = topple_back(pt, 2.2, 22.0, PT_HIPS, spin0=0.5, length=3.6,
                  arms=lambda u: dict(rShoulder=mix(CLUTCH, J((40, 0, 30)), u), lShoulder=mix(J((-10, 0, -26)), BACK_L, u)),
                  head0=2.0)
supine_key(pt, 3.8, "sine", neck=(16, 0, -6), hips=PT_HIPS, rShoulder=J((40, 0, 30)), lShoulder=BACK_L)
soft(pt, head=2.6, arms=2.2)
pt.build()
record(pt, hit, fx=SHOT)

# The grave, after (the reference's 1:50-2:15): who salutes stands at the headstone looking down at the name; the head
# comes up, and the hand rises slowly to the brow and holds there to the end, the head dipping once. Played by the
# saluter's copy in the grave cutscene (Shared/Cinema/DeathCuts "patriot_grave"), not a death: no timing.
gs = Motion("graveSalute", 9.6, note="At the grave: looking down at the name, the head up, a slow salute held.")
BROW = reach(1, (0.8, 1.7, -0.45), direction=(-0.55, 0.65, -0.5))
body_key(gs, 0.0, "smooth", -3, neck=(-26, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(gs, 2.0, "sine", -3, neck=(-24, 2, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(gs, 2.7, "sine", 0, neck=(-4, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(gs, 3.0, "smooth", 0, neck=(-3, 0, 0), rShoulder=J((6, 0, 10)), lShoulder=HANG_L)
body_key(gs, 4.2, "out", 1, neck=(-2, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
body_key(gs, 6.2, "sine", 1, neck=(-2, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
body_key(gs, 6.9, "sine", 0, neck=(-9, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
body_key(gs, 8.0, "sine", 1, neck=(-3, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
body_key(gs, 9.6, "smooth", 1, neck=(-3, 0, 0), rShoulder=BROW, lShoulder=HANG_L)
stand(gs, 0.0, 9.6, Feet(stance=0.12))
alive(gs, amount=0.45, seed=3)
soft(gs, head=2.0, arms=2.0)
gs.build()
