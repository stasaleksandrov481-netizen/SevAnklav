"""Bake wall-section IDs in plan space, without changing wall geometry.

CSG cap triangles can cross several corners. A triangle/vertex ID makes half a
cap remain opaque when its wall fades. A nearest-section map labels every
fragment consistently, including long cap triangles and their vertical sides.
Only this authoring tool needs numpy/Pillow; the game loads the baked PNG.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

BASE = Path(__file__).resolve().parents[2] / "iso/maps/level2"
SIZE = (1024, 512)


def bake():
    sections = json.loads((BASE / "wall_sections.json").read_text())["sections"]
    x = (np.arange(SIZE[0], dtype=np.float32) + .5) * 70 / SIZE[0] - 35
    z = (np.arange(SIZE[1], dtype=np.float32) + .5) * 30 / SIZE[1] - 15
    xx, zz = np.meshgrid(x, z)
    distance = np.full(xx.shape, np.inf, dtype=np.float32)
    ids = np.zeros(xx.shape, dtype=np.uint16)
    for index, spec in enumerate(sections):
        ax, az = spec["a"]
        bx, bz = spec["b"]
        dx, dz = bx - ax, bz - az
        t = np.clip(((xx - ax) * dx + (zz - az) * dz) / (dx * dx + dz * dz), 0, 1)
        d = (xx - ax - t * dx) ** 2 + (zz - az - t * dz) ** 2
        update = d < distance
        distance[update] = d[update]
        ids[update] = index + 1
    rgba = np.zeros((*ids.shape, 4), dtype=np.uint8)
    rgba[:, :, 0] = ids // 256
    rgba[:, :, 1] = ids % 256
    rgba[:, :, 3] = 255
    path = BASE / "wall_section_ids.png"
    Image.fromarray(rgba).save(path)
    print(f"BAKED {path.name}: {len(sections)} sections, {SIZE[0]}x{SIZE[1]}, IDs {ids.min()}..{ids.max()}")


if __name__ == "__main__":
    bake()
