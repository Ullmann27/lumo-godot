"""Create original mobile PBR lantern/chest meshes and editable studio source.

Blender 4.3: blender --background --threads 4 --python tools/create_creative_objects.py
UVs, texture and meshes are authored locally; no external assets or provider jobs.
"""
import json
import math
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/creative/models"
SOURCE = ROOT / "docs/design/2026-10-12-creative-objects/source"
ASSETS.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, metallic=0, roughness=.4, glow=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    if glow:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = .65
    return m


wood = mat('Original warm wood', (.3, .15, .08), roughness=.65)
gold = mat('Brushed brass', (.84, .52, .15), .7, .3)
teal = mat('Deep teal enamel', (.025, .11, .16), .3, .25)
glass = mat('Warm luminous glass', (1, .64, .2), .05, .24, True)
grain = bpy.data.images.new('Locally authored wood grain', 128, 128)
pixels = []
for y in range(128):
    for x in range(128):
        stripe = math.sin(x * .26 + math.sin(y * .047) * .55) * .045
        pixels.extend([.28 + stripe, .13 + stripe * .6, .055 + stripe * .28, 1])
grain.pixels = pixels
grain.filepath_raw = str(SOURCE / 'wood_grain.png')
grain.file_format = 'PNG'
grain.save()
grain.pack()
tex = wood.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = grain
wood.node_tree.links.new(tex.outputs['Color'],
                         wood.node_tree.nodes['Principled BSDF'].inputs['Base Color'])


def cube(name, at, size, material, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    modifier = obj.modifiers.new('Soft edges', 'BEVEL')
    modifier.width = bevel
    modifier.segments = 2
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return obj


def cylinder(name, at, radius, height, material, top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=radius,
        radius2=radius if top is None else top, depth=height, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def export(name, pieces):
    bpy.ops.object.select_all(action='DESELECT')
    for piece in pieces:
        piece.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    # Set the local origin at ground level before export; game colliders stay unchanged.
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=str(ASSETS / f'{name}.glb'), export_format='GLB',
        use_selection=True, export_yup=True, export_animations=False)
    obj.hide_set(True)
    return {'file': f'{name}.glb', 'vertices': len(obj.data.vertices),
        'triangles': sum(len(p.vertices) - 2 for p in obj.data.polygons),
        'materials': len(set(obj.data.materials)), 'uv_layers': len(obj.data.uv_layers)}


parts = [cylinder('Foot', (0, 0, .1), .22, .2, teal),
    cylinder('Brass foot ring', (0, 0, .18), .235, .045, gold),
    cylinder('Post', (0, 0, .88), .07, 1.4, teal),
    cube('Glass', (0, 0, 1.72), (.36, .36, .4), glass),
    cube('Lamp base', (0, 0, 1.5), (.48, .48, .07), gold),
    cylinder('Roof', (0, 0, 1.98), .33, .2, teal, .08)]
for x in [-.21, .21]:
    for y in [-.21, .21]:
        parts.append(cylinder('Corner frame', (x, y, 1.74), .025, .5, gold))
models = [export('lumo_lantern', parts)]
parts = [cube('Chest body', (0, 0, .5), (2.4, 1.3, 1), wood, .1)]
# Convex sloped lid, individual planks and bands; solid on mobile GL.
for i in range(5):
    y = (i - 2) * .25
    height = 1.10 + .21 * math.cos((i - 2) * .47)
    parts.append(cube('Curved lid plank', (0, y, height), (2.4, .24, .16), wood, .06))
for x in [-.85, .85]:
    for i in range(5):
        y = (i - 2) * .25
        height = 1.195 + .21 * math.cos((i - 2) * .47)
        parts.append(cube('Lid band', (x, y, height), (.14, .255, .06), gold, .02))
    for y in [-.665, .665]:
        parts.append(cube('Body band', (x, y, .5), (.14, .06, .96), gold, .02))
parts.append(cube('Brass lock', (0, -.705, .73), (.33, .09, .38), gold, .05))
parts.append(cube('Keyhole', (0, -.757, .73), (.07, .018, .16), teal, .014))
models.append(export('lumo_treasure_chest', parts))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'Lumo-Creative-Objects.blend'))
(SOURCE / 'MANIFEST.json').write_text(json.dumps({'author': 'Lumo project / Ullmann27',
    'source': 'Original local Blender meshes, UVs and wood texture',
    'license': 'Project-owned; no third-party assets', 'models': models,
    'runtime': 'Actual Godot GLB geometry, existing game rules/colliders preserved'}, indent=2) + '\n')
