"""Every death the game plays (the user's ask of 2026-11-07: "very high quality", all of them redone; the custom deaths'
first actings of 2026-10-27 and the three plain collapses are replaced): the three everyday causes (Heart attack,
Disease, Accident: collapse*), the eleven causes bought in the shop (Shared/Cosmetics kind "reason": death*, matched to
their effects in Presentation/CustomDeaths) and what a fallen body does under its death style (fallen.py). anims.py
imports this file near its end, so its helpers are ready.

Every death ends lying still on the floor (face down or on the back, near enough the poses deathkit names): the server
then locks the last pose into the joints. Shared/Anim/DeathTiming (written from TIMING below) tells the game when each
body first hits the floor (`hit`: the burst and chalk line, the custom effect's impact), when its effect starts (`fx`)
and when it lies still.

How each was worked out is in art/refs/deaths/<clip>.toml. The falls are timed by gravity (deathkit.rod_fall: a body
tipping about its knees, hips or toes); the feet hold where they stand and step for real (deathkit.Feet + stand); the
body is placed by its hips (deathkit.body_key: a knee, a hip or a toe stays where it is while the body tips over it);
hands go to their marks with emotes.kit.reach."""

import math
import os

import numpy as np

import posekit
from animlib import J
from deathkit import (AHEAD_L, AHEAD_R, BACK_L, BACK_R, OUT_L, OUT_R, REST, SIDE_L, SIDE_R, Feet, body, body_key,
                      breaths, clamp01, floor_key, hips_of, kneel_key, lead_arm, mix, prone_key, rod_fall, shiver,
                      sit_key, stand, supine_key)
from cinema.acting import soft, strike
from emotes.kit import BELLY, CHEST, reach
from motion import Motion

# When each death's body first hits the floor, when its effect starts (custom deaths), and when it lies still.
TIMING = {}

THROAT = (0.0, 0.92, -0.64)
CLUTCH = reach(1, CHEST, direction=(-0.55, 0.15, -0.8))  # the right hand clawed into the chest
OVER_L = reach(-1, (0.1, 0.25, -0.85), direction=(0.6, 0.2, -0.75))  # the left over it, both at the heart
THROAT_R = reach(1, (0.14, THROAT[1], -0.7), direction=(-0.5, 0.35, -0.78))
THROAT_L = reach(-1, (-0.14, THROAT[1] - 0.06, -0.72), direction=(0.5, 0.35, -0.78))
MOUTH_R = reach(1, (0.06, 1.24, -0.74), direction=(-0.35, 0.6, -0.72))
BELLY_R = reach(1, (0.12, BELLY[1], -0.78), direction=(-0.5, -0.15, -0.85))
BELLY_L = reach(-1, (-0.12, BELLY[1] + 0.08, -0.8), direction=(0.5, -0.15, -0.85))
HANG_R, HANG_L = J((2, 0, 4), (0, 0.02, 0)), J((2, 0, -4), (0, 0.02, 0))
BENT = 0.42  # a knee bent: the leg slid this far up into the hip


def body_on(joints, part, local, target):
    """The body offset that puts a point of a part (in the part's own frame) on `target` (character frame) for this
    pose (a body tipping over its toes keeps them where they were)."""
    world = posekit.fk(joints)
    p = (world[part] @ np.array([*local, 1.0]))[:3]
    return tuple(float(v) for v in np.array(target, float) - p)


def crouch_legs(fwd=40.0, bend=BENT, spread=4.0):
    """Legs swung `fwd` degrees forward of the torso with the knees bent (slid up into the hips)."""
    return dict(rHip=J((fwd, 0, spread), (0, bend, 0)), lHip=J((fwd - 4, 0, -spread), (0, bend, 0)))


def topple_forward(m, t0, lean0, hips, spin0=1.4, arm="l", hold_r=CLUTCH, hold_l=None, head0=-24.0, turn=0.0,
                   length=3.6, other=None, give=0.12, rest_neck=(12, 0, 14)):
    """From on the knees at `hips`, leaning `lean0` degrees forward, over onto the face under gravity (about the
    knees): the `arm` side leads the body down (out ahead along the floor when it lands), the other arm goes from
    `hold_*` to along its side; the head lifts as it lands, whips at the hit and drops. Returns the hit time."""
    keys, hit = rod_fall(t0, lean0, spin0=spin0, length=length, give=give)
    held = hold_r if arm == "l" else hold_l
    other = other if other is not None else (SIDE_R if arm == "l" else SIDE_L)
    sign = -1 if arm == "l" else 1
    for t, lean in keys[1:]:
        u = clamp01((lean - lean0) / (88.0 - lean0))
        ahead = lead_arm(lean)
        lead = J((max(90.0, ahead), 0, sign * (4 + 6 * min(1.0, ahead / 176.0))))
        trail = mix(held, other, min(1.0, u * 1.8)) if held is not None else other
        upper = dict(lShoulder=lead, rShoulder=trail) if arm == "l" else dict(rShoulder=lead, lShoulder=trail)
        head = head0 + (12 - head0) * u if t < hit else 18
        kneel_key(m, t, "linear", lean=-lean, turn=turn, neck=(head, 0, 6 * u), hips=hips, **upper)
    lead_flat, flat = J((184, 0, sign * 8)), J((180, 0, sign * 8))
    upper = dict(lShoulder=lead_flat, rShoulder=other) if arm == "l" else dict(rShoulder=lead_flat, lShoulder=other)
    prone_key(m, hit + 0.12, "in", turn=turn, neck=(26, 0, 8), hips=hips, **upper)  # the arm lands; the head whips
    upper = dict(lShoulder=flat, rShoulder=other) if arm == "l" else dict(rShoulder=flat, lShoulder=other)
    prone_key(m, hit + 0.36, "sine", turn=turn, neck=rest_neck, hips=hips, **upper)  # ...and drops
    return hit


def topple_back(m, t0, lean0, hips, spin0=1.0, length=3.0, turn=0.0, arms=None, head0=-6.0, give=0.1):
    """From sat on the floor at `hips`, leaning `lean0` back, over onto the back under gravity (about the hips);
    `arms(u)` gives the arms (u 0..1 of the way down). Returns the hit time."""
    keys, hit = rod_fall(t0, lean0, spin0=spin0, length=length, give=give)
    for t, lean in keys[1:]:
        u = clamp01((lean - lean0) / (88.0 - lean0))
        upper = arms(u) if arms else dict(rShoulder=mix(HANG_R, BACK_R, u), lShoulder=mix(HANG_L, BACK_L, u))
        head = head0 * (1 - u) - 14 * u if t < hit else 26  # (on the back +x presses the head to the floor)
        sit_key(m, t, "linear", lean=lean, turn=turn, neck=(head, 0, 0), hips=hips, **upper)
    return hit


def record(clip, hit, fx=None, still=None):
    TIMING[clip.name] = {"hit": round(hit, 3), "fx": None if fx is None else round(fx, 3),
                         "still": round(still if still is not None else clip.length, 3), "length": clip.length}


# =====================================================================================================================
# Heart attack: Death Note's death. A sudden seizure in the chest: the hand claws at it, the breath catches, a stagger
# forward onto a step that holds a moment, the knees go (the stage faint's drop) and over onto the face.

heart = Motion("collapseHeart", 2.7, note="The heart seizes: a hand clawing at the chest, a stagger, the knees go, "
               "down on the face.", floor=True)
heart.key(0.0, **REST)
# the jolt: a catch of breath up, then the chest caves round the clawing hand
strike(heart, 0.14, body(3, drop=-0.03, neck=J((8, 0, 0)), rShoulder=J((16, 0, 8))),
       body(-17, roll=3, hips=(0, 0.06), drop=0.08, neck=J((-4, 0, 2)), rShoulder=CLUTCH, lShoulder=J((26, 0, -16))),
       antic=0.08, travel=0.05, over=0.2, settle=0.18)
# agony where he stands: the head comes up gasping, the left hand comes over the right, the weight rocks back
body_key(heart, 0.32, "out", -13, roll=4, hips=(0, 0.1), drop=0.1, neck=(8, -6, 4), rShoulder=CLUTCH,
         lShoulder=J((40, 0, -10), (0.1, 0.04, -0.1)))
