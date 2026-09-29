"""Review sheets: each group of props rendered in a row beside a player-sized figure, with a red
arrow on the floor in front of each (the way its front faces, -Y), seen from the front three-
quarter and from behind. The sheets are how a new or rebuilt prop gets approved before a map
uses it:

    blender -b --factory-startup --python art/scripts/run_props.py -- --sheet street

writes art/export/previews/sheet_street.png: close-ups of a few props at a time, front on the left
and back on the right (building the group's props first; add --no-build to render what
Props.blend already holds)."""

import math
import os

import bpy
from mathutils import Vector

import common
import modelkit as mk
from common import srgb

GROUPS = {
    "street": ["StreetLightTokyo", "TrafficSignal", "PedestrianSignal", "UtilityPole", "RoadSign", "GuardRail",
               "Bollard", "PostBox", "RecycleBins", "Bicycle", "BikeRack", "Scooter", "Planter", "VendingBlue",
               "VendingWhite"],
    "barriers": ["SiteFence", "PoliceTape", "Barricade", "TrafficCone", "PoliceCar"],
    "vehicles": ["Bus", "Taxi", "KeiTruck", "TrainHead", "TrainMiddle"],
    "transit": ["BusShelter", "BusStopSign", "TaxiRankSign", "TicketGate", "TicketMachine", "StationSignHanging",
                "PlatformBench", "CoinLockers", "StationClock"],
    "shops": ["StoreShelf", "DrinkFridge", "ShopCounter", "BarStool", "RamenCounter", "MealTicketMachine",
              "ClawMachine", "ArcadeCabinet", "Washer", "DryerStack", "DisplayCase", "ClothesRack", "Mannequin",
              "CosmeticsCounter", "FittingRoom"],
    "yokocho": ["Chochin", "LanternString", "Noren", "BeerCrates", "YakitoriGrill", "Boat"],
    "trees": ["TreeSakura", "TreeZelkova", "PetalScatter"],
    "stations": ["StationCCTV", "StationReception", "StationPhoneBooth", "StationPrintKit", "StationLabBench"],
    "agency_stations": ["StationCRTBank", "StationPhoneDesk", "StationReelToReel", "ElevatorDoors", "MetalDetector",
                        "XRayScanner"],
    "agency_rooms": ["InterrogationTable", "ArchiveShelving", "EvidenceCage", "ExecutiveDesk", "FumeHood",
                     "MicrofilmReader"],
    "agency_office": ["WaterCooler", "Photocopier", "FaxMachine", "DeskPhone", "CoffeeMachine", "CoatStand",
                      "PinBoard", "Whiteboard"],
    "campus_stations": ["StationCameraPost", "StationPublicPhone", "StationNewsDesk", "StationBookReturn",
                        "StationVault", "StationAutopsy"],
    "campus_grounds": ["GinkgoBare", "PineYukizuri", "ShrubSnow", "StoneLantern", "Snowman", "SnowTools",
                       "CampusLamp", "NoticeBoard", "Tatekan", "BustStatue", "UmpireChair", "TennisNet"],
    "campus_exam": ["EventTent", "KeroseneHeater", "ExamDesk", "Lectern", "ExamSignStand", "QueuePosts"],
    "campus_rooms": ["ReadingTable", "CardCatalog", "BookCart", "SkeletonModel", "SpecimenShelf", "Microscope",
                     "Kotatsu", "ShoeLockers", "DrumKit", "UprightPiano", "FilmProjector", "Typewriter",
                     "TrayReturn", "UmbrellaStand"],
    "lobby_realm": ["DeadTree", "DeadTreeGnarled", "WitheredAppleTree", "GiantSkull", "BoneThrone"],
    "lobby_things": ["PracticeAltar", "Effigy", "BoneBrazier", "LanternPost", "CandleCluster", "SkullPile",
                     "BoneScatter", "Cairn", "DiceGame", "BoneStool"],
    "meeting_room": ["WarTable", "WarChair", "Sideboard", "BookcaseTall", "SpeakerColumn", "FloorGlobe"],
    "meeting_things": ["ClubChair", "DrinksTrolley", "Radiator", "WallClock", "CaseFiles", "FloorLamp", "BankerLamp"],
}

GAP = 3.0
FIGURE = [  # (centre, size) in Blender space: an R15-sized body 5.2 tall, facing -Y
    ((-0.5, 0, 1.0), (0.9, 0.9, 2.0)), ((0.5, 0, 1.0), (0.9, 0.9, 2.0)), ((0, 0, 3.0), (2.0, 1.0, 2.0)),
    ((-1.45, 0, 3.0), (0.8, 0.8, 2.0)), ((1.45, 0, 3.0), (0.8, 0.8, 2.0)), ((0, 0, 4.6), (1.2, 1.2, 1.2)),
]


def _parts_of(key):
    return [o for o in bpy.data.objects if o.type == "MESH" and (o.name == key or o.name.startswith(key + "_Glow"))]


