"""Looping dances, each copied from its reference (art/refs/emotes/<clip>.toml): the source, the segment
copied, its tempo and the beats the keys below land on.

Dances keep time with one another in the game (a loop starts on the server's beat), and each loop is a whole
number of beats of its own song's tempo, so the owner can put the right music under it.
"""

import math

from animlib import J
from emotes import mocap
from emotes.kit import Clock, beats, reach
from motion import Motion


def _close_turn(m):
    """A loop whose angles end on another spelling of the start (a turn on the spot carries the X-Y-Z angles over
    to their other branch, x+180, 180-y, z+180, or whole turns on): the loop would spin back to the first key's
    spelling at the seam. A key at the very end, the first pose spelt the way the last key is, carries it on round
    instead (the same rotation, so nothing jumps when the loop starts again). The angles are unwrapped first (as
    build does), so the last key is where the loop really ends up."""
    if m.unwrap:
        m._unwrap()
    for channel in m.channels.values():
        first, last = channel.keys[0][1], channel.keys[-1][1]
        x, y, z = first[:3]
        best = None
        for spelt in ((x, y, z), (x + 180.0, 180.0 - y, z + 180.0)):
            near = [spelt[a] + 360.0 * round((last[a] - spelt[a]) / 360.0) for a in range(3)]
            gap = sum((near[a] - last[a]) ** 2 for a in range(3))
            if best is None or gap < best[0]:
                best = (gap, near)
        near = best[1]
        if any(abs(near[a] - first[a]) > 1e-6 for a in range(3)):
            end = first.copy()
            end[:3] = near
            channel.add(m.length, end, "smooth")


# Bye Bye Bye (clip puppetPop, item emote_puppet_pop) ------------------------------------------------------
# The chorus routine of the 2000 music video (choreography by Darrin Henson), as the 2024 trend dances it:
# "hey" arm flicks, the arms crossed at the face and flung open, the head tilt, the hands pulled to the chest
# and pushed out palms first (bye, bye, bye) and spread wide, then hands on the hips with knee pops and a
# look over the shoulder, the wide-stance bounce, and the swing up to the raised fist with stomping knees.
# Motion-captured (2026-10-17, owner's note: real weight, fluid legs, arms not pulled in) from the mirrored
# front-facing breakdown (refs: puppetPop.toml, mocap/puppetPop.json), 4.00-10.94 s at 15 frames a second,
# 173 bpm: 20 beats of the routine, then two beats easing home into the first pose.
B = beats(173)
clock = Clock(4.0, 173)
at = clock.at
bye = Motion("puppetPop", 22 * B, loop=True, note="Bye Bye Bye: the chorus routine (arm flicks, palms out, hips, the fist).", unwrap=True)
mocap.capture(bye, "puppetPop", clock.start, 0.0, at(4.0 + 20 * B))
bye.build()

# The Classic (clip theClassic, item emote_the_classic) ---------------------------------------------------------
# Fortnite's Default Dance, the game's own animation filmed on green screen (refs: theClassic.toml,
# mocap/theClassic.json, 10 frames a second over 0-7.2 s): the arms pumping across the body by turns as the feet
# step, the elbows rolling, the hands thrown up by the head, the arms swinging down and back, the hand on the hip
# with the thumb out, a point. The whole routine (0.3-5.6 s, up to the point; after it the arms fold back across
# the chest, the game's outro) at 100 bpm, then 0.7 s easing home into its first pose.
clock = Clock(0.3, 100)
at = clock.at
classic = Motion("theClassic", 10 * beats(100), loop=True, note="Fortnite's Default Dance: the pumping arms, the "
                 "rolls, the hands up, the swing, the thumb.", unwrap=True, floor=True)
mocap.capture(classic, "theClassic", clock.start, 0.0, at(5.6))
classic.build()

# Take the L (clip takeTheL, item emote_take_the_l) ---------------------------------------------------------
# Fortnite's Take the L, the game's own animation filmed on green screen (refs: takeTheL.toml, mocap/takeTheL.json,
# 10 frames a second over 0-2.4 s): the right hand up at the forehead in an L the whole time, hopping from foot
# to foot, the free leg kicked out to the side on every other hop. Its cycle is 0.8 s (a kick each way), and it
# loops as the game's does: two cycles, 4 beats at 150 bpm, the last frame flowing back into the first.
take_l = Motion("takeTheL", 4 * beats(150), loop=True, note="Fortnite's Take the L: the L at the forehead, hopping "
                "foot to foot, kicking out.", unwrap=True, floor=True)
mocap.capture(take_l, "takeTheL", 0.0, 0.0, 1.5)
take_l.build()

