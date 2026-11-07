"""What a fallen body does under its death style (Shared/Cosmetics kind "death"; the user's ask of 2026-11-07: "new
ones for death styles", in matches and in the shop). Each style acts after the collapse, from the body lying still, on
a copy of it that stands in for the real one on every screen (Presentation/Fallen), its effect timed to the acting
(Presentation/Styles.death):

  strings  Cut Strings: strings drop from above and catch the head, the hands and the knees; they haul the body up off
           the floor until it hangs like a marionette, jerk it through a few steps of a puppet's dance, and snap: it
           drops in a heap on its knees, folded over, an arm sliding off to the floor.
  crows    Murder of Crows: the chest lifts off the floor, then the whole body, limp, limbs hanging, rising slowly;
           at the top it swings upright, the arms thrown open like wings, and it bursts into crows.
  stone    Petrified: a last effort as the stone climbs from the feet: up on one arm, the other reaching out and up,
           slower and slower, and it sets there; a held moment; it crumbles.
  glass    Shattered: drawn up off the floor as it turns to glass, onto its knees (or sat up), head bowed, arms hanging;
           the head comes up a little, a last look; it shatters.
  ash      Ash to Ash: a last try to get up, pushing up on the arms (or sitting up, reaching out), trembling; the arms
           give, and it sinks back as it greys and crumbles from the head down.

Each comes twice: <name>Down from a body lying face down, <name>Up from one on its back (a death ends one way or the
other; the game picks by which way the chest faces). Both start from deathkit's lying pose with the hips on the mark;
the game lays the clip's first frame over the body as it lies (its torso where the body's is) and eases the limbs from
where they are into it over the first moments."""

from animlib import J
from deathkit import (BACK_L, BACK_R, PRONE_LEGS, SIDE_L, SIDE_R, SUPINE_LEGS, body_key, kneel_key, mix, prone_key,
                      shiver, sit_key, supine_key)
from cinema.acting import soft
from motion import Motion

# When each style's moments come (seconds from the clip's start), for the effects (Presentation/Styles.death).
MOMENTS = {}

PRONE_NECK, SUPINE_NECK = (12, 0, 14), (18, 0, -10)


def lying(m, t, family, ease="smooth", **kw):
    """The lying pose the style clips start from (deathkit's), at t."""
    if family == "Down":
        prone_key(m, t, ease, neck=kw.get("neck", PRONE_NECK), rShoulder=kw.get("rShoulder", SIDE_R),
                  lShoulder=kw.get("lShoulder", SIDE_L), legs=kw.get("legs"))
    else:
        supine_key(m, t, ease, neck=kw.get("neck", SUPINE_NECK), rShoulder=kw.get("rShoulder", BACK_R),
                   lShoulder=kw.get("lShoulder", BACK_L), legs=kw.get("legs"))


def arm_world(pitch, world, out=0.0, side=1, slide=(0, 0, 0)):
    """An arm pointing `world` degrees in the body's own upright plane (0 down, 90 ahead, 180 up) for a torso pitched
    `pitch` (negative forward), swung `out` degrees to its side."""
    return J((world - pitch, 0, side * out), slide)


# =====================================================================================================================
# Cut Strings

HANG = 2.2  # the hips' height when it hangs, the toes just off the floor
SNAP = 2.5


