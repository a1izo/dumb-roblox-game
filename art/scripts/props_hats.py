"""The shop's hats as real models (Core set; the shop overhaul's B9, 2026-10-22, from the review page's looks):
each sits on an R6 head the way Shared/CosmeticBuild places it (round Z, the head's up; the front facing -Y; the
head inside the crown, its brim about 0.42 studs above the head's middle). Small and plain, like the emote props."""

import math

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop
from props_emotes import _bend_brim


def _fedora_shape(name, felt, band, front=0.1, crown=0.8):
    """A fedora: a pinched crown and a brim snapped down at the front, with its band."""
    k = crown / 0.8
    hat = mk.lathe(name, [(0.0, 0.02), (0.96, 0.0), (1.0, 0.035), (0.97, 0.07), (0.69, 0.085), (0.68, 0.3 * k),
                          (0.65, 0.58 * k), (0.58, 0.76 * k), (0.36, 0.8 * k), (0.18, 0.7 * k), (0.0, 0.69 * k)],
                   mat=felt, segments=40)
    _bend_brim(hat, 0.7, 1.0, front=front, sides=0.06)
    ribbon = mk.lathe("Band", [(0.688, 0.09), (0.702, 0.09), (0.692, 0.26 * k), (0.678, 0.26 * k), (0.688, 0.09)],
                      mat=band, segments=40)
    return [hat, ribbon]


@prop("HatCap", pivot="centre", material="Fabric", collide=False, texture=256)
def hat_cap():
    """Night Shift Cap: a soft wool patrol cap with a short stiff brim and a grey-thread Bureau badge on the front."""
    wool = mk.noisy("Hc_Wool", srgb(28, 34, 48), srgb(44, 52, 70), roughness=0.9, kind="cloth")
    brim = mk.noisy("Hc_Brim", srgb(16, 18, 24), srgb(30, 32, 40), roughness=0.5, kind="plastic")
    badge = mk.noisy("Hc_Badge", srgb(120, 122, 128), srgb(170, 172, 178), roughness=0.4, metallic=0.6)
    crown = mk.lathe("Crown", [(0.0, 0.0), (0.7, 0.0), (0.71, 0.18), (0.64, 0.42), (0.42, 0.56), (0.0, 0.6)],
                     mat=wool, segments=32)
    peak = mk.box("Brim", (1.1, 0.62, 0.05), (0, -0.82, 0.04), rot=(-8, 0, 0), mat=brim, bevel=0.02)
    plate = mk.box("Badge", (0.26, 0.04, 0.22), (0, -0.7, 0.26), rot=(70, 0, 0), mat=badge, bevel=0.01)
    return [crown, peak, plate], []


@prop("HatTrench", pivot="centre", material="Fabric", collide=False, texture=256)
def hat_trench():
    """Trench Fedora: charcoal felt, a pinched crown, a rain-darkened band, the brim snapped down at the front."""
    felt = mk.noisy("Ht_Felt", srgb(34, 34, 38), srgb(54, 54, 60), roughness=0.85, kind="cloth")
    band = mk.noisy("Ht_Band", srgb(14, 14, 16), srgb(26, 26, 30), roughness=0.4, kind="cloth")
    return _fedora_shape("Hat", felt, band), []


@prop("HatDiavolo", pivot="centre", material="Fabric", collide=False, texture=256)
def hat_diavolo():
    """Diavolo's Fedora: oxblood felt with a black band and one long black feather swept back."""
    felt = mk.noisy("Hd_Felt", srgb(78, 14, 20), srgb(110, 24, 30), roughness=0.85, kind="cloth")
    band = mk.noisy("Hd_Band", srgb(10, 10, 12), srgb(24, 24, 28), roughness=0.4, kind="cloth")
    quill = mk.flat("Hd_Feather", srgb(14, 14, 16), 0.5)
    parts = _fedora_shape("Hat", felt, band, front=0.12)
    # (from the band on the left side, swept back and up past the crown)
    parts.append(mk.tube("Feather", (-0.7, -0.1, 0.2), (-0.62, 0.55, 0.62), 0.075, 0.06, mat=quill, verts=8))
    parts.append(mk.tube("FeatherTip", (-0.62, 0.55, 0.62), (-0.5, 1.15, 0.95), 0.06, 0.008, mat=quill, verts=8))
    return parts, []


