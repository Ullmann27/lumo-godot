"""Render every authored driver from identical neutral studio viewpoints."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--preview',action='store_true')
    parser.add_argument('--with-karts',action='store_true',help='Show seated drivers and unchanged Comet GLBs from behind for appendage inspection.')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    spec=importlib.util.spec_from_file_location('driver_authoring',Path(__file__).with_name('build_drivers.py'))
    authoring=importlib.util.module_from_spec(spec);spec.loader.exec_module(authoring)
    camera=authoring.studio()
    scene=bpy.context.scene
    scene.render.threads=4
    scene.cycles.max_bounces=3;scene.cycles.diffuse_bounces=1;scene.cycles.glossy_bounces=2
    scene.cycles.samples=8 if args.preview else 32
    scene.cycles.use_adaptive_sampling=True
    scene.cycles.adaptive_threshold=.045
    scene.render.resolution_x=1400 if args.preview else 2800
    scene.render.resolution_y=650 if args.preview else 1300
    scene.render.resolution_percentage=100
    scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=7.1
    camera.location=(0,8,1.35);authoring.look_at(camera,(0,0,1.05))
    if args.with_karts:
        scene.render.resolution_x=1900 if args.preview else 2400
        scene.render.resolution_y=700 if args.preview else 885
        camera.data.ortho_scale=14.3
        camera.location=(0,8,4.1);authoring.look_at(camera,(0,0,1.05))
        for light in [obj for obj in scene.objects if obj.type=='LIGHT']:
            light.data.size*=2.0
            light.data.energy*=2.0
    groups=[];inputs=[]
    for index,animal in enumerate(['lion','owl','rabbit','squirrel','turtle']):
        source=ROOT/'art/lumo_kart/blender/drivers'/(animal+'.blend')
        with bpy.data.libraries.load(str(source),link=False) as (available,loaded):
            loaded.objects=[name for name in available.objects if name in ['DriverRig','DriverMesh','Grip_L','Grip_R','Foot_L','Foot_R','HeadAnchor','NeckAnchor','SeatAnchor']]
            names=list(available.actions);loaded.actions=list(names)
        objects=list(loaded.objects)
        group=bpy.data.objects.new(animal+'_ReviewPlacement',None);scene.collection.objects.link(group)
        for obj in objects:
            scene.collection.objects.link(obj)
            if obj.parent not in objects:obj.parent=group
        rig=next(obj for obj in objects if obj.type=='ARMATURE')
        action=loaded.actions[names.index('kart_seated' if args.with_karts else 'idle')]
        rig.animation_data.action=action
        if args.with_karts:
            kart=ROOT/'assets/kart/production/karts/aurora_comet.glb'
            before=set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(kart))
            added=set(bpy.data.objects)-before
            for obj in added:
                if obj.parent not in added:obj.parent=group
        group.location.x=(index-2)*(2.75 if args.with_karts else 1.27)
        scene.frame_set(1);bpy.context.view_layer.update()
        skin=next(obj for obj in objects if obj.type=='MESH')
        evaluated=skin.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh()
        minimum=min((evaluated.matrix_world@v.co).z for v in data.vertices)
        evaluated.to_mesh_clear()
        if not args.with_karts:group.location.z=-minimum
        groups.append(group)
        inputs.append({'species':animal,'blend':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
    evidence=ROOT/'evidence/lumo_kart_art/drivers';evidence.mkdir(parents=True,exist_ok=True)
    angles=[('front',0),('three_quarter',math.pi/4)] if args.preview else [('front',0),('three_quarter',math.pi/4),('side',math.pi/2),('rear',math.pi)]
    if args.with_karts:angles=[('rear_three_quarter',3*math.pi/4),('rear',math.pi)]
    prefix='roster_'+('kart_' if args.with_karts else '')+('preview_' if args.preview else '')
    for name,angle in angles:
        for group in groups:group.rotation_euler.z=angle
        scene.frame_set(1)
        scene.render.filepath=str(evidence/(prefix+name+'.png'))
        bpy.ops.render.render(write_still=True)
    report={'inputs':inputs,'engine':'Blender Cycles CPU','resolution':[scene.render.resolution_x,scene.render.resolution_y],'samples_max':scene.cycles.samples,'angles_degrees':{name:math.degrees(a) for name,a in angles},'shared_camera':True,'shared_lighting':True,'placement':'Driver and kart retain identity-relative attachment transforms. Each pair rotates about its own vertical axis.' if args.with_karts else 'Each model is rotated about its own vertical axis; shared camera remains fixed. Feet are placed on the same floor.'}
    if args.with_karts:report['kart']={'file':str(kart.relative_to(ROOT)),'sha256':hashlib.sha256(kart.read_bytes()).hexdigest()}
    (evidence/(prefix+'render.json')).write_text(json.dumps(report,indent=2))
    print('ROSTER_RENDER_PASS',len(inputs),len(angles))


if __name__=='__main__':main()
