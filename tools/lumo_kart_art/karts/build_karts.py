#!/usr/bin/env python3
"""Author LUMO Aurora karts in Blender, preserving the shipped mechanical contract.

Run: blender -b -t 4 --python tools/lumo_kart_art/karts/build_karts.py -- --variant comet
All modelling coordinates use the existing Godot convention: metres, Y up, -Z forward.
No downloaded geometry, provider generation, stock textures or third-party marks.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[3]
G_TO_B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
PALETTES = {
    "comet": ("172c49", "e9f5ff", "c79850", "62d8f0"),
    "glider": ("dff0ff", "3fd0c0", "bed6df", "61e1ce"),
    "turbo": ("3a1f6e", "ffd36a", "be9139", "b39ae8"),
}
STANCES={'comet':1.0,'glider':.91,'turbo':1.10}


def g(point):
    return G_TO_B @ Vector(point)


def linear(hex_color):
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1.0,)


def material(name, color, metal=0, rough=.5, emission=0, coat=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs['Base Color'].default_value = linear(color)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    p.inputs['Coat Weight'].default_value = coat
    p.inputs['Coat Roughness'].default_value = .23
    if emission:
        p.inputs['Emission Color'].default_value = linear(color)
        p.inputs['Emission Strength'].default_value = emission
    m.diffuse_color = linear(color)
    return m


def empty(name, at=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.empty_display_type = 'PLAIN_AXES'
    o.empty_display_size = .08
    o.location = g(at)
    o.parent = parent
    return o


def finish(o, mat, parent=None, smooth=True):
    if mat:
        o.data.materials.append(mat)
    o.parent = parent
    if hasattr(o.data, "polygons"):
        for p in o.data.polygons:
            p.use_smooth = smooth
    return o


def mesh(name, verts, faces, mat, parent=None, uv=None):
    data = bpy.data.meshes.new(name + '_mesh')
    data.from_pydata([g(v) for v in verts], [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data)
    bm.free()
    data.update()
    layer = data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        for li in poly.loop_indices:
            vi = data.loops[li].vertex_index
            p = verts[vi]
            layer.data[li].uv = uv[vi] if uv else (p[0] * .5 + .5, p[2] * .5 + .5)
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    return finish(o, mat, parent)


def bevel_box(name, at, size, mat, parent=None, bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1, location=g(at))
    o = bpy.context.object
    o.name = name
    o.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        m = o.modifiers.new("Machined fillet", 'BEVEL')
        # Leave a finite face between fillets; a half-thickness bevel collapses
        # opposite edges and produces zero-area triangles in the glTF export.
        m.width = min(bevel, min(size) * .42)
        m.segments = 3
        m.affect = 'EDGES'
        m = o.modifiers.new("Weighted corner normals", 'WEIGHTED_NORMAL')
        m.keep_sharp = True
    return finish(o, mat, parent)


def ellipsoid(name, at, size, mat, parent=None, segments=28, rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=g(at))
    o = bpy.context.object
    o.name = name
    o.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, mat, parent)


def tube(name, points, radius, mat, parent=None, sides=8):
    closed=(Vector(points[0])-Vector(points[-1])).length_squared<1e-12
    if closed:
        points=points[:-1]
    verts, faces, uv = [], [], []
    cumulative = 0.0
    for row, p in enumerate(points):
        p = Vector(p)
        tangent = (Vector(points[(row+1)%len(points)])-Vector(points[(row-1)%len(points)])) if closed else (Vector(points[min(row + 1, len(points) - 1)]) - Vector(points[max(row - 1, 0)]))
        tangent.normalize()
        # The closed steering rim lies in XY: a fixed perpendicular frame
        # avoids the visible quarter-turn twist from switching reference axes.
        reference = Vector((0,0,1)) if closed else (Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0)))
        u = tangent.cross(reference).normalized()
        v = tangent.cross(u).normalized()
        if row:
            cumulative += (p - Vector(points[row - 1])).length
        for col in range(sides):
            a = col * math.tau / sides
            verts.append(p + radius * (u * math.cos(a) + v * math.sin(a)))
            uv.append((col / sides, cumulative / (math.tau * radius)))
    for row in range(len(points) if closed else len(points) - 1):
        for col in range(sides):
            a = row * sides + col
            b = row * sides + (col + 1) % sides
            faces.append((a, b, (b + sides)%(len(points)*sides), (a + sides)%(len(points)*sides)))
    if not closed:
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple((len(points) - 1) * sides + i for i in range(sides)))
    return mesh(name, verts, faces, mat, parent, uv)


def loft(name, rows, mat, parent=None, sections=32, steps=3, vertical=False, power=.82):
    """Smooth closed superellipse loft; rows=(axis, halfwidth, halftall, offset)."""
    samples = []
    for k in range(len(rows) - 1):
        a, b, c, d = [Vector(rows[min(max(i, 0), len(rows) - 1)]) for i in (k - 1, k, k + 1, k + 2)]
        for j in range(steps):
            t = j / steps
            samples.append(.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t))
    samples.append(Vector(rows[-1]))
    verts, faces, uv = [], [], []
    for ri, row in enumerate(samples):
        for ci in range(sections):
            a = ci * math.tau / sections
            cs, sn = math.cos(a), math.sin(a)
            x = math.copysign(abs(cs) ** power, cs) * max(.002, row[1])
            y = row[3] + math.copysign(abs(sn) ** power, sn) * max(.002, row[2])
            verts.append((x, row[0], y) if vertical else (x, y, row[0]))
            uv.append((ci / sections, ri / (len(samples) - 1)))
    for ri in range(len(samples) - 1):
        for ci in range(sections):
            a = ri * sections + ci
            b = ri * sections + (ci + 1) % sections
            faces.append((a, b, b + sections, a + sections))
    faces.append(tuple(reversed(range(sections))))
    faces.append(tuple((len(samples) - 1) * sections + i for i in range(sections)))
    return mesh(name, verts, faces, mat, parent, uv)


def torus_x(name, x, radius, minor, mat, parent=None, major_steps=48, minor_steps=8):
    verts, faces, uv = [], [], []
    for i in range(major_steps):
        a = i * math.tau / major_steps
        for j in range(minor_steps):
            b = j * math.tau / minor_steps
            r = radius + minor * math.cos(b)
            verts.append((x + minor * math.sin(b), r * math.cos(a), r * math.sin(a)))
            uv.append((i / major_steps, j / minor_steps))
    for i in range(major_steps):
        for j in range(minor_steps):
            faces.append((i * minor_steps + j, (i + 1) % major_steps * minor_steps + j,
                          (i + 1) % major_steps * minor_steps + (j + 1) % minor_steps,
                          i * minor_steps + (j + 1) % minor_steps))
    return mesh(name, verts, faces, mat, parent, uv)


def tyre(parent, mats):
    # Closed annulus includes both sidewalls and the inner barrel. Grooves are geometry.
    rows = [(-.19,.211),(-.19,.253),(-.175,.298),(-.142,.331),(-.115,.347),
            (-.095,.350),(-.082,.338),(-.071,.350),(-.016,.350),(.016,.350),
            (.071,.350),(.082,.338),(.095,.350),(.115,.347),(.142,.331),
            (.175,.298),(.19,.253),(.19,.211),(.16,.204),(-.16,.204)]
    verts, faces, uv = [], [], []
    n = 80
    for ri, (x,r) in enumerate(rows):
        for ci in range(n):
            a = ci * math.tau / n
            cut = .007 if abs(x) < .143 and ci % 5 == (1 if x < 0 else 2) else 0
            verts.append((x, (r-cut)*math.cos(a), (r-cut)*math.sin(a)))
            uv.append((ci/n, (x+.19)/.38))
    for ri in range(len(rows)):
        for ci in range(n):
            faces.append((ri*n+ci, ri*n+(ci+1)%n, (ri+1)%len(rows)*n+(ci+1)%n, (ri+1)%len(rows)*n+ci))
    return mesh("TyreClosedDirectional", verts, faces, mats['rubber'], parent, uv)


def wheel(label, x, z, mats, root):
    side = -1 if x < 0 else 1
    steering = empty("Steer_" + label, (x,.35,z), root)
    steering['axis_godot'] = '+Y'
    steering['max_steer_rad'] = .34 if label.startswith('F') else 0.0
    rotor = empty("Wheel_" + label, parent=steering)
    rotor['spin_axis_godot'] = '+X'
    rotor['rolling_radius_m'] = .35
    tyre(rotor, mats)
    face_x = side*.191
    torus_x("RimOuterLip_"+label,face_x,.221,.013,mats['alloy'],rotor)
    torus_x("RimBarrelInner_"+label,-side*.177,.207,.010,mats['alloy'],rotor,32,6)
    for i in range(5):
        a = math.tau*i/5
        points=[]
        for t in (0,.45,1):
            r=.047+.157*t
            aa=a+.20*t
            points.append((face_x+side*(.012-.009*t),math.cos(aa)*r,math.sin(aa)*r))
        tube("ForgedSpoke_"+label,points,.021,mats['alloy'],rotor,6)
        a += .04
        ellipsoid("LugBolt_"+label,(face_x+side*.026,math.cos(a)*.065,math.sin(a)*.065),(.009,.011,.011),mats['gold'],rotor,12,8)
    ellipsoid("Hub_"+label,(face_x+side*.014,0,0),(.025,.065,.065),mats['paint'],rotor,20,10)
    ellipsoid("HubBadge_"+label,(face_x+side*.038,0,0),(.006,.023,.023),mats['gold'],rotor,16,8)
    torus_x("MouldedSidewallRib_"+label,side*.188,.267,.003,mats['rubber'],rotor,48,5)
    # Brake disc is axle-concentric; caliper remains fixed to steering knuckle.
    torus_x("BrakeDisc_"+label,side*.14,.163,.027,mats['alloy'],rotor,32,6)
    bevel_box("BrakeCaliper_"+label,(side*.15,.060,-.145),(.05,.12,.065),mats['gold'],steering,.012)
    tube("StubAxle_"+label,[(-side*.18,0,0),(side*.16,0,0)],.043,mats['alloy'],steering)
    for offset in (-.08,.08):
        tube("Wishbone_"+label,[(side*.35,.31,z+offset),(x,.35,z)],.018,mats['alloy'],root)
    a,b=Vector((side*.40,.62,z)),Vector((x,.385,z))
    tube("DamperShaft_"+label,[a,b],.024,mats['alloy'],root)
    axis=(b-a).normalized()
    u=axis.cross(Vector((0,0,1))).normalized()
    v=axis.cross(u).normalized()
    coil=[]
    for i in range(61):
        t=.14+.70*i/60
        coil.append(a.lerp(b,t)+.046*(math.cos(i/60*math.tau*5)*u+math.sin(i/60*math.tau*5)*v))
    tube("HelicalSpring_"+label,coil,.008,mats['gold'],root,6)
    return steering, rotor


def create_kart(variant):
    paint, trim, gold, ice = PALETTES[variant]
    mats = {
        'paint':material('Aurora_'+variant+'_paint',paint,.34,.27,coat=.42),
        'trim':material('CeramicPearl',trim,.20,.33,coat=.2),
        'gold':material('SatinAccent',gold,.68,.34),
        'alloy':material('BrushedAluminium','b7c7d3',.78,.31),
        'rubber':material('VulcanisedRubber','101722',0,.84),
        'carbon':material('GraphiteComposite','16202c',.12,.58),
        'cloth':material('WovenSeatUpholstery','29435e',0,.86),
        'lamp':material('InsetCyanLens',ice,.15,.24,.45),
        'brake':material('RearBrakeLens','f05c52',.12,.27,.35),
    }
    root=empty('Aurora_'+variant)
    root['asset_contract']='lumo_kart_art.v1'
    root['source_style']=variant
    root['units']='metres'
    root['forward_axis']='Godot -Z'
    root['physics_changed']=False
    root['stance_multiplier']=STANCES[variant]
    body=empty('Coachwork',parent=root)
    body.scale.x=STANCES[variant]
    # 2026-11-18 cockpit rework: the driver sits IN the kart. Seat pan 0.31 m
    # above ground (was 0.69 m, above the tyres), feet in a footwell under the
    # front fairing, steering wheel in front of the chest. Wheel pivots, track,
    # wheelbase and the boost ports are unchanged, so driving physics, collision
    # and cameras keep their values.
    bevel_box('FloorPan',(0,.115,-.02),(.84,.05,1.96),mats['carbon'],body,.02)
    # Front fairing: closed shell that hides the footwell; highest at the dash.
    loft('NoseFairing',[(-1.19,.09,.03,.29),(-1.12,.25,.07,.305),(-.96,.35,.115,.35),
         (-.74,.385,.16,.405),(-.52,.40,.195,.445),(-.37,.40,.215,.46),(-.30,.385,.205,.452)],mats['paint'],body,32,3)
    loft('NoseStripe',[(-1.16,.035,.012,.345),(-1.0,.06,.014,.455),(-.80,.07,.014,.545),
         (-.62,.075,.013,.622),(-.47,.075,.012,.664),(-.40,.07,.01,.674)],mats['trim'],body,12,2)
    # Dark footwell mouth behind the dash: the legs disappear into it.
    bevel_box('FootwellMouth',(0,.40,-.292),(.60,.27,.02),mats['carbon'],body,.006)
    tube('DashHoop',[(-.385,.47,-.305),(-.33,.62,-.315),(-.18,.69,-.325),(0,.705,-.33),
         (.18,.69,-.325),(.33,.62,-.315),(.385,.47,-.305)],.026,mats['carbon'],body,10)
    for side in (-1,1):
        # Cockpit wall from dash to seat back; the driver's hips sit between them.
        o=loft('CockpitWall',[(-.31,.03,.11,.33),(-.20,.055,.17,.37),(.10,.06,.185,.385),
               (.40,.06,.20,.40),(.60,.05,.18,.41),(.68,.02,.10,.40)],mats['paint'],body,16,3)
        o.location.x=side*.345
        tube('CockpitRimPad',[(side*.345,.545,-.20),(side*.345,.572,.10),(side*.345,.602,.40),(side*.345,.595,.62)],.022,mats['cloth'],body,8)
        # A fixed-width tyre moves inward on Glider's original 0.91 axle stance.
        pod_center=.555 if variant=='glider' else .585
        pod_scale=.80 if variant=='glider' else 1.0
        def pod_x(x):
            return side*(pod_center+(x-.585)*pod_scale)
        o=loft('SculptedSidePod',[(-.235,.02,.03,.325),(-.17,.135,.10,.33),(-.02,.168,.125,.335),
               (.18,.165,.13,.34),(.265,.10,.10,.34),(.295,.02,.04,.34)],mats['paint'],body,24,4)
        o.location.x=side*pod_center
        o.scale.x=pod_scale
        tube('SidePodLightStrip',[(pod_x(.735),.385,-.15),(pod_x(.752),.392,-.02),(pod_x(.750),.398,.17),(pod_x(.72),.40,.255)],.012,mats['lamp'],body,6)
        tube('SideGoldWaist',[(pod_x(.60),.462,-.15),(pod_x(.62),.468,.0),(pod_x(.62),.474,.18)],.007,mats['gold'],body,6)
        for i in range(3):
            bevel_box('InsetCoolingVent',(pod_x(.59),.455,-.08+i*.085),(.11,.012,.05),mats['carbon'],body,.004)
        tube('NerfBar',[(pod_x(.78),.20,-.21),(pod_x(.81),.215,0),(pod_x(.78),.20,.27)],.02,mats['alloy'],body,6)
        # Headlight band on the fairing shoulder.
        tube('HeadlightRecess',[(side*.13,.335,-1.165),(side*.24,.372,-1.07),(side*.325,.43,-.93)],.026,mats['carbon'],body)
        tube('HeadlightLens',[(side*.13,.345,-1.182),(side*.24,.384,-1.088),(side*.325,.443,-.948)],.014,mats['lamp'],body)
        # Wide front wing ahead of the tyres with a light strip, as in the target art.
        tube('FrontWingStay',[(side*.22,.25,-.96),(side*.30,.215,-1.15)],.02,mats['alloy'],body,6)
        bevel_box('FrontWingEndplate',(side*.80,.235,-1.165),(.035,.15,.15),mats['trim'],body,.012)
        bevel_box('FrontWingLight',(side*.47,.222,-1.239),(.50,.032,.014),mats['lamp'],body,.005)
        # Pedals inside the footwell: the soles rest here.
        bevel_box('Pedal_'+str(side),(side*.15,.20,-.40),(.15,.045,.20),mats['alloy'],body,.014)
        for k in range(3):
            bevel_box('PedalGrip',(side*.15,.226,-.46+k*.054),(.11,.007,.012),mats['rubber'],body,.003)
        # Seat-back stays; between them the tail leaves the cockpit.
        tube('SeatBackStay',[(side*.245,.19,.46),(side*.255,.42,.47),(side*.215,.60,.44)],.02,mats['alloy'],body,8)
    bevel_box('FrontWing',(0,.20,-1.165),(1.56,.07,.15),mats['paint'],body,.022)
    bevel_box('FrontWingIntake',(0,.212,-1.239),(.34,.04,.012),mats['carbon'],body,.005)
    # Glowing bonnet letter with real thickness; stays an own node for the runtime.
    badge=empty('BonnetBadge',(0,.60,-.66),body)
    badge.rotation_euler[0]=.31
    bevel_box('LetterLStem',(-.05,0,-.01),(.05,.016,.21),mats['lamp'],badge,.007)
    bevel_box('LetterLFoot',(.012,0,.072),(.175,.016,.05),mats['lamp'],badge,.007)
    # Bucket seat: base on the floor, cushion top at 0.31 m, back from 0.56 m up.
    bevel_box('SeatBase',(0,.205,.22),(.56,.13,.50),mats['carbon'],body,.04)
    ellipsoid('SeatCushion',(0,.272,.20),(.265,.05,.225),mats['cloth'],body)
    loft('BucketSeatShell',[(.555,.215,.05,.445),(.66,.275,.058,.46),(.80,.27,.056,.495),
         (.90,.20,.05,.522),(.945,.06,.02,.535)],mats['carbon'],body,28,4,True,.73)
    loft('BackCushion',[(.585,.175,.024,.402),(.68,.225,.028,.416),(.80,.22,.028,.45),(.885,.15,.022,.475)],mats['cloth'],body,24,3,True,.7)
    for j in range(3):
        y=.63+j*.085
        tube('UpholsteryStitch',[(x,y,.387+(y-.585)*.26-.004) for x in (-.15,-.075,0,.075,.15)],.0016,mats['gold'],body,5)
    # Engine and tail: readable from the chase camera behind the kart.
    bevel_box('PowerModule',(0,.36,.84),(.62,.36,.52),mats['carbon'],body,.06)
    loft('RearPaintCowl',[(.52,.27,.07,.55),(.66,.33,.105,.565),(.90,.335,.10,.555),(1.06,.28,.07,.53),(1.10,.10,.03,.52)],mats['paint'],body,24,3)
    bevel_box('RearPanel',(0,.60,1.035),(.70,.21,.05),mats['carbon'],body,.02)
    for side in (-1,1):
        tube('RearProtection',[(side*.50,.26,.74),(side*.47,.26,1.02),(side*.28,.26,1.17),(0,.26,1.19)],.026,mats['alloy'],body)
        tube('ExhaustPipe',[(side*.20,.47,.70),(side*.215,.50,.95),(side*.12,.467,1.10)],.034,mats['alloy'],body,8)
        bevel_box('TailLampHousing',(side*.242,.678,1.045),(.20,.075,.04),mats['carbon'],body,.014)
        bevel_box('TailLampLens',(side*.242,.683,1.066),(.157,.029,.012),mats['brake'],body,.006)
        bevel_box('RearBoostOutlet',(side*.12,.465,1.104),(.15,.07,.028),mats['carbon'],body,.014)
        bevel_box('RearBoostLens',(side*.12,.467,1.122),(.10,.018,.009),mats['lamp'],body,.004)
    for j in range(5):
        bevel_box('PowerModuleFin',(0,.33+j*.043,1.105),(.33,.014,.02),mats['alloy'],body,.004)
    for x in (-.18,0,.18):
        bevel_box('UnderbodyDiffuser',(x,.15,.98),(.018,.07,.26),mats['carbon'],body,.005)
    # Original Comet has no elevated wing. Other existing fleet liveries keep their wing.
    if variant != 'comet':
        wing_span=1.65 if variant=='glider' else (1.35 if variant=='turbo' else 1.38)
        wing_height=1.02 if variant=='glider' else .94
        for side in (-1,1):
            tube('WingUpright',[(side*.29,.66,.90),(side*.40,wing_height,1.04)],.022,mats['alloy'],body)
            bevel_box('WingEndplate',(side*wing_span*.46,wing_height+.025,1.04),(.035,.14,.29),mats['trim'],body,.012)
        o=loft('AeroWing',[(-wing_span/2,.01,.01,0),(-wing_span*.43,.12,.025,0),(0,.145,.032,0),(wing_span*.43,.12,.025,0),(wing_span/2,.01,.01,0)],mats['paint'],body,16,2)
        o.rotation_euler[2]=math.pi/2
        o.location=g((0,wing_height,1.04))
    steering=empty('SteeringWheel',(0,.68,-.03),root)
    steering.rotation_euler[0]=-.45
    ring_points=[(.155*math.cos(i*math.tau/48),.155*math.sin(i*math.tau/48),0) for i in range(49)]
    tube('LeatherSteeringRim',ring_points,.02,mats['rubber'],steering,10)
    for a in (0,math.pi,math.pi*1.5):
        tube('SteeringSpoke',[(0,0,0),(.135*math.cos(a),.135*math.sin(a),0)],.014,mats['alloy'],steering,6)
    ellipsoid('SteeringBoss',(0,0,-.012),(.055,.038,.018),mats['paint'],steering,20,10)
    tube('SteeringColumn',[(0,.40,-.33),(0,.68,-.03)],.024,mats['alloy'],root)
    wheels=[]
    for side,label in ((-1,'L'),(1,'R')):
        for z,axle in ((-.66,'F'),(.66,'R')):
            wheels.append(wheel(axle+label,side*.77*STANCES[variant],z,mats,root))
    markers={
        'DriverSeat':(0,.31,.20),'DriverOrigin':(0,0,0),
        'Grip_L':(-.16,.70,-.04),'Grip_R':(.16,.70,-.04),
        'Foot_L':(-.15,.31,-.34),'Foot_R':(.15,.31,-.34),
        'FrontAxle':(0,.35,-.66),'RearAxle':(0,.35,.66),
        'Boost_L':(-.12,.467,1.13),'Boost_R':(.12,.467,1.13),
    }
    for name,at in markers.items():
        o=empty(name,at,root)
        o['attachment_marker']=True
        o['position_godot_m']=list(at)
    # Grip markers are wheel children, so procedural wheel rotation keeps contact exact.
    bpy.context.view_layer.update()
    for label in ('L','R'):
        o=bpy.data.objects['Grip_'+label]
        world=o.matrix_world.copy()
        o.parent=steering
        o.matrix_world=world
    return root,mats,wheels,steering,markers


def descendants(root):
    return [root]+list(root.children_recursive)


def apply_modifiers(root):
    for o in descendants(root):
        if o.type=='MESH':
            bpy.context.view_layer.objects.active=o
            for modifier in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=modifier.name)


def prepare_uvs(root):
    """Give cap and bevel faces real area; solid PBR must remain texture-ready.

    One simultaneous unwrap gives consistent density across editable components.
    This also prevents the line-shaped UVs generated at collapsed primitive poles.
    """
    bpy.ops.object.select_all(action='DESELECT')
    meshes=[o for o in descendants(root) if o.type=='MESH']
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(65),island_margin=.02,
                            area_weight=.25,correct_aspect=True,scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')


def batch_assembly(parent):
    meshes=[o for o in parent.children if o.type=='MESH']
    if not meshes:
        return
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.join()
    meshes[0].name=parent.name+'_Mesh'


def measurements(root):
    nodes=[]
    points=[]
    used=set()
    nonmanifold=0
    for o in descendants(root):
        if o.type!='MESH':
            continue
        o.data.calc_loop_triangles()
        bm=bmesh.new();bm.from_mesh(o.data)
        open_edges=sum(1 for e in bm.edges if not e.is_manifold)
        nonmanifold+=open_edges;bm.free()
        points.extend([o.matrix_world@v.co for v in o.data.vertices])
        used.update(m.name for m in o.data.materials if m)
        nodes.append({'node':o.name,'triangles':len(o.data.loop_triangles),'vertices':len(o.data.vertices),'material_slots':len(o.data.materials),'non_manifold_edges':open_edges})
    lo=[min(p[i] for p in points) for i in range(3)]
    hi=[max(p[i] for p in points) for i in range(3)]
    return {'triangles':sum(n['triangles'] for n in nodes),'mesh_nodes':len(nodes),'material_count':len(used),'materials':sorted(used),'non_manifold_edges':nonmanifold,'bounds_blender_m':{'min':lo,'max':hi},'dimensions_godot_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'meshes':nodes}


def export_glb(root,path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in descendants(root):o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_extras=True,export_yup=True,export_animations=True,
        export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='mechanical_demo',
        export_anim_slide_to_zero=True,
        export_cameras=False,export_lights=False)


def action_fcurves(o):
    """F-curves of an object's action in Blender 4 (flat) and 5 (layered, slotted)."""
    action=o.animation_data.action
    if hasattr(action,'fcurves'):
        return list(action.fcurves)
    curves=[]
    for layer in action.layers:
        for strip in layer.strips:
            bag=strip.channelbag(o.animation_data.action_slot)
            if bag:
                curves.extend(bag.fcurves)
    return curves


