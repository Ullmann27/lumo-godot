"""Build the village lion and human carpenter. Run with blender -b -P this_file."""
import math
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[2] / 'assets/creative/village'
TAU = math.tau
groups = {}
pivots = {}


def srgb(v):
    v /= 255
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4


def part(obj, color, group='Body'):
    rgb = [srgb(int(color[i:i + 2], 16)) for i in (0, 2, 4)] + [1]
    attr = obj.data.color_attributes.new(name='Farbe', type='BYTE_COLOR', domain='CORNER')
    for item in attr.data:
        item.color = rgb
    groups.setdefault(group, []).append(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def oval(at, size, color, group='Body', sides=10, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=sides, ring_count=rings, location=at)
    obj = bpy.context.object
    obj.scale = size
    return part(obj, color, group)


def loft(name, levels, color, axis='z', group='Body', n=12):
    # Cross sections follow the spine or a limb; every ring can change its centre.
    verts, faces = [], []
    for x, y, z, rx, r in levels:
        for i in range(n):
            a = i * TAU / n
            verts.append((x + rx * math.cos(a), y + (r * math.sin(a) if axis == 'z' else 0),
                          z + (r * math.sin(a) if axis == 'y' else 0)))
    for j in range(len(levels) - 1):
        for i in range(n):
            a = j * n + i
            b = j * n + (i + 1) % n
            faces.append((a, b, b + n, a + n))
    faces += [tuple(reversed(range(n))), tuple(range(len(verts) - n, len(verts)))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    part(obj, color, group)


def link(a, b, radius, color, group='Body'):
    a, b = Vector(a), Vector(b)
    obj = oval((a+b)/2, (radius, radius, (b-a).length/2+radius*.25), color, group)
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()


def begin():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    groups.clear()
    pivots.clear()


def export(name):
    material = bpy.data.materials.new('Painted clay')
    material.use_nodes = True
    material.use_backface_culling = True
    nodes = material.node_tree.nodes
    color = nodes.new('ShaderNodeVertexColor')
    color.layer_name = 'Farbe'
    shader = nodes.get('Principled BSDF')
    material.node_tree.links.new(color.outputs['Color'], shader.inputs['Base Color'])
    shader.inputs['Roughness'].default_value = .84
    for group, meshes in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = group
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.context.scene.cursor.location = pivots.get(group, (0,0,0))
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        obj.data.materials.append(material)
        # Ring order varies for horizontal and vertical lofts.
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name+'.glb')), export_format='GLB',
                              export_animations=False, export_yup=True)


def lion():
    begin()
    fur, warm, cream = 'd59a50', 'bb7641', 'f4ddad'
    loft('Ribcage and flank', [(0,-.71,.94,.22,.29),(0,-.53,.97,.34,.43),
        (0,-.14,.90,.33,.36),(0,.22,.86,.24,.26),(0,.55,.91,.31,.35),
        (0,.73,.91,.21,.24)], fur,'y',n=18)
    oval((0,-.58,1.13),(.43,.38,.53),'754328')
    oval((0,-.79,1.28),(.42,.31,.44),'96552d')
    # Overlapping pointed locks taper down around the face, leaving the muzzle clear.
    for i in range(16):
        a = TAU*i/16
        x, z = math.cos(a)*.34, 1.30+math.sin(a)*.35
        loft('Mane lock', [(x*1.17,-.84,z-.17,.012,.015),(x*1.13,-.85,z-.06,.095,.085),
             (x,-.82,z+.08,.122,.12),(x*.93,-.78,z+.14,.05,.06)],
             ('b96b33','8f4f2a','a45c2c','bd763d')[i%4],n=9)
    oval((0,-.99,1.37),(.292,.24,.30),fur)
    for s in (-1,1):
        oval((s*.267,-.86,1.55),(.102,.065,.125),'553925')
        oval((s*.258,-.915,1.56),(.069,.024,.076),'c49074')
        oval((s*.145,-1.181,1.43),(.090,.036,.055),'69432b')
        oval((s*.149,-1.208,1.433),(.054,.022,.043),'e5ae52')
        oval((s*.148,-1.228,1.432),(.024,.012,.033),'251c19')
        oval((s*.143-.006,-1.238,1.448),(.009,.006,.010),'fff5dc')
        oval((s*.114,-1.215,1.285),(.142,.111,.103),cream)
        for j in range(4):
            oval((s*(.113+j*.020),-1.315+j*.009,1.285+(j%2)*.022),
                 (.009,.006,.008),'75543c',sides=8,rings=4)
        for j in range(2):
            link((s*.18,-1.293,1.265+j*.035),(s*.32,-1.298,1.25+j*.056),.0048,'f0d7ac')
    oval((0,-1.191,1.21),(.14,.094,.078),'e4c592')
    loft('Nose',[(0,-1.309,1.308,.035,.023),(0,-1.30,1.356,.095,.045),
        (0,-1.281,1.383,.062,.025)],'44312b',n=10)
    for s in (-1,1):
        for fore in (True,False):
            y = -.46 if fore else .51
            grp = ('Fore' if fore else 'Hind')+('L' if s<0 else 'R')
            pivots[grp] = (s*.208,y,.90)
            levels = [(.065,-.015,.093,.108),(.16,.045,.065,.065),(.39,.065,.057,.08),
                      (.56,.088,.079,.09),(.76,.018,.122,.128),(.93,0,.105,.12)] if fore else [
                      (.066,-.025,.095,.11),(.19,.065,.061,.067),(.34,.14,.061,.075),
                      (.56,-.014,.089,.11),(.74,-.038,.145,.17),(.95,0,.135,.153)]
            loft(grp,[(s*.21,y+d,z,rx,ry) for z,d,rx,ry in levels],fur,'z',grp)
            oval((s*.21,y-.047,.071),(.104,.155,.072),warm,grp)
            for t in (-1,0,1):
                oval((s*.21+t*.044,y-.13,.061),(.041,.075,.047),fur,grp)
    pivots['Tail']=(0,.68,1)
    for a,b in [((0,.65,1),(.03,.93,.82)),((.03,.91,.84),(.10,1.14,.62)),
                ((.10,1.12,.63),(.23,1.32,.68)),((.23,1.31,.68),(.31,1.40,.86))]:
        link(a,b,.049,fur,'Tail')
    oval((.31,1.40,.87),(.082,.081,.131),'62402a','Tail')
    export('lion_village')


