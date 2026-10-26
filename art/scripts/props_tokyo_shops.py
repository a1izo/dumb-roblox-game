"""Tokyo's shop and interior props (set "Tokyo"): konbini shelves, the drinks fridge, the till
counter, bar stools, the ramen counter and its meal-ticket machine, the game centre's claw
machine and arcade cabinet, the laundromat's washer and dryers, the department store's display
case, clothes rack, mannequin, cosmetics counter and fitting room.

Built to the semi-real standard (propkit). They face -Y (a customer's side) and stand on z = 0."""

import math
import random

from mathutils import Matrix

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop

GOODS = [(200, 40, 40), (240, 200, 60), (40, 110, 190), (240, 240, 236), (60, 150, 80), (230, 120, 40),
         (150, 60, 150), (40, 40, 44)]


def _goods(prefix, rng, x0, x1, y, z, depth, h_max, parts):
    """A shelf's worth of packets, boxes and bottles between x0 and x1, fronts at y."""
    x = x0
    k = 0
    while x < x1 - 0.3:
        w = rng.uniform(0.35, 0.8)
        if x + w > x1:
            break
        colour = GOODS[rng.randrange(len(GOODS))]
        mat = pk.plastic(f"{prefix}Goods{GOODS.index(colour)}", colour)
        kind = rng.random()
        if kind < 0.25:
            parts += pk.bottle(prefix + "Bottle", x + w / 2, y + depth / 2, z, mat,
                               pk.plastic(prefix + "Cap", (240, 240, 236)), r=min(0.2, w / 2), h=min(h_max, 1.0))
        else:
            h = rng.uniform(0.5, h_max)
            parts.append(mk.box(prefix + "Pack", (w - 0.06, depth * rng.uniform(0.6, 0.95), h), (x + w / 2, y + depth / 2, z + h / 2),
                                mat=mat, bevel=0.02))
        x += w
        k += 1
    return parts