def strings(family):
    m = Motion("fallenStrings" + family, 3.6, note="Cut Strings: hauled up on strings, a puppet's jerks, dropped in a "
               "heap.", floor=True)
    down = family == "Down"
    lying(m, 0.0, family)
    # the strings catch: the head, then each hand, jerked a little toward them
    if down:
        prone_key(m, 0.14, "snap", neck=(24, 0, 10))
        prone_key(m, 0.24, "snap", neck=(22, 0, 10), rShoulder=J((26, 0, 22)))
        prone_key(m, 0.32, "snap", neck=(22, 0, 10), rShoulder=J((24, 0, 20)), lShoulder=J((28, 0, -24)))
        prone_key(m, 0.42, "sine", neck=(20, 0, 8), rShoulder=J((22, 0, 20)), lShoulder=J((24, 0, -22)))
        # hauled up by the head and the hands: the chest rises off the floor about the hips, the legs trailing on it
        body_key(m, 0.82, "in", -58, hips=(0, -0.1), drop=1.5, neck=(-26, 0, 8), rShoulder=arm_world(-58, 168, 26, 1),
                 lShoulder=arm_world(-58, 166, 26, -1), rHip=J((-30, 0, 4)), lHip=J((-28, 0, -4)))
        hang_hips = (0.0, -0.85)
    else:
        supine_key(m, 0.14, "snap", neck=(6, 0, -8))
        supine_key(m, 0.24, "snap", neck=(4, 0, -8), rShoulder=J((26, 0, 40)))
        supine_key(m, 0.32, "snap", neck=(4, 0, -8), rShoulder=J((24, 0, 40)), lShoulder=J((30, 0, -40)))
        supine_key(m, 0.42, "sine", neck=(2, 0, -6), rShoulder=J((22, 0, 38)), lShoulder=J((26, 0, -38)))
        # hauled up by the head and the hands: sat up, the legs along the floor
        body_key(m, 0.82, "in", 34, hips=(0, 0.1), drop=1.5, neck=(-24, 0, 6), rShoulder=arm_world(34, 168, 26, 1),
                 lShoulder=arm_world(34, 166, 26, -1), rHip=J((56, 0, 4)), lHip=J((56, 0, -4)))
        hang_hips = (0.0, 0.85)
    # ...up off the floor, the legs swinging down under it, until it hangs, the head lolling, toes just clear
    body_key(m, 1.18, "smooth", -24, hips=(hang_hips[0], hang_hips[1] * 0.7), drop=0.9, neck=(-34, 0, 10),
             rShoulder=arm_world(-24, 158, 34, 1), lShoulder=arm_world(-24, 160, 34, -1), rHip=J((14, 0, 6)),
             lHip=J((6, 0, -6)))
    body_key(m, 1.5, "out", -10, hips=hang_hips, drop=2.0 - HANG, neck=(-40, 0, 14), rShoulder=J((150, 0, 38)),
             lShoulder=J((148, 0, -38)), rHip=J((8, 0, 4)), lHip=J((2, 0, -4)))
    # a puppet's dance: jerked, and dangling after each jerk
    jerks = [
        (1.66, dict(pitch=-6, roll=6, drop=-0.36, neck=(-20, 0, 18), rShoulder=J((172, 0, 22)), lShoulder=J((112, 0, -30)),
                    rHip=J((4, 0, 4)), lHip=J((-4, 0, -4)))),
        (1.86, dict(pitch=-8, roll=-6, drop=-0.3, neck=(-24, 0, -14), rShoulder=J((110, 0, 30)), lShoulder=J((170, 0, -20)),
                    rHip=J((44, 0, 4), (0, 0.3, 0)), lHip=J((-6, 0, -4)))),
        (2.06, dict(pitch=-2, roll=2, drop=-0.48, neck=(-6, 0, 6), rShoulder=J((176, 0, 30)), lShoulder=J((176, 0, -30)),
                    rHip=J((-4, 0, 4)), lHip=J((40, 0, -4), (0, 0.3, 0)))),
        (2.28, dict(pitch=-30, roll=0, drop=-0.22, neck=(-44, 0, 8), rShoulder=J((96, 0, 18)), lShoulder=J((94, 0, -18)),
                    rHip=J((10, 0, 4)), lHip=J((6, 0, -4)))),
    ]
    for t, pose in jerks:
        hips = (hang_hips[0], hang_hips[1])
        body_key(m, t - 0.06, "smooth", **{**pose, "hips": hips, "drop": 2.0 - HANG + 0.04})
        body_key(m, t, "snap", **{**pose, "hips": hips})
    body_key(m, SNAP, "smooth", -14, hips=hang_hips, drop=2.0 - HANG, neck=(-36, 0, 10), rShoulder=J((140, 0, 30)),
             lShoulder=J((138, 0, -30)), rHip=J((6, 0, 4)), lHip=J((2, 0, -4)))
    # the strings snap: it drops, the knees buckle, and it folds into a heap on them
    body_key(m, SNAP + 0.12, "in", -20, hips=hang_hips, drop=0.35, neck=(-30, 0, 10), rShoulder=J((60, 0, 20)),
             lShoulder=J((56, 0, -20)), rHip=J((20, 0, 4), (0, 0.4, 0)), lHip=J((16, 0, -4), (0, 0.4, 0)))
    kneel_key(m, SNAP + 0.3, "in", lean=-50, head=-40, hips=hang_hips, rShoulder=J((40, 0, 10)), lShoulder=J((36, 0, -10)))
    kneel_key(m, SNAP + 0.42, "out", lean=-44, head=-34, hips=hang_hips, rShoulder=J((44, 0, 10)),
              lShoulder=J((40, 0, -10)))
    kneel_key(m, SNAP + 0.75, "sine", lean=-66, head=-44, roll=6, hips=hang_hips, rShoulder=J((62, 0, 12)),
              lShoulder=J((58, 0, -12)))
    # an arm slides off the knee to the floor; still, a puppet left on the floor
    kneel_key(m, 3.6, "sine", lean=-68, head=-46, roll=8, hips=hang_hips, rShoulder=J((66, 0, 16)),
              lShoulder=J((30, 0, -34)))
    soft(m, head=2.2, arms=2.6, head_damp=0.4, arm_damp=0.38)
    m.follow(("rHip", "lHip"), 2.4, 0.4)
    m.build()
    MOMENTS[m.name] = {"catch": 0.14, "lift": 0.42, "snap": SNAP, "heap": SNAP + 0.3}


