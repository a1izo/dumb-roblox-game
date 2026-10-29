"""The Muerto's flat, after the room Mikami writes in (Death Note; the user's reference of 2026-10-27,
youtube.com/watch?v=tBQhV6BWK18: the wide at 6.8 s, the glass at 5.0-5.6 s, the panels at 12.75 s). High over the
city at night: the north wall nearly all glass, floor to ceiling in small tall panes, blown out cold blue-white from
outside with the towers dark against it; before it a long glossy red desk with a silver rim on slim steel legs, a
pale glowing monitor, a keyboard, a silver gooseneck lamp and loose papers under the Manual; a dark teal marble
floor; frosted panels down both side walls glowing pink under recessed red downlights. Red against teal.

The desk keeps the old one's footprint (6.7 by 3.4, top 3.42) and its screen and lamp where they stood (the screen
on its west half, 2.5 to the writer's right; the lamp 1.4 to his left; both about head high), so the shots
(cinema/shots/role_follower.py, which bring the scene's own light) frame it as before. They look at the desk from
the room (south), the window behind it."""

import math

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.FLAT
X0, X1, Z0, Z1, H = -9.0, 9.0, -7.0, 7.0, 10.0
DESK = (0.0, -2.6)  # the desk (its writer sits north of it, facing south, the window at their back)
CHAIR = (1.3, -5.5)  # east of the screen, where the writer sits
DESK_SCALE = 1.12  # (the old Desk prop's scale: the shots' TOP is 3.05 times it)
TOP = 3.05 * DESK_SCALE  # the desk top; a seated R6 body's thighs (a stud thick, knees that do not bend) pass under
DESK_W, DESK_D = 6.72, 3.36
SCREEN = (-1.23, -1.95)  # the monitor's middle, on the desk's west half, its screen to the writer (north)
LAMP = (2.65, -1.75)  # the gooseneck lamp's foot, on the east half
PANELS = (-3.6, 0.3, 4.2)  # the frosted panels' middles along each side wall (z)
DOWNLIGHTS = ((-7.4, -3.6), (-7.4, 0.3), (-7.4, 4.2), (7.4, -3.6), (7.4, 0.3), (7.4, 4.2), (-3.2, 2.6), (3.2, 2.6))


def at(x, z):
    return OX + x, OZ + z


def desk(s):
    """The red desk: a glossy top in a silver rim a hair proud of its edges, slim steel legs and an apron under it."""
    dx, dz = at(*DESK)
    t = 0.12
    s.box("LacquerRed", (dx, TOP - t / 2, dz), (DESK_W, t, DESK_D))
    rim_y = TOP - 0.065
    for side in (-1, 1):
        s.box("Steel", (dx, rim_y, dz + side * (DESK_D / 2 + 0.03)), (DESK_W + 0.12, 0.15, 0.06))
        s.box("Steel", (dx + side * (DESK_W / 2 + 0.03), rim_y, dz), (0.06, 0.15, DESK_D))
    inset = 0.2
    for sx in (-1, 1):
        for sz in (-1, 1):
            s.box("Steel", (dx + sx * (DESK_W / 2 - inset), (TOP - t) / 2, dz + sz * (DESK_D / 2 - inset)),
                  (0.12, TOP - t, 0.12))
    apron_y = TOP - t - 0.09
    for side in (-1, 1):
        s.box("Steel", (dx, apron_y, dz + side * (DESK_D / 2 - inset)), (DESK_W - 2 * inset - 0.12, 0.18, 0.05))
        s.box("Steel", (dx + side * (DESK_W / 2 - inset), apron_y, dz), (0.05, 0.18, DESK_D - 2 * inset - 0.12))


