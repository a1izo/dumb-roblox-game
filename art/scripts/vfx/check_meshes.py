"""Checks the VFX kit's meshes (art/scripts/vfx/meshes.py) and draws them: builds every shape in a blank scene (the
export is NOT run, nothing is written but pictures), prints one line per shape, and renders each with a UV test
picture so the way u and v flow can be seen.

    blender -b --factory-startup --python art/scripts/vfx/check_meshes.py -- [--no-render] [--scratch DIR] [--sheet PNG]

Per shape it prints: triangles (the importer refuses 20,000), UV range (every UV must be inside 0..1), the u and v
spans, whether the seam is closed (the first and last column share their vertices' places), the seam stretch (the
texture density of the faces on the seam against the median of their own row; 1.00 is none), faces with no area in
space or in the picture, and the worst corner-normal against its face normal (a note, not a test). Exit code 1 when
anything fails.

The test picture: u is the HUE (it goes once round the wheel, so a good seam shows no jump), v is the BRIGHTNESS (dark
at v 0, bright at v 1), and a 16 x 16 checker over both shows any stretch. On a shape u runs round it as a rainbow and
v climbs from dark to bright; a shape with the rainbow running up it, or the bright end at its foot, has the rule the
wrong way round. Views: A and B from two sides, C square on to the +X seam.
"""

import colorsys
import math
import os
import struct
import sys
import tempfile
import zlib

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import meshes  # noqa: E402  (importing it builds nothing and exports nothing)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
DEFAULT_SHEET = os.path.join(ROOT, "art", "export", "previews", "vfx", "after", "meshes_uv_sheet.png")

# What each shape is, by the builder's name: wrapped = its u goes once round (the first and last column meet);
# stretch = the seam-density test applies (a lattice with rows); view = (elevation of the camera in degrees).
INFO = {
    "ring": dict(wrapped=True, stretch=True, elev=62),
    "dome": dict(wrapped=True, stretch=True, elev=28),
    "tube": dict(wrapped=True, stretch=True, elev=22),
    "cone": dict(wrapped=True, stretch=True, elev=22),
    "swirl": dict(wrapped=False, stretch=False, elev=22),
    "crescent": dict(wrapped=False, stretch=False, elev=62),
    "sphere": dict(wrapped=True, stretch=True, elev=22),
    "spike_ball": dict(wrapped=True, stretch=False, elev=22),
    "shard": dict(wrapped=True, stretch=False, elev=15),
    "rock": dict(wrapped=True, stretch=False, elev=22),
    "page": dict(wrapped=False, stretch=False, elev=15),
    "slash_arc": dict(wrapped=False, stretch=False, elev=55),
    "twister": dict(wrapped=True, stretch=True, elev=22),
    "shell": dict(wrapped=True, stretch=True, elev=22),
}
NEW = {"slash_arc", "twister", "shell"}
POLED = {"dome", "cone", "sphere", "twister", "shell"}  # (view C is from above, to show the pole)
TOL = 1e-6


def poly_area3(coords):
    a = np.zeros(3)
    for k in range(1, len(coords) - 1):
        a += np.cross(coords[k] - coords[0], coords[k + 1] - coords[0])
    return float(np.linalg.norm(a)) / 2.0


def poly_area2(uvs):
    s = 0.0
    for k in range(len(uvs)):
        x0, y0 = uvs[k]
        x1, y1 = uvs[(k + 1) % len(uvs)]
        s += x0 * y1 - x1 * y0
    return abs(s) / 2.0


