import os
import re
import shutil
import sys

text = open(sys.argv[1], encoding="utf-8-sig", errors="ignore").read()
labels = [m.group(2).strip() for m in re.finditer(r"picture (\d+) (.+?) ->", text)]
files = [f + ".png" for f in re.findall(r"\d\d:\d\d:\d\d \d+ (\S+captures\\wob-\d+)", text)]
print(len(labels), len(files))
want = {"reason_requiem rewind": "b2_requiem_rewind.png", "reason_requiem what": "b2_requiem_what.png",
        "reason_blackwall burst": "b2_blackwall.png", "reason_god boast": "b2_god.png",
        "reason_ironman burnt": "b2_ironman.png", "reason_sam zan": "b2_sam_zan.png", "reason_sam cuts": "b2_sam_cuts.png",
        "reason_walrider swarm": "b2_walrider.png", "reason_sans slash": "b2_sans.png", "reason_patriot shot": "b2_patriot.png",
        "patriot_grave stone": "b2_grave_stone.png", "patriot_grave wide": "b2_grave_wide.png"}
for label, path in zip(labels, files):
    if label in want:
        shutil.copy(path, os.path.join(sys.argv[2], want[label]))
        print("copied", label)
