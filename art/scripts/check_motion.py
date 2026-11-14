"""The motion report: the nine traits of motion that looks made by a person (docs/agent-memory/animation-bar.md),
measured as numbers on the clips the game plays. Tool 1 of the animation and cutscene plan
(docs/handoff/animation-cutscene-plan-2026-11-13.md). Calibrated 2026-11-14 on RoleMuerto (the bar, must pass)
against RoleAce (must fail); the limits, the numbers and which traits separate the two are in that plan, under Tool 1.

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/check_motion.py <what> [options]
    (any Python with numpy does; it needs no Blender scene and writes nothing but the --json file you name)

What to check (any mix; a clip is checked once):
    <name> ...        a clip (RoleMuerto_self, bow), or a whole cutscene (RoleAce)
    --shot A[,B]      every actor clip of those cutscenes           --all      every cutscene
    --emotes          the 70 emotes                                  --movement the movement set (idle, walk, run ...)
    --lead            leave out the extras of a cutscene (slots everyone:N and extra:N)
    --list            the cutscenes and their clips
Output:
    One line per clip: PASS, FAIL or info (an extra's faults are only noted; --strict-extras fails them), the clip, its
    length, a number for each trait, and the failing traits named after "<-". --detail adds, for each failing trait,
    why and where (seconds into the clip). --quiet prints failing clips only (with the detail). --worst N ranks the
    failing clips by how many traits fail. --table adds a Markdown table of the numbers, --json PATH writes them all.
    Exit code 1 when a clip that counts fails, 2 for a name it does not know, 0 otherwise (--no-fail: always 0).
    --frozen-ok A,B   clips the story keeps still (skips frozen and dead; FREEZE_OK below holds the standing ones)
    --selftest        measures made-up clips with known answers (run it after changing a measuring)

What it reads: the exported keys of src/shared/Cinema/Acting/<Shot>.luau (cutscene clips; the shot in Cinema/Shots
gives each clip its slot and the time window it is shown; a clip no actor plays is skipped) and of
src/shared/Anim/Clips (emotes, movement), played back on the game's own curve (cubic.py) at 60 a second. Both are
committed, generated files: it reads what the game plays, and never opens Animations.blend. Rebuild and export a clip
first (run_anims.py --add, run_cinema.py --export) or the report measures the old one.

The traits. The upper body is the torso (the root joint), the neck and the two shoulders; the legs are planned by
footwork.py and are left out. A move is a stretch where a joint turns faster than 6 degrees a second (nothing smaller
counts: Anim/Life breathes and glances at run time), cut where it turns back. A big move is over 40 degrees (or the
body's offset over 1.5 studs).
    frozen        the longest span in which no upper-body joint moves more than 0.6 degrees from where it began
    dead limb     the same for one joint on its own, the worst joint named. The whole-body span cannot tell a good
                  scene from a stiff one (the neck always drifts); one arm or the torso dead for a whole scene can
    glides        spans over 0.4 s where a joint (or the body offset) moves at a speed that varies by under 15%
    snap/hold     per big move: how long it takes (10 to 90%) and the hold after it (it rests within 0.6 s, then stays
                  within 2 degrees); a big move over 0.35 s with no hold is "slow"
    anticipation  a big move is "wound up" when in the 0.3 s before it the joint was drawn back by 2 degrees and 5 to
                  50% of the move (a stroke as big as the move is the move before, not a wind-up)
    overshoot     info only: a big move passes the pose it settles in (by 2 degrees, under 60% of the move) and comes back
    symmetry      arms still together for 0.3 s (a held pose) and within 8 degrees of mirror images
    torso share   the torso (root joint plus body offset at 25 degrees a stud) as a share of all the turning of the
                  torso, neck and arms
    metronome     moves of one joint in one direction of one size (15%) at one interval (15%), in a row; and "same
                  timing": how many of one joint's moves take the same number of frames (one frame either way)
    overlap       after the torso turns or stops (6+ degrees), does the neck or an arm arrive 2 to 12 frames later
A loop repeats on purpose, so it is not judged on repeating (metronome, same timing, anticipation, snap, glides,
overlap). An emote may hold a mirrored pose (symmetry is not judged). The movement set is judged on freezing alone.
Each trait is judged only when there is enough of it to judge (LIMITS says how much); a failure is a number past its
limit. The report is a floor: failing it means the clip is not done, passing it does not make a clip good.
"""

import argparse
import json
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import cubic  # noqa: E402
import rbxsim  # noqa: E402

RATE = 60
UPPER = ("root", "neck", "rShoulder", "lShoulder")
JOINTS = UPPER + ("rHip", "lHip")
ACTING_DIR = os.path.join(ROOT, "src", "shared", "Cinema", "Acting")
SHOTS_DIR = os.path.join(ROOT, "src", "shared", "Cinema", "Shots")
COSMETICS = os.path.join(ROOT, "src", "shared", "Cosmetics.luau")

# How a move is found (not thresholds of the verdict): a joint turning faster than V_ROT degrees a second (or the
# body's offset faster than V_POS studs a second) is moving; gaps shorter than GAP samples inside a move are
# bridged; a move that turns back by REV_ABS degrees or REV_FRAC of its size is cut where it turned.
V_ROT, V_POS, GAP = 6.0, 0.5, 3
REV_ABS, REV_FRAC = 4.0, 0.25
BIG_ROT, BIG_POS = 40.0, 1.5  # the plan's "big move": over 40 degrees or 1.5 studs
HOLD_TOL = 2.0  # degrees a joint may drift while it is held
MOVE_MIN_ROT, MOVE_MIN_POS = 3.0, 0.15  # smaller than this is not a move

EVERYONES = ("wave", "point", "cheer", "laugh", "dance", "salute", "bow", "shrug", "facepalm", "highFive", "handshake")


# --- Quaternions (x, y, z, w) -------------------------------------------------------------


def qconj(q):
    return q * np.array([-1.0, -1.0, -1.0, 1.0])


def qmul(a, b):
    ax, ay, az, aw = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    bx, by, bz, bw = b[..., 0], b[..., 1], b[..., 2], b[..., 3]
    return np.stack(
        [
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        ],
        axis=-1,
    )