def measure(name, obj):
    """The numbers for one shape; returns (row dict, list of failure strings)."""
    mesh = obj.data
    info = INFO[name]
    fails = []
    uv = mesh.uv_layers["UVMap"].data
    verts = np.array([v.co[:] for v in mesh.vertices])
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    alluv = np.array([l.uv[:] for l in uv])
    umin, vmin = alluv.min(axis=0)
    umax, vmax = alluv.max(axis=0)
    inside = bool((alluv >= -TOL).all() and (alluv <= 1 + TOL).all())
    if not inside:
        fails.append("UV outside 0..1")
    if tris >= 20000:
        fails.append("20,000 triangles or more")
    if umax - umin < 0.97 or vmax - vmin < 0.97:
        fails.append("u or v does not span 0..1")

    # faces: areas in space and in the picture, and their texture density
    rows = {}
    dens = {}
    degenerate = 0
    for p in mesh.polygons:
        coords = np.array([verts[i] for i in p.vertices])
        uvs = [tuple(uv[l].uv) for l in p.loop_indices]
        a3, a2 = poly_area3(coords), poly_area2(uvs)
        if a3 < 1e-9 or a2 < 1e-9:
            degenerate += 1
            continue
        d = a2 / a3
        key = round(sum(c[1] for c in uvs) / len(uvs), 4)
        # (a face on the seam column has a corner with u = 1)
        rows.setdefault(key, []).append(d)
        dens[p.index] = (key, d, max(c[0] for c in uvs) > 1 - TOL)
    if degenerate:
        fails.append("%d degenerate faces" % degenerate)

    # seam closed: the loops at u 0 and the loops at u 1 stand at the same places
    closed = "-"
    stretch = "-"
    if info["wrapped"]:
        def at(u):
            out = set()
            for p in mesh.polygons:
                for vi, l in zip(p.vertices, p.loop_indices):
                    c = uv[l].uv
                    if abs(c[0] - u) < TOL:
                        out.add(tuple(round(float(x), 4) for x in verts[vi]))
            return out
        a, b = at(0.0), at(1.0)
        closed = "yes" if a and a == b else "NO"
        if closed == "NO":
            fails.append("seam not closed")
    if info["stretch"]:
        worst = 1.0
        for key, d, on_seam in dens.values():
            if not on_seam:
                continue
            group = rows[key]
            if len(group) < 4:
                continue
            ratio = d / float(np.median(group))
            if abs(math.log(ratio)) > abs(math.log(worst)):
                worst = ratio
        stretch = "%.2f" % worst
        if not 0.6 <= worst <= 1.7:
            fails.append("seam stretch %.2f" % worst)

    # corner normals against their face's own normal (a note)
    worstn = 1.0
    try:
        cn = mesh.corner_normals
        for p in mesh.polygons:
            for l in p.loop_indices:
                worstn = min(worstn, float(np.dot(np.array(cn[l].vector), np.array(p.normal))))
    except Exception:
        worstn = float("nan")
    return dict(tris=tris, inside=inside, u=(umin, umax), v=(vmin, vmax), closed=closed, stretch=stretch,
                degenerate=degenerate, normal=worstn), fails


# ---- pictures ---------------------------------------------------------------------------------------------------

