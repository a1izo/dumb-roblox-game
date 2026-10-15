"""The Muertos' shrine: a bare stone hall under the city, lit only by candles. Rows of candles on the floor
lead to an altar on three steps at the north end, draped in red, and above it a robed figure looms
against a red glow. Diavolo stands at the altar; the Muertos kneel before it."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.SHRINE
X0, X1, Z0, Z1, H = -11.0, 11.0, -16.0, 14.0, 20.0
STEP = 0.6
DOOR_W, DOOR_H = 6.4, 8.4  # the doorway in the south wall (the double doors are the cutscene's own props)
FLIGHT = dict(rise=0.5, run=0.85, steps=12)  # the stairs from the doorway up to the alley
ALLEY_Y = FLIGHT["rise"] * FLIGHT["steps"]
STAIR_TOP = Z1 + 0.5 + FLIGHT["run"] * FLIGHT["steps"]  # where the flight ends (local z)
ALLEY = (Z1 + 14.0, Z1 + 34.0)  # the alley's length (local z), at ALLEY_Y


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "Stone")
    kit.ceiling(s, x0, z0, x1, z1, H, "RuinStone")
    door = {"at": X1, "w": DOOR_W, "bottom": 0.0, "top": DOOR_H, "kind": "gap"}  # the way in, from the stairs
    runs = [((x0, z0), (x1, z0), []), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]), ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="RockGrey", side_s="RuinStone", openings=ops)
    # Pillars down both sides of the nave.
    for z in (-8.0, -1.0, 6.0):
        for x in (X0 + 2.4, X1 - 2.4):
            kit.column_square(s, OX + x, OZ + z, H, 1.6, "RuinStone", trim="Stone")
    # The altar: three steps up from the north wall, a red-draped stone block, and behind it the figure.
    for k in range(3):
        w, d = 14.0 - k * 2.0, 9.0 - k * 1.0
        s.box("Stone", (OX, STEP * (k + 0.5), OZ + Z0 + 0.5 + d / 2), (w, STEP, d), collide=True)
    top, block = STEP * 3, OZ + Z0 + 5.6
    s.box("RuinStone", (OX, top + 1.6, block), (6.0, 3.2, 2.4), collide=True)
    s.box("FabricRed", (OX, top + 3.25, block), (6.4, 0.1, 2.8))
    s.box("FabricRed", (OX, top + 2.2, block + 1.25), (2.4, 2.2, 0.05))
    s.prop("Effigy", OX, OZ + Z0 + 2.4, 0, 1.8, top)
    # A red glow over and behind the figure (its rim) and a red spot down on the altar.
    s.light("point", (OX, top + 13.0, OZ + Z0 + 0.9), (255, 40, 30), 22, 2.2, shadows=True)
    s.light("spot", (OX, H - 1.0, OZ + Z0 + 9.0), (255, 70, 50), 24, 1.4, shadows=True, angle=40)
    for dx in (-2.4, 0.0, 2.4):
        s.prop("CandleCluster", OX + dx, block, 0, 0.7, top + 3.2)
    # Two rows of candles on the floor down the nave to the door.
    for z in (-5.2, -1.6, 9.6):  # clear of the bottom step (its edge at -6.5) and of the kneeling Muertos
        for x in (-6.0, 6.0):
            s.prop("CandleCluster", OX + x, OZ + z, 37 * z)
    # A dim warm light down from the dark over the nave, on the altar steps and whoever kneels before them.
    s.light("spot", (OX, H - 1.0, OZ - 5.0), (255, 170, 110), 26, 0.9, shadows=True, angle=50)
    s.light("point", (OX, 3.0, OZ - 5.6), (255, 160, 90), 9, 0.6)  # the candles' glow on the steps
    s.emitter("mist", (OX, 0.6, OZ - 1.0), 0, (18.0, 1.6, 26.0))
    s.emitter("dust", (OX, 9.0, OZ - 1.0), 0, (18.0, 14.0, 26.0))
    stairs_and_alley(s)


def stairs_and_alley(s):
    """Out through the doorway: a stone stair climbing south between close walls, candles on its steps, to a
    landing and a rainy alley above (wet asphalt, brick walls, a dumpster, a warm lamp over the way down)."""
    z1 = OZ + Z1
    # the doorway's stone frame
    for side in (-1, 1):
        # (A hair proud of the wall's ends in the doorway: level with them, the two flickered.)
        s.box("Stone", (OX + side * (DOOR_W / 2 + 0.38), (DOOR_H + 0.4) / 2, z1), (0.84, DOOR_H + 0.4, 1.4), collide=True)
    s.box("Stone", (OX, DOOR_H + 0.6, z1), (DOOR_W + 1.6, 0.8, 1.4), collide=True)
    # the flight, its walls and vault, the landing at the top
    kit.stairs(s, OX, z1 + 0.5, 180, DOOR_W, FLIGHT["rise"], FLIGHT["run"], FLIGHT["steps"], "Stone")
    top = OZ + STAIR_TOP
    s.box("Stone", (OX, ALLEY_Y / 2, (top + OZ + ALLEY[0]) / 2), (DOOR_W, ALLEY_Y, OZ + ALLEY[0] - top), collide=True)
    for side in (-1, 1):
        x = OX + side * (DOOR_W / 2 + 0.5)
        # (From the shrine wall's face to the alley wall's: running into them, their faces lay in the planes of the
        # doorways' sides and flickered.)
        kit.wall(s, (x, z1 + 0.5), (x, OZ + ALLEY[0] - 0.5), ALLEY_Y + 9.0, core="RockGrey", side_s="RuinStone",
                 side_n="RuinStone")
    s.box("RuinStone", (OX, ALLEY_Y + 7.5, (z1 + OZ + ALLEY[0]) / 2), (DOOR_W + 2.0, 1.0, OZ + ALLEY[0] - z1),
          skip=("+y",))
    for i in (1, 4, 7, 10):
        step_top = FLIGHT["rise"] * (i + 1)
        z = z1 + 0.5 + FLIGHT["run"] * (i + 0.5)
        for side in (-1, 1):
            s.prop("CandleCluster", OX + side * 2.5, z, 0, 0.45, step_top)  # fits a tread
        s.light("point", (OX, step_top + 2.0, z), (255, 150, 80), 9, 0.6, flicker=True)
    # the alley
    a0, a1 = OZ + ALLEY[0], OZ + ALLEY[1]
    w = 10.0
    s.box("AsphaltWet", (OX, ALLEY_Y - 0.5, (a0 + a1) / 2), (2 * w, 1.0, a1 - a0), collide=True)
    entrance = {"at": w, "w": DOOR_W, "bottom": ALLEY_Y, "top": ALLEY_Y + 9.0, "kind": "gap"}  # heights from y 0
    walls = [((OX + w, a0), (OX - w, a0), [entrance], "BrickDark"), ((OX - w, a0), (OX - w, a1), [], "BrickDark"),
             ((OX - w, a1), (OX + w, a1), [], "BrickRed"), ((OX + w, a1), (OX + w, a0), [], "BrickDark")]
    for a, b, ops, mat in walls:
        kit.wall(s, a, b, 24.0, base=ALLEY_Y, core=mat, side_n=mat, side_s=mat, openings=ops)
    s.prop("Dumpster", OX + w - 2.2, a0 + 8.0, 90, 1.0, ALLEY_Y)
    s.tube("BlackMetal", (OX - w + 0.6, ALLEY_Y, a0 + 5.0), (OX - w + 0.6, ALLEY_Y + 22.0, a0 + 5.0), 0.25, 8)
    s.tube("BlackMetal", (OX + w - 0.6, ALLEY_Y, a0 + 15.0), (OX + w - 0.6, ALLEY_Y + 22.0, a0 + 15.0), 0.25, 8)
    kit.puddle(s, OX - 3.0, a0 + 6.0, 2.2, 1.4, y=ALLEY_Y + 0.03)
    kit.puddle(s, OX + 2.6, a0 + 13.0, 1.6, 2.4, y=ALLEY_Y + 0.03)
    # a sodium lamp over the way down, the moon from above, the candles' glow coming up the stairs
    kit.sconce(s, OX, ALLEY_Y + 9.8, a0 + 0.6, 180, color=(255, 170, 90), range_=26, brightness=1.3)
    s.light("spot", (OX, ALLEY_Y + 24.0, (a0 + a1) / 2), (150, 170, 220), 40, 0.8, shadows=True, angle=60)
    s.emitter("mist", (OX, ALLEY_Y + 0.6, (a0 + a1) / 2), 0, (2 * w - 2, 1.4, a1 - a0 - 2))

