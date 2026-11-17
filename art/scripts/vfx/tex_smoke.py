"""The VFX library's matter textures, group V1.1 (plan Part 5): VfxSmokePuff, VfxSmokePlume, VfxDustRoll, VfxMist.

Route S: a Blender gas (smoke) simulation is baked headless (Mantaflow, cache in a scratch folder),
the baked density is read out of the cache's OpenVDB files, and each frame is lit and rendered here in numpy: an
orthographic ray-march from the side with the sun above and to one side (so the top is lit and the belly is in its own
shadow), then reframed, eroded where a one-shot has to break into islands, closed into a loop where a loop is wanted,
and packed into a 1024 x 1024 sheet with vfx/draw.py. White and grey, so the game tints it; the grey is the smoke's own
light and shade. (Why not Cycles: a headless Cycles render of the fluid domain showed nothing from the baked cache, so
the baked density is rendered by this file's own ray-marcher. The simulation itself is Blender's.)
VfxMist and VfxDustRoll are the exceptions: the mist is a layered 3D noise volume whose noise drifts a whole period
per loop (it closes exactly), and the dust is a made-up cast of billowing cloudlets flown out along the floor (six
baked sims of a floor burst all rolled up instead of along). Neither is a simulation; both are lit and packed by the
same code.

    blender -b --factory-startup --python art/scripts/vfx/tex_smoke.py -- [names] [--sim] [--post] [--cache DIR]

    names     which of the four (default all)
    --sim     bake and read out the density (needs Blender; writes <cache>/<name>/dens_NNNN.npy)
    --post    render, frame and pack from the density already in the cache (plain Python with numpy is enough)
    --quick   half the grid, to try a setting (use its own --cache folder; the PNGs it writes are not final)
    --cache   the scratch folder (default: the system temp folder / vfx_smoke_cache)
    --look    also write pictures into <cache> to look at (over dark and over light, tinted)
    --out DIR write the PNGs there instead of art/export/textures
With neither --sim nor --post it does both.
"""

import json
import math
import os
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vfx import draw as D  # noqa: E402
from vfx import noise as N  # noqa: E402

try:
    import bpy  # noqa: E402
except ImportError:  # --post runs without Blender
    bpy = None

TEXTURES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "export",
                        "textures")
SHEET = 1024


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=np.float32) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------------------------------
# What each texture is: the simulation (Blender side) and the look (render and pack side)
# ---------------------------------------------------------------------------------------------------------------------

SIM = {}

SIM["VfxSmokePuff"] = dict(
    grid=8, mode="oneshot", cell=128,
    sim=dict(
        domain_scale=(1.0, 1.0, 1.0), res=128, vorticity=0.35, buoy_density=1.0, buoy_heat=0.2, time_scale=1.3,
        dissolve=0, frames=64,
        flows=[dict(pos=(0.0, 0.0, -0.1), radius=0.28, density=1.0, temperature=0.15, v_normal=4.5, v_random=1.0,
                    on=1, off=11, grow=(1, 9, 0.2, 1.0))],
        forces=[dict(type="TURBULENCE", strength=0.8, size=0.3, flow=0.5)],
    ),
    look=dict(
        sigma=lambda life: 0.20, blur=1, lump=(0.9, 1.4), blur_after=1, follow="xy",
        erode=lambda life: 0.0 if life < 0.4 else 1.9 * ((life - 0.4) / 0.6) ** 1.3,
    ),
)

SIM["VfxSmokePlume"] = dict(
    grid=8, mode="loop", cell=128,
    sim=dict(
        domain_scale=(1.0, 0.7, 1.0), res=128, vorticity=0.8, buoy_density=1.0, buoy_heat=1.3, time_scale=1.0,
        dissolve=0, frames=140,
        flows=[dict(pos=(0.0, 0.0, -0.9), radius=0.17, scale=(1.0, 1.0, 0.6), density=1.0, temperature=1.4,
                    v_coord=(0.0, 0.0, 1.6), on=1)],
        forces=[dict(type="TURBULENCE", strength=1.2, size=0.4, flow=0.4)],
    ),
    look=dict(
        sigma=lambda life: 0.085, take=(56, 84), loop=(64, 20), blur=1, lump_rise=(1.0, 30.0, 2), blur_after=1,
        stretch_x=1.2,
    ),
)

SIM["VfxDustRoll"] = dict(
    # NOT a gas simulation (said in the Log): six baked sims of a floor burst (a ball, jets, jets under a ceiling,
    # slumping blocks) all rolled the dust up into lobes or a bush, or slumped it into a film. So this is the volume
    # route: a slam at the left sends a rolling wave to the right. The head is a ring of cloudlets orbiting a core
    # (a torus seen from the side, the top turning forward), a low tapering body is left behind with wisps, spray
    # stands over the head, and the rising cut eats it into islands. Lit and packed like the others.
    grid=8, mode="oneshot", cell=128, procedural="dust", frames=64, dims=(240, 36, 152),
    look=dict(
        sigma=lambda life: 0.24, sun=1.0, amb=0.55, fill=0.18, k_sun=0.5, k_amb=0.12, follow="floor", fit=0.92,
        box_alpha=0.15,
    ),
)

SIM["VfxMist"] = dict(
    # (not a gas simulation: fog does not come out of one. A baked smoke sim of a fog bank came out as cigarette
    # streaks, so the bank is a 3D noise volume whose noise orbits through space, which closes the loop exactly.)
    grid=4, mode="loop", cell=256, procedural=True, frames=16, dims=(192, 16, 172),
    look=dict(sigma=lambda life: 0.11, sun=1.0, amb=0.9, fill=0.55, k_sun=0.13, k_amb=0.05, fit=0.97, tone=(0.28, 1.0), box_alpha=0.1, flatten=(0.0, 0.6),
        calm_thin=(0.08, 0.5)),
)


