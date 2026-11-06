"""How evenly a venue is lit, room by room: per named zone (HQ: per room of its plan), the lamps in it, its floor area
and an estimated light level at eye height on a 2-stud grid (every lamp of the scene and its props, spots within
their cones, brightness x (1 - d / range)^2, no walls: Roblox lamps cast no shadows). Each zone is compared with the
median of its kind: under 0.5x is marked DARK, over 2x BRIGHT. Reads art/export/scenes/<Venue>.json, so export the
venue first. Made for the 2026-11-06 sweep (docs/agent-memory/lighting-sweep-2026-11.md).

    <Blender's python> art/scripts/maps/room_light.py Campus [--json out.json]
"""
import json, math, os, sys, statistics
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.join(ROOT, "art", "scripts"))
os.chdir(ROOT)
from maps import catalog
from maps import geo2d as g2

venue = sys.argv[1]
d = json.load(open(f"art/export/scenes/{venue}.json"))
cat = catalog.load()
lamps = []
for li in d["lights"]:
    if li.get("role") == "emergency":
        continue
    lamps.append(dict(pos=tuple(li["pos"]), r=li["range"], b=li["brightness"], kind=li["kind"], face=li.get("face"),
                      angle=li.get("angle", 90), rot=li.get("rot", 0) or 0, src="scene"))
for key, x, y, z, rot, sc, *rest in d["props"]:
    if rest and rest[0] == "dark":
        continue
    a = math.radians(rot)
    for li in cat.get(key, {}).get("lights", []):
        lx, ly, lz = li["at"]
        lamps.append(dict(pos=(x + (lx * math.cos(a) + lz * math.sin(a)) * sc, y + ly * sc,
                               z + (-lx * math.sin(a) + lz * math.cos(a)) * sc),
                          r=li["range"], b=li["brightness"], kind=li.get("kind", "point"), face=li.get("face"),
                          angle=li.get("angle", 90), rot=rot, src=key))

def level_at(p):
    x, y, z = p
    total = 0.0
    for L in lamps:
        lx, ly, lz = L["pos"]
        dd = math.dist(p, L["pos"])
        if dd >= L["r"] or dd < 1e-3:
            continue
        if L["kind"] == "spot":
            if L["face"] == "Bottom":
                cosang = (ly - y) / dd
            elif L["face"] == "Top":
                cosang = (y - ly) / dd
            else:
                a = math.radians(L["rot"])
                cosang = ((x - lx) * -math.sin(a) + (z - lz) * -math.cos(a)) / dd
            if cosang < math.cos(math.radians(min(180, L["angle"]) / 2)):
                continue
        total += L["b"] * (1 - dd / L["r"]) ** 2
    return total

zones_in = d["zones"]
if venue == "Agency":
    import importlib.util
    spec = importlib.util.spec_from_file_location("agplan", os.path.join(ROOT, "art", "scripts", "maps", "venues", "agency", "plan.py"))
    P = importlib.util.module_from_spec(spec); spec.loader.exec_module(P)
    zones_in = []
    small = {"security", "observation", "interview_a", "interview_b", "copy", "lockers", "sergeant", "forensics", "lockup", "server", "archive", "training", "director"}
    for level, table in ((P.L1, P.ROOMS_L1), (P.L2, P.ROOMS_L2)):
        for name, poly in table.items():
            zones_in.append(dict(name=name, kind="room" if name in small else "open", poly=[list(q) for q in poly], y0=level, y1=level + 13))
    for name, poly, level in (("lounge", P.LOUNGE, P.L1), ("lobby", P.LOBBY, P.L1), ("bullpen", P.BULLPEN, P.L1), ("analysts", P.ANALYSTS, P.L2), ("ops", P.OPS, P.L2)):
        zones_in.append(dict(name=name, kind="open", poly=[list(q) for q in poly], y0=level, y1=level + 13))
rows = []
for zone in zones_in:
    if not zone.get("name") or zone["kind"] in ("water", "offlimits", "stairs", "track", "park"):
        continue
    poly = zone["poly"]
    lo = min(zone["y0"], zone["y1"])
    xs = [p[0] for p in poly]; zs = [p[1] for p in poly]
    samples = []
    step = 2.0
    gx = math.floor(min(xs)) + 1.0
    while gx < max(xs):
        gz = math.floor(min(zs)) + 1.0
        while gz < max(zs):
            if g2.contains(poly, (gx, gz)):
                samples.append(level_at((gx, lo + 5.0, gz)))
            gz += step
        gx += step
    if not samples:
        continue
    inside = [L for L in lamps if g2.contains(poly, (L["pos"][0], L["pos"][2])) and lo - 1 <= L["pos"][1] <= lo + 30]
    area = len(samples) * step * step
    s = sorted(samples)
    rows.append(dict(name=zone["name"], kind=zone["kind"], floor=lo, area=round(area), lamps=len(inside),
                     scene_lamps=sum(1 for L in inside if L["src"] == "scene"),
                     mean=round(statistics.mean(s), 3), p25=round(s[len(s) // 4], 3), median=round(s[len(s) // 2], 3),
                     dark=round(100 * sum(1 for v in s if v < 0.15) / len(s))))
# merge zones with the same name (a room split in pieces)
merged = {}
for r in rows:
    k = (r["name"], r["kind"], r["floor"])
    if k in merged:
        m = merged[k]; tot = m["area"] + r["area"]
        for f in ("mean", "p25", "median", "dark"):
            m[f] = round((m[f] * m["area"] + r[f] * r["area"]) / tot, 3)
        m["area"] = tot; m["lamps"] += r["lamps"]; m["scene_lamps"] += r["scene_lamps"]
    else:
        merged[k] = dict(r)
rows = sorted(merged.values(), key=lambda r: (r["kind"], r["mean"]))
by_kind = {}
for r in rows:
    by_kind.setdefault(r["kind"], []).append(r["mean"])
print(f"{venue}: {len(lamps)} lamps ({len(d['lights'])} scene)")
print(f"{'zone':38} {'kind':9} {'floor':>5} {'area':>6} {'lamps':>5} {'mean':>6} {'p25':>6} {'dark%':>5}  vs kind median")
for r in rows:
    med = statistics.median(by_kind[r["kind"]])
    ratio = r["mean"] / med if med else 0
    flag = " DARK" if ratio < 0.5 else (" BRIGHT" if ratio > 2.0 else "")
    r["ratio"] = round(ratio, 2)
    print(f"{r['name'][:38]:38} {r['kind'][:9]:9} {r['floor']:5.0f} {r['area']:6} {r['lamps']:5} {r['mean']:6.2f} {r['p25']:6.2f} {r['dark']:5.0f}  x{ratio:.2f}{flag}")
if "--json" in sys.argv:
    json.dump(rows, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)
