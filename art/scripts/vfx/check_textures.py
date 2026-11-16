"""The texture check: "small, flat, blurry" as numbers, so a new VFX texture cannot be worse than the bar. Ticket V0.3
of docs/handoff/vfx-rework-plan-2026-11-16.md (Part 3 is the bar, Part 5 the textures this will judge).

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/vfx/check_textures.py [names]
    (any Python with numpy does; it writes nothing)

    names            textures to check (VfxSmoke, or a path to a png); none = every Vfx*.png in the folder
    --dir PATH       the folder of the pngs (default: art/export/textures next to this repo, else the main checkout's)
    --detail         every cell of every texture (fill, edge, tone, step to the next, coverage, islands)
    --table          also print a Markdown table of the numbers (for the plan's Log)
    --calibrate      also require the four known-bad textures (VfxSmoke, VfxWisp, VfxCandleFlame, VfxCrack) to fail
    --selftest       judges made-up arrays with known answers (run it after changing a measuring)
    --no-fail        always exit 0
Exit code 1 when a texture fails (or a calibration/selftest expectation breaks), 0 otherwise.

Per texture, per cell (a flipbook's frame; a single image is one cell):
    fill      the box round alpha over 0.1, as a share of the cell. The texture is judged on its LARGEST cell ("the
              subject fills 80% of its cell at its largest": a one-shot is born small). Fails under 55%.
    edge      any alpha over 0.02 within 3 px of a cell's edge fails (blended frames bleed into each other).
    tone      the spread (standard deviation) of brightness inside alpha over 0.5. Judged on the median over the
              cells that have at least 24 such pixels. Fails under 0.12 (a flat fill).
    motion    (loops and one-shots) the mean change between neighbouring frames: mean of |alpha change| and
              |premultiplied brightness change| over the cell. Fails under 0.01. A loop's last-to-first step must be no
              bigger than LOOP_SLACK times the average step.
    erosion   (one-shots) the share of the cell with alpha over 0.1 must fall by more than half from the start of
              the last third of the frames to the last frame, and the number of separate islands (8-connected, over
              5 px) in the last third at its most must be more than in the fullest frame: it breaks up, it does not
              only fade.
    size      a flipbook sheet is 1024 x 1024 (8 x 8 gives 128 px cells, 4 x 4 gives 256, 2 x 2 gives 512); a single
              image listed with a size must be that size.
The numbers are a floor: passing does not make a texture good, it only rules out the small, flat, still and
bleeding ones. Look at it with preview.py as well.
"""

import os
import sys
from collections import deque

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vfx import draw as D  # noqa: E402  (read_png only; this file never imports textures.py)

# ---------------------------------------------------------------------------------------------------------------------
# What each texture is. grid: 1 for a single image, else the sheet is grid x grid. mode: "loop" (last frame runs into
# the first), "oneshot" (a whole life, erodes at the end), "random" (each cell is a separate pick: no motion, no
# erosion), "single". exempt: checks that do not apply (halos and specks are exempt from fill and tone; beam bands
# reach their edges on purpose). size: the (w, h) in px a single image must be (sheets are always 1024 x 1024).
# The first block is what the game has today (Vfx/Emit.luau's SHEETS give the grids; the rest is read from
# art/scripts/vfx/textures.py); the second block is plan Part 5's names, so a new texture is judged by what it
# declares the day it is made. Change a line only when the texture or the plan changes.
# ---------------------------------------------------------------------------------------------------------------------
SUPPORT = ("fill", "tone")  # halos and specks: round soft dots whose job is to sit behind or round something
BAND = ("fill", "edge")  # laid along a beam or a stretched particle: runs off its cell on purpose
# (a single image that is meant to fill its frame, a page, a feather, a slash, a spike, is exempt from fill and edge
# in its line below: there is no neighbouring frame to bleed into)

