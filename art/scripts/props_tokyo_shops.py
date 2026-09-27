"""Tokyo's shop and interior props (set "Tokyo"): konbini shelves, the drinks fridge, the till
counter, bar stools, the ramen counter and its meal-ticket machine, the game centre's claw
machine and arcade cabinet, the laundromat's washer and dryers, the department store's display
case, clothes rack, mannequin, cosmetics counter and fitting room.

Built to the semi-real standard (propkit). They face -Y (a customer's side) and stand on z = 0."""

import math
import random

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
      lights=[dict(at=(0, -2.2, 4.0), kind="point", color=(214, 232, 255), range=10, brightness=0.7)])
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
        parts.append(mk.box("Rail", (8.0, 0.3, 0.16), (0, -1.25, z), mat=steel))
    for x in (-2.66, 0.0, 2.66):
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
    """A konbini till counter 8 long, the customer's side at -Y: a laminate front with the shop's
    stripe, two registers with their customer screens, a card reader, the hot-snack case lit at
    one end, a donation box and a rack of sweets."""
    body = pk.plastic("SC_Body", (230, 230, 226))
    top = mk.noisy("SC_Top", srgb(170, 166, 160), srgb(200, 196, 190), scale=12, roughness=0.3)
    stripe = pk.plastic("SC_Stripe", (40, 120, 70))
    dark = pk.metal("SC_Dark", (30, 30, 34), (46, 46, 50))
    parts = [pk.rounded("Body", (8.0, 2.4, 3.3), (0, 0, 1.65), body, r=0.05),
             mk.box("Top", (8.2, 2.6, 0.12), (0, 0, 3.36), mat=top, bevel=0.03),
             mk.box("Stripe", (8.0, 0.04, 0.3), (0, -1.22, 2.7), mat=stripe),
             mk.box("Kick", (8.0, 0.3, 0.3), (0, -1.0, 0.15), mat=dark)]
    for x in (-2.4, 1.2):
        parts += [pk.rounded("Register", (1.4, 1.2, 0.6), (x, 0.4, 3.72), dark, r=0.06),
                  mk.box("Drawer", (1.2, 1.0, 0.25), (x, 0.4, 3.55), mat=dark),
                  mk.box("CustScreen", (0.8, 0.06, 0.55), (x, -0.4, 4.3), rot=(-10, 0, 0), mat=dark),
                  mk.cylinder("ScreenArm", 0.05, 0.6, (x, -0.35, 3.8), mat=dark, verts=6),
                  mk.box("Reader", (0.35, 0.5, 0.15), (x + 0.9, -0.7, 3.5), mat=dark, bevel=0.03)]
    parts += [mk.box("SnackCase", (2.0, 1.4, 1.6), (3.0, 0.2, 4.2), mat=pk.metal("SC_Steel", (150, 154, 160), (190, 194, 200))),
              mk.box("Donation", (0.5, 0.4, 0.6), (-0.6, -0.9, 3.72), mat=pk.plastic("SC_Box", (200, 40, 40)))]
    glows = [mk.box("SnackGlow", (1.8, 0.05, 1.2), (3.0, -0.52, 4.2), mat=pk.glow("SC_Snack", (255, 200, 120), 2.5))]
    for x in (-2.4, 1.2):
        glows.append(mk.box("CustLit", (0.7, 0.03, 0.45), (x, -0.44, 4.3), rot=(-10, 0, 0),
                            mat=pk.glow("SC_Screen", (120, 200, 255), 2.5)))
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
             mk.box("Panel", (3.8, 0.9, 0.3), (0, -1.9, 2.75), rot=(-15, 0, 0), mat=white),
             mk.cylinder("Stick", 0.05, 0.5, (-0.8, -2.0, 3.1), mat=chrome, verts=8),
             mk.sphere("Knob", 0.14, (-0.8, -2.0, 3.35), mat=pk.plastic("CM_Knob", (230, 40, 40)), segments=10, rings=6),
             mk.cylinder("Push", 0.18, 0.1, (0.2, -2.0, 3.0), mat=pk.plastic("CM_Push", (60, 160, 255)), verts=12),
             pk.rounded("Top", (3.9, 4.1, 0.9), (0, 0, 7.2), body, r=0.12),
             mk.box("GantryX", (3.4, 0.1, 0.1), (0, -0.4, 6.6), mat=chrome),
             mk.box("GantryY", (0.1, 3.4, 0.1), (0.3, 0, 6.6), mat=chrome),
             mk.cylinder("Cable", 0.02, 1.4, (0.3, -0.4, 5.9), mat=chrome, verts=4),
             mk.cylinder("ClawHub", 0.15, 0.3, (0.3, -0.4, 5.1), mat=chrome, verts=10)]
    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append(mk.tube("Claw", (0.3, -0.4, 5.0), (0.3 + math.cos(a) * 0.35, -0.4 + math.sin(a) * 0.35, 4.6), 0.03,
                             mat=chrome, verts=4))
    for x in (-1.85, 1.85):
        for y in (-1.95, 1.95):
            parts.append(mk.box("Post", (0.12, 0.12, 3.8), (x, y, 4.75), mat=chrome))
    for k in range(14):
        colour = [(250, 200, 220), (200, 230, 255), (255, 240, 170), (220, 200, 255)][k % 4]
        mat = pk.plastic(f"CM_Toy{k % 4}", colour)
        x, y = rng.uniform(-1.4, 1.4), rng.uniform(-1.3, 1.5)
        parts.append(mk.sphere("Toy", 0.45, (x, y, 3.2 + rng.uniform(0, 0.3)), scale=(1, 1, 0.8), mat=mat, segments=10, rings=6))
        parts.append(mk.sphere("Ear", 0.14, (x - 0.25, y, 3.65), mat=mat, segments=6, rings=4))
    glows = [mk.box("Marquee", (3.4, 0.05, 0.6), (0, -2.07, 7.2), mat=pk.glow("CM_Marquee", (255, 150, 210), 3)),
             mk.box("CaseLight", (3.3, 3.5, 0.05), (0, 0, 6.72), mat=pk.glow("CM_Case", (255, 230, 245), 2))]
    return parts, glows


