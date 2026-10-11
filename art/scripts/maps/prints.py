"""Printed matter for the maps: posters and notices, drawn with real typefaces (art/source/fonts, Google
Fonts under the Open Font License; see art/scripts/sources.py) on photographed paper, and weathered.

What may be printed (the owner's rules, 2026-10-10): brands are invented, the Japanese says what it
means to say, no real trademark, no name from the source material, no photographed person or face
(people appear as flat shapes only), nothing about alcohol, tobacco or gambling, and nothing that
gives away what happens in a match. Next to everyday Tokyo there is a thin layer of the game's own
world: the Bureau's public notices, memorial notices, a late-night advisory.

One sheet per venue, art/export/textures/Prints<Venue>.png: 4 x 2 portrait posters, each a quarter of
the sheet wide and half of it high. SHEETS[venue] lists them in reading order from the top left.

    blender -b --factory-startup --python art/scripts/maps/prints.py [-- Tokyo]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402
from maps import scanlib  # noqa: E402

FONTS = common.source("fonts")
SIZE = 1024
COLS, ROWS = 4, 2

FACES = {
    "loud": ("delagothicone", "DelaGothicOne-Regular.ttf"),
    "round": ("zenmarugothic", "ZenMaruGothic-Bold.ttf"),
    "pop": ("rocknrollone", "RocknRollOne-Regular.ttf"),
    "brush": ("yujisyuku", "YujiSyuku-Regular.ttf"),
    "caps": ("bebasneue", "BebasNeue-Regular.ttf"),  # Latin capitals and figures only
}
# (Noto Sans JP, Noto Serif JP and Oswald are variable fonts, which Blender loads at their lightest
# weight only; they wait in art/source/fonts until that can be chosen.)

INK = (26, 26, 30)
PAPER = (232, 228, 216)

# A poster: its paper colour and what is printed on it, bottom up. Positions are in the poster's own
# units: 1 across, 2 up. ("box", x0, y0, x1, y1, colour), ("disc", x, y, radius, colour),
# ("tri", x0, y0, x1, y1, x2, y2, colour), ("text", words, face, size, x, y, colour) with the text
# centred on x and standing on y.
SHEETS = {
    "Tokyo": [
        # Green tea in a bottle: "Midori. Clean, in one sip."
        dict(paper=(214, 226, 204), items=[
            ("box", 0.0, 0.0, 1.0, 0.5, (58, 104, 70)),
            ("box", 0.42, 0.62, 0.58, 1.32, (70, 122, 78)), ("box", 0.46, 1.32, 0.54, 1.44, (236, 236, 228)),
            ("text", "みどり", "round", 0.26, 0.5, 1.58, (40, 84, 54)),
            ("text", "緑茶", "brush", 0.2, 0.5, 0.2, (236, 236, 224)),
            ("text", "すっきり、ひとくち。", "round", 0.085, 0.5, 0.07, (236, 236, 224)),
        ]),
        # Karaoke Hibiki: "30 minutes 180 yen. Open 24 hours."
        dict(paper=(40, 32, 62), items=[
            ("disc", 0.5, 1.3, 0.34, (224, 86, 152)), ("disc", 0.5, 1.3, 0.24, (40, 32, 62)),
            ("text", "カラオケ", "pop", 0.2, 0.5, 1.72, (250, 226, 110)),
            ("text", "ひびき", "loud", 0.26, 0.5, 0.62, (244, 240, 250)),
            ("text", "30分 ¥180", "round", 0.2, 0.5, 0.34, (250, 226, 110)),
            ("text", "24時間営業", "round", 0.1, 0.5, 0.14, (224, 86, 152)),
        ]),
        # Akatsuki cram school: "Winter course: enrolling now."
        dict(paper=(236, 232, 222), items=[
            ("box", 0.0, 1.5, 1.0, 2.0, (30, 60, 122)),
            ("text", "進学塾", "round", 0.12, 0.5, 1.8, (236, 232, 222)),
            ("text", "あかつき", "loud", 0.2, 0.5, 1.54, (250, 208, 70)),
            ("text", "冬期講習", "brush", 0.22, 0.5, 1.02, INK),
            ("text", "受付中", "brush", 0.3, 0.5, 0.62, (176, 42, 40)),
            ("box", 0.12, 0.42, 0.88, 0.44, INK),
            ("text", "影ヶ丘駅 北口 徒歩3分", "round", 0.08, 0.5, 0.22, INK),
        ]),
        # Kagegaoka dental clinic: "Weekdays 9:00 to 19:00."
        dict(paper=(226, 236, 238), items=[
            ("disc", 0.5, 1.36, 0.3, (90, 170, 190)), ("disc", 0.5, 1.36, 0.2, (226, 236, 238)),
            ("text", "影ヶ丘", "round", 0.16, 0.5, 0.8, (40, 90, 110)),
            ("text", "歯科", "round", 0.32, 0.5, 0.42, (40, 90, 110)),
            ("text", "平日 9:00–19:00", "round", 0.1, 0.5, 0.2, (40, 90, 110)),
        ]),
        # A room to let: "1K, five minutes on foot, 62,000 yen a month."
        dict(paper=(240, 236, 224), items=[
            ("box", 0.0, 1.62, 1.0, 2.0, (196, 60, 44)),
            ("text", "賃貸", "loud", 0.26, 0.5, 1.68, (240, 236, 224)),
            ("box", 0.14, 0.86, 0.86, 1.5, (222, 216, 200)), ("box", 0.14, 1.16, 0.5, 1.5, (206, 198, 180)),
            ("text", "1K", "caps", 0.2, 0.68, 1.22, INK),
            ("text", "徒歩5分", "round", 0.14, 0.5, 0.6, INK),
            ("text", "¥62,000", "round", 0.2, 0.5, 0.32, (196, 60, 44)),
            ("text", "かげ不動産", "round", 0.08, 0.5, 0.12, INK),
        ]),
        # A lost cat: "Looking for our cat. Her name is Mike."
        dict(paper=(238, 232, 210), items=[
            ("text", "迷い猫", "brush", 0.26, 0.5, 1.62, INK),
            ("disc", 0.5, 0.92, 0.26, (60, 56, 52)), ("disc", 0.5, 1.26, 0.17, (60, 56, 52)),
            ("tri", 0.35, 1.3, 0.47, 1.4, 0.37, 1.52, (60, 56, 52)), ("tri", 0.65, 1.3, 0.53, 1.4, 0.63, 1.52, (60, 56, 52)),
            ("box", 0.3, 0.64, 0.82, 0.72, (60, 56, 52)), ("disc", 0.82, 0.68, 0.04, (60, 56, 52)),
            ("text", "さがしています", "round", 0.1, 0.5, 0.42, INK),
            ("text", "名前:ミケ", "round", 0.1, 0.5, 0.26, INK),
            ("text", "見かけたら交番まで", "round", 0.085, 0.5, 0.1, INK),
        ]),
        # The Bureau's advisory: "Take care when out late at night."
        dict(paper=(228, 228, 224), items=[
            ("box", 0.0, 1.7, 1.0, 2.0, (36, 38, 46)),
            ("text", "捜査局より", "round", 0.12, 0.5, 1.8, (228, 228, 224)),
            ("text", "深夜の", "brush", 0.2, 0.5, 1.3, INK),
            ("text", "外出に", "brush", 0.2, 0.5, 1.04, INK),
            ("text", "ご注意", "brush", 0.26, 0.5, 0.7, INK),
            ("box", 0.1, 0.56, 0.9, 0.58, INK),
            ("text", "不審なことは交番へ", "round", 0.085, 0.5, 0.34, INK),
        ]),
        # A memorial notice: "In memory. A prayer for those we lost."
        dict(paper=(222, 220, 214), items=[
            ("box", 0.06, 0.06, 0.94, 1.94, (40, 40, 44)), ("box", 0.09, 0.09, 0.91, 1.91, (222, 220, 214)),
            ("text", "追悼", "brush", 0.34, 0.5, 1.26, INK),
            ("text", "失われた方々に", "brush", 0.11, 0.5, 0.8, INK),
            ("text", "祈りを", "brush", 0.14, 0.5, 0.56, INK),
            ("text", "影ヶ丘町内会", "round", 0.085, 0.5, 0.2, INK),
        ]),
    ],
}


def _flat(rgb):
    """A material that shows one colour exactly as given (it gives off its own light)."""
    name = "Print_%d_%d_%d" % rgb
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    glow = nodes.new("ShaderNodeEmission")
    glow.inputs["Color"].default_value = (*common.srgb(*rgb), 1)
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(glow.outputs["Emission"], out.inputs["Surface"])
    return mat


def _font(face):
    folder, name = FACES[face]
    return bpy.data.fonts.load(os.path.join(FONTS, folder, name), check_existing=True)


def _quad(coll, x0, y0, x1, y1, z, rgb):
    mesh = bpy.data.meshes.new("PrintBox")
    mesh.from_pydata([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [], [(0, 1, 2, 3)])
    mesh.materials.append(_flat(rgb))
    coll.objects.link(bpy.data.objects.new("PrintBox", mesh))


def _disc(coll, x, y, radius, z, rgb, sides=48):
    ring = [(x + radius * np.cos(a), y + radius * np.sin(a), z) for a in np.linspace(0, 2 * np.pi, sides, endpoint=False)]
    mesh = bpy.data.meshes.new("PrintDisc")
    mesh.from_pydata(ring, [], [tuple(range(sides))])
    mesh.materials.append(_flat(rgb))
    coll.objects.link(bpy.data.objects.new("PrintDisc", mesh))


def _tri(coll, points, z, rgb):
    mesh = bpy.data.meshes.new("PrintTri")
    mesh.from_pydata([(x, y, z) for x, y in points], [], [(0, 1, 2)])
    mesh.materials.append(_flat(rgb))
    coll.objects.link(bpy.data.objects.new("PrintTri", mesh))


def _text(coll, words, face, size, x, y, z, rgb):
    curve = bpy.data.curves.new("PrintText", "FONT")
    curve.body = words
    curve.font = _font(face)
    curve.size = size
    curve.align_x = "CENTER"
    curve.materials.append(_flat(rgb))
    obj = bpy.data.objects.new("PrintText", curve)
    obj.location = (x, y, z)
    coll.objects.link(obj)


def _weathered(sheet, seed):
    """The printed sheet as it hangs outside: on creased paper, bleached a little, grimy at the foot."""
    r = np.random.default_rng(seed)
    paper = scanlib.load("Paper003", SIZE // COLS)
    grain = paper["color"] @ scanlib.LUMA
    grain = np.tile(grain / float(grain.mean()), (ROWS * 2, COLS))[:SIZE, :SIZE]
    out = scanlib.to_linear(sheet) * np.power(grain, 0.8)[..., None]
    v = (np.mgrid[0:SIZE, 0:SIZE][0] % (SIZE // ROWS)) / (SIZE // ROWS)  # 0 at each poster's foot
    grime = (1 - scanlib.smoothstep(0.0, 0.22, v)) * (0.25 + 0.5 * scanlib.drift(r, SIZE, 2, 12))
    out = out * (1 - 0.45 * grime[..., None])
    grey = (out @ scanlib.LUMA)[..., None]
    out = grey + (out - grey) * 0.82  # the sun has had the colours
    out = out * 0.94 + 0.03
    return scanlib.to_srgb(out).astype(np.float32)


def make(venue):
    posters = SHEETS[venue]
    scene = bpy.data.scenes.new("Prints")
    coll = bpy.data.collections.new("Prints")
    scene.collection.children.link(coll)
    for i, poster in enumerate(posters):
        ox, oy = i % COLS, (ROWS - 1 - i // COLS) * 2.0
        _quad(coll, ox, oy, ox + 1, oy + 2, 0.0, poster.get("paper", PAPER))
        for layer, item in enumerate(poster["items"]):
            z = 0.001 * (layer + 1)
            if item[0] == "box":
                _, x0, y0, x1, y1, rgb = item
                _quad(coll, ox + x0, oy + y0, ox + x1, oy + y1, z, rgb)
            elif item[0] == "disc":
                _, x, y, radius, rgb = item
                _disc(coll, ox + x, oy + y, radius, z, rgb)
            elif item[0] == "tri":
                _, x0, y0, x1, y1, x2, y2, rgb = item
                _tri(coll, [(ox + x0, oy + y0), (ox + x1, oy + y1), (ox + x2, oy + y2)], z, rgb)
            else:
                _, words, face, size, x, y, rgb = item
                _text(coll, words, face, size, ox + x, oy + y, z, rgb)
    cam_data = bpy.data.cameras.new("PrintCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = float(COLS)
    cam = bpy.data.objects.new("PrintCam", cam_data)
    cam.location = (COLS / 2, ROWS, 10)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PrintWorld")
    raw = os.path.join(common.TEXTURES, f"Prints{venue}_raw.png")
    scene.render.filepath = raw
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True, scene=scene.name)
    img = bpy.data.images.load(raw, check_existing=False)
    buf = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    os.remove(raw)
    sheet = _weathered(buf.reshape(SIZE, SIZE, 4)[..., :3], seed=len(venue))
    rgba = np.concatenate([sheet, np.ones((SIZE, SIZE, 1), dtype=np.float32)], axis=-1)
    out = bpy.data.images.new(f"Prints{venue}", SIZE, SIZE, alpha=False)
    out.pixels.foreach_set(rgba.ravel())
    path = os.path.join(common.TEXTURES, f"Prints{venue}.png")
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    bpy.data.scenes.remove(scene)
    print("[prints]", venue, len(posters), "posters")
    return path


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for venue in argv or list(SHEETS):
        make(venue)
