"""Art-directed, Blender-editable premium LUMO teaching props.

The input eight base objects already exist and retain their *exact* names.
Meshes are joined (not rasterized), with separate PBR materials per surface.
All geometry is authored here from primitives; no new third-party assets.
Blender is Z-up. Export is standard glTF Y-up for Godot.
"""
from __future__ import annotations

import math
import bpy
from mathutils import Vector

ASSET_NAMES = (
    "CounterBerry", "LetterTile", "TenBundle", "ShapeCircle",
    "ShapeSquare", "ShapeTriangle", "TenFrameCell", "LearningPodium",
)


def mat(name, color, roughness=0.48, metal=0.0):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1.0)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metal
    return m


def assign(o, material):
    o.data.materials.clear()
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = len(p.vertices) > 3


def uv_sphere(at, scale, material, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1, location=at)
    o = bpy.context.object
    o.scale = scale
    assign(o, material)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def cuboid(at, size, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(o, material)
    if bevel > 0:
        mod = o.modifiers.new("RoundedChildSafeEdges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in o.data.polygons:
        poly.use_smooth = True
    return o


def cylinder(at, radius, depth, material, vertices=16, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=at)
    o = bpy.context.object
    assign(o, material)
    if bevel > 0:
        mod = o.modifiers.new("RoundedRim", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in o.data.polygons:
        poly.use_smooth = True
    return o


def merge_under(original, additions):
    """Join edited real mesh geometry into ONE Godot instantiable model node.

    GLB stage code reads a Mesh and deliberately ignores the node's authored
    scene transform. Keeping the original object as active join target
    therefore preserves the correct asset-local pivot for every reuse.
    """
    for object_to_join in additions:
        assert object_to_join.type == "MESH"
        assert object_to_join is not original
    bpy.ops.object.select_all(action="DESELECT")
    for obj in additions:
        obj.select_set(True)
    original.select_set(True)
    bpy.context.view_layer.objects.active = original
    bpy.ops.object.join()
    assert bpy.context.object is original
    return original


def add_berry():
    base = bpy.data.objects["CounterBerry"]
    center = base.location.copy()
    leaves = mat("Berry_LeafEmerald", (0.10, 0.46, 0.27), .66)
    veins = mat("Berry_LeafGlint", (0.42, 0.77, 0.40), .56)
    seed = mat("Berry_GoldSeeds", (0.98, 0.73, 0.32), .48)
    stem = mat("Berry_ChestnutStem", (0.34, 0.20, 0.12), .85)
    body = mat("Berry_MatteCoral", (0.84, 0.15, 0.18), .44)
    assign(base, body)
    # Real slightly asymmetric berry instead of an untextured sphere.
    base.scale = (0.94, 1.0, 1.08)
    bpy.context.view_layer.objects.active = base
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    additions = []
    for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        p = Vector((math.cos(a) * .072, math.sin(a) * .072, .151))
        leaf = uv_sphere(center + p, (.065, .021, .018), leaves, 12, 6)
        leaf.rotation_euler.z = a
        additions.append(leaf)
        vein = uv_sphere(center + p * .93 + Vector((0, 0, .010)),
                         (.028, .005, .002), veins, 10, 5)
        vein.rotation_euler.z = a
        additions.append(vein)
    additions.append(cylinder(center + Vector((0, 0, .178)),
                              .014, .060, stem, 10, .006))
    # Seeds are visible when the child rotates the berry. Few enough to
    # keep 13 copies affordable on an Android Mali/Adreno device.
    for row, z in enumerate((-.062, .010, .073)):
        count = 5 if row == 1 else 4
        radius = .145 * math.sqrt(max(.0, 1.0 - (z/.16)**2))
        for k in range(count):
            a = math.tau * (k + (row % 2)*.5) / count
            dot = center + Vector((radius*math.cos(a),
                                   radius*math.sin(a), z))
            additions.append(uv_sphere(dot, (.011, .007, .011),
                                       seed, 8, 4))
    merge_under(base, additions)


def add_tile():
    base = bpy.data.objects["LetterTile"]
    center = base.location.copy()
    face = mat("Tile_CreamCeramic", (0.97, 0.83, 0.60), .57)
    edge = mat("Tile_TurquoiseInset", (0.20, 0.56, 0.64), .45)
    dot = mat("Tile_MetalPin", (0.91, 0.73, 0.41), .36, .23)
    assign(base, face)
    extras = [cuboid(center+Vector((0, -.209, 0)),
                    (.343, .010, .335), edge, .012),
              cuboid(center+Vector((0, -.219, 0)),
                    (.317, .012, .310), face, .015)]
    for sign_x in (-1, 1):
        for sign_z in (-1, 1):
            extras.append(uv_sphere(
                center + Vector((sign_x*.151, -.235, sign_z*.15)),
                (.008, .004, .008), dot, 8, 4))
    merge_under(base, extras)


def add_bundle():
    root = bpy.data.objects["TenBundle"]
    center = root.location.copy()
    # Replace a single stretched block with TEN independently modeled
    # sticks, bundled by one band. All are joined into one editable mesh.
    original_mesh = root.data
    bpy.data.objects.remove(root, do_unlink=True)
    if original_mesh.users == 0:
        bpy.data.meshes.remove(original_mesh)
    wood = mat("TenBundle_LightBeech", (0.85, 0.63, 0.38), .65)
    ochre = mat("TenBundle_SoftGrain", (0.67, 0.41, 0.25), .74)
    band = mat("TenBundle_PurpleBand", (0.50, 0.30, 0.80), .47)
    sticks = []
    for row in range(2):
        for col in range(5):
            origin = center + Vector(((col - 2) * .060,
                                      (row - .5) * .058, 0))
            stick = cylinder(origin, .023, .365,
                             wood if (row+col)%2==0 else ochre,
                             vertices=12, bevel=.006)
            sticks.append(stick)
    top = sticks.pop(0)
    top.name = "TenBundle"
    strips = [
        cuboid(center+Vector((0, 0, -.032)), (.30, .14, .055),
               band, .010),
        cuboid(center+Vector((0, 0, .008)), (.30, .14, .015),
               mat("TenBundle_BandHighlight", (.80,.62,.97), .40), .005),
    ]
    merge_under(top, sticks + strips)


def flat_triangle():
    o = bpy.data.objects["ShapeTriangle"]
    geo = bpy.data.meshes.new("ShapeTrianglePrismTopology")
    # A triangle in XY for Blender Z-up; runtime turns it upright, so it
    # remains an actual triangle (not a tetrahedron or conic silhouette).
    verts = [(-.18,-.18,-.048),(.18,-.18,-.048),(0,.18,-.048),
             (-.18,-.18,.048),(.18,-.18,.048),(0,.18,.048)]
    faces = [(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]
    geo.from_pydata(verts, [], faces)
    geo.update()
    old = o.data
    o.data = geo
    if old.users == 0:
        bpy.data.meshes.remove(old)
    o.data.materials.append(mat("Triangle_Jade",(.14,.69,.55), .45))
    bevel = o.modifiers.new("RoundedTrianglePrism", "BEVEL")
    bevel.width = .020
    bevel.segments = 3
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for f in o.data.polygons:
        f.use_smooth = True


def shapes():
    circle = bpy.data.objects["ShapeCircle"]
    square = bpy.data.objects["ShapeSquare"]
    triangle = bpy.data.objects["ShapeTriangle"]
    flat_triangle()
    # Layered edge accents improve recognition on the 412px mobile view.
    circle_at = circle.location.copy()
    c = cylinder(circle_at+Vector((0,0,.035)), .146, .012,
                 mat("Circle_SunlitInlay",(.99,.91,.53), .34), 32, .003)
    merge_under(circle, [c])
    square_at = square.location.copy()
    s = cuboid(square_at+Vector((0, -.195, 0)), (.305,.018,.305),
               mat("Square_LilacInlay",(.72,.57,.96), .48), .017)
    merge_under(square, [s])
    # A thin inset in the triangle's actual frontal surface.
    center = triangle.location.copy()
    inlay = cuboid(center+Vector((0,-.188,0)), (.04,.008,.04),
                   mat("Triangle_InnerGlint",(.58,.93,.71), .42), .009)
    # The triangle's exterior is a triangular prism, not the inlay marker.
    merge_under(triangle, [inlay])


def ten_cell():
    base = bpy.data.objects["TenFrameCell"]
    center = base.location.copy()
    assign(base, mat("TenFrameCell_AzureBase",(.16,.35,.47), .72))
    accent = mat("TenFrameCell_Border",(.54,.87,.91), .39, .09)
    dark = mat("TenFrameCell_Recess",(.12,.24,.34), .78)
    # Facing towards exported Godot +Z (Blender -Y).
    extras = [
        cuboid(center+Vector((0, -.177, 0)), (.30,.009,.30), accent, .013),
        cuboid(center+Vector((0, -.183, 0)), (.265,.010,.265), dark, .010),
    ]
    merge_under(base, extras)


def podium():
    base = bpy.data.objects["LearningPodium"]
    at = base.location.copy()
    assign(base, mat("Podium_LapisStone",(.14,.29,.50), .59))
    extras=[
        cylinder(at+Vector((0,0,.055)), .95,.028,
                 mat("Podium_LavenderEdge",(.54,.36,.79),.41), 48, .010),
        cylinder(at+Vector((0,0,.076)), .88,.025,
                 mat("Podium_MidnightSurface",(.17,.19,.34),.64), 48, .007)
    ]
    merge_under(base, extras)


def upgrade():
    """Preserve all original top-level asset names for existing Godot scenes."""
    assert all(bpy.data.objects.get(n) for n in ASSET_NAMES)
    add_berry()
    add_tile()
    add_bundle()
    shapes()
    ten_cell()
    podium()
    assert {o.name for o in bpy.context.scene.objects if o.type=="MESH"} == set(ASSET_NAMES)
    polygons=sum(sum(len(f.vertices)-2 for f in obj.data.polygons)
                 for obj in bpy.context.scene.objects if obj.type=="MESH")
    assert polygons <= 11000, f"Detailed kit exceeds 11k triangle prototype budget ({polygons})"
    return {"assets": list(ASSET_NAMES),
            "asset_mesh_objects": 8,
            "triangles_in_full_kit": polygons,
            "materials": len(bpy.data.materials),
            "license": "Original locally authored scripted meshes and materials"}


def render_preview(output):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 28
    if scene.world is None:
        scene.world = bpy.data.worlds.new("LumoObjectStudioWorld")
    scene.world.color = (.15,.12,.20)
    for layer in scene.view_layers:
        if hasattr(layer,"cycles"):
            layer.cycles.use_denoising=False
    bpy.ops.object.camera_add(location=(2.6,-4.2,2.4))
    cam=bpy.context.object
    cam.name="PreviewOnly_LearningObjectsCamera"
    point=Vector((.15,.45,.23))
    cam.rotation_euler=(point-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=4.35
    scene.camera=cam
    for xyz, energy, radius in [
        ((-3,-3,4), 650, 3.0),
        ((3,-1,3), 480, 2.5),
        ((1,2,4), 370, 2.8),
    ]:
        data=bpy.data.lights.new("PreviewOnly_Artbox", "AREA")
        data.energy=energy
        data.shape="DISK"
        data.size=radius
        l=bpy.data.objects.new(data.name,data)
        scene.collection.objects.link(l)
        l.location=xyz
        l.rotation_euler=(point-l.location).to_track_quat("-Z","Y").to_euler()
    scene.render.resolution_x=1200
    scene.render.resolution_y=820
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(output / "Blender_Lumo_LearningObjects.png")
    bpy.ops.render.render(write_still=True)