DECLARED = {
    # today's textures
    "VfxFlame": dict(grid=8, mode="loop"),
    "VfxCandleFlame": dict(grid=8, mode="loop"),
    "VfxSmoke": dict(grid=8, mode="oneshot"),
    "VfxWisp": dict(grid=4, mode="oneshot"),
    "VfxDust": dict(grid=4, mode="oneshot"),
    "VfxChunk": dict(grid=2, mode="random"),
    "VfxMoth": dict(grid=2, mode="loop"),
    "VfxAsh": dict(grid=4, mode="loop"),
    "VfxGlow": dict(grid=1, mode="single", exempt=SUPPORT),
    "VfxEmber": dict(grid=1, mode="single", exempt=SUPPORT),
    "VfxFlare": dict(grid=1, mode="single", exempt=SUPPORT),
    "VfxStreak": dict(grid=1, mode="single", exempt=SUPPORT + ("edge",)),
    "VfxSpike": dict(grid=1, mode="single", exempt=("fill", "edge")),
    "VfxBurst": dict(grid=1, mode="single"),
    "VfxRing": dict(grid=1, mode="single"),
    "VfxRingBand": dict(grid=1, mode="single", exempt=BAND),
    "VfxColumn": dict(grid=1, mode="single", exempt=BAND),
    "VfxSlash": dict(grid=1, mode="single", exempt=("fill", "edge")),
    "VfxSlashBand": dict(grid=1, mode="single", exempt=BAND),
    "VfxCrack": dict(grid=1, mode="single"),
    "VfxCircle": dict(grid=1, mode="single"),
    "VfxPage": dict(grid=1, mode="single", exempt=("fill", "edge")),
    "VfxFeather": dict(grid=1, mode="single", exempt=("fill", "edge")),
    # plan Part 5 (not made yet)
    "VfxSmokePuff": dict(grid=8, mode="oneshot"),
    "VfxSmokePlume": dict(grid=8, mode="loop"),
    "VfxDustRoll": dict(grid=8, mode="oneshot"),
    "VfxMist": dict(grid=4, mode="loop"),
    "VfxFire": dict(grid=8, mode="loop"),
    "VfxFireBurst": dict(grid=8, mode="oneshot"),
    "VfxCandle": dict(grid=8, mode="loop"),
    "VfxAuraFlame": dict(grid=4, mode="loop"),
    "VfxImpactA": dict(grid=4, mode="oneshot"),
    "VfxImpactB": dict(grid=4, mode="oneshot"),
    "VfxImpactC": dict(grid=4, mode="oneshot"),
    "VfxShock": dict(grid=4, mode="oneshot"),
    "VfxGlint": dict(grid=4, mode="oneshot"),
    "VfxSparks": dict(grid=2, mode="random", exempt=("fill",)),
    "VfxSlashA": dict(grid=4, mode="oneshot"),
    "VfxSlashB": dict(grid=4, mode="oneshot"),
    "VfxArc": dict(grid=4, mode="random"),
    "VfxEnergyWisp": dict(grid=4, mode="loop"),
    "VfxAshFlakes": dict(grid=4, mode="loop"),
    "VfxShards": dict(grid=4, mode="random"),
    "VfxPaper": dict(grid=4, mode="loop"),
    "VfxFeatherTumble": dict(grid=4, mode="loop"),
    "VfxCrackA": dict(grid=1, mode="single", size=(1024, 1024)),
    "VfxCrackB": dict(grid=1, mode="single", size=(1024, 1024)),
    "VfxScorch": dict(grid=1, mode="single", size=(1024, 1024)),
    "VfxSigil": dict(grid=1, mode="single", size=(1024, 1024)),
}
UNLISTED = dict(grid=1, mode="single")  # a texture this table does not know is judged as a single image

# the limits (plan V0.3)
FILL_MIN = 0.55
FILL_ALPHA = 0.1
EDGE_PX = 3
EDGE_ALPHA = 0.02
TONE_MIN = 0.12
TONE_ALPHA = 0.5
TONE_MIN_PIXELS = 24
MOTION_MIN = 0.01
LOOP_SLACK = 1.5  # the wrap step may be this many times the average step (a smooth loop's wrap is the average, give
#                   or take noise; the plan says "no bigger than the average", which half of all good loops would miss)
ERODE_FALL = 0.5  # coverage at the last frame must be under this share of coverage at the start of the last third
ISLAND_MIN_PX = 5
SHEET_PX = 1024