# Bounce Pump (clip bouncePump, item emote_bounce_pump) -----------------------------------------------------
# Fortnite's Orange Justice, the game's own animation filmed on green screen (refs: bouncePump.toml,
# mocap/bouncePump.json, 10 frames a second over 2.0-9.1 s): the arms swung low and across the body as a leg
# swings out, side to side and bouncing, the hands thrown up and shaken, the arms crossed and pumped at the
# waist, the wide low step. The routine repeats every 6.5 s (source 2.3 s matches 8.8 s): 16 beats at 148 bpm.
clock = Clock(2.3, 148)
at = clock.at
pump = Motion("bouncePump", 16 * beats(148), loop=True, note="Fortnite's Orange Justice: low swings across the body, "
              "the leg out, hands up, the crossed pump.", unwrap=True, floor=True)
mocap.capture(pump, "bouncePump", clock.start, 0.0, at(8.7))
pump.build()

# Bunny Ears (clip bunnyEars, item emote_bunny_ears) --------------------------------------------------------
# Caramelldansen (the 2008 anime meme dance), danced by a real dancer from the front (refs: bunnyEars.toml,
# mocap/bunnyEars.json, 15 frames a second over 4.0-7.2 s): both hands up on the head, flapping like ears on every
# beat, the hips swaying side to side over two. At the song's 165 bpm, 4 beats loop (from 4.2 s, the first tracked
# frame being off), the last frame flowing back into the first.
clock = Clock(4.2, 165)
at = clock.at
bunny = Motion("bunnyEars", 4 * beats(165), loop=True, note="Caramelldansen: hands on the head flapping like ears, "
               "the hips swaying.", unwrap=True, floor=True)
mocap.capture(bunny, "bunnyEars", clock.start, 0.0, at(4.2 + 4 * beats(165) - 1 / 15))
bunny.build()

# Jackpot Shuffle (clip jackpotShuffle, item emote_jackpot_shuffle) -----------------------------------------
# Hakari's dance (Jujutsu Kaisen, to "Tuca Donka"), danced by a real dancer from the front (refs:
# jackpotShuffle.toml, mocap/jackpotShuffle.json, 10 frames a second over 0.3-5.8 s): feet planted wide, both
# fists raised over the head, the hips swung side to side under them with a little double bounce. The sway from
# 0.3 s comes back to the same pose at 3.0 s; that stretch loops (7 beats at 150 bpm). The tutorial's second
# move, arms held out in front, is nearly still and left out.
clock = Clock(0.3, 150)
at = clock.at
jackpot = Motion("jackpotShuffle", 7 * beats(150), loop=True, note="Hakari's dance: fists up over the head, the hips "
                 "swung side to side, a double bounce.", unwrap=True, floor=True)
mocap.capture(jackpot, "jackpotShuffle", clock.start, 0.0, at(3.0))
jackpot.build()

# Rat Dance (clip ratDance, item emote_rat_dance) -----------------------------------------------------------
# The Rat Dance trend (to Joyful's "Chess Type Beat"), danced at speed by a real dancer from the front (refs:
# ratDance.toml, mocap/ratDance.json, 15 frames a second over 11.2-14.4 s, the tutorial's "now speed it up"): the
# hands pulled up to the chest like a rat's paws and flicked, the cross-step, the wide bouncing step. It repeats
# every 1.13 s, two beats at 106 bpm; the cleanest repeat (from 13.2 s) loops.
clock = Clock(13.2, 106)
at = clock.at
rat = Motion("ratDance", 2 * beats(106), loop=True, note="The Rat Dance: paws at the chest, the cross-step, the wide "
             "bounce.", unwrap=True, floor=True)
mocap.capture(rat, "ratDance", clock.start, 0.0, at(13.2 + 2 * beats(106) - 1 / 15))
rat.build()

# Goal Celebration (clip goalCelebration, item emote_goal_celebration) --------------------------------------
# Cristiano Ronaldo's "SIUUU" (refs: goalCelebration.toml): the poses from a close shot of it at Real Madrid
# (about 4x slow motion), the timing at real speed. Three quick steps turning away, the take-off, a half turn in the
# air with the arms swung up, and the landing facing front again, the feet planted wide, the knees bent, the arms
# thrust down and back, the chest out and the head up for the shout, held. Keyed: a body in the air turning has no
# floor for the motion capture to stand it on.
goal = Motion("goalCelebration", 3.0, note="Ronaldo's SIUUU: steps turning away, a half turn in the air, the wide "
              "landing, arms thrust down and back, the shout.")
REST_R, REST_L = J((4, 0, 4)), J((4, 0, -4))
STAND_R, STAND_L = J((0, 0, 2)), J((0, 0, -2))
WIDE_R, WIDE_L = J((-4, 0, 24), (0, 0.28, 0)), J((-4, 0, -24), (0, 0.28, 0))  # knees bent: the legs slide up
DEEP_R, DEEP_L = J((-4, 0, 26), (0, 0.36, 0)), J((-4, 0, -26), (0, 0.36, 0))
THRUST_R, THRUST_L = J((-34, 0, 26), (0, 0.06, 0)), J((-34, 0, -26), (0, 0.06, 0))  # down, back and out
goal.key(0.0, "smooth", floor=True, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=REST_R, lShoulder=REST_L,
         rHip=STAND_R, lHip=STAND_L)