def on_desk(s):
    """The monitor, the keyboard, the gooseneck lamp and the papers the Manual lies on."""
    # The monitor: a thin silver panel on a neck and foot, its pale screen to the writer (north).
    mx, mz = at(*SCREEN)
    s.box("Steel", (mx, TOP + 0.02, mz + 0.1), (0.9, 0.04, 0.6))
    s.box("Steel", (mx, TOP + 0.5, mz + 0.1), (0.16, 0.96, 0.08))
    s.box("Steel", (mx, 4.35, mz), (2.2, 1.5, 0.12))
    s.box("MonitorPale", (mx, 4.37, mz - 0.07), (2.0, 1.3, 0.02), skip=("+z",))
    s.light("point", (mx, 4.3, mz - 0.9), (176, 200, 230), 7, 0.9)
    # The keyboard before it.
    kx, kz = at(-1.12, -3.5)
    s.box("Screen", (kx, TOP + 0.035, kz), (2.0, 0.07, 0.66))
    s.box("BlackMetal", (kx, TOP + 0.075, kz + 0.02), (1.84, 0.012, 0.5))
    # The gooseneck lamp: a round foot, the neck rising and arching over towards the writer, a small cone hung
    # from its end with the bulb in its mouth.
    lx, lz = at(*LAMP)
    s.cylinder("Steel", (lx, TOP, lz), 0.3, 0.07, segments=20)
    neck = [(lx, TOP + 0.07, lz), (lx, TOP + 0.75, lz - 0.05), (lx - 0.03, TOP + 1.2, lz - 0.22),
            (lx - 0.08, TOP + 1.48, lz - 0.55), (lx - 0.12, TOP + 1.52, lz - 0.85)]
    for a, b in zip(neck, neck[1:]):
        s.tube("Steel", a, b, 0.035, segments=8)
    tip = neck[-1]
    mouth = (tip[0] - 0.05, tip[1] - 0.38, tip[2] - 0.2)
    s.tube("Steel", tip, mouth, 0.07, segments=14, radius_b=0.26)
    d = [m - p for m, p in zip(mouth, tip)]
    n = math.sqrt(sum(v * v for v in d))
    d = [v / n for v in d]
    s.tube("NeonWarm", tuple(m - v * 0.08 for m, v in zip(mouth, d)), tuple(m - v * 0.03 for m, v in zip(mouth, d)),
           0.2, segments=12)
    s.light("point", (mouth[0], mouth[1] - 0.25, mouth[2] - 0.1), (255, 232, 200), 6, 1.0, shadows=True)
    # Loose papers: two under the Manual (the shots lay it on them), two more at the desk's west end.
    for x, z, rot, lift in ((0.78, -3.3, 7, 0.012), (0.6, -3.42, -5, 0.03), (-2.75, -2.6, 12, 0.012),
                            (-2.6, -2.5, -3, 0.03)):
        px, pz = at(x, z)
        s.box("Paper", (px, TOP + lift, pz), (1.1, 0.012, 1.45), rot)


def panels(s):
    """Frosted panels down both side walls, each in a black frame standing on two feet, lit pink from behind."""
    for side in (-1, 1):
        px = OX + side * (X1 - 0.75)
        for z in PANELS:
            pz = OZ + z
            s.box("FrostPink", (px, 3.95, pz), (0.06, 7.1, 3.4))
            for edge in (-1, 1):
                s.box("BlackTrim", (px, 3.95, pz + edge * 1.76), (0.16, 7.36, 0.12))
                s.box("BlackTrim", (px, 0.14, pz + edge * 1.4), (0.16, 0.28, 0.12))
            for y in (0.34, 7.56):
                s.box("BlackTrim", (px, y, pz), (0.16, 0.12, 3.4))


def build(s):
    x0, z0 = at(X0, Z0)
    x1, z1 = at(X1, Z1)
    kit.floor(s, x0, z0, x1, z1, "MarbleTeal")
    kit.ceiling(s, x0, z0, x1, z1, H, "CeilingPlasterDark")
    # The north wall nearly all glass, floor to ceiling, in small tall panes (ten across, five up).
    window = {"at": 9.0, "w": 16.0, "bottom": 0.3, "top": 9.5, "kind": "window", "frame": "BlackTrim",
              "mullions": "BlackTrim", "cols": 10, "rows": 5, "sill": "BlackTrim", "glass": "Glass"}
    door = {"at": 14.0, "w": 3.6, "bottom": 0.0, "top": 7.6, "kind": "door", "frame": "BlackTrim"}
    runs = [((x0, z0), (x1, z0), [window]), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="PlasterDark", openings=ops, trim_s={"base": "BlackTrim"})
    # Beyond the glass: the cold glare (the reference's blown-out window) with the city's towers dark against it,
    # low, for the flat is high up (all well clear of the locker room to the north). A cold light from out there
    # throws the panes' grid across the floor.
    cx, cz = at(0.0, Z0)
    s.box("WindowCool", (cx, 6.0, cz - 14.0), (60.0, 40.0, 1.0))
    for dx, top, w in ((-17.0, 3.0, 7.0), (-9.5, 1.0, 5.0), (-3.0, 2.2, 6.0), (6.0, 0.5, 8.0), (14.5, 3.6, 6.0)):
        s.box("CityFacade", (cx + dx, top - 15.0, cz - 10.0), (w, 30.0, 1.0))
    s.light("spot", (cx + 2.0, 8.5, cz - 4.0), (200, 220, 255), 30, 1.1, shadows=True, face="Back", angle=70)
    # The desk, what stands on it, and its chair.
    desk(s)
    on_desk(s)
    px, pz = at(*CHAIR)
    s.prop("OfficeChair", px, pz, 180, 0.85)  # low enough for a seated R6 body to go under the desk
    panels(s)
    # Recessed red downlights over each side's panels and two over the floor before the desk, pooling pink.
    for x, z in DOWNLIGHTS:
        px, pz = at(x, z)
        s.cylinder("NeonRed", (px, H - 0.05, pz), 0.28, 0.05, segments=16, caps=(True, False))
        s.light("spot", (px, H - 0.3, pz), (255, 50, 90), 13, 0.9, angle=50)
    s.light("spot", (OX, H - 0.6, OZ + 3.0), (120, 130, 170), 22, 0.25, shadows=False, angle=80)  # a breath of fill
