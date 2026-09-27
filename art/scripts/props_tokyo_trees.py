"""Tokyo's trees (set "Tokyo"): a Somei-Yoshino cherry in bloom, a zelkova for the plaza, and a
scatter of fallen petals for under the cherries.

A tree is a real branching skeleton: a trunk that splits into a few main limbs, each splitting
again, every limb a tapered tube; at the outer twigs, clumps of blossom or leaves (lumpy, solid,
so nothing is see-through in Roblox). Seeded, so a tree rebuilds the same. They face -Y (a tree
has no front) and stand on z = 0 with their anchor at the trunk's foot."""

import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop


def _grow(parts, tips, rng, start, direction, length, radius, depth, mat, spread, rise, droop):
    """Grows a limb from start along direction (a unit vector), then its children; collects the
    twig tips (point, radius) where foliage goes."""
    dx, dy, dz = direction
    end = (start[0] + dx * length, start[1] + dy * length, start[2] + dz * length)
    # Two segments with a slight bend make a limb less like a pipe.
    mid = (start[0] + dx * length * 0.5 + rng.uniform(-0.3, 0.3) * length * 0.12,
           start[1] + dy * length * 0.5 + rng.uniform(-0.3, 0.3) * length * 0.12,
           start[2] + dz * length * 0.5 + length * 0.05)
    tip_r = radius * 0.62
    parts.append(mk.tube("Limb", start, mid, radius, (radius + tip_r) / 2, mat=mat, verts=7 if radius > 0.25 else 5))
    parts.append(mk.tube("Limb", mid, end, (radius + tip_r) / 2, tip_r, mat=mat, verts=7 if radius > 0.25 else 5))
    if depth == 0:
        tips.append((end, length))
        return
    count = 2 if depth > 1 else rng.choice((2, 3))
    base = math.atan2(dy, dx)
    for k in range(count):
        yaw = base + rng.uniform(-spread, spread) + (k - (count - 1) / 2) * spread * 0.8
        horizontal = math.hypot(dx, dy)
        pitch = math.atan2(dz, horizontal) + rng.uniform(-0.25, 0.25) + rise - droop * (3 - depth) * 0.2
        pitch = max(-0.5, min(1.35, pitch))
        nd = (math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch))
        _grow(parts, tips, rng, end, nd, length * rng.uniform(0.62, 0.78), tip_r, depth - 1, mat, spread, rise, droop)


def tree(prefix, seed, trunk_h, trunk_r, limbs, limb_len, depth, spread, rise, droop, bark, foliage, clump_r,
         clumps_per_tip, lift=0.0):
    rng = random.Random(seed)
    parts = [mk.cylinder(prefix + "Flare", trunk_r * 1.5, 0.6, (0, 0, 0.3), mat=bark, verts=10, radius2=trunk_r)]
    top = (0.0, 0.0, trunk_h)
    parts.append(mk.tube(prefix + "Trunk", (0, 0, 0.5), (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), trunk_h),
                         trunk_r, trunk_r * 0.8, mat=bark, verts=10))
    tips = []
    for k in range(limbs):
        yaw = 2 * math.pi * k / limbs + rng.uniform(-0.3, 0.3)
        pitch = rise + rng.uniform(-0.15, 0.2)
        d = (math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch))
        _grow(parts, tips, rng, top, d, limb_len * rng.uniform(0.85, 1.1), trunk_r * 0.62, depth, bark, spread, rise * 0.6,
              droop)
    for (x, y, z), length in tips:
        for _ in range(clumps_per_tip):
            r = clump_r * rng.uniform(0.7, 1.15)
            c = mk.sphere(prefix + "Clump", r, (x + rng.uniform(-1, 1) * r * 0.8, y + rng.uniform(-1, 1) * r * 0.8,
                                                z + lift + rng.uniform(-0.4, 0.6) * r),
                          scale=(1, 1, rng.uniform(0.62, 0.8)), mat=rng.choice(foliage), segments=9, rings=6)
            mk.displace_noise(c, strength=r * 0.35, scale=r * 0.55, name=prefix + "ClumpNoise")
            parts.append(c)
    return parts


@prop("TreeSakura", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Tokyo", anchor=(0, 0))
def tree_sakura():
    """A Somei-Yoshino cherry in full bloom: a short dark trunk splitting low into wide, rising
    limbs that droop at their ends, clouds of pale pink blossom (white and deeper pink in it)."""
    bark = mk.noisy("TS_Bark", srgb(38, 28, 26), srgb(70, 54, 48), scale=10, roughness=0.9, stretch=(1, 1, 0.25))
    pinks = [mk.noisy("TS_Bloom1", srgb(236, 176, 196), srgb(252, 214, 226), scale=40, roughness=0.8),
             mk.noisy("TS_Bloom2", srgb(246, 204, 216), srgb(255, 234, 240), scale=40, roughness=0.8),
             mk.noisy("TS_Bloom3", srgb(222, 150, 176), srgb(240, 190, 208), scale=40, roughness=0.8)]
    return tree("TS_", 11, trunk_h=4.6, trunk_r=0.62, limbs=5, limb_len=6.0, depth=2, spread=0.55, rise=0.55,
                droop=0.5, bark=bark, foliage=pinks, clump_r=1.55, clumps_per_tip=3, lift=0.3), []


@prop("TreeZelkova", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Tokyo", anchor=(0, 0))
def tree_zelkova():
    """A zelkova for the plaza: a straight grey trunk dividing into many upswept limbs, a tall
    vase-shaped crown of small leaf clumps."""
    bark = mk.noisy("TZ_Bark", srgb(84, 80, 74), srgb(122, 116, 108), scale=12, roughness=0.85, stretch=(1, 1, 0.3))
    greens = [mk.noisy("TZ_Leaf1", srgb(38, 70, 34), srgb(70, 108, 50), scale=36, roughness=0.8),
              mk.noisy("TZ_Leaf2", srgb(46, 82, 40), srgb(86, 124, 60), scale=36, roughness=0.8),
              mk.noisy("TZ_Leaf3", srgb(30, 58, 30), srgb(58, 92, 44), scale=36, roughness=0.8)]
    return tree("TZ_", 23, trunk_h=6.5, trunk_r=0.7, limbs=6, limb_len=5.6, depth=2, spread=0.35, rise=1.05,
                droop=0.1, bark=bark, foliage=greens, clump_r=1.45, clumps_per_tip=3), []


@prop("PetalScatter", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Tokyo")
def petal_scatter():
    """Fallen cherry petals lying on the ground under a tree, thickest near the middle."""
    rng = random.Random(5)
    pinks = [pk.plastic("PS_Petal1", (244, 196, 212)), pk.plastic("PS_Petal2", (252, 224, 232))]
    parts = []
    for _ in range(160):
        r = 7.0 * math.sqrt(rng.random()) * rng.uniform(0.5, 1.0)
        a = rng.uniform(0, 2 * math.pi)
        parts.append(mk.box("Petal", (0.22, 0.16, 0.02), (math.cos(a) * r, math.sin(a) * r * 0.8, 0.01),
                            rot=(0, 0, rng.uniform(0, 180)), mat=rng.choice(pinks)))
    return parts, []
