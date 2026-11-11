"""Every death the game plays (the user's ask of 2026-11-07: "very high quality", all of them redone; the custom deaths'
first actings of 2026-10-27 and the three plain collapses are replaced): the three everyday causes (Heart attack,
Disease, Accident: collapse*), the causes bought in the shop (Shared/Cosmetics kind "reason": death*, matched to
their effects in Presentation/CustomDeaths). anims.py
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
# Shared/Anim/DeathTiming.luau, from TIMING (anims.py writes it once every death is made).

def _num(v):
    return f"{v:g}"


def write_timing():
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.normpath(os.path.join(here, "..", "..", "src", "shared", "Anim", "DeathTiming.luau"))
    lines = [
        "--!strict",
        "-- When things happen in each death, seconds from the start of its clip. Written by art/scripts/deaths.py",
        "-- (do not edit by hand).",
        "--   deaths  each collapse and custom death: when the body first hits the floor (`hit`), when its custom effect",
        "--           starts (`fx`: Presentation/CustomDeaths), when it lies still (`still`), the clip's `length`",
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
    lines.append("}")
    text = "\n".join(lines) + "\n"
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    if old != text:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
