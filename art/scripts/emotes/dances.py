"""Looping dances, each copied from its reference (art/refs/emotes/<clip>.toml): the source, the segment
copied, its tempo and the beats the keys below land on.

Dances keep time with one another in the game (a loop starts on the server's beat), and each loop is a whole
number of beats of its own song's tempo, so the owner can put the right music under it.
"""

from animlib import J
from emotes.kit import Clock, akimbo, beats, raise_leg, reach
from motion import Motion

# Bye Bye Bye (clip puppetPop, item emote_puppet_pop) ------------------------------------------------------
# The chorus routine of the 2000 music video (choreography by Darrin Henson), as the 2024 trend dances it:
# "hey" arm flicks, the arms crossed at the face and flung open, the head tilt, the hands pulled to the chest
# and pushed out palms first (bye, bye, bye) and spread wide, then hands on the hips with knee pops and a
# look over the shoulder, the wide-stance bounce, and the swing up to the raised fist with stomping knees.
# Copied from the mirrored front-facing breakdown (refs: puppetPop.toml), 4.00-11.00 s, 173 bpm; the loop is
# 22 beats, the last two easing back into the first pose.
B = beats(173)
clock = Clock(4.0, 173)
at = clock.at
bye = Motion("puppetPop", 22 * B, loop=True, note="Bye Bye Bye: the chorus routine (arm flicks, palms out, hips, the fist).", unwrap=True)


def arms(r, l):
    return {"rShoulder": r, "lShoulder": l}


low_out = arms(J((34, 0, 44), (-0.08, 0.06, -0.08)), J((34, 0, -44), (0.08, 0.06, -0.08)))
flung = arms(J((8, 0, 76)), J((8, 0, -76)))
pulled = arms(reach(1, (0.5, 0.42, -0.72)), reach(-1, (-0.5, 0.42, -0.72)))
crossed = arms(reach(1, (-0.35, 0.95, -1.05), direction=(-0.55, 0.75, -0.6)),
               reach(-1, (0.35, 1.05, -1.15), direction=(0.55, 0.75, -0.6)))
t_pose = arms(J((4, 0, 88)), J((4, 0, -88)))
down_out = arms(J((4, 0, 38)), J((4, 0, -38)))
by_sides = arms(J((2, 0, 7)), J((2, 0, -7)))
together = arms(reach(1, (0.12, 0.62, -0.88)), reach(-1, (-0.12, 0.62, -0.88)))
pushed = arms(J((86, 0, 9)), J((86, 0, -9)))
palms_up = arms(reach(1, (1.3, 1.6, -0.75), direction=(0.2, 1.0, -0.45)),
                reach(-1, (-1.3, 1.6, -0.75), direction=(-0.2, 1.0, -0.45)))
spread = arms(J((108, 0, 46)), J((108, 0, -46)))
wide = arms(J((22, 0, 80)), J((22, 0, -80)))
hips = arms(akimbo(1), akimbo(-1))
loose = arms(reach(1, (1.05, -0.45, -0.45)), reach(-1, (-1.05, -0.45, -0.45)))
fist_high = reach(-1, (-0.7, 2.55, -0.35))
fist_head = reach(-1, (-0.85, 1.85, -0.45))
fist_shoulder = reach(-1, (-1.0, 1.15, -0.55))
swing_low = J((22, 0, -62))
swing_over = J((168, 0, -26), (0, 0.18, 0))

# "hey": the flicks out from bent elbows, in to the chest, out again, crossed at the face, flung wide.
bye.key(at(4.00), offset=(0, -0.08, 0), root=(-2, 0, 0), neck=(-2, 0, 0), **low_out)
bye.key(at(4.13), "snap", offset=(0, -0.02, 0), root=(0, 0, 0), neck=(2, 0, 0), **flung)
bye.key(at(4.25), "snap", offset=(0, -0.06, 0), root=(-3, 0, 0), neck=(-2, 0, 0), **pulled)
bye.key(at(4.38), "snap", offset=(0, -0.02, 0), root=(0, 0, 0), neck=(2, 0, 0), **flung)
bye.key(at(4.50), "out", offset=(0, -0.06, 0), root=(-2, 0, 0), neck=(-4, 0, 0), **crossed)
bye.key(at(4.63), offset=(0, -0.03, 0), root=(0, 0, 0), neck=(0, 0, 0),
        **arms(J((62, 0, 58)), J((62, 0, -58))))
