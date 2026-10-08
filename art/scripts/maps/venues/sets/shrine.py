"""The Muertos' shrine: a bare stone hall under the city, lit only by candles. Rows of candles on the floor
lead to an altar on three steps at the north end, draped in red, and above it a robed figure looms
against a red glow. Diavolo stands at the altar; the Muertos kneel before it."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.SHRINE
X0, X1, Z0, Z1, H = -11.0, 11.0, -16.0, 14.0, 20.0
STEP = 0.6


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "Stone")
    kit.ceiling(s, x0, z0, x1, z1, H, "RuinStone")
    runs = [((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)), ((x0, z1), (x0, z0))]
    for a, b in runs:
        kit.wall(s, a, b, H, core="RockGrey", side_s="RuinStone")
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