# the four textures that must fail today (the plan's calibration, as the motion report was): name -> the check that
# the plan's own numbers say fails it
CALIBRATION = {"VfxSmoke": "fill", "VfxWisp": "fill", "VfxCandleFlame": "fill", "VfxCrack": "tone"}

CHECKS = ("size", "fill", "edge", "tone", "motion", "erosion")


def default_dir():
    here = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    for cand in (os.path.join(here, "export", "textures"),
                 os.path.join("C:\\Users\\negru\\Documents\\Lgame", "art", "export", "textures")):
        if os.path.isdir(cand):
            return cand
    return os.path.join(here, "export", "textures")


# ---------------------------------------------------------------------------------------------------------------------
# Measuring one cell. A cell is an (h, w, 4) float array, straight alpha.
# ---------------------------------------------------------------------------------------------------------------------


def cells_of(img, grid):
    h, w = img.shape[:2]
    if grid <= 1:
        return [img]
    ch, cw = h // grid, w // grid
    return [img[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] for r in range(grid) for c in range(grid)]


def fill_of(cell):
    """The box round alpha over 0.1, as a share of the cell."""
    ys, xs = np.nonzero(cell[..., 3] > FILL_ALPHA)
    if len(ys) == 0:
        return 0.0
    box = (ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)
    return float(box) / (cell.shape[0] * cell.shape[1])


def edge_of(cell):
    """The largest alpha within EDGE_PX of the cell's edge (a cell fails when it is over EDGE_ALPHA)."""
    a = cell[..., 3]
    m = EDGE_PX
    band = np.concatenate([a[:m].ravel(), a[-m:].ravel(), a[m:-m, :m].ravel(), a[m:-m, -m:].ravel()])
    return float(band.max()) if band.size else 0.0


def luma(cell):
    return cell[..., :3].mean(axis=2)


def tone_of(cell):
    """(spread of brightness inside alpha over 0.5, how many such pixels). The spread is None with too few pixels."""
    solid = cell[..., 3] > TONE_ALPHA
    n = int(solid.sum())
    if n < TONE_MIN_PIXELS:
        return None, n
    return float(luma(cell)[solid].std()), n


def coverage_of(cell):
    return float((cell[..., 3] > FILL_ALPHA).mean())


def islands_of(cell):
    """The number of separate islands (8-connected) of alpha over 0.1, ignoring those of ISLAND_MIN_PX or fewer."""
    mask = cell[..., 3] > FILL_ALPHA
    h, w = mask.shape
    seen = np.zeros_like(mask)
    count = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        seen[y0, x0] = True
        size = 0
        todo = deque([(y0, x0)])
        while todo:
            y, x = todo.popleft()
            size += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        todo.append((ny, nx))
        if size > ISLAND_MIN_PX:
            count += 1
    return count


def step_between(a, b):
    """The change from cell a to cell b: mean of |alpha change| and |premultiplied brightness change|."""
    pa, pb = luma(a) * a[..., 3], luma(b) * b[..., 3]
    return float((np.abs(a[..., 3] - b[..., 3]).mean() + np.abs(pa - pb).mean()) / 2)


# ---------------------------------------------------------------------------------------------------------------------
# Judging one texture
# ---------------------------------------------------------------------------------------------------------------------


