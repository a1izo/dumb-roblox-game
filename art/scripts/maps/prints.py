"""Printed matter for the maps: posters and notices, drawn with real typefaces (art/source/fonts, Google
Fonts under the Open Font License; see art/scripts/sources.py) on photographed paper, and weathered.

What may be printed (the owner's rules, 2026-10-10): brands are invented, the Japanese says what it
means to say, no real trademark, no name from the source material, no photographed person or face
(people appear as flat shapes only), nothing about alcohol, tobacco or gambling, and nothing that
gives away what happens in a match. Next to everyday Tokyo there is a thin layer of the game's own
world: the Bureau's public notices.

One sheet per venue, art/export/textures/Prints<Venue>.png: 3 x 2 upright posters in the proportion
of a sheet of paper (1 : 1.414). SHEETS[venue] lists them in reading order from the top left; a map
puts poster n of its sheet on a wall with the material name(venue) and the UVs of cell(n).

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
COLS, ROWS = 3, 2
TALL = 1.414  # a poster is 1 wide and this high

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
CREAM = (244, 236, 214)
CAT = (34, 32, 34)

# A poster: its paper colour and what is printed on it, bottom up. Positions are in the poster's own
# units: 1 across, 1.414 up. ("box", x0, y0, x1, y1, colour), ("disc", x, y, radius, colour),
# ("tri", x0, y0, x1, y1, x2, y2, colour), ("text", words, face, size, x, y, colour) with the text
# centred on x and standing on y.
SHEETS = {
    "Tokyo": [
        # 0. A club night: "Live, Kagegaoka, Club Noir, 29 November. Doors at 19:00."
        dict(paper=(226, 188, 44), items=[
            ("box", 0.0, 1.1, 1.0, 1.414, INK),
            ("text", "LIVE", "loud", 0.26, 0.5, 1.16, (226, 188, 44)),
            ("text", "影ヶ丘", "round", 0.16, 0.5, 0.86, INK),
            ("text", "CLUB NOIR", "caps", 0.2, 0.5, 0.6, INK),
            ("box", 0.1, 0.52, 0.9, 0.535, INK),
            ("text", "11.29", "caps", 0.32, 0.5, 0.2, INK),
            ("text", "開場 19:00", "round", 0.075, 0.5, 0.07, INK),
        ]),
        # 1. A lost cat: "Lost cat. We are looking for him. A black tom. If you see him, the police box."
        dict(paper=(238, 232, 210), items=[
            ("text", "迷い猫", "brush", 0.24, 0.5, 1.12, INK),
            ("disc", 0.5, 0.6, 0.17, CAT), ("disc", 0.5, 0.83, 0.115, CAT),
            ("tri", 0.4, 0.86, 0.48, 0.93, 0.41, 1.0, CAT), ("tri", 0.6, 0.86, 0.52, 0.93, 0.59, 1.0, CAT),
            ("box", 0.36, 0.43, 0.72, 0.48, CAT), ("disc", 0.72, 0.455, 0.025, CAT),
            ("text", "さがしています", "round", 0.085, 0.5, 0.29, INK),
            ("text", "黒猫・オス", "round", 0.085, 0.5, 0.17, INK),
            ("text", "見かけたら交番まで", "round", 0.07, 0.5, 0.06, INK),
        ]),
        # 2. A gig: "Jazz, Moonlight Trio. Every Friday at 21:00."
        dict(paper=(120, 24, 30), items=[
            ("disc", 0.7, 1.06, 0.2, CREAM), ("disc", 0.62, 1.1, 0.17, (120, 24, 30)),
            ("text", "JAZZ", "caps", 0.38, 0.5, 0.6, CREAM),
            ("text", "MOONLIGHT", "caps", 0.17, 0.5, 0.41, CREAM),
            ("text", "TRIO", "caps", 0.17, 0.5, 0.23, CREAM),
            ("text", "毎週金曜 21:00", "round", 0.075, 0.5, 0.08, CREAM),
        ]),
        # 3. Akatsuki cram school: "Winter course: enrolling now. Three minutes from the north exit."
        dict(paper=(236, 232, 222), items=[
            ("box", 0.0, 1.04, 1.0, 1.414, (30, 60, 122)),
            ("text", "進学塾", "round", 0.1, 0.5, 1.27, (236, 232, 222)),
            ("text", "あかつき", "loud", 0.17, 0.5, 1.08, (250, 208, 70)),
            ("text", "冬期講習", "brush", 0.2, 0.5, 0.74, INK),
            ("text", "受付中", "brush", 0.26, 0.5, 0.42, (30, 60, 122)),
            ("box", 0.12, 0.32, 0.88, 0.335, INK),
            ("text", "影ヶ丘駅 北口 徒歩3分", "round", 0.07, 0.5, 0.14, INK),
        ]),
        # 4. The Bureau's advisory: "From the Bureau. Take care when out late at night."
        dict(paper=(228, 228, 224), items=[
            ("box", 0.0, 1.2, 1.0, 1.414, (36, 38, 46)),
            ("text", "捜査局より", "round", 0.1, 0.5, 1.26, (228, 228, 224)),
            ("text", "深夜の", "brush", 0.17, 0.5, 0.96, INK),
            ("text", "外出に", "brush", 0.17, 0.5, 0.75, INK),
            ("text", "ご注意", "brush", 0.22, 0.5, 0.47, INK),
            ("box", 0.1, 0.36, 0.9, 0.375, INK),
            ("text", "不審なことは交番へ", "round", 0.07, 0.5, 0.18, INK),
        ]),
        # 5. A shop to let: "Shop to let. Ground floor, shop or office. Kage Estates. Ask inside."
        dict(paper=(240, 236, 224), items=[
            ("box", 0.0, 1.08, 1.0, 1.414, (28, 82, 76)),
            ("text", "貸店舗", "loud", 0.22, 0.5, 1.16, CREAM),
            ("text", "FOR RENT", "caps", 0.2, 0.5, 0.78, INK),
            ("box", 0.12, 0.7, 0.88, 0.715, INK),
            ("text", "1階 店舗・事務所", "round", 0.08, 0.5, 0.52, INK),
            ("text", "かげ不動産", "round", 0.1, 0.5, 0.3, INK),
            ("text", "お問い合わせは店頭まで", "round", 0.06, 0.5, 0.1, INK),
        ]),
    ],
}


def name(venue):
    """The map material a venue's sheet is (matlib.SHEETS)."""
    return "Prints" + venue