def mechanical_animation(wheels, steering):
    """Actual editable keyframed wheel-spin and steering clip, 2 s at 24 FPS."""
    scene=bpy.context.scene
    scene.render.fps=24;scene.frame_start=1;scene.frame_end=49
    for pivot,rotor in wheels:
        for f,angle in ((1,0),(49,math.tau*4)):
            rotor.rotation_euler.x=angle
            rotor.keyframe_insert(data_path='rotation_euler',frame=f)
        rotor.animation_data.action.name='mechanical_demo_'+rotor.name
        for fc in action_fcurves(rotor):
            for k in fc.keyframe_points:k.interpolation='LINEAR'
        if pivot.name.startswith('Steer_F'):
            for f,angle in ((1,0),(13,.34),(25,0),(37,-.34),(49,0)):
                pivot.rotation_euler.z=angle
                pivot.keyframe_insert(data_path='rotation_euler',frame=f)
            pivot.animation_data.action.name='mechanical_demo_'+pivot.name
    steering.rotation_mode='QUATERNION'
    for f,angle in ((1,0),(13,.40),(25,0),(37,-.40),(49,0)):
        steering.rotation_quaternion=Quaternion((1,0,0),-.45)@Quaternion((0,-1,0),angle)
        steering.keyframe_insert(data_path='rotation_quaternion',frame=f)
    steering.animation_data.action.name='mechanical_demo_SteeringWheel'
    scene.frame_set(1)