def judge(img, spec):
    """Measures and judges an (h, w, 4) image against its declaration. Returns a dict: per-cell lists, the aggregates,
    `fails` (check name -> why) and `skipped` (checks that do not apply)."""
    grid, mode = spec["grid"], spec["mode"]
    exempt = set(spec.get("exempt", ()))
    h, w = img.shape[:2]
    cells = cells_of(img, grid)
    n = len(cells)
    out = {"w": w, "h": h, "grid": grid, "mode": mode, "n": n, "fails": {}, "skipped": []}

    fills = [fill_of(c) for c in cells]
    edges = [edge_of(c) for c in cells]
    tones = [tone_of(c) for c in cells]
    covs = [coverage_of(c) for c in cells]
    out.update(fills=fills, edges=edges, tones=tones, covs=covs)
    out["fill_max"], out["fill_mean"] = max(fills), float(np.mean(fills))
    out["edge_cells"] = [k for k, e in enumerate(edges) if e > EDGE_ALPHA]
    spreads = [t[0] for t in tones if t[0] is not None]
    out["tone_median"] = float(np.median(spreads)) if spreads else None
    out["tone_mean"] = float(np.mean(spreads)) if spreads else None

    # size
    sheet_px = spec.get("sheet_px", SHEET_PX)  # (the self-test's small made-up sheets say None)
    if grid > 1 and sheet_px is None:
        out["skipped"].append("size")
    elif grid > 1:
        if (w, h) != (sheet_px, sheet_px):
            out["fails"]["size"] = f"sheet is {w} x {h}, must be {sheet_px} x {sheet_px}"
    elif spec.get("size") and (w, h) != tuple(spec["size"]):
        out["fails"]["size"] = f"image is {w} x {h}, must be {spec['size'][0]} x {spec['size'][1]}"
    else:
        out["skipped"].append("size")

    # fill
    if "fill" in exempt:
        out["skipped"].append("fill")
    elif out["fill_max"] < FILL_MIN:
        out["fails"]["fill"] = f"largest cell fills {out['fill_max']:.0%} (mean {out['fill_mean']:.0%}), under {FILL_MIN:.0%}"

    # edge
    if "edge" in exempt:
        out["skipped"].append("edge")
    elif out["edge_cells"]:
        cells_txt = ",".join(str(k + 1) for k in out["edge_cells"][:8]) + ("..." if len(out["edge_cells"]) > 8 else "")
        out["fails"]["edge"] = (f"{len(out['edge_cells'])} of {n} cells have alpha over {EDGE_ALPHA} within "
                                f"{EDGE_PX} px of the edge (largest {max(edges):.2f}; cells {cells_txt})")

    # tone
    if "tone" in exempt:
        out["skipped"].append("tone")
    elif out["tone_median"] is None:
        out["fails"]["tone"] = f"no cell has {TONE_MIN_PIXELS} pixels over alpha {TONE_ALPHA}: nothing solid"
    elif out["tone_median"] < TONE_MIN:
        out["fails"]["tone"] = f"brightness spread {out['tone_median']:.3f} (median over cells), under {TONE_MIN}"

    # motion
    steps = []
    if mode in ("loop", "oneshot") and n > 1:
        steps = [step_between(cells[k], cells[k + 1]) for k in range(n - 1)]
        out["steps"] = steps
        out["step_mean"] = float(np.mean(steps))
        if out["step_mean"] < MOTION_MIN:
            out["fails"]["motion"] = f"mean step between frames {out['step_mean']:.4f}, under {MOTION_MIN}: does not move"
        elif mode == "loop":
            wrap = step_between(cells[-1], cells[0])
            out["wrap"] = wrap
            if wrap > LOOP_SLACK * out["step_mean"]:
                out["fails"]["motion"] = (f"last frame to first steps {wrap:.4f}, over {LOOP_SLACK} x the average "
                                          f"{out['step_mean']:.4f}: the loop jumps")
    else:
        out["skipped"].append("motion")

    # erosion
    if mode == "oneshot" and n >= 6:
        third = n - n // 3
        start, last = covs[third], covs[-1]
        out["cov_start"], out["cov_end"] = start, last
        body = int(np.argmax(covs))
        isl = [islands_of(c) for c in cells]
        out["islands"] = isl
        tail_isl = max(isl[third:])
        out["isl_body"], out["isl_tail"] = isl[body], tail_isl
        why = []
        if start > 0 and last >= ERODE_FALL * start:
            why.append(f"coverage goes {start:.0%} to {last:.0%} over the last third, not under half")
        if tail_isl <= isl[body]:
            why.append(f"islands go {isl[body]} (fullest frame) to {tail_isl} (last third at most): it does not break up")
        if why:
            out["fails"]["erosion"] = "; ".join(why)
    else:
        out["skipped"].append("erosion")
    return out