def _label(text, loc, mat):
    curve = bpy.data.curves.new("SheetLabel", "FONT")
    curve.body = text
    curve.size = 0.9
    curve.align_x = "CENTER"
    curve.materials.append(mat)
    obj = bpy.data.objects.new("SheetLabel", curve)
    obj.location = loc
    bpy.context.scene.collection.objects.link(obj)
    return obj


CHUNK = 34.0  # studs of props per close-up


def _shot(tag, keys, made_all):
    """Renders one close-up of keys beside the figure, from the front and from behind."""
    scene = bpy.context.scene
    made, moved = [], []
    grey = mk.flat("Sheet_Grey", srgb(150, 150, 156), 0.6)
    floor_mat = mk.flat("Sheet_Floor", srgb(46, 46, 50), 0.9)
    red = mk.emissive("Sheet_Red", srgb(230, 30, 40), 3)
    ink = mk.emissive("Sheet_Ink", srgb(240, 240, 236), 2)
    for centre, size in FIGURE:
        part = mk.box("SheetFigure", size, centre, mat=grey)
        part.location.x += 1.5
        made.append(part)
    x = 3 + GAP
    tallest, deepest = 5.2, 2.0
    for key in keys:
        main = bpy.data.objects.get(key)
        if not main:
            continue
        w, d, h = mk.dimensions(main)
        lift = h / 2 if main.get("pivot") == "centre" else 0.0
        for obj in _parts_of(key):
            moved.append((obj, obj.location.copy()))
            obj.location = Vector((x + w / 2, 0, lift)) + obj.location
            obj.hide_render = False
        made += [mk.box("SheetArrow", (0.3, 2.0, 0.08), (x + w / 2, -d / 2 - 2.0, 0.05), mat=red),
                 mk.box("SheetArrowHead", (1.0, 0.4, 0.08), (x + w / 2, -d / 2 - 3.1, 0.05), mat=red),
                 _label(key, (x + w / 2, -d / 2 - 4.6, 0.06), ink)]
        tallest, deepest = max(tallest, h + lift), max(deepest, d)
        x += w + GAP
    width = x
    made.append(mk.box("SheetFloor", (width + 40, deepest + 40, 0.2), (width / 2, 0, -0.11), mat=floor_mat))
    target = Vector((width / 2, 0, tallest * 0.45))
    span = max(width * 0.55 + 2, tallest * 1.1)
    distance = span / math.tan(math.radians(24))
    cam = scene.camera
    paths = []
    for side, sign in (("front", -1), ("back", 1)):
        cam.location = target + Vector((distance * 0.2 * -sign, sign * distance, distance * 0.22))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(common.PREVIEWS, f"_sheet_{tag}_{side}.png")
        common.render(path)
        paths.append(path)
    for obj, loc in moved:
        obj.location = loc
        obj.hide_render = True
    for obj in made:
        bpy.data.objects.remove(obj, do_unlink=True)
    return paths


def _compose(rows, path):
    """Stacks rows of [front, back] images into one PNG."""
    import numpy as np

    blocks = []
    for pair in rows:
        imgs = []
        for p in pair:
            img = bpy.data.images.load(p)
            w, h = img.size
            imgs.append(np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4))
            bpy.data.images.remove(img)
        blocks.append(np.concatenate(imgs, axis=1))
    sheet = np.concatenate(list(reversed(blocks)), axis=0)  # Blender images are bottom-up
    h, w = sheet.shape[:2]
    out = bpy.data.images.new("SheetOut", w, h, alpha=True)
    out.pixels = sheet.ravel()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    return path


def render(name, keys):
    """Renders the sheet for `keys` (those that exist) in close-ups of about CHUNK studs, each
    from the front and from behind, stacked into previews/sheet_<name>.png."""
    scene = bpy.context.scene
    hidden = []
    for obj in bpy.data.objects:
        if obj.type == "MESH" and not obj.hide_render:
            obj.hide_render = True
            hidden.append(obj)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1100, 620
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.3, 0.31, 0.34, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
    sun_data = bpy.data.lights.get("SheetSun") or bpy.data.lights.new("SheetSun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("SheetSun", sun_data)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    cam_data = bpy.data.cameras.get("SheetCam") or bpy.data.cameras.new("SheetCam")
    cam_data.lens = 35
    cam = bpy.data.objects.new("SheetCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    chunks, current, width = [], [], 0.0
    for key in keys:
        main = bpy.data.objects.get(key)
        if not main:
            continue
        w = mk.dimensions(main)[0] + GAP
        if current and width + w > CHUNK:
            chunks.append(current)
            current, width = [], 0.0
        current.append(key)
        width += w
    if current:
        chunks.append(current)
    rows = [_shot(f"{name}{i}", chunk, None) for i, chunk in enumerate(chunks)]
    path = _compose(rows, os.path.join(common.PREVIEWS, f"sheet_{name}.png"))
    for pair in rows:
        for p in pair:
            os.remove(p)
    bpy.data.objects.remove(sun, do_unlink=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    for obj in hidden:
        obj.hide_render = False
    return path
