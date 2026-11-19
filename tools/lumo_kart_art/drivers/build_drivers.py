"""Author editable LUMO rival drivers, skinned GLBs and measured review evidence.

Run with Blender 4.3+: blender -b -t 4 --python tools/lumo_kart_art/drivers/build_drivers.py -- --species rabbit
The rig is authored in the actual kart coordinate system, not scaled by a viewer.
All geometry is locally authored. No remote generation or paid API is used.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector

TAU = math.tau
ROOT = Path(__file__).resolve().parents[3]
PARTS = []
BONES = {}
MATERIALS = {}
RIG = None
HEAD_PROFILE = []
HEAD_SCALE = .84
HEAD_ATTACHMENT = Vector((0,-.015,1.42))


def srgb(hex_color):
    values = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values]


def material(name, color, roughness=0.65, metallic=0.0, sheen=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*srgb(color), 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Sheen Weight'].default_value = sheen
    m.diffuse_color = (*srgb(color), 1)
    MATERIALS[name] = m
    return m


def setup_materials(species):
    palettes = {
        'rabbit': ('AA774C', 'EED6B7', 'C77F81'),
        'lion': ('DDA04A', 'F7D9A4', '9E5330'),
        'owl': ('8D6D56', 'F5E4CB', 'B28A64'),
        'squirrel': ('BC632E', 'F5DCB9', 'D48B60'),
        'turtle': ('A2BE69', 'D8DDA0', '638B53'),
        'frog': ('53A865', 'E3E7A1', '78CF82'),
    }
    fur, cream, inner = palettes[species]
    material('Fur', fur, .82, sheen=.25)
    material('Cream', cream, .78, sheen=.20)
    material('InnerEar', inner, .8)
    material('SuitBlue', '1D5185', .74, sheen=.18)
    material('Navy', '132D49', .78)
    material('Orange', 'EB7F33', .61)
    material('Ivory', 'E7EADE', .62)
    material('Rubber', '17232A', .91)
    material('Metal', '9AABB7', .3, .76)
    material('GoggleGlass', '2471A5', .17, .35)
    material('EyeWhite', 'FBF0DE', .27)
    material('Iris', '764227' if species != 'owl' else 'B77825', .26)
    material('Pupil', '100E12', .22)
    material('Nose', 'C17E7C' if species == 'rabbit' else '46251D', .37)
    material('Mouth', '341724', .76)
    material('Tongue', 'B76372', .72)
    material('Mane', '8F4524', .81, sheen=.22)
    material('Beak', 'DB9A34', .45)


def normalize_weights(weights):
    keep = sorted(((k, max(0.0, v)) for k, v in weights.items() if v > 1e-7), key=lambda p: -p[1])[:4]
    total = sum(v for _, v in keep)
    return {k: v / total for k, v in keep}


def mesh(name, verts, faces, mat, weights='Head'):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(MATERIALS[mat])
    for poly in data.polygons:
        poly.use_smooth = True
    for i, vertex in enumerate(data.vertices):
        w = {weights: 1.0} if isinstance(weights, str) else weights(Vector(vertex.co), i)
        for bone_name, value in normalize_weights(w).items():
            group = obj.vertex_groups.get(bone_name) or obj.vertex_groups.new(name=bone_name)
            group.add([i], value, 'REPLACE')
    # A deterministic spherical UV chart exists even for solid material regions.
    uv = data.uv_layers.new(name='UVMap')
    center = sum((Vector(v) for v in verts), Vector()) / max(1, len(verts))
    for poly in data.polygons:
        for loop_index in poly.loop_indices:
            co = data.vertices[data.loops[loop_index].vertex_index].co - center
            uv.data[loop_index].uv = (.5 + math.atan2(co.y, co.x) / TAU, .5 + math.atan2(co.z, max(.00001, math.hypot(co.x, co.y))) / math.pi)
    PARTS.append(obj)
    return obj


def ellipsoid(name, center, radii, mat, bone='Head', seg=24, rings=14, rotation=None):
    c = Vector(center)
    rot = rotation or Matrix.Identity(3)
    verts = [tuple(c + rot @ Vector((0, 0, -radii[2])))]
    for j in range(1, rings):
        theta = math.pi * j / rings
        for i in range(seg):
            a = TAU * i / seg
            verts.append(tuple(c + rot @ Vector((radii[0] * math.sin(theta) * math.cos(a), radii[1] * math.sin(theta) * math.sin(a), -radii[2] * math.cos(theta)))))
    top = len(verts)
    verts.append(tuple(c + rot @ Vector((0, 0, radii[2]))))
    faces = []
    for i in range(seg):
        faces.append((0, 1 + (i + 1) % seg, 1 + i))
    for j in range(rings - 2):
        for i in range(seg):
            a = 1 + j * seg + i
            b = 1 + j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    base = 1 + (rings - 2) * seg
    for i in range(seg):
        faces.append((base + i, base + (i + 1) % seg, top))
    return mesh(name, verts, faces, mat, bone)


def tube(name, points, radii, mat, bone='Head', sides=10, caps=True):
    points = [Vector(p) for p in points]
    closed = len(points) > 2 and (points[0] - points[-1]).length < 1e-7
    if closed:
        points = points[:-1]
        if isinstance(radii, list):
            radii = radii[:-1]
    verts = []
    for i, p in enumerate(points):
        tangent = ((points[(i + 1) % len(points)] - points[(i - 1) % len(points)]) if closed else (points[min(len(points) - 1, i + 1)] - points[max(0, i - 1)])).normalized()
        ref = Vector((0, 0, 1)) if abs(tangent.z) < .9 else Vector((0, 1, 0))
        u = tangent.cross(ref).normalized()
        v = tangent.cross(u).normalized()
        r = radii[i] if isinstance(radii, list) else radii
        rx, ry = r if isinstance(r, tuple) else (r, r)
        for k in range(sides):
            a = TAU * k / sides
            verts.append(tuple(p + u * math.cos(a) * rx + v * math.sin(a) * ry))
    faces = []
    for i in range(len(points) if closed else len(points) - 1):
        for k in range(sides):
            a, b = i * sides + k, i * sides + (k + 1) % sides
            faces.append((a, b, (b + sides) % len(verts), (a + sides) % len(verts)))
    if caps and not closed:
        faces.append(tuple(range(sides - 1, -1, -1)))
        faces.append(tuple((len(points) - 1) * sides + k for k in range(sides)))
    return mesh(name, verts, faces, mat, bone)


def loft(name, profile, mat, bone='Chest', sides=32):
    # Profile entries are z, halfwidth, halfdepth, forward-center.
    verts = []
    for z, rx, ry, cy in profile:
        for i in range(sides):
            a = TAU * i / sides
            verts.append((rx * math.cos(a), cy + ry * math.sin(a), z))
    faces = []
    for j in range(len(profile) - 1):
        for i in range(sides):
            a, b = j * sides + i, j * sides + (i + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces += [tuple(range(sides - 1, -1, -1)), tuple((len(profile) - 1) * sides + i for i in range(sides))]
    return mesh(name, verts, faces, mat, bone)


def ribbon(name, points, width, mat, bone='Chest', thickness=.003):
    return tube(name, points, (width, thickness), mat, bone, sides=8)


def face_front(x,z):
    for a,b in zip(HEAD_PROFILE,HEAD_PROFILE[1:]):
        if a[0] <= z <= b[0]:
            t=(z-a[0])/(b[0]-a[0])
            _,rx,ry,cy=[a[i]*(1-t)+b[i]*t for i in range(4)]
            return cy+ry*math.sqrt(max(.01,1-(x/rx)**2))+forehead_relief(x,z)
    return .19


def forehead_relief(x,z):
    bridge=.023*math.exp(-((z-1.805)/.095)**2)*math.exp(-(x/.22)**2)
    brows=.010*math.exp(-((z-1.785)/.045)**2)*math.exp(-((abs(x)-.13)/.065)**2)
    return bridge+brows


def smooth_profile(profile,steps=4):
    output=[]
    for i in range(len(profile)-1):
        a=profile[max(0,i-1)];b=profile[i];c=profile[i+1];d=profile[min(len(profile)-1,i+2)]
        for sample in range(steps):
            t=sample/steps
            value=[.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(4)]
            value[1]=max(.001,value[1]);value[2]=max(.001,value[2]);output.append(value)
    return output+[profile[-1]]


def eye_patch(name,cx,cz,rx,rz,mat,height):
    """Closed shallow lens fitted to the actual curved skull, with no floating rim."""
    seg=32;rings=6
    verts=[(cx,height(cx,cz,0),cz)]
    for j in range(1,rings+1):
        radius=j/rings
        for i in range(seg):
            a=TAU*i/seg;x=cx+rx*radius*math.cos(a);z=cz+rz*radius*math.sin(a)
            verts.append((x,height(x,z,radius),z))
    back=len(verts);verts.append((cx,face_front(cx,cz)-.01,cz))
    faces=[]
    for i in range(seg):faces.append((0,1+i,1+(i+1)%seg))
    for j in range(rings-1):
        for i in range(seg):
            a=1+j*seg+i;b=1+j*seg+(i+1)%seg
            faces.append((a,b,b+seg,a+seg))
    edge=1+(rings-1)*seg
    for i in range(seg):faces.append((back,edge+(i+1)%seg,edge+i))
    return mesh(name,verts,faces,mat,'Head')


def smile_volume(name,y_front,y_back,mat):
    outline=[]
    for i in range(25):
        x=-.112+.224*i/24
        outline.append((x,1.455+.023*(x/.112)**2))
    for i in range(24,-1,-1):
        x=-.112+.224*i/24
        outline.append((x,1.405+.073*(x/.112)**2))
    # Exclude duplicated sharp corner endpoints to keep the cutter manifold.
    outline=outline[:-1]
    outline.pop(25)
    n=len(outline)
    verts=[(x,y,z) for y in [y_back,y_front] for x,z in outline]
    faces=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]
    for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
    return mesh(name,verts,faces,mat,'Head')


def carve_smile(surfaces,species):
    cutter=smile_volume('SmileBooleanTool',.37,.214,'Mouth')
    PARTS.remove(cutter)
    for obj in surfaces:
        bpy.context.view_layer.objects.active=obj
        modifier=obj.modifiers.new('TrueMouthCavity','BOOLEAN')
        modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        group=obj.vertex_groups.get('Head') or obj.vertex_groups.new(name='Head')
        group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
    bpy.data.objects.remove(cutter,do_unlink=True)
    smile_volume('RecessedMouthInterior',.237,.215,'Mouth')
    ellipsoid('Tongue',(0,.261,1.418),(.045,.011,.011),'Tongue','Head',20,10)
    if species in ['rabbit','squirrel']:
        for s in [-1,1]:
            ellipsoid('FrontTooth',(s*.013,.276,1.448),(.013,.010,.014),'Ivory','Head',12,8)
    else:
        ellipsoid('UpperTeeth',(0,.268,1.451),(.047,.009,.009),'Ivory','Head',20,8)


def bone_spec():
    specs = {
        'Root': ((0, 0, 0), (0, 0, .15), None),
        'Pelvis': ((0, -.07, .82), (0, -.07, .92), 'Root'),
        'Spine': ((0, -.07, .92), (0, -.075, 1.10), 'Pelvis'),
        'Chest': ((0, -.075, 1.10), (0, -.04, 1.29), 'Spine'),
        'Neck': ((0, -.04, 1.29), (0, -.015, 1.42), 'Chest'),
        'Head': ((0, -.015, 1.42), (0, -.015, 1.91), 'Neck'),
        'Tail': ((0, -.21, .89), (0, -.215, 1.03), 'Pelvis'),
    }
    for side, sign in [('L', -1), ('R', 1)]:
        shoulder = (sign * .255, -.015, 1.235)
        elbow = (sign * .325, .16, 1.04)
        hand = (sign * .16, .34, 1.055)
        specs.update({
            'UpperArm.' + side: (shoulder, elbow, 'Chest'),
            'Forearm.' + side: (elbow, hand, 'UpperArm.' + side),
            'Hand.' + side: (hand, (sign * .16, .385, 1.055), 'Forearm.' + side),
            'Thigh.' + side: ((sign * .145, -.04, .83), (sign * .165, .18, .91), 'Pelvis'),
            'Shin.' + side: ((sign * .165, .18, .91), (sign * .18, .24, .80), 'Thigh.' + side),
            'Foot.' + side: ((sign * .18, .24, .80), (sign * .18, .38, .80), 'Shin.' + side),
            'Ear.' + side: ((sign * .17, -.025, 1.87), (sign * .24, -.04, 2.37), 'Head'),
        })
    for name in ['Head','Ear.L','Ear.R']:
        head,tail,parent=specs[name]
        specs[name]=(tuple(HEAD_ATTACHMENT+(Vector(head)-HEAD_ATTACHMENT)*HEAD_SCALE),tuple(HEAD_ATTACHMENT+(Vector(tail)-HEAD_ATTACHMENT)*HEAD_SCALE),parent)
    return specs


def make_rig():
    global RIG, BONES
    BONES = bone_spec()
    data = bpy.data.armatures.new('DriverSkeleton')
    RIG = bpy.data.objects.new('DriverRig', data)
    bpy.context.collection.objects.link(RIG)
    bpy.context.view_layer.objects.active = RIG
    RIG.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (head, tail, parent) in BONES.items():
        b = data.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = data.edit_bones[parent]
        b.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')
    RIG.select_set(False)
    RIG.show_in_front = True
    RIG['coordinate_contract'] = 'Metres; +Y forward and Z up in Blender; -Z forward and Y up in Godot.'
    RIG['seat_godot'] = [0, .69, .07]
    return RIG


def torso_weights(co, _):
    z = co.z
    if z < .94:
        t = max(0, min(1, (z - .84) / .10))
        return {'Pelvis': 1 - t, 'Spine': t}
    t = max(0, min(1, (z - .97) / .24))
    return {'Spine': 1 - t, 'Chest': t}


def conform_lower_back(part):
    """Shape only the rear cloth half to the measured inner kart seat profile.

    The central shell is the strictest measured depth. Thirty millimetres of
    reserve cover cloth thickness and the existing breathing/steering motion.
    Front vertices, profile heights, widths and all skeletal coordinates stay
    fixed. The same continuous contour is applied to suit and attached belt.
    """
    # The 0.75 m endpoint continues the lowest measured segment as a design
    # allowance; only heights >=0.77 m are used, and the final meshes are tested.
    profile=[(.75,.057),(.775,.0882079),(.8,.1199999),(.825,.1475762),
             (.85,.1747999),(.875,.2013951),(.9,.2274608),(.925,.2528099),
             (.95,.2771396),(.975,.3003566),(1.0,.3195062)]
    rows={}
    for vertex in part.data.vertices:
        rows.setdefault(round(vertex.co.z,6),[]).append(vertex)
    for height,vertices in rows.items():
        if height>.96:continue
        for (h0,d0),(h1,d1) in zip(profile,profile[1:]):
            if h0<=height<=h1:
                boundary=d0+(d1-d0)*(height-h0)/(h1-h0)
                break
        else:
            raise ValueError(('Unmeasured lower-back height',part.name,height))
        maximum_depth=max(-vertex.co.y for vertex in vertices)
        factor=min(1.0,(boundary-.03)/maximum_depth)
        for vertex in vertices:
            if vertex.co.y<0:vertex.co.y*=factor
    part.data.update()


def body(species):
    suit=loft('TailoredRacingSuit', [(.77,.16,.13,-.06),(.79,.20,.15,-.06),(.86,.218,.17,-.07),(.96,.22,.165,-.07),(1.08,.238,.17,-.07),(1.20,.262,.155,-.04),(1.25,.259,.13,-.025),(1.285,.19,.108,-.02),(1.30,.13,.09,-.025)], 'SuitBlue', torso_weights, 36)
    conform_lower_back(suit)
    # Sculpted shoulder yoke and shaped ivory chest inset, not a flat decal.
    loft('FrontChestYoke', [(.94,.045,.014,.110),(1.02,.085,.014,.113),(1.18,.118,.014,.116),(1.245,.126,.014,.100),(1.27,.095,.012,.090)], 'Ivory', torso_weights, 24)
    for s in [-1, 1]:
        ribbon('OrangeSideSeam', [(s*.15,.068,.82),(s*.18,.083,.96),(s*.205,.086,1.12),(s*.21,.08,1.235)], .018, 'Orange', torso_weights)
        ribbon('CreamSidePiping', [(s*.128,.080,.83),(s*.154,.096,.98),(s*.177,.101,1.12),(s*.181,.094,1.24)], .006, 'Ivory', torso_weights)
    ribbon('Zipper', [(0,.119,.91),(0,.13,1.08),(0,.122,1.25)], .0045, 'Metal', torso_weights)
    ellipsoid('ZipPull', (.014,.143,1.215),(.014,.006,.023),'Metal','Chest',16,10)
    loft('Collar', [(1.275,.125,.095,-.025),(1.29,.127,.096,-.025),(1.335,.113,.085,-.02),(1.34,.108,.081,-.02)],'Navy','Neck',24)
    tube('CollarOrangeLip',[(.114*math.cos(TAU*i/32),-.02+.087*math.sin(TAU*i/32),1.334) for i in range(33)],.008,'Orange','Neck',8)
    belt=loft('Belt',[ (.825,.222,.171,-.07),(.833,.224,.173,-.07),(.879,.224,.173,-.07),(.886,.221,.170,-.07)],'Rubber','Pelvis',32)
    conform_lower_back(belt)
    ellipsoid('BeltBuckle',(0,.112,.855),(.060,.017,.035),'Metal','Pelvis',20,10)
    ellipsoid('BuckleInset',(0,.128,.855),(.035,.006,.021),'Orange','Pelvis',16,10)
    for s in [-1,1]:
        ellipsoid('BeltKeeper',(s*.13,.087,.857),(.013,.015,.034),'Orange','Pelvis',12,8)
    for side, s in [('L',-1),('R',1)]:
        a = Vector(BONES['UpperArm.'+side][0]); e = Vector(BONES['Forearm.'+side][0]); h = Vector(BONES['Hand.'+side][0])
        pts = [a+(e-a)*t for t in [0,.15,.40,.70,.88,1.0]] + [e+(h-e)*t for t in [.15,.40,.70,.90,1.0]]
        radii = [.089,.099,.088,.075,.069,.068,.071,.074,.067,.058,.055]
        def arm_weight(co, i, side=side):
            ring=i//16
            t=max(0,min(1,(ring-3)/4))
            return {'UpperArm.'+side:1-t,'Forearm.'+side:t}
        tube('ArticulatedSleeve.'+side,pts,radii,'SuitBlue',arm_weight,16)
        # Shoulder patch, cuff and stitching stay on their correct joint.
        ellipsoid('ShoulderPatch.'+side,a+Vector((s*.018,.04,.022)),(.078,.065,.045),'Orange','UpperArm.'+side,20,12)
        ellipsoid('ElbowReinforcement.'+side,e+Vector((s*.02,-.025,-.012)),(.069,.072,.045),'Navy','Forearm.'+side,20,12)
        wrist=h-(h-e).normalized()*.06
        tube('Cuff.'+side,[wrist-(h-e).normalized()*.025,wrist+(h-e).normalized()*.022],[.067,.062],'Ivory','Forearm.'+side,16)
        ellipsoid('GripGlove.'+side,h,(.063,.068,.057),'Navy','Hand.'+side,24,14)
        ellipsoid('GlovePad.'+side,h+Vector((0,-.025,.04)),(.046,.045,.018),'Orange','Hand.'+side,16,10)
        for digit in range(3):
            ellipsoid('Finger.'+side+str(digit),h+Vector((s*(-.037+digit*.027),.043,-.021)),(.016,.034,.025),'Navy','Hand.'+side,12,8)
        ellipsoid('Thumb.'+side,h+Vector((-s*.055,.002,-.022)),(.021,.033,.026),'Navy','Hand.'+side,14,10)
        hip=Vector(BONES['Thigh.'+side][0]);knee=Vector(BONES['Shin.'+side][0]);ankle=Vector(BONES['Foot.'+side][0])
        pts=[hip+(knee-hip)*t for t in [0,.25,.5,.75,1]]+[knee+(ankle-knee)*t for t in [.25,.5,.75,1]]
        def leg_weight(co,i,side=side):
            t=max(0,min(1,(i//16-2)/4))
            return {'Thigh.'+side:1-t,'Shin.'+side:t}
        tube('BentTrouserLeg.'+side,pts,[.10,.102,.098,.09,.085,.082,.077,.070,.065],'SuitBlue',leg_weight,16)
        ellipsoid('KneePad.'+side,knee+Vector((0,.045,.027)),(.070,.054,.035),'Rubber','Shin.'+side,20,12)
        ellipsoid('Boot.'+side,(s*.18,.24,.813),(.12,.14,.072),'SuitBlue','Foot.'+side,28,14)
        ellipsoid('BootToe.'+side,(s*.18,.325,.804),(.108,.055,.061),'Ivory','Foot.'+side,24,12)
        ellipsoid('BootSole.'+side,(s*.18,.24,.744),(.119,.14,.024),'Rubber','Foot.'+side,28,10)
        ellipsoid('BootHeel.'+side,(s*.18,.137,.808),(.096,.040,.065),'Orange','Foot.'+side,20,10)
        ribbon('BootStrap.'+side,[(s*.18-.093,.235,.85),(s*.18,.235,.879),(s*.18+.093,.235,.85)],.022,'Orange','Foot.'+side)
        for k in range(4):
            ribbon('BootTread.'+side+str(k),[(s*.18-.085,.15+k*.051,.724),(s*.18+.085,.15+k*.051,.724)],.006,'Rubber','Foot.'+side)
    ellipsoid('NeckBridge',(0,-.012,1.365),(.106,.094,.12),'Fur','Neck',24,14)


def head(species):
    global HEAD_PROFILE
    # A single closed head surface supplies jaw, forehead, cheek width and cranium.
    profile=[(1.365,.075,.09,.015),(1.395,.175,.142,.010),(1.46,.258,.184,-.005),(1.54,.316,.217,-.012),(1.64,.295,.238,-.018),(1.75,.269,.234,-.026),(1.84,.227,.198,-.039),(1.91,.145,.137,-.04),(1.94,.06,.058,-.04),(1.945,.008,.008,-.04)]
    if species=='frog':
        profile=[(z,1.08*x,y,cy) for z,x,y,cy in profile]
    elif species=='turtle':
        profile=[(z,.94*x,.99*y,cy+.015) for z,x,y,cy in profile]
    profile=smooth_profile(profile)
    HEAD_PROFILE=profile
    skull=loft('SculptedHead',profile,'Fur','Head',48)
    for vertex in skull.data.vertices:
        if vertex.co.y > -.01:
            front_blend=max(0,min(1,(vertex.co.y+.01)/.16))
            vertex.co.y+=forehead_relief(vertex.co.x,vertex.co.z)*front_blend
    skull.data.update()
    mouth_surfaces=[]
    for s in [-1,1]:
        # Rounded cream muzzle grows out of the jaw, with shallow embedded eyes.
        mouth_surfaces.append(ellipsoid('MuzzleCheek',(s*.128,.205,1.49),(.168,.095,.097),'Cream','Head',32,18))
        if species in ['rabbit','squirrel','lion','owl']:
            count=2 if species=='rabbit' else 3 if species!='owl' else 5
            for k in range(count):
                z=1.48+k*.038
                tube('CheekFurLock',[(s*.235,.109,z+.015),(s*.292,.098,z),(s*(.323+k*.008),.061,z+.009)],[.040,.032,.002],'Cream','Head',10)
    mouth_surfaces.append(ellipsoid('LowerJaw',(0,.184,1.401),(.153,.087,.057),'Cream','Head',28,14))
    if species=='owl':
        mesh('Beak',[(0,.299,1.57),(-.052,.24,1.575),(.052,.24,1.575),(0,.254,1.49),(0,.18,1.56)],[(0,1,3),(0,3,2),(0,2,1),(1,2,4),(1,4,3),(2,3,4)],'Beak','Head')
    elif species not in ['turtle','frog']:
        ellipsoid('HeartNose',(0,.296,1.535),(.052,.024,.03),'Nose','Head',24,12)
        ellipsoid('NoseTip',(0,.3,1.519),(.022,.018,.016),'Nose','Head',16,10)
        ribbon('Philtrum',[(0,.284,1.511),(0,.275,1.485)],.005,'Nose','Head')
    else:
        width = .219 if species == 'frog' else .162
        mouth_surfaces.append(ellipsoid('BroadMuzzle',(0,.245,1.505),(width,.075,.064),'Cream','Head',28,14))
        for s in [-1,1]:
            ellipsoid('Nostril',(s*.051,.3,1.548),(.008,.004,.006),'Nose','Head',12,8)
    carve_smile(mouth_surfaces,species)
    for side,s in [('L',-1),('R',1)]:
        if species=='frog':
            # Tree-frog eyes sit above the wide jaw on two raised green lobes.
            x=s*.202
            ellipsoid('EyeLobe.'+side,(x,.041,1.891),(.131,.136,.163),'Fur','Head',28,18)
            ellipsoid('EyeGold.'+side,(x,.142,1.933),(.088,.052,.083),'Iris','Head',24,16)
            ellipsoid('Pupil.'+side,(x-s*.008,.186,1.930),(.066,.015,.034),'Pupil','Head',24,14)
            ellipsoid('EyeCatchlight.'+side,(x-.025,.200,1.945),(.014,.004,.010),'EyeWhite','Head',16,10)
            for index in range(3):
                ellipsoid('CheekSpot.'+side+str(index),(s*(.156+.038*index),.279-.012*index,1.565+.015*index),(.012,.007,.010),'InnerEar','Head',12,8)
            continue
        eye_x=s*.129
        eye_z=1.708
        if species=='owl':
            eye_patch('FacialDisc.'+side,eye_x,eye_z,.135,.146,'Cream',lambda x,z,r:face_front(x,z)+.002)
        # Every contour follows the skull; only 12 mm of local corneal curvature.
        def white_height(x,z,radius,cx=eye_x,cz=eye_z):
            r2=((x-cx)/.064)**2+((z-cz)/.083)**2
            return face_front(x,z)+.004+.009*max(0,1-r2)
        eye_patch('InsetSclera.'+side,eye_x,eye_z,.064,.083,'EyeWhite',white_height)
        eye_patch('Iris.'+side,eye_x-s*.006,eye_z-.007,.044,.061,'Iris',lambda x,z,r:white_height(x,z,r)+.0015+.001*(1-r*r))
        eye_patch('Pupil.'+side,eye_x-s*.006,eye_z-.007,.027,.041,'Pupil',lambda x,z,r:white_height(x,z,r)+.0035)
        ex,ez=eye_x-s*.016,eye_z+.022
        ellipsoid('EyeCatchlight.'+side,(ex,white_height(ex,ez,0)+.005,ez),(.010,.002,.012),'EyeWhite','Head',16,10)
        ex,ez=eye_x+s*.014,eye_z-.026
        ellipsoid('EyeSoftCatchlight.'+side,(ex,white_height(ex,ez,0)+.005,ez),(.004,.002,.005),'EyeWhite','Head',12,8)
        # Flesh/fur eyelids close the sclera edge into the face.
        pts=[(eye_x+.066*math.cos(a),face_front(eye_x+.066*math.cos(a),eye_z+.085*math.sin(a))+.003,eye_z+.085*math.sin(a)) for a in [TAU*k/40 for k in range(41)]]
        tube('SocketRim.'+side,pts,.006,'Fur','Head',8)
        pts=[(eye_x+.065*math.cos(a),face_front(eye_x+.065*math.cos(a),eye_z+.084*math.sin(a))+.006,eye_z+.084*math.sin(a)) for a in [math.pi*k/20 for k in range(21)]]
        tube('UpperLid.'+side,pts,[.002+.003*math.sin(math.pi*k/20) for k in range(21)],'Nose' if species=='rabbit' else 'Navy','Head',8)
        brow=[(eye_x-.073+i*.0146,face_front(eye_x-.073+i*.0146,1.793+.023*math.sin(i*math.pi/10))+.006,1.793+.023*math.sin(i*math.pi/10)) for i in range(11)]
        tube('Eyebrow.'+side,brow,[.008+.007*math.sin(i*math.pi/10) for i in range(11)],'Mane','Head',8)
    if species=='rabbit':
        for side,s in [('L',-1),('R',1)]:
            points=[(s*(.168+.09*t),-.045-.018*t,1.84+.62*t) for t in [0,.1,.22,.4,.6,.78,.9,1]]
            radii=[(.055,.037),(.071,.045),(.082,.047),(.087,.048),(.077,.041),(.055,.032),(.031,.022),(.003,.003)]
            tube('RabbitEar.'+side,points,radii,'Fur','Ear.'+side,24)
            points2=[(s*(.168+.09*t),.002-.015*t,1.87+.55*t) for t in [0,.12,.28,.48,.67,.84,.96,1]]
            radii2=[(.017,.006),(.043,.009),(.057,.009),(.056,.009),(.045,.008),(.028,.006),(.010,.004),(.002,.002)]
            tube('EarInset.'+side,points2,radii2,'InnerEar','Ear.'+side,20)
        # The short soft tail rests in the measured gap in front of the backrest.
        # Its root remains on the lower back; it is not translated off the body.
        ellipsoid('CottonTail',(0,-.27,1.06),(.105,.04,.075),'Cream','Tail',24,16)
    elif species=='lion':
        # Overlapping tapered mane locks follow the skull with closed backs.
        for k in range(22):
            a=TAU*k/22
            x=.315*math.cos(a);z=1.66+.30*math.sin(a)
            pts=[(x*.8,-.10,z),(x*1.16,-.09,1.66+(z-1.66)*1.17),(x*1.27,-.11,1.66+(z-1.66)*1.35)]
            tube('ManeLock'+str(k),pts,[.105,.083,.006],'Mane','Head',10)
        for side,s in [('L',-1),('R',1)]:
            ellipsoid('RoundEar.'+side,(s*.275,-.014,1.85),(.092,.051,.092),'Fur','Ear.'+side,24,14)
            ellipsoid('EarInset.'+side,(s*.275,.035,1.85),(.058,.012,.059),'InnerEar','Ear.'+side,20,12)
        tube('LionTail',[(0,-.17,.915),(0,-.215,1.08),(.02,-.22,1.20),(.15,-.35,1.27),(.29,-.53,1.25),(.33,-.60,1.21)],[.025,.025,.029,.032,.027,.018],'Fur','Tail',12)
        ellipsoid('TailTuft',(.33,-.60,1.21),(.057,.05,.074),'Mane','Tail',20,12)
    elif species=='squirrel':
        for side,s in [('L',-1),('R',1)]:
            tube('SquirrelEar.'+side,[(s*.22,-.04,1.84),(s*.26,-.025,2.0),(s*.26,-.04,2.12)],[.082,.065,.004],'Fur','Ear.'+side,20)
            tube('EarInset.'+side,[(s*.22,.027,1.88),(s*.25,.026,2.0),(s*.26,-.01,2.08)],[.043,.036,.003],'InnerEar','Ear.'+side,16)
        tail=[(0,-.17,.915),(.025,-.215,1.08),(.05,-.225,1.20),(.08,-.26,1.30),(.12,-.39,1.46),(.10,-.49,1.66),(-.04,-.47,1.80),(-.18,-.40,1.74),(-.18,-.36,1.62)]
        tube('CurledSquirrelTail',tail,[.025,.028,.037,.062,.15,.19,.17,.12,.008],'Fur','Tail',24)
        tube('TailCreamRidge',[(x,y-.115,z) for x,y,z in tail[4:-1]],[.035,.07,.065,.01],'Cream','Tail',16)
    elif species=='owl':
        for side,s in [('L',-1),('R',1)]:
            for k in range(4):
                tube('OwlEarFeather.'+side+str(k),[(s*(.19+k*.018),-.06,1.85),(s*(.27+k*.02),-.06,2.00+k*.025),(s*(.30+k*.02),-.08,2.07+k*.035)],[.051,.029,.002],'Fur','Ear.'+side,10)
            for k in range(7):
                ellipsoid('WingFeather.'+side+str(k),(s*(.27+.012*k),-.09,1.14-k*.046),(.052,.055,.095),'Fur','UpperArm.'+side,16,10,Matrix.Rotation(s*.25,3,'Y'))
        for k in range(5):
            ellipsoid('TailFeather'+str(k),((k-2)*.038,-.22,1.06),(.033,.014,.13),'Fur','Tail',16,12)
    elif species=='turtle':
        ellipsoid('ShellRim',(0,-.225,1.12),(.282,.095,.323),'Cream','Chest',32,20)
        ellipsoid('Shell',(0,-.29,1.13),(.256,.115,.30),'Navy','Chest',32,20)
        for k in range(6):
            a=TAU*k/6
            ellipsoid('ShellScute'+str(k),(.16*math.sin(a),-.36,1.13+.20*math.cos(a)),(.098,.034,.119),'Orange' if k%2==0 else 'SuitBlue','Chest',20,14)
        ellipsoid('CenterScute',(0,-.402,1.13),(.112,.022,.138),'SuitBlue','Chest',24,16)
        # Pull the lower shell into the real torso outline. Keep the upper dome
        # above the measured 1.115 m backrest while preserving a connected shell.
        for part in PARTS:
            if part.name.startswith(('ShellRim','ShellScute','CenterScute')) or part.name=='Shell':
                for vertex in part.data.vertices:
                    t=max(0,min(1,(vertex.co.z-1.10)/.18));t=t*t*(3-2*t)
                    vertex.co.x*=.48+.52*t
                    lower_back=.225-min(.14,max(0,.95-vertex.co.z))
                    vertex.co.y=-lower_back+(vertex.co.y+.225)*(.10+.90*t)
                part.data.update()
    if species!='frog':
        goggles(species)


def goggles(species):
    # One wraparound strap and shaped individual lens housings sit above the brows.
    points=[(.241*math.cos(TAU*i/64),-.037+.201*math.sin(TAU*i/64),1.837) for i in range(65)]
    tube('GoggleStrap',points,(.025,.012),'Navy','Head',8)
    for s in [-1,1]:
        cx=s*.117
        ellipsoid('GoggleHousing',(cx,.172,1.893),(.102,.045,.068),'Rubber','Head',28,16)
        ellipsoid('GoggleLens',(cx,.211,1.900),(.084,.017,.048),'GoggleGlass','Head',32,18)
        pts=[(cx+.090*math.cos(TAU*i/40),.211,1.896+.055*math.sin(TAU*i/40)) for i in range(41)]
        tube('MetalLensRim',pts,.011,'Metal','Head',8)
        ellipsoid('GoggleBuckle',(s*.235,.103,1.852),(.024,.026,.031),'Orange','Head',16,10)
        ribbon('LensReflection',[(cx-.044,.229,1.917),(cx-.016,.230,1.934),(cx+.011,.227,1.932)],.005,'Ivory','Head')
    tube('GoggleBridge',[(-.032,.187,1.905),(0,.201,1.914),(.032,.187,1.905)],.015,'Metal','Head',10)


def joined_mesh():
    # The original-Lumo same-height review requires a smaller rival head group.
    # Scale only head/ear-weighted components around the head-neck attachment.
    # Shells, tails, owl wings, torso, pelvis, grips and boots remain untouched.
    for part in PARTS:
        relevant={group.index for group in part.vertex_groups if group.name in ['Head','Ear.L','Ear.R']}
        if relevant:
            for vertex in part.data.vertices:
                amount=sum(group.weight for group in vertex.groups if group.group in relevant)
                if amount>.999:
                    vertex.co=HEAD_ATTACHMENT+(vertex.co-HEAD_ATTACHMENT)*HEAD_SCALE
            part.data.update()
    bpy.ops.object.select_all(action='DESELECT')
    for p in PARTS:
        p.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name='DriverMesh'
    obj.data.name='DriverSurface'
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bmesh.ops.dissolve_degenerate(bm,dist=1e-8,edges=list(bm.edges))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    obj.parent=RIG
    mod=obj.modifiers.new('NormalizedSkin','ARMATURE')
    mod.object=RIG
    obj['skin_contract']='Every vertex has one to four normalized deform weights. Rigid face details use Head; sleeves and trousers blend adjacent bones.'
    obj['eye_sclera_width_height_m']=[.128*HEAD_SCALE,.166*HEAD_SCALE]
    obj['maximum_local_cornea_protrusion_m']=.013*HEAD_SCALE
    obj['head_width_m']=max(row[1] for row in HEAD_PROFILE)*2*HEAD_SCALE
    obj['head_proportion_scale']=HEAD_SCALE
    return obj


def consolidate_finishes(obj):
    """Retain exact palette in vertex colors while reducing material draw surfaces."""
    groups = {
        'Organic': (['Fur','Cream','InnerEar','Mane','Mouth','Tongue'], .79, .0, .2),
        'Fabric': (['SuitBlue','Navy','Orange','Ivory'], .71, .0, .15),
        'Rubber': (['Rubber'], .91, .0, .0),
        'Metal': (['Metal'], .3, .76, .0),
        'Glass': (['GoggleGlass'], .17, .35, .0),
        'Face': (['EyeWhite','Iris','Pupil','Nose','Beak'], .30, .0, .0),
    }
    colors=obj.data.color_attributes.new(name='Palette',type='BYTE_COLOR',domain='CORNER')
    mapping={}
    new_materials=[]
    for name,(sources,rough,metal,sheen) in groups.items():
        mat=material('Finish_'+name,'FFFFFF',rough,metal,sheen)
        attribute=mat.node_tree.nodes.new('ShaderNodeVertexColor');attribute.layer_name='Palette'
        mat.node_tree.links.new(attribute.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        new_materials.append(mat)
        for source in sources:mapping[source]=len(new_materials)-1
    indices=[]
    for poly in obj.data.polygons:
        old_mat=obj.data.materials[poly.material_index]
        old_color=old_mat.diffuse_color
        for li in poly.loop_indices:colors.data[li].color=old_color
        indices.append(mapping[old_mat.name])
    obj.data.materials.clear()
    for mat in new_materials:obj.data.materials.append(mat)
    for poly,index in zip(obj.data.polygons,indices):poly.material_index=index
    obj.data.color_attributes.active_color=colors
    for family in ['Organic','Fabric']:
        size=512
        v,u=np.mgrid[0:size,0:size].astype(np.float32)/size
        if family=='Organic':
            height=.18*np.sin(TAU*(71*u+1.1*np.sin(TAU*3*v)))+.05*np.sin(TAU*(113*u+7*v))
        else:
            height=.10*np.cos(TAU*64*u)+.10*np.cos(TAU*64*v)+.06*np.cos(TAU*32*u)*np.cos(TAU*32*v)
        dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.5
        dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.5
        normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1)
        normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
        rgba=np.ones((size,size,4),dtype=np.float32);rgba[:,:,:3]=normal*.5+.5
        image=bpy.data.images.new('LUMO_'+family+'_MicroNormal',width=size,height=size,alpha=False)
        image.colorspace_settings.name='Non-Color'
        image.pixels.foreach_set(rgba.ravel());image.update();image.pack()
        mat=bpy.data.materials['Finish_'+family]
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.extension='REPEAT'
        bump=mat.node_tree.nodes.new('ShaderNodeNormalMap');bump.uv_map='UVMap'
        bump.inputs['Strength'].default_value=.42 if family=='Organic' else .32
        mat.node_tree.links.new(tex.outputs['Color'],bump.inputs['Color'])
        mat.node_tree.links.new(bump.outputs['Normal'],mat.node_tree.nodes['Principled BSDF'].inputs['Normal'])


def matrix_for_segment(head,tail):
    head,tail=Vector(head),Vector(tail)
    y=(tail-head).normalized()
    ref=Vector((0,0,1)) if abs(y.z)<.95 else Vector((0,1,0))
    x=y.cross(ref).normalized()
    z=x.cross(y).normalized()
    return Matrix(((x.x,y.x,z.x,head.x),(x.y,y.y,z.y,head.y),(x.z,y.z,z.z,head.z),(0,0,0,1)))


def solve_joint(start,end,length_a,length_b,pole):
    """Two-segment IK with constant physical bone lengths and a stable pole."""
    delta=end-start
    distance=max(1e-6,min(delta.length,length_a+length_b-1e-6))
    axis=delta.normalized()
    along=(length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
    radius=math.sqrt(max(0,length_a*length_a-along*along))
    perpendicular=Vector(pole)-axis*Vector(pole).dot(axis)
    if perpendicular.length<1e-6:perpendicular=axis.cross(Vector((0,0,1)))
    return start+axis*along+perpendicular.normalized()*radius


def limb_lengths(side,upper,lower):
    a,b,_=BONES[upper+'.'+side]
    c,d,_=BONES[lower+'.'+side]
    return (Vector(b)-Vector(a)).length,(Vector(d)-Vector(c)).length


def posed_points(clip,t):
    p={n:[Vector(a),Vector(b)] for n,(a,b,parent) in BONES.items()}
    breath=math.sin(TAU*t)*.006
    steer=0.0
    if clip=='kart_steer_left':steer=math.sin(math.pi*min(1,t/.25)/2) if t<.25 else 1.0 if t<.75 else math.cos(math.pi*(t-.75)/.25/2)
    if clip=='kart_steer_right':steer=-(math.sin(math.pi*min(1,t/.25)/2) if t<.25 else 1.0 if t<.75 else math.cos(math.pi*(t-.75)/.25/2))
    if clip=='idle':
        shift=Vector((0,0,-.43+breath))
        for n in p:
            if n!='Root':p[n]=[v+shift for v in p[n]]
        for side,s in [('L',-1),('R',1)]:
            hip=p['Thigh.'+side][0]
            ankle=Vector((s*.17,.005,.08))
            l1,l2=limb_lengths(side,'Thigh','Shin')
            knee=solve_joint(hip,ankle,l1,l2,(s*.1,1,0))
            hand=Vector((s*(.33+.006*math.sin(TAU*t)),.018,.36))
            shoulder=p['UpperArm.'+side][0]
            l1,l2=limb_lengths(side,'UpperArm','Forearm')
            elbow=solve_joint(shoulder,hand,l1,l2,(s,.2,-.1))
            p['Thigh.'+side]=[hip,knee]
            p['Shin.'+side]=[knee,ankle]
            p['Foot.'+side]=[ankle,ankle+Vector((0,.14,0))]
            p['UpperArm.'+side]=[p['UpperArm.'+side][0],elbow]
            p['Forearm.'+side]=[elbow,hand]
            p['Hand.'+side]=[hand,hand+Vector((0,.045,0))]
    else:
        lean=Vector((-steer*.022,0,breath))
        bounce=math.sin(math.pi*t)*.045 if clip=='kart_jump' else 0
        lean.z+=bounce
        for n in ['Spine','Chest','Neck','Head','Ear.L','Ear.R']:
            p[n]=[v+lean for v in p[n]]
        for side,s in [('L',-1),('R',1)]:
            shoulder=Vector(BONES['UpperArm.'+side][0])+lean
            hand=Vector(BONES['Hand.'+side][0])
            if steer:
                axis=Vector((0,-math.cos(.45),math.sin(.45)))
                hand=Vector((0,.33,1.035))+Quaternion(axis,-steer*.4)@(hand-Vector((0,.33,1.035)))
            if clip=='celebrate':
                lift=math.sin(math.pi*t)**2
                hand+=Vector((s*.07,-.20,.51))*lift
            l1,l2=limb_lengths(side,'UpperArm','Forearm')
            pole=Vector(BONES['Forearm.'+side][0])-Vector(BONES['UpperArm.'+side][0])
            elbow=solve_joint(shoulder,hand,l1,l2,pole)
            p['UpperArm.'+side]=[shoulder,elbow]
            p['Forearm.'+side]=[elbow,hand]
            p['Hand.'+side]=[hand,hand+Vector((0,.045,0))]
        # Head turns slightly into a bend; ears lag instead of moving as one block.
        head_rot=Matrix.Rotation(-steer*.12,4,'Z')
        pivot=p['Head'][0]
        p['Head'][1]=pivot+head_rot.to_3x3()@(p['Head'][1]-pivot)
    for side,s in [('L',-1),('R',1)]:
        h,tail=p['Ear.'+side]
        p['Ear.'+side][1]=h+Matrix.Rotation(s*.035*math.sin(TAU*t+.3)+steer*.04,3,'Y')@(tail-h)
    p['Tail'][1]+=Vector((.015*math.sin(TAU*t),0,.01*math.cos(TAU*t)))
    return p


def animate():
    RIG.animation_data_create()
    scene=bpy.context.scene
    scene.render.fps=24
    durations={'idle':72,'kart_seated':72,'kart_steer_left':48,'kart_steer_right':48,'kart_jump':36,'celebrate':72}
    rests={n:b.matrix_local.copy() for n,b in RIG.data.bones.items()}
    contacts={}
    for clip,length in durations.items():
        action=bpy.data.actions.new(clip)
        RIG.animation_data.action=action
        max_error=0.0
        for frame in range(1,length+1,3):
            scene.frame_set(frame)
            t=(frame-1)/(length-1)
            desired=posed_points(clip,t)
            target_matrices={}
            for name in BONES:
                if name=='Root':
                    target_matrices[name]=rests[name]
                else:
                    h,tail=desired[name]
                    rest_h,rest_t,_=BONES[name]
                    rest_dir=Vector(rest_t)-Vector(rest_h)
                    posed_dir=tail-h
                    delta=rest_dir.rotation_difference(posed_dir)
                    mat=Matrix.Translation(h)@delta.to_matrix().to_4x4()@Matrix.Translation(-Vector(rest_h))@rests[name]
                    # Keep constant-length rotation bones: parent nonuniform scaling
                    # would create unrepresentable shear and break exported hand contact.
                    target_matrices[name]=mat
            for name in BONES:
                bone=RIG.pose.bones[name]
                bone.rotation_mode='QUATERNION'
                parent_name=BONES[name][2]
                if parent_name:
                    bone.matrix_basis=rests[name].inverted()@rests[parent_name]@target_matrices[parent_name].inverted()@target_matrices[name]
                else:
                    bone.matrix_basis=rests[name].inverted()@target_matrices[name]
                bone.keyframe_insert('location',frame=frame,group=name)
                bone.keyframe_insert('rotation_quaternion',frame=frame,group=name)
                bone.keyframe_insert('scale',frame=frame,group=name)
            bpy.context.view_layer.update()
            if clip in ['kart_seated','kart_steer_left','kart_steer_right','kart_jump']:
                for side in ['L','R']:
                    actual=RIG.pose.bones['Hand.'+side].matrix.translation
                    max_error=max(max_error,(actual-desired['Hand.'+side][0]).length)
        # Close every action at its exact endpoint, not one sample short.
        scene.frame_set(1)
        for name in BONES:
            bone=RIG.pose.bones[name]
            for path in ['location','rotation_quaternion','scale']:
                bone.keyframe_insert(path,frame=length,group=name)
        for fc in action.fcurves:
            for key in fc.keyframe_points:
                key.interpolation='BEZIER' if clip in ['idle','kart_seated'] else 'LINEAR'
        action.use_fake_user=True
        contacts[clip]={'frames':length,'fps':24,'duration_s':(length-1)/24,'sampled_max_hand_origin_error_m':max_error}
    RIG.animation_data.action=bpy.data.actions['kart_seated']
    scene.frame_set(1)
    scene.frame_start=1;scene.frame_end=72
    return contacts


def make_markers():
    for name,bone_name in [('Grip_L','Hand.L'),('Grip_R','Hand.R'),('Foot_L','Foot.L'),('Foot_R','Foot.R'),('HeadAnchor','Head'),('NeckAnchor','Head')]:
        obj=bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(obj)
        obj.empty_display_size=.025
        obj.parent=RIG
        obj.parent_type='BONE'
        obj.parent_bone=bone_name
        obj.location=(0,-RIG.data.bones[bone_name].length,0)
        obj['bone_origin_marker']=bone_name
    seat=bpy.data.objects.new('SeatAnchor',None)
    bpy.context.collection.objects.link(seat)
    seat.parent=RIG
    seat.location=(0,-.07,.69)
    seat.empty_display_size=.06


def measured_mesh(obj):
    obj.data.calc_loop_triangles()
    weights=[]
    for v in obj.data.vertices:
        weights.append(sum(g.weight for g in v.groups))
    bm=bmesh.new();bm.from_mesh(obj.data)
    bad_edges=sum(1 for e in bm.edges if not e.is_manifold)
    bm.free()
    return {'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),'materials':len(obj.data.materials),'nonmanifold_edges':bad_edges,'zero_weight_vertices':sum(w<.999 for w in weights),'max_weight_sum_error':max(abs(w-1) for w in weights),'max_influences':max(len(v.groups) for v in obj.data.vertices),'evaluated_dimensions_blender_m':list(obj.dimensions)}


def export_models(obj,outdir):
    outdir.mkdir(parents=True,exist_ok=True)
    results={}
    for level,ratio in [(0,1.0),(1,.57),(2,.29)]:
        if level==0:
            target=obj
        else:
            target=obj.copy();target.data=obj.data.copy();bpy.context.collection.objects.link(target)
            target.name='DriverMesh_LOD'+str(level)
            # Apply decimation before the armature, preserving weights and materials.
            arm=target.modifiers.get('NormalizedSkin')
            if arm: target.modifiers.remove(arm)
            dec=target.modifiers.new('SilhouetteLOD','DECIMATE');dec.ratio=ratio
            bpy.context.view_layer.objects.active=target
            bpy.ops.object.modifier_apply(modifier=dec.name)
            arm=target.modifiers.new('NormalizedSkin','ARMATURE');arm.object=RIG
        bpy.ops.object.select_all(action='DESELECT')
        RIG.select_set(True);target.select_set(True)
        for c in RIG.children:
            if c.type=='EMPTY':c.select_set(True)
        filename='driver.glb' if level==0 else 'driver_lod'+str(level)+'.glb'
        bpy.context.view_layer.objects.active=RIG
        bpy.ops.export_scene.gltf(filepath=str(outdir/filename),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_skins=True,export_all_influences=False,export_apply=False,export_extras=True,export_def_bones=False,export_materials='EXPORT',export_cameras=False,export_lights=False)
        results['lod'+str(level)]=measured_mesh(target)
        results['lod'+str(level)]['file']=str((outdir/filename).relative_to(ROOT))
        results['lod'+str(level)]['sha256']=hashlib.sha256((outdir/filename).read_bytes()).hexdigest()
        if level: bpy.data.objects.remove(target,do_unlink=True)
    return results


def look_at(obj,point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()


def studio():
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.device='CPU'
    scene.cycles.samples=28
    scene.cycles.use_denoising=False
    scene.render.threads_mode='FIXED';scene.render.threads=4
    scene.render.resolution_x=1600;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.film_transparent=False
    scene.world.color=(.19,.22,.26)
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.21,.25,.31,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
    scene.view_settings.view_transform='AgX'
    for name,location,power,color,size in [('Key',(-3,4,5),650,(1,.86,.72),4),('Fill',(4,2,3),500,(.70,.83,1),3),('Rim',(1,-3,4),750,(.75,.85,1),2.5)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
        ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);ob.location=location;look_at(ob,(0,0,1))
    floor_mat=material('StudioFloor','BCC6CB',.8)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015))
    floor=bpy.context.object;floor.name='ReviewFloor';floor.data.materials.append(floor_mat)
    data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',data);bpy.context.collection.objects.link(camera)
    camera.data.type='ORTHO';camera.data.ortho_scale=2.75;scene.camera=camera
    return camera


def render_review(species,evidence,camera):
    scene=bpy.context.scene
    RIG.animation_data.action=bpy.data.actions['idle'];scene.frame_set(1)
    views={'front':((0,5,1.35),(0,0,1.05)),'three_quarter':((3.8,5,2.45),(0,0,1.07)),'rear':((2.8,-5,2.35),(0,0,1.05)),'side':((5,0,1.4),(0,0,1.05))}
    for name,(position,target) in views.items():
        camera.location=position;look_at(camera,target)
        scene.render.filepath=str(evidence/(species+'_'+name+'.png'))
        bpy.ops.render.render(write_still=True)
    RIG.animation_data.action=bpy.data.actions['kart_seated'];scene.frame_set(18)
    camera.location=(3.8,4.8,2.8);look_at(camera,(0,0,1.35));camera.data.ortho_scale=2.8
    scene.render.filepath=str(evidence/(species+'_seated.png'));bpy.ops.render.render(write_still=True)
    camera.location=(0,-5,3.0);look_at(camera,(0,.1,1.25));camera.data.type='PERSP';camera.data.lens=48
    scene.render.filepath=str(evidence/(species+'_race_camera.png'));bpy.ops.render.render(write_still=True)
    camera.data.type='ORTHO';camera.data.ortho_scale=2.75
    camera.location=(3.8,5,2.45);look_at(camera,(0,0,1.07))


def main():
    argv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument('--species',choices=['rabbit','lion','owl','squirrel','turtle','frog'],default='rabbit')
    parser.add_argument('--no-render',action='store_true')
    args=parser.parse_args(argv)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    species=args.species
    out=ROOT/'assets/kart/production/drivers'/species
    evidence=ROOT/'evidence/lumo_kart_art/drivers'/species;evidence.mkdir(parents=True,exist_ok=True)
    blends=ROOT/'art/lumo_kart/blender/drivers';blends.mkdir(parents=True,exist_ok=True)
    setup_materials(species);make_rig();body(species);head(species)
    obj=joined_mesh();consolidate_finishes(obj);contacts=animate();make_markers()
    metrics=export_models(obj,out)
    camera=studio()
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(blends/(species+'.blend')),compress=True)
    if not args.no_render:render_review(species,evidence,camera)
    RIG.animation_data.action=bpy.data.actions['kart_seated'];bpy.context.scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(blends/(species+'.blend')),compress=True)
    textures=[{'name':image.name,'width':image.size[0],'height':image.size[1],'packed_bytes':image.packed_file.size,'sha256':hashlib.sha256(image.packed_file.data).hexdigest()} for image in bpy.data.images if image.packed_file]
    report={'species':species,'authoring':'Local Blender Python mesh construction; reference-guided original LUMO rival art. No external generation.','blender':bpy.app.version_string,'runtime_integrated':False,'axes':{'blender':'X right,+Y forward,Z up','godot':'X right,Y up,-Z forward'},'units':'metres','rig':'DriverRig','bones':list(BONES),'markers':['Grip_L','Grip_R','Foot_L','Foot_R','SeatAnchor','HeadAnchor'],'animations':contacts,'lods':metrics,'texture_images':textures,'material_policy':'Six PBR finishes with per-vertex palette colors and two locally authored 512px periodic micro-normal maps, packed in Blender and embedded in GLB.','reference_paths':['assets/characters/rivals/reference/inputs/'+species+'-front.jpg','assets/characters/rivals/reference/inputs/'+species+'-material.jpg'],'eye_scale':{'sclera_width_m':.128,'sclera_height_m':.166,'maximum_local_sclera_protrusion_m':.013,'head_width_m':.632,'comment':'Eye surfaces follow the measured curved skull; closed shallow cornea geometry and attached lids replace protruding globes.'},'proof_limit':'Blender render and mesh measurements only. Godot and Android tests must be reported separately.'}
    report['markers'].append('NeckAnchor')
    roster=json.loads((ROOT/'assets/characters/rivals/roster.json').read_text())
    rival=next(entry for entry in roster['opponents'] if entry['id']==species)
    report['reference_paths']=list(dict.fromkeys('assets/characters/rivals/'+rival[key] for key in ['geometryInput','materialInput'] if key in rival))
    if species=='frog':
        report['authoring']='New original tree frog authored with the existing LUMO driver rig. No recovered Frog Blender source or external reference.'
        report['eye_scale']={'comment':'Raised tree-frog eye lobes with gold horizontal pupils.'}
    for reference in report['reference_paths']:
        if not (ROOT/reference).is_file():raise FileNotFoundError(reference)
    for clip in report['animations'].values():
        clip['exported_first_key_s']=1.0/clip['fps']
        clip['active_key_span_s']=clip['duration_s']
        clip['godot_clip_length_s']=clip['frames']/clip['fps']
    report['head_proportion_scale']=HEAD_SCALE
    report['head_scale_attachment_blender_m']=list(HEAD_ATTACHMENT)
    if species!='frog':
        report['eye_scale'].update({'sclera_width_m':.128*HEAD_SCALE,'sclera_height_m':.166*HEAD_SCALE,'maximum_local_sclera_protrusion_m':.013*HEAD_SCALE,'head_width_m':max(row[1] for row in HEAD_PROFILE)*2*HEAD_SCALE})
    (evidence/'measurement.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('DRIVER_BUILD_COMPLETE',json.dumps({'species':species,'files':metrics,'blend':str(blends/(species+'.blend'))}))


if __name__=='__main__':main()
