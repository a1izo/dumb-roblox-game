"""Tokyo's street props (set "Tokyo", exported to DeathsGambitModels_Tokyo.fbx): the lamp, the traffic
and walk signals, the power pole, road signs, the guard rail and bollards, the post box, recycling
bins, bicycles in and out of their rack, a scooter, a planter and the two vending machines; and
the barriers that close the streets leaving the map (site fence, police tape, barricade, cone,
patrol car). Vehicles and the station's things are in props_tokyo_transit.py, shops in
props_tokyo_shops.py, the yokocho and the river in props_tokyo_yokocho.py, trees in
props_tokyo_trees.py.

Built to the semi-real standard (propkit): real sizes at about 3.5 studs to the metre, bevelled
edges, the small parts that make a thing read as real (bolts, seams, vents, labels), textured
materials baked with ambient occlusion. Props face -Y and stand on z = 0. Poles are built at
x = y = 0 with their anchor there, so a map places the pole's foot where it asks. Every lamp
carries its own light (props.prop)."""

import math

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop

WARM_LIGHT = (255, 232, 196)
GREEN = (60, 255, 190)


def galvanised(name):
    return pk.metal(name, (118, 122, 126), (150, 154, 158), rough=0.45, metallic=0.5, scale=22)


# Lamps and signals ---------------------------------------------------------------------------------


@prop("StreetLightTokyo", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo",
      anchor=(0, 0),
      lights=[dict(at=(0, -4.3, 16.4), kind="spot", face="Bottom", angle=120, color=WARM_LIGHT, range=30,
                   brightness=2.6)])
def street_light():
    """A galvanised road lamp: a tapered pole on a bolted base plate with its access hatch, a
    curved arm over the road and a slim LED luminaire with cooling fins on its back."""
    steel = galvanised("SL_Steel")
    dark = pk.metal("SL_Dark", (46, 48, 52), (70, 72, 76), rough=0.5)
    concrete = mk.noisy("SL_Concrete", srgb(112, 110, 106), srgb(140, 138, 134), scale=12, roughness=0.85)
    parts = [
        mk.cylinder("Plinth", 0.9, 0.5, (0, 0, 0.25), mat=concrete, verts=16, bevel=0.06),
        mk.box("Plate", (1.2, 1.2, 0.12), (0, 0, 0.56), mat=steel, bevel=0.03),
        mk.cylinder("Collar", 0.38, 0.9, (0, 0, 1.05), mat=steel, verts=16, bevel=0.03),
        mk.cylinder("Pole", 0.33, 14.8, (0, 0, 8.5), mat=steel, verts=16, radius2=0.22),
        mk.box("Hatch", (0.36, 0.08, 1.1), (0, -0.33, 2.2), mat=steel, bevel=0.02),
        mk.cylinder("Joint", 0.24, 0.5, (0, 0, 15.9), mat=steel, verts=12),
        mk.tube("Arm1", (0, 0, 16.0), (0, -0.9, 16.8), 0.17, mat=steel, verts=10),
        mk.tube("Arm2", (0, -0.9, 16.8), (0, -2.4, 17.1), 0.15, mat=steel, verts=10),
        mk.tube("Arm3", (0, -2.4, 17.1), (0, -3.2, 17.05), 0.14, mat=steel, verts=10),
        # The luminaire: a tapered housing, a lens tray under it, fins on top.
        mk.box("Housing", (1.1, 2.4, 0.34), (0, -4.3, 16.95), rot=(-5, 0, 0), mat=dark, bevel=0.12, segments=3),
        mk.box("Tray", (0.9, 2.0, 0.08), (0, -4.35, 16.75), rot=(-5, 0, 0), mat=dark, bevel=0.03),
        mk.box("PlateID", (0.45, 0.05, 0.7), (0, -0.33, 6.2), mat=pk.plastic("SL_ID", (232, 232, 226))),
        mk.box("PlateBlue", (0.5, 0.05, 1.3), (0, -0.33, 7.4), mat=pk.plastic("SL_Blue", (30, 80, 170))),
    ]
    for k in range(7):
        parts.append(mk.box("Fin", (0.9, 0.06, 0.12), (0, -3.5 - k * 0.27, 17.18 + k * 0.024), mat=dark))
    parts += pk.bolts("Bolt", [(sx * 0.45, sy * 0.45, 0.66) for sx in (-1, 1) for sy in (-1, 1)], steel, r=0.07,
                      depth=0.1, axis="z")
    parts += pk.bolts("HatchScrew", [(0, -0.38, 1.75), (0, -0.38, 2.65)], dark, r=0.04)
    glow = [mk.box("Led", (0.8, 1.8, 0.04), (0, -4.36, 16.7), rot=(-5, 0, 0),
                   mat=pk.glow("SL_Glow", (255, 236, 210), 5))]
    return parts, glow


SIGNAL_LAMPS = (-6.3, -7.5, -8.7)  # the three lamps along the arm: green, amber, red from the pole outward