def rotvec(q):
    """The turn a unit quaternion makes as an axis times its angle, in degrees (the short way round)."""
    q = np.where(q[..., 3:4] < 0, -q, q)
    v = q[..., :3]
    s = np.linalg.norm(v, axis=-1, keepdims=True)
    angle = np.degrees(2.0 * np.arctan2(s, q[..., 3:4]))
    return np.where(s > 1e-9, v / np.maximum(s, 1e-9) * angle, v * (2.0 * 180.0 / math.pi))


def turn_between(a, b):
    """Degrees between two unit quaternions (or arrays of them, rowwise)."""
    d = np.abs(np.sum(a * b, axis=-1))
    return np.degrees(2.0 * np.arccos(np.clip(d, 0.0, 1.0)))


# --- Reading the clips ----------------------------------------------------------------------


class Sampled:
    """A clip played at RATE a second over [t0, t1]: a unit quaternion per joint per sample, the body's offset, and
    the slide of each joint, as the game's ClipPlayer would give them."""

    def __init__(self, name, clip, t0=0.0, t1=None):
        self.name, self.clip = name, clip
        length = float(clip["length"])
        t1 = length if t1 is None else min(float(t1), length)
        t0 = min(max(0.0, float(t0)), max(0.0, t1 - 1.0 / RATE))
        n = max(3, int(round((t1 - t0) * RATE)))
        self.times = np.minimum(t0 + np.arange(n + 1) / RATE, t1)
        self.t0, self.t1, self.n = t0, t1, n
        self.q, self.slide = {}, {}
        identity = np.tile(np.array([0.0, 0.0, 0.0, 1.0]), (n + 1, 1))
        for j in JOINTS:
            track = clip["joints"].get(j)
            if track is None:
                self.q[j] = identity
                continue
            period = rbxsim.period_of(clip, track["t"])
            quats = np.array(track["q"], float).reshape(len(track["t"]), 4)
            self.q[j] = cubic.evaluate(track["t"], quats, self.times, period, quat=True)
            if track.get("p"):
                pos = np.array(track["p"], float).reshape(len(track["t"]), 3)
                self.slide[j] = cubic.evaluate(track["t"], pos, self.times, period)
        off = clip.get("offset")
        if off:
            pos = np.array(off["p"], float).reshape(len(off["t"]), 3)
            self.offset = cubic.evaluate(off["t"], pos, self.times, rbxsim.period_of(clip, off["t"]))
        else:
            self.offset = np.zeros((n + 1, 3))
        self.loop = bool(clip.get("loop"))

    def time(self, i):
        return float(self.times[min(int(i), self.n)])


# --- Moves ----------------------------------------------------------------------------------


class Signal:
    """One thing that moves: a joint's turn (degrees) or the body's offset (studs), with what a move needs of it."""

    def __init__(self, name, kind, data):
        self.name, self.kind = name, kind
        self.is_rot = kind == "rot"
        self.data = data  # quaternions (n+1, 4) or positions (n+1, 3)
        if self.is_rot:
            self.inc = rotvec(qmul(data[1:], qconj(data[:-1])))
            self.v_move, self.v_glide = V_ROT, 10.0
            self.big, self.move_min = BIG_ROT, MOVE_MIN_ROT
            self.rev_abs = REV_ABS
        else:
            self.inc = np.diff(data, axis=0)
            self.v_move, self.v_glide = V_POS, 0.6
            self.big, self.move_min = BIG_POS, MOVE_MIN_POS
            self.rev_abs = 0.2
        self.speed = np.linalg.norm(self.inc, axis=1) * RATE  # per unit of time, between sample i and i + 1
        pad = np.pad(self.speed, 1, mode="edge")
        self.smooth = (pad[:-2] + pad[1:-1] + pad[2:]) / 3.0

    def disp(self, s, ks):
        """Where samples ks are, as a displacement from sample s (vectors; degrees as an axis-angle, or studs)."""
        if self.is_rot:
            return rotvec(qmul(self.data[ks], qconj(self.data[s])))
        return self.data[ks] - self.data[s]

    def dist(self, s, ks):
        return np.linalg.norm(self.disp(s, ks), axis=-1)


def runs_of(mask):
    out, start = [], None
    for i, m in enumerate(mask):
        if m and start is None:
            start = i
        elif not m and start is not None:
            out.append((start, i - 1))
            start = None
    if start is not None:
        out.append((start, len(mask) - 1))
    return out


def find_moves(sig):
    """The moves of a signal: [(s, e)] sample indices. A move is a stretch moving faster than the signal's floor,
    cut where the direction turns back."""
    mask = sig.smooth > sig.v_move
    runs = runs_of(mask)
    merged = []
    for a, b in runs:
        if merged and a - merged[-1][1] - 1 <= GAP:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))
    moves = []
    for a, b in merged:
        s, last = a, b + 1  # samples a .. b + 1 are the stretch
        for _ in range(64):
            if last - s < 2:
                break
            ks = np.arange(s, last + 1)
            disp = sig.disp(s, ks)
            d = np.linalg.norm(disp, axis=1)
            peak = np.maximum.accumulate(d)
            turned = peak - d > np.maximum(sig.rev_abs, REV_FRAC * peak)
            # a reversal that swings back past where the move began: progress along its first direction goes back
            by_p = np.zeros(len(ks), bool)
            started = np.where(d >= 0.6 * sig.move_min)[0]
            if len(started):
                dir0 = disp[started[0]] / max(d[started[0]], 1e-9)
                p = disp @ dir0
                pk = np.maximum.accumulate(p)
                leaving = np.vstack([sig.inc[s:last], np.zeros((1, disp.shape[1]))]) @ dir0
                by_p = (pk - p > np.maximum(sig.rev_abs, REV_FRAC * pk)) & (leaving < 0)
            hit = np.where(turned | by_p)[0]
            if len(hit) == 0:
                moves.append((s, int(s + np.argmax(d))))
                break
            k = hit[0]
            e = int(s + np.argmax(d[: k + 1]))
            if by_p[k]:
                e = min(e, int(s + np.argmax(p[: k + 1])))
            if e - s >= 2:
                moves.append((s, e))
            s = e if e > s else s + 1
    out = []
    for s, e in moves:
        size = float(sig.dist(s, np.array([e]))[0])
        if size >= sig.move_min and e - s >= 2:
            out.append((s, e))
    return out