body_key(heart, 0.5, "smooth", -15, 4, 5, hips=(0, 0.08), drop=0.11, neck=(10, -8, 4), rShoulder=CLUTCH,
         lShoulder=OVER_L)
# he pitches forward and a step catches him (the right foot), the hips coming over it
body_key(heart, 0.72, "in", -24, 6, 4, hips=(0.05, -0.12), drop=0.16, neck=(-2, -4, 2), rShoulder=CLUTCH,
         lShoulder=OVER_L)
HEART_HIPS = (0.08, -0.26)
body_key(heart, 0.9, "out", -28, 6, 3, hips=HEART_HIPS, drop=0.26, neck=(-8, -2, 2), rShoulder=CLUTCH,
         lShoulder=mix(OVER_L, HANG_L, 0.3))
stand(heart, 0.0, 1.0, Feet(steps=[(0.56, 0.8, 1, 0.5)]))
# the knees go: the body drops onto them, folding over the clutched chest, the legs swinging back under it
floor_key(heart, 1.12, "in", -40, 4, 3, HEART_HIPS, dict(rHip=J((40, 0, 2)), lHip=J((40, 0, -2))),
          dict(neck=(-14, 0, 2), rShoulder=CLUTCH, lShoulder=mix(OVER_L, HANG_L, 0.6)))
floor_key(heart, 1.28, "in", -44, 3, 3, HEART_HIPS,
          dict(rHip=J((6, 0, 2), (0, 0.06, 0.12)), lHip=J((6, 0, -2), (0, 0.06, 0.12))),
          dict(neck=(-20, 0, 3), rShoulder=CLUTCH, lShoulder=J((40, 0, -8))))
kneel_key(heart, 1.4, "in", lean=-46, turn=3, head=-22, hips=HEART_HIPS, rShoulder=CLUTCH, lShoulder=J((70, 0, -6)))
# over onto the face, the left arm out ahead to lead it down; the clutching hand slips out to the side
hit = topple_forward(heart, 1.4, 46.0, HEART_HIPS, spin0=1.5, arm="l", hold_r=CLUTCH, head0=-22.0, turn=3,
                     rest_neck=(12, 0, 16))
breaths(heart, hit + 0.45, 2.55, every=0.7, depth=2.2)
soft(heart, head=3.2, arms=3.0, arm_damp=0.55)
heart.build()
record(heart, hit)

# =====================================================================================================================
# Disease: a racking cough into the fist, worse each time, the knees softening; a dizzy reach for something to hold;
# the legs fold and they sit down hard, a hand back to the floor; the arm gives and they go over onto the back.

ill = Motion("collapseDisease", 3.4, note="Racking coughs into the fist, a dizzy reach, sat down hard, over onto the "
             "back.", floor=True)
ill.key(0.0, **REST)
COUGH_R = reach(1, (0.3, 1.08, -0.8), direction=(-0.12, 0.88, -0.46))  # the fist at the side of the mouth, elbow down
for k, (t, bend, drop) in enumerate([(0.14, 18, 0.04), (0.42, 22, 0.07), (0.7, 29, 0.13), (0.97, 24, 0.18)]):
    # each cough: a small breath in (up), the hack (folded, in two frames), a recoil
    body_key(ill, t - 0.08, "sine", -bend * 0.25, hips=(0, 0.02), drop=drop - 0.04, neck=(4, 0, 0),
             rShoulder=COUGH_R, lShoulder=BELLY_L)
    body_key(ill, t, "snap", -bend, 2 * (k % 2 * 2 - 1), 2, hips=(0, 0.06), drop=drop + 0.04, neck=(-12, 0, 0),
             rShoulder=COUGH_R, lShoulder=BELLY_L)
    body_key(ill, t + 0.14, "out", -bend * 0.55, 0, 1, hips=(0, 0.04), drop=drop, neck=(-4, 0, 0),
             rShoulder=COUGH_R, lShoulder=BELLY_L)
# dizzy: up, the head rolling, the right hand out to the side for something to hold; the weight goes right
body_key(ill, 1.32, "sine", -6, -6, -7, hips=(0.14, 0.04), drop=0.16, neck=(4, 6, -12), rShoulder=J((52, 0, 58)),
         lShoulder=mix(BELLY_L, HANG_L, 0.5))
body_key(ill, 1.52, "smooth", -4, -8, -10, hips=(0.3, 0.06), drop=0.22, neck=(0, 4, -16), rShoulder=J((60, 0, 66)),
         lShoulder=HANG_L)
stand(ill, 0.0, 1.6, Feet(steps=[(1.22, 1.46, 1, (0.92, 0.05))]))
# the legs fold and they sit down hard, the right hand reaching back and down for the floor
ILL_HIPS = (0.3, 0.4)
floor_key(ill, 1.82, "in", -14, -8, -8, (0.3, 0.22), crouch_legs(56, 0.45),
          dict(neck=(-8, 0, -10), rShoulder=J((-10, 0, 40), (0, 0.05, 0)), lShoulder=J((30, 0, -14))))
PROP_R = J((-38, 0, 30), (0, 0.06, 0))  # the right arm back and down, propping them up
sit_key(ill, 2.06, "in", lean=12, turn=-8, roll=-4, neck=(-12, 0, -8), hips=ILL_HIPS, rShoulder=PROP_R,
        lShoulder=J((26, 0, -10)))
sit_key(ill, 2.2, "out", lean=8, turn=-8, roll=-3, neck=(-6, 0, -6), hips=ILL_HIPS, rShoulder=PROP_R,
        lShoulder=J((22, 0, -10)))
sit_key(ill, 2.42, "sine", lean=14, turn=-8, roll=-4, neck=(-16, 0, -10), hips=ILL_HIPS, rShoulder=PROP_R,
        lShoulder=BELLY_L)
# the propping arm gives and they go over onto the back
hit = topple_back(ill, 2.42, 14.0, ILL_HIPS, spin0=0.9, turn=-8,
                  arms=lambda u: dict(rShoulder=mix(PROP_R, BACK_R, u), lShoulder=mix(BELLY_L, J((40, 0, -16)), u)),
                  head0=-16.0)
supine_key(ill, hit + 0.14, "out", turn=-8, neck=(30, 0, -6), hips=ILL_HIPS, rShoulder=BACK_R,
           lShoulder=J((40, 0, -14)))
supine_key(ill, hit + 0.4, "sine", turn=-8, neck=(16, 4, -12), hips=ILL_HIPS, rShoulder=BACK_R,
           lShoulder=J((34, 0, -16)))
# the hand on the stomach slides off to the floor; the head rolls aside
supine_key(ill, 3.25, "sine", turn=-8, neck=(14, 24, -14), hips=ILL_HIPS, rShoulder=BACK_R, lShoulder=BACK_L)
breaths(ill, hit + 0.4, 3.1, every=0.9, depth=1.6)
soft(ill, head=2.8, arms=2.4)
ill.build()
record(ill, hit)

# =====================================================================================================================
# Accident: turning to go, a step onto something slick: the foot shoots out ahead, the arms fly up, a moment in the air
# and down flat on the back, the head hitting the floor; the legs drop after; the head lolls aside.

acc = Motion("collapseAccident", 2.3, note="A step, the foot shoots out ahead, the arms fly up, slammed flat on the "
             "back, the head hits.", floor=True)
acc.key(0.0, **REST)
body_key(acc, 0.12, "sine", -4, hips=(0, -0.12), drop=0.05, neck=(-4, 0, 0), rShoulder=J((-12, 0, 6)),
         lShoulder=J((14, 0, -6)))
body_key(acc, 0.26, "smooth", -2, hips=(0, -0.34), drop=0.08, neck=(-6, 0, 0), rShoulder=J((-8, 0, 6)),
         lShoulder=J((10, 0, -6)))
stand(acc, 0.0, 0.27, Feet(steps=[(0.06, 0.27, 1, 0.62)]), ramp=0.0)
# the slip: the right foot shoots out ahead and up, the left leaves the floor, the body goes back, arms flung up
body_key(acc, 0.38, "out", 24, 0, 4, hips=(0, -0.24), drop=0.14, neck=(-22, 0, 0), rShoulder=J((112, 0, 52)),
         lShoulder=J((124, 0, -44)), rHip=J((58, 0, 4)), lHip=J((14, 0, -4)))
