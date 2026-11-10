"""Where each scene death's set stands in the Scenes venue: its own cell, 1000 studs along X apart, so no mesh holds
two sets (SceneDeaths finds a set's meshes by this cell: round(x / 1000) is the set's index)."""

ORDER = ("patriot", "blackwall", "walrider", "sam", "ironman", "selection")
PATRIOT = (0.0, 0.0)
BLACKWALL = (1000.0, 0.0)
WALRIDER = (2000.0, 0.0)
SAM = (3000.0, 0.0)
IRONMAN = (4000.0, 0.0)
SELECTION = (5000.0, 0.0)
CELL = 1000.0

# The skies the scenes show (Sky faces SkyScene<name><face>, art/scripts/scene_skies.py).
SKIES = ("Mist", "Dusk", "Ember", "Requiem", "God", "Night")

BOUNDS = ((-450.0, -80.0, -450.0), (5450.0, 220.0, 450.0))


def group(centre):
    """The set a piece belongs to (its index in ORDER)."""
    return round(centre[0] / CELL)


def name_at(x):
    k = round(x / CELL)
    return ORDER[k] if 0 <= k < len(ORDER) else ORDER[-1]
