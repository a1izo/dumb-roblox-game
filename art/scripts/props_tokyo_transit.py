"""Tokyo's vehicles and the station's things (set "Tokyo"): the taxi, the patrol car's body, the
city bus, the kei truck and the metro's two cars; the bus shelter and stop sign, the taxi-rank
sign, ticket gates and machines, the hanging platform sign, benches, coin lockers and the
station clock.

Cars are built from their side profile (extruded across their width), a glass cabin with its
pillars and roof, then lamps, bumpers, plates, mirrors and wheels. Everything faces -Y (a car's
front) and stands on z = 0."""

import math

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop


def _profile(name, points, width, mat, bevel=0.12):
    """A side profile [(y, z)] extruded `width` across X (centred)."""
    return mk.extrude_shape(name, points, width, rot=(90, 0, 90), mat=mat, bevel=bevel)


def car_body(prefix, length, width, height, lower, upper, split, hood=3.3, boot=2.6, glass_tint=(20, 26, 36),
             wheel_r=1.15, tall=False):
    """A car facing -Y: the lower body to the beltline (`split`) in `lower`, the cabin above in
    `upper` pillars round dark glass, and all its small parts. tall: a box-shaped cab (taxi)."""
    half = length / 2
    body = pk.paint(prefix + "Lower", lower, rough=0.25, wear=8)
    top = pk.paint(prefix + "Upper", upper, rough=0.25, wear=8)
    glass = pk.dark_glass(prefix + "Glass", glass_tint)
    trim = pk.metal(prefix + "Trim", (22, 22, 24), (36, 36, 40), rough=0.6, metallic=0.2)
    chrome = pk.chrome(prefix + "Chrome")
    tyre = pk.rubber(prefix + "Tyre")
    rim = pk.metal(prefix + "Rim", (150, 152, 156), (190, 192, 196), rough=0.3, metallic=0.8)
    lens = mk.flat(prefix + "Lens", srgb(236, 236, 230), 0.1)
    tail = mk.flat(prefix + "Tail", srgb(170, 20, 24), 0.2)
    plate = pk.plastic(prefix + "Plate", (236, 236, 228))
    lower_profile = [(-half, 0.75), (-half, 1.9), (-half + 0.35, 2.55), (-half + hood, split),
                     (half - boot, split), (half - 0.3, split - 0.25), (half, split - 0.9), (half, 0.75)]
    wind_top = -half + hood + (1.1 if tall else 2.2)
    rear_top = half - boot - (0.4 if tall else 2.0)
    cabin = [(-half + hood - 0.05, split), (wind_top, height - 0.25), (rear_top, height - 0.25),
             (half - boot + (0.15 if tall else 0.0), split)]
    parts = [_profile(prefix + "Body", lower_profile, width, body, bevel=0.18),
             _profile(prefix + "Cabin", cabin, width - 0.35, glass, bevel=0.05),
             mk.box(prefix + "Roof", (width - 0.3, rear_top - wind_top + 0.3, 0.28),
                    (0, (wind_top + rear_top) / 2, height - 0.12), mat=top, bevel=0.12, segments=3)]
    # Pillars: A along the windscreen, B in the middle, C along the back glass, on both sides.
    for sx in (-1, 1):
        x = sx * (width / 2 - 0.2)
        parts += [mk.tube(prefix + "APillar", (x, -half + hood, split), (x, wind_top, height - 0.2), 0.12, mat=top, verts=6),
                  mk.box(prefix + "BPillar", (0.24, 0.35, height - split), (x, (wind_top + rear_top) / 2 - 0.2,
                                                                          (split + height) / 2), mat=top),
                  mk.tube(prefix + "CPillar", (x, half - boot, split), (x, rear_top, height - 0.2), 0.14, mat=top, verts=6),
                  mk.box(prefix + "Sill", (0.1, rear_top - wind_top + 3.0, 0.12), (sx * (width / 2 - 0.12),
                                                                                (wind_top + rear_top) / 2, split + 0.05),
                         mat=chrome)]
        # Door seams and handles.
        for y in (-half + hood + 0.3, (wind_top + rear_top) / 2 - 0.2, half - boot - 0.1):
            parts.append(mk.box(prefix + "Seam", (0.03, 0.05, split - 1.0), (sx * (width / 2 + 0.005), y, (split + 0.9) / 2),
                                mat=trim))
        for y in (-half + hood + 1.6, (wind_top + rear_top) / 2 + 1.2):
            parts.append(mk.box(prefix + "Handle", (0.08, 0.6, 0.14), (sx * (width / 2 + 0.03), y, split - 0.45),
                                mat=chrome, bevel=0.03))
        # Mirrors on the doors, lamps at the corners.
        parts += [mk.box(prefix + "MirrorArm", (0.5, 0.2, 0.15), (sx * (width / 2 + 0.2), -half + hood + 0.5, split + 0.3),
                         mat=trim),
                  pk.rounded(prefix + "Mirror", (0.5, 0.35, 0.4), (sx * (width / 2 + 0.45), -half + hood + 0.55,
                                                                   split + 0.35), top, r=0.08),
                  pk.rounded(prefix + "Head", (1.3, 0.2, 0.45), (sx * (width / 2 - 0.9), -half + 0.05, 2.05), lens, r=0.08),
                  pk.rounded(prefix + "TailL", (1.2, 0.2, 0.5), (sx * (width / 2 - 0.8), half - 0.02, split - 0.7), tail,
                             r=0.08)]
        # Wheels in their arches.
        for y in (-half + hood - 0.3, half - boot + 0.1):
            parts += pk.wheel(prefix + "W", sx * (width / 2 - 0.45), y, wheel_r, 0.8, tyre, rim, spokes=6)
            parts.append(mk.cylinder(prefix + "Arch", wheel_r + 0.2, 0.2, (sx * (width / 2 - 0.02), y, wheel_r),
                                     rot=(0, 90, 0), mat=trim, verts=18))
    parts += [
        pk.rounded(prefix + "BumperF", (width + 0.1, 0.5, 0.7), (0, -half + 0.05, 1.1), trim, r=0.15),
        pk.rounded(prefix + "BumperR", (width + 0.1, 0.5, 0.7), (0, half - 0.05, 1.1), trim, r=0.15),
        mk.box(prefix + "Grille", (width - 2.8, 0.15, 0.55), (0, -half - 0.02, 2.0), mat=trim, bevel=0.05),
        mk.box(prefix + "PlateF", (1.3, 0.06, 0.65), (0, -half - 0.22, 1.2), mat=plate),
        mk.box(prefix + "PlateR", (1.3, 0.06, 0.65), (0, half + 0.22, 1.4), mat=plate),
        mk.box(prefix + "Wiper", (1.6, 0.06, 0.06), (-0.5, -half + hood + 0.2, split + 0.12), rot=(0, 0, 8), mat=trim),
    ]
    ink = pk.plastic(prefix + "PlateInk", (30, 90, 60))
    parts += pk.label(prefix + "PlateFT", "品川 500 あ 12-34", 0.12, (0, -half - 0.26, 1.2), ink)
    parts += pk.label(prefix + "PlateRT", "品川 500 あ 12-34", 0.12, (0, half + 0.26, 1.4), ink, rot=(90, 0, 180))
    return parts, []