# ---------------------------------------------------------------------------------------------------------------------
# Blender side: the gas simulation, baked headless, read out of the OpenVDB cache
# ---------------------------------------------------------------------------------------------------------------------


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = 1, 250
    return scene


def build_domain(sim, cache):
    bpy.ops.mesh.primitive_cube_add(size=2.0)
    dom = bpy.context.active_object
    dom.name = "Domain"
    dom.scale = tuple(sim["domain_scale"])
    mod = dom.modifiers.new("Fluid", "FLUID")
    mod.fluid_type = "DOMAIN"
    ds = mod.domain_settings
    ds.domain_type = "GAS"
    ds.cache_type = "ALL"  # (the default, REPLAY, bakes one frame headless)
    ds.cache_data_format = "OPENVDB"
    ds.cache_directory = cache
    ds.cache_frame_start, ds.cache_frame_end = 1, sim["frames"]
    ds.resolution_max = sim["res"]
    ds.use_noise = False  # (Mantaflow's noise upres writes empty grids when baked headless: more base resolution
    #                        instead)
    ds.vorticity = sim.get("vorticity", 0.3)
    ds.alpha = sim.get("buoy_density", 1.0)
    ds.beta = sim.get("buoy_heat", 1.0)
    ds.use_dissolve_smoke = sim.get("dissolve", 0) > 0
    if ds.use_dissolve_smoke:
        ds.dissolve_speed = sim["dissolve"]
        ds.use_dissolve_smoke_log = True
    for side in ("front", "back", "right", "left", "top", "bottom"):
        setattr(ds, f"use_collision_border_{side}",
                (side == "bottom" and sim.get("floor", False)) or (side == "top" and sim.get("ceiling", False)))
    ds.use_adaptive_timesteps = True
    ds.cfl_condition = sim.get("cfl", 4.0)
    for k, v in sim.get("domain", {}).items():
        setattr(ds, k, v)
    return dom


def add_flows(sim):
    for f in sim["flows"]:
        kind = f.get("shape", "sphere")
        if kind == "sphere":
            bpy.ops.mesh.primitive_ico_sphere_add(radius=f["radius"], subdivisions=3, location=f["pos"])
        elif kind == "disc":
            bpy.ops.mesh.primitive_cylinder_add(radius=f["radius"], depth=f.get("depth", 0.04), location=f["pos"],
                                                vertices=24)
        elif kind == "torus":
            bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=f.get("minor", 0.28), major_segments=48,
                                             minor_segments=16, location=f["pos"])
        elif kind == "box":
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=f["pos"])
            bpy.context.active_object.scale = f["size"]
        obj = bpy.context.active_object
        obj.name = f.get("name", "Flow")
        base = tuple(f.get("scale", f.get("size", (1.0, 1.0, 1.0))))
        obj.scale = base
        if "grow" in f:  # (frame0, frame1, s0, s1): the source swells (a puff is born small; a ring spreads out)
            f0, f1, s0, s1 = f["grow"]
            for fr, sc in ((f0, s0), (f1, s1)):
                obj.scale = tuple(b * sc for b in base)
                obj.keyframe_insert("scale", frame=fr)
            for fcu in obj.animation_data.action.fcurves if hasattr(obj.animation_data.action, "fcurves") else []:
                for kp in fcu.keyframe_points:
                    kp.interpolation = "SINE"
        mod = obj.modifiers.new("Fluid", "FLUID")
        mod.fluid_type = "FLOW"
        fs = mod.flow_settings
        fs.flow_type = "SMOKE"
        fs.flow_behavior = "INFLOW"
        fs.flow_source = "MESH"
        fs.smoke_color = (1, 1, 1)
        fs.density = f.get("density", 1.0)
        fs.temperature = f.get("temperature", 1.0)
        fs.surface_distance = f.get("surface", 1.5)
        fs.use_initial_velocity = True
        fs.velocity_normal = f.get("v_normal", 0.0)
        fs.velocity_factor = f.get("v_factor", 1.0)
        fs.velocity_random = f.get("v_random", 0.0)
        if "v_coord" in f:
            fs.velocity_coord = f["v_coord"]
        fs.subframes = f.get("subframes", 1)
        on, off = f.get("on", 1), f.get("off")
        fs.use_inflow = True
        fs.keyframe_insert("use_inflow", frame=on)
        if off:
            fs.use_inflow = False
            fs.keyframe_insert("use_inflow", frame=off)


def add_forces(sim):
    for f in sim.get("forces", []):
        bpy.ops.object.effector_add(type=f["type"], location=f.get("pos", (0, 0, 0)))
        obj = bpy.context.active_object
        fld = obj.field
        fld.strength = f["strength"]
        for fr, val in f.get("keys", []):  # (frame, strength): a blast that is on for a few frames only
            fld.strength = val
            fld.keyframe_insert("strength", frame=fr)
        for key in ("size", "flow", "noise", "seed"):
            if key in f:
                setattr(fld, key, f[key])
        for k, v in f.get("props", {}).items():
            setattr(fld, k, v)
        if "rot" in f:
            obj.rotation_euler = tuple(math.radians(a) for a in f["rot"])


def bake_all(dom, sim, work):
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, sim["frames"]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = dom
    dom.select_set(True)
    bpy.ops.fluid.bake_data()


def read_density(path, dims):
    import openvdb as vdb

    g = vdb.read(path, "density")
    arr = np.zeros(dims, dtype=np.float32)
    g.copyToArray(arr, ijk=(0, 0, 0))
    return arr


