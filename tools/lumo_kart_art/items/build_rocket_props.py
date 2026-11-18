#!/usr/bin/env python3
"""Author the Lumo-Kart Sternraketen props in Blender: a fold-out rocket pod and the rocket.

Run: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/items/build_rocket_props.py
Writes assets/kart/items/models/{lumo_rocket_pod,lumo_star_rocket}.glb plus a JSON report.

Coordinates follow the Godot convention (metres, Y up, -Z forward), converted for Blender.
Each prop is ONE mesh with ONE material and per-corner vertex colours, so the game draws a
rocket or a pod in a single draw call (the runtime uses a shared vertex-colour material).
No textures, no downloaded geometry: original procedural shapes by the Lumo team.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy  # noqa: I001 - bpy must load before bmesh in the pip build
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/kart/items/models"
G_TO_B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

# Kid-friendly "Sternrakete": white body, coral nose, gold fins, cyan band, dark nozzle.
PALETTE = {
    "body": "f7f9ff", "nose": "ff4f6d", "band": "36d8ff", "fin": "ffc22e", "star": "fff1a8",
    "nozzle": "3a4256", "nozzle_hot": "ff9a3c", "rack": "273b6e", "rack_trim": "ffc22e",
    "rail": "aab8c8", "light": "5ff2ff", "hinge": "1b2438", "clamp": "e9eef8",
}


def srgb_to_linear(hex_color: str) -> tuple[float, float, float, float]:
    values = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values) + (1.0,)


class Builder:
    """Accumulates coloured primitives into one bmesh (Godot coordinates in, Blender out)."""

    def __init__(self) -> None:
        self.bm = bmesh.new()
        self.color = self.bm.loops.layers.color.new("Col")

    def _paint(self, faces, color: str) -> None:
        # The bmesh byte-colour layer takes display (sRGB) values directly.
        rgba = tuple(int(PALETTE[color][i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)
        for face in faces:
            face.smooth = True
            for loop in face.loops:
                loop[self.color] = rgba

    def revolve(self, profile, color: str, segments: int = 18, centre=(0.0, 0.0, 0.0), axis: str = "z") -> None:
        """Lathe a (along, radius) profile around the Godot Z (or X) axis."""
        rings = []
        for along, radius in profile:
            ring = []
            for s in range(segments):
                a = math.tau * s / segments
                if axis == "z":
                    p = (centre[0] + math.cos(a) * radius, centre[1] + math.sin(a) * radius, centre[2] + along)
                else:
                    p = (centre[0] + along, centre[1] + math.sin(a) * radius, centre[2] + math.cos(a) * radius)
                ring.append(self.bm.verts.new(G_TO_B @ Vector(p)))
            rings.append(ring)
        faces = []
        for i in range(len(rings) - 1):
            for s in range(segments):
                a, b = rings[i][s], rings[i][(s + 1) % segments]
                c, d = rings[i + 1][(s + 1) % segments], rings[i + 1][s]
                if a.co == d.co and b.co == c.co:
                    continue
                faces.append(self.bm.faces.new((a, b, c, d)))
        # Caps where the profile does not close on the axis.
        for ring, flip in ((rings[0], True), (rings[-1], False)):
            if (ring[0].co - ring[1].co).length > 1e-6:
                faces.append(self.bm.faces.new(list(reversed(ring)) if flip else ring))
        self._paint(faces, color)

    def box(self, centre, size, color: str, bevel: float = 0.0) -> None:
        geom = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = geom["verts"]
        for v in verts:
            local = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            v.co = G_TO_B @ (local + Vector(centre))
        faces = list({f for v in verts for f in v.link_faces})
        if bevel > 0.0:
            edges = list({e for f in faces for e in f.edges})
            result = bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=2, affect="EDGES", profile=0.5)
            faces = list(set(faces) | set(result.get("faces", [])))
            faces = [f for f in faces if f.is_valid]
        self._paint(faces, color)

    def fin(self, root, tip, back, thickness: float, color: str) -> None:
        """Thin swept fin: triangle root-front, tip, root-back extruded sideways."""
        a, b, c = Vector(root), Vector(tip), Vector(back)
        normal = (b - a).cross(c - a).normalized() * thickness * 0.5
        front = [self.bm.verts.new(G_TO_B @ (p + normal)) for p in (a, b, c)]
        rear = [self.bm.verts.new(G_TO_B @ (p - normal)) for p in (a, b, c)]
        faces = [self.bm.faces.new(front), self.bm.faces.new(list(reversed(rear)))]
        for i in range(3):
            j = (i + 1) % 3
            faces.append(self.bm.faces.new((front[i], rear[i], rear[j], front[j])))
        self._paint(faces, color)

    def star(self, centre, radius: float, depth: float, color: str, facing: str = "x") -> None:
        """Five-pointed badge (kids read it as 'Stern'), facing +X or -Z in Godot space."""
        points = []
        for i in range(10):
            r = radius if i % 2 == 0 else radius * 0.45
            a = math.pi / 2 + i * math.pi / 5
            points.append((math.cos(a) * r, math.sin(a) * r))
        def place(u, v, w):
            if facing == "x":
                return Vector((centre[0] + w, centre[1] + v, centre[2] + u))
            return Vector((centre[0] + u, centre[1] + v, centre[2] - w))
        front = [self.bm.verts.new(G_TO_B @ place(u, v, depth * 0.5)) for u, v in points]
        back = [self.bm.verts.new(G_TO_B @ place(u, v, -depth * 0.5)) for u, v in points]
        cf = self.bm.verts.new(G_TO_B @ place(0, 0, depth * 0.5))
        cb = self.bm.verts.new(G_TO_B @ place(0, 0, -depth * 0.5))
        faces = []
        for i in range(10):
            j = (i + 1) % 10
            faces.append(self.bm.faces.new((cf, front[i], front[j])))
            faces.append(self.bm.faces.new((cb, back[j], back[i])))
            faces.append(self.bm.faces.new((front[i], back[i], back[j], front[j])))
        self._paint(faces, color)

    def to_object(self, name: str) -> bpy.types.Object:
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(name + "_mesh")
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.update()
        mesh.uv_layers.new(name="UVMap")
        if mesh.color_attributes:
            mesh.color_attributes.active_color = mesh.color_attributes[0]
        material = bpy.data.materials.new(name + "_vertex_colour")
        material.use_nodes = True
        nodes = material.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        attribute = nodes.new("ShaderNodeVertexColor")
        attribute.layer_name = "Col"
        material.node_tree.links.new(attribute.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.38
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def empty(name: str, at, parent=None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = G_TO_B @ Vector(at)
    obj.parent = parent
    obj["attachment_marker"] = True
    obj["position_godot_m"] = list(at)
    return obj


ROCKET_LENGTH = 0.66
ROCKET_RADIUS = 0.078


def build_rocket() -> bpy.types.Object:
    """Rocket along -Z (nose forward); origin at its centre of mass."""
    b = Builder()
    r = ROCKET_RADIUS
    # Nose cone (coral), rounded ogive.
    nose = [(-0.33, 0.0)] + [(-0.33 + 0.15 * t, r * math.sin(t * math.pi / 2) ** 0.75) for t in (0.18, 0.4, 0.62, 0.82, 1.0)]
    b.revolve(nose, "nose", 20)
    b.revolve([(-0.18, r), (-0.10, r)], "body", 20)
    b.revolve([(-0.10, r * 1.06), (-0.055, r * 1.06)], "band", 20)
    b.revolve([(-0.055, r), (0.17, r), (0.21, r * 0.86)], "body", 20)
    b.revolve([(0.21, r * 0.86), (0.235, r * 0.62)], "nozzle", 20)
    # Nozzle bell with a hot inner ring (reads as 'fire' even before the flame starts).
    b.revolve([(0.235, r * 0.50), (0.30, r * 0.78), (0.31, r * 0.70)], "nozzle", 20)
    b.revolve([(0.31, r * 0.70), (0.27, r * 0.40), (0.27, 0.0)], "nozzle_hot", 20)
    # Four swept gold fins.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        out = Vector((math.cos(a), math.sin(a), 0.0))
        root_front = out * (r * 0.95) + Vector((0, 0, 0.06))
        root_back = out * (r * 0.9) + Vector((0, 0, 0.22))
        tip = out * (r + 0.085) + Vector((0, 0, 0.215))
        b.fin(root_front, tip, root_back, 0.014, "fin")
    # Star badges on both flanks.
    b.star((r * 1.0, 0.0, 0.05), 0.042, 0.008, "star", "x")
    b.star((-r * 1.0, 0.0, 0.05), 0.042, 0.008, "star", "x")
    rocket = b.to_object("LumoStarRocket")
    empty("Nozzle", (0.0, 0.0, 0.31), rocket)
    return rocket


POD_SLOTS = {"Slot_A": (0.16, 0.135, 0.0), "Slot_B": (0.34, 0.135, 0.0)}


def build_pod() -> bpy.types.Object:
    """Right-hand pod; the runtime mirrors it for the left side. Origin = fold hinge, +X out."""
    b = Builder()
    # Hinge knuckle on the kart flank and a swept strut out to the rack.
    b.revolve([(-0.06, 0.045), (0.06, 0.045)], "hinge", 14, (0.0, 0.0, 0.0), "x")
    b.box((0.09, 0.03, 0.0), (0.16, 0.05, 0.11), "rack", 0.012)
    # Rack cradle: a rounded rail under both rockets with gold trim and a light strip.
    b.box((0.25, 0.045, 0.02), (0.36, 0.05, 0.44), "rack", 0.018)
    b.box((0.25, 0.075, 0.02), (0.38, 0.012, 0.46), "rack_trim", 0.004)
    b.box((0.435, 0.05, 0.02), (0.012, 0.03, 0.40), "light", 0.003)
    for slot in POD_SLOTS.values():
        x, y, _ = slot
        # Two clamp rings per rocket, and a short pylon to the rail.
        for z in (-0.11, 0.12):
            b.revolve([(z - 0.018, ROCKET_RADIUS + 0.014), (z + 0.018, ROCKET_RADIUS + 0.014)], "clamp", 18, (x, y, 0.0))
            b.box((x, 0.08, z), (0.05, 0.05, 0.03), "rail", 0.006)
    # Front fairing so the folded pod reads as part of the kart, not a loose part.
    b.revolve([(-0.30, 0.0), (-0.27, 0.05), (-0.22, 0.07), (-0.20, 0.07)], "rack", 16, (0.25, 0.045, 0.0))
    b.star((0.25, 0.045, -0.302), 0.035, 0.01, "rack_trim", "z")
    pod = b.to_object("LumoRocketPod")
    for name, at in POD_SLOTS.items():
        empty(name, at, pod)
    return pod


def measure(obj: bpy.types.Object) -> dict:
    mesh = obj.data
    mesh.calc_loop_triangles()
    points = [obj.matrix_world @ v.co for v in mesh.vertices]
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return {
        "triangles": len(mesh.loop_triangles), "vertices": len(mesh.vertices),
        "materials": len(mesh.materials), "dimensions_godot_m": [hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]],
    }


def export(obj: bpy.types.Object, path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in [obj] + list(obj.children_recursive):
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True, export_extras=True, export_yup=True,
        export_vertex_color="NAME", export_vertex_color_name="Col", export_all_vertex_colors=False, export_animations=False, export_cameras=False, export_lights=False,
        export_materials="EXPORT", export_image_format="NONE",
    )


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    report = {"generator": "tools/lumo_kart_art/items/build_rocket_props.py", "units": "metres",
              "axes": "Godot -Z forward, +Y up", "texture_images": [], "authorship": "Original procedural Lumo geometry; no third-party assets."}
    rocket = build_rocket()
    pod = build_pod()
    bpy.context.view_layer.update()
    for obj, name in ((rocket, "lumo_star_rocket"), (pod, "lumo_rocket_pod")):
        path = OUT / (name + ".glb")
        export(obj, path)
        report[name] = measure(obj) | {"bytes": path.stat().st_size}
    report["pod_slots_godot_m"] = POD_SLOTS
    report["rocket_nozzle_godot_m"] = [0.0, 0.0, 0.31]
    (OUT / "rocket_props_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("LUMO_ROCKET_PROPS " + json.dumps({k: v for k, v in report.items() if isinstance(v, dict)}))


if __name__ == "__main__":
    main()
