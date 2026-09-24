"""blender -b --factory-startup --python art/scripts/run_textures.py"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import textures  # noqa: E402

for path in textures.build():
    print("[textures]", path)
