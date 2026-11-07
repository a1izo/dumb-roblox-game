"""Footwork: a cutscene actor's soles stay where they come down in the set, and the feet step after the body wherever
its path takes it (2026-11-07, asked for movements that "dont look stiff and ai made": a check of every shot found
the feet skating at every walk's start and end, people moved a stud or two with their legs standing still, and turns
on the spot pivoting on flat feet).

    footwork.apply(shot)        # at the end of a shot's module, once its actors' marks are down (before a Retime)
    footwork.apply(shot, carried={"watcher": [(0.0, 4.6)]})   # a floor that moves with the body (a train car)

For every actor whose motion plants its feet (Motion.plant) or walks (acting.walking), the legs inside those windows
(and a moment either side of an edge, so a window's end no longer snaps the legs) are planned from the actor's whole
path, which is known in advance. A planted sole keeps its place and its turn in the set while the body moves over it
(the rigid R6 leg leaning, or sliding in the hip, to keep it there). A foot lifts when it would be too far from its
spot under the hip, or turned too far from the body, by the time it could come down again, and it comes down where
the body will be then (on a walk, ahead of it by half the ground the body covers while that foot is down), on the
old gait's arc (smooth along, sin^1.5 up). At walking speed the steps fall into the old gait's cadence, stride and
lift (gait.WALK, slower walks taking slower steps), so a steady walk looks as it did; starting, stopping, a step back
and a turn on the spot are steps now. The body bobs with the steps, and on a walk the arms swing against the feet as
they really are, a little behind them (acting.walking's `arms` sets how far; its own legs give way to these).
A floor that moves with the body (a train car) is `carried`: the feet keep their place on it.

The planning runs when the shot module is imported (run_anims, run_cinema); the clip is rebuilt with it."""

import math

import numpy as np

import posekit
from gait import SOLE_X, WALK

RATE = 60  # the plan's samples a second (the clips are built at 30)
STAND_FROM = 0.38  # studs a planted sole may be off its spot (standing) before it steps
TURN_FROM = 24.0  # degrees a planted sole may be turned from the body before it steps
SETTLE_AFTER = 0.3  # seconds the body stands still before a sole a little off its spot steps home
SETTLE_FROM, SETTLE_TURN = 0.16, 10.0  # (studs, degrees) off its spot a sole steps home once the body is still
STAND_STEP = 0.26  # seconds a step takes standing
QUICK_STEP = 0.16  # the quickest step (a fast turn on the spot)
MIN_DOWN = 0.06  # seconds a foot stays down before either may lift
LIFT_STAND = (0.07, 0.1, 0.22)  # a standing step lifts a + b * its length studs, at most c
WALK_FROM, WALK_FULL = 0.6, 2.0  # body speeds (studs/s) between which standing steps turn into a walk's
RAMP = 0.15  # seconds the plan takes to come in or give way at a window's edge
DEFAULT_ARMS = 0.6  # the arms' swing (a share of acting.WALK_ARMS) on a walk outside acting.walking's windows
YAW_MAX = 75.0  # the most a planted foot is turned from the body (degrees)
STEP_DIP = 0.03  # studs the body dips as it takes a standing step
AHEAD = 0.6  # seconds ahead a step looks for the speed it sizes itself by (a walk's first step is a walk's step)
FOOT_SPEED = 7.0  # studs a second a foot in the air goes at most on average standing (walking: 1.3x the gait's own)
STEP_MAX = (1.6, 1.25)  # the longest step: studs standing; a share of the walk's stride walking
LEAN_FROM, LEAN_FULL = 0.25, 0.75  # studs a planted sole is off from under its hip before the leg leans to it


def _smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def _wrap(a):
    return (a + 180.0) % 360.0 - 180.0


