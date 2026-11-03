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
        "ExecutiveDesk": "ProfessorDesk",
        "Desk": "ProfessorDesk",
        "OfficeChair": "BankerChair",
        "Whiteboard": "ChalkBoard",
        "CoatStand": "BentwoodCoatStand",
        "DisplayCase": "OakDisplayCase",
        "CoinLockers": "OakLockers",
        "VendingWhite": "CupVendor",
        "VendingBlue": "CupVendor",
        "DrinkFridge": "CanteenChiller",
        "MealTicketMachine": "PushTicketer",
        "PoliceTape": "CampusTape",
        "WaterCooler": "StoneFountain",
        "PinBoard": "CorkBoard",
        "Planter": "GranitePlanter",
        "Barricade": "TimberBarrier",
        "SiteFence": "ScaffoldScreen",
        "UtilityPole": "SnowPole",
        "Bicycle": "SnowBicycle",
        "TrafficCone": "SnowCone",
        "Taxi": "SnowTaxi",
        "KeiTruck": "SnowKeiTruck",
        "PoliceCar": "SnowPoliceCar",
        "FumeHood": "SoapstoneHood",
        "Photocopier": "Mimeograph",
        "MicrofilmReader": "FilmReader",
        "KaraokeSpeaker": "ClubAmp",
        "MicStand": "ClubMic",
        "RecycleBins": "BinStore",
        "FloorLamp": "ReadingLamp",
        "BusShelter": "TimberShelter",
        "BusStopSign": "CampusBusSign",
        "StationClock": "SchoolClock",
    },
    "Agency": {
        "Chair": "BureauChair",
        "PlatformBench": "BureauBench",
        "Bench": "BureauBench",
        "Sofa": "BureauSofa",
        "Plant": "OfficeFicus",
        "FilingCabinet": "BureauCabinet",
        "Desk": "BureauDesk",
        "Bookshelf": "ArchiveShelf",
        "CoinLockers": "StaffLockers",
        "Crate": "EvidenceCrate",
        "VendingWhite": "SnackVendor",
        "VendingBlue": "SnackVendor",
        "DrinkFridge": "BureauCooler",
        "MealTicketMachine": "CanteenKiosk",
        "PoliceTape": "BureauTape",
        "TicketGate": "SecurityGate",
        "DisplayCase": "HonorCase",
        "Microscope": "ForensicScope",
        "BarStool": "CounterStool",
        "TrashCan": "OfficeBin",
        "Planter": "SteelPlanter",
        "SpecimenShelf": "EvidenceRack",
        "FloorLamp": "BureauFloorLamp",
        "Mannequin": "RangeTarget",
    },
    "Tokyo": {
        "Bench": "StreetBench",
        "Sofa": "BoothSofa",
        "Plant": "BambooPot",
        "Crate": "MarketCrate",
        "WaterCooler": "WaterServer",
        "PinBoard": "WardBoard",
    },
}

# (several things can stand for one model: the last named in a map is the one it falls back on, so the Core VendingMachine,
# which is gone, is mapped apart)
RETIRED = {"Campus": {"VendingMachine": "CupVendor"}, "Agency": {"VendingMachine": "SnackVendor"}}

BASE = {own: base for table in OWN.values() for base, own in table.items()}


def own(venue, key):
    """The model this venue uses for `key`: its own, or the shared one."""
    return OWN.get(venue, {}).get(key) or RETIRED.get(venue, {}).get(key, key)