body_key(acc, 0.48, "smooth", 44, 0, 6, hips=(0, -0.1), drop=0.55, neck=(-24, 0, 0), rShoulder=J((132, 0, 60)),
         lShoulder=J((138, 0, -54)), rHip=J((74, 0, 4)), lHip=J((40, 0, -6)))
# in the air, going down (a drop of about two studs takes a third of a second)
body_key(acc, 0.62, "in", 70, 0, 6, hips=(0, 0.0), drop=1.42, neck=(-18, 0, 0), rShoulder=J((120, 0, 70)),
         lShoulder=J((122, 0, -66)), rHip=J((66, 0, 4)), lHip=J((50, 0, -6)))
HIT_ACC = 0.7
ACC_HIPS = (0.0, 0.05)
# slammed flat on the back: the head hits and bounces; the arms slap down out to the sides; the legs still up
floor_key(acc, HIT_ACC, "in", 88, 0, 4, ACC_HIPS, dict(rHip=J((48, 0, 4)), lHip=J((36, 0, -6))),
          dict(neck=(30, 0, 0), rShoulder=J((60, 0, 74)), lShoulder=J((64, 0, -70))))
floor_key(acc, 0.8, "out", 84, 0, 4, ACC_HIPS, dict(rHip=J((40, 0, 4)), lHip=J((24, 0, -6))),
          dict(neck=(4, 0, 2), rShoulder=J((8, 0, 78)), lShoulder=J((10, 0, -74))))
# the legs drop to the floor; the chest settles
LYING = dict(rHip=J((-2, 0, 6)), lHip=J((-4, 0, -6)))
floor_key(acc, 0.98, "in", 88, 0, 4, ACC_HIPS, LYING, dict(neck=(14, 0, 2), rShoulder=OUT_R, lShoulder=OUT_L))
floor_key(acc, 1.08, "out", 86, 0, 4, ACC_HIPS, dict(rHip=J((10, 0, 6), (0, 0.18, 0)), lHip=J((-4, 0, -6))),
          dict(neck=(12, 0, 2), rShoulder=OUT_R, lShoulder=OUT_L))
# a knee comes up once (a reflex) and goes down; the head lolls aside
floor_key(acc, 1.4, "sine", 88, 0, 4, ACC_HIPS, dict(rHip=J((24, 0, 6), (0, 0.42, 0)), lHip=J((-4, 0, -6))),
          dict(neck=(14, 10, 4), rShoulder=OUT_R, lShoulder=OUT_L))
floor_key(acc, 1.95, "sine", 88, 0, 4, ACC_HIPS, LYING, dict(neck=(14, 34, 6), rShoulder=OUT_R, lShoulder=OUT_L))
floor_key(acc, 2.3, "smooth", 88, 0, 4, ACC_HIPS, LYING, dict(neck=(14, 36, 6), rShoulder=OUT_R, lShoulder=OUT_L))
soft(acc, head=4.0, arms=3.4, arm_damp=0.5)
acc.build()
record(acc, HIT_ACC)

# The rift dive's crash keeps the old knocked-sideways fall (DiveController), under its own name.
crash = Motion("diveCrash", 1.9, note="The rift dive's crash: knocked off balance, the knees go, down.", floor=True)
crash.key(0.0, **REST)
crash.key(0.1, "snap", offset=(0.3, -0.05, 0.05), root=(-6, 16, 24), neck=(-4, 0, -18),
          rShoulder=J((30, 0, 40), (0, 0.1, 0)), lShoulder=J((22, 0, -20)))
crash.key(0.45, "in", offset=(0.75, -0.8, 0.2), root=(8, 24, 50), neck=(4, 0, -20),
          rShoulder=J((50, 0, 56), (0, 0.1, 0)), lShoulder=J((30, 0, -30)), rHip=J((-8, 0, 14), (0, 0.3, 0)),
          lHip=J((24, 0, -6), (0, 0.5, 0)))
crash.key(0.95, "in", offset=(1.3, 0, 0.3), floor=True, root=(40, 20, 62), neck=(8, 0, -12),
          rShoulder=J((20, 0, 60)), lShoulder=J((16, 0, -34)), rHip=J((-4, 0, 14), (0, 0.2, 0)),
          lHip=J((16, 0, -8), (0, 0.3, 0)))
crash.key(1.4, "in", offset=(1.4, 0, 0.4), floor=True, root=(86, 10, 8), neck=(12, 0, -10),
          rShoulder=J((6, 0, 48)), lShoulder=J((12, 0, -30)), rHip=J((-2, 0, 10)), lHip=J((6, 0, -8)))
crash.key(1.9, "out", offset=(1.4, 0, 0.4), floor=True, root=(87, 10, 8), neck=(13, 0, -10),
          rShoulder=J((6, 0, 49)), lShoulder=J((12, 0, -31)), rHip=J((-2, 0, 10)), lHip=J((6, 0, -8)))
soft(crash, arms=2.6)
crash.build()

# =====================================================================================================================
# A long fall ("They trip on nothing"): a step, the trailing toe catches on nothing, and they go down like a felled tree
# from their own height, arms flung out ahead; the floor comes up hard (the effect's slam, 0.25 s after it starts).

fall = Motion("deathFall", 2.7, note="A step, the toe catches on nothing, down from full height like a felled tree, "
              "slammed flat.", floor=True)
fall.key(0.0, **REST)
body_key(fall, 0.2, "sine", -6, hips=(-0.02, -0.24), drop=0.06, neck=(-4, 0, 0), rShoulder=J((16, 0, 6)),
         lShoulder=J((-14, 0, -6)))
body_key(fall, 0.36, "smooth", -8, hips=(-0.05, -0.44), drop=0.04, neck=(-2, 0, 0), rShoulder=J((10, 0, 6)),
         lShoulder=J((-10, 0, -6)))
stand(fall, 0.0, 0.42, Feet(steps=[(0.06, 0.3, -1, 0.6)]), ramp=0.0)
# the right toe catches as it swings through: the body goes on without it, the arms flung out ahead, the head up
TRIP = 0.42
# down like a tree from its own height, pivoting on the left foot (a rod five studs long)
keys, HIT_FALL = rod_fall(TRIP, 14.0, spin0=1.1, length=5.0, give=0.14)
PIVOT = (-0.55, 0.0, -1.1)  # the left sole's front edge, where it stands
last = None
for t, lean in keys:
    u = clamp01((lean - 14.0) / 74.0)
    arms_out = 60 + 120 * u ** 0.8
    joints = dict(root=(-lean, 0, 2 - 2 * u), neck=(14 + 20 * u if t < HIT_FALL else 30, 0, 4 * u),
                  rShoulder=J((arms_out, 0, 26 - 10 * u)), lShoulder=J((arms_out + 6 * (1 - u), 0, -24 + 10 * u)),
                  rHip=J((-24 - 12 * math.sin(math.pi * u), 0, 4)), lHip=J((6 * (1 - u), 0, -2)))
    off = body_on(joints, "Left Leg", (0, -1, -0.5), PIVOT)
    fall.key(t, "snap" if t == TRIP else "linear", offset=off, **joints)
    last = (joints, off)
    if t > HIT_FALL + 0.15:
        break
FALL_HIPS = hips_of(*last)
prone_key(fall, HIT_FALL + 0.2, "out", neck=(28, 0, 6), rShoulder=J((176, 0, 18)), lShoulder=J((178, 0, -18)),
          hips=FALL_HIPS, legs=dict(rHip=J((-8, 0, 6)), lHip=J((-2, 0, -4))))
prone_key(fall, HIT_FALL + 0.4, "in", neck=(10, 0, 12), rShoulder=AHEAD_R, lShoulder=AHEAD_L, hips=FALL_HIPS)
# a hand closes on the floor and opens; the head turns aside; still
prone_key(fall, 1.95, "sine", neck=(12, 0, 18), rShoulder=J((172, 0, 14), (0, 0.1, 0)), lShoulder=AHEAD_L,
          hips=FALL_HIPS)