def carpenter():
    begin()
    skin='995f43'
    loft('Coat',[(0,0,.68,.18,.13),(0,.015,.77,.205,.15),(0,.01,1.04,.197,.14),
                 (0,0,1.18,.23,.13),(0,0,1.23,.14,.102)],'257b78')
    loft('Work apron',[(0,-.045,.66,.177,.112),(0,-.055,.72,.19,.12),
         (0,-.055,.99,.162,.117),(0,-.075,1.11,.111,.09)],'d99348')
    oval((0,0,1.27),(.098,.092,.12),skin)
    oval((0,-.01,1.43),(.152,.135,.194),skin)
    oval((0,.036,1.51),(.16,.143,.137),'362821')
    for s in (-1,1):
        oval((s*.143,-.002,1.431),(.035,.04,.052),skin)
        oval((s*.061,-.132,1.452),(.020,.011,.020),'32241e')
        link((s*.037,-.134,1.482),(s*.087,-.119,1.483),.009,'382b23')
    oval((0,-.143,1.416),(.035,.041,.041),'ab6d4d')
    link((-.037,-.135,1.377),(.034,-.138,1.374),.007,'613b32')
    oval((0,0,1.588),(.219,.196,.029),'b87837')
    loft('Felt hat',[(0,.006,1.58,.16,.143),(0,.007,1.615,.16,.144),
         (.006,.018,1.695,.127,.117),(.012,.022,1.712,.090,.095)],'e3b65e')
    loft('Hat band',[(0,.006,1.599,.164,.148),(0,.008,1.626,.157,.143)],'365e60')
    for s in (-1,1):
        side='L' if s<0 else 'R'
        leg='Hind'+side
        pivots[leg]=(s*.097,0,.73)
        loft('Trouser',[(s*.101,0,.12,.070,.072),(s*.099,.014,.34,.072,.071),
             (s*.096,-.009,.47,.08,.079),(s*.094,0,.74,.1,.10)],'354d61','z',leg)
        oval((s*.102,-.036,.087),(.085,.146,.086),'654637',leg)
        arm='Fore'+side
        pivots[arm]=(s*.20,0,1.16)
        link((s*.182,.005,1.16),(s*.247,0,.973),.086,'257b78',arm)
        link((s*.247,0,1.002),(s*.256,-.033,.822),.059,'edc993',arm)
        oval((s*.253,-.04,.803),(.05,.051,.075),skin,arm)
    link((-.11,-.089,1.205),(.156,-.137,.756),.022,'764a2e')
    oval((.17,-.061,.734),(.075,.118,.093),'875734')
    export('carpenter_village')


lion()
carpenter()