def describe_move(sig, sm, s, e):
    """Everything the traits ask of one move: its size and how long it takes, the hold after, the pull before."""
    ks = np.arange(s, e + 1)
    d = sig.dist(s, ks)
    size = float(d[-1]) if d[-1] >= d.max() - 1e-9 else float(d.max())
    k10 = int(np.argmax(d >= 0.1 * size))
    k90 = int(np.argmax(d >= 0.9 * size))
    dur = max(1, k90 - k10) / RATE
    u = sig.disp(s, np.array([e]))[0]
    u = u / max(np.linalg.norm(u), 1e-9)
    # the hold after: the signal comes to rest within 0.6 s of the move's end (an overshoot is swung past and
    # settled first) and then stays within the hold tolerance of that rest pose
    tol = HOLD_TOL if sig.is_rot else 0.12
    hold = 0.0
    moving = sig.smooth[e:min(sm.n, e + int(round(0.6 * RATE)))] > sig.v_move
    for k in range(len(moving)):
        if not moving[k:k + 3].any():
            rest = e + k
            drift = sig.dist(rest, np.arange(rest, sm.n + 1))
            out_of = np.where(drift > tol)[0]
            hold = (out_of[0] if len(out_of) else len(drift)) / RATE
            break
    # the pull before: a move that is drawn back first begins at its farthest point back, so the signal stood
    # further along the move's direction a moment earlier. The farthest it was, in the 0.3 s before, is the pull.
    window = np.arange(max(0, s - int(round(0.3 * RATE))), s + 1)
    ahead = sig.disp(s, window) @ u
    back = float(max(0.0, ahead.max())) if len(window) > 1 else 0.0
    return {
        "name": sig.name, "s": s, "e": e, "t0": sm.time(s), "t1": sm.time(e), "size": size, "dur": dur,
        "hold": hold, "pull": back, "u": u, "mid": sm.time((s + e) // 2),
    }


# --- The traits ------------------------------------------------------------------------------

ACTING = ("root", "neck", "rShoulder", "lShoulder")  # what a scene acts with; the legs are planned by footwork.py
OFFSET_DEG = 25.0  # the body's offset counts toward the torso's share at this many degrees a stud

# The glide: a stretch that long, moving at least this fast, whose speed stays within this fraction of its mean.
GLIDE_SECONDS, GLIDE_VARIES = 0.4, 0.15
# The hold after a big move counts when it lasts this long; a big move slower than SLOW_MOVE with less is flagged.
SLOW_MOVE, HOLD_MIN = 0.35, 0.15
PULL_MIN = 2.0  # degrees (or 0.1 studs) of pull the other way in the 0.3 s before a big move
PULL_FRAC = (0.05, 0.5)  # ... and between these fractions of the move's size
OVERSHOOT_MIN = 2.0  # degrees past the rest pose before it comes back
SYMMETRIC = 8.0  # degrees the arms may be off mirror images and still be called mirrored
MIRROR_HOLD = 0.3  # seconds both arms stay still for that to be a held pose
METRO_SIZE, METRO_SAME, METRO_MIN = 8.0, 0.15, 3  # moves of 8+ degrees within 15% in size and interval, 3 or more
TORSO_MOVE = 6.0  # degrees the torso must turn for it to be a turn or a stop
LAG_FRAMES = (2, 12)  # the head and arms arrive this many frames after the torso stops


def trait_frozen(sm, sigs):
    """The longest span in which no upper-body joint moves more than 0.6 degrees from where the span began, and each
    joint's own longest."""
    n = sm.n + 1
    devs = {}
    for name in UPPER:
        q = sm.q[name]
        devs[name] = turn_between(q[:, None, :], q[None, :, :])
    worst = np.maximum.reduce(list(devs.values()))
    per = {}
    for name, dev in list(devs.items()) + [("all", worst)]:
        best = (0.0, 0, 0)
        for i in range(n):
            bad = np.where(dev[i, i:] > 0.6)[0]
            k = int(bad[0]) if len(bad) else n - i
            span = max(0, k - 1) / RATE
            if span > best[0]:
                best = (span, i, i + k - 1)
        per[name] = (best[0], sm.time(best[1]), sm.time(best[2]))
    joint = max(UPPER, key=lambda j: per[j][0])
    return {
        "frozen": per["all"][0], "frozen_at": per["all"][1:],
        "dead": per[joint][0], "dead_joint": joint, "dead_at": per[joint][1:],
        "frozen_by_joint": {j: per[j][0] for j in UPPER},
    }


def trait_glides(sm, sigs):
    """Spans over 0.4 s where a joint (or the body's offset) moves at a speed within 15% of its mean."""
    out = []
    need = int(round(GLIDE_SECONDS * RATE))
    for sig in sigs:
        if sig.name in ("rHip", "lHip"):
            continue
        sp = sig.smooth
        i, n = 0, len(sp)
        while i < n:
            if sp[i] < sig.v_glide:
                i += 1
                continue
            lo = hi = sp[i]
            total, j = sp[i], i
            while j + 1 < n and sp[j + 1] >= sig.v_glide:
                nl, nh = min(lo, sp[j + 1]), max(hi, sp[j + 1])
                mean = (total + sp[j + 1]) / (j - i + 2)
                if (nh - nl) / mean > GLIDE_VARIES:
                    break
                lo, hi, total, j = nl, nh, total + sp[j + 1], j + 1
            if j - i + 1 >= need:
                out.append({"name": sig.name, "t0": sm.time(i), "t1": sm.time(j + 1), "speed": total / (j - i + 1)})
                i = j + 1
            else:
                i += 1
    out.sort(key=lambda g: g["t0"])
    return {
        "glides": out,
        "glide_time": float(sum(g["t1"] - g["t0"] for g in out)),
        "glide_longest": max((g["t1"] - g["t0"] for g in out), default=0.0),
    }


def big_moves(moves):
    """The big moves of the acting joints and the body's offset."""
    out = []
    for name in ACTING + ("offset",):
        floor = BIG_POS if name == "offset" else BIG_ROT
        out += [m for m in moves[name] if m["size"] >= floor]
    return sorted(out, key=lambda m: m["t0"])


def trait_snap(sm, big):
    flagged = [m for m in big if m["dur"] > SLOW_MOVE + 1e-6 and m["hold"] < HOLD_MIN]
    durs = [m["dur"] for m in big]
    holds = [m["hold"] for m in big]
    return {
        "big": len(big), "slow_no_hold": flagged,
        "snap_median": float(np.median(durs)) if durs else 0.0,
        "hold_median": float(np.median(holds)) if holds else 0.0,
        "slow_share": len(flagged) / len(big) if big else 0.0,
    }


def pull_ok(m):
    """A pull-back before a move that is an anticipation: noticeable, and a fraction of the move (a stroke as big as
    the move itself is the move before, not a wind-up)."""
    floor = 0.1 if m["name"] == "offset" else PULL_MIN
    return max(floor, PULL_FRAC[0] * m["size"]) <= m["pull"] <= PULL_FRAC[1] * m["size"]


def trait_anticipation(sm, big):
    pulled = [m for m in big if pull_ok(m)]
    return {
        "anticipated": len(pulled), "anticipation_share": len(pulled) / len(big) if big else 1.0,
        "unanticipated": [m for m in big if m not in pulled],
    }


def trait_overshoot(sm, sigs, big):
    """A big move overshoots when the signal comes back from its farthest point to a rest pose within 0.5 s: the
    peak lies past where it settles by at least 2 degrees (0.1 studs) and by less than 60% of the move."""
    by_name = {s.name: s for s in sigs}
    over, flat = [], []
    window = int(round(0.5 * RATE))
    for m in big:
        sig = by_name[m["name"]]
        e = m["e"]
        last = min(sm.n, e + window)
        moving = sig.smooth[e:last] > sig.v_move
        rest = None
        for k in range(2, len(moving) - 3):
            if not moving[k:k + 4].any():
                rest = e + k
                break
        amount = 0.0
        if rest is not None:
            reached = float(sig.disp(m["s"], np.array([rest]))[0] @ m["u"])
            amount = max(0.0, m["size"] - reached)
        m["overshoot"] = amount
        floor = OVERSHOOT_MIN if sig.is_rot else 0.1
        (over if floor <= amount <= 0.6 * m["size"] else flat).append(m)
    return {"overshot": len(over), "overshoot_share": len(over) / len(big) if big else 1.0, "undershot": flat}


def trait_timing(sm, moves):
    """The same timing again and again: the largest group of one joint's moves (8 degrees or more) that took the
    same number of frames (give or take one). A person's repeated beats differ."""
    best = {"same_name": "-", "same_count": 0, "same_of": 0, "same_share": 0.0, "same_span": 0.0}
    for name in ACTING:
        ms = [m for m in moves[name] if m["size"] >= METRO_SIZE]
        if len(ms) < 4:
            continue
        frames = np.array(sorted(m["e"] - m["s"] for m in ms))
        group = max(int(((frames >= f) & (frames <= f + 2)).sum()) for f in frames)
        share = group / len(ms)
        if group > best["same_count"] or (group == best["same_count"] and share > best["same_share"]):
            f0 = [f for f in frames if int(((frames >= f) & (frames <= f + 2)).sum()) == group][0]
            best = {"same_name": name, "same_count": group, "same_of": len(ms), "same_share": share,
                    "same_span": float(f0 + 1) / RATE}
    return best


def arm_directions(rig, clip, t):
    parts = rbxsim.pose_parts(rig, clip, t)
    torso = parts["Torso"][:3, :3]
    down = np.array([0.0, -1.0, 0.0])
    right = torso.T @ (parts["Right Arm"][:3, :3] @ down)
    left = torso.T @ (parts["Left Arm"][:3, :3] @ down)
    return right, left


def trait_symmetry(sm, sigs, rig):
    """Held poses (both arms still for 0.3 s): how far the left arm is from the right arm's mirror image."""
    by = {s.name: s for s in sigs}
    still = (by["rShoulder"].smooth <= V_ROT) & (by["lShoulder"].smooth <= V_ROT)
    holds, total, mirrored = [], 0.0, 0.0
    for a, b in runs_of(still):
        if b - a + 1 < int(round(MIRROR_HOLD * RATE)):
            continue
        mid = (a + b) // 2
        r, l = arm_directions(rig, sm.clip, sm.time(mid))
        r = r * np.array([-1.0, 1.0, 1.0])
        cos = float(r @ l) / max(np.linalg.norm(r) * np.linalg.norm(l), 1e-9)
        off = math.degrees(math.acos(max(-1.0, min(1.0, cos))))
        span = (b - a + 1) / RATE
        holds.append({"t0": sm.time(a), "t1": sm.time(b + 1), "off": off, "mirrored": off <= SYMMETRIC})
        total += span
        mirrored += span if off <= SYMMETRIC else 0.0
    return {
        "holds": holds, "held_time": total, "mirrored_time": mirrored,
        "mirrored_share": mirrored / total if total > 0 else 0.0,
        "mirrored_longest": max((h["t1"] - h["t0"] for h in holds if h["mirrored"]), default=0.0),
    }


def trait_torso(sm, sigs):
    by = {s.name: s for s in sigs}
    path = {n: float(by[n].speed.sum() / RATE) for n in ACTING}
    path["offset"] = float(by["offset"].speed.sum() / RATE) * OFFSET_DEG
    torso = path["root"] + path["offset"]
    limbs = path["neck"] + path["rShoulder"] + path["lShoulder"]
    return {
        "torso_share": torso / (torso + limbs) if torso + limbs > 1e-6 else 0.0,
        "torso_path": torso, "limb_path": limbs, "torso_rate": torso / max(sm.t1 - sm.t0, 1e-6),
    }


def similar(a, b):
    return abs(a - b) <= METRO_SAME * max(a, b)


def trait_metronome(sm, moves):
    """Runs of three or more moves of one joint in one direction, the same size and the same interval apart (the
    way back between two of them does not count)."""
    found = []
    for name in ACTING:
        ms = [m for m in moves[name] if m["size"] >= METRO_SIZE]
        prev, length = {}, {}
        for i, m in enumerate(ms):
            prev[i] = None
            for j in range(i - 1, -1, -1):
                o = ms[j]
                if m["t0"] - o["t0"] > 4.0:
                    break
                if float(m["u"] @ o["u"]) > 0.7 and similar(m["size"], o["size"]):
                    prev[i] = j
                    break
            length[i] = 1
            j = prev[i]
            if j is not None:
                length[i] = 2
                k = prev[j]
                if k is not None and similar(m["t0"] - ms[j]["t0"], ms[j]["t0"] - ms[k]["t0"]):
                    length[i] = length[j] + 1
        if not ms:
            continue
        top = max(range(len(ms)), key=lambda i: length[i])
        if length[top] >= METRO_MIN:
            chain = [top]
            while prev[chain[-1]] is not None and len(chain) < length[top]:
                chain.append(prev[chain[-1]])
            chain.reverse()
            found.append({
                "name": name, "count": len(chain), "t0": ms[chain[0]]["t0"], "t1": ms[chain[-1]]["t1"],
                "size": float(np.mean([ms[i]["size"] for i in chain])),
                "every": float(np.mean(np.diff([ms[i]["t0"] for i in chain]))),
            })
    return {"metronome": found, "metronome_count": max((f["count"] for f in found), default=0)}


def trait_overlap(sm, moves):
    """After the torso turns or stops, do the head and arms arrive a few frames later."""
    events, good, lags = [], 0, []
    lo, hi = LAG_FRAMES[0] / RATE, LAG_FRAMES[1] / RATE
    for m in moves["root"]:
        if m["size"] < TORSO_MOVE:
            continue
        lag = None
        for name in ("neck", "rShoulder", "lShoulder"):
            for o in moves[name]:
                if o["size"] >= MOVE_MIN_ROT and o["t0"] <= m["t1"] and lo - 1e-6 <= o["t1"] - m["t1"] <= hi + 1e-6:
                    d = o["t1"] - m["t1"]
                    lag = d if lag is None else min(lag, d)
        events.append({"t": m["t1"], "size": m["size"], "lag": lag})
        if lag is not None:
            good += 1
            lags.append(lag)
    return {
        "torso_events": len(events), "overlapped": good,
        "overlap_share": good / len(events) if events else 1.0,
        "overlap_lag": float(np.mean(lags)) if lags else 0.0,
        "no_overlap": [e for e in events if e["lag"] is None],
    }


def measure(sm, rig):
    """Every trait of one sampled clip: a dict of numbers and of where."""
    sigs = [Signal(j, "rot", sm.q[j]) for j in JOINTS] + [Signal("offset", "pos", sm.offset)]
    moves = {}
    for sig in sigs:
        moves[sig.name] = [describe_move(sig, sm, s, e) for s, e in find_moves(sig)]
    big = big_moves(moves)
    out = {"length": sm.t1 - sm.t0, "loop": sm.loop, "moves": {k: len(v) for k, v in moves.items()}}
    out.update(trait_frozen(sm, sigs))
    out.update(trait_glides(sm, sigs))
    out.update(trait_snap(sm, big))
    out.update(trait_anticipation(sm, big))
    out.update(trait_overshoot(sm, sigs, big))
    out.update(trait_symmetry(sm, sigs, rig))
    out.update(trait_torso(sm, sigs))
    out.update(trait_metronome(sm, moves))
    out.update(trait_timing(sm, moves))
    out.update(trait_overlap(sm, moves))
    return out


# --- The verdict -----------------------------------------------------------------------------

# Calibrated 2026-11-14 on RoleMuerto (must pass) and RoleAce (must fail); the numbers are in the plan, under Tool 1.
LIMITS = {
    "dead": 8.0,  # seconds one upper-body joint may stay within 0.6 degrees (Muerto 3.7, Ace 17.5)
    "frozen": 2.5,  # seconds the whole upper body may stay within 0.6 degrees (the plan's number; Muerto 0.6, Ace 0.9)
    "torso": 0.04,  # torso (root and body offset) share of the acting motion (Muerto 0.15, Ace 0.01)
    "torso_min_path": 100.0,  # ... judged only when the neck and arms turn at least this many degrees in all
    "same_share": 0.6,  # the share of one joint's moves that took the same number of frames (Muerto 0.33, Ace 0.76)
    "same_min": 6,  # ... judged from this many such moves
    "metronome": 5,  # moves of one size at one interval, this many times in a row (the plan said 3; Muerto's torso makes 4)
    "anticipation": 0.15,  # share of big moves drawn back first (Muerto 0.37)
    "slow_share": 0.35,  # share of big moves that take over 0.35 s with no hold after (Muerto 0.11)
    "big_min": 5,  # anticipation and snap are judged from this many big moves
    "glide_time": 2.5,  # seconds in glides (constant-speed stretches) in all
    "mirrored_share": 0.5,  # share of held arm poses within 8 degrees of mirror images
    "mirrored_min": 2.0,  # ... judged from this many seconds of held arms
    "overlap": 0.25,  # share of torso turns and stops the head or arms trail by a few frames (Muerto 0.93)
    "overlap_min": 3,  # ... judged from this many torso turns and stops
}

# Which traits a kind of clip is judged on. "scene": all. A loop repeats on purpose, so a loop is not judged on what
# repeating means. An emote's held poses may be mirrored (poses are), and the movement set is judged on freezing alone.
CYCLIC = {"metronome", "same", "anticipation", "snap", "glides", "overlap"}
KIND_SKIPS = {
    "scene": set(),
    "clip": set(),
    "emote": {"symmetry"},
    "movement": {"symmetry", "torso", "metronome", "same", "anticipation", "snap", "glides", "overlap"},
}
# A body the story keeps still (the plan: "only flag spans where the story does not freeze the body").
FREEZE_OK = {
    "RoleButler_ace": "Ace sits curled in the armchair all through the Butler's scene",
}

TRAITS = ("frozen", "dead", "glides", "snap", "anticipation", "symmetry", "torso", "metronome", "same", "overlap")


def judge(result, kind, role="lead", name="", frozen_ok=()):
    """[(trait, why)] for each trait the clip fails, from its numbers."""
    skip = set(KIND_SKIPS.get(kind, ()))
    if result["loop"]:
        skip |= CYCLIC
    if name in FREEZE_OK or name in frozen_ok:
        skip |= {"frozen", "dead"}
    L = LIMITS
    bad = []

    def add(trait, why):
        if trait not in skip:
            bad.append((trait, why))

    if result["frozen"] > L["frozen"]:
        a, b = result["frozen_at"]
        add("frozen", f"the whole upper body is still for {result['frozen']:.1f} s ({a:.1f} to {b:.1f}; limit {L['frozen']})")
    if result["dead"] > L["dead"]:
        a, b = result["dead_at"]
        add("dead", f"{result['dead_joint']} stays still for {result['dead']:.1f} s ({a:.1f} to {b:.1f}; limit {L['dead']:g})")
    if result["torso_share"] < L["torso"] and result["limb_path"] >= L["torso_min_path"]:
        add("torso", f"the torso is {100 * result['torso_share']:.0f}% of the motion ({result['torso_path']:.0f} of "
                     f"{result['torso_path'] + result['limb_path']:.0f} degrees; limit {100 * L['torso']:.0f}%): only the limbs act")
    if result["same_count"] >= L["same_min"] and result["same_share"] >= L["same_share"]:
        add("same", f"{result['same_count']} of {result['same_of']} {result['same_name']} moves take {result['same_span']:.2f} s: "
                    f"the same timing every time")
    if result["metronome_count"] >= L["metronome"]:
        f = max(result["metronome"], key=lambda x: x["count"])
        add("metronome", f"{f['name']} makes {f['count']} moves of {f['size']:.0f} degrees every {f['every']:.2f} s "
                         f"({f['t0']:.1f} to {f['t1']:.1f})")
    if result["big"] >= L["big_min"] and result["anticipation_share"] < L["anticipation"]:
        add("anticipation", f"{result['anticipated']} of {result['big']} big moves are drawn back first "
                            f"(limit {100 * L['anticipation']:.0f}%)")
    if result["big"] >= L["big_min"] and result["slow_share"] > L["slow_share"]:
        add("snap", f"{len(result['slow_no_hold'])} of {result['big']} big moves take over {SLOW_MOVE} s with no hold after "
                    f"(limit {100 * L['slow_share']:.0f}%)")
    if result["glide_time"] > L["glide_time"]:
        add("glides", f"{len(result['glides'])} constant-speed stretches, {result['glide_time']:.1f} s in all (limit {L['glide_time']})")
    if result["held_time"] >= L["mirrored_min"] and result["mirrored_share"] > L["mirrored_share"]:
        add("symmetry", f"the arms are mirror images for {result['mirrored_time']:.1f} of {result['held_time']:.1f} s of held poses "
                        f"(limit {100 * L['mirrored_share']:.0f}%)")
    if result["torso_events"] >= L["overlap_min"] and result["overlap_share"] < L["overlap"]:
        add("overlap", f"the head and arms trail {result['overlapped']} of {result['torso_events']} torso turns and stops "
                       f"(limit {100 * L['overlap']:.0f}%)")
    return bad


# --- What to check ---------------------------------------------------------------------------


class Item:
    def __init__(self, name, clip, kind, shot=None, slot=None, role="lead", window=(0.0, None)):
        self.name, self.clip, self.kind, self.shot, self.slot, self.role, self.window = name, clip, kind, shot, slot, role, window


def shot_names():
    return sorted(f[:-5] for f in os.listdir(ACTING_DIR) if f.endswith(".luau"))


def load_shot(shot):
    """[Item] for the actors of one cutscene: each clip with its slot, whether it leads, and the time it is shown."""
    path = os.path.join(ACTING_DIR, shot + ".luau")
    if not os.path.exists(path):
        print(f"[check_motion] no such cutscene: {shot} (try --list)", file=sys.stderr)
        raise SystemExit(2)
    clips = rbxsim.read_luau_table(path)
    actors = []
    shot_file = os.path.join(SHOTS_DIR, shot + ".luau")
    if os.path.exists(shot_file):
        actors = rbxsim.read_luau_table(shot_file).get("actors", [])
    by_clip = {a["clip"]: a for a in actors if "clip" in a}
    items = []
    for name, clip in clips.items():
        if by_clip and name not in by_clip:
            continue  # built but no actor plays it (an old clip left in the acting file)
        a = by_clip.get(name, {})
        slot = a.get("slot", name.split("_", 1)[-1])
        at = float(a.get("at", 0.0) or 0.0)
        show = a.get("show") or [0.0, clip["length"] + at]
        window = (max(0.0, float(show[0]) - at), min(float(clip["length"]), float(show[1]) - at))
        role = "extra" if str(slot).startswith(("everyone", "extra")) else "lead"
        items.append(Item(name, clip, "scene", shot, slot, role, window))
    items.sort(key=lambda i: (i.role != "lead", i.name))
    return items


def emote_names(clips):
    try:
        text = open(COSMETICS, encoding="utf-8").read()
    except OSError:
        text = ""
    ids = set(re.findall(r'^\s*emote = "(\w+)"', text, re.M)) | set(EVERYONES)
    return sorted(i for i in ids if i in clips)


def movement_names(clips):
    try:
        import check_anims

        names = check_anims.STRICT
    except Exception:  # pragma: no cover
        names = ()
    return sorted(n for n in names if n in clips)


def collect(args):
    items, seen = [], set()
    exported = {}

    def clips():
        if not exported:
            exported.update(rbxsim.load_clips())
        return exported

    def add(item):
        if item.name not in seen:
            seen.add(item.name)
            items.append(item)

    shots = []
    for group in args.shot or []:
        shots += [s for s in group.split(",") if s]
    if args.all:
        shots = shot_names()
    for shot in shots:
        for item in load_shot(shot):
            add(item)
    for name in args.names:
        if name in shot_names():
            for item in load_shot(name):
                add(item)
            continue
        shot = name.split("_", 1)[0]
        if shot in shot_names() and name not in seen:
            hit = [i for i in load_shot(shot) if i.name == name]
            if hit:
                add(hit[0])
                continue
        if name in clips():
            add(Item(name, clips()[name], "clip"))
            continue
        print(f"[check_motion] no such clip or cutscene: {name} (try --list)", file=sys.stderr)
        raise SystemExit(2)
    if args.emotes:
        for name in emote_names(clips()):
            add(Item(name, clips()[name], "emote", slot=name))
    if args.movement:
        for name in movement_names(clips()):
            add(Item(name, clips()[name], "movement", slot=name))
    if args.lead:
        items = [i for i in items if i.role == "lead"]
    return items


# --- Output ----------------------------------------------------------------------------------


def clean(value):
    if isinstance(value, dict):
        return {str(k): clean(v) for k, v in value.items() if k != "u"}
    if isinstance(value, (list, tuple)):
        return [clean(v) for v in value]
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, np.ndarray):
        return value.tolist()
    return value