def judge_file(path, name=None):
    name = name or os.path.splitext(os.path.basename(path))[0]
    spec = DECLARED.get(name)
    declared = spec is not None
    spec = spec or UNLISTED
    img = D.read_png(path)
    r = judge(img, spec)
    r["name"], r["declared"] = name, declared
    return r


# ---------------------------------------------------------------------------------------------------------------------
# Printing
# ---------------------------------------------------------------------------------------------------------------------


def cell_txt(r, key, fmt):
    v = r.get(key)
    return "-" if v is None else fmt % v


def row(r):
    verdict = "FAIL" if r["fails"] else "PASS"
    skipped = [c for c in ("fill", "edge", "tone") if c in r["skipped"]]
    if not r["fails"] and skipped:
        verdict = "PASS (exempt: " + ", ".join(skipped) + ")"  # only what is not exempt was looked at
    erosion = "-"
    if "cov_start" in r:
        erosion = f"cov {r['cov_start']:.0%}>{r['cov_end']:.0%} isl {r['isl_body']}>{r['isl_tail']}"
    motion = "-"
    if "step_mean" in r:
        motion = f"{r['step_mean']:.3f}"
        if "wrap" in r:
            motion += f" wrap {r['wrap']:.3f}"
    edge = "-" if "edge" in r["skipped"] else f"{len(r['edge_cells'])}/{r['n']}"
    fill = "-" if "fill" in r["skipped"] else f"{r['fill_max']:.0%} ({r['fill_mean']:.0%})"
    tone = "-" if "tone" in r["skipped"] else cell_txt(r, "tone_median", "%.3f")
    size = f"{r['w']}x{r['h']}"
    kind = "single" if r["grid"] == 1 else f"{r['grid']}x{r['grid']} {r['mode']}"
    return [r["name"] + ("" if r["declared"] else " (undeclared)"), kind, size, fill, edge, tone, motion, erosion,
            verdict + ("" if not r["fails"] else " <- " + ", ".join(c for c in CHECKS if c in r["fails"]))]


HEAD = ["texture", "kind", "size", "fill max (mean)", "edge cells", "tone", "motion", "erosion", "verdict"]


def print_rows(rows):
    widths = [max(len(HEAD[i]), *(len(r[i]) for r in rows)) for i in range(len(HEAD))]
    line = "  ".join(HEAD[i].ljust(widths[i]) for i in range(len(HEAD)))
    print(line)
    print("  ".join("-" * widths[i] for i in range(len(HEAD))))
    for r in rows:
        print("  ".join(r[i].ljust(widths[i]) for i in range(len(HEAD))))


def print_markdown(rows):
    print("| " + " | ".join(HEAD) + " |")
    print("|" + "---|" * len(HEAD))
    for r in rows:
        print("| " + " | ".join(c.replace("|", "/") for c in r) + " |")


def print_detail(r):
    print(f"\n{r['name']}: {r['w']} x {r['h']}, {r['n']} cell(s), {r['mode']}")
    print("  cell   fill   edge  tone   solid  coverage  islands  step->next")
    for k in range(r["n"]):
        spread, solid = r["tones"][k]
        step = r["steps"][k] if "steps" in r and k < len(r["steps"]) else None
        isl = r["islands"][k] if "islands" in r else None
        print("  %4d  %4.0f%%  %5.2f  %s  %5d  %7.0f%%  %7s  %s" % (
            k + 1, r["fills"][k] * 100, r["edges"][k], "  -  " if spread is None else "%.3f" % spread, solid,
            r["covs"][k] * 100, "-" if isl is None else isl, "-" if step is None else "%.4f" % step))


def print_reasons(results):
    for r in results:
        for check in CHECKS:
            if check in r["fails"]:
                print(f"  {r['name']}: {check}: {r['fails'][check]}")


# ---------------------------------------------------------------------------------------------------------------------
# The self-test: made-up arrays with known answers
# ---------------------------------------------------------------------------------------------------------------------


def _disc(cell, radius, cy=None, cx=None):
    yy, xx = np.mgrid[0:cell, 0:cell]
    cy = cell / 2 if cy is None else cy
    cx = cell / 2 if cx is None else cx
    return np.hypot(yy + 0.5 - cy, xx + 0.5 - cx) <= radius


