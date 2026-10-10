"""Tokyo District at night: a compact 400 x 300 stud district at real scale. A big scramble
crossing sits in front of the station (its metro platform runs under the station drive), with a
glass tower and a department store on its corners and a covered shopping street leading off it;
a river lined with cherry trees crosses the south, and on its far bank lie the yokocho's tiny bars,
a karaoke tower and the rail viaduct. The expressway runs overhead along the north.

Built for the map TokyoDistrict: the gameplay spots are placed here with the architecture and
exported with it (src/server/Maps/Scenes/Tokyo/). The layout is in plan.py.
"""

from maps import buildings, city
from maps.venues.tokyo import boats, decor, dressing, edges, gameplay, ground, interiors, mood, plan, river, station
from maps.venues.tokyo import clutter, crowd, styles

FORMAT = 2
MAP_ID = "TokyoDistrict"
# Effect textures the map's own FBX carries (art/scripts/textures.py): the rain's streaks and
# splashes (client/World/RainController) and the petals over the river (SceneBuilder).
TEXTURES = ["TokyoRain", "TokyoSplash", "TokyoPetal"]

# Plan renders: the camera sits just under each level's ceiling, looking down.
PLAN_LEVELS = [("platform", -9.0), ("ground", 12.0), ("upper", 24.0)]

# Massing renders (--massing): (camera, target, lens), Roblox studs; and where a player-sized
# figure stands for scale.
MASSING_VIEWS = [
    ((120, 320, 180), (-40, 0, -40), 24),  # from high over the south-east
    ((170, 320, -200), (-20, 0, 20), 24),  # from high over the north-east
    ((-200, 300, 190), (-40, 0, 0), 24),  # from high over the south-west
    ((-52, 9, -34), (-30, 14, -80), 18),  # a player on the scramble, looking at its corners
]
FIGURES = [(-45, 0, -46, -30)]  # (x, y, z, rot)

# Night views for --preview: (camera, target, lens), a player's height and further out.
VIEWS = [
    ((-50, 10, -44), (-20, 20, -96), 17),  # the scramble from its south-west corner
    ((-66, 9, -50), (-130, 16, -70), 18),  # the station plaza and the station
    ((-110, 6, -72), (-140, 3, -60), 16),  # inside the station hall, towards the gates
    ((-117, 6.5, -64.8), (-141, -9, -64.8), 16),  # through the gates, down the stairs
    ((-36, -13, -60), (-120, -14, -66), 18),  # the metro platform with the train in
    ((-6, 8, -86), (60, 12, -104), 17),  # into the covered shopping street
    ((6, 7, -74), (40, 6, -82), 16),  # inside the department store
    ((-58, 9, 14), (30, 5, 38), 18),  # the river's north promenade under the cherry trees
    ((-101.5, 7, 58), (-101.5, 8, 112), 17),  # down a yokocho alley
    ((30, 9, 56), (92, 26, 82), 18),  # the karaoke tower across the bridge
    ((178, 8, -40), (206, 8, -41), 17),  # the east street's end: the barrier and the city past it
    ((60, 280, 230), (-40, 0, -40), 24),  # the whole district from above
]


def preview(s):
    """Things the game moves itself, shown in the previews: the train standing at the platform."""
    stop = (plan.PLATFORM[0] + plan.PLATFORM[1]) / 2
    z = sum(plan.TRACKS_Z[0]) / 2
    s.preview_prop("TrainHead", stop - 26.0, z, 90, 1.0, station.TRACK_Y + 0.7)
    s.preview_prop("TrainMiddle", stop + 26.0, z, 90, 1.0, station.TRACK_Y + 0.7)


def build(s):
    # The city far out past the edges goes in a few big meshes, not hundreds of small ones.
    s.far_chunk = (360.0, 1400.0)
    g = city.Ground(s)
    ground.build(s, g)
    river.build(s, g)
    station.build(s, g)
    tops = [(b["poly"], buildings.height(b["floors"])) for b in plan.BUILDINGS]
    for b in plan.BUILDINGS:
        others = [t for t, o in zip(tops, plan.BUILDINGS) if o is not b]
        buildings.build(s, b, styles.style(b), others, styles.fronts(b, plan.BUILDINGS))
    interiors.build(s, g)
    clutter.build(s)
    dressing.build(s)
    boats.build(s)
    decor.build(s)
    edges.build(s, g)
    mood.build(s)
    g.finish()
    gameplay.build(s)
    crowd.build(s)
    noir_signs(s)
    s.set_bounds(*plan.BOUNDS)


def noir_signs(s):
    """The district's English in a noir face: Bodoni on the big signs, Special Elite (a typewriter)
    on plates and notices. Japanese comes out in the game's own kanji face whatever the font."""
    for sign in s.signs:
        latin = any("A" <= ch <= "Z" or "a" <= ch <= "z" for ch in sign["text"])
        if sign["font"] != "GothamBlack" or not latin:
            continue
        small = sign["h"] < 1.5 or sign["w"] * sign["h"] < 8.0
        sign["font"] = "SpecialElite" if small else "Bodoni"