def aim(o,target):
    o.rotation_euler=(g(target)-o.location).to_track_quat('-Z','Y').to_euler()


def setup_studio():
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=64
    scene.cycles.use_denoising=False
    scene.cycles.max_bounces=6
    scene.render.threads_mode='FIXED';scene.render.threads=4
    scene.render.resolution_x=1440;scene.render.resolution_y=1080
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='AgX'
    scene.world=bpy.data.worlds.new('NeutralStudioWorld')
    scene.world.color=(.13,.13,.13)
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.39,.48,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    floor=material('StudioFloor','7e909b',0,.6)
    bevel_box('StudioGround',(0,-.045,0),(200,.08,200),floor,None,0)
    for name,at,power,size,color in [
        ('Key',(3.2,5.3,-3.4),850,5.0,(.88,.95,1)),
        ('Fill',(-3.6,3.2,-1),650,4.0,(.72,.88,1)),
        ('Rim',(1.0,4.0,3.6),1100,3.0,(1,.82,.64))]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
        o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=g(at);aim(o,(0,.6,0))
    data=bpy.data.cameras.new('ReviewCamera');o=bpy.data.objects.new('ReviewCamera',data)
    scene.collection.objects.link(o);scene.camera=o
    o.data.lens=48
    o.data.sensor_width=36;o.data.sensor_height=24
    return o