def simulate(name, cache):
    spec = SIM[name]
    if spec.get("procedural"):
        return  # nothing to bake
    sim = spec["sim"]
    work = os.path.join(cache, name)
    bakedir = os.path.join(work, "bake")
    os.makedirs(work, exist_ok=True)
    new_scene()
    dom = build_domain(sim, bakedir)
    add_flows(sim)
    add_forces(sim)
    bake_all(dom, sim, work)
    # the grid's size: the largest side is res, the others follow the domain's shape
    big = max(sim["domain_scale"])
    dims = tuple(max(4, int(round(sim["res"] * s / big))) for s in sim["domain_scale"])
    folder, fmt = "data", "fluid_data_%04d.vdb"
    print(f"[tex_smoke] {name}: grid {dims}")
    for k in range(1, sim["frames"] + 1):
        arr = read_density(os.path.join(bakedir, folder, fmt % k), dims)
        np.save(os.path.join(work, "dens_%04d.npy" % k), arr.astype(np.float16))
    json.dump({"dims": dims, "scale": sim["domain_scale"], "frames": sim["frames"]},
              open(os.path.join(work, "meta.json"), "w"))


# ---------------------------------------------------------------------------------------------------------------------
# Numpy side: light and render the baked density
# ---------------------------------------------------------------------------------------------------------------------


def shift2d(a, sx, sy):
    """out[i, j] = a[i + sx, j + sy] (bilinear, zero outside), for the light's slant across a slice."""
    out = np.zeros_like(a)
    fx, fy = math.floor(sx), math.floor(sy)
    tx, ty = sx - fx, sy - fy
    nx, ny = a.shape

    def take(ox, oy):
        res = np.zeros_like(a)
        x0, x1 = max(0, -ox), min(nx, nx - ox)
        y0, y1 = max(0, -oy), min(ny, ny - oy)
        if x1 > x0 and y1 > y0:
            res[x0:x1, y0:y1] = a[x0 + ox:x1 + ox, y0 + oy:y1 + oy]
        return res

    out = (take(fx, fy) * (1 - tx) * (1 - ty) + take(fx + 1, fy) * tx * (1 - ty) + take(fx, fy + 1) * (1 - tx) * ty +
           take(fx + 1, fy + 1) * tx * ty)
    return out


LIGHT = (0.55, -0.30, 1.0)  # towards the sun: up, to one side (image right), a little towards the camera


def light_depth(sigma):
    """Optical depth from every voxel up to the sun (a march from the top, slanting by LIGHT). sigma (nx, ny, nz)."""
    lx, ly, lz = LIGHT
    sx, sy = lx / lz, ly / lz
    length = math.sqrt(1 + sx * sx + sy * sy)
    nx, ny, nz = sigma.shape
    tau = np.zeros_like(sigma)
    carry = np.zeros((nx, ny), dtype=np.float32)
    for k in range(nz - 2, -1, -1):
        carry = shift2d(carry + sigma[:, :, k + 1] * length, sx, sy)
        tau[:, :, k] = carry
    return tau


def march(sigma, tau, look):
    """Front to back along y: returns (premultiplied radiance, alpha) images of shape (nx, nz)."""
    nx, ny, nz = sigma.shape
    ks, ka = look.get("k_sun", 0.5), look.get("k_amb", 0.12)
    sun, amb, fill = look.get("sun", 1.0), look.get("amb", 0.55), look.get("fill", 0.18)
    src = sun * np.exp(-ks * tau) + amb * np.exp(-ka * tau) + fill
    trans = np.ones((nx, nz), dtype=np.float32)
    rad = np.zeros((nx, nz), dtype=np.float32)
    for j in range(ny):
        s = sigma[:, j, :]
        a = 1.0 - np.exp(-s)
        rad += trans * src[:, j, :] * a
        trans *= 1.0 - a
    return rad, 1.0 - trans


def blur3(a):
    """A one-voxel binomial blur along each axis, edges held (nothing wraps round to the far side)."""
    out = a
    for ax in range(3):
        pad = [(0, 0)] * 3
        pad[ax] = (1, 1)
        p = np.pad(out, pad, mode="edge")
        sl = [slice(None)] * 3
        lo, mid, hi = list(sl), list(sl), list(sl)
        lo[ax], mid[ax], hi[ax] = slice(0, -2), slice(1, -1), slice(2, None)
        out = (p[tuple(lo)] + 2 * p[tuple(mid)] + p[tuple(hi)]) / 4
    return out


LUMP_N = 96


def lump_volume(seed):
    """A fixed cube of 3D noise (0..1) over q in [-1, 1]^3 for the cauliflower: sampled relative to the cloud's own
    centre and size, so the lumps grow with the cloud instead of sliding through it."""
    ax = np.linspace(0, 1, LUMP_N, dtype=np.float32)
    x, y, z = np.meshgrid(ax, ax, ax, indexing="ij")
    f = N.fbm3(x * 3.0, y * 3.0, z * 3.0, octaves=4, seed=seed)
    return np.clip(0.5 + 2.4 * f, 0.0, 1.0).astype(np.float32)


TILE_N = 64


def lump_tile(seed):
    """A cube of 3D noise (0..1) that tiles in every direction (4 features across), for lumps carried up a column."""
    ax = np.arange(TILE_N, dtype=np.float32) / TILE_N * 4.0
    x, y, z = np.meshgrid(ax, ax, ax, indexing="ij")
    f = N.fbm3(x, y, z, octaves=3, period=(4, 4, 4), seed=seed)
    return np.clip(0.5 + 2.2 * f, 0.0, 1.0).astype(np.float32)


def lumpy_rise(d, tile, params, k):
    """Lumps for a rising column: the tile is sampled so that it climbs one whole tile height per 64 frames (so a
    64-frame loop closes) while the density keeps the shape the simulation gave it. params = (depth, voxels per
    feature, tile heights climbed per loop)."""
    depth, feat, m = params
    nx, ny, nz = d.shape
    per = TILE_N / 4.0 / feat  # tile cells per voxel
    ix = (np.arange(nx) * per).astype(np.int64) % TILE_N
    iy = (np.arange(ny) * per + 11).astype(np.int64) % TILE_N
    iz = (np.arange(nz) * per - k * m).astype(np.int64) % TILE_N
    n = tile[ix[:, None, None], iy[None, :, None], iz[None, None, :]]
    return d * (1.0 - depth + depth * 2.0 * n)