def _ry(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def walk_times(speed):
    """(cycle, time a foot is down, swing) of the old gait at this speed (studs/s)."""
    period = WALK.period * (4.0 / max(speed, 1.0)) ** 0.5
    return period, WALK.stance * period, (1 - WALK.stance) * period


def _leg(side, foot, yaw_rel, root, off, pitch, roll):
    """The hip value that stands this leg on `foot` (character frame), turned yaw_rel degrees from the body and leaning
    pitch / roll degrees (the R6 way: the rigid leg slides in or out of the hip for the rest)."""
    world = posekit.R(pitch, 0.0, roll) @ posekit.ry(yaw_rel)
    pivot = np.asarray(foot, float) - world @ np.array([-side * 0.5, -posekit.LEG_LENGTH, 0.0])
    natural = posekit.hip_world(side, root, off)
    root_rot = posekit.R(*root)
    slide = root_rot.T @ (pivot - natural)
    return np.array([*posekit.euler(root_rot.T @ world), *slide], float)


class Plan:
    def __init__(self, motion, actor, carried=()):
        self.m = motion
        self.a = actor
        self.carried = [(float(t0), float(t1)) for t0, t1 in carried]
        self.planning = False
        self.n = max(2, int(round(motion.length * RATE)))
        self.times = [motion.length * i / self.n for i in range(self.n + 1)]
        self.rows = None
        self.windows = self._windows()
        self.steps = []  # (side, t0, t_land, length studs): the plan's steps, for a look at what it did

    # --- where the plan has the legs ---------------------------------------------------------------------------

    def _windows(self):
        spans = [(t0, t1) for t0, t1, *_ in self.m.plants]
        spans += [(w["t0"] - w["blend"], w["t1"] + w["blend"]) for w in self.m.walks]
        spans.sort()
        merged = []
        for t0, t1 in spans:
            if merged and t0 <= merged[-1][1] + 1e-6:
                merged[-1] = (merged[-1][0], max(merged[-1][1], t1))
            else:
                merged.append((t0, t1))
        return merged

    def weight(self, t):
        """1 inside a window, easing in and out over RAMP outside its edges (never past the clip's ends)."""
        best = 0.0
        for t0, t1 in self.windows:
            if t0 - 1e-9 <= t <= t1 + 1e-9:
                return 1.0
            if t0 - RAMP < t < t0:
                best = max(best, _smooth((t - (t0 - RAMP)) / RAMP))
            elif t1 < t < t1 + RAMP:
                best = max(best, _smooth(((t1 + RAMP) - t) / RAMP))
        return best

    def _walk_at(self, t):
        for w in self.m.walks:
            if w["t0"] - w["blend"] <= t <= w["t1"] + w["blend"]:
                return w
        return None

    def home(self, side, t):
        """(this sole's spot in the character frame, the standing leg's tilt) at t, from the plant window there (or
        the nearest one)."""
        plants = self.m.plants
        here = next((p for p in plants if p[0] - 1e-9 <= t <= p[1] + 1e-9), None)
        if here is None and plants:
            near = min(plants, key=lambda p: min(abs(t - p[0]), abs(t - p[1])))
            here = (near[0], near[1], near[2], (0.0, 0.0), (0.0, 0.0))
        stance, forward, tilt = (here[2], here[3], here[4]) if here else (0.05, (0.0, 0.0), (0.0, 0.0))
        wide = stance if not isinstance(stance, (tuple, list)) else (stance[0] if side > 0 else stance[1])
        ahead = forward[0] if side > 0 else forward[1]
        lean = tilt[0] if side > 0 else tilt[1]
        return np.array([side * (SOLE_X + wide), 0.0, -ahead]), lean, wide

    # --- the path, on the plan's grid -------------------------------------------------------------------------

    def _cache_path(self):
        rows = [self.a.path.value(min(self.a.shot.length, max(0.0, t + self.a.at))) for t in self.times]
        self.P = np.array([r[:3] for r in rows], float)
        self.Y = np.array([float(r[3]) for r in rows], float)

    def _at(self, arr, t):
        x = max(0.0, min(float(self.n), t * self.n / self.m.length))
        i = min(self.n - 1, int(x))
        k = x - i
        return arr[i] * (1 - k) + arr[i + 1] * k

    def pos(self, t):
        return self._at(self.P, t)

    def yaw(self, t):
        return float(self._at(self.Y, t))

    def vel(self, t):
        h = 2.0 / RATE
        if self.is_carried(t):
            return np.zeros(3)
        v = (self.pos(min(self.m.length, t + h)) - self.pos(max(0.0, t - h))) / (2 * h)
        v[1] = 0.0
        return v

    def yaw_rate(self, t):
        h = 2.0 / RATE
        if self.is_carried(t):
            return 0.0
        return (self.yaw(min(self.m.length, t + h)) - self.yaw(max(0.0, t - h))) / (2 * h)

    def speed(self, t):
        v = self.vel(t)
        return float(math.hypot(v[0], v[2]))

    def is_carried(self, t):
        return any(t0 - 1e-9 <= t <= t1 + 1e-9 for t0, t1 in self.carried)

    def home_world(self, side, t):
        c, _, _ = self.home(side, t)
        return self.pos(t) + _ry(self.yaw(t)) @ c

    def target(self, side, t_land, lead):
        """Where and how turned a foot comes down at t_land: its spot `lead` seconds later, off the path itself (so a
        step ends where the body will stand, never past where it stops)."""
        return self.home_world(side, t_land + lead), self.yaw(t_land + lead)

    def _landing(self, side, sw):
        """A step's landing, no farther from where it lifted than its cap (the next step makes up the rest)."""
        spot, turn_to = self.target(side, sw["t_land"], sw["lead"])
        dx, dz = spot[0] - sw["P0"][0], spot[2] - sw["P0"][2]
        dist = math.hypot(dx, dz)
        if dist > sw["cap"]:
            spot = spot.copy()
            spot[0] = sw["P0"][0] + dx * sw["cap"] / dist
            spot[2] = sw["P0"][2] + dz * sw["cap"] / dist
        return spot, turn_to

    # --- planning --------------------------------------------------------------------------------------------

    def _start(self, feet, t):
        """The feet as the plan takes the legs at t: side by side on their spots, or, for a body already on its way,
        mid-stride (the right foot just down ahead, the left behind about to lift), as a walk in from out of shot is."""
        for s, f in feet.items():
            f.update(P=self.home_world(s, t), Y=self.yaw(t), h=0.0, swing=None, down=t - 1.0)
        speed = self.speed(t)
        if speed > WALK_FROM and not self.is_carried(t):
            _, down_t, _ = walk_times(speed)
            feet[1]["P"] = self.home_world(1, t + down_t / 2)
            feet[1]["down"] = t
            feet[-1]["P"] = self.home_world(-1, t) - self.vel(t) * (down_t / 2)

    def plan(self):
        self._cache_path()
        feet = {s: {"P": self.home_world(s, 0.0), "Y": self.yaw(0.0), "h": 0.0, "swing": None, "down": -1.0}
                for s in (1, -1)}
        last = -1
        still = 0.0
        prev_t = None
        fresh = True
        record = []
        for t in self.times:
            w_own = self.weight(t)
            if prev_t is not None and self.is_carried(t):
                # the floor moved with the body: so did the feet on it
                p0, p1 = self.pos(prev_t), self.pos(t)
                turn = _ry(self.yaw(t)) @ _ry(self.yaw(prev_t)).T
                dy = self.yaw(t) - self.yaw(prev_t)
                for f in feet.values():
                    f["P"] = p1 + turn @ (f["P"] - p0)
                    f["Y"] += dy
                    if f["swing"]:
                        f["swing"]["P0"] = p1 + turn @ (f["swing"]["P0"] - p0)
                        f["swing"]["Y0"] += dy
            prev_t = t
            if w_own <= 0.0:
                fresh = True
                still = t
                record.append(None)
                continue
            if fresh:
                self._start(feet, t)
                fresh = False
            v = self.vel(t)
            speed = float(math.hypot(v[0], v[2]))
            turning = self.yaw_rate(t)
            if speed > 0.15 or abs(turning) > 8.0:
                still = t
            # the feet in the air come on
            u_swing = 0.0
            for s, f in feet.items():
                sw = f["swing"]
                if not sw:
                    continue
                u = min(1.0, (t - sw["t0"]) / sw["d"])
                spot, turn_to = self._landing(s, sw)
                k = _smooth(u)
                f["P"] = sw["P0"] + (spot - sw["P0"]) * k
                f["Y"] = sw["Y0"] + _wrap(turn_to - sw["Y0"]) * k
                f["h"] = sw["lift"] * math.sin(math.pi * u) ** 1.5
                u_swing = u
                if u >= 1.0:
                    f.update(P=spot, Y=turn_to, h=0.0, swing=None, down=t)
            walk = _smooth((speed - WALK_FROM) / (WALK_FULL - WALK_FROM))
            # a foot lifts?
            if not any(f["swing"] for f in feet.values()):
                carried = self.is_carried(t)
                # (sized by the speed the body is coming to: a walk's first step is a walk's, not a shuffle)
                ahead = speed if carried else max([speed] + [self.speed(t + AHEAD * k / 4) for k in (1, 2, 3, 4)])
                walk_a = _smooth((ahead - WALK_FROM) / (WALK_FULL - WALK_FROM))
                cycle, down_t, swing_t = walk_times(ahead)
                d = STAND_STEP + (swing_t - STAND_STEP) * walk_a
                if abs(turning) > 1.0:
                    d = min(d, max(QUICK_STEP, TURN_FROM * 2.2 / abs(turning)))
                look = t if carried else t + d  # (on a moving floor the spot moves with the feet)
                # (when it lifts goes by the speed now, so the first step lifts as the body sets off)
                _, down_now, _ = walk_times(speed)
                thr = STAND_FROM + (max(STAND_FROM, speed * (down_now / 2 + d)) - STAND_FROM) * walk
                settle = t - still >= SETTLE_AFTER
                needs = {}
                for s, f in feet.items():
                    spot = self.home_world(s, look)
                    err = math.hypot(f["P"][0] - spot[0], f["P"][2] - spot[2])
                    yerr = abs(_wrap(f["Y"] - self.yaw(look)))
                    needs[s] = max(err / (SETTLE_FROM if settle else thr), yerr / (SETTLE_TURN if settle else TURN_FROM))
                best = max((1, -1), key=lambda s: (needs[s], s != last))
                if best == last and needs[-best] > 0.6:
                    best = -best  # (the feet take turns while both need to go)
                if needs[best] > 1.0:
                    f, other = feet[best], feet[-best]
                    min_down = max(MIN_DOWN, (down_t - d) / 2 * walk_a)
                    if t - other["down"] >= min_down and t - f["down"] >= MIN_DOWN:
                        lead = down_t / 2 * walk_a
                        cap = STEP_MAX[0] + (STEP_MAX[1] * ahead * cycle - STEP_MAX[0]) * walk_a
                        sw = {"t0": t, "d": d, "P0": f["P"].copy(), "Y0": f["Y"], "t_land": t + d, "lead": lead,
                              "cap": max(STEP_MAX[0], cap)}
                        spot, _ = self._landing(best, sw)
                        length = math.hypot(spot[0] - f["P"][0], spot[2] - f["P"][2])
                        # (a long step takes longer: never a foot whipped along faster than a walk's own)
                        quickest = max(FOOT_SPEED, 1.3 * ahead / (1 - WALK.stance))
                        if length / d > quickest:
                            sw["d"] = d = length / quickest
                            sw["t_land"] = t + d
                            spot, _ = self._landing(best, sw)
                            length = math.hypot(spot[0] - f["P"][0], spot[2] - f["P"][2])
                        stand_lift = min(LIFT_STAND[2], LIFT_STAND[0] + LIFT_STAND[1] * length)
                        sw["lift"] = WALK.lift * min(1.0, ahead / 4.0) * walk_a + stand_lift * (1 - walk_a)
                        f["swing"] = sw
                        self.steps.append((best, round(t, 3), round(t + d, 3), round(length, 2)))
                        last = best
            record.append({"w": w_own, "walk": walk, "speed": speed, "u": u_swing,
                           "feet": {s: (f["P"].copy(), f["Y"], f["h"], f["swing"]) for s, f in feet.items()}})
        self._solve(record)
        return self

    def _solve(self, record):
        """The legs, the body's bob and the arms' swing on the grid, from the planned feet and the clip's own pose."""
        from cinema.acting import HELD_FROM, WALK_ARM_LAG, WALK_ARMS, WALK_TWIST

        m = self.m
        n = len(self.times)
        self.planning = True
        m.footwork = self
        try:
            base = [m.sample(t) for t in self.times]
        finally:
            self.planning = False
        # the arms' swing: the feet's spread along the body, at the walk's own measure, a little behind them
        raw = np.zeros(n)
        lag = np.zeros(n)
        for i, rec in enumerate(record):
            if rec is None or rec["walk"] <= 0.0:
                continue
            t = self.times[i]
            turn = _ry(self.yaw(t)).T
            fwd = {s: -(turn @ (rec["feet"][s][0] - self.pos(t)))[2] for s in (1, -1)}
            walk_w = self._walk_at(t)
            ref_speed = max(1.0, walk_w["speed"] if walk_w else rec["speed"])
            travel = ref_speed * walk_times(ref_speed)[1]
            raw[i] = max(-1.2, min(1.2, (fwd[1] - fwd[-1]) / travel)) * rec["walk"]
            lag[i] = WALK_ARM_LAG * walk_times(max(1.0, rec["speed"]))[0]
        swing = np.zeros(n)
        for i in range(n):
            j = i - int(round(lag[i] * RATE))
            swing[i] = raw[max(0, j)]
        rows = []
        for i, t in enumerate(self.times):
            rec = record[i]
            pose, off = base[i]
            if rec is None:
                rows.append(None)
                continue
            walk_w = self._walk_at(t)
            arms = DEFAULT_ARMS
            if walk_w is not None:
                arms = walk_w["arms"]
                arms = 1.0 if arms is True else float(arms or 0.0)
            speed = rec["speed"]
            reach = WALK_ARMS * min(1.3, (speed / 4.0) ** 0.6) * arms
            sw = swing[i]
            twist = WALK_TWIST * sw if arms > 0 else 0.0
            drop = rec["walk"] * (0.1 + 0.05 * math.cos(2 * math.pi * rec["u"]))
            drop += (1 - rec["walk"]) * STEP_DIP * math.sin(math.pi * rec["u"])
            off = np.array(off, float)
            off[1] -= drop
            # (the legs ride the shoulders' small turn, as the old walk's did: the twist is laid on after them)
            root = tuple(float(v) for v in pose["root"][:3]) if "root" in pose else (0.0, 0.0, 0.0)
            yaw_body = self.yaw(t)
            to_char = _ry(yaw_body).T
            legs = {}
            for s, key in ((1, "rHip"), (-1, "lHip")):
                P, Y, h, sw_state = rec["feet"][s]
                foot = to_char @ (P - self.pos(t))
                foot[1] += h
                spot, tilt, wide = self.home(s, t)
                yaw_rel = max(-YAW_MAX, min(YAW_MAX, _wrap(Y - yaw_body)))
                top = np.asarray(posekit.hip_world(s, root, tuple(off))) + posekit.R(*root) @ np.array([-s * 0.5, 0.0, 0.0])
                dy = max(0.5, top[1] - foot[1])
                pitch_lean = math.degrees(math.atan2(top[2] - foot[2], dy))
                side_off = foot[0] - (top[0] + s * wide)
                side_off = math.copysign(max(0.0, abs(side_off) - 0.1), side_off)  # (the weight's sway is no side-step)
                roll_lean = math.degrees(math.atan2(side_off, dy))
                # (a leg leans on a walk, in the air, and wherever its sole is well off from under the hip: the rigid
                # R6 leg reaching for it, never sliding out of the hip to stay upright)
                away = math.hypot(foot[0] - (top[0] + s * wide), foot[2] - top[2])
                lean_w = max(rec["walk"], _smooth((away - LEAN_FROM) / (LEAN_FULL - LEAN_FROM)))
                busy = rec["walk"]
                if sw_state:
                    u = min(1.0, (t - sw_state["t0"]) / sw_state["d"])
                    lean_w = max(lean_w, math.sin(math.pi * u))
                    busy = 1.0
                pitch = pitch_lean * lean_w + tilt * (1 - lean_w)
                roll = roll_lean * lean_w
                solved = _leg(s, foot, yaw_rel, root, tuple(off), pitch, roll)
                # Where the plan has nothing to add (the sole on its own spot, nothing stepping, no walk), the clip's own
                # planted leg stands (it rides the hips' sway as it always did, and keeps one key where it always had one).
                gone = math.hypot(foot[0] - spot[0], foot[2] - spot[2])
                busy = max(busy, _smooth((gone - 0.03) / 0.07), _smooth((abs(yaw_rel) - 1.0) / 3.0))
                if rec["w"] < 1.0:
                    busy = 1.0  # (past a window's edge the planted legs hand over to the clip's own over RAMP, never at once)
                own = pose.get(key)
                legs[key] = solved if own is None or busy >= 1.0 else own * (1 - busy) + solved * busy
            arm = {}
            for key, side in (("rShoulder", -1.0), ("lShoulder", 1.0)):
                if key in pose:
                    held = 0.25 if pose[key][0] > HELD_FROM else 1.0
                    arm[key] = held * reach * side * sw
            rows.append({"w": rec["w"], "drop": drop, "twist": twist, "arm": arm, "legs": legs})
        self.rows = rows

    # --- in the clip -----------------------------------------------------------------------------------------

    def extra(self, t, pose, off):
        """Motion extra: the planned legs (and bob, twist, swing) laid over the pose, by the plan's weight."""
        if self.planning or self.rows is None:
            return
        x = max(0.0, min(float(self.n), t * self.n / self.m.length))
        i = min(self.n - 1, int(x))
        k = x - i
        a, b = self.rows[i], self.rows[i + 1]
        if a is None and b is None:
            return
        if a is None or b is None:
            row, w = (b, b["w"] * k) if a is None else (a, a["w"] * (1 - k))
            a = b = row
            k = 0.0
        else:
            w = a["w"] * (1 - k) + b["w"] * k
        if w <= 0.0:
            return

        def mix(name):
            return a[name] * (1 - k) + b[name] * k

        off[1] -= w * mix("drop")
        twist = w * mix("twist")
        if "root" in pose:
            pose["root"][1] += twist
        if "neck" in pose:
            pose["neck"][1] -= twist * 0.8
        for key in a["arm"]:
            if key in pose:
                pose[key][0] += w * (a["arm"][key] * (1 - k) + b["arm"].get(key, 0.0) * k)
        for key in ("rHip", "lHip"):
            leg = a["legs"][key] * (1 - k) + b["legs"][key] * k
            old = pose.get(key, np.zeros(6))
            pose[key] = old * (1 - w) + leg * w


def apply(shot, skip=(), carried=None):
    """Plans the feet of every actor of `shot` whose clip plants or walks (and is its own: a clip shared by actors on
    different paths is left as it was), and rebuilds those clips. Returns the plans."""
    from motion import MOTIONS, Motion

    carried = carried or {}
    users = {}
    for a in shot.actors:
        mo = a.motion if a.motion is not None else MOTIONS.get(a.clip)
        if isinstance(mo, Motion):
            users.setdefault(id(mo), []).append((a, mo))
    plans = []
    for found in users.values():
        if len(found) != 1:
            continue
        a, mo = found[0]
        if a.slot in skip or mo.loop or not (mo.plants or mo.walks) or getattr(mo, "footwork", None) is not None:
            continue
        p = Plan(mo, a, carried.get(a.slot, ())).plan()
        mo.extra(p.extra)
        mo.build()
        plans.append(p)
    return plans