def render_view(camera,path,at,target=(0,.54,0),lens=48):
    camera.location=g(at);camera.data.lens=lens;aim(camera,target)
    bpy.context.scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument('--variant',choices=PALETTES,default='comet')
    parser.add_argument('--renders',choices=['first','all','none'],default='first')
    parser.add_argument('--samples',type=int,default=32)
    parser.add_argument('--clip',action='store_true')
    a=parser.parse_args(args)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    asset=ROOT/'assets/kart/production/karts';source=ROOT/'art/lumo_kart/blender/karts';evidence=ROOT/'evidence/lumo_kart_art/karts'/a.variant
    for p in (asset,source,evidence):p.mkdir(parents=True,exist_ok=True)
    root,mats,wheels,steering,markers=create_kart(a.variant)
    mechanical_animation(wheels,steering)
    bpy.context.view_layer.update()
    camera=setup_studio()
    bpy.context.scene.cycles.samples=max(1,a.samples)
    camera.location=g((3.1,2.25,-3.7));aim(camera,(0,.56,0))
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.context.scene.unit_settings.scale_length=1
    bpy.context.preferences.filepaths.save_version=0
    apply_modifiers(root)
    prepare_uvs(root)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/('aurora_'+a.variant+'.blend')),compress=True)
    for parent in [o for o in descendants(root) if o.type=='EMPTY']:
        batch_assembly(parent)
    bpy.context.view_layer.update()
    report=measurements(root)
    report.update({'variant':a.variant,'units':'metres','source_axes':'Blender +Y forward, +Z up','export_axes':'Godot -Z forward, +Y up','animations':['mechanical_demo'],'texture_images':[],'texture_note':'Solid PBR finishes with explicit UVs and geometric tread; no blurry image textures or shader-only export dependencies.','attachments_godot_m':markers,'wheel_radius_m':.35,'wheel_width_m':.38,'front_steer_limit_rad':.34,'authorship':'Original procedural Blender geometry and PBR materials by the LUMO team, based on existing LUMO mechanical dimensions; no third-party assets.','runtime_integration':'Standalone export; production kart_vehicle.gd is unchanged.'})
    export_glb(root,asset/('aurora_'+a.variant+'.glb'))
    (evidence/'mesh_report.json').write_text(json.dumps(report,indent=2)+'\n')
    # Explicit LOD assets keep joints/markers identical. Decimation is measured, not assumed.
    for level,ratio in ((1,.48),(2,.32)):
        duplicates=[]
        for o in descendants(root):
            if o.type!='MESH':continue
            original=o.data
            duplicates.append((o,original))
            o.data=original.copy()
            if len(o.data.polygons)>20:
                bpy.context.view_layer.objects.active=o
                m=o.modifiers.new('LOD simplification','DECIMATE');m.ratio=ratio
                bpy.ops.object.modifier_apply(modifier=m.name)
        export_glb(root,asset/('aurora_'+a.variant+'_lod'+str(level)+'.glb'))
        (evidence/('lod'+str(level)+'_report.json')).write_text(json.dumps(measurements(root),indent=2)+'\n')
        for o,original in duplicates:o.data=original
    if a.renders!='none':
        render_view(camera,evidence/'front_three_quarter.png',(3.1,2.25,-3.7))
        if a.renders=='all':
            render_view(camera,evidence/'rear_three_quarter.png',(-3.2,2.0,3.9))
            render_view(camera,evidence/'side_profile.png',(4.7,1.15,0),lens=55)
            render_view(camera,evidence/'seat_controls.png',(1.8,2.6,-1.1),(0,.82,-.06),lens=58)
            bpy.data.objects['StudioGround'].hide_render=True
            render_view(camera,evidence/'underside.png',(2.3,-1.4,-2.4),(0,.44,0),lens=48)
            bpy.data.objects['StudioGround'].hide_render=False
            # Chase-camera values are taken from the checked-in visual-grade contract.
            camera.data.sensor_fit='VERTICAL'
            bpy.context.scene.render.resolution_y=810
            render_view(camera,evidence/'chase_camera.png',(0,2.52,4.35),(0,.78,-4.15),lens=24/(2*math.tan(math.radians(55)/2)))
            camera.data.sensor_fit='AUTO'
            bpy.context.scene.render.resolution_y=1080
            bpy.context.scene.frame_set(13)
            render_view(camera,evidence/'steering_clearance.png',(2.0,2.8,-2.4),(0,.45,-.3),lens=50)
            bpy.context.scene.frame_set(1)
    if a.clip:
        frames=evidence/'clip_frames';frames.mkdir(exist_ok=True)
        scene=bpy.context.scene
        scene.render.resolution_x=800;scene.render.resolution_y=600;scene.cycles.samples=12
        scene.render.fps=24
        for f in range(96):
            t=f/96
            angle=math.tau*t-.72
            scene.frame_set(f%48+1)
            render_view(camera,frames/(str(f).zfill(4)+'.png'),(math.cos(angle)*4,2.1,math.sin(angle)*4),(0,.55,0),lens=47)
    print('LUMO_KART_EXPORT_COMPLETE '+json.dumps({'variant':a.variant,'report':str(evidence/'mesh_report.json'),'triangles':report['triangles'],'materials':report['material_count']}))


if __name__=='__main__':
    main()
