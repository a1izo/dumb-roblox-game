"""Contact sheets of the harness's pictures, in the order they were taken (background Blender):
    blender -b --factory-startup --python pics_sheet.py -- <run log> <out dir> <per row>
The run log's "pictures since the start:" list gives the copies in order; the probe's "picture N label" lines name them."""

import os
import re
import sys

sys.path.insert(0, r"C:\Users\negru\Documents\Lgame\art\scripts")

import review_emote as rv  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
log, out, per_row = argv[0], argv[1], int(argv[2])
text = open(log, encoding="utf-8", errors="ignore").read()
labels = [m.group(2) for m in re.finditer(r"picture (\d+) (.+?) ->", text)]
files = [f + ".png" for f in re.findall(r"\d\d:\d\d:\d\d \d+ (\S+captures\\wob-\d+)", text)]
print(f"[sheet] {len(labels)} labels, {len(files)} files")
os.makedirs(out, exist_ok=True)
groups = {}
order = []
for i, path in enumerate(files):
    label = labels[i] if i < len(labels) else f"extra {i}"
    scene = label.split(" ")[0]
    if scene not in groups:
        groups[scene] = []
        order.append(scene)
    groups[scene].append(path)
stills, row_names = [], []
for scene in order:
    row = groups[scene][:per_row]
    while len(row) < per_row:
        row.append(row[-1])
    stills += row
    row_names.append(scene)
half = (len(order) + 1) // 2
for k, chunk in enumerate((order[:half], order[half:])):
    paths = []
    for scene in chunk:
        row = groups[scene][:per_row]
        while len(row) < per_row:
            row.append(row[-1])
        paths += row
    if paths:
        dest = os.path.join(out, f"pics_{k + 1}.png")
        rv.make_sheet(paths, dest, cols=per_row, tile=300, tall=169)
        print("[sheet]", dest, "rows:", ", ".join(chunk))
