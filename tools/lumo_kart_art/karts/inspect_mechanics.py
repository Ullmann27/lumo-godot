#!/usr/bin/env python3
"""Numerically inspect the authored Blender assembly, including steering sweep.

Run with Blender, not system Python. BVH tests intersect actual evaluated triangles;
they are deliberately limited to tyre/coachwork contacts, excluding intended joints.
"""
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
G_TO_B=Matrix(((1,0,0),(0,0,-1),(0,1,0)))


def evaluated_surface(objects):
    verts,faces,face_sources=[],[],[]
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated=obj.evaluated_get(depsgraph)
        mesh=evaluated.to_mesh()
        mesh.calc_loop_triangles()
        offset=len(verts)
        verts.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
        for tri in mesh.loop_triangles:
            faces.append(tuple(offset+i for i in tri.vertices))
            face_sources.append(obj.name)
        evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(verts,faces,all_triangles=True),face_sources


def inspect(variant):
    path=ROOT/'art/lumo_kart/blender/karts'/('aurora_'+variant+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    root=bpy.data.objects['Aurora_'+variant]
    body=bpy.data.objects['Coachwork']
    bpy.context.scene.frame_set(1)
    body_surface,sources=evaluated_surface([o for o in body.children_recursive if o.type=='MESH'])
    result={'variant':variant,'method':'Evaluated Blender triangles; BVH surface intersection at seven steering samples; dimensions from source mechanical contract.','tyre_coachwork_intersections':[],'pivot_errors_m':{},'grip_rest_errors_m':{},'forward_axis_godot':'-Z','source_file':str(path.relative_to(ROOT))}
    for axle,z in (('F',-.66),('R',.66)):
        for label,side in (('L',-1),('R',1)):
            name=axle+label
            pivot=bpy.data.objects['Steer_'+name]
            rotor=bpy.data.objects['Wheel_'+name]
            # Disable the demonstration clip only during the independent sweep.
            pivot.animation_data_clear()
            rotor.animation_data_clear()
            rotor.rotation_euler=(0,0,0)
            expected=G_TO_B@Vector((side*.77*float(root.get('stance_multiplier',1)),.35,z))
            result['pivot_errors_m'][name]=(pivot.matrix_world.translation-expected).length
            tyres=[o for o in rotor.children if o.name.startswith('TyreClosedDirectional')]
            for angle in (-.34,-.2267,-.1133,0,.1133,.2267,.34) if axle=='F' else (0,):
                pivot.rotation_euler.z=angle
                bpy.context.view_layer.update()
                surface,_=evaluated_surface(tyres)
                hits=body_surface.overlap(surface)
                result['tyre_coachwork_intersections'].append({'wheel':name,'steer_rad':angle,'triangle_pairs':len(hits),'coachwork_parts':sorted(set(sources[a] for a,b in hits))})
            pivot.rotation_euler.z=0
    for side,label in ((-1,'L'),(1,'R')):
        marker=bpy.data.objects['Grip_'+label]
        expected=G_TO_B@Vector((side*.16,1.055,-.34))
        result['grip_rest_errors_m'][label]=(marker.matrix_world.translation-expected).length
    result['passed']=all(x['triangle_pairs']==0 for x in result['tyre_coachwork_intersections']) and max(result['pivot_errors_m'].values())<1e-6 and max(result['grip_rest_errors_m'].values())<1e-6
    out=ROOT/'evidence/lumo_kart_art/karts'/variant/'mechanical_clearance.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print('LUMO_KART_MECHANICAL_CHECK '+json.dumps(result))
    if not result['passed']:
        raise RuntimeError('Tyre/coachwork or marker contract requires repair; see mechanical_clearance.json')


if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['comet']
    inspect(args[0])