# =====================================================================================================================
# Murder of Crows

BURST = 1.68


def crows(family):
    m = Motion("fallenCrows" + family, 2.8, note="Murder of Crows: lifted off the floor, limp, swung upright with the "
               "arms thrown open, burst into crows.", floor=True)
    down = family == "Down"
    lying(m, 0.0, family)
    if down:
        # the chest lifts off the floor, the head up, the arms hanging toward it
        body_key(m, 0.45, "sine", -74, hips=(0, 0.0), drop=1.42, neck=(30, 0, 6), rShoulder=arm_world(-74, 4, 10, 1),
                 lShoulder=arm_world(-74, 2, 10, -1), rHip=J((-14, 0, 4)), lHip=J((-14, 0, -4)))
        # the whole body lifts, limp, face down, the limbs hanging under it, turning a little
        body_key(m, 1.0, "sine", -78, 8, 0, hips=(0, -0.2), drop=0.6, neck=(-30, 0, 4), rShoulder=arm_world(-78, -4, 8, 1),
                 lShoulder=arm_world(-78, -6, 8, -1), rHip=J((60, 0, 4)), lHip=J((52, 0, -4)))
        body_key(m, 1.42, "sine", -70, 16, 0, hips=(0, -0.45), drop=-0.25, neck=(-34, 0, 4),
                 rShoulder=arm_world(-70, -6, 6, 1), lShoulder=arm_world(-70, -8, 6, -1), rHip=J((58, 0, 4)),
                 lHip=J((50, 0, -4)))
    else:
        # the chest arches up off the floor, the head hanging back, the arms hanging toward it
        body_key(m, 0.45, "sine", 66, hips=(0, 0.0), drop=1.35, neck=(-10, 0, -4), rShoulder=arm_world(66, -6, 16, 1),
                 lShoulder=arm_world(66, -4, 16, -1), rHip=J((20, 0, 4)), lHip=J((22, 0, -4)))
        body_key(m, 1.0, "sine", 72, -8, 0, hips=(0, 0.2), drop=0.6, neck=(-34, 0, -4),
                 rShoulder=arm_world(72, -2, 10, 1), lShoulder=arm_world(72, 0, 10, -1), rHip=J((-50, 0, 4)),
                 lHip=J((-44, 0, -4)))
        body_key(m, 1.42, "sine", 64, -16, 0, hips=(0, 0.45), drop=-0.25, neck=(-36, 0, -4),
                 rShoulder=arm_world(64, 0, 8, 1), lShoulder=arm_world(64, 2, 8, -1), rHip=J((-48, 0, 4)),
                 lHip=J((-40, 0, -4)))
    top = (0, -0.45) if down else (0, 0.45)
    # swung upright at the top, and the arms thrown open like wings: it bursts
    body_key(m, BURST - 0.06, "in", -6, 0, 0, hips=top, drop=-0.45, neck=(-10, 0, 0), rShoulder=J((60, 0, 40)),
             lShoulder=J((60, 0, -40)), rHip=J((6, 0, 4)), lHip=J((2, 0, -4)))
    body_key(m, BURST, "snap", 8, 0, 0, hips=top, drop=-0.55, neck=(24, 0, 0), rShoulder=J((96, 0, 104)),
             lShoulder=J((96, 0, -104)), rHip=J((-6, 0, 6)), lHip=J((-8, 0, -6)))
    body_key(m, 2.8, "out", 10, 0, 0, hips=top, drop=-0.6, neck=(26, 0, 0), rShoulder=J((100, 0, 108)),
             lShoulder=J((100, 0, -108)), rHip=J((-6, 0, 6)), lHip=J((-8, 0, -6)))
    soft(m, head=1.6, arms=1.6, head_damp=0.55, arm_damp=0.5)
    m.follow(("rHip", "lHip"), 1.6, 0.5)
    m.build()
    MOMENTS[m.name] = {"lift": 0.45, "burst": BURST}