def line(item, r, bad, verdict):
    j = {"root": "torso", "neck": "neck", "rShoulder": "rSh", "lShoulder": "lSh"}[r["dead_joint"]]
    big = r["big"]
    parts = [
        f"frozen {r['frozen']:.1f}s",
        f"dead {r['dead']:.1f}s {j}",
        f"glides {r['glide_time']:.1f}s",
        f"snap {len(r['slow_no_hold'])}/{big} slow",
        f"anticip {r['anticipated']}/{big}",
        f"overshoot {r['overshot']}/{big}",
        f"sym {100 * r['mirrored_share']:.0f}% of {r['held_time']:.1f}s",
        f"torso {100 * r['torso_share']:.0f}%",
        f"metro {r['metronome_count']}/same {r['same_count']} of {r['same_of']}",
        f"overlap {r['overlapped']}/{r['torso_events']}",
    ]
    who = f"{item.name}" + (f" ({item.role})" if item.kind == "scene" and item.role != "lead" else "")
    out = f"[check_motion] {verdict:4} {who} {r['length']:.1f}s: " + ", ".join(parts)
    if bad:
        out += "  <- " + ", ".join(sorted({t for t, _ in bad}, key=TRAITS.index))
    return out


def details(r, bad):
    """Where each fault is, one indented line per failing trait, then the clues behind the numbers."""
    lines = [f"      {trait}: {why}" for trait, why in bad]
    traits = {t for t, _ in bad}

    def times(moves, limit=8):
        return ", ".join(f"{m['name']} {m['t0']:.2f}-{m['t1']:.2f}" for m in moves[:limit]) + (" ..." if len(moves) > limit else "")

    if "anticipation" in traits and r["unanticipated"]:
        lines.append("        no wind-up before: " + times(r["unanticipated"]))
    if "snap" in traits and r["slow_no_hold"]:
        lines.append("        slow and no hold: " + times(r["slow_no_hold"]))
    if "glides" in traits and r["glides"]:
        lines.append("        gliding: " + ", ".join(f"{g['name']} {g['t0']:.2f}-{g['t1']:.2f}" for g in r["glides"][:8]))
    if "symmetry" in traits:
        lines.append("        mirrored holds: " + ", ".join(f"{h['t0']:.1f}-{h['t1']:.1f}" for h in r["holds"] if h["mirrored"]))
    if "overlap" in traits and r["no_overlap"]:
        lines.append("        torso stops with nothing trailing at: " + ", ".join(f"{e['t']:.2f}" for e in r["no_overlap"][:10]))
    if "dead" in traits or "frozen" in traits:
        lines.append("        longest still, by joint: " + ", ".join(f"{k} {v:.1f}s" for k, v in r["frozen_by_joint"].items()))
    return lines


