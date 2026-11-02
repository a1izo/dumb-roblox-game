"""Each case map's own furniture (the user, 2026-11-02: "make way more detailed assets so we dont reuse them in every
other map"). The maps' scripts go on asking for "Chair" or "Desk"; Scene.prop gives each map its own model of that
thing, made to the same footprint and heights (props_mapown.py), so seats, desks, colliders and shots all hold.

The catalog names what each one stands for (`base`): until a set's import lands, a map shows the shared model there
(SceneBuilder), and the cutscene checks read it as the thing it stands for (cinema/clearance.py)."""

OWN = {
    "Campus": {
        "Chair": "LectureChair",
        "Bench": "OakBench",
        "Sofa": "ChesterfieldSofa",
        "Plant": "FernStand",
        "FilingCabinet": "OakCabinet",
        "Desk": "ProfessorDesk",
        "OfficeChair": "BankerChair",
    },
    "Agency": {
        "Chair": "BureauChair",
        "Bench": "BureauBench",
        "Sofa": "BureauSofa",
        "Plant": "OfficeFicus",
        "FilingCabinet": "BureauCabinet",
        "Desk": "BureauDesk",
        "Bookshelf": "ArchiveShelf",
    },
    "Tokyo": {
        "Bench": "StreetBench",
        "Sofa": "BoothSofa",
        "Plant": "BambooPot",
    },
}

BASE = {own: base for table in OWN.values() for base, own in table.items()}


def own(venue, key):
    """The model this venue uses for `key`: its own, or the shared one."""
    return OWN.get(venue, {}).get(key, key)