# the steps, turning away from the front
for t, yaw, lead in ((0.2, 55, 1), (0.4, 115, -1), (0.58, 172, 1)):
    up = J((38, 0, 2 * lead), (0, 0.22, -0.05))
    goal.key(t, "smooth", floor=True, root=(-6, yaw, 0), neck=(-4, 0, 0),
             rShoulder=J((-24 * lead, 0, 8)), lShoulder=J((24 * lead, 0, -8)),
             rHip=up if lead > 0 else STAND_R, lHip=up if lead < 0 else STAND_L)
# the take-off: low on both feet, the arms swung back
goal.key(0.74, "in", floor=True, root=(-14, 180, 0), neck=(-6, 0, 0), rShoulder=J((-48, 0, 14)),
         lShoulder=J((-48, 0, -14)), rHip=J((-6, 0, 6), (0, 0.32, 0)), lHip=J((-6, 0, -6), (0, 0.32, 0)))
# in the air: up with the arms swung over the head, the half turn, coming down with them opening out
goal.key(0.96, "out", offset=(0, 1.55, 0), root=(4, 268, 0), neck=(10, 0, 0), rShoulder=J((150, 0, 36), (0, 0.12, 0)),
         lShoulder=J((150, 0, -36), (0, 0.12, 0)), rHip=J((34, 0, 8), (0, 0.18, 0)), lHip=J((12, 0, -6)))
goal.key(1.14, "in", offset=(0, 0.7, 0), root=(2, 340, 0), neck=(8, 0, 0), rShoulder=J((70, 0, 70)),
         lShoulder=J((70, 0, -70)), rHip=J((6, 0, 18)), lHip=J((6, 0, -18)))
# the landing, wide, and the shout
goal.key(1.26, "snap", floor=True, root=(-4, 360, 0), neck=(4, 0, 0), rShoulder=THRUST_R, lShoulder=THRUST_L,
         rHip=WIDE_R, lHip=WIDE_L)
goal.key(1.42, "smooth", floor=True, root=(7, 360, 0), neck=(18, 0, 0), rShoulder=THRUST_R, lShoulder=THRUST_L,
         rHip=DEEP_R, lHip=DEEP_L)
goal.key(2.3, "smooth", floor=True, root=(8, 360, 0), neck=(20, 0, 0), rShoulder=J((-36, 0, 27), (0, 0.06, 0)),
         lShoulder=J((-36, 0, -27), (0, 0.06, 0)), rHip=DEEP_R, lHip=DEEP_L)
# straightening up
goal.key(2.65, "smooth", floor=True, root=(0, 360, 0), neck=(4, 0, 0), rShoulder=J((-6, 0, 10)),
         lShoulder=J((-6, 0, -10)), rHip=J((0, 0, 8), (0, 0.06, 0)), lHip=J((0, 0, -8), (0, 0.06, 0)))
goal.key(3.0, "smooth", floor=True, root=(0, 360, 0), neck=(0, 0, 0), rShoulder=REST_R, lShoulder=REST_L,
         rHip=STAND_R, lHip=STAND_L)
goal.follow(("rShoulder", "lShoulder"), 3.2, 0.62)
goal.follow("neck", 2.6, 0.7)
goal.build()

# Boat Aura (clip boatAura, item emote_boat_aura) -----------------------------------------------------------
# "Aura farming": the boy on the bow of a Pacu Jalur racing boat (Riau, 2025), dancing calm and deadpan while the
# boat surges (refs: boatAura.toml). The moves and their order from a front-on tutorial of it, keyed (its frames
# are too small to track well): the right hand held out, the left sweeping round under it; the fists rolling over
# each other, carried side to side; the right arm swung down and back like a paddle; flung up and out at the sky;
# a kiss blown off the fingers; both arms out, the left bent across. All the while the feet stay set wide on the
# bow and the body rides it: rocking side to side, the knees giving on every beat. 16 beats at 150 bpm.
B = beats(150)
boat = Motion("boatAura", 16 * B, loop=True, note="Aura farming on a racing boat's bow: the sweep, the rolling fists, "
              "the paddle, the sky, the kiss, arms out, riding the swell.")


def _ride(t):
    """The bow under him: a slow rock side to side over 8 beats, the knees giving on each beat."""
    phase = 2 * math.pi * t / (8 * B)
    beat = 0.5 + 0.5 * math.cos(2 * math.pi * t / B)
    return (0.05 * math.sin(phase), -0.08 - 0.05 * (1 - beat), 0.0), 3.5 * math.sin(phase)


