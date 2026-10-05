"""Kagegaoka University (影ヶ丘大学) on the eve of its entrance exam: a winter night, snow falling.
The red gate opens onto the avenue of bare ginkgos, which runs up to the forecourt and the Great
Auditorium, where tomorrow's exam hall waits under its clock tower.
- West of the avenue: Law & Letters with its arcade, the pond hollow with its frozen pond and
  red bridge, the club house and the cafeteria.
- East of it: the library (its reading room's gallery up two stairs), the tennis court under
  snow, and the Faculty of Science with its forensic medicine lab.
- Beyond the wall, Kagegaoka carries on in the snow, the Agency's tower on its skyline.

Built for the map UniversityCampus: the gameplay spots are placed here with the architecture and
exported with it (src/server/Maps/Scenes/Campus/). The layout is in plan.py."""

from maps import catalog, city
from maps.venues.campus import auditorium, faculties, fit, gameplay, ground, grounds, library, mood, outside, student
from maps.venues.campus import plan as P

FORMAT = 2
MAP_ID = "UniversityCampus"
# Effect textures the map's own FBX carries (art/scripts/textures.py): the crisp snow crystal the
# snow falls as (client/World/RainController) and the feather that now and then falls through it.
TEXTURES = ["CampusFlake", "Feather"]

# Plan renders: the camera under each level's ceiling, looking down.
PLAN_LEVELS = [("ground", 11.0), ("gallery", 24.0)]

# Massing renders (--massing): (camera, target, lens); a player-sized figure for scale.
MASSING_VIEWS = [
    ((200.0, 230.0, 220.0), (0.0, 0.0, 0.0), 24),
    ((-220.0, 220.0, -200.0), (0.0, 0.0, 0.0), 24),
    ((-20.0, 6.0, 60.0), (-20.0, 30.0, -60.0), 18),
]
FIGURES = [(-20.0, 0.0, 30.0, 0.0)]

# Night views for --preview: (camera, target, lens), at a player's height unless noted.
VIEWS = [
    ((-6.0, 7.0, 134.0), (-20.0, 13.0, 50.0), 16),  # the red gate and its cordon from the street, the avenue beyond
    ((-20.0, 6.0, 60.0), (-20.0, 40.0, -60.0), 18),  # the avenue's vista to the clock tower
    ((-40.0, 6.0, -31.0), (-50.0, 5.0, -44.0), 16),  # the forecourt, the evidence board's kiosk
    ((-46.0, 6.0, -66.0), (-62.0, 4.0, -72.0), 14),  # the exam headquarters
    ((-20.0, 8.0, -80.0), (-20.0, 6.0, -105.0), 14),  # the exam hall
    ((100.0, 18.0, -78.0), (110.0, 4.0, -50.0), 14),  # the reading room from the gallery
    ((-70.0, 2.0, 36.0), (-104.0, -3.0, 0.0), 16),  # the pond hollow and the bridge
    ((-92.0, 5.5, 73.5), (-146.0, 5.0, 73.5), 14),  # the club house corridor
    ((-44.0, 6.0, 62.0), (-70.0, 4.0, 92.0), 14),  # the cafeteria
    ((72.0, 6.0, 66.0), (90.0, 4.0, 50.0), 14),  # the forensic medicine lab
    ((60.0, 6.0, 30.0), (104.0, 4.0, -4.0), 16),  # the tennis court through its fence
    ((60.0, 260.0, 240.0), (0.0, 0.0, 0.0), 24),  # the campus from above
]

# check_v2's targets: the walk (seconds) between the campus's far corners, measured between
# the rooms furthest apart (the stair up to the gallery included).
CHECKS = {
    "walk": (22.0, 30.0),
    "corners": [[(-144.0, 0.0, -104.0), (146.0, 0.0, 68.0)], [(-146.0, 0.0, 106.0), (146.0, 0.0, -106.0)],
                [(130.0, P.GALLERY_Y, -80.0), (-92.0, 0.0, 106.0)]],
}


def preview(s):
    """What the game builds itself, for the previews: the station looks."""
    cat = catalog.load()
    for st in s_layout(s)["stations"]:
        info = cat.get(st["prop"], {})
        ax, az = info.get("anchor") or (0.0, 0.0)
        dx, dz = fit.turn(st["rot"], -ax, -az)
        s.prop(st["prop"], st["x"] + dx, st["z"] + dz, st["rot"], 1.0, st["y"])


_LAST = {}


def s_layout(s):
    return _LAST.get("layout") or {"stations": []}


def build(s):
    g = city.Ground(s)
    ground.build(s, g)
    auditorium.build(s, g)
    library.build(s, g)
    faculties.build(s, g)
    student.build(s, g)
    grounds.build(s)
    outside.build(s, g)
    gameplay.build(s)
    mood.build(s)
    g.finish()
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
    s.far_chunk = (200.0, 1400.0)
    fit.clear_of_stations(s)
    _LAST["layout"] = s.layout