@prop("StoreShelf", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def store_shelf():
    """A double-sided konbini gondola 8 long: four shelves each side, full of goods, price rails
    on the shelf fronts, an end cap."""
    steel = pk.paint("SS_Steel", (220, 222, 224), rough=0.35, wear=8)
    rail = pk.plastic("SS_Rail", (250, 220, 60))
    rng = random.Random(3)
    parts = [mk.box("Spine", (8.0, 0.2, 5.6), (0, 0, 2.95), mat=steel),
             mk.box("Base", (8.0, 3.0, 0.5), (0, 0, 0.25), mat=steel, bevel=0.03),
             mk.box("Top", (8.0, 0.4, 0.2), (0, 0, 5.75), mat=steel)]
    for sx in (-1, 1):
        parts.append(mk.box("End", (0.12, 3.0, 5.8), (sx * 4.0, 0, 2.9), mat=steel, bevel=0.02))
    for side in (-1, 1):
        for z in (0.5, 1.8, 3.1, 4.4):
            y = side * 0.85
            parts.append(mk.box("Shelf", (7.8, 1.3, 0.08), (0, y, z), mat=steel))
            parts.append(mk.box("Rail", (7.8, 0.04, 0.18), (0, side * 1.52, z + 0.02), mat=rail))
            _goods("SS_", rng, -3.85, 3.85, side * 1.45 - (0.9 if side > 0 else 0), z + 0.04, 0.9, 1.1, parts)
    return parts, []


@prop("DrinkFridge", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo",
      lights=[dict(at=(0, -2.2, 4.0), kind="spot", face="Front", angle=160, color=(214, 232, 255), range=10,
                   brightness=0.7)])
def drink_fridge():
    """A konbini's walk-in fridge front, 8 wide: three glass doors in steel frames with long
    handles, five lit shelves of bottles and cans behind them, a header with the shop's colours."""
    steel = pk.metal("DF_Steel", (150, 154, 160), (190, 194, 200), rough=0.3, metallic=0.6)
    dark = pk.metal("DF_Dark", (30, 32, 36), (46, 48, 52))
    white = pk.plastic("DF_White", (238, 240, 240))
    rng = random.Random(8)
    parts = [mk.box("Back", (8.0, 0.2, 6.6), (0, 1.2, 3.3), mat=white),
             mk.box("Header", (8.0, 2.8, 0.5), (0, 0, 6.75), mat=pk.plastic("DF_Header", (40, 120, 70))),
             mk.box("Kick", (8.0, 0.3, 0.4), (0, -1.25, 0.2), mat=dark)]
    for x in (-4.0, -1.33, 1.33, 4.0):
        parts.append(mk.box("Mullion", (0.18, 0.3, 6.2), (x, -1.25, 3.4), mat=steel))
    for z in (0.45, 6.4):
        parts.append(mk.box("Rail", (8.0, 0.28, 0.16), (0, -1.25, z), mat=steel))
    for x in (-2.66, 0.0, 2.66):
        parts.append(mk.box("Stile", (0.14, 0.06, 5.84), (x + 1.05, -1.37, 3.42), mat=steel))
        parts += pk.handle("Handle", x + 1.05, -1.4, 3.5, 2.4, steel, stand=0.14)
    for z in (0.7, 1.85, 3.0, 4.15, 5.3):
        parts.append(mk.box("Shelf", (7.8, 2.0, 0.06), (0, 0.1, z), mat=white))
        x = -3.8
        while x < 3.6:
            colour = GOODS[rng.randrange(len(GOODS))]
            mat = pk.plastic(f"DF_Drink{GOODS.index(colour)}", colour)
            cap = pk.plastic("DF_Cap", (240, 240, 236))
            if rng.random() < 0.6:
                parts += pk.bottle("Bottle", x + 0.2, -0.6, z + 0.03, mat, cap, r=0.19, h=0.95)
            else:
                parts += pk.can("Can", x + 0.2, -0.6, z + 0.03, mat, cap, r=0.17, h=0.55)
            x += 0.42
    glows = [mk.box("Light", (7.6, 0.05, 0.08), (0, -1.0, 6.3), mat=pk.glow("DF_Light", (230, 240, 255), 4)),
             mk.box("BackGlow", (7.6, 0.05, 5.4), (0, 1.08, 3.3), mat=pk.glow("DF_BackGlow", (200, 214, 230), 1.2))]
    return parts, glows


@prop("ShopCounter", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def shop_counter():
    """A konbini till counter 8 long, the customer's side at -Y: a laminate front in panels with the shop's two
    stripes, a stone-look top; two registers, each with its keys, its receipt printer and a scanner, the customer's
    screen on its arm, a card reader; the hot-snack warmer lit at one end, its two trays of fried chicken and skewers
    behind the open front; a donation box with its slot; a small rack of sweets on the customer's side."""
    body = pk.plastic("SC_Body", (230, 230, 226))
    top = mk.noisy("SC_Top", srgb(170, 166, 160), srgb(200, 196, 190), scale=12, roughness=0.3)
    stripe = pk.plastic("SC_Stripe", (40, 120, 70))
    stripe2 = pk.plastic("SC_Stripe2", (236, 140, 40))
    dark = pk.metal("SC_Dark", (30, 30, 34), (46, 46, 50))
    steel = pk.metal("SC_Steel", (150, 154, 160), (190, 194, 200))
    white = pk.plastic("SC_White", (240, 240, 236))
    fried = mk.noisy("SC_Fried", srgb(160, 96, 40), srgb(206, 146, 70), scale=30, roughness=0.6)
    parts = [pk.rounded("Body", (8.0, 2.4, 3.3), (0, 0, 1.65), body, r=0.05),
             mk.box("Top", (8.2, 2.6, 0.12), (0, 0, 3.36), mat=top, bevel=0.03),
             mk.box("Stripe", (8.0, 0.04, 0.3), (0, -1.22, 2.7), mat=stripe),
             mk.box("Stripe2", (8.0, 0.04, 0.1), (0, -1.22, 2.45), mat=stripe2),
             mk.box("Kick", (7.96, 0.3, 0.3), (0, -1.0, 0.15), mat=dark)]
    for x in (-2.7, 0.0, 2.7):  # (the front's panel seams)
        parts.append(mk.box("Seam", (0.04, 0.03, 2.0), (x, -1.215, 1.3), mat=dark))
    for x in (-2.4, 1.2):
        parts += [pk.rounded("Register", (1.4, 1.2, 0.6), (x, 0.4, 3.72), dark, r=0.06),
                  mk.box("Drawer", (1.2, 1.0, 0.25), (x, 0.4, 3.55), mat=dark),
                  mk.box("Keys", (0.8, 0.5, 0.08), (x - 0.15, 0.15, 4.04), rot=(14, 0, 0), mat=steel),
                  pk.rounded("Printer", (0.45, 0.5, 0.35), (x + 0.5, 0.55, 4.2), white, r=0.05),
                  mk.box("Receipt", (0.3, 0.02, 0.35), (x + 0.5, 0.31, 4.45), rot=(-20, 0, 0), mat=white),
                  pk.rounded("Scanner", (0.5, 0.4, 0.22), (x - 0.75, -0.55, 3.53), dark, r=0.05),
                  mk.box("CustScreen", (0.8, 0.06, 0.55), (x, -0.4, 4.3), rot=(-10, 0, 0), mat=dark),
                  mk.cylinder("ScreenArm", 0.05, 0.75, (x, -0.35, 3.77), mat=dark, verts=6),
                  mk.box("Reader", (0.35, 0.5, 0.15), (x + 0.9, -0.7, 3.5), mat=dark, bevel=0.03)]
    # The hot-snack warmer: a steel cabinet open at the front, two lit trays of fried chicken and skewers.
    wx = 3.0
    parts += [mk.box("WarmerBack", (2.0, 0.08, 1.6), (wx, 0.86, 4.2), mat=steel),
              mk.box("WarmerTop", (2.08, 1.48, 0.1), (wx, 0.2, 5.02), mat=steel, bevel=0.02),
              mk.box("WarmerBase", (2.08, 1.48, 0.1), (wx, 0.2, 3.47), mat=steel)]
    for sx in (-1, 1):
        parts.append(mk.box("WarmerSide", (0.06, 1.44, 1.6), (wx + sx * 0.99, 0.2, 4.2), mat=steel))
    rng = random.Random(21)
    for tz in (3.62, 4.32):
        parts.append(mk.box("Tray", (1.8, 1.0, 0.06), (wx, 0.25, tz), mat=steel))
        for k in range(6):
            fx = wx - 0.7 + k * 0.28 + rng.uniform(-0.04, 0.04)
            if tz < 4:
                piece = mk.sphere("Chicken", 0.14, (fx, 0.1 + rng.uniform(-0.1, 0.1), tz + 0.1),
                                  scale=(1.0, 0.8, 0.65), mat=fried, segments=8, rings=6)
                mk.displace_noise(piece, strength=0.025, scale=0.2, name="SCChicken")
                parts.append(piece)
            else:
                parts.append(mk.tube("Skewer", (fx, -0.2, tz + 0.06), (fx, 0.6, tz + 0.06), 0.012, mat=white, verts=4))
                for m in range(3):
                    parts.append(mk.box("Bite", (0.12, 0.14, 0.1), (fx, -0.05 + m * 0.18, tz + 0.1), mat=fried,
                                        bevel=0.03))
    # The donation box with its slot; the sweets on the customer's side.
    parts += [mk.box("Donation", (0.5, 0.4, 0.6), (-0.6, -0.9, 3.72), mat=pk.plastic("SC_Box", (200, 40, 40))),
              mk.box("Slot", (0.3, 0.06, 0.03), (-0.6, -0.9, 4.03), mat=dark),
              mk.box("SweetRack", (1.6, 0.5, 0.08), (-1.0, -1.42, 2.95), mat=steel),
              mk.box("SweetLip", (1.6, 0.04, 0.12), (-1.0, -1.66, 3.02), mat=steel)]
    sweets = [pk.plastic(f"SC_Sweet{k}", c) for k, c in enumerate(((236, 60, 80), (250, 210, 60), (90, 160, 230),
                                                                       (120, 200, 110), (240, 140, 200)))]
    for k in range(8):
        parts.append(mk.box("Sweet", (0.16, 0.3, 0.24), (-1.7 + k * 0.2, -1.42, 3.11), rot=(-8, 0, 0),
                            mat=sweets[k % len(sweets)]))
    glows = [mk.box("WarmerLamp", (1.8, 0.3, 0.04), (wx, 0.2, 4.95), mat=pk.glow("SC_Snack", (255, 200, 120), 2.5))]
    for x in (-2.4, 1.2):
        glows.append(mk.box("CustLit", (0.7, 0.03, 0.45), (x, -0.44, 4.3), rot=(-10, 0, 0),
                            mat=pk.glow("SC_Screen", (120, 200, 255), 2.5)))
        glows.append(mk.box("ScanLine", (0.32, 0.03, 0.04), (x - 0.75, -0.77, 3.56), mat=pk.glow("SC_Scan", (255, 40, 40), 3)))
    return parts, glows


@prop("BarStool", pivot="bottom", material="Metal", collide=False, texture=512, set="Tokyo")
def bar_stool():
    """A counter stool: a round padded seat on a chrome column, a foot ring and a heavy base."""
    chrome = pk.chrome("BS_Chrome")
    seat = mk.noisy("BS_Seat", srgb(90, 20, 22), srgb(130, 34, 36), scale=30, roughness=0.6)
    parts = [mk.cylinder("Base", 0.6, 0.12, (0, 0, 0.06), mat=chrome, verts=20, bevel=0.03),
             mk.cylinder("Column", 0.08, 2.8, (0, 0, 1.5), mat=chrome, verts=10),
             mk.torus("Ring", 0.45, 0.04, (0, 0, 1.0), mat=chrome, major_segments=20, minor_segments=5),
             mk.lathe("Seat", [(0.0, 0), (0.55, 0.0), (0.62, 0.1), (0.62, 0.26), (0.5, 0.34), (0.0, 0.36)], (0, 0, 2.82),
                      mat=seat, segments=20)]
    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append(mk.tube("Spoke", (0, 0, 1.0), (math.cos(a) * 0.45, math.sin(a) * 0.45, 1.0), 0.025, mat=chrome, verts=4))
    return parts, []


@prop("RamenCounter", pivot="bottom", material="Wood", collide=True, texture=1024, set="Tokyo")
def ramen_counter():
    """A ramen bar's counter 12 long, the diners' side at -Y: a thick wooden top, a raised ledge on
    the kitchen side with bowls, condiment racks, water jugs and chopstick boxes, a panelled front."""
    wood = mk.wood("RC_Wood", srgb(160, 116, 72), srgb(96, 64, 38))
    dark = mk.wood("RC_Dark", srgb(70, 46, 30), srgb(36, 22, 14))
    bowl = pk.plastic("RC_Bowl", (200, 34, 36))
    white = pk.plastic("RC_White", (236, 234, 228))
    steel = pk.metal("RC_Steel", (150, 154, 160), (190, 194, 200), rough=0.3, metallic=0.6)
    parts = [mk.box("Body", (12.0, 2.2, 3.3), (0, 0.15, 1.65), mat=dark, bevel=0.03),
             mk.box("Top", (12.2, 2.7, 0.2), (0, 0, 3.45), mat=wood, bevel=0.04),
             mk.box("Ledge", (12.0, 0.9, 1.0), (0, 0.9, 4.05), mat=dark),
             mk.box("LedgeTop", (12.2, 1.0, 0.12), (0, 0.9, 4.6), mat=wood)]
    for k in range(7):
        parts.append(mk.box("Panel", (1.5, 0.04, 2.4), (-5.2 + k * 1.73, -0.97, 1.6), mat=wood, bevel=0.02))
    for k in range(6):
        x = -5.0 + k * 2.0
        parts += [mk.lathe("Bowl", [(0.0, 0), (0.28, 0.0), (0.42, 0.18), (0.48, 0.34), (0.0, 0.34)], (x, 0.9, 4.66),
                           mat=bowl, segments=14),
                  mk.box("Chopsticks", (0.4, 0.3, 0.3), (x + 0.6, 0.9, 4.82), mat=wood, bevel=0.02),
                  mk.cylinder("Soy", 0.1, 0.35, (x + 0.95, 0.9, 4.84), mat=white, verts=8)]
    for x in (-3.0, 3.0):
        parts.append(mk.cylinder("Jug", 0.22, 0.7, (x, -0.2, 3.9), mat=steel, verts=12))
    return parts, []


@prop("MealTicketMachine", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def meal_ticket_machine():
    """A ramen shop's meal-ticket machine: a grid of lit dish buttons with pictures and prices, a
    note slot, coin slot and the ticket tray."""
    body = pk.paint("MT_Body", (224, 226, 228), rough=0.3, wear=8)
    dark = pk.metal("MT_Dark", (30, 30, 34), (46, 46, 50))
    chrome = pk.chrome("MT_Chrome")
    parts = [pk.rounded("Body", (3.0, 1.7, 5.8), (0, 0, 2.9), body, r=0.08),
             mk.box("Panel", (2.6, 0.05, 2.6), (0, -0.86, 4.1), mat=dark),
             mk.box("NoteSlot", (0.7, 0.05, 0.1), (-0.5, -0.87, 2.4), mat=chrome),
             mk.box("CoinSlot", (0.1, 0.05, 0.35), (0.7, -0.87, 2.45), mat=chrome),
             mk.box("Tray", (1.2, 0.3, 0.4), (0, -0.8, 1.4), mat=dark, bevel=0.03)]
    ink = pk.plastic("MT_Ink", (30, 24, 20))
    glows = []
    colours = [(255, 200, 120), (255, 160, 100), (255, 236, 180)]
    for r in range(4):
        for c in range(4):
            x, z = -0.93 + c * 0.62, 5.1 - r * 0.62
            glows.append(mk.box("Button", (0.54, 0.05, 0.5), (x, -0.9, z), mat=pk.glow(f"MT_Btn{(r + c) % 3}", colours[(r + c) % 3], 2.5)))
            parts.append(mk.cylinder("Dish", 0.14, 0.03, (x, -0.94, z + 0.06), rot=(90, 0, 0),
                                     mat=pk.plastic("MT_Dish", (200, 120, 60)), verts=10))
    parts += pk.label("Title", "食券", 0.3, (0, -0.88, 5.6), ink)
    return parts, glows


@prop("ClawMachine", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo",
      lights=[dict(at=(0, 0, 5.8), kind="point", color=(255, 120, 200), range=8, brightness=0.8)])
def claw_machine():
    """A crane game: a pink cabinet with a lit glass case on top, the claw hanging on its gantry
    over a pile of plush toys, the prize chute, joystick and button, a lit marquee."""
    body = pk.plastic("CM_Body", (230, 110, 170))
    white = pk.plastic("CM_White", (244, 244, 240))
    chrome = pk.chrome("CM_Chrome")
    dark = pk.metal("CM_Dark", (30, 30, 34), (46, 46, 50))
    rng = random.Random(4)
    parts = [pk.rounded("Base", (3.8, 4.0, 2.8), (0, 0, 1.4), body, r=0.1),
             mk.box("Chute", (1.2, 0.4, 1.0), (1.0, -2.05, 1.3), mat=dark, bevel=0.04),
             mk.box("Panel", (3.76, 0.9, 0.3), (0, -1.9, 2.75), rot=(-15, 0, 0), mat=white),
             mk.cylinder("Stick", 0.05, 0.5, (-0.8, -2.0, 3.1), mat=chrome, verts=8),
             mk.sphere("Knob", 0.14, (-0.8, -2.0, 3.35), mat=pk.plastic("CM_Knob", (230, 40, 40)), segments=10, rings=6),
             mk.cylinder("Push", 0.18, 0.1, (0.2, -2.0, 3.0), mat=pk.plastic("CM_Push", (60, 160, 255)), verts=12),
             pk.rounded("Top", (3.9, 4.1, 0.9), (0, 0, 7.2), body, r=0.12),
             mk.box("GantryX", (3.7, 0.1, 0.1), (0, -0.4, 6.6), mat=chrome),
             mk.box("GantryY", (0.1, 3.9, 0.1), (0.3, 0, 6.6), mat=chrome),
             mk.box("RailF", (3.82, 0.12, 0.12), (0, -1.95, 6.6), mat=chrome),
             mk.box("RailB", (3.82, 0.12, 0.12), (0, 1.95, 6.6), mat=chrome),
             mk.cylinder("Cable", 0.02, 1.4, (0.3, -0.4, 5.9), mat=chrome, verts=4),
             mk.cylinder("ClawHub", 0.15, 0.3, (0.3, -0.4, 5.1), mat=chrome, verts=10)]
    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append(mk.tube("Claw", (0.3, -0.4, 5.0), (0.3 + math.cos(a) * 0.35, -0.4 + math.sin(a) * 0.35, 4.6), 0.03,
                             mat=chrome, verts=4))
    for x in (-1.85, 1.85):
        for y in (-1.95, 1.95):
            parts.append(mk.box("Post", (0.12, 0.12, 4.0), (x, y, 4.775), mat=chrome))
    for k in range(14):
        colour = [(250, 200, 220), (200, 230, 255), (255, 240, 170), (220, 200, 255)][k % 4]
        mat = pk.plastic(f"CM_Toy{k % 4}", colour)
        x, y = rng.uniform(-1.4, 1.4), rng.uniform(-1.3, 1.5)
        rng.uniform(0, 0.3)  # (the height a toy once hung at, still drawn so the others keep their places)
        tz = 3.15  # (every toy down on the case's floor, none hanging over it)
        parts.append(mk.sphere("Toy", 0.45, (x, y, tz), scale=(1, 1, 0.8), mat=mat, segments=10, rings=6))
        parts.append(mk.sphere("Ear", 0.14, (x - 0.25, y, tz + 0.42), mat=mat, segments=6, rings=4))
    glows = [mk.box("Marquee", (3.4, 0.05, 0.6), (0, -2.07, 7.2), mat=pk.glow("CM_Marquee", (255, 150, 210), 3)),
             mk.box("CaseLight", (3.3, 3.5, 0.05), (0, 0, 6.72), mat=pk.glow("CM_Case", (255, 230, 245), 2))]
    return parts, glows


@prop("ArcadeCabinet", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def arcade_cabinet():
    """A Japanese candy cabinet, the kind a game centre lines up: its white shell drawn from one curved side (a
    rounded hood over the screen, the screen tilted back, the control panel jutting out, the base stepping in under
    it), pastel side art set into each flank, the big screen in its black bezel, a lit marquee under the hood, a
    stick and six buttons on the panel, the coin door with its lit slots, a kick plate."""
    shell = pk.plastic("AC_Shell", (236, 236, 240), rough=0.3)
    art = [pk.plastic("AC_ArtPink", (236, 120, 176)), pk.plastic("AC_ArtBlue", (110, 140, 236))]
    dark = pk.metal("AC_Dark", (20, 20, 24), (34, 34, 38))
    chrome = pk.chrome("AC_Chrome")
    # the side profile (y, z), front at -y
    profile = [(1.4, 0.0), (1.4, 5.8), (1.0, 6.2), (0.15, 6.2), (-0.35, 5.95), (-0.45, 5.7), (-0.2, 5.62),
               (-0.78, 3.6), (-1.25, 3.48), (-1.85, 3.28), (-1.85, 3.02), (-1.05, 2.66), (-1.05, 0.0)]
    body = mk.extrude_shape("Shell", profile, 3.0, rot=(90, 0, 90), mat=shell, bevel=0.08)
    parts = [body, mk.box("Kick", (2.9, 0.1, 0.3), (0, -1.08, 0.15), mat=dark)]
    # the side art: the profile drawn in, set into each flank
    inner = [(y * 0.82 + 0.04, z * 0.82 + 0.45) for y, z in profile]
    for sx, mat in ((-1, art[0]), (1, art[1])):
        side = mk.extrude_shape("SideArt", inner, 0.06, rot=(90, 0, 90), mat=mat, bevel=0.02)
        side.location = (sx * 1.52, 0, 0)
        parts.append(side)
    # the screen's bezel on the tilted face, the panel's top with its stick and buttons
    a, b = (-0.78, 3.6), (-0.2, 5.62)
    tilt = math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    out = (-math.cos(math.radians(tilt)), math.sin(math.radians(tilt)))
    parts.append(mk.box("Bezel", (2.7, 0.04, 2.0), (0, mid[0] + out[0] * 0.02, mid[1] + out[1] * 0.02),
                        rot=(-tilt, 0, 0), mat=dark, bevel=0.03))
    panel_z = 3.4
    parts += [mk.cylinder("Stick", 0.045, 0.42, (-0.75, -1.5, panel_z + 0.2), mat=chrome, verts=8),
              mk.sphere("Ball", 0.15, (-0.75, -1.5, panel_z + 0.44), mat=pk.plastic("AC_Ball", (230, 40, 40)),
                        segments=12, rings=8),
              mk.cylinder("StickBase", 0.18, 0.04, (-0.75, -1.5, panel_z + 0.0), mat=dark, verts=12)]
    colours = [(230, 40, 40), (40, 160, 255), (250, 200, 40)]
    for k in range(6):
        parts.append(mk.cylinder("Btn", 0.11, 0.08, (0.05 + (k % 3) * 0.36, -1.62 + (k // 3) * 0.3, panel_z + 0.0),
                                 mat=pk.plastic(f"AC_Btn{k % 3}", colours[k % 3]), verts=12))
    parts += [mk.box("CoinDoor", (1.0, 0.05, 0.9), (0, -1.08, 1.6), mat=dark, bevel=0.02),
              mk.box("Lock", (0.08, 0.04, 0.12), (0.38, -1.11, 1.6), mat=chrome)]
    glows = [mk.box("Screen", (2.4, 0.03, 1.75), (0, mid[0] + out[0] * 0.05, mid[1] + out[1] * 0.05), rot=(-tilt, 0, 0),
                    mat=pk.glow("AC_Screen", (120, 200, 255), 3)),
             mk.box("Marquee", (2.5, 0.04, 0.24), (0, -0.36, 5.82), rot=(-20, 0, 0),
                    mat=pk.glow("AC_Marquee", (255, 220, 120), 3)),
             mk.box("Coin", (0.12, 0.04, 0.22), (-0.2, -1.12, 1.75), mat=pk.glow("AC_Coin", (255, 60, 60), 3)),
             mk.box("Coin", (0.12, 0.04, 0.22), (0.15, -1.12, 1.75), mat=pk.glow("AC_Coin", (255, 60, 60), 3))]
    return parts, glows


@prop("Washer", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def washer():
    """A coin-op front-loading washer: a steel cabinet, the round door with its chrome ring and
    dark window, the coin box and dial on the top panel, the price label."""
    body = pk.paint("WA_Body", (232, 234, 236), rough=0.3, wear=8)
    chrome = pk.chrome("WA_Chrome")
    dark = pk.dark_glass("WA_Window", (30, 40, 50))
    panel = pk.metal("WA_Panel", (40, 42, 46), (60, 62, 66))
    parts = [pk.rounded("Body", (3.2, 3.1, 4.3), (0, 0, 2.15), body, r=0.08),
             mk.box("TopPanel", (3.16, 0.3, 0.9), (0, -1.45, 3.9), mat=panel),
             mk.torus("Ring", 1.0, 0.12, (0, -1.6, 2.0), rot=(90, 0, 0), mat=chrome, major_segments=24, minor_segments=6),
             mk.cylinder("Window", 0.92, 0.1, (0, -1.56, 2.0), rot=(90, 0, 0), mat=dark, verts=24),
             mk.box("Handle", (0.2, 0.2, 0.7), (0.95, -1.75, 2.0), mat=chrome, bevel=0.05),
             mk.box("CoinBox", (0.8, 0.1, 0.5), (0.8, -1.62, 3.9), mat=chrome),
             mk.cylinder("Dial", 0.2, 0.1, (-0.8, -1.62, 3.9), rot=(90, 0, 0), mat=chrome, verts=12),
             mk.box("Kick", (3.0, 0.2, 0.3), (0, -1.47, 0.15), mat=panel)]
    parts += pk.label("Price", "400円", 0.18, (0, -1.62, 3.92), pk.plastic("WA_Ink", (240, 240, 236)))
    glows = [mk.box("Led", (0.4, 0.05, 0.2), (-0.1, -1.62, 3.9), mat=pk.glow("WA_Led", (255, 90, 70), 3))]
    return parts, glows


@prop("DryerStack", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def dryer_stack():
    """Two coin-op dryers stacked, each with its round door, dark window and coin panel."""
    body = pk.paint("DR_Body", (206, 208, 212), rough=0.3, wear=8)
    chrome = pk.chrome("DR_Chrome")
    dark = pk.dark_glass("DR_Window", (40, 36, 30))
    panel = pk.metal("DR_Panel", (40, 42, 46), (60, 62, 66))
    parts = [pk.rounded("Body", (3.2, 3.1, 8.6), (0, 0, 4.3), body, r=0.08)]
    for z in (2.0, 6.0):
        parts += [mk.torus("Ring", 1.0, 0.12, (0, -1.6, z), rot=(90, 0, 0), mat=chrome, major_segments=24, minor_segments=6),
                  mk.cylinder("Window", 0.92, 0.1, (0, -1.56, z), rot=(90, 0, 0), mat=dark, verts=24),
                  mk.box("Panel", (3.2, 0.12, 0.6), (0, -1.58, z + 1.55), mat=panel),
                  mk.box("Coin", (0.6, 0.06, 0.35), (0.9, -1.66, z + 1.55), mat=chrome)]
    glows = [mk.box("Led", (0.5, 0.05, 0.2), (-0.8, -1.66, z + 1.55), mat=pk.glow("DR_Led", (80, 255, 150), 3))
             for z in (2.0, 6.0)]
    return parts, glows


@prop("DisplayCase", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def display_case():
    """A jewellery counter 6 long: a lit glass-topped case of rings and watches on velvet, brass
    edging, a lower cabinet with doors on the staff side."""
    body = pk.plastic("DC_Body", (236, 232, 222))
    brass = pk.metal("DC_Brass", (176, 140, 72), (214, 176, 96), rough=0.3, metallic=0.9)
    velvet = mk.noisy("DC_Velvet", srgb(40, 20, 50), srgb(60, 30, 70), scale=40, roughness=0.9)
    gold = pk.metal("DC_Gold", (200, 160, 70), (240, 200, 110), rough=0.2, metallic=1.0)
    parts = [pk.rounded("Cabinet", (6.0, 2.4, 2.4), (0, 0, 1.2), body, r=0.06),
             mk.box("Velvet", (5.6, 2.0, 0.1), (0, 0, 2.45), mat=velvet)]
    # (the glass top is its brass frame alone: glass bakes solid, and a pane hid the rings and watches under it)
    for x in (-3.0, 3.0):
        for y in (-1.2, 1.2):
            parts.append(mk.box("Edge", (0.1, 0.1, 1.1), (x, y, 2.95), mat=brass))
    for y in (-1.2, 1.2):
        parts.append(mk.box("Rail", (6.0, 0.1, 0.1), (0, y, 3.47), mat=brass))
    for k in range(10):
        x = -2.5 + k * 0.55
        parts.append(mk.torus("Ring", 0.12, 0.03, (x, -0.4, 2.62), rot=(90, 0, 0), mat=gold, major_segments=12,
                              minor_segments=4))
        parts.append(mk.cylinder("Watch", 0.14, 0.05, (x, 0.4, 2.52), mat=gold, verts=12))
    glows = [mk.box("CaseLight", (5.6, 0.2, 0.05), (0, 1.0, 3.4), mat=pk.glow("DC_Light", (255, 244, 230), 3))]
    return parts, glows


@prop("ClothesRack", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def clothes_rack():
    """A chrome clothes rail 6 long on two uprights with wheeled feet, a row of shirts and coats on
    hangers in a few colours."""
    chrome = pk.chrome("CR_Chrome")
    rng = random.Random(9)
    colours = [(40, 50, 80), (180, 170, 150), (120, 30, 40), (220, 220, 214), (60, 70, 60), (30, 30, 34)]
    parts = [mk.tube("Rail", (-3.0, 0, 5.0), (3.0, 0, 5.0), 0.06, mat=chrome, verts=8)]
    for x in (-2.9, 2.9):
        parts += [mk.tube("Upright", (x, 0, 0.3), (x, 0, 5.0), 0.06, mat=chrome, verts=8),
                  mk.tube("Foot", (x, -0.9, 0.3), (x, 0.9, 0.3), 0.05, mat=chrome, verts=6)]
        parts += [mk.sphere("Wheel", 0.15, (x, sy * 0.85, 0.15), mat=pk.rubber("CR_Wheel"), segments=8, rings=5)
                  for sy in (-1, 1)]
    x = -2.6
    while x < 2.6:
        colour = colours[rng.randrange(len(colours))]
        mat = mk.noisy(f"CR_Cloth{colours.index(colour)}", srgb(*[max(0, c - 16) for c in colour]), srgb(*colour),
                       scale=30, roughness=0.9)
        long = rng.random() < 0.35
        h = 3.2 if long else 2.2
        parts += [mk.tube("Hanger", (x, 0, 5.0), (x, 0, 4.7), 0.02, mat=chrome, verts=4),
                  mk.box("Shoulders", (0.12, 1.6, 0.3), (x, 0, 4.55), mat=mat, bevel=0.06),
                  mk.box("Body", (0.1, 1.5, h), (x, 0, 4.45 - h / 2), mat=mat, bevel=0.04)]
        x += rng.uniform(0.25, 0.4)
    return parts, []


def mannequin_head(name, at, size, mat):
    """A shop mannequin's head and neck (2026-10-25, the owner: "i dont like the mannequin head it looks weird redo
    it"): faceless as a display head is, but shaped like a head and not an egg on a stick: one smooth form blended from
    the skull's round, the face's flatter mass, a narrow jaw to a small chin, the ridge of a nose, a soft brow,
    cheekbones (soft sockets for eyes between them and the brow), the ears' faint shells, and a full neck down into the collar.
    `at` is the middle of the head, `size` its height; it faces -Y, turned a touch to one side."""
    from props_lobby import _blob

    elements = [
        ("ellipsoid", (0, 0.06, 0.12), 0.5, (0.8, 1.0, 1.0)),  # the skull
        ("ellipsoid", (0, -0.16, -0.1), 0.37, (0.8, 0.9, 1.15)),  # the face
        ("ellipsoid", (0, -0.25, -0.42), 0.19, (1.05, 0.95, 0.8)),  # the jaw and chin
        ("ellipsoid", (0, -0.4, -0.3), 0.06, (1.6, 0.8, 0.7)),  # the lips' soft swell
        ("capsule", (0, -0.42, 0.1), (0, -0.5, -0.1), 0.055),  # the nose
        ("capsule", (-0.19, -0.37, 0.17), (0.19, -0.37, 0.17), 0.065),  # the brow
        ("ball", (-0.21, -0.31, -0.05), 0.1),  # cheekbones
        ("ball", (0.21, -0.31, -0.05), 0.1),
        ("ellipsoid", (-0.41, 0.03, 0.0), 0.09, (0.5, 0.8, 1.3)),  # the ears
        ("ellipsoid", (0.41, 0.03, 0.0), 0.09, (0.5, 0.8, 1.3)),
        ("capsule", (0, 0.06, -0.3), (0, 0.1, -0.95), 0.19),  # the neck, down into the collar
    ]
    head = _blob(name, elements, 0.045, 0.8, mat)
    turn = Matrix.Rotation(math.radians(-12), 4, "Z") @ Matrix.Rotation(math.radians(4), 4, "X")
    head.data.transform(Matrix.Translation(at) @ turn @ Matrix.Diagonal((size, size, size, 1.0)))
    return head


@prop("Mannequin", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Tokyo")
def mannequin():
    """A dressed display mannequin: a smooth grey figure in a long coat and scarf on a round glass
    base, arms at its sides, its face blank."""
    skin = pk.plastic("MN_Skin", (214, 212, 206), rough=0.22)
    coat = mk.noisy("MN_Coat", srgb(90, 70, 50), srgb(120, 96, 70), scale=24, roughness=0.9)
    scarf = mk.noisy("MN_Scarf", srgb(150, 30, 40), srgb(190, 50, 60), scale=24, roughness=0.9)
    base = pk.dark_glass("MN_Base", (60, 70, 80))
    parts = [mk.cylinder("Base", 0.9, 0.12, (0, 0, 0.06), mat=base, verts=24),
             mk.cylinder("Rod", 0.05, 0.9, (0, 0.2, 0.55), mat=pk.chrome("MN_Rod"), verts=6),
             mk.lathe("Coat", [(0.0, 0.9), (0.72, 0.95), (0.62, 2.6), (0.56, 3.6), (0.7, 4.3), (0.36, 4.7), (0.0, 4.75)],
                      mat=coat, segments=18),
             # (the neck flaring out of the collar into the head's underside, the head sculpted: mannequin_head)
             mannequin_head("Head", (0, -0.03, 5.45), 0.95, skin),
             mk.torus("Scarf", 0.3, 0.12, (0, 0, 4.75), mat=scarf, major_segments=16, minor_segments=6)]
    for sx in (-1, 1):
        parts += [mk.tube("Arm", (sx * 0.72, 0, 4.3), (sx * 0.78, 0.05, 2.5), 0.16, 0.13, mat=coat, verts=10),
                  mk.sphere("Hand", 0.13, (sx * 0.78, 0.05, 2.36), scale=(0.7, 0.9, 1.4), mat=skin, segments=12, rings=8)]
    return parts, []


@prop("CosmeticsCounter", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def cosmetics_counter():
    """A department store's cosmetics counter 6 long, customers at -Y: a white lacquered base with a
    lit glass shelf of bottles and palettes, a brand plinth with its lit logo, testers on a tray,
    two stools' worth of mirror."""
    white = pk.plastic("CO_White", (242, 240, 236))
    gold = pk.metal("CO_Gold", (200, 160, 80), (236, 200, 120), rough=0.25, metallic=0.9)
    black = pk.plastic("CO_Black", (20, 20, 22))
    mirror = pk.metal("CO_Mirror", (170, 176, 184), (210, 214, 220), rough=0.05, metallic=1.0)
    rng = random.Random(12)
    parts = [pk.rounded("Base", (6.0, 2.4, 3.2), (0, 0, 1.6), white, r=0.08),
             mk.box("Top", (6.1, 2.5, 0.1), (0, 0, 3.25), mat=black),
             mk.box("Kick", (5.8, 2.2, 0.25), (0, 0, 0.12), mat=gold),
             mk.box("Plinth", (1.8, 1.4, 2.4), (0, 0.4, 4.5), mat=white, bevel=0.04),
             mk.box("Tray", (3.0, 0.8, 0.06), (-1.4, -0.5, 3.33), mat=gold),
             mk.box("Mirror", (1.0, 0.1, 1.4), (2.0, -0.2, 4.1), rot=(-10, 0, 0), mat=mirror),
             mk.box("MirrorStand", (0.2, 0.2, 0.6), (2.0, -0.2, 3.5), mat=gold)]
    for k in range(9):
        x = -2.6 + k * 0.3
        colour = [(200, 60, 80), (240, 200, 180), (160, 40, 60), (230, 230, 226)][k % 4]
        parts += pk.bottle("Tester", x, -0.5, 3.36, pk.plastic(f"CO_T{k % 4}", colour), gold, r=0.1, h=0.5)
    for k in range(6):
        parts.append(mk.box("Palette", (0.5, 0.35, 0.06), (-2.2 + k * 0.8, 0.5, 2.3), mat=black, bevel=0.02))
    glows = [mk.box("Shelf", (5.6, 1.4, 0.05), (0, 0.2, 2.2), mat=pk.glow("CO_Shelf", (255, 244, 236), 2)),
             mk.box("Logo", (1.4, 0.05, 0.5), (0, -0.31, 5.2), mat=pk.glow("CO_Logo", (255, 220, 200), 3))]
    return parts, glows


@prop("FittingRoom", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def fitting_room():
    """A fitting cubicle 4 wide, its opening at -Y behind a heavy curtain half drawn: walls of framed panels on a
    skirting under a cornice, the head over the opening with its number; the curtain hanging in deep folds from
    rings on its rod; inside a mirror in a slim frame, a hook with a shirt on its hanger, a padded stool on four
    legs, the light over it all."""
    panel = mk.wood("FR_Panel", srgb(186, 160, 124), srgb(140, 116, 86))
    trim = mk.wood("FR_Trim", srgb(120, 94, 64), srgb(92, 70, 46))
    curtain = mk.noisy("FR_Curtain", srgb(84, 20, 26), srgb(118, 32, 38), scale=26, roughness=0.92)  # (velvet)
    mirror = pk.metal("FR_Mirror", (170, 176, 184), (210, 214, 220), rough=0.05, metallic=1.0)
    chrome = pk.chrome("FR_Chrome")
    pad = mk.noisy("FR_Pad", srgb(40, 34, 38), srgb(62, 54, 58), scale=24, roughness=0.8)
    shirt = mk.noisy("FR_Shirt", srgb(200, 206, 214), srgb(226, 230, 236), scale=20, roughness=0.85)
    ink = pk.plastic("FR_Ink", (236, 228, 210))
    parts = [mk.box("Back", (4.0, 0.15, 8.0), (0, 1.9, 4.0), mat=panel),
             mk.box("SideL", (0.15, 4.0, 8.0), (-2.0, 0, 4.0), mat=panel),
             mk.box("SideR", (0.15, 4.0, 8.0), (2.0, 0, 4.0), mat=panel),
             mk.box("Head", (4.3, 0.34, 0.7), (0, -1.9, 7.95), mat=trim, bevel=0.04),
             mk.box("Cornice", (4.4, 4.3, 0.18), (0, 0, 8.09), mat=trim, bevel=0.05)]
    # the walls' outer faces in framed panels on a skirting (the sides, and the back's)
    for sx in (-1, 1):
        parts.append(mk.box("Skirt", (0.08, 4.1, 0.5), (sx * 2.1, 0, 0.25), mat=trim))
        for zc in (2.4, 5.6):
            for obj in pk.frame("Panel", 3.2, 2.6, 0.12, 0.05, (0, 0, 0), trim):
                obj.data.transform(obj.matrix_basis)
                obj.matrix_basis = Matrix.Translation((sx * 2.1, 0, zc)) @ Matrix.Rotation(math.radians(90), 4, "Z")
                parts.append(obj)
    parts.append(mk.box("SkirtBack", (4.1, 0.08, 0.5), (0, 2.0, 0.25), mat=trim))
    parts += pk.label("Number", "3", 0.32, (0, -2.08, 7.95), ink)
    # The curtain: drawn across the left of the opening, hanging in deep folds from rings on the rod.
    rows, cols = 9, 44
    x0, x1, top, bottom = -1.9, 0.35, 7.42, 0.18
    grid = []
    for r in range(rows):
        z = top - (top - bottom) * r / (rows - 1)
        row = []
        for c in range(cols):
            u = c / (cols - 1)
            x = x0 + (x1 - x0) * u
            fold = 0.13 * math.sin(u * math.tau * 5.0) * (0.75 + 0.25 * r / (rows - 1))
            row.append((x, -1.8 + fold, z))
        grid.append(row)
    drape = mk.sheet("Curtain", grid, curtain)
    mk.smooth(drape)  # (round folds, not flat slats catching the light)
    parts.append(drape)
    parts.append(mk.tube("Rod", (-1.94, -1.8, 7.5), (1.94, -1.8, 7.5), 0.04, mat=chrome, verts=8))
    for k in range(6):
        parts.append(mk.torus("Ring", 0.07, 0.015, (x0 + (x1 - x0) * k / 5, -1.8, 7.5), rot=(0, 90, 0), mat=chrome,
                              major_segments=10, minor_segments=4))
    # Inside: the mirror in its frame, the hook with a shirt on a hanger, the padded stool.
    parts.append(mk.box("Mirror", (1.6, 0.05, 5.0), (0, 1.8, 3.8), mat=mirror))
    parts += pk.frame("MirrorFrame", 1.75, 5.15, 0.08, 0.07, (0, 1.79, 3.8), trim)
    parts.append(mk.tube("Hook", (-1.94, 1.0, 5.8), (-1.6, 1.0, 5.9), 0.03, mat=chrome, verts=4))
    parts.append(pk.sweep("Hanger", [(-1.62, 1.0, 5.9), (-1.6, 1.0, 5.72), (-1.6, 0.55, 5.45), (-1.6, 1.45, 5.45),
                                     (-1.6, 1.0, 5.72)], 0.018, chrome, sides=4))
    tee = mk.box("Shirt", (0.08, 0.95, 1.4), (-1.6, 1.0, 4.72), mat=shirt, bevel=0.03)
    for v in tee.data.vertices:  # (narrowing to the collar, a little slack at the hem)
        f = max(0.0, (v.co.z - 0.2) / 0.5)
        v.co.y *= 1.0 - 0.25 * min(1.0, f)
    parts.append(tee)
    parts.append(pk.rounded("StoolPad", (1.1, 1.1, 0.3), (1.2, 1.0, 1.55), pad, r=0.12))
    for dx, dy in ((-0.4, -0.4), (0.4, -0.4), (-0.4, 0.4), (0.4, 0.4)):
        parts.append(mk.cylinder("StoolLeg", 0.05, 1.42, (1.2 + dx, 1.0 + dy, 0.71), mat=chrome, verts=6))
    glows = [mk.box("Light", (1.5, 1.5, 0.05), (0, 0, 7.95), mat=pk.glow("FR_Light", (255, 236, 210), 2.5))]
    return parts, glows
