"""The effects' shapes (Core set; the FX kit, 2026-10-22, after the owner's tutorial: stylised effects are plain
shapes grown and faded on a curve). White and untextured in use: Presentation/FxKit strips their texture, tints
them and makes them glow (Neon) or shimmer (ForceField), and scales them over time. Each is 2 studs across (its
radius 1), round Z (the world's up), so the kit scales them by the size it wants."""

import math

import modelkit as mk
from common import srgb
from props import prop


def _white():
    return mk.flat("Fx_White", srgb(250, 250, 250), 0.5, kind="plastic")


@prop("FxDome", pivot="centre", material="SmoothPlastic", collide=False, texture=64)
def fx_dome():
    """A shockwave dome: a thin half-sphere shell, open underneath."""
    white = _white()
    steps = 14
    profile = [(math.cos(math.pi / 2 * k / steps), math.sin(math.pi / 2 * k / steps)) for k in range(steps + 1)]
    profile[-1] = (0.03, 1.0)  # (a tiny cap at the pole: a point there dents the shell)
    dome = mk.lathe("Dome", profile, mat=white, segments=40)
    shell = dome.modifiers.new("Shell", "SOLIDIFY")
    shell.thickness = 0.03
    return [dome], []


@prop("FxRing", pivot="centre", material="SmoothPlastic", collide=False, texture=64)
def fx_ring():
    """A thin flat ring (a ripple across the floor, a halo)."""
    ring = mk.torus("Ring", 0.93, 0.07, mat=_white(), major_segments=48, minor_segments=8)
    for v in ring.data.vertices:
        v.co.z *= 0.35
    return [ring], []


@prop("FxCrescent", pivot="centre", material="SmoothPlastic", collide=False, texture=64)
def fx_crescent():
    """A crescent slash: a flat blade of light, thick in the middle and sharp at both ends, curving round -Y."""
    outer = [(math.sin(a) * 1.0, -math.cos(a) * 1.0) for a in [math.radians(d) for d in range(-75, 76, 10)]]
    inner = [(math.sin(a) * 0.78, -math.cos(a) * 0.78 + 0.2) for a in [math.radians(d) for d in range(70, -71, -10)]]
    blade = mk.extrude_shape("Crescent", outer + inner, 0.04, mat=_white())
    return [blade], []


@prop("FxSpikes", pivot="centre", material="SmoothPlastic", collide=False, texture=64)
def fx_spikes():
    """A spike burst: sharp spikes thrown out from a point, flat round it and a few up."""
    white = _white()
    parts = [mk.sphere("Core", 0.16, (0, 0, 0), mat=white, segments=10, rings=6)]
    for k in range(12):
        a = 2 * math.pi * k / 12
        length = 1.0 if k % 2 == 0 else 0.7
        parts.append(mk.tube("Spike", (0, 0, 0), (math.cos(a) * length, math.sin(a) * length, 0.12 * (k % 3)), 0.09,
                             0.004, mat=white, verts=6))
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        parts.append(mk.tube("Spike", (0, 0, 0), (math.cos(a) * 0.35, math.sin(a) * 0.35, 0.9), 0.08, 0.004,
                             mat=white, verts=6))
    return parts, []