def print_table(scored):
    """The numbers of each clip as a Markdown table, for a report."""
    names = {"root": "torso", "neck": "neck", "rShoulder": "rSh", "lShoulder": "lSh"}
    print("| clip | verdict | frozen s | dead limb s | glides s | slow/big | wound up/big | overshot/big | mirrored | torso | "
          "metronome / same timing | overlap |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for item, r, bad, verdict in scored:
        fails = ", ".join(sorted({t for t, _ in bad}, key=TRAITS.index))
        name = item.name + (" (extra)" if item.role == "extra" else "")
        shown = verdict + (f" ({fails})" if fails else "")
        print(f"| {name} | {shown} | {r['frozen']:.1f} | {r['dead']:.1f} {names[r['dead_joint']]} | "
              f"{r['glide_time']:.1f} | {len(r['slow_no_hold'])}/{r['big']} | {r['anticipated']}/{r['big']} | "
              f"{r['overshot']}/{r['big']} | {100 * r['mirrored_share']:.0f}% of {r['held_time']:.1f} s | "
              f"{100 * r['torso_share']:.0f}% | {r['metronome_count']} / {r['same_count']} of {r['same_of']} | "
              f"{r['overlapped']}/{r['torso_events']} |")


def z_quat(deg):
    a = math.radians(deg) / 2.0
    return [0.0, 0.0, math.sin(a), math.cos(a)]


def made_up(length, keys, joint="rShoulder", extra=None):
    """A clip that turns one joint about z through (time, degrees) keys."""
    joints = {joint: {"t": [k[0] for k in keys], "q": [v for k in keys for v in z_quat(k[1])]}}
    joints.update(extra or {})
    return {"length": length, "loop": False, "joints": joints}


def selftest():
    """Made-up clips with a known answer for each measuring: exits 1 when any answer is wrong."""
    rig = rbxsim.load_rig()
    wrong = []

    def check(label, ok):
        print(f"[check_motion] selftest {'ok   ' if ok else 'WRONG'} {label}")
        if not ok:
            wrong.append(label)

    def run(clip):
        return measure(Sampled("made_up", clip), rig)

    # a glide: 90 degrees in a straight line over 1.2 s, then still
    r = run(made_up(3.0, [(0, 0), (0.6, 45), (1.2, 90), (3.0, 90)]))
    check("a constant-speed turn is a glide", bool(r["glides"]) and r["glides"][0]["t1"] - r["glides"][0]["t0"] > 0.5)
    check("a joint that never moves is a dead limb", r["dead"] >= 2.9 and r["dead_joint"] != "rShoulder")
    # a strike: held, drawn back 14 degrees, snapped to 100 in 3 frames, settled to 90, held
    r = run(made_up(3.0, [(0, 0), (1.0, 0), (1.15, -14), (1.2, 100), (1.45, 90), (3.0, 90)]))
    check("a big move is found", r["big"] >= 1)
    check("a draw-back before it is an anticipation", r["anticipated"] >= 1)
    check("passing the rest pose and settling is an overshoot", r["overshot"] >= 1)
    check("a 3-frame move with a hold is not slow", not r["slow_no_hold"] and r["hold_median"] >= 1.0)
    # the same without the wind-up: a slow straight slide that ends as it is
    r = run(made_up(3.0, [(0, 0), (1.0, 0), (1.8, 100), (1.85, 100)]))
    check("no draw-back means no anticipation", r["anticipated"] == 0 and r["big"] >= 1)
    # five moves of 30 degrees every 0.5 s, each taking 0.2 s
    pts = [(0.0, 0)]
    for i in range(5):
        pts += [(0.5 + i * 0.5, 0), (0.6 + i * 0.5, 30), (0.7 + i * 0.5, 0)]
    r = run(made_up(4.0, sorted(set(pts))))
    check("five identical moves at one interval are a metronome", r["metronome_count"] >= 3 and r["same_count"] >= 5)
    # arms at rest are mirror images; one arm turned is not
    r = run(made_up(2.0, [(0, 0), (2.0, 0)], "neck"))
    check("both arms down for the whole clip are mirrored", r["mirrored_share"] > 0.9 and r["held_time"] > 1.5)
    r = run(made_up(2.0, [(0, 60), (2.0, 60)], "rShoulder"))
    check("one arm raised breaks the mirror", r["mirrored_share"] < 0.1 and r["held_time"] > 1.5)
    # the torso turns; the head follows three frames after, or arrives with it
    root = {"root": {"t": [0, 1.0, 1.15, 3.0], "q": [v for d in (0, 0, 40, 40) for v in z_quat(d)]}}
    late = {"neck": {"t": [0, 1.0, 1.2, 3.0], "q": [v for d in (0, 0, 25, 25) for v in z_quat(d)]}}
    same = {"neck": {"t": [0, 1.0, 1.15, 3.0], "q": [v for d in (0, 0, 25, 25) for v in z_quat(d)]}}
    r = run({"length": 3.0, "loop": False, "joints": {**root, **late}})
    check("a head that arrives after the torso stops overlaps it", r["torso_events"] == 1 and r["overlapped"] == 1)
    r = run({"length": 3.0, "loop": False, "joints": {**root, **same}})
    check("a head that arrives with the torso does not", r["torso_events"] == 1 and r["overlapped"] == 0)
    print(f"[check_motion] selftest {len(wrong)} wrong")
    return 1 if wrong else 0


def window_note(item, sm):
    if item.window[0] > 1e-6 or (item.window[1] is not None and item.window[1] < item.clip["length"] - 1e-6):
        return f" (shown {sm.t0:.1f} to {sm.t1:.1f})"
    return ""


def main(argv=None):
    ap = argparse.ArgumentParser(description="The motion report: nine traits of motion that looks made by a person.")
    ap.add_argument("names", nargs="*", help="clips (RoleMuerto_self, bow ...) or cutscenes (RoleAce)")
    ap.add_argument("--shot", action="append", help="every actor clip of a cutscene (comma separated)")
    ap.add_argument("--all", action="store_true", help="every cutscene")
    ap.add_argument("--emotes", action="store_true", help="the 70 emotes")
    ap.add_argument("--movement", action="store_true", help="the movement set")
    ap.add_argument("--lead", action="store_true", help="only the lead actors of a cutscene, not the extras")
    ap.add_argument("--strict-extras", action="store_true", help="fail on an extra's faults too (they are info by default)")
    ap.add_argument("--frozen-ok", default="", help="clips the story keeps still (comma separated)")
    ap.add_argument("--detail", action="store_true", help="where each fault is")
    ap.add_argument("--quiet", action="store_true", help="only the clips that fail")
    ap.add_argument("--worst", type=int, default=0, metavar="N", help="after the list, the N clips with most failing traits")
    ap.add_argument("--json", metavar="PATH", help="also write every number to a file")
    ap.add_argument("--list", action="store_true", help="list the cutscenes and their clips")
    ap.add_argument("--table", action="store_true", help="also print the numbers as a Markdown table (for a report)")
    ap.add_argument("--selftest", action="store_true", help="check the measuring on made-up clips and exit")
    ap.add_argument("--no-fail", action="store_true", help="exit 0 whatever the verdict")
    args = ap.parse_args(argv)

    if args.selftest:
        return selftest()
    if args.list:
        for shot in shot_names():
            print(shot + ": " + ", ".join(f"{i.name}{'*' if i.role == 'extra' else ''}" for i in load_shot(shot)))
        print("(* an extra: judged as info)")
        return 0
    if not (args.names or args.shot or args.all or args.emotes or args.movement):
        ap.print_usage()
        print("name a clip, --shot, --all, --emotes or --movement (--help for all of it)")
        return 2

    items = collect(args)
    rig = rbxsim.load_rig()
    frozen_ok = [n for n in args.frozen_ok.split(",") if n]
    failed, results, scored = 0, {}, []
    for item in items:
        sm = Sampled(item.name, item.clip, item.window[0], item.window[1])
        r = measure(sm, rig)
        bad = judge(r, item.kind, item.role, item.name, frozen_ok)
        extra = item.role == "extra" and not args.strict_extras
        verdict = "info" if extra and bad else ("FAIL" if bad else "PASS")
        results[item.name] = {"kind": item.kind, "shot": item.shot, "slot": item.slot, "role": item.role,
                              "verdict": verdict, "failing": [t for t, _ in bad], "numbers": clean(r)}
        if bad and not extra:
            failed += 1
        scored.append((item, r, bad, verdict))
        if args.quiet and not (bad and not extra):
            continue
        print(line(item, r, bad, verdict) + window_note(item, sm))
        if args.detail or (bad and not extra and args.quiet):
            for text in details(r, bad):
                print(text)
    if args.worst:
        print(f"[check_motion] the {args.worst} worst by failing traits:")
        order = sorted((s for s in scored if s[2]), key=lambda s: (-len({t for t, _ in s[2]}), s[0].name))[: args.worst]
        for item, r, bad, verdict in order:
            print(f"    {len({t for t, _ in bad})} fail  {item.name}: " + ", ".join(sorted({t for t, _ in bad}, key=TRAITS.index)))
    if args.table:
        print_table(scored)
    checked = len(scored)
    print(f"[check_motion] {checked} clip(s) checked, {failed} failed" +
          (f", {sum(1 for s in scored if s[3] == 'info')} extra(s) only noted" if any(s[3] == 'info' for s in scored) else ""))
    if args.json:
        with open(args.json, "w", encoding="utf-8", newline="\n") as f:
            json.dump(results, f, indent=1)
            f.write("\n")
    return 0 if args.no_fail or not failed else 1


if __name__ == "__main__":
    sys.exit(main())
