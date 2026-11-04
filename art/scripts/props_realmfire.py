"""The Grey Realm's fire (set "Lobby"): the bone braziers burning the realm's pale cold fire round the plaza, the
plateaus and the monolith, and the lantern posts along the ways people walk. Remade 2026-11-03 to the semi-real
standard: forged and riveted iron, bound bones, a real lantern with smoked panes; each keeps the footprint, height,
light and flame of what it replaced (the venue places them where they stood). They face -Y and stand on z = 0."""

import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop
from props_academy import weathered
from props_lobby import PALE_FIRE, bone_mat, candle, candle_wax, long_bone

FORGED = {"sub": 1, "disp": [("cells", 0.012, 0.16), ("grain", 0.004, 0.04)]}  # hammered iron


def _iron(prefix):
    return pk.metal(prefix + "_Iron", (22, 22, 24), (52, 49, 47), rough=0.62, metallic=0.7)


def _rust(prefix):
    return pk.metal(prefix + "Rust_Iron", (40, 30, 26), (70, 56, 46), rough=0.85, metallic=0.4)