def _noise(cell, seed, block=6):
    """Smooth-ish random field 0..1 (blocks of random numbers, stretched), so thresholding it makes holes and islands."""
    rng = np.random.default_rng(seed)
    small = rng.random((cell // block + 1, cell // block + 1))
    big = np.kron(small, np.ones((block, block)))[:cell, :cell]
    return big


def _frame(alpha, value=0.8):
    out = np.zeros(alpha.shape + (4,), dtype=np.float32)
    out[..., :3] = np.clip(value, 0, 1)[..., None] if np.ndim(value) else value
    out[..., 3] = alpha
    return out


def _sheet(frames, grid):
    return D.sheet(frames, grid)


def good_oneshot(cell=64, grid=4):
    """A whole life that should pass everything: a big shaded disc that wobbles, fills by a fifth, and from the half is
    eaten into islands by a rising threshold."""
    n = grid * grid
    yy, xx = np.mgrid[0:cell, 0:cell]
    shade = np.clip(1.15 - 1.3 * np.hypot(yy - cell * 0.3, xx - cell * 0.3) / cell, 0.1, 1)  # lit from the top left
    field = _noise(cell, 5, 5)
    frames = []
    for k in range(n):
        life = k / (n - 1)
        radius = cell * (0.1 + 0.3 * min(1.0, life * 5)) + 0.6 * np.sin(k * 1.3)
        shape = _disc(cell, radius, cell / 2 + np.sin(k * 0.7) * 1.2, cell / 2 + np.cos(k * 0.9) * 1.2)
        cut = max(0.0, (life - 0.5) * 2.2)  # the threshold that eats it from the half on
        alive = shape & (field > cut)
        frames.append(_frame(alive.astype(np.float32), shade))
    return _sheet(frames, grid)


def selftest():
    failures = []

    def expect(label, cond):
        if not cond:
            failures.append(label)
        print(("  ok   " if cond else "  FAIL ") + label)

    def verdict(img, **spec):
        base = dict(grid=4, mode="oneshot", sheet_px=None)
        base.update(spec)
        return judge(img, base)

    # the measuring pieces, on arrays whose answers are known
    square = np.zeros((100, 100, 4), dtype=np.float32)
    square[20:70, 30:80, 3] = 1.0  # a 50 x 50 square
    expect("fill: a 50 x 50 square in 100 x 100 is exactly 25%", abs(fill_of(square) - 0.25) < 1e-9)
    plus = np.zeros((100, 100, 4), dtype=np.float32)
    plus[45:55, 10:90, 3] = 1.0
    plus[10:90, 45:55, 3] = 1.0
    expect("fill: a plus sign counts its whole box (64%)", abs(fill_of(plus) - 0.64) < 1e-9)
    expect("fill: an empty cell is 0", fill_of(np.zeros((8, 8, 4), dtype=np.float32)) == 0.0)
    faint = np.zeros((100, 100, 4), dtype=np.float32)
    faint[:, :, 3] = 0.05
    expect("fill: alpha under 0.1 does not count", fill_of(faint) == 0.0)

    e1 = np.zeros((64, 64, 4), dtype=np.float32)
    e1[30:34, 61, 3] = 0.5  # 3 px from the right edge's last column (columns 61..63 are the margin)
    e2 = np.zeros((64, 64, 4), dtype=np.float32)
    e2[30:34, 60, 3] = 0.5  # one column further in: clear of the margin
    expect("edge: alpha 0.5 inside the 3 px margin is seen", edge_of(e1) == 0.5)
    expect("edge: alpha just clear of the margin is not", edge_of(e2) == 0.0)

    two = np.zeros((64, 64, 4), dtype=np.float32)
    two[10:20, 10:20, 3] = 1.0
    two[40:50, 40:50, 3] = 1.0
    two[30, 30, 3] = 1.0  # a single speck: ignored
    expect("islands: two blocks and a speck count as 2", islands_of(two) == 2)
    diag = np.zeros((64, 64, 4), dtype=np.float32)
    diag[10:14, 10:14, 3] = 1.0
    diag[14:18, 14:18, 3] = 1.0  # touching at a corner: one island under 8-connection
    expect("islands: blocks touching at a corner are one", islands_of(diag) == 1)

    flatcell = _frame(np.ones((32, 32), dtype=np.float32), 0.6)
    expect("tone: a flat fill has spread 0", tone_of(flatcell)[0] == 0.0)
    ramp = _frame(np.ones((32, 32), dtype=np.float32), np.tile(np.linspace(0, 1, 32), (32, 1)))
    expect("tone: a ramp 0..1 has spread near 0.29", abs(tone_of(ramp)[0] - 0.2887) < 0.01)
    expect("tone: too few solid pixels gives None", tone_of(_frame(np.zeros((32, 32), dtype=np.float32)))[0] is None)

    a = _frame(np.full((8, 8), 0.4, dtype=np.float32), 1.0)
    b = _frame(np.full((8, 8), 0.5, dtype=np.float32), 1.0)
    # alpha change 0.1; premultiplied brightness 0.4 to 0.5: change 0.1; mean 0.1
    expect("motion: a step of 0.1 in alpha at full brightness measures 0.1", abs(step_between(a, b) - 0.1) < 1e-6)

    # whole sheets
    good = good_oneshot()
    r = verdict(good)
    print("      good one-shot: " + (", ".join(f"{c} {v}" for c, v in r["fails"].items()) or "no failures"))
    expect("a big shaded moving disc that erodes into islands passes everything", not r["fails"])

    def disc_sheet(radius, shade=None, move=True, cell=64, grid=4):
        yy, xx = np.mgrid[0:cell, 0:cell]
        fr = []
        for k in range(grid * grid):
            s = _disc(cell, radius + (0.8 * np.sin(k) if move else 0))
            v = shade if shade is not None else (0.3 + 0.7 * (xx / cell))
            fr.append(_frame(s.astype(np.float32), v))
        return _sheet(fr, grid)

    r = verdict(disc_sheet(10), mode="loop")
    expect("a small subject fails fill", "fill" in r["fails"])
    r = verdict(disc_sheet(24, shade=0.7), mode="loop")
    expect("a flat grey fill fails tone", "tone" in r["fails"] and "fill" not in r["fails"])
    r = verdict(disc_sheet(36), mode="loop")
    expect("a subject that runs to the cell's edge fails edge", "edge" in r["fails"])
    r = verdict(disc_sheet(24, move=False), mode="loop")
    expect("a flipbook of identical frames fails motion", "motion" in r["fails"])
    r = verdict(disc_sheet(24), mode="loop")
    expect("a shaded, moving disc loop passes motion, fill, tone and edge", not r["fails"])
    r = verdict(disc_sheet(24, move=False), mode="random")
    expect("a random sheet is not judged on motion or erosion", "motion" not in r["fails"] and "erosion" not in r["fails"])

    # a loop whose last frame jumps back
    cell, grid = 64, 4
    fr = []
    yy, xx = np.mgrid[0:cell, 0:cell]
    for k in range(grid * grid):
        s = _disc(cell, 24, cell / 2, 14 + k * 2.4)  # slides right a little each frame
        fr.append(_frame(s.astype(np.float32), 0.3 + 0.7 * (xx / cell)))
    r = verdict(_sheet(fr, grid), mode="loop")
    expect("a loop whose last frame is far from the first fails the wrap", "motion" in r["fails"] and "wrap" in r)
    r = verdict(_sheet(fr, grid), mode="oneshot")
    expect("the same frames as a one-shot are not judged on the wrap", "motion" not in r["fails"])

    # fade only: the good life but alpha scaled down (it never breaks up)
    yy, xx = np.mgrid[0:cell, 0:cell]
    fr = []
    for k in range(grid * grid):
        life = k / (grid * grid - 1)
        s = _disc(cell, 24 + 0.8 * np.sin(k)).astype(np.float32)
        fade = 1.0 if life < 0.6 else max(0.0, 1 - (life - 0.6) / 0.35)
        fr.append(_frame(s * fade * 0.95, 0.3 + 0.7 * (xx / cell)))
    r = verdict(_sheet(fr, grid))
    expect("a one-shot that only fades fails erosion", "erosion" in r["fails"])

    # erosion that falls but never breaks into more islands: shrinks as one disc
    fr = []
    for k in range(grid * grid):
        life = k / (grid * grid - 1)
        rad = 28 if life < 0.5 else max(1.0, 28 * (1 - (life - 0.5) * 2))
        fr.append(_frame(_disc(cell, rad).astype(np.float32), 0.3 + 0.7 * (xx / cell)))
    r = verdict(_sheet(fr, grid))
    expect("a one-shot that shrinks as one blob fails erosion (no more islands)", "erosion" in r["fails"])

    # size
    r = judge(good, dict(grid=4, mode="oneshot"))
    expect("a 256 x 256 sheet fails size", "size" in r["fails"])
    r = judge(np.zeros((1024, 1024, 4), dtype=np.float32), dict(grid=8, mode="loop"))
    expect("a 1024 x 1024 sheet does not fail size", "size" not in r["fails"])
    big = np.zeros((1024, 1024, 4), dtype=np.float32)
    expect("a single image declared 1024 but 512 fails size",
           "size" in judge(big[:512, :512], dict(grid=1, mode="single", size=(1024, 1024)))["fails"])
    expect("a single image declared 1024 and 1024 does not fail size",
           "size" not in judge(big, dict(grid=1, mode="single", size=(1024, 1024)))["fails"])
    expect("an exempt check is skipped", "fill" in judge(disc_sheet(10), dict(grid=4, mode="loop", exempt=("fill",)))["skipped"])

    print("[check_textures selftest]", "PASS" if not failures else "FAIL: " + "; ".join(failures))
    return not failures


# ---------------------------------------------------------------------------------------------------------------------


def main(argv):
    names, folder = [], None
    detail = table = calibrate = no_fail = False
    k = 0
    while k < len(argv):
        arg = argv[k]
        if arg == "--dir":
            folder = argv[k + 1]
            k += 2
            continue
        if arg == "--detail":
            detail = True
        elif arg == "--table":
            table = True
        elif arg == "--calibrate":
            calibrate = True
        elif arg == "--no-fail":
            no_fail = True
        elif arg == "--selftest":
            return 0 if selftest() else 1
        elif arg in ("-h", "--help"):
            print(__doc__)
            return 0
        elif arg.startswith("--"):
            print("unknown option", arg)
            return 2
        else:
            names.append(arg)
        k += 1

    folder = folder or default_dir()
    paths = []
    if names:
        for nm in names:
            p = nm if nm.lower().endswith(".png") else os.path.join(folder, nm + ".png")
            if not os.path.isfile(p):
                print("no such texture:", p)
                return 2
            paths.append(p)
    else:
        if not os.path.isdir(folder):
            print("no textures folder:", folder)
            return 2
        paths = [os.path.join(folder, f) for f in sorted(os.listdir(folder)) if f.startswith("Vfx") and f.endswith(".png")]
    if not paths:
        print("no Vfx*.png in", folder)
        return 2

    print("[check_textures]", folder, "(%d textures)" % len(paths))
    results = [judge_file(p) for p in paths]
    rows = [row(r) for r in results]
    print_rows(rows)
    failing = [r for r in results if r["fails"]]
    print()
    print(f"{len(results) - len(failing)} pass, {len(failing)} fail")
    if failing:
        print("why:")
        print_reasons(failing)
    if detail:
        for r in results:
            print_detail(r)
    if table:
        print()
        print_markdown(rows)

    bad = bool(failing)
    if calibrate:
        # the four are expected to fail, so with --calibrate the exit code says whether they do (and nothing else)
        by = {r["name"]: r for r in results}
        print("\ncalibration (these four must fail):")
        bad = False
        for name, check in CALIBRATION.items():
            r = by.get(name)
            if r is None:
                print(f"  {name}: not in this run")
                bad = True
                continue
            ok = check in r["fails"]
            print(f"  {name}: {'fails ' + check if ok else 'DOES NOT FAIL ' + check} ({r['fails'].get(check, 'no failure')})")
            bad = bad or not ok
    return 0 if (no_fail or not bad) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