def uv_image(size=512):
    """The test picture, bottom row first (Blender's order): hue = u, brightness = v, a 16 x 16 checker over both."""
    img = np.zeros((size, size, 4), dtype=np.float32)
    for x in range(size):
        r, g, b = colorsys.hsv_to_rgb(x / size, 0.85, 1.0)
        img[:, x, 0], img[:, x, 1], img[:, x, 2] = r, g, b
    v = (np.arange(size, dtype=np.float32) / (size - 1))[:, None]
    light = 0.30 + 0.70 * v
    cell = size // 16
    ys, xs = np.mgrid[0:size, 0:size]
    checker = np.where(((ys // cell) + (xs // cell)) % 2 == 0, 1.0, 0.72).astype(np.float32)
    for c in range(3):
        img[:, :, c] *= light * checker
    img[:, :, 3] = 1.0
    image = bpy.data.images.new("vfx_uvcheck", size, size, alpha=False, float_buffer=False)
    image.pixels.foreach_set(img.ravel())
    image.pack()
    return image


def checker_material(image):
    mat = bpy.data.materials.new("vfx_uvcheck_mat")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Linear"
    links.new(tex.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    nodes.active = tex
    return mat


def setup_scene(size):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.display.render_aa = "8"
    scene.view_settings.view_transform = "Standard"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_backface_culling = False
    scene.display.shading.background_type = "WORLD"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.09, 0.09, 0.10)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def look(cam, loc, target):
    from mathutils import Vector
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def render_png(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(path, check_existing=False)
    image.colorspace_settings.name = "Non-Color"
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, :3]
    bpy.data.images.remove(image)
    return px  # bottom row first


def write_png(path, rgb_top_first):
    """A PNG from an (h, w, 3) uint8 array, top row first (no Blender colour handling in the way)."""
    h, w, _ = rgb_top_first.shape
    raw = b"".join(b"\x00" + rgb_top_first[y].tobytes() for y in range(h))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def label_strip(scene, cam, text, width, height, scratch):
    """A strip of white text on the scene's dark, as pixels (bottom row first)."""
    curve = bpy.data.curves.new("label", "FONT")
    curve.body = text
    curve.size = 0.5
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = bpy.data.objects.new("label", curve)
    scene.collection.objects.link(obj)
    obj.location = (0, 0, 0)
    old = (scene.render.resolution_x, scene.render.resolution_y, scene.display.shading.color_type)
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (1.0, 1.0, 1.0)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 16.0
    look(cam, (0, 0, 5), (0, 0, 0))
    px = render_png(scene, os.path.join(scratch, "label.png"))
    cam.data.type = "PERSP"
    scene.render.resolution_x, scene.render.resolution_y, scene.display.shading.color_type = old
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.curves.remove(curve)
    return px


def render_views(scene, cam, obj, elev, tile, poles=False):
    """Three views of one shape as one strip (tile x 3 tile), bottom row first."""
    from mathutils import Vector
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    centre = sum(corners, Vector()) / 8.0
    radius = max((c - centre).length for c in corners)
    cam.data.type = "PERSP"
    cam.data.lens = 50
    dist = radius * 3.0
    tiles = []
    for azimuth in (-50.0, 140.0, 0.0):
        # (the third view: square on to the +X seam, except that a shape with poles is seen from above, to show them)
        third = 82 if poles else min(elev, 12)
        el = math.radians(elev if azimuth != 0.0 else third)
        az = math.radians(azimuth)
        loc = (centre.x + dist * math.cos(el) * math.cos(az), centre.y + dist * math.cos(el) * math.sin(az),
               centre.z + dist * math.sin(el))
        look(cam, loc, centre)
        tiles.append(render_png(scene, os.path.join(tempfile.gettempdir(), "vfx_mesh_view.png")))
    return np.concatenate(tiles, axis=1)


def parse_args():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = dict(render=True, scratch=None, sheet=DEFAULT_SHEET)
    k = 0
    while k < len(args):
        if args[k] == "--no-render":
            out["render"] = False
        elif args[k] == "--scratch":
            k += 1
            out["scratch"] = args[k]
        elif args[k] == "--sheet":
            k += 1
            out["sheet"] = args[k]
        k += 1
    return out


def main():
    opts = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scratch = opts["scratch"] or tempfile.mkdtemp(prefix="vfx_meshes_")
    os.makedirs(scratch, exist_ok=True)
    tile = 224
    if opts["render"]:
        scene, cam = setup_scene(tile)
        image = uv_image()
        material = checker_material(image)
    failed = []
    cells = []
    print("%-12s %5s %-3s %-13s %-13s %-6s %-7s %-4s %s" % ("shape", "tris", "in", "u range", "v range", "seam",
                                                           "stretch", "deg", "worst normal"))
    for build in meshes.BUILDERS:
        name = build.__name__
        obj = build()
        row, fails = measure(name, obj)
        flag = "FAIL " + "; ".join(fails) if fails else "ok"
        print("%-12s %5d %-3s %5.3f-%-7.3f %5.3f-%-7.3f %-6s %-7s %-4d %5.2f   %s%s" % (
            obj.name, row["tris"], "yes" if row["inside"] else "NO", row["u"][0], row["u"][1], row["v"][0],
            row["v"][1], row["closed"], row["stretch"], row["degenerate"], row["normal"], flag,
            "  (new)" if name in NEW else ""))
        if fails:
            failed.append(obj.name)
        if opts["render"]:
            obj.data.materials.clear()
            obj.data.materials.append(material)
            strip = render_views(scene, cam, obj, INFO[name]["elev"], tile, name in POLED)
            text = "%s   %d tris   u %.0f-%.0f  v %.0f-%.0f" % (
                obj.name, row["tris"], row["u"][0], row["u"][1], row["v"][0], row["v"][1])
            obj.hide_render = True
            bpy.context.view_layer.update()
            label = label_strip(scene, cam, text, tile * 3, 30, scratch)
            full = np.concatenate([strip, label], axis=0)  # (the label sits above the pictures: bottom row first)
            write_png(os.path.join(scratch, obj.name + "_uv.png"),
                      (np.clip(full[::-1], 0, 1) * 255 + 0.5).astype(np.uint8))
            cells.append(full)
            bpy.data.objects.remove(obj, do_unlink=True)
    print("%d shapes, %d failed%s" % (len(meshes.BUILDERS), len(failed), (": " + ", ".join(failed)) if failed else ""))
    if opts["render"] and cells:
        cols = 3
        ch, cw = cells[0].shape[0], cells[0].shape[1]
        nrows = (len(cells) + cols - 1) // cols
        sheet = np.full((nrows * ch, cols * cw, 3), 0.09, dtype=np.float32)
        for k, cell in enumerate(cells):
            r, c = divmod(k, cols)
            y0 = (nrows - 1 - r) * ch  # (bottom row first)
            sheet[y0:y0 + ch, c * cw:(c + 1) * cw] = cell
        os.makedirs(os.path.dirname(opts["sheet"]), exist_ok=True)
        write_png(opts["sheet"], (np.clip(sheet[::-1], 0, 1) * 255 + 0.5).astype(np.uint8))
        print("sheet", opts["sheet"])
    sys.stdout.flush()
    if failed:
        sys.exit(1)


main()