@prop("HatTopper", pivot="centre", material="Fabric", collide=False, texture=256)
def hat_topper():
    """Undertaker's Topper (redesigned 2026-10-22, the owner's "change it"): a tall matte black silk topper,
    a little taller and narrower than a gentleman's, with a mourning crape band whose two long tails hang down the
    back, a jet pin where they meet."""
    silk = mk.noisy("Hu_Silk", srgb(12, 12, 14), srgb(26, 26, 30), roughness=0.75, kind="cloth")
    crape = mk.noisy("Hu_Crape", srgb(20, 20, 22), srgb(34, 34, 38), roughness=0.95, kind="cloth")
    jet = mk.flat("Hu_Jet", srgb(8, 8, 10), 0.15)
    hat = mk.lathe("Hat", [(0.0, 0.02), (0.84, 0.0), (0.88, 0.04), (0.84, 0.075), (0.63, 0.09), (0.62, 0.2),
                           (0.625, 0.85), (0.655, 1.22), (0.635, 1.25), (0.0, 1.25)], mat=silk, segments=40)
    _bend_brim(hat, 0.64, 0.88, sides=0.08)
    band = mk.lathe("Band", [(0.628, 0.1), (0.645, 0.1), (0.642, 0.42), (0.626, 0.42), (0.628, 0.1)], mat=crape,
                    segments=40)
    parts = [hat, band]
    for side in (-1, 1):
        parts.append(mk.box("Tail", (0.16, 0.03, 0.95), (0.12 * side, 0.66, -0.2), rot=(-8, 0, 6 * side), mat=crape,
                            bevel=0.01))
    parts.append(mk.sphere("Pin", 0.05, (0, 0.66, 0.3), mat=jet, segments=10, rings=6))
    return parts, []


@prop("HatGraveSilk", pivot="centre", material="Fabric", collide=False, texture=256)
def hat_grave_silk():
    """Grave Silk: a black top hat whose crown frays at the top into ragged points (the smoke and ash rise from
    them in the game: Shared/CosmeticBuild)."""
    silk = mk.noisy("Hg_Silk", srgb(16, 16, 18), srgb(36, 34, 36), roughness=0.5, kind="cloth")
    ash = mk.noisy("Hg_Ash", srgb(70, 66, 64), srgb(110, 104, 100), roughness=0.95, kind="cloth")
    hat = mk.lathe("Hat", [(0.0, 0.02), (0.9, 0.0), (0.94, 0.04), (0.9, 0.075), (0.66, 0.09), (0.645, 0.2),
                           (0.655, 0.9), (0.0, 0.9)], mat=silk, segments=40)
    _bend_brim(hat, 0.67, 0.94, sides=0.09)
    parts = [hat]
    # (ragged tatters, leaning out, each a different height)
    for k in range(14):
        a = 2 * math.pi * (k + 0.3 * ((k * 5) % 3)) / 14
        h = 0.14 + 0.09 * ((k * 7) % 4)
        base = (0.64 * math.cos(a), 0.64 * math.sin(a), 0.88)
        tip = (0.76 * math.cos(a), 0.76 * math.sin(a), 0.88 + h)
        parts.append(mk.tube("Fray", base, tip, 0.06, 0.008, mat=ash if k % 3 == 0 else silk, verts=5))
    return parts, []


@prop("HatCowl", pivot="centre", material="Fabric", collide=False, texture=256)
def hat_cowl():
    """Reaper's Cowl: a deep wool hood with stitched seams that shades the face, open at the front."""
    import bmesh
    wool = mk.noisy("Hw_Wool", srgb(20, 20, 22), srgb(38, 36, 38), roughness=0.95, kind="cloth")
    seam = mk.flat("Hw_Seam", srgb(56, 54, 52), 0.9)
    hood = mk.lathe("Hood", [(1.0, -1.05), (0.88, -0.78), (0.84, -0.2), (0.8, 0.25), (0.62, 0.62), (0.34, 0.86),
                             (0.0, 0.94)], mat=wool, segments=36)
    bm = bmesh.new()
    bm.from_mesh(hood.data)
    gone = [f for f in bm.faces if f.calc_center_median().y < -0.3 and -0.82 < f.calc_center_median().z < 0.42]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(hood.data)
    bm.free()
    solid = hood.modifiers.new("Thick", "SOLIDIFY")
    solid.thickness = 0.07
    stitch = mk.tube("Seam", (0, 0.86, 0.1), (0, 0.2, 0.86), 0.02, 0.02, mat=seam, verts=6)
    return [hood, stitch], []


@prop("HatCirclet", pivot="centre", material="Metal", collide=False, texture=256)
def hat_circlet():
    """Thorned Circlet: a thin crown of black iron thorns (a cold white light between them in the game)."""
    iron = mk.noisy("Hi_Iron", srgb(20, 20, 22), srgb(48, 48, 52), roughness=0.45, metallic=1.0)
    ring = mk.torus("Ring", 0.7, 0.045, mat=iron, major_segments=40, minor_segments=8)
    parts = [ring]
    for k in range(12):
        a = 2 * math.pi * k / 12
        tall = 0.34 if k % 2 == 0 else 0.22
        tip = (0.74 * math.cos(a), 0.74 * math.sin(a), tall)
        parts.append(mk.tube("Thorn", (0.7 * math.cos(a), 0.7 * math.sin(a), 0.0), tip, 0.05, 0.004, mat=iron, verts=6))
    return parts, []