def lumpy(d, lumps, params):
    """Cauliflower: the density times a lump pattern that is attached to the cloud (its centroid and its radius), so
    the soft simulated mass gets rounded billows with dark creases between them. params = (depth, scale)."""
    depth, scale = params
    tot = d.sum()
    if tot < 1e-3:
        return d
    nx, ny, nz = d.shape
    ix = np.arange(nx, dtype=np.float32)
    iy = np.arange(ny, dtype=np.float32)
    iz = np.arange(nz, dtype=np.float32)
    px, py, pz = d.sum(axis=(1, 2)), d.sum(axis=(0, 2)), d.sum(axis=(0, 1))
    c = [(ix * px).sum() / tot, (iy * py).sum() / tot, (iz * pz).sum() / tot]
    var = [((ix - c[0]) ** 2 * px).sum() / tot, ((iy - c[1]) ** 2 * py).sum() / tot, ((iz - c[2]) ** 2 * pz).sum() / tot]
    rad = max(math.sqrt(sum(var)), 3.0) * scale
    half = LUMP_N / 2 - 1
    qx = np.clip(((ix - c[0]) / rad * half + half).astype(np.int32), 0, LUMP_N - 1)
    qy = np.clip(((iy - c[1]) / rad * half + half).astype(np.int32), 0, LUMP_N - 1)
    qz = np.clip(((iz - c[2]) / rad * half + half).astype(np.int32), 0, LUMP_N - 1)
    n = lumps[qx[:, None, None], qy[None, :, None], qz[None, None, :]]
    # thin parts take more of the pattern (they break into lumps first), thick parts keep their body
    return d * (1.0 - depth + depth * 2.0 * n)


def erosion_field(dims, seed=11):
    """A fixed 3D noise volume in 0..1 that the rising cut is compared to (so the smoke is eaten away in lumps)."""
    nx, ny, nz = dims
    ax = np.linspace(0, 3.2, nx, dtype=np.float32)
    ay = np.linspace(0, 3.2, ny, dtype=np.float32)
    az = np.linspace(0, 3.2, nz, dtype=np.float32)
    x, y, z = np.meshgrid(ax, ay, az, indexing="ij")
    f = N.fbm3(x, y, z, octaves=4, seed=seed)
    return np.clip(0.5 + 0.9 * f, 0.0, 1.0).astype(np.float32)


def mist_volume(k, n, dims):
    """Frame k of n of a bank of fog: several soft horizontal layers of different thickness and height, each broken
    into long patches by noise that is stretched along the bank, the layers drifting in different directions (one
    whole noise period per loop, so frame n is frame 0 again), all fading to nothing before the cell's edge so the
    bank has no outline. Index order (x, depth, up)."""
    nx, ny, nz = dims
    x = np.linspace(-1.0, 1.0, nx, dtype=np.float32)[:, None, None]
    y = np.linspace(-0.25, 0.25, ny, dtype=np.float32)[None, :, None]
    z = np.linspace(-0.9, 0.9, nz, dtype=np.float32)[None, None, :]
    xx, yy, zz = np.broadcast_arrays(x, y, z)
    u = (xx + 1.0) * 2.0  # four lattice cells across; the period is 2 cells = half the bank per loop
    t = k / n
    layers = (  # (height, thickness, strength, drift in periods per loop, noise seed, wobble phase)
        (-0.50, 0.30, 0.85, 1, 11, 0.0),
        (-0.12, 0.24, 0.65, -1, 23, 1.7),
        (0.22, 0.30, 0.85, 1, 37, 3.1),
        (0.58, 0.24, 0.55, -1, 51, 4.4),
    )
    total = np.zeros(xx.shape, dtype=np.float32)
    for height, thick, strength, drift, seed, ph in layers:
        # long patches along x (low frequency in x, higher in z), drifting one period per loop
        patch = N.fbm3(u * 0.6 + 2.0 * drift * t, zz * 0.7 + seed, yy * 0.8, octaves=2, seed=seed,
                       period=(2, None, None))
        wave = 0.05 * N.fbm3(u * 0.5 + 2.0 * drift * t + 5.0, zz * 0.0 + seed, yy * 0.0, octaves=2, seed=seed + 5,
                             period=(2, None, None)) + 0.03 * math.sin(2 * math.pi * (t * drift) + ph)
        band = np.exp(-(((zz - height - wave) / thick) ** 2))
        total += strength * band * smoothstep(-0.55, 0.6, patch)
    veil = 0.10 * smoothstep(-0.3, 0.5, N.fbm3(u * 0.5 - 2.0 * t, zz * 1.0, yy, octaves=2, seed=3, period=(2, None, None)))
    total = total + veil * np.exp(-((zz / 0.85) ** 2))
    depth = np.exp(-((yy / 0.2) ** 2))
    edge_x = smoothstep(1.0, 0.45, np.abs(xx)) ** 1.5  # fades to nothing before the side edges
    edge_z = smoothstep(0.9, 0.4, np.abs(zz))
    d = (total * depth * edge_x * edge_z).astype(np.float32)
    return blur3(blur3(d))


_DUST = {}
DUST_X = (-0.1, 2.3)  # the grid's x range in the dust's own units (the hit is at x = 0, the wave runs to the right)
DUST_Z = 1.45