@prop("Taxi", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def taxi():
    """A tall Tokyo taxi in deep indigo: its roof lamp lit (the company's mark), the fare flag in
    the windscreen, orange side bands, a sliding rear door."""
    parts, glows = car_body("TX_", length=15.4, width=5.9, height=6.0, lower=(24, 30, 58), upper=(24, 30, 58),
                            split=3.0, hood=3.0, boot=1.2, tall=True)
    band = pk.plastic("TX_Band", (236, 150, 40))
    ink = pk.plastic("TX_Ink", (30, 30, 34))
    for sx in (-1, 1):
        parts.append(mk.box("Band", (0.03, 10.0, 0.18), (sx * 2.96, 0.6, 2.5), mat=band))
        parts.append(mk.box("DoorRail", (0.05, 4.0, 0.08), (sx * 2.97, 2.2, 4.6), mat=pk.chrome("TX_Rail")))
    parts.append(mk.box("LampBase", (1.6, 0.6, 0.2), (0, -0.8, 6.1), mat=pk.plastic("TX_LampBase", (30, 30, 34))))
    glows += [pk.rounded("Lamp", (1.4, 0.45, 0.65), (0, -0.8, 6.5), pk.glow("TX_Lamp", (255, 220, 120), 4), r=0.15),
              mk.box("Flag", (0.9, 0.05, 0.4), (1.3, -4.05, 3.6), rot=(18, 0, 0), mat=pk.glow("TX_Flag", (255, 60, 60), 4))]
    parts += pk.label("LampText", "影", 0.4, (0, -1.04, 6.5), ink)
    return parts, glows


@prop("KeiTruck", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def kei_truck():
    """A white kei truck, front to -Y: its short cab over the front wheels, the flat bed with
    drop-down side gates and a headboard, crates tied down in the back."""
    white = pk.paint("KT_White", (228, 228, 224), rough=0.3, wear=14)
    glass = pk.dark_glass("KT_Glass")
    trim = pk.metal("KT_Trim", (26, 26, 28), (40, 40, 44), rough=0.6, metallic=0.2)
    chrome = pk.chrome("KT_Chrome")
    tyre = pk.rubber("KT_Tyre")
    rim = pk.metal("KT_Rim", (170, 172, 176), (200, 202, 206), rough=0.3, metallic=0.8)
    bed = pk.metal("KT_Bed", (170, 172, 176), (200, 202, 206), rough=0.5, metallic=0.4)
    crate = pk.plastic("KT_Crate", (40, 110, 60))
    lens = mk.flat("KT_Lens", srgb(236, 236, 230), 0.1)
    parts = [
        _profile("Cab", [(-5.5, 0.9), (-5.5, 3.9), (-5.2, 6.0), (-2.2, 6.2), (-2.2, 0.9)], 5.1, white, bevel=0.2),
        _profile("Windscreen", [(-5.35, 4.0), (-5.08, 5.8), (-3.0, 5.95), (-3.0, 4.0)], 4.8, glass, bevel=0.04),
        mk.box("Bed", (5.1, 7.6, 0.3), (0, 1.6, 1.8), mat=bed),
        mk.box("Chassis", (3.6, 9.0, 0.6), (0, 0.5, 1.2), mat=trim),
        mk.box("Headboard", (5.0, 0.2, 2.2), (0, -2.05, 3.0), mat=bed),
        mk.box("TailGate", (5.1, 0.12, 1.3), (0, 5.4, 2.6), mat=bed, bevel=0.03),
        pk.rounded("BumperF", (5.3, 0.4, 0.6), (0, -5.55, 1.1), trim, r=0.12),
        pk.rounded("HeadL", (0.9, 0.2, 0.6), (-1.8, -5.58, 2.4), lens, r=0.08),
        pk.rounded("HeadR", (0.9, 0.2, 0.6), (1.8, -5.58, 2.4), lens, r=0.08),
        mk.box("PlateF", (1.2, 0.06, 0.6), (0, -5.8, 1.2), mat=pk.plastic("KT_Plate", (238, 214, 60))),
    ]
    for sx in (-1, 1):
        parts += [mk.box("SideGate", (0.12, 7.6, 1.3), (sx * 2.5, 1.6, 2.6), mat=bed, bevel=0.03),
                  mk.box("SideWindow", (0.1, 1.8, 1.5), (sx * 2.5, -3.5, 4.9), mat=glass),
                  mk.box("DoorSeam", (0.03, 0.05, 3.2), (sx * 2.56, -2.4, 2.6), mat=trim),
                  mk.box("Handle", (0.08, 0.5, 0.12), (sx * 2.58, -3.0, 3.5), mat=chrome),
                  pk.rounded("Mirror", (0.4, 0.3, 0.5), (sx * 2.85, -4.8, 4.6), trim, r=0.08)]
        for y in (-3.9, 3.7):
            parts += pk.wheel("W", sx * 2.1, y, 1.0, 0.7, tyre, rim, spokes=5)
    for k, (x, y) in enumerate(((-1.2, 0.5), (1.2, 0.5), (-1.2, 3.0), (0.0, 1.7))):
        parts.append(mk.box("Crate", (2.2, 2.2, 1.2), (x, y, 2.55 + (1.2 if k == 3 else 0)), mat=crate, bevel=0.05))
    parts.append(mk.tube("Rope", (-2.5, 1.7, 3.2), (2.5, 1.7, 4.3), 0.04, mat=pk.plastic("KT_Rope", (220, 200, 80)), verts=4))
    return parts, []


@prop("Bus", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo",
      lights=[dict(at=(0, 0, 9.4), kind="point", color=(236, 244, 255), range=18, brightness=0.9)])
def bus():
    """A city bus, front to -Y: white with green bands, a deep windscreen, the lit destination sign,
    two doors on the kerb side (+X), the long window band with lit seats behind, mirrors on stalks,
    the roof's air-conditioner, wheels in their arches."""
    white = pk.paint("BU_White", (232, 232, 226), rough=0.3, wear=12)
    green = pk.paint("BU_Green", (30, 140, 90), rough=0.3, wear=8)
    trim = pk.metal("BU_Trim", (24, 24, 26), (40, 40, 44), rough=0.6, metallic=0.2)
    glass = pk.dark_glass("BU_Glass")
    chrome = pk.chrome("BU_Chrome")
    tyre = pk.rubber("BU_Tyre")
    rim = pk.metal("BU_Rim", (170, 172, 176), (200, 202, 206), rough=0.3, metallic=0.8)
    lens = mk.flat("BU_Lens", srgb(236, 236, 230), 0.1)
    L, W, H = 36.4, 8.8, 10.4
    parts = [
        pk.rounded("Body", (W, L, H - 1.0), (0, 0, (H - 1.0) / 2 + 1.0), white, r=0.5),
        mk.box("Skirt", (W - 0.3, L - 1.0, 1.0), (0, 0, 0.9), mat=trim),
        mk.box("BandLow", (W + 0.04, L - 1.0, 0.8), (0, 0, 2.3), mat=green),
        mk.box("BandTop", (W + 0.04, L - 1.0, 0.25), (0, 0, 8.6), mat=green),
        mk.box("Windscreen", (W - 0.8, 0.12, 4.6), (0, -L / 2 - 0.02, 5.7), mat=glass),
        mk.box("DestFrame", (W - 1.2, 0.14, 1.1), (0, -L / 2 - 0.03, 8.9), mat=trim),
        mk.box("RearWindow", (W - 1.6, 0.1, 2.6), (0, L / 2 + 0.02, 6.6), mat=glass),
        pk.rounded("AC", (W - 1.6, 8.0, 0.8), (0, 3.0, H + 0.3), white, r=0.3),
        pk.rounded("BumperF", (W, 0.6, 0.9), (0, -L / 2 - 0.1, 1.2), trim, r=0.2),
        pk.rounded("BumperR", (W, 0.6, 0.9), (0, L / 2 + 0.1, 1.2), trim, r=0.2),
        mk.box("PlateF", (1.4, 0.06, 0.7), (0, -L / 2 - 0.42, 1.6), mat=pk.plastic("BU_Plate", (236, 236, 228))),
    ]
    for sx in (-1, 1):
        parts += [mk.box("Windows", (0.1, L - 9.0, 3.8), (sx * (W / 2 + 0.01), 1.6, 6.3), mat=glass),
                  pk.rounded("HeadLamp", (1.4, 0.2, 0.6), (sx * (W / 2 - 1.2), -L / 2 - 0.02, 2.2), lens, r=0.1),
                  mk.tube("MirrorStalk", (sx * (W / 2 - 0.3), -L / 2, 8.4), (sx * (W / 2 + 0.8), -L / 2 - 1.2, 7.8), 0.07,
                          mat=trim, verts=6),
                  pk.rounded("Mirror", (0.6, 0.3, 1.1), (sx * (W / 2 + 0.8), -L / 2 - 1.3, 7.2), trim, r=0.1)]
        for k in range(6):  # window pillars
            parts.append(mk.box("Pillar", (0.12, 0.3, 3.8), (sx * (W / 2 + 0.05), -11.3 + k * 4.6, 6.3), mat=trim))
        for y in (-10.4, 10.0):
            parts += pk.wheel("W", sx * (W / 2 - 0.6), y, 1.6, 1.0, tyre, rim, spokes=8)
            parts.append(mk.cylinder("Arch", 1.9, 0.2, (sx * (W / 2 - 0.02), y, 1.6), rot=(0, 90, 0), mat=trim, verts=20))
    for y0, y1 in ((-L / 2 + 1.0, -L / 2 + 4.2), (-1.2, 2.2)):  # the doors on the kerb side
        parts.append(mk.box("Door", (0.08, y1 - y0, 7.6), (W / 2 + 0.03, (y0 + y1) / 2, 4.6), mat=glass))
        parts.append(mk.box("DoorSplit", (0.1, 0.1, 7.6), (W / 2 + 0.05, (y0 + y1) / 2, 4.6), mat=trim))
    glows = [mk.box("Dest", (W - 1.5, 0.05, 0.8), (0, -L / 2 - 0.12, 8.9), mat=pk.glow("BU_Dest", (255, 150, 40), 4)),
             mk.box("RearDest", (3.0, 0.05, 0.6), (0, L / 2 + 0.06, 8.7), mat=pk.glow("BU_Dest", (255, 150, 40), 4)),
             mk.box("CabinGlow", (W - 0.6, L - 10.0, 2.6), (0, 1.6, 6.4), mat=pk.glow("BU_Cabin", (190, 200, 210), 1.2))]
    ink = pk.plastic("BU_PlateInk", (30, 90, 60))
    parts += pk.label("PlateT", "品川 200 か 88-01", 0.12, (0, -L / 2 - 0.46, 1.6), ink)
    return parts, glows


TRAIN_LIGHTS = [dict(at=(0, -12.0, 9.5), kind="point", color=(236, 244, 255), range=18, brightness=0.9),
                dict(at=(0, 12.0, 9.5), kind="point", color=(236, 244, 255), range=18, brightness=0.9)]


def train_car(prefix, head):
    """A metro car 51 long, facing -Y: stainless sides with the line's band, four doors a side with
    their windows, the window band lit from inside, roof air-conditioners, the gangway at its back;
    the head car's cab front has its windscreen, lamps and the lit destination sign."""
    steel = pk.metal(prefix + "Steel", (170, 174, 180), (206, 210, 214), rough=0.3, metallic=0.8, scale=6)
    band = pk.paint(prefix + "Band", (110, 60, 170), rough=0.3, wear=6)
    trim = pk.metal(prefix + "Trim", (30, 30, 34), (46, 46, 50), rough=0.5, metallic=0.3)
    glass = pk.dark_glass(prefix + "Glass", (40, 50, 60))
    rubber = pk.rubber(prefix + "Rubber")
    L, W, H = 51.0, 8.8, 11.8
    front = -L / 2
    parts = [
        pk.rounded("Body", (W, L, H - 1.4), (0, 0, (H - 1.4) / 2 + 1.4), steel, r=0.45),
        mk.box("Under", (W - 0.6, L - 4.0, 1.4), (0, 0, 0.8), mat=trim),
        mk.box("Roof", (W - 1.0, L - 1.0, 0.4), (0, 0, H + 0.1), mat=steel, bevel=0.15),
    ]
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.01)
        parts += [mk.box("Band", (0.05, L - 0.6, 0.55), (x, 0, 3.4), mat=band),
                  mk.box("BandTop", (0.05, L - 0.6, 0.3), (x, 0, 9.6), mat=band)]
        for k in range(4):  # doors
            y = front + 6.5 + k * 12.6
            parts += [mk.box("Door", (0.08, 4.4, 7.4), (x, y, 5.2), mat=steel),
                      mk.box("DoorGap", (0.1, 0.1, 7.4), (x, y, 5.2), mat=rubber),
                      mk.box("DoorWinL", (0.1, 1.4, 3.0), (x, y - 1.0, 6.5), mat=glass),
                      mk.box("DoorWinR", (0.1, 1.4, 3.0), (x, y + 1.0, 6.5), mat=glass)]
        for k in range(3):  # window bays between doors
            y = front + 12.8 + k * 12.6
            parts.append(mk.box("Window", (0.1, 7.2, 3.2), (x, y, 6.6), mat=glass))
        for y in (front + 3.0, -front - 3.0):  # bogies
            parts.append(mk.box("Bogie", (W - 1.8, 6.0, 1.2), (0, y, 0.8), mat=trim))
            for yy in (y - 1.8, y + 1.8):
                parts.append(mk.cylinder("Wheel", 0.9, 0.4, (sx * (W / 2 - 1.3), yy, 0.9), rot=(0, 90, 0), mat=trim, verts=16))
    for k in range(3):
        parts.append(pk.rounded("AC", (4.6, 5.0, 0.8), (0, front + 10 + k * 15.5, H + 0.6), steel, r=0.2))
    parts.append(mk.box("Gangway", (3.2, 0.8, 7.4), (0, -front + 0.3, 5.2), mat=rubber, bevel=0.1))
    glows = []
    for sx in (-1, 1):
        for k in range(3):
            glows.append(mk.box("Lit", (0.05, 7.0, 3.0), (sx * (W / 2 - 0.06), front + 12.8 + k * 12.6, 6.6),
                                mat=pk.glow(prefix + "Lit", (220, 228, 236), 1.4)))
    if head:
        parts += [
            mk.box("CabFront", (W, 0.5, H - 1.4), (0, front - 0.1, (H - 1.4) / 2 + 1.4), mat=band, bevel=0.3),
            mk.box("Windscreen", (W - 1.6, 0.2, 3.6), (0, front - 0.4, 7.2), mat=glass, bevel=0.1),
            mk.box("Coupler", (1.2, 1.4, 0.8), (0, front - 0.8, 1.6), mat=trim),
            mk.box("Door", (2.4, 0.1, 6.6), (0, front - 0.38, 5.0), mat=steel),
        ]
        glows += [mk.box("Dest", (4.2, 0.05, 0.9), (0, front - 0.52, 9.6), mat=pk.glow(prefix + "Dest", (255, 160, 60), 4)),
                  mk.box("HeadL", (1.0, 0.05, 0.5), (-2.9, front - 0.37, 3.0), mat=pk.glow(prefix + "Head", (255, 250, 230), 5)),
                  mk.box("HeadR", (1.0, 0.05, 0.5), (2.9, front - 0.37, 3.0), mat=pk.glow(prefix + "Head", (255, 250, 230), 5))]
    return parts, glows


@prop("TrainHead", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", lights=TRAIN_LIGHTS)
def train_head():
    return train_car("TH_", True)


@prop("TrainMiddle", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", lights=TRAIN_LIGHTS)
def train_middle():
    return train_car("TM_", False)


# The bus stop and the taxi rank ---------------------------------------------------------------------------


@prop("BusShelter", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo",
      lights=[dict(at=(0, 0.2, 7.6), kind="point", color=(236, 240, 255), range=14, brightness=0.8)])
def bus_shelter():
    """A bus shelter 12 long, open to the kerb (-Y): a steel frame under a curved roof with its
    strip light, frosted glass at the back (+Y) and the ends, a lit advert at one end, the route
    map and a slatted bench."""
    steel = pk.metal("BS_Steel", (70, 72, 78), (100, 102, 108))
    frosted = mk.noisy("BS_Frosted", srgb(150, 160, 170), srgb(186, 194, 202), scale=4, roughness=0.3)
    wood = mk.wood("BS_Wood", srgb(150, 106, 66), srgb(92, 62, 38))
    white = pk.plastic("BS_White", (236, 236, 232))
    parts = [
        mk.box("Roof", (12.4, 4.4, 0.25), (0, 0, 8.5), rot=(-4, 0, 0), mat=steel, bevel=0.1),
        mk.box("Fascia", (12.4, 0.3, 0.6), (0, -2.15, 8.3), mat=steel, bevel=0.05),
        mk.box("BackGlass", (11.6, 0.1, 6.4), (0, 1.9, 4.2), mat=frosted),
        mk.box("MapPanel", (3.0, 0.08, 2.4), (-2.5, 1.82, 5.0), mat=white),
        mk.box("BenchSeat", (6.0, 1.1, 0.18), (1.5, 1.2, 1.7), mat=wood, bevel=0.03),
        mk.box("BenchBack", (6.0, 0.14, 0.9), (1.5, 1.72, 2.4), mat=wood, bevel=0.03),
    ]
    for x in (-6.0, -2.0, 2.0, 6.0):
        parts.append(mk.box("Post", (0.25, 0.25, 8.4), (x, 1.95, 4.2), mat=steel, bevel=0.03))
    for x in (-6.0, 6.0):
        parts.append(mk.box("EndGlass", (0.1, 3.2, 6.4), (x, 0.35, 4.2), mat=frosted))
        parts.append(mk.box("EndPost", (0.25, 0.25, 8.4), (x, -1.2, 4.2), mat=steel, bevel=0.03))
    for x in (-1.0, 4.0):
        parts.append(mk.box("BenchLeg", (0.2, 1.0, 1.6), (x, 1.2, 0.8), mat=steel))
    ink = pk.plastic("BS_Ink", (30, 30, 34))
    parts += pk.label("MapTitle", "路線図 ROUTE MAP", 0.2, (-2.5, 1.77, 6.0), ink)
    glows = [mk.box("Strip", (10.0, 0.4, 0.06), (0, -0.3, 8.33), mat=pk.glow("BS_Strip", (236, 240, 255), 3)),
             mk.box("Advert", (0.06, 2.6, 5.0), (-5.9, 0.35, 4.3), mat=pk.glow("BS_Ad", (255, 200, 150), 2))]
    return parts, glows


@prop("BusStopSign", pivot="bottom", material="Metal", collide=False, texture=512, set="Tokyo", anchor=(0, 0))
def bus_stop_sign():
    """The bus stop's post: a round sign with the stop's name on top, the lit timetable box below,
    a weighted base."""
    steel = pk.metal("BP_Steel", (150, 152, 158), (180, 182, 188), rough=0.35, metallic=0.5)
    green = pk.plastic("BP_Green", (30, 140, 90))
    white = pk.plastic("BP_White", (240, 240, 236))
    parts = [mk.cylinder("Base", 0.8, 0.4, (0, 0, 0.2), mat=steel, verts=16),
             mk.cylinder("Pole", 0.12, 8.2, (0, 0, 4.3), mat=steel, verts=10),
             mk.cylinder("Disc", 0.9, 0.12, (0, 0, 8.3), rot=(90, 0, 0), mat=green, verts=28),
             mk.cylinder("DiscIn", 0.72, 0.14, (0, 0, 8.3), rot=(90, 0, 0), mat=white, verts=28),
             mk.box("TimeBox", (1.6, 0.4, 2.2), (0, 0, 4.8), mat=steel, bevel=0.05)]
    ink = pk.plastic("BP_Ink", (30, 30, 34))
    for side in (1, -1):
        parts += pk.label("Stop", "影ヶ丘駅", 0.28, (0, -side * 0.08, 8.4), ink, rot=(90, 0, 0 if side > 0 else 180))
        parts += pk.label("Bus", "バス", 0.24, (0, -side * 0.08, 8.0), ink, rot=(90, 0, 0 if side > 0 else 180))
    glows = [mk.box("Timetable", (1.3, 0.05, 1.8), (0, -0.22, 4.8), mat=pk.glow("BP_Lit", (240, 244, 250), 2))]
    return parts, glows


@prop("TaxiRankSign", pivot="bottom", material="Metal", collide=False, texture=512, set="Tokyo", anchor=(0, 0))
def taxi_rank_sign():
    """The taxi rank's post: a lit box sign reading タクシーのりば TAXI on both faces."""
    steel = pk.metal("TR_Steel", (60, 62, 68), (90, 92, 98))
    ink = pk.plastic("TR_Ink", (24, 24, 30))
    parts = [mk.cylinder("Base", 0.7, 0.3, (0, 0, 0.15), mat=steel, verts=16),
             mk.cylinder("Pole", 0.13, 7.4, (0, 0, 3.9), mat=steel, verts=10),
             mk.box("Box", (2.6, 0.7, 1.9), (0, 0, 8.2), mat=steel, bevel=0.08)]
    glows = []
    for side in (1, -1):
        y = -side * 0.37
        glows.append(mk.box("Face", (2.3, 0.04, 1.6), (0, y, 8.2), mat=pk.glow("TR_Face", (252, 214, 70), 3)))
        parts += pk.label("Taxi", "タクシーのりば", 0.24, (0, y - side * 0.03, 8.5), ink, rot=(90, 0, 0 if side > 0 else 180))
        parts += pk.label("TaxiEn", "TAXI", 0.4, (0, y - side * 0.03, 7.9), ink, rot=(90, 0, 0 if side > 0 else 180))
    return parts, glows


# The station ----------------------------------------------------------------------------------------------


@prop("TicketGate", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def ticket_gate():
    """An automatic ticket gate cabinet, 1.2 wide and 5.6 long, the passage along Y (in at -Y):
    the IC card reader glowing at the entry end, the ticket slot and its return, a small screen,
    orange flaps halfway on both sides, a green arrow at the entry and a red bar at the exit."""
    body = pk.paint("TG_Body", (206, 208, 210), rough=0.3, wear=8)
    top = pk.metal("TG_Top", (40, 42, 46), (60, 62, 66), rough=0.4, metallic=0.3)
    flap = pk.plastic("TG_Flap", (236, 120, 40))
    chrome = pk.chrome("TG_Chrome")
    parts = [
        pk.rounded("Body", (1.2, 5.6, 3.3), (0, 0, 1.75), body, r=0.12),
        mk.box("Plinth", (1.1, 5.4, 0.12), (0, 0, 0.06), mat=top),
        mk.box("Top", (1.3, 5.7, 0.14), (0, 0, 3.45), mat=top, bevel=0.05),
        mk.box("Slot", (0.5, 0.2, 0.04), (0, -1.2, 3.53), mat=chrome),
        mk.box("Return", (0.5, 0.2, 0.04), (0, 1.4, 3.53), mat=chrome),
        mk.box("ScreenFrame", (0.8, 0.5, 0.3), (0, -0.3, 3.62), rot=(-30, 0, 0), mat=top),
    ]
    for sx in (-1, 1):
        parts += [mk.box("Flap", (0.08, 0.9, 1.3), (sx * 0.64, 0.4, 2.4), mat=flap, bevel=0.03),
                  mk.box("Stripe", (0.02, 5.4, 0.12), (sx * 0.605, 0, 2.9), mat=top)]
    glows = [mk.box("Reader", (0.8, 0.8, 0.05), (0, -2.1, 3.54), mat=pk.glow("TG_Reader", (80, 180, 255), 4)),
             mk.box("Screen", (0.6, 0.05, 0.3), (0, -0.44, 3.62), rot=(-30, 0, 0), mat=pk.glow("TG_Screen", (120, 220, 255), 3)),
             mk.box("Arrow", (0.5, 0.05, 0.4), (0, -2.81, 2.6), mat=pk.glow("TG_Green", (80, 255, 150), 4)),
             mk.box("NoEntry", (0.5, 0.05, 0.4), (0, 2.81, 2.6), mat=pk.glow("TG_Red", (255, 60, 60), 4))]
    return parts, glows


@prop("TicketMachine", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def ticket_machine():
    """A ticket and IC-card machine: a hood with its lamp, the fare map above, a slanted touch
    screen, slots for coins, notes and cards, the ticket outlet and the change tray."""
    body = pk.paint("TM_Body", (214, 216, 218), rough=0.3, wear=8)
    dark = pk.metal("TM_Dark", (30, 32, 36), (46, 48, 52), rough=0.4, metallic=0.3)
    chrome = pk.chrome("TM_Chrome")
    white = pk.plastic("TM_White", (244, 244, 240))
    ink = pk.plastic("TM_Ink", (24, 24, 30))
    parts = [
        pk.rounded("Body", (3.2, 2.1, 5.6), (0, 0, 2.8), body, r=0.1),
        mk.box("Hood", (3.3, 1.0, 0.4), (0, -0.6, 6.2), mat=dark, bevel=0.06),
        mk.box("Map", (3.0, 0.06, 1.0), (0, -1.07, 5.35), mat=white),
        mk.box("Desk", (3.0, 0.9, 0.12), (0, -1.1, 3.4), rot=(-25, 0, 0), mat=dark),
        mk.box("CoinSlot", (0.1, 0.06, 0.4), (-1.0, -1.08, 2.8), mat=chrome),
        mk.box("NoteSlot", (0.8, 0.06, 0.1), (0.2, -1.08, 2.8), mat=chrome),
        mk.box("CardSlot", (0.6, 0.06, 0.08), (1.1, -1.08, 2.8), mat=chrome),
        mk.box("Outlet", (1.4, 0.3, 0.4), (-0.5, -1.0, 1.6), mat=dark, bevel=0.03),
        mk.box("Tray", (0.9, 0.4, 0.3), (1.0, -1.0, 1.6), mat=chrome, bevel=0.03),
        mk.box("Plinth", (3.0, 1.9, 0.2), (0, 0, 0.1), mat=dark),
    ]
    parts += pk.label("Title", "きっぷ・ICカード", 0.22, (0, -1.1, 5.72), ink)
    for k, line in enumerate(("影ヶ丘 ─ 140", "中央 ─ 180", "港 ─ 210")):
        parts += pk.label("Fare", line, 0.13, (-0.6 + k * 0.0, -1.1, 5.45 - k * 0.2), ink)
    glows = [mk.box("Screen", (2.0, 0.05, 0.95), (0, -1.18, 3.65), rot=(-25, 0, 0), mat=pk.glow("TM_Screen", (120, 200, 255), 3)),
             mk.box("HoodLamp", (3.0, 0.4, 0.05), (0, -0.7, 5.98), mat=pk.glow("TM_Lamp", (240, 244, 255), 3))]
    return parts, glows


@prop("StationSignHanging", pivot="centre", material="Metal", collide=False, texture=1024, set="Tokyo")
def station_sign_hanging():
    """A lit double-faced platform sign on two rods: のりば 1・2 Platforms, arrows either way."""
    frame = pk.metal("SH_Frame", (30, 30, 34), (46, 46, 50), rough=0.4, metallic=0.4)
    ink = pk.plastic("SH_Ink", (20, 22, 30))
    parts = [mk.box("Box", (10.4, 0.6, 1.9), (0, 0, 0), mat=frame, bevel=0.06)]
    for x in (-4.2, 4.2):
        parts.append(mk.cylinder("Rod", 0.06, 2.4, (x, 0, 2.15), mat=frame, verts=8))
    glows = []
    for side in (1, -1):
        y = -side * 0.31
        glows.append(mk.box("Face", (10.0, 0.04, 1.6), (0, y, 0), mat=pk.glow("SH_Face", (236, 238, 232), 2.5)))
        rot = (90, 0, 0 if side > 0 else 180)
        parts += pk.label("Main", "のりば 1・2", 0.5, (-2.0 * side, y - side * 0.03, 0.2), ink, rot=rot)
        parts += pk.label("En", "Platforms", 0.3, (-2.0 * side, y - side * 0.03, -0.45), ink, rot=rot)
        parts += pk.label("Arrow", "↓", 0.8, (3.8 * side, y - side * 0.03, 0), ink, rot=rot)
    return parts, glows


@prop("PlatformBench", pivot="bottom", material="Metal", collide=True, texture=512, set="Tokyo")
def platform_bench():
    """A platform bench: four moulded seats on a steel beam and two legs."""
    steel = pk.metal("PB_Steel", (80, 82, 88), (110, 112, 118))
    seat = pk.plastic("PBe_Seat", (60, 110, 170))
    parts = [mk.box("Beam", (6.2, 0.3, 0.3), (0, 0.1, 1.5), mat=steel)]
    for x in (-2.4, 2.4):
        parts += [mk.box("Leg", (0.3, 0.3, 1.5), (x, 0.1, 0.75), mat=steel), mk.box("Foot", (0.6, 1.2, 0.1), (x, 0.1, 0.05),
                                                                                 mat=steel)]
    for k in range(4):
        x = -2.25 + k * 1.5
        parts += [pk.rounded("Seat", (1.35, 1.3, 0.2), (x, -0.1, 1.75), seat, r=0.1),
                  pk.rounded("Back", (1.35, 0.2, 1.4), (x, 0.55, 2.5), seat, r=0.1)]
    return parts, []


@prop("CoinLockers", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def coin_lockers():
    """A bank of coin lockers 6 wide: doors of three sizes with numbers and lock panels, the
    payment panel with its screen in the middle, a header sign."""
    body = pk.paint("CL_Body", (200, 204, 208), rough=0.3, wear=10)
    door = pk.paint("CL_Door", (170, 186, 200), rough=0.3, wear=8)
    dark = pk.metal("CL_Dark", (40, 42, 46), (60, 62, 66))
    white = pk.plastic("CL_White", (244, 244, 240))
    ink = pk.plastic("CL_Ink", (24, 24, 30))
    parts = [pk.rounded("Body", (6.0, 2.6, 6.8), (0, 0, 3.5), body, r=0.06),
             mk.box("Header", (6.0, 0.1, 0.6), (0, -1.32, 6.6), mat=pk.plastic("CL_Header", (30, 60, 130)))]
    parts += pk.label("Title", "コインロッカー COIN LOCKERS", 0.22, (0, -1.38, 6.6), white)
    n = 1
    for col, x in enumerate((-2.25, -0.75, 2.25)):
        rows = (5, 3, 4)[col]
        h = 6.0 / rows
        for r in range(rows):
            z = 0.3 + h * (r + 0.5)
            parts.append(mk.box("Door", (1.4, 0.06, h - 0.1), (x, -1.32, z), mat=door, bevel=0.02))
            parts.append(mk.box("Plate", (0.4, 0.03, 0.2), (x - 0.4, -1.36, z + h / 2 - 0.25), mat=white))
            parts += pk.label("Num", str(n), 0.14, (x - 0.4, -1.39, z + h / 2 - 0.25), ink)
            parts.append(mk.box("Lock", (0.25, 0.05, 0.35), (x + 0.5, -1.37, z), mat=dark))
            n += 1
    parts.append(mk.box("PayPanel", (1.4, 0.08, 6.0), (0.75, -1.32, 3.3), mat=dark))
    glows = [mk.box("Screen", (1.0, 0.05, 0.8), (0.75, -1.38, 4.4), mat=pk.glow("CL_Screen", (120, 200, 255), 3)),
             mk.box("Reader", (0.6, 0.05, 0.6), (0.75, -1.38, 3.3), mat=pk.glow("CL_Reader", (80, 180, 255), 3))]
    return parts, glows


@prop("StationClock", pivot="centre", material="Metal", collide=False, texture=1024, set="Tokyo")
def station_clock():
    """A double-faced station clock, 3 across, hung from the ceiling on a rod: a deep round case,
    white backlit faces with bold hour bars, black hands and a red seconds hand; its top meets a
    ceiling 3 above the case."""
    case = pk.metal("SC_Case", (30, 30, 34), (48, 48, 52), rough=0.35, metallic=0.5)
    ink = pk.plastic("SC_Ink", (18, 18, 20))
    red = pk.plastic("SC_Red", (210, 30, 36))
    R = 1.5
    parts = [
        mk.cylinder("Case", R + 0.15, 0.9, (0, 0, 0), rot=(90, 0, 0), mat=case, verts=40, bevel=0.1),
        mk.cylinder("Rod", 0.1, 3.0, (0, 0, R + 1.6), mat=case, verts=10),
        mk.cylinder("Canopy", 0.4, 0.15, (0, 0, R + 3.05), mat=case, verts=16),
        mk.box("Clamp", (0.5, 0.5, 0.3), (0, 0, R + 0.2), mat=case),
    ]
    glows = []
    for side in (1, -1):
        y = -side * 0.46
        glows.append(mk.cylinder("Face", R, 0.03, (0, y, 0), rot=(90, 0, 0), mat=pk.glow("SC_Face", (244, 244, 238), 2),
                                 verts=40))
        yy = y - side * 0.03
        for k in range(12):
            a = math.radians(k * 30)
            long = k % 3 == 0
            length = 0.36 if long else 0.2
            width = 0.12 if long else 0.07
            r = R - 0.12 - length / 2
            parts.append(mk.box("Mark", (width, 0.03, length), (math.sin(a) * r * side, yy, math.cos(a) * r),
                                rot=(0, k * 30 * side, 0), mat=ink))
        parts += [mk.box("Hour", (0.12, 0.04, 0.8), (0.28 * side, yy - side * 0.02, 0.2), rot=(0, 55 * side, 0), mat=ink),
                  mk.box("Minute", (0.08, 0.04, 1.15), (-0.2 * side, yy - side * 0.04, 0.5), rot=(0, -22 * side, 0), mat=ink),
                  mk.box("Second", (0.03, 0.04, 1.2), (0.05 * side, yy - side * 0.06, -0.55), rot=(0, 170 * side, 0), mat=red),
                  mk.cylinder("Pin", 0.08, 0.1, (0, yy - side * 0.05, 0), rot=(90, 0, 0), mat=ink, verts=10)]
    return parts, glows
