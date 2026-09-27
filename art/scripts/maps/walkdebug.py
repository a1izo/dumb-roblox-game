"""Where can you walk from a spot? For finding what cuts a stair, door or bridge off:

    python art/scripts/maps/walkdebug.py Tokyo x y z [radius]

Walks from (x, y, z) inside `radius` studs and prints the heights reached and the edges that
were refused (with the reason) close to the start."""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from maps import check_v2 as C  # noqa: E402


def main():
    venue, x, y, z = sys.argv[1], *map(float, sys.argv[2:5])
    radius = float(sys.argv[5]) if len(sys.argv) > 5 else 40.0
    data = json.load(open(os.path.join(C.SIDECARS, venue + ".json"), encoding="utf-8"))
    world = C.World(data, C.load_catalog())
    G = C.GRID
    si, sj = round(x / G), round(z / G)
    tops = world.tops(si * G, sj * G)
    print("tops at start:", tops)
    if not tops:
        near = [s for s in world.near(x, z) if s.top_at(x, z) is not None]
        for s in near:
            print("  solid", s.kind, round(s.y0, 2), round(s.y1, 2))
        return
    h0 = min(tops, key=lambda h: abs(h - y))
    seen = {(si, sj, h0)}
    stack = [(si, sj, h0)]
    refused = {}
    while stack:
        i, j, h = stack.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ni, nj = i + di, j + dj
            if math.hypot((ni - si) * G, (nj - sj) * G) > radius:
                continue
            nts = world.tops(ni * G, nj * G)
            for nh in nts:
                if (ni, nj, nh) in seen:
                    continue
                if abs(nh - h) > C.STEP:
                    refused.setdefault("step", []).append(((i * G, h, j * G), (ni * G, nh, nj * G)))
                    continue
                if not world.open((i * G, j * G), (ni * G, nj * G), max(h, nh)):
                    refused.setdefault("wall", []).append(((i * G, h, j * G), (ni * G, nh, nj * G)))
                    continue
                seen.add((ni, nj, nh))
                stack.append((ni, nj, nh))
            if not nts:
                refused.setdefault("no floor", []).append(((i * G, h, j * G), (ni * G, None, nj * G)))
    heights = sorted({round(h, 1) for _, _, h in seen})
    print(f"reached {len(seen)} spots; heights {heights[:12]}{' ...' if len(heights) > 12 else ''}")
    for why, edges in refused.items():
        edges.sort(key=lambda e: math.dist((e[0][0], e[0][2]), (x, z)))
        print(f"refused ({why}): {len(edges)}; nearest:")
        for a, b in edges[:8]:
            print("   ", tuple(round(v, 1) if v is not None else None for v in a), "->",
                  tuple(round(v, 1) if v is not None else None for v in b))


if __name__ == "__main__":
    main()