prone_key(fall, 2.7, "sine", neck=(12, 0, 20), rShoulder=AHEAD_R, lShoulder=AHEAD_L, hips=FALL_HIPS)
soft(fall, head=3.5, arms=3.0, arm_damp=0.5)
fall.build()
record(fall, HIT_FALL, fx=HIT_FALL - 0.25)

# =====================================================================================================================
# A broken heart: a hand rises to the heart and the other over it; it beats once (a jolt) and again (an arch, the
# head thrown back: the effect's two beats, 0 and 0.32 s in); it cracks (0.7 s in) and they go slack, swooning back
# onto the floor, the right hand reaching out to someone a moment.

bh = Motion("deathHeart", 3.3, note="Hands to the heart, two beats arching them back, it cracks: a swoon back onto "
            "the floor.", floor=True)
BEAT1, BEAT2 = 0.9, 1.22
CRACK = BEAT1 + 0.7
bh.key(0.0, **REST)
bh.key(0.22, root=(0, 0, 0), neck=(-2, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
body_key(bh, 0.6, "sine", -6, drop=0.03, neck=(-14, 0, 0), rShoulder=CLUTCH, lShoulder=HANG_L)
body_key(bh, 0.84, "sine", -8, drop=0.05, neck=(-12, 0, 0), rShoulder=CLUTCH, lShoulder=OVER_L)
strike(bh, BEAT1, body(-9, drop=0.05), body(6, hips=(0, 0.06), drop=0.02, neck=J((4, 0, 0))),
       antic=0.06, travel=0.05, over=0.25, settle=0.12)
body_key(bh, BEAT2 - 0.1, "sine", -3, hips=(0, 0.04), drop=0.04, neck=(-4, 0, 0), rShoulder=CLUTCH, lShoulder=OVER_L)
strike(bh, BEAT2, body(-5, hips=(0, 0.04), drop=0.04, neck=J((-6, 0, 0))),
       body(16, hips=(0, 0.1), drop=-0.05, neck=J((24, 0, 0))), antic=0.05, travel=0.06, over=0.18, settle=0.14)
body_key(bh, 1.5, "smooth", 17, 0, 1, hips=(0, 0.1), drop=-0.04, neck=(26, 0, 2), rShoulder=CLUTCH, lShoulder=OVER_L)
shiver(bh, BEAT2 + 0.12, CRACK, {"root": (0.6, 0.3, 0.4), "neck": (0.8, 0.6, 0.0)}, amount=1.0, hz=11)
# the crack: slack; the hands fall from the heart, the right one out to someone; the knees soften
REACH_OUT = J((78, 0, 14), (0, 0.04, 0))
body_key(bh, CRACK + 0.08, "snap", 10, 0, 2, hips=(0, 0.1), drop=0.1, neck=(10, 0, 4), rShoulder=J((62, 0, 10)),
         lShoulder=mix(OVER_L, HANG_L, 0.6))
stand(bh, 0.0, 1.8, Feet())
BH_HIPS = (0.0, 0.34)
floor_key(bh, 1.95, "in", 14, 0, 4, (0.0, 0.2), crouch_legs(40, 0.44),
          dict(neck=(0, 0, 8), rShoulder=REACH_OUT, lShoulder=J((10, 0, -10))))
sit_key(bh, 2.16, "in", lean=18, neck=(-4, 0, 8), hips=BH_HIPS, rShoulder=J((70, 0, 18)), lShoulder=J((4, 0, -14)))
hit = topple_back(bh, 2.16, 18.0, BH_HIPS, spin0=1.0, length=3.0,
                  arms=lambda u: dict(rShoulder=mix(J((70, 0, 18)), J((40, 0, 52)), u),
                                      lShoulder=mix(J((4, 0, -14)), BACK_L, u)), head0=-4.0)
supine_key(bh, hit + 0.14, "out", neck=(28, 0, 4), hips=BH_HIPS, rShoulder=J((46, 0, 60)), lShoulder=BACK_L)
# the reaching hand falls last, out on the floor; the head rolls toward it
supine_key(bh, hit + 0.42, "in", neck=(16, -8, 4), hips=BH_HIPS, rShoulder=J((4, 0, 62)), lShoulder=BACK_L)
supine_key(bh, 3.3, "sine", neck=(14, -22, 6), hips=BH_HIPS, rShoulder=J((2, 0, 64)), lShoulder=BACK_L)
soft(bh, head=2.8, arms=2.2, arm_damp=0.6)
bh.build()
record(bh, hit, fx=BEAT1)

# =====================================================================================================================
# Frozen where they stood: a chill hunches them, arms hugging themselves, shivering hard; the shiver slows as the frost
# climbs and stops; frozen solid a moment; then the statue tips over stiff about its toes and lands whole on its folded
# arms, the ice breaking off as it hits.

fr = Motion("deathFrost", 2.9, note="Hugging themselves, shivering, frozen solid, then tipping over stiff as a statue.",
            floor=True)
HUG_R = reach(1, (-0.95, 0.52, -0.64), direction=(-0.92, 0.05, -0.38))
HUG_L = reach(-1, (0.95, 0.36, -0.74), direction=(0.92, 0.05, -0.38))
fr.key(0.0, **REST)
strike(fr, 0.2, body(2, neck=J((4, 0, 0))),
       body(-8, hips=(0, 0.04), drop=0.08, neck=J((-12, 0, 0)), rShoulder=HUG_R, lShoulder=HUG_L),
       antic=0.07, travel=0.08, over=0.15, settle=0.2)
FROZEN = dict(neck=(-10, 0, 2), rShoulder=HUG_R, lShoulder=HUG_L)
body_key(fr, 0.9, "smooth", -9, 0, 1, hips=(0, 0.04), drop=0.1, **FROZEN)
body_key(fr, 1.5, "smooth", -9, 0, 1, hips=(0, 0.04), drop=0.1, **FROZEN)
shiver(fr, 0.24, 1.5, {"root": (1.2, 1.8, 1.4), "neck": (1.6, 2.4, 0.8), "rShoulder": (1.8, 0, 1.6),
                       "lShoulder": (1.8, 0, 1.6)}, amount=1.0, hz=10, decay=0.95)
FROST_TIP = 1.72
body_key(fr, FROST_TIP, "smooth", -9, 0, 1, hips=(0, 0.04), drop=0.1, **FROZEN)
stand(fr, 0.0, FROST_TIP, Feet(stance=0.0), ramp=0.0)
# over, stiff: the whole body a rod five studs long about the front of its soles
keys, HIT_FROST = rod_fall(FROST_TIP, 4.0, spin0=0.75, length=5.0, give=0.04)
for t, lean in keys[1:]:
    joints = dict(root=(-9 - lean, 0, 1), rHip=J((9, 0, 0)), lHip=J((9, 0, 0)), **FROZEN)
    off = body_on(joints, "Right Leg", (0, -1, -0.5), (0.5, 0.0, -0.5))
    if lean >= 84:
        low = posekit.lowest(joints, off)
        off = (off[0], off[1] - low + 0.02, off[2])
    fr.key(t, "linear", offset=off, **joints)
fr.build()
record(fr, HIT_FROST, fx=0.9, still=HIT_FROST + 0.2)

# =====================================================================================================================
# The chandelier: a creak above; the head snaps up; frozen a beat looking at it; the arms fly up over the head, the
# knees bend, too late: crushed flat under it (the effect's crystal lands 0.5 s after it starts), limbs flung out; a
# twitch; pinned.

ch = Motion("deathChandelier", 2.8, note="A look up at a creak, the arms up too late, crushed flat, limbs flung out.",
            floor=True)
ch.key(0.0, **REST)
strike(ch, 0.2, body(0, neck=J((-4, 0, 0))), body(5, hips=(0, 0.04), drop=-0.01, neck=J((42, 0, 0))),
       antic=0.08, travel=0.08, over=0.12, settle=0.2)
body_key(ch, 0.5, "smooth", 5, hips=(0, 0.04), drop=-0.01, neck=(44, 0, 2), rShoulder=J((10, 0, 8)),
         lShoulder=J((12, 0, -8)))
SHIELD_R, SHIELD_L = J((152, 0, 30), (0, 0.06, 0)), J((150, 0, -32), (0, 0.06, 0))
strike(ch, 0.72, dict(rShoulder=J((20, 0, 10)), lShoulder=J((22, 0, -10))),
       body(-12, hips=(0, 0.14), drop=0.28, rShoulder=SHIELD_R, lShoulder=SHIELD_L, neck=J((30, 0, 0))),
       antic=0.1, travel=0.1, over=0.1, settle=0.12)
HIT_CH = 0.95
CH_HIPS = (0.0, 0.14)
body_key(ch, HIT_CH - 0.04, "smooth", -14, hips=CH_HIPS, drop=0.34, neck=(30, 0, 0), rShoulder=SHIELD_R,
         lShoulder=SHIELD_L)
stand(ch, 0.0, HIT_CH - 0.03, Feet(), ramp=0.0)
# crushed: driven down flat in a few frames, the arms and legs flung out
floor_key(ch, HIT_CH + 0.03, "snap", -62, 0, 0, CH_HIPS, dict(rHip=J((30, 0, 16)), lHip=J((26, 0, -16))),
          dict(neck=(10, 0, 0), rShoulder=J((150, 0, 70)), lShoulder=J((150, 0, -70))))
PINNED_LEGS = dict(rHip=J((-3, 0, 15)), lHip=J((-2, 0, -15)))
PIN_R, PIN_L = J((96, 0, 82)), J((96, 0, -84))
prone_key(ch, HIT_CH + 0.1, "snap", neck=(6, 0, 4), rShoulder=J((92, 0, 86)), lShoulder=J((92, 0, -86)), hips=CH_HIPS,
          legs=dict(rHip=J((-2, 0, 16)), lHip=J((-2, 0, -16))))
prone_key(ch, HIT_CH + 0.2, "out", neck=(10, 0, 8), rShoulder=PIN_R, lShoulder=PIN_L, hips=CH_HIPS,
          legs=dict(rHip=J((-4, 0, 14)), lHip=J((-2, 0, -15))))
# a twitch of the leg, then of a hand; pinned
prone_key(ch, 1.25, "snap", neck=(10, 0, 8), rShoulder=PIN_R, lShoulder=PIN_L, hips=CH_HIPS,
          legs=dict(rHip=J((-14, 0, 16), (0, 0.15, 0)), lHip=J((-2, 0, -15))))
prone_key(ch, 1.45, "sine", neck=(10, 0, 8), rShoulder=PIN_R, lShoulder=PIN_L, hips=CH_HIPS, legs=PINNED_LEGS)
prone_key(ch, 1.62, "snap", neck=(10, 0, 8), rShoulder=PIN_R, lShoulder=J((106, 0, -80)), hips=CH_HIPS,
          legs=PINNED_LEGS)
prone_key(ch, 1.9, "sine", neck=(10, 0, 9), rShoulder=PIN_R, lShoulder=PIN_L, hips=CH_HIPS, legs=PINNED_LEGS)
prone_key(ch, 2.8, "smooth", neck=(10, 0, 9), rShoulder=PIN_R, lShoulder=PIN_L, hips=CH_HIPS, legs=PINNED_LEGS)
soft(ch, head=4.0, arms=4.0, arm_damp=0.5)
ch.build()
record(ch, HIT_CH, fx=HIT_CH - 0.5)

# =====================================================================================================================
# Drowned on dry land: a gasp and both hands at the throat, clawing, twisting, a step back; then it is as if they were
# under water: everything slows, the arms reach up and pull for a surface that isn't there, up on the toes, the head
# back; and a slow sink, sat down and laid back as if the water held them, the arms floating down last.

dr = Motion("deathDrown", 3.7, note="Clawing at the throat, then as if under water: reaching up for a surface, a slow "
            "sink onto the back.", floor=True)
dr.key(0.0, **REST)
strike(dr, 0.18, body(-3), body(8, hips=(0, 0.06), drop=-0.04, neck=J((18, 0, 0)), rShoulder=THROAT_R,
                                lShoulder=THROAT_L), antic=0.06, travel=0.08, over=0.15, settle=0.15)
for k, t in enumerate((0.42, 0.62, 0.82, 1.0)):
    s = 1 if k % 2 else -1
    body_key(dr, t, "sine", 6 - k, 12 * s, 4 * s, hips=(0.03 * s, 0.06 + 0.1 * min(1, k / 2)), drop=0.04 + 0.02 * k,
             neck=(14, -10 * s, 4 * s), rShoulder=mix(THROAT_R, J((112, 0, -26), (-0.25, 0.2, -0.2)), 0.2 * (k % 2)),
             lShoulder=mix(THROAT_L, J((110, 0, 26), (0.25, 0.2, -0.2)), 0.2 * ((k + 1) % 2)))
# under water: slow; the arms let go of the throat and reach up, pulling down in turn; up on the toes
body_key(dr, 1.3, "sine", 6, hips=(0, 0.22), drop=-0.06, neck=(30, 0, 0), rShoulder=J((168, 0, 18)),
         lShoulder=J((120, 0, -30)))
body_key(dr, 1.6, "sine", 8, 4, 2, hips=(0, 0.2), drop=-0.08, neck=(32, 4, 0), rShoulder=J((120, 0, 30)),
         lShoulder=J((170, 0, -16)))
body_key(dr, 1.9, "sine", 6, -2, -1, hips=(0, 0.2), drop=-0.04, neck=(30, -2, 0), rShoulder=J((166, 0, 20)),
         lShoulder=J((116, 0, -32)))
stand(dr, 0.0, 2.0, Feet(steps=[(0.5, 0.74, 1, -0.42)]))
# the slow sink: the knees fold, they settle onto the floor, the arms floating up before them
DR_HIPS = (0.0, 0.5)
floor_key(dr, 2.3, "sine", 4, 0, 0, (0.0, 0.3), crouch_legs(50, 0.5),
          dict(neck=(18, 0, 0), rShoulder=J((120, 0, 24)), lShoulder=J((110, 0, -26))))
sit_key(dr, 2.65, "sine", lean=16, neck=(8, 0, 0), hips=DR_HIPS, rShoulder=J((104, 0, 26)), lShoulder=J((100, 0, -28)))
# laid back slowly, as if the water held them (no gravity's snap)
sit_key(dr, 2.9, "sine", lean=46, neck=(-6, 0, 0), hips=DR_HIPS, rShoulder=J((100, 0, 30)), lShoulder=J((96, 0, -30)))
HIT_DR = 3.12
supine_key(dr, HIT_DR, "sine", neck=(10, 0, 0), hips=DR_HIPS, rShoulder=J((96, 0, 34)), lShoulder=J((92, 0, -34)))
# the arms drift down to the floor
supine_key(dr, 3.5, "sine", neck=(14, 8, -4), hips=DR_HIPS, rShoulder=J((30, 0, 40)), lShoulder=J((26, 0, -38)))
supine_key(dr, 3.7, "smooth", neck=(14, 10, -4), hips=DR_HIPS, rShoulder=BACK_R, lShoulder=BACK_L)
soft(dr, head=1.6, arms=1.2, head_damp=0.8, arm_damp=0.75)
dr.build()
record(dr, HIT_DR, fx=0.9)

# =====================================================================================================================
# Struck by lightning: a prickle, the head tilting up; the bolt: rigid in two frames, arched back, the arms flung out
# stiff, up on the toes, shaking with the current; it stops: limp at once, the knees go, sat down and over onto the
# back; one last twitch.

lt = Motion("deathLightning", 2.8, note="A prickle, the bolt: rigid and arched, shaking; limp at once, down on the "
            "back; a last twitch.", floor=True)
BOLT = 0.55
lt.key(0.0, **REST)
lt.key(0.4, "sine", root=(1, 0, 0), neck=(10, 4, 0), rShoulder=HANG_R, lShoulder=HANG_L)
lt.key(BOLT, root=(1, 0, 0), neck=(10, 4, 0), rShoulder=HANG_R, lShoulder=HANG_L)
RIGID = dict(neck=(28, 0, 0), rShoulder=J((-12, 0, 82)), lShoulder=J((-12, 0, -82)))
body_key(lt, BOLT + 0.04, "snap", 18, hips=(0, 0.06), drop=-0.14, **RIGID)
body_key(lt, 1.12, "smooth", 18, hips=(0, 0.06), drop=-0.14, **RIGID)
shiver(lt, BOLT + 0.03, 1.13, {"root": (2.4, 1.2, 2.0), "neck": (3.0, 2.4, 1.0), "rShoulder": (4.0, 0, 3.2),
                               "lShoulder": (4.0, 0, 3.2)}, amount=1.0, hz=15)
stand(lt, 0.0, 1.14, Feet(stance=0.0), ramp=0.0)
# limp: dropped straight down, the arms falling, the arch carrying them back
RELEASE = 1.14
LT_HIPS = (0.0, 0.4)
floor_key(lt, RELEASE + 0.16, "in", 22, 0, 3, (0.0, 0.26), crouch_legs(46, 0.5),
          dict(neck=(-14, 0, 4), rShoulder=J((10, 0, 30)), lShoulder=J((12, 0, -26))))
sit_key(lt, RELEASE + 0.32, "in", lean=26, neck=(-20, 0, 6), hips=LT_HIPS, rShoulder=J((6, 0, 22)),
        lShoulder=J((8, 0, -20)))
hit = topple_back(lt, RELEASE + 0.32, 26.0, LT_HIPS, spin0=1.6, length=3.0,
                  arms=lambda u: dict(rShoulder=mix(J((6, 0, 22)), OUT_R, u), lShoulder=mix(J((8, 0, -20)), OUT_L, u)),
                  head0=-20.0)
supine_key(lt, hit + 0.12, "out", neck=(28, 0, 6), hips=LT_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
supine_key(lt, hit + 0.36, "sine", neck=(14, 0, 8), hips=LT_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
# one last twitch: an arm and a leg jerk with what is left of the current
TWITCH = hit + 0.62
supine_key(lt, TWITCH - 0.02, "smooth", neck=(14, 0, 8), hips=LT_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
supine_key(lt, TWITCH + 0.05, "snap", neck=(18, 0, 8), hips=LT_HIPS, rShoulder=J((26, 0, 70)), lShoulder=OUT_L,
           legs=dict(rHip=J((16, 0, 5), (0, 0.2, 0)), lHip=J((-4, 0, -5))))
supine_key(lt, TWITCH + 0.3, "sine", neck=(14, 4, 10), hips=LT_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
supine_key(lt, 2.8, "smooth", neck=(14, 6, 10), hips=LT_HIPS, rShoulder=OUT_R, lShoulder=OUT_L)
soft(lt, head=3.5, arms=3.0, arm_damp=0.5)
lt.build()
record(lt, hit, fx=BOLT)

# =====================================================================================================================
# A thousand paper cuts: a flinch at the first, the arms up beside the head; then cut from every side, each a jerk away
# from it, staggering round on real steps; the arms give, the knees go, and over onto the face.

pg = Motion("deathPages", 3.1, note="Arms up against a storm of pages, flinching from every side, staggering round, "
            "down on the face.", floor=True)
GUARD_R = reach(1, (0.62, 1.7, -0.5), direction=(-0.2, 0.95, -0.3))
GUARD_L = reach(-1, (-0.62, 1.66, -0.52), direction=(0.2, 0.95, -0.3))
pg.key(0.0, **REST)
strike(pg, 0.3, body(0), body(-6, 14, 6, hips=(-0.06, 0.0), drop=0.04, neck=J((-6, 24, 4)),
                              rShoulder=J((70, 0, 20))), antic=0.05, travel=0.05, over=0.2, settle=0.12)
body_key(pg, 0.52, "out", -10, 10, 0, hips=(0, 0.04), drop=0.12, neck=(-8, 6, 0), rShoulder=GUARD_R, lShoulder=GUARD_L)
# cut after cut, each from a side: the body jerks away from it (two frames) and turns further round each time,
# the feet stepping round under it
turn = 10.0
cuts = [(0.66, 1, 22, (0.0, 0.12)), (0.9, -1, 34, (0.05, 0.26)), (1.1, 1, 30, (0.0, 0.42)), (1.32, -1, 34, (0.1, 0.6)),
        (1.52, 1, 30, (0.12, 0.68))]
for k, (t, side, more, hips) in enumerate(cuts):
    body_key(pg, t - 0.05, "smooth", -10, turn + more * 0.4, 0, hips=hips, drop=0.14, neck=(-8, 0, 0),
             rShoulder=GUARD_R, lShoulder=GUARD_L)
    turn += more
    body_key(pg, t, "snap", -14 + 6 * (k % 2), turn, -8 * side, hips=(hips[0] + 0.05 * side, hips[1]), drop=0.2,
             neck=(-14, -10 * side, -6 * side), rShoulder=GUARD_R, lShoulder=GUARD_L)
TURN = turn
pg_feet = Feet(steps=[(0.62, 0.84, -1, (-0.35, 0.3, 50)), (0.86, 1.06, 1, (0.6, 0.35, 92)),
                      (1.08, 1.28, -1, (-0.2, 0.85, 128)), (1.3, 1.5, 1, (0.55, 0.95, 160))])
pg.key(0.0, rHip=J((0, 0, 0)), lHip=J((0, 0, 0)))
PG_HIPS = (0.14, 0.72)
body_key(pg, 1.72, "sine", -14, TURN, -4, hips=PG_HIPS, drop=0.3, neck=(-12, 0, -4), rShoulder=mix(GUARD_R, HANG_R, 0.6),
         lShoulder=mix(GUARD_L, HANG_L, 0.7))
stand(pg, 0.0, 1.85, pg_feet)
# the arms give, the knees go
floor_key(pg, 2.0, "in", -34, TURN, -4, PG_HIPS, dict(rHip=J((34, 0, 2)), lHip=J((34, 0, -2))),
          dict(neck=(-16, 0, -2), rShoulder=J((30, 0, 6)), lShoulder=J((26, 0, -6))))
kneel_key(pg, 2.16, "in", lean=-40, turn=TURN, head=-20, hips=PG_HIPS, rShoulder=J((60, 0, 6)), lShoulder=J((50, 0, -6)))
hit = topple_forward(pg, 2.16, 40.0, PG_HIPS, spin0=1.7, arm="r", hold_l=J((50, 0, -6)), head0=-20.0, turn=TURN,
                     rest_neck=(12, 0, -16))
prone_key(pg, 3.1, "smooth", turn=TURN, neck=(12, 0, -18), hips=PG_HIPS, rShoulder=J((180, 0, 8)), lShoulder=SIDE_L)
soft(pg, head=3.6, arms=3.2, arm_damp=0.5)
pg.build()
record(pg, hit, fx=0.3)

# =====================================================================================================================
# Burned from within: doubled over at the gut; the heat climbs and throws them upright, the head back in a silent
# scream, hands tearing at the chest; staggering, beating at themselves; the knees go, hands to the face; over.

bn = Motion("deathBurn", 3.1, note="Doubled over at the gut, thrown upright screaming, beating at themselves, down on "
            "the face.", floor=True)
bn.key(0.0, **REST)
strike(bn, 0.2, body(3), body(-32, hips=(0, 0.16), drop=0.12, neck=J((-6, 0, 0)), rShoulder=BELLY_R,
                              lShoulder=BELLY_L), antic=0.06, travel=0.08, over=0.15, settle=0.2)
FX_BURN = 0.45
TEAR_R = reach(1, (0.3, 0.75, -0.72), direction=(-0.4, 0.55, -0.72))
TEAR_L = reach(-1, (-0.3, 0.7, -0.72), direction=(0.4, 0.55, -0.72))
strike(bn, 0.72, body(-36, hips=(0, 0.16), drop=0.14, neck=J((-12, 0, 0))),
       body(12, hips=(0, 0.06), drop=0.0, neck=J((36, 0, 0)), rShoulder=TEAR_R, lShoulder=TEAR_L),
       antic=0.12, travel=0.12, over=0.12, settle=0.2)
body_key(bn, 1.0, "sine", 8, 8, 4, hips=(0, 0.1), drop=0.04, neck=(30, 10, 4), rShoulder=J((70, 0, 46)),
         lShoulder=TEAR_L)
body_key(bn, 1.2, "snap", -4, -10, -4, hips=(0.05, 0.22), drop=0.08, neck=(14, -8, -4),
         rShoulder=reach(1, (-0.9, 0.3, -0.7), direction=(-0.9, -0.1, -0.4)), lShoulder=J((60, 0, -50)))
body_key(bn, 1.4, "snap", -8, 8, 4, hips=(-0.04, 0.04), drop=0.1, neck=(10, 8, 4), rShoulder=J((50, 0, 40)),
         lShoulder=reach(-1, (0.3, 0.45, -0.75), direction=(0.8, 0.0, -0.6)))
BN_HIPS = (0.0, -0.02)
body_key(bn, 1.58, "sine", -14, 4, 2, hips=BN_HIPS, drop=0.2, neck=(4, 0, 2), rShoulder=J((40, 0, 20)),
         lShoulder=J((44, 0, -18)))
stand(bn, 0.0, 1.66, Feet(steps=[(0.98, 1.16, -1, -0.38), (1.22, 1.42, 1, 0.4)]))
FACE_R = reach(1, (0.2, 1.42, -0.86), direction=(-0.3, 0.8, -0.5))
FACE_L = reach(-1, (-0.2, 1.38, -0.86), direction=(0.3, 0.8, -0.5))
floor_key(bn, 1.8, "in", -30, 2, 2, BN_HIPS, dict(rHip=J((36, 0, 2)), lHip=J((36, 0, -2))),
          dict(neck=(-6, 0, 0), rShoulder=FACE_R, lShoulder=FACE_L))
kneel_key(bn, 1.98, "in", lean=-38, head=-12, hips=BN_HIPS, rShoulder=FACE_R, lShoulder=FACE_L)
kneel_key(bn, 2.12, "sine", lean=-42, head=-16, hips=BN_HIPS, rShoulder=FACE_R, lShoulder=FACE_L)
hit = topple_forward(bn, 2.12, 42.0, BN_HIPS, spin0=1.5, arm="l", hold_r=FACE_R, head0=-16.0)
prone_key(bn, 2.75, "sine", neck=(12, 0, 14), hips=BN_HIPS, rShoulder=SIDE_R, lShoulder=J((180, 0, -8)))
prone_key(bn, 2.85, "snap", neck=(12, 0, 14), hips=BN_HIPS, rShoulder=J((14, 0, 12)), lShoulder=J((180, 0, -8)))
prone_key(bn, 3.1, "sine", neck=(12, 0, 14), hips=BN_HIPS, rShoulder=SIDE_R, lShoulder=J((180, 0, -8)))
soft(bn, head=3.4, arms=3.0, arm_damp=0.55)
bn.build()
record(bn, hit, fx=FX_BURN)

# =====================================================================================================================
# Choked on a potato chip (Light's chip: "and EAT IT"): the hand sweeps up from the side with a flourish to the mouth;
# the crunch; frozen a beat; both hands to the throat; staggering back, bending to cough it up, a hand reaching out
# for help; the knees go and over onto the back, a hand still at the throat.

cp = Motion("deathChip", 3.3, note="A flourished bite, the crunch, frozen; hands to the throat, staggering, reaching "
            "out, over onto the back.", floor=True)
CRUNCH = 0.62
cp.key(0.0, **REST)
cp.key(0.22, "sine", root=(0, -4, 0), neck=(2, -10, 0), rShoulder=J((40, 0, 62)), lShoulder=HANG_L)
body_key(cp, 0.44, "sine", 3, -6, 0, hips=(0, 0.02), neck=(10, -12, 0), rShoulder=J((132, 0, 44)), lShoulder=HANG_L)
strike(cp, CRUNCH, dict(neck=J((14, -10, 0))), body(-3, hips=(0, 0.0), drop=0.02, neck=J((-4, 0, 0)), rShoulder=MOUTH_R),
       antic=0.06, travel=0.06, over=0.12, settle=0.1)
body_key(cp, 1.0, "smooth", -3, drop=0.02, neck=(-4, 0, 0), rShoulder=MOUTH_R, lShoulder=HANG_L)
strike(cp, 1.14, dict(neck=J((4, 0, 0))), body(4, hips=(0, 0.06), drop=0.0, neck=J((12, 0, 0)), rShoulder=THROAT_R,
                                                lShoulder=THROAT_L), antic=0.07, travel=0.07, over=0.18, settle=0.14)
# staggering back, trying to cough it up: bent over, up again
body_key(cp, 1.36, "sine", -20, 6, 4, hips=(0, 0.3), drop=0.08, neck=(-4, 6, 0), rShoulder=THROAT_R, lShoulder=THROAT_L)
body_key(cp, 1.58, "sine", 6, -4, -2, hips=(0, 0.46), drop=0.04, neck=(20, -4, 0), rShoulder=THROAT_R,
         lShoulder=THROAT_L)
REACH_HELP = J((96, 0, -14), (0, 0.04, 0))
CP_HIPS = (0.0, 0.62)
body_key(cp, 1.82, "sine", -22, 2, 4, hips=CP_HIPS, drop=0.12, neck=(2, 4, 0), rShoulder=THROAT_R,
         lShoulder=REACH_HELP)
stand(cp, 0.0, 1.95, Feet(steps=[(1.22, 1.42, 1, -0.42), (1.48, 1.68, -1, -0.7)]))
# the knees go and they sit down backwards, then over
SIT_CP = (0.0, 1.0)
floor_key(cp, 2.12, "in", 6, 0, 2, (0.0, 0.8), crouch_legs(44, 0.45),
          dict(neck=(6, 0, 0), rShoulder=THROAT_R, lShoulder=J((80, 0, -16))))
sit_key(cp, 2.3, "in", lean=20, neck=(-6, 0, 0), hips=SIT_CP, rShoulder=THROAT_R, lShoulder=J((66, 0, -18)))
hit = topple_back(cp, 2.3, 20.0, SIT_CP, spin0=1.3, length=3.0,
                  arms=lambda u: dict(rShoulder=THROAT_R, lShoulder=mix(J((66, 0, -18)), BACK_L, u)), head0=-6.0)
supine_key(cp, hit + 0.12, "out", neck=(26, 0, 0), hips=SIT_CP, rShoulder=THROAT_R, lShoulder=BACK_L)
supine_key(cp, hit + 0.4, "sine", neck=(16, 0, -4), hips=SIT_CP, rShoulder=THROAT_R, lShoulder=BACK_L)
# the hand slides off the throat onto the chest; still
supine_key(cp, 3.3, "sine", neck=(14, -14, -6), hips=SIT_CP,
           rShoulder=reach(1, (0.1, 0.4, -0.62), direction=(-0.5, 0.2, -0.8)), lShoulder=BACK_L)
soft(cp, head=3.2, arms=2.8, arm_damp=0.55)
cp.build()
record(cp, hit, fx=CRUNCH)

# =====================================================================================================================
# Their time ran out ("The clock hits forty and stops"): a glance at the wrist, the head coming up slowly; then time
# runs down in them and they move only in ticks, like a stopping clock's hand, each tick lower and slower, until the
# last one lays them on the floor; and they stop. No settle: time has stopped.

ck = Motion("deathClock", 3.8, note="A glance at the wrist; then down only in ticks, slower and slower, like a "
            "stopping clock, and stopped.", floor=True)
WATCH_L = reach(-1, (0.15, 0.32, -1.05), direction=(0.72, 0.1, -0.68))
ck.key(0.0, **REST)
body_key(ck, 0.4, "sine", -4, drop=0.02, neck=(-18, -4, 0), rShoulder=HANG_R, lShoulder=WATCH_L)
body_key(ck, 0.62, "smooth", -4, drop=0.02, neck=(-18, -4, 0), rShoulder=HANG_R, lShoulder=WATCH_L)
body_key(ck, 0.9, "sine", -2, drop=0.02, neck=(0, -2, 0), rShoulder=HANG_R, lShoulder=WATCH_L)
CK_HIPS = (0.0, 0.1)
TICKS = [
    (1.0, dict(pitch=-4, hips=(0, 0.02), drop=0.04, neck=(-2, 0, 6), rShoulder=HANG_R, lShoulder=J((26, 0, -10)))),
    (1.3, dict(pitch=-12, roll=2, hips=(0, 0.06), drop=0.16, neck=(-6, 0, 8), rShoulder=J((6, 0, 6)),
               lShoulder=J((8, 0, -8)))),
    (1.62, dict(pitch=-24, roll=3, hips=CK_HIPS, drop=0.38, neck=(-10, 0, 8), rShoulder=J((14, 0, 6)),
                lShoulder=J((12, 0, -8)))),
]
for k, (t, pose) in enumerate(TICKS):
    if k > 0:
        body_key(ck, t - 0.07, "hold", **TICKS[k - 1][1])
    body_key(ck, t, "snap", **pose)
stand(ck, 0.0, 1.9, Feet(stance=0.04), ramp=0.0)
body_key(ck, 1.9, "hold", **TICKS[-1][1])
# the knees give in a tick: the legs swing back under the body (R6's knee), then onto the knees, then over
floor_key(ck, 1.97, "snap", -32, 0, 4, CK_HIPS, dict(rHip=J((4, 0, 2), (0, 0.08, 0.1)), lHip=J((4, 0, -2), (0, 0.08, 0.1))),
          dict(neck=(-12, 0, 10), rShoulder=J((26, 0, 8)), lShoulder=J((24, 0, -8))))
floor_key(ck, 2.28, "hold", -32, 0, 4, CK_HIPS, dict(rHip=J((4, 0, 2), (0, 0.08, 0.1)), lHip=J((4, 0, -2), (0, 0.08, 0.1))),
          dict(neck=(-12, 0, 10), rShoulder=J((26, 0, 8)), lShoulder=J((24, 0, -8))))
kneel_key(ck, 2.35, "snap", lean=-40, head=-14, roll=4, hips=CK_HIPS, rShoulder=J((30, 0, 6)), lShoulder=J((28, 0, -6)))
kneel_key(ck, 2.71, "hold", lean=-40, head=-14, roll=4, hips=CK_HIPS, rShoulder=J((30, 0, 6)), lShoulder=J((28, 0, -6)))
kneel_key(ck, 2.78, "snap", lean=-64, head=-6, roll=4, hips=CK_HIPS, rShoulder=J((56, 0, 6)), lShoulder=J((120, 0, -6)))
kneel_key(ck, 3.18, "hold", lean=-64, head=-6, roll=4, hips=CK_HIPS, rShoulder=J((56, 0, 6)), lShoulder=J((120, 0, -6)))
HIT_CK = 3.25
prone_key(ck, HIT_CK, "snap", neck=(12, 0, 16), hips=CK_HIPS, rShoulder=SIDE_R, lShoulder=J((176, 0, -8)))
prone_key(ck, 3.8, "hold", neck=(12, 0, 16), hips=CK_HIPS, rShoulder=SIDE_R, lShoulder=J((176, 0, -8)))
ck.build()
record(ck, HIT_CK, fx=0.9, still=HIT_CK)

# =====================================================================================================================
# Taken by the dark: unease, a slow look back over the shoulder; a yank: the legs pulled out from behind, down on the
# face, the arms out to catch it; dragged back along the floor in pulls, clawing at it, the head up to us; a last long
# pull back into the dark.

dk = Motion("deathDark", 3.1, note="A look back; the legs yanked out, down on the face; dragged back in pulls, "
            "clawing at the floor.", floor=True)
dk.key(0.0, **REST)
body_key(dk, 0.55, "sine", -2, -14, 0, drop=0.04, neck=(-2, -56, 0), rShoulder=J((4, 0, 10)), lShoulder=J((6, 0, -6)))
YANK = 0.78
body_key(dk, YANK - 0.05, "smooth", -2, -14, 0, drop=0.05, neck=(0, -50, 0), rShoulder=J((4, 0, 10)),
         lShoulder=J((6, 0, -6)))
stand(dk, 0.0, YANK, Feet(), ramp=0.0)
# the legs swept back from under them: the body pitches down onto its face, the arms thrown out to catch it
body_key(dk, YANK + 0.1, "snap", -42, -6, 0, hips=(0, 0.45), drop=0.62, neck=(20, -10, 0), rShoulder=J((110, 0, 20)),
         lShoulder=J((116, 0, -18)), rHip=J((-48, 0, 4)), lHip=J((-44, 0, -4)))
body_key(dk, YANK + 0.2, "in", -72, 0, 0, hips=(0, 0.85), drop=1.35, neck=(26, 0, 0), rShoulder=J((150, 0, 16)),
         lShoulder=J((156, 0, -16)), rHip=J((-20, 0, 4)), lHip=J((-18, 0, -4)))
HIT_DK = YANK + 0.28
CLAW = J((160, 0, 14), (0, 0.15, 0))
z = 1.0
prone_key(dk, HIT_DK, "in", neck=(30, 0, 0), rShoulder=AHEAD_R, lShoulder=AHEAD_L, hips=(0.0, z))
for t, dz, side in [(1.35, 0.55, "r"), (1.82, 0.7, "l"), (2.25, 0.8, "r")]:
    # between pulls a hand reaches ahead and claws; on a pull the body slides back, the clawing arm dragged straight
    reach_r, reach_l = (CLAW, AHEAD_L) if side == "r" else (AHEAD_R, J((160, 0, -14), (0, 0.15, 0)))
    prone_key(dk, t - 0.12, "sine", neck=(32, 4 if side == "r" else -4, 0), rShoulder=reach_r, lShoulder=reach_l,
              hips=(0.0, z))
    z += dz
    prone_key(dk, t + 0.08, "snap", neck=(24, 0, 0), rShoulder=AHEAD_R, lShoulder=AHEAD_L, hips=(0.0, z))
# the last long pull, into the dark
prone_key(dk, 2.5, "sine", neck=(34, 0, 0), rShoulder=J((176, 0, 12)), lShoulder=J((176, 0, -12)), hips=(0.0, z))
z += 1.6
prone_key(dk, 2.82, "in", neck=(16, 0, 6), rShoulder=AHEAD_R, lShoulder=AHEAD_L, hips=(0.0, z))
prone_key(dk, 3.1, "smooth", neck=(12, 0, 8), rShoulder=AHEAD_R, lShoulder=AHEAD_L, hips=(0.0, z))
soft(dk, head=3.2, arms=3.0, arm_damp=0.55)
dk.build()
record(dk, HIT_DK, fx=0.5)


# =====================================================================================================================
# Shared/Anim/DeathTiming.luau, from TIMING and fallen.py's MOMENTS (fallen.py writes it once both are made).

def _num(v):
    return f"{v:g}"


def write_timing(fallen=None):
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.normpath(os.path.join(here, "..", "..", "src", "shared", "Anim", "DeathTiming.luau"))
    lines = [
        "--!strict",
        "-- When things happen in each death, seconds from the start of its clip. Written by art/scripts/deaths.py and",
        "-- fallen.py (do not edit by hand).",
        "--   deaths  each collapse and custom death: when the body first hits the floor (`hit`), when its custom effect",
        "--           starts (`fx`: Presentation/CustomDeaths), when it lies still (`still`), the clip's `length`",
        "--   fallen  each fallen body's death-style clip (fallen<Style><Down|Up>): its `length` and its moments, which",
        "--           Presentation/Styles.death times its effect by (strings: catch, lift, snap, heap; crows: lift, burst;",
        "--           stone: climb, set, crumble; glass: glass, look, shatter; ash: effort, give, grey, crumble)",
        "",
        "export type Timing = { hit: number, fx: number?, still: number, length: number }",
        "",
        "return {",
        "	deaths = {",
    ]
    for name in sorted(TIMING):
        t = TIMING[name]
        fx = "" if t["fx"] is None else f", fx = {_num(t['fx'])}"
        lines.append(f"		{name} = {{ hit = {_num(t['hit'])}{fx}, still = {_num(t['still'])}, length = {_num(t['length'])} }},")
    lines.append("	} :: { [string]: Timing },")
    lines.append("	fallen = {")
    for name in sorted(fallen or {}):
        moments = fallen[name]
        parts = ", ".join(f"{k} = {_num(v)}" for k, v in sorted(moments.items()))
        lines.append(f"		{name} = {{ {parts} }},")
    lines.append("	} :: { [string]: { [string]: number } },")
    lines.append("}")
    text = "\n".join(lines) + "\n"
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    if old != text:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