@prop("TrafficSignal", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      lights=[dict(at=(-1.0, SIGNAL_LAMPS[0], 12.6), kind="point", color=GREEN, range=10, brightness=0.8)])
def traffic_signal():
    """A Japanese signal: a kerbside pole, an arm over the lane with a street-name plate, and a
    flat horizontal three-lamp LED head facing oncoming traffic (along -X) under its visors;
    green lit."""
    steel = galvanised("TS_Steel")
    dark = pk.metal("TS_Dark", (30, 30, 34), (48, 48, 52), rough=0.5, metallic=0.2)
    off = {"amber": mk.flat("TS_AmberOff", srgb(96, 64, 12), 0.25), "red": mk.flat("TS_RedOff", srgb(88, 14, 14), 0.25)}
    white = pk.plastic("TS_White", (234, 234, 230))
    blue = pk.plastic("TS_Blue", (26, 70, 160))
    parts = [
        mk.cylinder("Base", 0.6, 0.7, (0, 0, 0.35), mat=steel, verts=16, bevel=0.05),
        mk.cylinder("Pole", 0.36, 13.2, (0, 0, 7.0), mat=steel, verts=16, radius2=0.27),
        mk.cylinder("Cap", 0.3, 0.2, (0, 0, 13.7), mat=steel, verts=12),
        mk.tube("Arm", (0, 0, 12.9), (0, -10.0, 12.9), 0.19, mat=steel, verts=12),
        mk.tube("Brace", (0, 0, 11.1), (0, -3.8, 12.9), 0.09, mat=steel, verts=8),
        mk.cylinder("ArmEnd", 0.22, 0.2, (0, -10.05, 12.9), rot=(90, 0, 0), mat=steel, verts=12),
        mk.box("Mount", (0.3, 0.3, 0.5), (0, -7.5, 13.25), mat=steel),
        mk.box("Head", (0.5, 4.2, 1.4), (-0.3, -7.5, 12.6), mat=dark, bevel=0.12, segments=3),
        mk.box("BackPlate", (0.08, 4.6, 1.8), (0.0, -7.5, 12.6), mat=white, bevel=0.05),
        # The street-name plate on the arm (blue with white letters, both sides).
        mk.box("NamePlate", (0.08, 3.4, 0.9), (0, -3.2, 13.55), mat=blue, bevel=0.03),
        mk.box("PedButton", (0.5, 0.35, 0.8), (0, -0.4, 3.8), mat=pk.plastic("TS_Yellow", (232, 196, 50)),
               bevel=0.06),
    ]
    for side in (-1, 1):  # both faces of the plate
        parts += pk.label("Name", "影ヶ丘駅前", 0.34, (side * 0.05, -3.2, 13.68), white, rot=(90, 0, 90 * side))
        parts += pk.label("NameEn", "Kagegaoka Sta.", 0.2, (side * 0.05, -3.2, 13.32), white, rot=(90, 0, 90 * side))
    for y, colour in zip(SIGNAL_LAMPS[1:], ("amber", "red")):
        parts.append(mk.cylinder("Lamp", 0.5, 0.06, (-0.57, y, 12.6), rot=(0, 90, 0), mat=off[colour], verts=24))
    for y in SIGNAL_LAMPS:
        parts.append(mk.cylinder("Visor", 0.58, 0.5, (-0.83, y, 12.75), rot=(0, 90, 0), mat=dark, verts=20,
                                 radius2=0.6))
        parts.append(mk.torus("Ring", 0.55, 0.04, (-0.58, y, 12.6), rot=(0, 90, 0), mat=dark, major_segments=20,
                              minor_segments=4))
    glow = [mk.cylinder("Green", 0.5, 0.06, (-0.58, SIGNAL_LAMPS[0], 12.6), rot=(0, 90, 0),
                        mat=pk.glow("TS_Green", GREEN, 5), verts=24)]
    return parts, glow


@prop("PedestrianSignal", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      lights=[dict(at=(0, -1.1, 7.3), kind="point", color=GREEN, range=5, brightness=0.6)])
def pedestrian_signal():
    """A walk signal: two lamps in one housing (a red standing figure, dark; a green walking one,
    lit), each under a hood, on a slim pole with the push-button box."""
    steel = galvanised("PS_Steel")
    dark = pk.metal("PS_Dark", (30, 30, 34), (48, 48, 52), rough=0.5, metallic=0.2)
    red_off = mk.flat("PS_RedOff", srgb(92, 20, 18), 0.3)
    red_fig = mk.flat("PS_RedFig", srgb(130, 34, 30), 0.3)
    parts = [
        mk.cylinder("Pole", 0.22, 9.4, (0, 0, 4.7), mat=steel, verts=12),
        mk.box("Clamp", (0.5, 0.5, 0.4), (0, -0.2, 8.0), mat=steel),
        mk.box("Head", (1.4, 0.8, 2.9), (0, -0.7, 8.0), mat=dark, bevel=0.1, segments=3),
        mk.box("RedPane", (1.1, 0.05, 1.15), (0, -1.12, 8.7), mat=red_off),
        mk.box("ButtonBox", (0.7, 0.45, 1.1), (0, -0.4, 3.7), mat=pk.plastic("PS_Yellow", (232, 196, 50)), bevel=0.08),
        mk.cylinder("Button", 0.16, 0.12, (0, -0.66, 3.55), rot=(90, 0, 0), mat=pk.plastic("PS_ButtonRed", (200, 30, 36)),
                    verts=12),
    ]
    parts += pk.label("Push", "押ボタン", 0.12, (0, -0.64, 4.05), pk.plastic("PS_Ink", (20, 20, 24)))
    # The standing figure on the red pane: head, body, legs.
    parts += [mk.cylinder("RFHead", 0.12, 0.04, (0, -1.15, 9.05), rot=(90, 0, 0), mat=red_fig, verts=10),
              mk.box("RFBody", (0.26, 0.04, 0.42), (0, -1.15, 8.75), mat=red_fig),
              mk.box("RFLegs", (0.2, 0.04, 0.34), (0, -1.15, 8.38), mat=red_fig)]
    for z in (8.7, 7.3):
        parts.append(mk.box("Hood", (1.35, 0.7, 0.08), (0, -1.45, z + 0.6), rot=(-14, 0, 0), mat=dark))
        parts += [mk.box("HoodSide", (0.06, 0.6, 1.1), (sx * 0.66, -1.42, z + 0.1), mat=dark) for sx in (-1, 1)]
    green = pk.glow("PS_Green", GREEN, 5)
    glow = [mk.box("GreenPane", (1.1, 0.05, 1.15), (0, -1.12, 7.3), mat=pk.glow("PS_GreenDim", (20, 80, 60), 2)),
            mk.cylinder("GFHead", 0.12, 0.06, (0.05, -1.16, 7.65), rot=(90, 0, 0), mat=green, verts=10),
            mk.box("GFBody", (0.24, 0.06, 0.4), (0.02, -1.16, 7.35), rot=(0, 10, 0), mat=green),
            mk.box("GFLegF", (0.1, 0.06, 0.38), (0.14, -1.16, 6.98), rot=(0, -24, 0), mat=green),
            mk.box("GFLegB", (0.1, 0.06, 0.38), (-0.12, -1.16, 6.98), rot=(0, 24, 0), mat=green)]
    return parts, glow