def dust_cast(seed=31):
    """The made-up parts of the roll, fixed by a seed: the head is a ring of cloudlets that orbits a core (a rolling
    torus seen from the side), the body is low flat sheets and long wisps that the head leaves behind, and a few puffs
    of spray stand over the head."""
    rng = np.random.default_rng(seed)
    ring = [dict(th=2 * np.pi * i / 20 + rng.normal(0, 0.12), rr=rng.uniform(0.85, 1.15), y=rng.normal(0, 0.09),
                 sz=rng.uniform(0.8, 1.25), off=rng.uniform(0, 60, 3)) for i in range(20)]
    sheets = [dict(x=rng.uniform(0.15, 1.0), R=0.0, t0=rng.uniform(0.0, 0.1), tau=rng.uniform(0.14, 0.24),
                   y=rng.normal(0, 0.1), amp=rng.uniform(0.6, 0.9), off=rng.uniform(0, 60, 3), kind="sheet") for i in range(16)]
    for sh in sheets:
        sh["R"] = 0.06 + 0.10 * sh["x"]
    wisps = [dict(x=rng.uniform(0.05, 0.85), R=0.05 + 0.04 * rng.random(), t0=rng.uniform(0.04, 0.2),
                  tau=rng.uniform(0.14, 0.26), y=rng.normal(0, 0.1), amp=rng.uniform(0.35, 0.6), off=rng.uniform(0, 60, 3),
                  kind="wisp") for i in range(10)]
    spray = [dict(ang=np.radians(rng.uniform(-10, 85)), dist=rng.uniform(1.15, 1.6), R=rng.uniform(0.06, 0.12),
                  y=rng.normal(0, 0.1), amp=rng.uniform(0.7, 1.0), off=rng.uniform(0, 60, 3), lag=rng.uniform(0.0, 0.1))
             for i in range(8)]
    return dict(ring=ring, body=sheets + wisps, spray=spray)


def dust_volume(k, n, dims):
    """Frame k of n of dust rolling along the floor from a slam at the left, seen from the side: the front runs to the
    right and billows up into a tall rolling curl (a ring of cloudlets orbiting a core, top turning forward), the body
    it leaves behind is a long low wedge that tapers to the left and sinks into wisps; lumps belong to each cloudlet;
    the rising cut at the end eats the whole thing from its thin parts into islands. Index (x, depth, up), z = 0 floor."""
    if "cast" not in _DUST:
        _DUST["cast"] = dust_cast()
        _DUST["lump"] = lump_tile(9)
    cast, tile = _DUST["cast"], _DUST["lump"]
    nx, ny, nz = dims
    tau = k / (n - 1)
    gx = np.linspace(DUST_X[0], DUST_X[1], nx, dtype=np.float32)
    gy = np.linspace(-0.35, 0.35, ny, dtype=np.float32)
    gz = np.linspace(0.0, DUST_Z, nz, dtype=np.float32)
    free = np.ones((nx, ny, nz), dtype=np.float32)  # 1 - the union of the cloudlets: they merge instead of adding
    sx, sy, sz = gx[1] - gx[0], gy[1] - gy[0], gz[1] - gz[0]

    def splat(cx, cy, cz, rx, ry, rz, amp, off, scale):
        x0, x1 = max(0, int((cx - 2.3 * rx - DUST_X[0]) / sx)), min(nx, int((cx + 2.3 * rx - DUST_X[0]) / sx) + 2)
        y0, y1 = max(0, int((cy - 2.3 * ry + 0.35) / sy)), min(ny, int((cy + 2.3 * ry + 0.35) / sy) + 2)
        z1 = min(nz, int((cz + 2.3 * rz) / sz) + 2)
        if x1 <= x0 or y1 <= y0 or z1 <= 0:
            return
        X = (gx[x0:x1] - cx)[:, None, None]
        Y = (gy[y0:y1] - cy)[None, :, None]
        Z = (gz[0:z1] - cz)[None, None, :]
        r2 = (X / rx) ** 2 + (Y / ry) ** 2 + (Z / rz) ** 2
        qx = ((X / rx * scale + off[0]).astype(np.int64)) % TILE_N
        qy = ((Y / ry * scale + off[1]).astype(np.int64)) % TILE_N
        qz = ((Z / rz * scale + off[2]).astype(np.int64)) % TILE_N
        n3 = tile[qx, qy, qz]
        body = np.exp(-r2 * (0.9 + 1.7 * (1.0 - n3)))  # the lumps pinch the surface in: a torn, cauliflower edge
        d = amp * np.clip(body * (0.35 + 1.3 * n3), 0, 1.4)
        free[x0:x1, y0:y1, 0:z1] *= np.clip(1.0 - np.clip(d, 0, 1), 0, 1)

    # --- the head: a ring of cloudlets orbiting a core that runs forward
    g = min(tau / 0.26, 1.0)
    hs = 0.10 + 0.90 * (1 - (1 - g) ** 2.2)  # born small, full by about a fifth of the life
    run = min(tau / 0.36, 1.0)
    head_x = 0.10 + 0.95 * (1 - (1 - run) ** 2.0) + 0.07 * tau
    Rh, rc = 0.40 * hs, 0.21 * hs
    head_z = 0.95 * Rh + 0.07
    spin = 2 * np.pi * 1.15 * min(tau, 0.85)  # the top turns forward, the underside back along the floor
    for c in cast["ring"]:
        th = c["th"] - spin
        cx = head_x + Rh * c["rr"] * np.cos(th)
        cz = head_z + Rh * c["rr"] * np.sin(th) * 1.28  # a little taller than wide: a curl, not a wheel
        R = rc * c["sz"]
        splat(cx, c["y"], cz, R * 1.15, R * 1.3, R * 0.95, 1.0, c["off"], 13.0)
    splat(head_x, 0.0, head_z, Rh * 0.62, Rh * 0.8, Rh * 0.62, 0.62, np.array([3.0, 7.0, 11.0]), 11.0)  # the core, thin
    for c in cast["spray"]:  # puffs flung up and ahead from the head's top
        t = max(0.0, tau - c["lag"])
        sc = min(t / 0.2, 1.0)
        cx = head_x + np.cos(c["ang"]) * Rh * c["dist"] * sc
        cz = head_z + np.sin(c["ang"]) * Rh * 1.2 * c["dist"] * sc + 0.02
        if sc > 0:
            splat(cx, c["y"], cz, c["R"] * hs * 2.2, c["R"] * hs * 2.4, c["R"] * hs * 2.0, c["amp"] * min(1.0, sc * 3), c["off"], 14.0)
    # --- the body the head leaves behind: low sheets and wisps, nearer the origin the thinner
    for c in cast["body"]:
        t = tau - c["t0"]
        if t <= 0:
            continue
        move = 1 - np.exp(-t / c["tau"])
        cx = 0.04 + (c["x"] * min(1.0, head_x / 1.05)) * move
        R = 0.02 + (c["R"] - 0.02) * (1 - np.exp(-t / (c["tau"] * 1.3)))
        if c["kind"] == "sheet":
            splat(cx, c["y"], 0.8 * R, R * 3.4, R * 1.5, R * 1.25, c["amp"] * min(1.0, t / 0.03) * (0.07 / R) ** 0.35, c["off"], 14.0)
        else:
            splat(cx, c["y"], 0.5 * R, R * 3.6, R * 1.2, R * 0.55, c["amp"] * min(1.0, t / 0.04), c["off"], 16.0)
    # the slam's own puff over the origin: stands up fast and sinks into the body
    hz = 0.08 + 0.10 * np.exp(-tau * 6.0)
    splat(0.06, 0.0, hz, 0.12, 0.14, hz * 1.1, 1.1 * (1 - smoothstep(0.06, 0.32, tau)), np.array([5.0, 9.0, 13.0]), 9.0)
    d = 1.0 - free
    if tau > 0.42:  # eaten from its thin parts first, in lumps, islands at the end
        cut = 3.2 * ((tau - 0.42) / 0.58) ** 1.1
        eat = N.fbm3(gx[:, None, None] * 3.5 + 3.0 * tau, gz[None, None, :] * 4.5, gy[None, :, None] * 4.0, octaves=4, seed=77)
        d = np.maximum(d - cut * (0.12 + 0.55 * (0.5 + eat)), 0.0)
    return blur3(d.astype(np.float32))