# =====================================================================================================================
# Petrified

SET = 1.34  # the reach stops: stone


def stone(family):
    m = Motion("fallenStone" + family, 3.4, note="Petrified: a last reach as the stone climbs, slower and slower, set "
               "in stone, crumbles.", floor=True)
    down = family == "Down"
    lying(m, 0.0, family)
    if down:
        lying(m, 0.28, family, neck=(20, 0, 10))
        # up on the right arm, the left reaching out ahead and up, the head up: slowing as the stone takes it
        steps = [(0.62, 0.45), (0.92, 0.75), (1.16, 0.92), (SET, 1.0)]
        for t, u in steps:
            pitch = -90 + 34 * u
            body_key(m, t, "out" if t == SET else "smooth", pitch, 0, 4 * u, hips=(0, 0.0),
                     drop=2.0 - (0.5 + 0.02), neck=(20 + 26 * u, 0, 10 - 6 * u),
                     rShoulder=mix(SIDE_R, arm_world(pitch, 4, 12, 1, (0, 0.2, 0)), u),
                     lShoulder=mix(SIDE_L, arm_world(pitch, 132, 16, -1), u),
                     rHip=J((-2 - 30 * u, 0, 4)), lHip=J((-2 - 34 * u, 0, -4)))
    else:
        lying(m, 0.28, family, neck=(8, 0, -8))
        # the head and shoulders up, the left hand pressing the floor, the right arm up to the sky
        steps = [(0.62, 0.45), (0.92, 0.75), (1.16, 0.92), (SET, 1.0)]
        for t, u in steps:
            pitch = 88 - 40 * u
            body_key(m, t, "out" if t == SET else "smooth", pitch, 0, -4 * u, hips=(0, 0.0), drop=1.48,
                     neck=(8 - 30 * u, 0, -8 + 4 * u), rShoulder=mix(BACK_R, arm_world(pitch, 176, 8, 1), u),
                     lShoulder=mix(BACK_L, arm_world(pitch, -10, 30, -1, (0, 0.15, 0)), u),
                     rHip=J((2 + 40 * u, 0, 5)), lHip=J((-4 + 46 * u, 0, -5)))
    # set: held exactly, until it crumbles (nothing breathes in stone)
    hold_pose = m.sample(SET)
    m.build()
    MOMENTS[m.name] = {"climb": 0.0, "set": SET, "crumble": 2.3}
    return hold_pose


