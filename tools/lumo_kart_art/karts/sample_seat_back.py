#!/usr/bin/env python3
"""Measure the forward-most real seat-shell surface behind a seated driver."""
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_mechanics import evaluated_surface

source = ROOT / 'art/lumo_kart/blender/karts/aurora_comet.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
surface, _ = evaluated_surface([bpy.data.objects['BucketSeatShell']])
samples = []
for x in (0, .05, .10, .15, .20, .25):
    for y in (.775, .80, .825, .85, .875, .90, .925, .95, .975, 1, 1.025, 1.05, 1.075, 1.10, 1.115, 1.125):
        location, normal, index, distance = surface.ray_cast(Vector((x, .7, y)), Vector((0, -1, 0)), 2)
        samples.append({'godot_x': x, 'godot_y': y,
                        'first_shell_z': -location.y if location is not None else None})
result = {'source': str(source.relative_to(ROOT)),
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'method': 'Ray cast through evaluated BucketSeatShell triangles from Godot Z=-.7 in +Z direction. Values describe the nearest actual shell boundary at each (X,Y); they are not a free-space certificate for other parts.',
          'samples': samples}
output = ROOT / 'evidence/lumo_kart_art/karts/seat_front_profile.json'
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