def cell(index):
    """(u0, v0, u1, v1) of poster `index` on its sheet."""
    col, row = index % COLS, index // COLS
    y0 = (ROWS - 1 - row) * TALL
    return col / COLS, y0 / COLS, (col + 1) / COLS, (y0 + TALL) / COLS


def _flat(rgb):
    """A material that shows one colour exactly as given (it gives off its own light)."""
    key = "Print_%d_%d_%d" % rgb
    mat = bpy.data.materials.get(key)
    if mat:
        return mat
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    glow = nodes.new("ShaderNodeEmission")
    glow.inputs["Color"].default_value = (*common.srgb(*rgb), 1)
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(glow.outputs["Emission"], out.inputs["Surface"])
    return mat


def _font(face):
    folder, file = FACES[face]
    return bpy.data.fonts.load(os.path.join(FONTS, folder, file), check_existing=True)


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
    paper = scanlib.load("Paper003", 256)
    grain = paper["color"] @ scanlib.LUMA
    grain = np.tile(grain / float(grain.mean()), (4, 4))[:SIZE, :SIZE]
    out = scanlib.to_linear(sheet) * np.power(grain, 0.8)[..., None]
    up = np.mgrid[0:SIZE, 0:SIZE][0] / SIZE * COLS  # height on the sheet, in poster widths
    foot = (up % TALL) / TALL  # 0 at each poster's foot
    grime = (1 - scanlib.smoothstep(0.0, 0.22, foot)) * (0.25 + 0.5 * scanlib.drift(r, SIZE, 2, 12))
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
        ox, oy = i % COLS, (ROWS - 1 - i // COLS) * TALL
        _quad(coll, ox, oy, ox + 1, oy + TALL, 0.0, poster.get("paper", PAPER))
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
    cam.location = (COLS / 2, COLS / 2, 10)  # the sheet is square: COLS wide, COLS high, posters from the foot
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
