"""blender -b --factory-startup --python art/scripts/run_textures.py [-- --only Tokyo,Campus]"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import textures  # noqa: E402

# "-- --only Tokyo,Campus" writes just those groups (the rest of the textures stay as they are).
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if "--only" in argv:
    paths = textures.build_only(argv[argv.index("--only") + 1].split(","))
else:
    paths = textures.build()
for path in paths:
    print("[textures]", path)
