"""The courthouse steps of God of the New World told for the Bureau (src/shared/Cinema/WinCuts.luau newWorldBureau;
the user, 2026-10-27: every shop win cutscene for both Ace and the Coven): the morning the case ends. A white stone
courthouse, its portico of six fluted columns under a deep entablature and attic, bronze doors; a broad flight of
steps falling from its landing to a paved square, the press held back at its foot behind barriers, lamp posts still
lit, and across the square a block of offices with the big screen the news plays on (the cutscene's). The sun comes
up low over the square, straight into the portico. The star's mark is the landing's front edge, in the middle
(plan.STEPS), looking down the steps (-z)."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.STEPS
DROP = 6.0  # the square, below the landing
RISE, RUN, COUNT = 0.6, 1.2, 10  # the flight: from the square up to the landing
HALF = 19.0  # the portico's half width
COLUMNS = (-12.5, -7.5, -2.5, 2.5, 7.5, 12.5)
COL_Z, COL_H = 4.0, 13.0
FRONT = 10.0  # the façade (the doors' wall) behind the columns
SUN = (255, 214, 168)


def build(s):
    # The landing the star stands on and the portico's floor, white marble to the doors.
    kit.floor(s, OX - HALF, OZ, OX + HALF, OZ + FRONT, "MarbleWhite")
    kit.stairs(s, OX, OZ - RUN * COUNT, 180, 2 * HALF - 4.0, RISE, RUN, COUNT, "Stone", base=-DROP)
    # (the cheek blocks either side of the flight, a lamp on each)
    for side in (-1, 1):
        x = OX + side * (HALF - 1.0)
        s.box("Stone", (x, -DROP / 2 + 0.6, OZ - RUN * COUNT / 2), (2.0, DROP + 1.2, RUN * COUNT))
        s.box("MarbleWhite", (x, 0.75, OZ - RUN * COUNT / 2), (2.3, 0.3, RUN * COUNT + 0.3))
        kit.lantern_post(s, x, OZ - 1.2, h=5.0, y=0.9, collide=False)
    # The square: warm pavers out to the offices across it; the barriers holding the press at the flight's foot.
    kit.floor(s, OX - 70.0, OZ - 82.0, OX + 70.0, OZ - RUN * COUNT, "PaversWarm", y=-DROP)
    for k in range(-3, 4):
        s.prop("Barricade", OX + k * 4.6, OZ - RUN * COUNT - 2.6, 0, 1.0, -DROP)
    for x in (-30.0, -14.0, 14.0, 30.0):
        kit.lantern_post(s, OX + x, OZ - 30.0, h=10.0, y=-DROP, collide=False)
    # The portico: six fluted columns, the entablature across them, the attic over it with its middle raised.
    for x in COLUMNS:
        kit.column_round(s, OX + x, OZ + COL_Z, COL_H, 1.0, "MarbleWhite", trim="Stone", flutes=16, collide=False)
    s.box("Stone", (OX, COL_H + 0.9, OZ + COL_Z + 2.5), (2 * HALF, 1.8, 7.0))  # the architrave and frieze
    s.box("MarbleWhite", (OX, COL_H + 2.05, OZ + COL_Z + 2.4), (2 * HALF + 1.2, 0.5, 7.6))  # the cornice
    s.box("Stone", (OX, COL_H + 3.6, OZ + COL_Z + 3.0), (2 * HALF - 1.0, 2.6, 6.0))  # the attic
    s.box("Stone", (OX, COL_H + 5.6, OZ + COL_Z + 3.0), (14.0, 1.4, 5.0))
    s.box("MarbleWhite", (OX, COL_H + 6.4, OZ + COL_Z + 3.0), (14.6, 0.3, 5.4))
    # The façade behind them: stone, tall bronze doors in the middle, a tall window either side.
    door = {"at": HALF, "w": 5.0, "bottom": 0.0, "top": 10.0, "kind": "door", "frame": "Brass"}
    windows = [{"at": HALF + dx, "w": 3.0, "bottom": 2.0, "top": 10.0, "kind": "window", "frame": "Brass",
                "mullions": "Brass", "cols": 2, "rows": 4, "sill": "Stone", "glass": "WindowDark"}
               for dx in (-10.0, 10.0)]
    kit.wall(s, (OX - HALF, OZ + FRONT), (OX + HALF, OZ + FRONT), COL_H + 1.8, thick=1.2, core="Stone",
             side_s="Stone", side_n="Stone", openings=[door] + windows)
    s.box("Brass", (OX - 1.25, 5.0, OZ + FRONT + 0.2), (2.4, 10.0, 0.25))  # the doors, shut
    s.box("Brass", (OX + 1.25, 5.0, OZ + FRONT + 0.2), (2.4, 10.0, 0.25))
    for side in (-1, 1):  # the portico's end walls
        kit.wall(s, (OX + side * HALF, OZ + 1.6), (OX + side * HALF, OZ + FRONT), COL_H + 1.8, thick=1.4,
                 core="Stone", side_s="Stone", side_n="Stone")
    # Across the square: a block of offices facing the courthouse, its windows catching the sun, the screen's frame.
    s.box("FacadeTileGrey", (OX, 14.0 - DROP, OZ - 86.0), (120.0, 40.0, 6.0))
    for row in range(6):
        for k in range(-13, 14):
            if abs(k) <= 3 and row >= 2:
                continue  # (the screen covers these)
            s.box("WindowCool", (OX + k * 4.2, -DROP + 4.0 + row * 5.6, OZ - 82.9), (2.6, 3.4, 0.1))
    s.box("BlackMetal", (OX, 13.0, OZ - 82.8), (26.0, 14.6, 0.6))
    # The low sun over the square, into the portico; the shade under the entablature.
    s.light("spot", (OX - 8.0, 10.0, OZ - 70.0), SUN, 90, 2.6, shadows=True, face="Back", angle=50)