bye.key(at(4.75), "snap", offset=(0, 0.0, 0), root=(1, 0, 0), neck=(3, 0, 0), **t_pose)
bye.key(at(4.88), offset=(0, -0.02, 0), root=(1, 0, 0), neck=(2, 0, 0), **arms(J((4, 0, 80)), J((4, 0, -80))))
bye.key(at(5.00), "sine", offset=(0, -0.05, 0), root=(0, 0, 0), neck=(0, 0, 0), **down_out)
# the head tilt, arms hanging
bye.key(at(5.25), "sine", offset=(0, -0.06, 0), root=(0, 0, 3), neck=(0, 0, 14), **by_sides)
bye.key(at(5.38), offset=(0, -0.06, 0), root=(0, 0, 3), neck=(0, 6, 16), **by_sides)
# bye, bye, bye: hands to the chest, pushed out palms first, up by the face, spread wide
bye.key(at(5.50), "out", offset=(0, -0.04, 0), root=(-2, 0, 0), neck=(-4, 0, 0), **together)
bye.key(at(5.63), "snap", offset=(0, -0.02, 0.04), root=(2, 0, 0), neck=(2, 0, 0), **pushed)
bye.key(at(5.75), "snap", offset=(0, -0.04, 0), root=(0, 0, 0), neck=(4, 0, 0), **palms_up)
bye.key(at(5.88), "out", offset=(0, -0.02, 0), root=(1, 0, 0), neck=(4, 0, 0), **spread)
for i, t in enumerate((6.00, 6.13, 6.25, 6.38)):  # held wide, bouncing on the eighths
    bye.key(at(t), "out", offset=(0, -0.11 if i % 2 == 0 else -0.03, 0), root=(1, 0, 0), neck=(6, 0, 0),
            **arms(J((22, 0, 80 + 4 * (i % 2))), J((22, 0, -80 - 4 * (i % 2)))))
bye.key(at(6.50), "sine", offset=(0, -0.08, 0), root=(-1, 0, 0), neck=(0, 0, 0), **down_out)
# hands on the hips, knee pops, the look over the left shoulder with the hips swaying, a lean
bye.key(at(6.75), "out", offset=(0, -0.1, 0), root=(-2, 0, 0), neck=(0, 0, 0), **hips)
bye.key(at(7.13), offset=(-0.12, -0.16, 0), root=(-2, 10, 5), neck=(0, 34, 0), **hips)
bye.key(at(7.25), "sine", offset=(0.1, -0.14, 0), root=(-2, 12, -5), neck=(-2, 42, 0), **hips)
bye.key(at(7.38), "sine", offset=(-0.08, -0.16, 0), root=(-2, 10, 4), neck=(-2, 40, 0), **hips)
bye.key(at(7.63), "sine", offset=(0, -0.12, 0), root=(-2, 0, 0), neck=(0, 6, 0), **hips)
bye.key(at(7.88), "sine", offset=(0.06, -0.18, 0), root=(-3, -4, -6), neck=(2, -4, 4), **hips)
# the wide bounce: down on every beat, arms loose and bent at the sides
for i in range(6):
    t = 8.25 + i * B / 2
    bye.key(at(t), "out" if i % 2 == 0 else "sine", offset=(0, -0.24 if i % 2 == 0 else -0.12, 0),
            root=(-6 if i % 2 == 0 else -3, 0, 0), neck=(-6 if i % 2 == 0 else 0, 0, 0), **loose)
# the swing up to the raised fist (left), knees stomping
bye.key(at(9.25), "out", offset=(0.04, -0.14, 0), root=(-2, 8, -3), neck=(0, 10, 0),
        rShoulder=loose["rShoulder"], lShoulder=swing_low)
bye.key(at(9.38), "out", offset=(0.06, -0.08, 0), root=(2, 14, -4), neck=(6, 24, 0),
        rShoulder=J((10, 0, 24)), lShoulder=swing_over)
bye.key(at(9.75), "snap", offset=(0, -0.16, 0), root=(0, 6, 3), neck=(2, 14, 0),
        rShoulder=loose["rShoulder"], lShoulder=fist_high)