def render_frames(name, work, spec):
    if spec.get("procedural") == "dust":
        look = spec["look"]
        n = spec["frames"]
        rads, alphas = [], []
        for k in range(n):
            d = dust_volume(k, n, spec["dims"])
            sigma = d * look["sigma"](k / n)
            rad, alpha = march(sigma, light_depth(sigma), look)
            rads.append(rad)
            alphas.append(alpha)
            print(f"[tex_smoke] {name} lit {k + 1}/{n}", flush=True)
        return np.stack(rads), np.stack(alphas), {}
    if spec.get("procedural"):
        look = spec["look"]
        n = spec["frames"]
        rads, alphas = [], []
        for k in range(n):
            d = mist_volume(k, n, spec["dims"])
            sigma = d * look["sigma"](k / n)
            rad, alpha = march(sigma, light_depth(sigma), look)
            rads.append(rad)
            alphas.append(alpha)
            print(f"[tex_smoke] {name} lit {k + 1}/{n}", flush=True)
        return np.stack(rads), np.stack(alphas), {}
    meta = json.load(open(os.path.join(work, "meta.json")))
    look = spec["look"]
    first, count = look.get("take", (1, meta["frames"]))
    n = count
    dims = tuple(meta["dims"])
    eros = erosion_field(dims) if "erode" in look else None
    lumps = lump_volume(look.get("lump_seed", 3)) if "lump" in look else (
        lump_tile(look.get("lump_seed", 3)) if "lump_rise" in look else None)
    rads, alphas = [], []
    for k in range(first, first + count):
        life = (k - first) / max(1, n - 1)
        d = np.load(os.path.join(work, "dens_%04d.npy" % k)).astype(np.float32)
        cut = look["erode"](life) if "erode" in look else 0.0
        if cut > 0:
            lift = int(round(life * look.get("rise_vox", 0)))
            e = np.roll(eros, lift, axis=2) if lift else eros
            d = np.maximum(d - cut * (0.15 + 1.1 * e), 0.0)
        for _ in range(look.get("blur", 0)):
            d = blur3(d)
        if "lump_rise" in look:
            d = lumpy_rise(d, lumps, look["lump_rise"], k - first)
            for _ in range(look.get("blur_after", 0)):
                d = blur3(d)
        if "lump" in look:
            d = lumpy(d, lumps, look["lump"])
            for _ in range(look.get("blur_after", 0)):
                d = blur3(d)
        sigma = d * look["sigma"](life) * (128.0 / max(dims))  # (per voxel: a finer grid has thinner voxels)
        tau = light_depth(sigma)
        rad, alpha = march(sigma, tau, look)
        rads.append(rad)
        alphas.append(alpha)
        print(f"[tex_smoke] {name} lit {k - first + 1}/{n}", flush=True)
    rads, alphas = np.stack(rads), np.stack(alphas)
    if "loop" in look:
        rads, alphas = close_loop(rads, alphas, *look["loop"])
    return rads, alphas, meta


def close_loop(rads, alphas, length, k):
    """The last frame must run into the first: the first k frames of the loop are the sim's frames from `length`
    on, crossfaded (smoothly) into the frames they would have been, so frame length-1 -> frame 0 is one more sim step."""
    out_r, out_a = rads[:length].copy(), alphas[:length].copy()
    for i in range(k):
        w = float(smoothstep(0.0, 1.0, i / k))
        out_r[i] = rads[length + i] * (1 - w) + rads[i] * w
        out_a[i] = alphas[length + i] * (1 - w) + alphas[i] * w
    return out_r, out_a