# =====================================================================================================================
# Shattered

RISEN = 1.2


def glass(family):
    m = Motion("fallenGlass" + family, 2.8, note="Shattered: drawn up onto the knees (or sat up) as it turns to glass, "
               "a last look, shatters.", floor=True)
    down = family == "Down"
    lying(m, 0.0, family)
    if down:
        # drawn up about the knees as if lifted by the chest, the legs folding under it
        kneel_key(m, 0.5, "sine", lean=-70, head=-10, hips=(0, 0.0), rShoulder=J((40, 0, 10)), lShoulder=J((38, 0, -10)))
        kneel_key(m, 0.9, "sine", lean=-32, head=-30, hips=(0, 0.0), rShoulder=J((12, 0, 8)), lShoulder=J((10, 0, -8)))
        kneel_key(m, RISEN, "out", lean=-6, head=-26, hips=(0, 0.0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
        kneel_key(m, 1.42, "smooth", lean=-6, head=-26, hips=(0, 0.0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
        kneel_key(m, 1.62, "sine", lean=-4, head=-12, hips=(0, 0.0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
        kneel_key(m, 2.8, "smooth", lean=-4, head=-12, hips=(0, 0.0), rShoulder=J((4, 0, 8)), lShoulder=J((4, 0, -8)))
    else:
        # drawn up to sit, the back straightening, the head bowed, the arms hanging to the floor
        sit_key(m, 0.5, "sine", lean=60, head=-6, hips=(0, 0.0), rShoulder=J((-10, 0, 20)), lShoulder=J((-10, 0, -20)))
        sit_key(m, 0.9, "sine", lean=22, head=-24, hips=(0, 0.0), rShoulder=J((0, 0, 14)), lShoulder=J((0, 0, -14)))
        sit_key(m, RISEN, "out", lean=4, head=-26, hips=(0, 0.0), rShoulder=J((4, 0, 12)), lShoulder=J((4, 0, -12)))
        sit_key(m, 1.42, "smooth", lean=4, head=-26, hips=(0, 0.0), rShoulder=J((4, 0, 12)), lShoulder=J((4, 0, -12)))
        sit_key(m, 1.62, "sine", lean=6, head=-12, hips=(0, 0.0), rShoulder=J((4, 0, 12)), lShoulder=J((4, 0, -12)))
        sit_key(m, 2.8, "smooth", lean=6, head=-12, hips=(0, 0.0), rShoulder=J((4, 0, 12)), lShoulder=J((4, 0, -12)))
    m.build()
    MOMENTS[m.name] = {"glass": 0.0, "look": 1.42, "shatter": 1.86}


# =====================================================================================================================
# Ash to Ash

GIVE = 0.92


def ash(family):
    m = Motion("fallenAsh" + family, 3.0, note="Ash to Ash: a last try to get up, trembling, the arms give, sinking back "
               "as it crumbles.", floor=True)
    down = family == "Down"
    lying(m, 0.0, family)
    if down:
        # pushed up on both arms, the chest off the floor, the head up, a knee drawn up under it
        lying(m, 0.2, family, neck=(20, 0, 10))
        PUSH_R = arm_world(-54, 4, 14, 1, (0, 0.25, 0))
        PUSH_L = arm_world(-54, 4, 14, -1, (0, 0.25, 0))
        body_key(m, 0.62, "out", -54, 0, 3, hips=(0, 0.0), drop=1.48, neck=(34, 0, 4), rShoulder=PUSH_R,
                 lShoulder=PUSH_L, rHip=J((14, 0, 6), (0, 0.4, 0)), lHip=J((-36, 0, -4)))
        body_key(m, GIVE - 0.04, "smooth", -50, 0, 4, hips=(0, 0.0), drop=1.48, neck=(36, 0, 4), rShoulder=PUSH_R,
                 lShoulder=PUSH_L, rHip=J((20, 0, 6), (0, 0.4, 0)), lHip=J((-36, 0, -4)))
        # the arms give: the chest drops, then sinks to the floor as it crumbles
        body_key(m, GIVE + 0.12, "in", -74, 0, 4, hips=(0, 0.0), drop=1.48, neck=(14, 0, 8),
                 rShoulder=arm_world(-74, 20, 30, 1), lShoulder=arm_world(-74, 16, 30, -1), rHip=J((6, 0, 6), (0, 0.2, 0)),
                 lHip=J((-16, 0, -4)))
        prone_key(m, 1.7, "sine", neck=(8, 0, 12), rShoulder=J((60, 0, 40)), lShoulder=J((56, 0, -40)),
                  legs=dict(rHip=J((-2, 0, 6)), lHip=PRONE_LEGS["lHip"]))
        prone_key(m, 3.0, "sine", neck=(6, 0, 12), rShoulder=J((60, 0, 42)), lShoulder=J((56, 0, -42)))
    else:
        # sitting up, the right arm reaching out ahead, the left propping behind
        lying(m, 0.2, family, neck=(8, 0, -8))
        body_key(m, 0.62, "out", 42, 0, -3, hips=(0, 0.0), drop=1.5, neck=(-10, 0, -4),
                 rShoulder=arm_world(42, 96, 8, 1), lShoulder=arm_world(42, -24, 26, -1, (0, 0.15, 0)),
                 rHip=J((46, 0, 5)), lHip=J((40, 0, -5)))
        body_key(m, GIVE - 0.04, "smooth", 38, 0, -4, hips=(0, 0.0), drop=1.5, neck=(-14, 0, -4),
                 rShoulder=arm_world(38, 102, 8, 1), lShoulder=arm_world(38, -24, 26, -1, (0, 0.15, 0)),
                 rHip=J((50, 0, 5)), lHip=J((44, 0, -5)))
        body_key(m, GIVE + 0.12, "in", 62, 0, -4, hips=(0, 0.0), drop=1.5, neck=(-4, 0, -6),
                 rShoulder=arm_world(62, 70, 12, 1), lShoulder=arm_world(62, -10, 30, -1), rHip=J((28, 0, 5)),
                 lHip=J((24, 0, -5)))
        supine_key(m, 1.7, "sine", neck=(12, 0, -8), rShoulder=J((40, 0, 30)), lShoulder=BACK_L, legs=SUPINE_LEGS)
        supine_key(m, 3.0, "sine", neck=(10, 0, -8), rShoulder=J((36, 0, 32)), lShoulder=BACK_L)
    shiver(m, 0.55, GIVE + 0.05, {"root": (1.2, 0.4, 0.8), "neck": (1.4, 0.8, 0.6), "rShoulder": (2.4, 0, 1.4),
                                  "lShoulder": (2.4, 0, 1.4)}, amount=1.0, hz=12)
    soft(m, head=2.6, arms=2.4)
    m.build()
    MOMENTS[m.name] = {"effort": 0.2, "give": GIVE, "grey": 0.6, "crumble": 1.15}


for fam in ("Down", "Up"):
    strings(fam)
    crows(fam)
    stone(fam)
    glass(fam)
    ash(fam)

for _name, _clip in list(MOMENTS.items()):
    from motion import MOTIONS

    _clip["length"] = MOTIONS[_name].length

import deaths  # noqa: E402

deaths.write_timing(MOMENTS)