for i, t in enumerate((10.00, 10.13, 10.25, 10.38)):
    bye.key(at(t), "snap" if i % 2 == 0 else "sine", offset=(0, -0.2 if i % 2 == 0 else -0.12, 0), root=(-2, 4, 2),
            neck=(0, 10, 0), rShoulder=loose["rShoulder"], lShoulder=fist_head if i % 2 == 0 else fist_high)
bye.key(at(10.50), "out", offset=(0, -0.18, 0), root=(-3, 2, 0), neck=(-2, 6, 0),
        rShoulder=loose["rShoulder"], lShoulder=fist_shoulder)
bye.key(at(10.63), "out", offset=(0.06, -0.08, 0), root=(2, 14, -4), neck=(6, 24, 0),
        rShoulder=J((10, 0, 24)), lShoulder=swing_over)
bye.key(at(10.88), "snap", offset=(0, -0.16, 0), root=(0, 6, 3), neck=(2, 14, 0),
        rShoulder=loose["rShoulder"], lShoulder=fist_high)
bye.key(at(11.00), offset=(0, -0.14, 0), root=(0, 4, 2), neck=(0, 10, 0),
        rShoulder=loose["rShoulder"], lShoulder=fist_high)
# two beats to come home into the first flick
bye.key(at(11.35), "sine", offset=(0, -0.06, 0), root=(-1, 0, 0), neck=(-2, 0, 0), **by_sides)

# Feet: ordinary stance for the flicks and the push; the right foot steps out into the wide stance while its
# knee pops (7.0), the left at 7.13; both come back in on the last beats.
narrow, wide_both = 0.08, (0.42, 0.42)
bye.plant(at(4.0) - 0.01, at(7.0), stance=narrow)
bye.plant(at(7.0), at(7.1), stance=(0.42, 0.08))
bye.plant(at(7.1), at(11.2), stance=wide_both)
bye.plant(at(11.2), at(11.3), stance=(0.08, 0.42))
bye.plant(at(11.3), 22 * B + 0.01, stance=narrow)
raise_leg(bye, "rHip", at(11.12), at(11.2), at(11.21), at(11.28), J((24, 0, 6), (0, 0.26, -0.04)))
raise_leg(bye, "lHip", at(11.22), at(11.3), at(11.31), at(11.38), J((24, 0, -6), (0, 0.26, -0.04)))
pop = J((34, 0, 0), (0, 0.32, -0.08))
pop_l = J((34, 0, 0), (0, 0.32, -0.08))
raise_leg(bye, "lHip", at(6.78), at(6.88), at(6.9), at(6.98), pop_l)
raise_leg(bye, "rHip", at(6.9), at(7.0), at(7.02), at(7.12), J((26, 0, 10), (0, 0.3, -0.06)))
raise_leg(bye, "lHip", at(7.02), at(7.1), at(7.11), at(7.2), J((20, 0, -10), (0, 0.24, 0)))
raise_leg(bye, "lHip", at(7.42), at(7.5), at(7.52), at(7.6), pop_l)
raise_leg(bye, "rHip", at(7.55), at(7.63), at(7.65), at(7.74), pop)
raise_leg(bye, "rHip", at(7.92), at(8.0), at(8.05), at(8.18), J((-38, 0, 6), (0, 0.22, 0.12)))  # the kick back
raise_leg(bye, "lHip", at(8.66), at(8.75), at(8.77), at(8.86), J((40, 0, -14), (0, 0.32, -0.1)))
raise_leg(bye, "rHip", at(8.8), at(8.88), at(8.9), at(8.99), J((40, 0, 14), (0, 0.32, -0.1)))
for side, t in (("rHip", 9.25), ("rHip", 9.38), ("lHip", 10.0), ("rHip", 10.13), ("lHip", 10.25), ("rHip", 10.38),
                ("rHip", 10.63), ("lHip", 10.75)):
    s = 1 if side == "rHip" else -1
    raise_leg(bye, side, at(t) - 0.09, at(t), at(t) + 0.02, at(t) + 0.1, J((48, 0, 10 * s), (0, 0.36, -0.12)))
bye.follow("neck", 5.0, 0.62).follow(("rShoulder", "lShoulder"), 7.0, 0.58)
bye.build()