def resample(img, x0, y0, step, size, stretch=1.0, stretch_x=1.0):
    """Bilinear sample of img (h, w) at pixel positions x0 + i * step, y0 + j * step (i, j over size), with a
    2 x 2 supersample so a downscale is not aliased."""
    h, w = img.shape
    out = np.zeros((size, size), dtype=np.float32)
    for oy in (0.25, 0.75):
        for ox in (0.25, 0.75):
            xs = x0 + (np.arange(size) + ox) * step / stretch_x - 0.5
            ys = y0 + (np.arange(size) + oy) * step / stretch - 0.5
            xi, yi = np.floor(xs).astype(int), np.floor(ys).astype(int)
            tx, ty = (xs - xi)[None, :], (ys - yi)[:, None]
            xi0, xi1 = np.clip(xi, 0, w - 1), np.clip(xi + 1, 0, w - 1)
            yi0, yi1 = np.clip(yi, 0, h - 1), np.clip(yi + 1, 0, h - 1)
            ok_x = ((xi >= 0) & (xi + 1 <= w - 1))[None, :]
            ok_y = ((yi >= 0) & (yi + 1 <= h - 1))[:, None]
            v = (img[yi0][:, xi0] * (1 - tx) * (1 - ty) + img[yi0][:, xi1] * tx * (1 - ty) +
                 img[yi1][:, xi0] * (1 - tx) * ty + img[yi1][:, xi1] * tx * ty)
            out += v * (ok_x & ok_y)
    return out / 4


def frame_images(rads, alphas, spec, cell):
    """Reframes the lit frames (rad/alpha stored (n, nx, nz) with x right, z up) to square cells. The window is as big
    as the cloud ever is (so it fills `fit` of the cell at its largest). `follow` says how the window keeps the cloud
    in it: "" = one fixed window over the whole life (a column that rises in place); "xy" = the window moves with the
    cloud (a puff drifts; the particle does the drifting in game, the picture keeps it centred); "x" = follows it
    sideways and keeps the floor at the bottom (dust). Returns straight-alpha frames (n, cell, cell, 4)."""
    look = spec["look"]
    n, nx, nz = alphas.shape
    al = np.transpose(alphas, (0, 2, 1))[:, ::-1]  # image rows go down, so z is flipped; columns are x
    ra = np.transpose(rads, (0, 2, 1))[:, ::-1]
    stretch = look.get("stretch_z", 1.0)  # (a little vertical stretch for dust: it is amorphous and the cell is square)
    stretch_x = look.get("stretch_x", 1.0)  # (a little sideways stretch for the plume, for the same reason)
    fit = look.get("fit", 0.90)
    thr = look.get("box_alpha", 0.2)
    boxes = []
    for k in range(n):
        ys, xs = np.nonzero(al[k] > thr)
        boxes.append((xs.min(), xs.max() + 1, ys.min(), ys.max() + 1) if len(ys) else None)
    good = [b for b in boxes if b]
    follow = look.get("follow", "")
    until = max(1, int(n * look.get("fit_until", 1.0)))  # the window is fitted to the frames up to here
    sized = [b for b in boxes[:until] if b]
    if follow in ("xy", "x"):
        side = max(max((b[1] - b[0]) * stretch_x, (b[3] - b[2]) * stretch) for b in sized) / fit
    else:
        ux0, ux1 = min(b[0] for b in good), max(b[1] for b in good)
        uy0, uy1 = min(b[2] for b in good), max(b[3] for b in good)
        side = max((ux1 - ux0) * stretch_x, (uy1 - uy0) * stretch) / fit
    # window centre per frame (smoothed over time so it never jitters)
    cxs = np.array([(b[0] + b[1]) / 2 if b else np.nan for b in boxes], dtype=np.float64)
    cys = np.array([(b[2] + b[3]) / 2 if b else np.nan for b in boxes], dtype=np.float64)
    for arr in (cxs, cys):  # frames with nothing (the very end) keep the last centre
        for k in range(n):
            if np.isnan(arr[k]):
                arr[k] = arr[k - 1] if k else np.nanmean(arr)

    def smooth(v, r=4):
        pad = np.concatenate([np.repeat(v[:1], r), v, np.repeat(v[-1:], r)])
        return np.convolve(pad, np.ones(2 * r + 1) / (2 * r + 1), mode="valid")

    if follow in ("xy", "x"):
        cxs, cys = smooth(cxs), smooth(cys)
        if follow == "x":
            floor = max(b[3] for b in good)
            cys = np.full(n, floor + 0.04 * side / stretch - side / stretch / 2)
    elif follow == "floor":  # one fixed window, the floor (the lowest row ever lit) kept just above the cell's bottom
        cxs = np.full(n, (ux0 + ux1) / 2)
        cys = np.full(n, uy1 + 0.04 * side / stretch - side / stretch / 2)
    else:
        cxs = np.full(n, (ux0 + ux1) / 2 + look.get("shift", (0, 0))[0] * side)
        cys = np.full(n, (uy0 + uy1) / 2 + look.get("shift", (0, 0))[1] * side)
    print(f"[tex_smoke] largest box {side * fit:.0f} voxels of {nx} x {nz}, window {side:.1f}, follow '{follow}'")
    step = side / cell
    out = []
    for k in range(n):
        ox, oy = cxs[k] - side / 2 / stretch_x, cys[k] - side / 2 / stretch
        a = resample(al[k], ox, oy, step, cell, stretch, stretch_x)
        r = resample(ra[k], ox, oy, step, cell, stretch, stretch_x)
        rgb = np.clip(r / np.maximum(a, 1e-4), 0, 4)
        out.append(np.concatenate([np.repeat(rgb[..., None], 3, axis=2), a[..., None]], axis=-1))
    return out


