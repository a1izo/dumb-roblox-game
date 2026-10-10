"""The gameplay side of a map scene: where the game puts its stations, spawns, paper sheets,
hoods, named areas, the tip box and the evidence board, plus spare spots for each
(a later rework can change the counts without rebuilding the map), zones (what kind of ground
each place is: road, sidewalk, interior...) and the box Specters stay inside.

Mixed into mesher.Scene, so a venue script writes s.station(...) next to the walls around it.
Everything is in the venue's local studs, like the geometry (rot 0 faces -Z).
"""

ZONE_KINDS = (
    "road",  # vehicles: nothing of the game's may stand here
    "crossing",  # painted crossings: people walk here, nothing stands here
    "sidewalk",
    "plaza",
    "alley",
    "lane",  # shared pedestrian street without a kerb
    "arcade",  # covered shopping street
    "interior",
    "platform",
    "park",
    "stairs",
    "water",
    "track",
    "offlimits",  # scenery the player cannot reach
)

# Where gameplay objects must never stand.
FORBIDDEN = ("road", "crossing", "water", "track", "stairs", "offlimits")

STATION_TYPES = ("Camera", "Fingerprint", "Phone", "Forensics")


class LayoutMixin:
    def _layout_init(self):
        self.layout = {
            "stations": [],
            "spawns": [],
            "sheets": [],
            "hoods": [],
            "areas": [],
            "tipBox": None,
            "board": None,
        }
        self.spare = {"stations": [], "spawns": [], "sheets": [], "hoods": [], "areas": []}
        self.zones = []
        self.anchors = {}
        # Tokyo's scramble: where its crowd walks (nodes, links between them, posts where some stand)
        # and where its cars drive (lanes, each with the distance along it to its stop line).
        self.crowd = {"nodes": [], "links": [], "posts": []}
        self.traffic = {"lanes": []}
        self.bounds = None

    def _put(self, kind, item, spare):
        (self.spare if spare else self.layout)[kind].append(item)
        return item

    def station(self, type_, name, x, z, rot, y=0.0, prop="Station", spare=False, id=None):
        assert type_ in STATION_TYPES, type_
        item = {"id": id or name, "type": type_, "name": name, "x": x, "y": y, "z": z, "rot": rot, "prop": prop}
        return self._put("stations", item, spare)

    def spawn(self, x, z, y=0.0, rot=None, spare=False, group=None):
        item = {"x": x, "y": y, "z": z}
        if rot is not None:
            item["rot"] = rot
        if group:
            item["group"] = group
        return self._put("spawns", item, spare)

    def sheet(self, x, y, z, spare=False):
        """y is the top of the surface the sheet lies on (tables 2.8, counters 3.55, + floor)."""
        return self._put("sheets", {"x": x, "y": y, "z": z}, spare)

    def hood(self, x, z, y=0.6, spare=False):
        return self._put("hoods", {"x": x, "y": y, "z": z}, spare)

    def area(self, name, x, z, y=0.0, marks=(), spare=False):
        """A named place. marks: (kind, x, z, rot[, y]) with kind "stand", "seat" or "wall":
        where avatars perform in the intro (a seat gets a chair behind it; a wall mark has its
        back to a wall). rot is the way the avatar faces."""
        out = []
        for mark in marks:
            kind, mx, mz, mrot = mark[:4]
            my = mark[4] if len(mark) > 4 else y
            out.append({"kind": kind, "x": mx, "y": my, "z": mz, "rot": mrot})
        return self._put("areas", {"name": name, "x": x, "y": y, "z": z, "marks": out}, spare)

    def tip_box(self, x, z, rot, y=0.0):
        self.layout["tipBox"] = {"x": x, "y": y, "z": z, "rot": rot}

    def board(self, x, y, z, rot, w=12.0, h=7.0):
        """The evidence board: y is its centre."""
        self.layout["board"] = {"x": x, "y": y, "z": z, "rot": rot, "w": w, "h": h}

    def zone(self, kind, poly, y0=0.0, y1=None, name=None):
        """poly: [(x, z)] (any winding); the ground's height runs from y0 to y1 inside it (they
        differ on slopes)."""
        assert kind in ZONE_KINDS, kind
        self.zones.append({"kind": kind, "poly": [tuple(p) for p in poly], "y0": y0,
                           "y1": y0 if y1 is None else y1, "name": name})

    def crowd_node(self, x, z, y=0.0, kind="walk"):
        """A spot the crowd walks through (kind "kerb": it waits there for the walk signal). Returns its
        index (1-based, as Luau reads it)."""
        self.crowd["nodes"].append({"x": round(x, 2), "y": y, "z": round(z, 2), "kind": kind})
        return len(self.crowd["nodes"])

    def crowd_link(self, a, b, kind="walk", width=2.0):
        """A way between two nodes (kind "crossing": only walked on the walk signal); width: how far a
        walker may step aside on it."""
        self.crowd["links"].append({"a": a, "b": b, "kind": kind, "width": width})

    def crowd_post(self, x, z, rot, y=0.0, kind="clerk"):
        """Where one of the crowd stands all match (behind a counter, at the police box's door)."""
        self.crowd["posts"].append({"x": x, "y": y, "z": z, "rot": rot, "kind": kind})

    def traffic_lane(self, points, stop, width=4.0, road=1, kinds=None):
        """A lane cars drive along ([(x, z)], from where they appear to where they leave); stop: the
        distance along it to its stop line (where they wait while pedestrians cross); road: which of
        the junction's roads it belongs to (the roads take turns, so their cars never cross); kinds:
        the only models that drive it (ModelCatalog keys; any of the game's cars when not given)."""
        lane = {"points": [[round(x, 2), round(z, 2)] for x, z in points], "stop": round(stop, 2), "width": width,
                "road": road}
        if kinds:
            lane["kinds"] = list(kinds)
        self.traffic["lanes"].append(lane)

    def anchor(self, name, x, y, z, rot=0.0, **extra):
        """A named spot the venue's own Luau builds something at (boards, seats, altars...)."""
        self.anchors[name] = dict(x=x, y=y, z=z, rot=rot, **extra)

    def set_bounds(self, lo, hi):
        """The box (local corners) Specters stay inside."""
        self.bounds = (tuple(lo), tuple(hi))
