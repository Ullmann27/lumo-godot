#!/usr/bin/env python3
"""Check rigidly weighted boot geometry against the real Blender kart coachwork."""
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from inspect_mechanics import evaluated_surface


def main():
    relative=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'assets/kart/production/drivers/rabbit/driver.glb'
    driver=ROOT/relative
    cases=[]
    source_hash=hashlib.sha256(driver.read_bytes()).hexdigest()
    kart_blend_hashes={}
    kart_glb_hashes={}
    for variant in ('comet','glider','turbo'):
        source=ROOT/'art/lumo_kart/blender/karts'/('aurora_'+variant+'.blend')
        exported=ROOT/'assets/kart/production/karts'/('aurora_'+variant+'.glb')
        kart_blend_hashes[variant]=hashlib.sha256(source.read_bytes()).hexdigest()
        kart_glb_hashes[variant]=hashlib.sha256(exported.read_bytes()).hexdigest()
        bpy.ops.wm.open_mainfile(filepath=str(source))
        body=bpy.data.objects['Coachwork']
        body_bvh,sources=evaluated_surface([o for o in body.children_recursive if o.type=='MESH'])
        previous=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(driver))
        imported=[o for o in bpy.data.objects if o not in previous]
        armature=next(o for o in imported if o.type=='ARMATURE')
        actor=next(o for o in imported if o.type=='MESH' and 'Foot.L' in o.vertex_groups)
        if armature.animation_data:
            for track in armature.animation_data.nla_tracks:track.mute=True
        rigid_indices={}
        for label in ('L','R'):
            index=actor.vertex_groups['Foot.'+label].index
            rigid_indices[label]={v.index for v in actor.data.vertices if any(w.group==index and w.weight>.999 for w in v.groups)}
        for clip in ('kart_seated','kart_steer_left','kart_steer_right','kart_jump'):
            candidates=[a for a in bpy.data.actions if a.name==clip or a.name.startswith(clip+'_') or a.name.startswith(clip+'.')]
            if len(candidates)!=1:
                raise RuntimeError('Cannot resolve exact driver clip '+clip+'; actions='+str([a.name for a in bpy.data.actions]))
            action=candidates[0]
            armature.animation_data_create();armature.animation_data.action=action
            begin,end=action.frame_range
            for fraction in (0,.5,1):
                frame=begin+(end-begin)*fraction
                bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
                bpy.context.view_layer.update()
                evaluated=actor.evaluated_get(bpy.context.evaluated_depsgraph_get())
                mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
                vertices=[evaluated.matrix_world@v.co for v in mesh.vertices]
                for label in ('L','R'):
                    indices=rigid_indices[label]
                    faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i in indices for i in t.vertices)]
                    if not faces:
                        raise RuntimeError('No rigid foot triangles for '+label)
                    bvh=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
                    hits=body_bvh.overlap(bvh)
                    points=[vertices[i] for face in faces for i in face]
                    godot=[Vector((v.x,v.z,-v.y)) for v in points]
                    cases.append({'kart':variant,'clip':clip,'clip_fraction':fraction,'foot':label,
                                  'triangles':len(faces),'bounds_godot_m':{'min':[min(v[i] for v in godot) for i in range(3)],'max':[max(v[i] for v in godot) for i in range(3)]},
                                  'intersecting_triangle_pairs':len(hits),'coachwork_parts':sorted(set(sources[a] for a,b in hits))})
                evaluated.to_mesh_clear()
    if hashlib.sha256(driver.read_bytes()).hexdigest()!=source_hash:
        raise RuntimeError('Driver export changed during inspection')
    result={'driver':relative,'driver_sha256':source_hash,'kart_blend_sha256':kart_blend_hashes,'kart_glb_sha256':kart_glb_hashes,'method':'Blender GLB import of the driver; real animation evaluation; Foot.L/R vertices with weight>0.999; BVH triangles against authored Blender kart coachwork. Kart GLB hashes identify the corresponding validated exports; this test evaluates the editable kart sources. This does not claim whole-body or human review.','cases':cases,'passed':all(c['intersecting_triangle_pairs']==0 for c in cases)}
    path=ROOT/'evidence/lumo_kart_art/karts/rabbit_boot_clearance.json'
    path.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'passed':result['passed'],'cases':len(cases),'report':str(path),'failed_cases':[c for c in cases if c['intersecting_triangle_pairs']]}))
    if not result['passed']:
        raise RuntimeError('Driver boot/coachwork intersection requires review')


if __name__=='__main__':main()