def flatten(frames, amount, vgrad):
    """Fog is lit softly and evenly: pull each frame's grey toward its own mean (so deep shadow pockets do not make
    the thin edge look like a bright outline) and add a gentle lighter-above, darker-below slope."""
    out = []
    for f in frames:
        a = f[..., 3]
        mean = (f[..., 0] * a).sum() / max(a.sum(), 1e-4)
        v = mean + (f[..., 0] - mean) * (1 - amount)
        h = f.shape[0]
        slope = 1.0 + vgrad * (0.5 - (np.arange(h, dtype=np.float32) / h))[:, None]
        g = f.copy()
        g[..., :3] = (v * slope)[..., None]
        out.append(g)
    return out


def calm_thin(frames, a0, a1):
    """The thin edge of a cloud is lit with nothing in front of it, so it comes out brighter than the body and, once
    the game lays it over a floor, shows as a bright rim round the sprite. Thin parts take the frame's own mean grey."""
    out = []
    for f in frames:
        a = f[..., 3]
        mean = (f[..., 0] * a).sum() / max(a.sum(), 1e-4)
        k = smoothstep(a0, a1, a)
        g = f.copy()
        g[..., :3] = (f[..., 0] * k + mean * (1 - k))[..., None]
        out.append(g)
    return out


def tonemap(frames, look):
    """Shapes the grey: the brightest lit smoke becomes near white, the shaded belly stays a real dark grey."""
    lum = np.concatenate([f[..., 0][f[..., 3] > 0.4] for f in frames])
    if lum.size == 0:
        return frames
    top, lo = np.percentile(lum, 97), np.percentile(lum, 3)
    lo_t, hi_t = look.get("tone", (0.26, 1.0))
    out = []
    for f in frames:
        t = np.clip((f[..., 0] - lo) / max(top - lo, 1e-4), 0, 1) ** look.get("gamma", 0.9)
        g = f.copy()
        g[..., :3] = (lo_t + (hi_t - lo_t) * t)[..., None]
        out.append(g)
    return out


def edge_window(cell, clear=4, ramp=10):
    """1 inside, 0 within `clear` px of the cell's edge, a smooth ramp between: nothing reaches a neighbour."""
    y = np.minimum(np.arange(cell), np.arange(cell)[::-1]).astype(np.float32)
    return smoothstep(clear, clear + ramp, np.minimum(y[:, None], y[None, :]))


def build_sheet(name, work, spec):
    cell = SHEET // spec["grid"]
    rads, alphas, meta = render_frames(name, work, spec)
    frames = frame_images(rads, alphas, spec, cell)
    if "calm_thin" in spec["look"]:
        frames = calm_thin(frames, *spec["look"]["calm_thin"])
    if "flatten" in spec["look"]:
        frames = flatten(frames, *spec["look"]["flatten"])
    frames = tonemap(frames, spec["look"])
    win = edge_window(cell)
    for f in frames:
        f[..., 3] *= win
    return D.bleed(D.sheet(frames, spec["grid"]))


def look_pictures(name, img, cache, grid, first=0, step=None):
    """Pictures for the eye: 16 frames of the sheet (every step-th) as the game would draw them: over the dark realm
    laid and added (white), and over a light floor laid, tinted warm and cold."""
    import importlib

    prev = importlib.import_module("vfx.preview")
    n = grid * grid
    step = step or max(1, n // 16)
    cell = img.shape[0] // grid
    idx = [(first + i * step) % n for i in range(16)]
    cells = []
    for k in idx:
        r, c = divmod(k, grid)
        cells.append(img[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell])
    show = 128 if cell >= 128 else cell
    cells = [D.resize(c, show, show) if show != cell else c for c in cells]
    dark, light = (0.07, 0.07, 0.085), (0.85, 0.85, 0.82)
    rows = []
    for tint, back, mode in (((1, 1, 1), dark, 0), ((1, 1, 1), dark, 1), ((0.95, 0.6, 0.35), light, 0),
                             ((0.45, 0.65, 1.0), light, 0)):
        panels = [prev.panel(c, tint, back)[..., :3] for c in cells]  # each (show, 2*show, 3): laid | added
        pick = [pn[:, :show] if mode == 0 else pn[:, show:] for pn in panels]
        rows.append(np.concatenate(pick[:8], axis=1))
        rows.append(np.concatenate(pick[8:], axis=1))
    pic = np.concatenate(rows, axis=0)
    path = os.path.join(cache, name + "_look.png")
    D.write_png(path, np.concatenate([pic, np.ones(pic.shape[:2] + (1,))], axis=-1))
    print("[tex_smoke] look:", path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    cache = os.path.join(tempfile.gettempdir(), "vfx_smoke_cache")
    out_dir = TEXTURES
    names, do_sim, do_post, do_look, quick = [], False, False, False, False
    k = 0
    while k < len(argv):
        a = argv[k]
        if a == "--cache":
            cache = argv[k + 1]
            k += 1
        elif a == "--out":
            out_dir = argv[k + 1]
            k += 1
        elif a == "--sim":
            do_sim = True
        elif a == "--post":
            do_post = True
        elif a == "--look":
            do_look = True
        elif a == "--quick":
            quick = True
        else:
            names.append(a)
        k += 1
    if not do_sim and not do_post:
        do_sim = do_post = True
    names = names or list(SIM)
    if quick:  # half the grid: for trying a setting out (cache it in its own folder)
        for n in names:
            SIM[n] = dict(SIM[n], sim=dict(SIM[n]["sim"], res=SIM[n]["sim"]["res"] // 2))
    os.makedirs(cache, exist_ok=True)
    for name in names:
        if do_sim:
            simulate(name, cache)
        if do_post:
            img = build_sheet(name, os.path.join(cache, name), SIM[name])
            path = D.write_png(os.path.join(out_dir, name + ".png"), img)
            print("[tex_smoke] wrote", path)
            if do_look:
                look_pictures(name, img, cache, SIM[name]["grid"])


if __name__ == "__main__":
    main()
