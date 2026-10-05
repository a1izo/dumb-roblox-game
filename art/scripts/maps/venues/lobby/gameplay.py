"""The lobby's spawns: where players appear on the terrace (the game uses the spawn anchor; these tell
the checks where people start their walk)."""

from maps.venues.lobby import plan as P


def build(s):
    for x, z in P.SPAWNS:
        s.spawn(x, z, P.TERRACE[4], rot=0.0)