@prop("UtilityPole", pivot="bottom", material="Concrete", collide=False, texture=1024, set="Tokyo", anchor=(0, 0))
def utility_pole():
    """A concrete power pole: yellow-and-black warning bands at its foot, climbing steps, an
    advert plate, a transformer with its bushings and cables, two braced crossarms with
    insulators (the map strings its wires between the arms' ends at x = +-2.3, heights 23.4 and
    20.8)."""
    concrete = mk.noisy("UP_Concrete", srgb(126, 124, 118), srgb(160, 158, 152), scale=10, roughness=0.8)
    steel = pk.metal("UP_Steel", (70, 72, 76), (104, 106, 112))
    porcelain = mk.flat("UP_Insulator", srgb(214, 210, 200), 0.3)
    grey_box = pk.paint("UP_Transformer", (130, 136, 140))
    cable = pk.rubber("UP_Cable")
    parts = [
        mk.cylinder("Pole", 0.56, 26.0, (0, 0, 13.0), mat=concrete, verts=16, radius2=0.38),
        mk.cylinder("Cap", 0.4, 0.3, (0, 0, 26.1), mat=concrete, verts=12, radius2=0.3),
        mk.box("ArmTop", (5.0, 0.32, 0.32), (0, 0, 23.2), mat=steel),
        mk.box("ArmLow", (4.4, 0.32, 0.32), (0, 0, 20.6), mat=steel),
        mk.tube("BraceL", (-1.6, 0, 23.05), (0, 0, 22.0), 0.06, mat=steel, verts=6),
        mk.tube("BraceR", (1.6, 0, 23.05), (0, 0, 22.0), 0.06, mat=steel, verts=6),
        mk.cylinder("Transformer", 0.85, 2.4, (0, 1.05, 17.4), mat=grey_box, verts=20),
        mk.cylinder("TransLid", 0.9, 0.18, (0, 1.05, 18.7), mat=grey_box, verts=20),
        mk.box("Bracket", (0.4, 0.7, 1.8), (0, 0.5, 17.4), mat=steel),
        mk.box("AdPlate", (0.8, 0.06, 2.2), (0, -0.5, 8.6), mat=pk.plastic("UP_Ad", (24, 70, 150))),
    ]
    white = pk.plastic("UP_Ink", (240, 240, 236))
    parts += pk.label("Ad", "影ヶ丘2", 0.24, (0, -0.54, 9.1), white, rot=(90, 0, 0))
    parts += pk.label("Ad2", "眼科", 0.3, (0, -0.54, 8.3), white, rot=(90, 0, 0))
    for k in range(3):  # the transformer's bushings and its cables up to the lower arm
        x = -0.4 + k * 0.4
        parts.append(mk.cylinder("Bushing", 0.08, 0.4, (x, 1.05, 18.95), mat=porcelain, verts=8))
        parts.append(mk.tube("Cable", (x, 1.05, 19.15), (x * 3, 0.1, 20.4), 0.04, mat=cable, verts=5))
    for x in (-2.3, -1.2, 1.2, 2.3):
        parts.append(mk.lathe("Ins", [(0.0, 0), (0.16, 0.02), (0.16, 0.1), (0.1, 0.16), (0.16, 0.24), (0.16, 0.3),
                                      (0.08, 0.38), (0.0, 0.42)], (x, 0, 23.36), mat=porcelain, segments=10))
    for x in (-2.0, 2.0):
        parts.append(mk.lathe("Ins", [(0.0, 0), (0.15, 0.02), (0.15, 0.1), (0.09, 0.16), (0.15, 0.24), (0.07, 0.34),
                                      (0.0, 0.38)], (x, 0, 20.76), mat=porcelain, segments=10))
    # Yellow and black warning bands at the foot.
    for k in range(6):
        mat = pk.plastic("UP_BandY", (230, 190, 40)) if k % 2 == 0 else pk.plastic("UP_BandK", (24, 24, 26))
        parts.append(mk.cylinder("Band", 0.575, 0.3, (0, 0, 1.2 + k * 0.3), mat=mat, verts=16))
    for k in range(10):
        a = math.radians(90 * (k % 2) + 45)
        parts.append(mk.box("Step", (0.8, 0.09, 0.09), (math.cos(a) * 0.5, math.sin(a) * 0.5, 7.5 + k * 1.3),
                            rot=(0, 0, math.degrees(a)), mat=steel))
    return parts, []


@prop("RoadSign", pivot="bottom", material="Metal", collide=False, texture=512, set="Tokyo", anchor=(0, 0))
def road_sign():
    """A sign post: a no-parking disc over the blue pedestrian-crossing square, both on clamps,
    their backs grey with the post's brackets."""
    steel = galvanised("RS_Steel")
    blue = pk.plastic("RS_Blue", (20, 70, 170))
    red = pk.plastic("RS_Red", (200, 30, 40))
    white = pk.plastic("RS_White", (238, 238, 234))
    back = pk.paint("RS_Back", (150, 152, 156))
    parts = [
        mk.cylinder("Pole", 0.15, 9.8, (0, 0, 4.9), mat=steel, verts=12),
        mk.cylinder("PoleCap", 0.17, 0.1, (0, 0, 9.85), mat=steel, verts=12),
        mk.cylinder("DiscBack", 1.12, 0.06, (0, -0.2, 8.6), rot=(90, 0, 0), mat=back, verts=32),
        mk.cylinder("Disc", 1.1, 0.04, (0, -0.25, 8.6), rot=(90, 0, 0), mat=red, verts=32),
        mk.cylinder("DiscIn", 0.84, 0.05, (0, -0.26, 8.6), rot=(90, 0, 0), mat=blue, verts=32),
        mk.box("Slash", (1.7, 0.06, 0.2), (0, -0.29, 8.6), rot=(0, 45, 0), mat=red),
        mk.box("SquareBack", (2.1, 0.06, 2.1), (0, -0.2, 6.3), mat=back, bevel=0.1),
        mk.box("Square", (2.0, 0.04, 2.0), (0, -0.25, 6.3), mat=blue, bevel=0.1),
        mk.box("Tri", (1.2, 0.05, 0.08), (0, -0.28, 5.75), mat=white),
        mk.cylinder("WalkerHead", 0.16, 0.05, (-0.1, -0.29, 6.85), rot=(90, 0, 0), mat=white, verts=10),
        mk.box("WalkerBody", (0.22, 0.05, 0.7), (0, -0.29, 6.4), rot=(0, 12, 0), mat=white),
        mk.box("Stripe1", (0.9, 0.05, 0.1), (0.1, -0.29, 5.95), mat=white),
    ]
    for z in (8.6, 6.3):
        parts += [mk.box("Clamp", (0.4, 0.2, 0.12), (0, -0.1, z + dz), mat=steel) for dz in (-0.5, 0.5)]
    return parts, []


@prop("GuardRail", pivot="bottom", material="Metal", collide=True, texture=512, set="Tokyo")
def guard_rail():
    """A pedestrian guard rail 8 long: white-painted posts, a round top rail, a flat mid rail and
    vertical bars, feet set in the kerb."""
    paint = pk.paint("GR_White", (222, 222, 216), wear=26)
    parts = [mk.tube("Top", (-4.0, 0, 2.9), (4.0, 0, 2.9), 0.11, mat=paint, verts=10),
             mk.box("Mid", (8.0, 0.08, 0.28), (0, 0, 1.4), mat=paint, bevel=0.02)]
    for x in (-3.9, -1.3, 1.3, 3.9):
        parts.append(mk.box("Post", (0.2, 0.2, 2.9), (x, 0, 1.45), mat=paint, bevel=0.03))
        parts.append(mk.box("Foot", (0.34, 0.34, 0.12), (x, 0, 0.06), mat=paint))
    x = -3.6
    while x < 3.7:
        if all(abs(x - p) > 0.3 for p in (-3.9, -1.3, 1.3, 3.9)):
            parts.append(mk.cylinder("Bar", 0.045, 2.6, (x, 0, 1.55), mat=paint, verts=6))
        x += 0.38
    return parts, []