@prop("ArcadeCabinet", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def arcade_cabinet():
    """A sit-down video cabinet: the screen under a lit marquee, a control panel with a stick and
    six buttons, the coin door, side art."""
    body = pk.plastic("AC_Body", (22, 26, 40))
    side = pk.plastic("AC_Side", (60, 40, 140))
    dark = pk.metal("AC_Dark", (20, 20, 24), (34, 34, 38))
    chrome = pk.chrome("AC_Chrome")
    parts = [mk.box("Cabinet", (3.0, 3.6, 6.0), (0, 0.4, 3.0), mat=body, bevel=0.06),
             mk.box("Panel", (3.0, 1.2, 0.35), (0, -1.6, 3.3), rot=(-12, 0, 0), mat=dark, bevel=0.04),
             mk.box("CoinDoor", (1.0, 0.05, 0.9), (0, -1.43, 1.6), mat=dark),
             mk.box("Bezel", (2.8, 0.2, 2.4), (0, -1.2, 4.7), rot=(-12, 0, 0), mat=dark)]
    for sx in (-1, 1):
        parts.append(mk.box("SideArt", (0.04, 3.4, 5.4), (sx * 1.52, 0.4, 3.1), mat=side))
    parts += [mk.cylinder("Stick", 0.05, 0.45, (-0.8, -1.7, 3.65), mat=chrome, verts=8),
              mk.sphere("Ball", 0.16, (-0.8, -1.7, 3.9), mat=pk.plastic("AC_Ball", (230, 40, 40)), segments=10, rings=6)]
    for k in range(6):
        parts.append(mk.cylinder("Btn", 0.12, 0.1, (0.1 + (k % 3) * 0.38, -1.65 + (k // 3) * 0.3, 3.55),
                                 mat=pk.plastic(f"AC_Btn{k % 3}", [(230, 40, 40), (40, 160, 255), (250, 200, 40)][k % 3]), verts=10))
    glows = [mk.box("Screen", (2.5, 0.05, 2.0), (0, -1.32, 4.7), rot=(-12, 0, 0), mat=pk.glow("AC_Screen", (120, 200, 255), 3)),
             mk.box("Marquee", (2.8, 0.05, 0.6), (0, -1.0, 6.1), mat=pk.glow("AC_Marquee", (255, 220, 120), 3)),
             mk.box("Coin", (0.3, 0.05, 0.2), (0, -1.47, 1.8), mat=pk.glow("AC_Coin", (255, 60, 60), 3))]
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
             mk.box("TopPanel", (3.2, 0.3, 0.9), (0, -1.45, 3.9), mat=panel),
             mk.torus("Ring", 1.0, 0.12, (0, -1.6, 2.0), rot=(90, 0, 0), mat=chrome, major_segments=24, minor_segments=6),
             mk.cylinder("Window", 0.92, 0.1, (0, -1.56, 2.0), rot=(90, 0, 0), mat=dark, verts=24),
             mk.box("Handle", (0.2, 0.2, 0.7), (0.95, -1.75, 2.0), mat=chrome, bevel=0.05),
             mk.box("CoinBox", (0.8, 0.1, 0.5), (0.8, -1.62, 3.9), mat=chrome),
             mk.cylinder("Dial", 0.2, 0.1, (-0.8, -1.62, 3.9), rot=(90, 0, 0), mat=chrome, verts=12),
             mk.box("Kick", (3.0, 0.2, 0.3), (0, -1.45, 0.15), mat=panel)]
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
    glass = pk.dark_glass("DC_Glass", (90, 110, 120))
    parts = [pk.rounded("Cabinet", (6.0, 2.4, 2.4), (0, 0, 1.2), body, r=0.06),
             mk.box("Velvet", (5.6, 2.0, 0.1), (0, 0, 2.5), mat=velvet),
             mk.box("GlassTop", (6.0, 2.4, 0.06), (0, 0, 3.47), mat=glass)]
    for x in (-3.0, 3.0):
        for y in (-1.2, 1.2):
            parts.append(mk.box("Edge", (0.1, 0.1, 1.0), (x, y, 3.0), mat=brass))
    for y in (-1.2, 1.2):
        parts.append(mk.box("Rail", (6.0, 0.1, 0.1), (0, y, 3.47), mat=brass))
    for k in range(10):
        x = -2.5 + k * 0.55
        parts.append(mk.torus("Ring", 0.12, 0.03, (x, -0.4, 2.62), rot=(90, 0, 0), mat=gold, major_segments=12,
                              minor_segments=4))
        parts.append(mk.cylinder("Watch", 0.14, 0.05, (x, 0.4, 2.58), mat=gold, verts=12))
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


@prop("Mannequin", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Tokyo")
def mannequin():
    """A dressed display mannequin: a smooth grey figure in a long coat and scarf on a round glass
    base, arms at its sides, its face blank."""
    skin = pk.plastic("MN_Skin", (200, 200, 196))
    coat = mk.noisy("MN_Coat", srgb(90, 70, 50), srgb(120, 96, 70), scale=24, roughness=0.9)
    scarf = mk.noisy("MN_Scarf", srgb(150, 30, 40), srgb(190, 50, 60), scale=24, roughness=0.9)
    base = pk.dark_glass("MN_Base", (60, 70, 80))
    parts = [mk.cylinder("Base", 0.9, 0.12, (0, 0, 0.06), mat=base, verts=24),
             mk.cylinder("Rod", 0.05, 0.9, (0, 0.2, 0.55), mat=pk.chrome("MN_Rod"), verts=6),
             mk.lathe("Coat", [(0.0, 0.9), (0.72, 0.95), (0.62, 2.6), (0.56, 3.6), (0.7, 4.3), (0.36, 4.7), (0.0, 4.75)],
                      mat=coat, segments=18),
             mk.cylinder("Neck", 0.16, 0.4, (0, 0, 4.9), mat=skin, verts=10),
             mk.sphere("Head", 0.42, (0, 0, 5.55), scale=(0.85, 0.9, 1.1), mat=skin, segments=14, rings=10),
             mk.torus("Scarf", 0.3, 0.12, (0, 0, 4.75), mat=scarf, major_segments=16, minor_segments=6)]
    for sx in (-1, 1):
        parts += [mk.tube("Arm", (sx * 0.72, 0, 4.3), (sx * 0.78, 0.05, 2.5), 0.16, 0.13, mat=coat, verts=8),
                  mk.sphere("Hand", 0.13, (sx * 0.78, 0.05, 2.35), mat=skin, segments=8, rings=6)]
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
    """A fitting cubicle 4 wide, its opening at -Y behind a heavy curtain half drawn: panelled
    sides, a mirror and a hook inside, a light over it, a stool."""
    panel = mk.wood("FR_Panel", srgb(186, 160, 124), srgb(140, 116, 86))
    curtain = mk.banded("FR_Curtain", srgb(90, 24, 30), srgb(120, 34, 40), frequency=18, axis="X", roughness=0.9)
    mirror = pk.metal("FR_Mirror", (170, 176, 184), (210, 214, 220), rough=0.05, metallic=1.0)
    chrome = pk.chrome("FR_Chrome")
    parts = [mk.box("Back", (4.0, 0.15, 8.0), (0, 1.9, 4.0), mat=panel),
             mk.box("SideL", (0.15, 4.0, 8.0), (-2.0, 0, 4.0), mat=panel),
             mk.box("SideR", (0.15, 4.0, 8.0), (2.0, 0, 4.0), mat=panel),
             mk.box("Head", (4.0, 0.3, 0.6), (0, -1.9, 7.9), mat=panel),
             mk.box("Mirror", (1.6, 0.05, 5.0), (0, 1.8, 3.8), mat=mirror),
             mk.tube("Rod", (-1.9, -1.8, 7.5), (1.9, -1.8, 7.5), 0.04, mat=chrome, verts=6),
             mk.box("Curtain", (2.2, 0.1, 7.0), (-0.9, -1.8, 4.0), mat=curtain),
             mk.cylinder("Stool", 0.5, 1.6, (1.2, 1.0, 0.8), mat=panel, verts=16),
             mk.tube("Hook", (-1.85, 1.0, 5.8), (-1.6, 1.0, 5.9), 0.03, mat=chrome, verts=4)]
    glows = [mk.box("Light", (1.5, 1.5, 0.05), (0, 0, 7.95), mat=pk.glow("FR_Light", (255, 236, 210), 2.5))]
    return parts, glows