HELD = reach(1, (0.55, 0.2, -1.6), direction=(-0.1, 0.3, -1.0))  # the right hand held out, palm up
for i in range(4):  # the sweep: the left hand round under the held one, out and back
    t = i * B
    under = i % 2 == 0
    left = reach(-1, (0.45, -0.1, -1.4) if under else (-0.25, 0.05, -1.3),
                 direction=(0.7, 0.05, -0.7) if under else (0.2, 0.3, -0.9))
    boat.key(round(t, 4), "smooth", neck=(-3, 6, 0), rShoulder=HELD, lShoulder=left)
for i in range(4):  # the fists rolling over each other, carried left, right, right, left
    t = (4 + i) * B
    side = (-1, 1, 1, -1)[i] * 0.3
    over = 1 if i % 2 == 0 else -1
    boat.key(round(t, 4), "smooth", neck=(-2, -10 * side, 0),
             rShoulder=reach(1, (0.25 + side, 0.15 + 0.18 * over, -1.25), direction=(-0.6, 0.3, -0.75)),
             lShoulder=reach(-1, (-0.25 + side, 0.15 - 0.18 * over, -1.25), direction=(0.6, 0.3, -0.75)))
# the paddle: the right arm swung down and back, the body turning with it
boat.key(round(8 * B, 4), "out", neck=(-2, 8, 0), rShoulder=J((-42, 0, 10), (0, 0.05, 0)), lShoulder=J((26, 0, -10)))
boat.key(round(9 * B, 4), "smooth", neck=(-2, 4, 0), rShoulder=J((30, 0, 6)), lShoulder=J((-20, 0, -8)))
boat.key(round(9.5 * B, 4), "out", neck=(0, 6, 0), rShoulder=J((-38, 0, 10), (0, 0.05, 0)), lShoulder=J((22, 0, -10)))
# flung up and out at the sky, the eyes following it
boat.key(round(10.5 * B, 4), "out", neck=(16, -10, 0), rShoulder=J((168, 0, 24), (0, 0.18, 0)), lShoulder=J((8, 0, -10)))
boat.key(round(11.5 * B, 4), "smooth", neck=(18, -12, 0), rShoulder=J((170, 0, 26), (0, 0.18, 0)),
         lShoulder=J((8, 0, -10)))
# the kiss: the fingers to the lips, thrown out
boat.key(round(12.25 * B, 4), "in", neck=(2, 0, 0), rShoulder=reach(1, (0.15, 0.95, -0.85), direction=(-0.5, 0.6, -0.6)),
         lShoulder=J((8, 0, -10)))
boat.key(round(12.9 * B, 4), "out", neck=(4, -18, 0), rShoulder=J((96, 0, 58), (0, 0.08, -0.04)), lShoulder=J((8, 0, -10)))
# both arms out, the left bent across the chest, riding it
ARMS_OUT = {"rShoulder": J((14, 0, 84), (0, 0.06, 0)),
            "lShoulder": reach(-1, (0.25, 0.45, -0.75), direction=(1.0, 0.0, -0.25))}
boat.key(round(13.75 * B, 4), "smooth", neck=(0, -8, 0), **ARMS_OUT)
boat.key(round(15 * B, 4), "smooth", neck=(-2, -6, 0), **ARMS_OUT)
# (beat 16 = beat 0: back to the held hand)
for k in range(64):  # the ride: every quarter beat
    t = k * B / 4
    offset, roll = _ride(t)
    boat.key(round(t, 4), "smooth", offset=offset, root=(-2, 0, roll))
boat.follow(("rShoulder", "lShoulder"), 2.8, 0.66)
boat.follow("neck", 2.0, 0.75)
boat.plant(stance=0.32)
boat.build()

# Office Party (clip officeParty, item emote_office_party) --------------------------------------------------
# The "I Want You Back" workplace trend: offices dancing *NSYNC's "I Want You Back" to Brotherhood's choreography
# (refs: officeParty.toml, mocap/officeParty.json), copied from a mirrored tutorial at half speed (video 1.0-17.2 s,
# a frame every 0.2 s, so 0.1 s of the real routine; flipped back to the real sides): the arms swung open, the
# shoulder rolls, the turn on the spot with the back to the room, the arm pumped up, the wide stance with the arms
# out. The routine comes back to its own pose after 6.4 s (real 1.5 s matches 7.9 s), which loops.
clock = Clock(1.5)
at = clock.at
party = Motion("officeParty", 6.4, loop=True, note="The I Want You Back office trend: swings, shoulder rolls, the "
               "turn, the pump, arms out.", unwrap=True, floor=True)
mocap.capture(party, "officeParty", clock.start, 0.0, at(7.8))
_close_turn(party)
party.build()
