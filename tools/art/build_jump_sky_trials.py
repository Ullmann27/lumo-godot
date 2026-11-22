"""Build the three Wolkeninseln play props. Run with Blender -b -P this_file.py.

Each prop is one vertex-painted mesh with a single opaque material. All sizes
below are in Godot metres, X right, Y up, and negative Z down the course.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[2] / "assets/games/jump"
PALETTE = {
    "ink": "233a60", "brass": "f9b653", "shell": "ef7351", "ivory": "fff2bb",
    "teal": "168f9a", "aqua": "74efda", "berry": "813a70", "rose": "ff83ac",
}


def xyz(x, y, z):
    return Vector((x, -z, y))


def color(key):
    raw = bytes.fromhex(PALETTE[key])
    return tuple(((c / 255 + .055) / 1.055) ** 2.4 for c in raw) + (1,)


class PaintMesh:
    def __init__(self):
        self.points = []
        self.faces = []
        self.colors = []

    def solid(self, front, back, key):
        count = len(front)
        base = len(self.points)
        self.points += front + back
        faces = [list(reversed(range(count))), list(range(count, count * 2))]
        faces += [[i, (i + 1) % count, (i + 1) % count + count, count + i] for i in range(count)]
        self.faces.extend([[base + i for i in face] for face in faces])
        self.colors.extend([color(key)] * len(faces))

    def badge(self, outline, z, thick, key):
        self.solid([xyz(x, y, z) for x, y in outline],
                   [xyz(x, y, z + thick) for x, y in outline], key)

    def tile(self, outline, y, thick, key):
        self.solid([xyz(x, y, z) for x, z in outline],
                   [xyz(x, y + thick, z) for x, z in outline], key)

    def band(self, begin, end, inner, outer, z, thick, key):
        steps = max(2, round((end - begin) / 8))
        for i in range(steps):
            a, b = [math.radians(begin + (end - begin) * j / steps) for j in (i, i + 1)]
            self.badge([(r * math.cos(t), r * math.sin(t))
                        for t, r in [(a, inner), (a, outer), (b, outer), (b, inner)]], z, thick, key)

    def export(self, name):
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.points, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        attr = mesh.color_attributes.new(name="Paint", type='BYTE_COLOR', domain='CORNER')
        for face, rgba in zip(mesh.polygons, self.colors):
            for loop in face.loop_indices:
                attr.data[loop].color = rgba
        mat = bpy.data.materials.new(name + " Enamel")
        mat.use_nodes = True
        mat.use_backface_culling = False
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        node = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        node.layer_name = "Paint"
        mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = .55
        mesh.materials.append(mat)
        # Closed volumes may be drawn clockwise from different authoring planes.
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format='GLB',
                                  use_selection=True, export_yup=True, export_cameras=False)


def sun_ring():
    prop = PaintMesh()
    prop.band(0, 360, 1.22, 1.40, -.10, .20, "ink")
    for i in range(12):
        prop.band(i * 30 + 1, (i + 1) * 30 - 1, 1.25, 1.39, .105, .055,
                  "ivory" if i % 3 == 1 else "brass")
    for sign in (-1, 1):
        for x, y, length in [(1.22, .17, .86), (1.27, -.06, .62), (1.30, -.27, .36)]:
            wing = [(x, y), (x + length, y + .22), (x + length - .15, y), (x + .05, y - .16)]
            prop.badge([(sign * a, b) for a, b in wing], -.07, .18, "shell")
    prop.badge([(0, 1.75), (.23, 1.37), (0, 1.17), (-.23, 1.37)], .10, .12, "brass")
    prop.badge([(0, 1.64), (.13, 1.38), (0, 1.26), (-.13, 1.38)], .225, .03, "aqua")
    prop.export("sun_ring")


def wind_pad():
    prop = PaintMesh()
    footprint = [(-.78, 1.03), (.78, 1.03), (1.03, .76), (1.03, -.65),
                 (.66, -.96), (0, -1.12), (-.66, -.96), (-1.03, -.65), (-1.03, .76)]
    prop.tile(footprint, 0, .09, "ink")
    prop.tile([(x * .93, z * .95) for x, z in footprint], .09, .05, "teal")
    for z in (-.48, .03, .54):
        prop.tile([(-.67, z + .19), (0, z - .09), (.67, z + .19),
                   (.67, z - .05), (0, z - .35), (-.67, z - .05)], .14, .022, "aqua")
    for x in (-.85, .85):
        prop.tile([(x - .035, .64), (x + .035, .64), (x + .035, -.58), (x - .035, -.58)],
                  .14, .018, "brass")
    prop.export("wind_pad")


def comet_bar():
    prop = PaintMesh()
    # A soft floating comet with alternating diagonal stripes like a jump rope.
    def profile(x, y, w, h):
        return [(x - w, y), (x - w + .13, y + h), (x + w - .13, y + h),
                (x + w, y), (x + w - .13, y - h), (x - w + .13, y - h)]
    prop.badge(profile(0, 0, 1.67, .13), -.10, .20, "berry")
    for i in range(-3, 4):
        x = i * .37
        prop.badge([(x - .12, -.11), (x + .025, .11), (x + .16, .11), (x + .015, -.11)],
                   .105, .018, "ivory")
    for sign in (-1, 1):
        x = sign * 1.68
        prop.badge([(x, .43), (x + .09, .13), (x + .35, 0), (x + .10, -.13),
                    (x, -.38), (x - .09, -.13), (x - .33, 0), (x - .09, .13)], -.12, .25, "rose")
        prop.badge([(x, .20), (x + .16, 0), (x, -.20), (x - .16, 0)], .135, .04, "brass")
    prop.export("comet_bar")


OUT.mkdir(parents=True, exist_ok=True)
sun_ring()
wind_pad()
comet_bar()