@prop("Bollard", pivot="bottom", material="Metal", collide=True, texture=256, set="Tokyo")
def bollard():
    """A steel bollard: a domed top, a band of reflective yellow and a chain eye."""
    steel = pk.metal("BO_Steel", (60, 62, 66), (90, 92, 98))
    yellow = pk.plastic("BO_Yellow", (236, 196, 40))
    parts = [
        mk.cylinder("Body", 0.26, 2.6, (0, 0, 1.3), mat=steel, verts=16),
        mk.lathe("Dome", [(0.28, 0), (0.28, 0.06), (0.22, 0.2), (0.1, 0.28), (0.0, 0.3)], (0, 0, 2.6), mat=steel,
                 segments=16),
        mk.cylinder("Band", 0.27, 0.3, (0, 0, 2.2), mat=yellow, verts=16),
        mk.cylinder("Base", 0.34, 0.1, (0, 0, 0.05), mat=steel, verts=16),
        mk.torus("Eye", 0.1, 0.03, (0, -0.3, 1.9), rot=(0, 90, 0), mat=steel, major_segments=12, minor_segments=4),
    ]
    return parts, []


@prop("PostBox", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def post_box():
    """Japan's red post box (the square kind on a pedestal): two slots under their lips, the white
    collection-times panel, the 〒 mark, a rounded roof and a door with its lock at the back."""
    red = pk.paint("PB_Red", (196, 28, 32), rough=0.35, wear=18)
    dark = pk.metal("PB_Dark", (30, 28, 28), (50, 46, 46), rough=0.5)
    white = pk.plastic("PB_White", (238, 236, 230))
    ink = pk.plastic("PB_Ink", (24, 22, 22))
    parts = [
        mk.box("Pedestal", (0.9, 0.9, 1.2), (0, 0, 0.6), mat=dark, bevel=0.05),
        mk.box("Foot", (1.3, 1.3, 0.12), (0, 0, 0.06), mat=dark, bevel=0.03),
        pk.rounded("Body", (1.9, 1.5, 3.3), (0, 0, 2.85), red, r=0.12),
        mk.box("Roof", (2.1, 1.7, 0.3), (0, 0, 4.62), mat=red, bevel=0.14, segments=3),
        mk.box("RoofTop", (1.7, 1.3, 0.18), (0, 0, 4.85), mat=red, bevel=0.08, segments=3),
    ]
    for x in (-0.46, 0.46):
        parts.append(mk.box("Slot", (0.7, 0.08, 0.1), (x, -0.76, 3.95), mat=dark))
        parts.append(mk.box("Lip", (0.8, 0.22, 0.06), (x, -0.84, 4.06), rot=(-20, 0, 0), mat=red, bevel=0.02))
        parts += pk.label("SlotLabel", "手紙" if x < 0 else "大型", 0.14, (x, -0.77, 3.72), white)
    parts.append(mk.box("Panel", (1.3, 0.04, 1.2), (0, -0.77, 2.7), mat=white, bevel=0.02))
    parts += pk.label("Times", "取集時刻", 0.13, (0, -0.8, 3.12), ink)
    for k, t in enumerate(("9:30", "13:00", "17:30")):
        parts += pk.label("Time", t, 0.13, (0, -0.8, 2.86 - k * 0.22), ink)
    parts += pk.label("Mark", "〒", 0.5, (0, -0.78, 1.72), white)
    parts.append(mk.box("Door", (1.5, 0.05, 2.4), (0, 0.77, 2.8), mat=red, bevel=0.03))
    parts.append(mk.cylinder("Lock", 0.1, 0.08, (0.55, 0.8, 3.3), rot=(90, 0, 0), mat=dark, verts=10))
    return parts, []


@prop("RecycleBins", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def recycle_bins():
    """Three steel recycling bins in a frame: cans (blue), bottles (green), PET (orange), each lid
    with its shaped hole and its label."""
    steel = pk.metal("RB_Steel", (160, 162, 164), (196, 198, 200), rough=0.35, metallic=0.4)
    dark = pk.metal("RB_Dark", (40, 40, 44), (60, 60, 64))
    ink = pk.plastic("RB_Ink", (250, 250, 246))
    parts = [mk.box("Plinth", (3.6, 1.4, 0.16), (0, 0, 0.08), mat=dark)]
    for k, (rgb, word, hole) in enumerate((((40, 90, 180), "カン", "round"), ((40, 140, 80), "ビン", "round"),
                                           ((220, 120, 30), "ペット", "slot"))):
        x = -1.15 + k * 1.15
        lid = pk.plastic(f"RB_Lid{k}", rgb)
        parts += [pk.rounded("Bin", (1.05, 1.2, 2.7), (x, 0, 1.5), steel, r=0.06),
                  mk.box("Lid", (1.1, 1.26, 0.22), (x, 0, 2.95), mat=lid, bevel=0.05),
                  mk.box("Band", (1.07, 0.04, 0.5), (x, -0.61, 2.4), mat=lid)]
        if hole == "round":
            parts.append(mk.cylinder("Hole", 0.22, 0.05, (x, -0.1, 3.07), mat=dark, verts=14))
        else:
            parts.append(mk.box("Hole", (0.6, 0.18, 0.05), (x, -0.1, 3.07), mat=dark))
        parts += pk.label("Word", word, 0.2, (x, -0.64, 2.4), ink)
    return parts, []


def bicycle_parts(prefix, x=0.0, y=0.0, colour=(40, 90, 150)):
    """A mamachari (city bike) running along Y at (x, y), front wheel to -Y: step-through frame,
    wire basket, mudguards, chain guard, dynamo lamp, rear rack, saddle, upright bars, a bell and
    its kickstand down."""
    frame = pk.paint(prefix + "Frame", colour, rough=0.35)
    chrome = pk.chrome(prefix + "Chrome")
    tyre = pk.rubber(prefix + "Tyre")
    black = pk.metal(prefix + "Black", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.3)
    r = 1.3
    fy, ry = y - 1.95, y + 1.95  # wheel centres
    parts = []
    parts += pk.spoked_wheel(prefix + "F", x, fy, r, tyre, chrome)
    parts += pk.spoked_wheel(prefix + "R", x, ry, r, tyre, chrome)
    bb = (x, y + 0.35, 1.0)  # bottom bracket
    head_lo, head_hi = (x, fy + 0.55, 2.5), (x, fy + 0.4, 3.1)
    seat_top = (x, ry - 0.9, 3.25)
    parts += [
        mk.tube(prefix + "Down", head_lo, bb, 0.09, mat=frame, verts=8),
        mk.tube(prefix + "Step", (x, fy + 0.5, 2.3), (x, y - 0.1, 1.2), 0.08, mat=frame, verts=8),
        mk.tube(prefix + "Seat", bb, seat_top, 0.085, mat=frame, verts=8),
        mk.tube(prefix + "Stay", bb, (x, ry, r), 0.06, mat=frame, verts=6),
        mk.tube(prefix + "SStay", (x, ry - 0.7, 2.7), (x, ry, r), 0.05, mat=frame, verts=6),
        mk.tube(prefix + "Head", head_lo, head_hi, 0.1, mat=frame, verts=8),
        mk.tube(prefix + "Fork", head_lo, (x, fy, r), 0.06, mat=chrome, verts=6),
        mk.tube(prefix + "Stem", head_hi, (x, fy + 0.55, 3.6), 0.05, mat=chrome, verts=6),
        mk.tube(prefix + "Bars", (x - 1.0, fy + 0.8, 3.7), (x + 1.0, fy + 0.8, 3.7), 0.05, mat=chrome, verts=6),
        mk.tube(prefix + "BarsL", (x - 1.0, fy + 0.8, 3.7), (x - 1.05, fy + 1.3, 3.65), 0.07, mat=black, verts=6),
        mk.tube(prefix + "BarsR", (x + 1.0, fy + 0.8, 3.7), (x + 1.05, fy + 1.3, 3.65), 0.07, mat=black, verts=6),
        mk.cylinder(prefix + "Bell", 0.12, 0.1, (x - 0.6, fy + 0.8, 3.8), mat=chrome, verts=10),
        mk.tube(prefix + "Post", seat_top, (x, ry - 0.95, 3.6), 0.05, mat=chrome, verts=6),
        mk.box(prefix + "Saddle", (0.5, 0.95, 0.22), (x, ry - 0.85, 3.7), mat=black, bevel=0.1, segments=3),
        mk.box(prefix + "ChainGuard", (0.06, 1.6, 0.4), (x + 0.2, y + 1.1, 1.05), mat=black, bevel=0.03),
        mk.cylinder(prefix + "Crank", 0.36, 0.06, (x + 0.24, y + 0.35, 1.0), rot=(0, 90, 0), mat=chrome, verts=14),
        mk.tube(prefix + "Kick", (x + 0.15, ry - 0.1, 1.0), (x + 0.5, ry + 0.5, 0.04), 0.04, mat=chrome, verts=5),
        mk.box(prefix + "Rack", (0.8, 1.3, 0.06), (x, ry, 2.8), mat=chrome),
        mk.tube(prefix + "RackStay", (x, ry + 0.6, 2.8), (x, ry, r), 0.03, mat=chrome, verts=4),
        mk.cylinder(prefix + "Lamp", 0.14, 0.3, (x, fy - 0.25, 2.9), rot=(90, 0, 0), mat=chrome, verts=10),
    ]
    for wy in (fy, ry):  # mudguards over both wheels
        parts.append(mk.torus(prefix + "Guard", r + 0.12, 0.05, (x, wy, r), rot=(0, 90, 0), mat=frame,
                              major_segments=20, minor_segments=4))
    # The front basket: wire sides on a frame.
    bx, by, bz = x, fy - 0.6, 3.25
    parts += pk.frame(prefix + "Basket", 1.3, 0.9, 0.05, 0.05, (bx, by - 0.45, bz), chrome)
    parts += pk.frame(prefix + "BasketB", 1.3, 0.9, 0.05, 0.05, (bx, by + 0.45, bz), chrome)
    parts.append(mk.box(prefix + "BasketFloor", (1.3, 0.95, 0.04), (bx, by, bz - 0.44), mat=chrome))
    for k in range(5):
        dx = -0.55 + k * 0.275
        parts.append(mk.tube(prefix + "Wire", (bx + dx, by - 0.45, bz - 0.44), (bx + dx, by + 0.45, bz - 0.44), 0.012,
                             mat=chrome, verts=3))
    for side in (-0.65, 0.65):
        parts += [mk.tube(prefix + "WireS", (bx + side, by - 0.45, bz - 0.44 + h), (bx + side, by + 0.45, bz - 0.44 + h),
                          0.012, mat=chrome, verts=3) for h in (0.3, 0.6)]
    return parts


@prop("Bicycle", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo")
def bicycle():
    return bicycle_parts("BI_"), []


@prop("BikeRack", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def bike_rack():
    """A floor rack of four slots, a bike in each (colours differ): the rail, its wheel clamps and
    the numbered plates."""
    steel = galvanised("BR_Steel")
    ink = pk.plastic("BR_Ink", (240, 240, 236))
    parts = [mk.box("Rail", (8.4, 0.3, 0.2), (0, -1.9, 0.1), mat=steel), mk.box("RailB", (8.4, 0.3, 0.2), (0, 1.9, 0.1),
                                                                               mat=steel)]
    for k, colour in enumerate(((180, 40, 50), (40, 90, 150), (230, 230, 226), (60, 60, 64))):
        x = -3.15 + k * 2.1
        parts += bicycle_parts(f"BR{k}_", x, 0.0, colour)
        parts += [mk.box("Clamp", (0.16, 0.9, 1.2), (x + sx * 0.18, -1.95, 0.6), mat=steel, bevel=0.03) for sx in (-1, 1)]
        parts.append(mk.box("Num", (0.5, 0.05, 0.3), (x, -2.4, 0.45), mat=pk.plastic("BR_Plate", (30, 80, 160))))
        parts += pk.label("NumT", str(k + 1), 0.2, (x, -2.43, 0.45), ink)
    return parts, []


@prop("Scooter", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Tokyo")
def scooter():
    """A 50cc scooter parked on its stand, front wheel to -Y: body panels, the seat, bars with
    mirrors, a front basket, the rear box and its number plate."""
    body = pk.plastic("SC_Body", (220, 222, 218))
    trim = pk.plastic("SC_Trim", (40, 42, 46))
    tyre = pk.rubber("SC_Tyre")
    chrome = pk.chrome("SC_Chrome")
    seat = mk.noisy("SC_Seat", srgb(24, 22, 22), srgb(40, 36, 36), scale=40, roughness=0.7)
    parts = []
    for y in (-1.6, 1.55):
        parts += pk.wheel("SCW", 0.0, y, 0.62, 0.35, tyre, chrome, spokes=5)
    parts += [
        pk.rounded("Floor", (1.0, 1.5, 0.25), (0, -0.1, 0.7), trim, r=0.06),
        pk.rounded("Rear", (1.1, 1.9, 1.1), (0, 1.25, 1.4), body, r=0.3),
        pk.rounded("Seat", (0.9, 1.6, 0.3), (0, 1.1, 2.1), seat, r=0.12),
        pk.rounded("Front", (1.0, 0.5, 2.0), (0, -1.05, 1.6), body, r=0.2),
        mk.tube("Fork", (0, -1.3, 2.3), (0, -1.6, 0.62), 0.07, mat=chrome, verts=6),
        mk.tube("Stem", (0, -1.2, 2.3), (0, -1.15, 2.9), 0.08, mat=trim, verts=6),
        mk.tube("Bars", (-0.8, -1.15, 2.95), (0.8, -1.15, 2.95), 0.06, mat=trim, verts=6),
        pk.rounded("Headlamp", (0.5, 0.3, 0.4), (0, -1.35, 2.85), body, r=0.1),
        mk.cylinder("Lens", 0.15, 0.05, (0, -1.51, 2.85), rot=(90, 0, 0), mat=chrome, verts=10),
        mk.box("Basket", (1.0, 0.7, 0.6), (0, -1.95, 2.45), mat=chrome, bevel=0.04),
        pk.rounded("Box", (1.0, 0.9, 0.8), (0, 2.3, 2.6), trim, r=0.1),
        mk.box("Plate", (0.6, 0.04, 0.35), (0, 2.37, 1.5), mat=pk.plastic("SC_Plate", (236, 236, 232))),
        mk.tube("Stand", (0, 0.8, 0.5), (0.2, 1.0, 0.02), 0.05, mat=chrome, verts=5),
    ]
    for sx in (-1, 1):
        parts.append(mk.tube("MirrorArm", (sx * 0.6, -1.15, 2.95), (sx * 0.75, -1.1, 3.5), 0.025, mat=chrome, verts=4))
        parts.append(mk.cylinder("Mirror", 0.16, 0.04, (sx * 0.78, -1.1, 3.55), rot=(90, 0, 0), mat=chrome, verts=10))
    parts += pk.label("PlateT", "影ヶ丘 あ 12", 0.08, (0, 2.41, 1.5), pk.plastic("SC_PlateInk", (30, 90, 60)),
                      rot=(90, 0, 180))
    return parts, []


@prop("Planter", pivot="bottom", material="Concrete", collide=True, texture=1024, set="Tokyo")
def planter():
    """A long precast planter with a chamfered rim, full of clipped shrubs and a few flowers."""
    concrete = mk.noisy("PL_Concrete", srgb(132, 128, 120), srgb(168, 164, 156), scale=9, roughness=0.85)
    soil = mk.noisy("PL_Soil", srgb(40, 30, 22), srgb(66, 50, 36), scale=20, roughness=0.95)
    leaf = mk.noisy("PL_Leaf", srgb(34, 64, 30), srgb(70, 110, 52), scale=24, roughness=0.8)
    petal = mk.flat("PL_Flower", srgb(230, 150, 190), 0.6)
    parts = [pk.rounded("Box", (6.4, 1.9, 1.7), (0, 0, 0.85), concrete, r=0.08),
             mk.box("Rim", (6.6, 2.1, 0.18), (0, 0, 1.75), mat=concrete, bevel=0.05),
             mk.box("Soil", (6.1, 1.6, 0.1), (0, 0, 1.7), mat=soil)]
    k = 0
    for i in range(7):
        x = -2.7 + i * 0.9
        for j, y in enumerate((-0.35, 0.35)):
            s = 0.62 + 0.12 * math.sin(k * 1.7)
            parts.append(mk.sphere("Shrub", s, (x + 0.2 * j, y, 1.9 + s * 0.5), scale=(1, 1, 0.8), mat=leaf,
                                   segments=10, rings=6))
            k += 1
    for i in range(9):
        parts.append(mk.sphere("Flower", 0.1, (-2.8 + i * 0.7, -0.75 + 0.2 * (i % 2), 2.35 + 0.1 * (i % 3)),
                               mat=petal, segments=6, rings=4))
    return parts, []


DRINKS = [((200, 30, 40), (240, 240, 236)), ((40, 90, 190), (240, 240, 236)), ((250, 200, 40), (60, 40, 20)),
          ((40, 150, 80), (240, 240, 236)), ((236, 236, 232), (40, 90, 190)), ((120, 60, 30), (230, 200, 150)),
          ((30, 30, 34), (220, 180, 60)), ((230, 120, 40), (255, 255, 255))]


def vending(prefix, body_rgb, trim_rgb, brand):
    """A drinks vending machine: three shelves of sample cans and bottles in a lit window with
    price tags and a lit button under each, the coin, note and card panel, the pick-up flap, a
    brand header; plain panels and a vent at the back."""
    body = pk.paint(prefix + "Body", body_rgb, rough=0.35, wear=10)
    trim = pk.paint(prefix + "Trim", trim_rgb, rough=0.35, wear=8)
    dark = pk.metal(prefix + "Dark", (22, 22, 26), (38, 38, 42), rough=0.5, metallic=0.3)
    chrome = pk.chrome(prefix + "Chrome")
    white = pk.plastic(prefix + "White", (244, 244, 240))
    ink = pk.plastic(prefix + "Ink", (24, 24, 28))
    w, d, h = 3.6, 2.6, 6.4
    front = -d / 2
    parts = [
        pk.rounded("Body", (w, d, h), (0, 0, h / 2 + 0.15), body, r=0.08),
        mk.box("Plinth", (w - 0.2, d - 0.2, 0.15), (0, 0, 0.075), mat=dark),
        mk.box("Header", (w + 0.04, 0.1, 0.55), (0, front - 0.03, h - 0.2), mat=trim, bevel=0.03),
        # The window's frame; the glowing back panel is the glow part, the samples stand before it.
        mk.box("WindowTop", (w - 0.3, 0.12, 0.12), (0, front - 0.02, 5.72), mat=dark),
        mk.box("WindowBottom", (w - 0.3, 0.12, 0.12), (0, front - 0.02, 2.88), mat=dark),
        # The payment panel on the right, the flap below.
        mk.box("PayPanel", (0.9, 0.08, 1.2), (1.2, front - 0.03, 2.1), mat=dark, bevel=0.02),
        mk.box("CoinSlot", (0.1, 0.05, 0.35), (1.0, front - 0.08, 2.5), mat=chrome),
        mk.box("NoteSlot", (0.6, 0.05, 0.08), (1.25, front - 0.08, 2.15), mat=chrome),
        mk.box("CardReader", (0.5, 0.06, 0.35), (1.25, front - 0.08, 1.75), mat=pk.plastic(prefix + "IC", (40, 110, 190))),
        mk.box("Return", (0.35, 0.12, 0.25), (1.35, front - 0.06, 1.3), mat=chrome),
        mk.box("FlapFrame", (2.2, 0.12, 0.9), (-0.45, front - 0.02, 0.9), mat=dark, bevel=0.03),
        mk.box("Flap", (2.0, 0.08, 0.7), (-0.45, front - 0.1, 0.92), rot=(-6, 0, 0), mat=pk.dark_glass(prefix + "Flap")),
        mk.box("VentBack", (2.6, 0.06, 0.8), (0, d / 2 + 0.02, 0.8), mat=dark),
        mk.box("PlateBack", (0.9, 0.04, 0.5), (1.1, d / 2 + 0.03, 4.8), mat=white),
    ]
    parts += pk.label("Brand", brand, 0.34, (0, front - 0.09, h - 0.2), white)
    parts += pk.label("Cold", "つめた〜い", 0.14, (-0.9, front - 0.03, 2.72), pk.plastic(prefix + "Blue", (40, 110, 220)))
    parts += pk.label("Hot", "あったか〜い", 0.14, (0.6, front - 0.03, 2.72), pk.plastic(prefix + "Red", (210, 40, 40)))
    k = 0
    for row, z in enumerate((5.0, 4.1, 3.2)):
        parts.append(mk.box("Shelf", (w - 0.4, 0.5, 0.06), (0, front + 0.3, z - 0.05), mat=white))
        for col in range(8):
            x = -1.47 + col * 0.42
            colour, cap = DRINKS[(k * 3 + row) % len(DRINKS)]
            mat = pk.plastic(f"{prefix}Drink{(k * 3 + row) % len(DRINKS)}", colour)
            capmat = pk.plastic(f"{prefix}Cap{(k * 3 + row) % len(DRINKS)}", cap)
            if (col + row) % 3 == 0:
                parts += pk.bottle("Bottle", x, front + 0.28, z, mat, capmat, r=0.15, h=0.72)
            else:
                parts += pk.can("Can", x, front + 0.28, z, mat, capmat, r=0.15, h=0.5)
            parts.append(mk.box("Price", (0.34, 0.04, 0.1), (x, front + 0.05, z - 0.13), mat=white))
            k += 1
    glows = [mk.box("Backlight", (w - 0.4, 0.05, 2.7), (0, front + 0.62, 4.3), mat=pk.glow(prefix + "Back", (236, 244, 255), 3))]
    for row, z in enumerate((5.0, 4.1, 3.2)):
        for col in range(8):
            x = -1.47 + col * 0.42
            glows.append(mk.box("Button", (0.22, 0.05, 0.08), (x, front + 0.02, z - 0.25),
                                mat=pk.glow(prefix + "Btn", (120, 230, 255), 3)))
    return parts, glows


VENDING_LIGHTS = [dict(at=(0, -2.2, 4.3), kind="point", color=(214, 232, 255), range=10, brightness=0.8)]


@prop("VendingBlue", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo",
      lights=VENDING_LIGHTS)
def vending_blue():
    return vending("VB_", (30, 70, 150), (220, 40, 40), "SUIGEN")


@prop("VendingWhite", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo",
      lights=VENDING_LIGHTS)
def vending_white():
    return vending("VW_", (226, 226, 222), (200, 30, 40), "KAGE COLA")


# Barriers ---------------------------------------------------------------------------------------------


@prop("Barricade", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def barricade():
    """A road-works barricade: two striped boards on steel A-frame legs with rubber feet, a
    flashing lamp on top (lit)."""
    steel = pk.metal("BA_Steel", (70, 72, 76), (100, 102, 108))
    stripes = mk.banded("BA_Stripe", srgb(240, 196, 30), srgb(24, 24, 26), frequency=10, axis="X", roughness=0.5)
    rubber = pk.rubber("BA_Feet")
    parts = [pk.rounded("Board1", (4.2, 0.1, 0.6), (0, 0, 2.7), stripes, r=0.04),
             pk.rounded("Board2", (4.2, 0.1, 0.6), (0, 0, 1.7), stripes, r=0.04)]
    for x in (-1.9, 1.9):
        parts += [mk.tube("Leg", (x, 0, 3.1), (x, -0.9, 0.05), 0.06, mat=steel, verts=6),
                  mk.tube("Leg", (x, 0, 3.1), (x, 0.9, 0.05), 0.06, mat=steel, verts=6),
                  mk.box("Foot", (0.3, 0.4, 0.12), (x, -0.9, 0.06), mat=rubber),
                  mk.box("Foot", (0.3, 0.4, 0.12), (x, 0.9, 0.06), mat=rubber),
                  mk.tube("Cross", (x, -0.6, 1.0), (x, 0.6, 1.0), 0.04, mat=steel, verts=5)]
    parts.append(mk.box("LampBase", (0.3, 0.3, 0.2), (1.6, 0, 3.1), mat=steel))
    glows = [mk.cylinder("Lamp", 0.2, 0.3, (1.6, 0, 3.35), mat=pk.glow("BA_Glow", (255, 140, 30), 4), verts=12)]
    return parts, glows


@prop("TrafficCone", pivot="bottom", material="Plastic", collide=False, texture=512, set="Tokyo")
def traffic_cone():
    """A road cone on its square base, with two reflective white bands."""
    orange = pk.plastic("TC_Orange", (236, 90, 24))
    white = pk.plastic("TC_White", (244, 244, 240))
    base = pk.plastic("TC_Base", (30, 30, 32))
    parts = [mk.box("Base", (1.2, 1.2, 0.14), (0, 0, 0.07), mat=base, bevel=0.1),
             mk.lathe("Cone", [(0.5, 0.14), (0.44, 0.5), (0.3, 1.3), (0.12, 2.1), (0.0, 2.15)], mat=orange, segments=18)]
    for z0, z1 in ((0.75, 1.0), (1.35, 1.55)):
        r0 = 0.5 - (z0 - 0.14) * 0.19
        r1 = 0.5 - (z1 - 0.14) * 0.19
        parts.append(mk.lathe("Band", [(r0 + 0.015, z0), (r1 + 0.015, z1)], mat=white, segments=18))
    return parts, []


@prop("SiteFence", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def site_fence():
    """A panel of the tall white hoarding that closes a street, 8 wide and 10 tall: ribbed steel
    sheet on a pipe frame braced behind, with a red band and the 立入禁止 KEEP OUT notice; panels
    meet end to end."""
    sheet = mk.banded("SF_Sheet", srgb(214, 214, 208), srgb(236, 236, 230), frequency=26, axis="X", roughness=0.6)
    pipe = galvanised("SF_Pipe")
    red = pk.plastic("SF_Red", (196, 36, 40))
    ink = pk.plastic("SF_Ink", (30, 30, 34))
    white = pk.plastic("SF_White", (244, 244, 240))
    parts = [mk.box("Sheet", (8.0, 0.12, 9.6), (0, 0, 5.0), mat=sheet),
             mk.box("Cap", (8.0, 0.3, 0.2), (0, 0, 9.9), mat=pipe),
             mk.box("Band", (8.0, 0.02, 0.5), (0, -0.07, 8.9), mat=red)]
    for x in (-3.9, 3.9):
        parts.append(mk.cylinder("Post", 0.14, 10.0, (x, 0.25, 5.0), mat=pipe, verts=10))
        parts.append(mk.tube("Brace", (x, 0.25, 7.5), (x, 2.3, 0.1), 0.1, mat=pipe, verts=8))
        parts.append(mk.box("Weight", (0.9, 0.9, 0.6), (x, 2.3, 0.3), mat=mk.noisy("SF_Weight", srgb(90, 88, 84),
                                                                                    srgb(120, 118, 112), scale=8)))
    for z in (2.0, 7.8):
        parts.append(mk.tube("Rail", (-4.0, 0.25, z), (4.0, 0.25, z), 0.1, mat=pipe, verts=8))
    parts.append(mk.box("Notice", (3.2, 0.03, 2.2), (0, -0.08, 5.2), mat=white))
    parts.append(mk.box("NoticeBar", (3.2, 0.035, 0.5), (0, -0.09, 6.05), mat=red))
    parts += pk.label("Ban", "立入禁止", 0.55, (0, -0.1, 5.25), ink)
    parts += pk.label("Keep", "KEEP OUT", 0.3, (0, -0.1, 4.55), ink)
    parts += pk.label("Works", "工事中", 0.26, (0, -0.1, 6.05), white)
    return parts, []


@prop("PoliceTape", pivot="centre", material="Plastic", collide=False, texture=512, set="Tokyo")
def police_tape():
    """A length of yellow police tape, 8.4 across, printed with the warning in both languages."""
    yellow = pk.plastic("PT_Yellow", (244, 210, 30))
    ink = pk.plastic("PT_Ink", (20, 20, 22))
    parts = [mk.box("Tape", (8.4, 0.03, 0.6), (0, 0, 0), mat=yellow)]
    for k in range(3):
        x = -2.8 + k * 2.8
        parts += pk.label("Words", "立入禁止 KEEP OUT", 0.2, (x, -0.02, 0), ink)
        parts += pk.label("WordsB", "立入禁止 KEEP OUT", 0.2, (x, 0.02, 0), ink, rot=(90, 0, 180))
    return parts, []


@prop("PoliceCar", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo",
      lights=[dict(at=(0, 0, 6.2), kind="point", color=(255, 40, 40), range=14, brightness=1.2)])
def police_car():
    """A patrol car in black and white, front to -Y: its light bar lit red, the 警視庁 lettering on
    the doors, lamps, mirrors, wheels with hub caps."""
    import props_tokyo_transit as tr

    parts, glows = tr.car_body("PC_", length=16.4, width=6.2, height=5.4, lower=(236, 236, 232), upper=(20, 20, 24),
                               split=2.9)
    white = pk.plastic("PC_Letters", (240, 240, 236))
    ink = pk.plastic("PC_Ink", (20, 20, 24))
    parts += [mk.box("BarBase", (4.2, 1.2, 0.2), (0, -0.2, 5.55), mat=pk.metal("PC_Bar", (40, 40, 44), (60, 60, 64)))]
    for sx in (-1, 1):
        parts += pk.label("Door", "警視庁", 0.5, (sx * 3.14, -0.6, 2.4), ink, rot=(90, 0, 90 * sx))
        parts += pk.label("Door2", "POLICE", 0.3, (sx * 3.14, -0.6, 1.8), ink, rot=(90, 0, 90 * sx))
    parts += pk.label("Hood", "POLICE", 0.4, (0, -6.6, 3.2), white, rot=(60, 0, 0))
    glows += [mk.box("BarRed", (1.8, 1.0, 0.45), (-1.0, -0.2, 5.85), mat=pk.glow("PC_Red", (255, 30, 30), 5)),
              mk.box("BarRed", (1.8, 1.0, 0.45), (1.0, -0.2, 5.85), mat=pk.glow("PC_Red", (255, 30, 30), 5))]
    return parts, glows


@prop("Crow", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Tokyo")
def crow():
    """A crow perched with its wings folded, beak to -Y: a glossy blue-black body and head, a heavy
    beak, a wedge tail, thin legs and feet. A little bigger than life, so it reads from the street."""
    feather = mk.noisy("CR_Feather", srgb(8, 8, 12), srgb(34, 38, 52), scale=34, roughness=0.32)
    wing = mk.noisy("CR_Wing", srgb(6, 6, 10), srgb(26, 28, 40), scale=26, roughness=0.3)
    beak = pk.plastic("CR_Beak", (46, 44, 46), rough=0.3)
    eye = pk.plastic("CR_Eye", (170, 172, 180), rough=0.2)
    parts = [
        mk.sphere("Body", 1.0, (0, 0.12, 1.0), scale=(0.4, 0.82, 0.46), mat=feather, segments=18, rings=12),
        mk.sphere("Chest", 1.0, (0, -0.4, 1.12), scale=(0.34, 0.4, 0.4), mat=feather, segments=14, rings=10),
        mk.sphere("Head", 0.3, (0, -0.72, 1.5), mat=feather, segments=14, rings=10),
        mk.cylinder("Beak", 0.14, 0.58, (0, -1.08, 1.46), rot=(90, 0, 0), radius2=0.02, mat=beak, verts=10),
        mk.box("Tail", (0.36, 1.0, 0.09), (0, 0.98, 0.92), rot=(-18, 0, 0), mat=wing, bevel=0.03),
        mk.sphere("WingL", 1.0, (-0.38, 0.22, 1.04), scale=(0.1, 0.78, 0.36), mat=wing, segments=12, rings=8),
        mk.sphere("WingR", 1.0, (0.38, 0.22, 1.04), scale=(0.1, 0.78, 0.36), mat=wing, segments=12, rings=8),
    ]
    for sx in (-1, 1):
        parts += [
            mk.cylinder("Leg", 0.045, 0.62, (sx * 0.15, -0.02, 0.31), mat=beak, verts=6),
            mk.box("Foot", (0.1, 0.34, 0.05), (sx * 0.15, -0.14, 0.03), mat=beak),
            mk.sphere("Eye", 0.055, (sx * 0.2, -0.88, 1.56), mat=eye, segments=8, rings=6),
        ]
    return parts, []


import props_tokyo_shops  # noqa: E402,F401
import props_tokyo_transit  # noqa: E402,F401
import props_tokyo_trees  # noqa: E402,F401
import props_tokyo_yokocho  # noqa: E402,F401
