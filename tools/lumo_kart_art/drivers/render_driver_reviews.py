"""Render reproducible animation reels, original-Lumo comparisons and kart fit views."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]


def look_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--species', default='rabbit', choices=['rabbit','lion','owl','squirrel','turtle'])
    parser.add_argument('--mode', choices=['preview','front_preview','stills','reel','comparison_preview','comparison','kart_preview','kart'], required=True)
    parser.add_argument('--engine', choices=['CYCLES','BLENDER_EEVEE_NEXT'], default='CYCLES')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    driver_source=ROOT/'art/lumo_kart/blender/drivers'/(args.species+'.blend')
    driver_source_hash=hashlib.sha256(driver_source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(driver_source))
    scene = bpy.context.scene
    scene.render.engine = args.engine
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces=3
    scene.cycles.diffuse_bounces=1
    scene.cycles.glossy_bounces=2
    scene.cycles.use_adaptive_sampling=True
    scene.cycles.adaptive_threshold=.045
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 4
    scene.render.image_settings.file_format = 'PNG'
    rig = bpy.data.objects['DriverRig']
    camera = scene.camera
    evidence = ROOT / 'evidence/lumo_kart_art/drivers' / args.species
    evidence.mkdir(parents=True, exist_ok=True)
    if args.mode in ['preview','front_preview','stills']:
        rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(1)
        quick=args.mode in ['preview','front_preview']
        scene.render.resolution_x=800 if quick else 1600
        scene.render.resolution_y=850 if quick else 1500
        scene.render.resolution_percentage=100
        scene.cycles.samples=8 if quick else 48
        camera.data.type='ORTHO';camera.data.ortho_scale=2.5
        views=[('preview',(3.8,5,2.4),(0,0,1.05))] if args.mode=='preview' else [('preview_front',(0,5,1.3),(0,0,1.05))] if args.mode=='front_preview' else [('front',(0,5,1.3),(0,0,1.05)),('three_quarter',(3.8,5,2.4),(0,0,1.05)),('rear',(2.8,-5,2.35),(0,0,1.05)),('side',(5,0,1.4),(0,0,1.05))]
        for view,pos,target in views:
            camera.location=pos;look_at(camera,target)
            scene.render.filepath=str(evidence/(args.species+'_'+view+'.png'))
            bpy.ops.render.render(write_still=True)
        if args.mode=='stills':
            rig.animation_data.action=bpy.data.actions['kart_seated'];scene.frame_set(18)
            for view,pos,target in [('seated',(3.8,4.8,2.8),(0,0,1.35)),('race_camera',(0,-5,3),(0,.1,1.25))]:
                camera.location=pos;look_at(camera,target);camera.data.ortho_scale=2.8
                scene.render.filepath=str(evidence/(args.species+'_'+view+'.png'));bpy.ops.render.render(write_still=True)
    elif args.mode == 'reel':
        frames = evidence / 'reel_frames'
        frames.mkdir(exist_ok=True)
        scene.render.resolution_x = 720
        scene.render.resolution_y = 800
        scene.render.resolution_percentage = 100
        scene.cycles.samples = 8
        scene.render.fps = 12
        camera.data.type = 'ORTHO'
        camera.data.ortho_scale = 2.9
        clips = ['idle','kart_seated','kart_steer_left','kart_steer_right','kart_jump','celebrate']
        index = 0
        for clip in clips:
            action = bpy.data.actions[clip]
            rig.animation_data.action = action
            for sample in range(16):
                scene.frame_set(round(action.frame_range.x + (action.frame_range.y - action.frame_range.x) * sample / 15))
                angle = (index / 96) * math.tau
                camera.location = (5 * math.sin(angle), 5 * math.cos(angle), 2.4)
                look_at(camera, (0,0,1.25 if clip != 'idle' else 1.05))
                scene.render.filepath = str(frames / ('%04d.png' % index))
                bpy.ops.render.render(write_still=True)
                index += 1
        output = evidence / (args.species + '_animation_turntable.mp4')
        labels=[]
        for i,clip in enumerate(clips):
            labels.append("drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:text='" + args.species + " - " + clip + "':fontsize=24:fontcolor=white:box=1:boxcolor=black@0.45:x=18:y=h-48:enable='between(t," + str(i*16/12) + ',' + str((i+1)*16/12) + ")'")
        subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate','12','-i',str(frames/'%04d.png'),'-vf',','.join(labels),'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(output)],check=True)
        result=subprocess.run(['ffprobe','-v','error','-show_entries','stream=width,height,nb_frames,duration','-of','json',str(output)],check=True,capture_output=True,text=True)
        (evidence/'reel_measurement.json').write_text(result.stdout)
        # Delete only this script's intermediate frames after successful encoding and readback.
        shutil.rmtree(frames)
    elif args.mode in ['comparison','comparison_preview']:
        rig.animation_data.action = bpy.data.actions['idle']
        scene.frame_set(1)
        rig.location.x = -.83
        bpy.context.view_layer.update()
        evaluated=bpy.data.objects['DriverMesh'].evaluated_get(bpy.context.evaluated_depsgraph_get())
        data=evaluated.to_mesh()
        rabbit_vertices=[evaluated.matrix_world@v.co for v in data.vertices]
        rabbit_minimum=min(v.z for v in rabbit_vertices)
        rabbit_crown=max(v.z for v in rabbit_vertices if abs(v.x+.83)<.05)
        evaluated.to_mesh_clear()
        target_body_height=rabbit_crown-rabbit_minimum
        rig.location.z=-rabbit_minimum
        before = set(bpy.data.objects)
        before_actions = set(bpy.data.actions)
        source = ROOT / 'assets/characters/lumo_animated/Lumo-Animated-Mobile.glb'
        bpy.ops.import_scene.gltf(filepath=str(source))
        added = set(bpy.data.objects) - before
        added_actions = set(bpy.data.actions) - before_actions
        parent = bpy.data.objects.new('UnmodifiedLumoComparison',None)
        scene.collection.objects.link(parent)
        for obj in added:
            if obj.type=='MESH' and not obj.visible_get():continue
            if obj.parent not in added:
                obj.parent = parent
        for obj in added:
            if obj.type == 'ARMATURE':
                idle = next((a for a in added_actions if a.name.split('.')[0]=='idle'), None)
                if idle:
                    obj.animation_data_create()
                    obj.animation_data.action = idle
        scene.frame_set(1)
        parent.rotation_euler.z = math.pi
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        verts = []
        visible_meshes=[]
        for obj in added:
            if obj.type != 'MESH' or not obj.visible_get(): continue
            visible_meshes.append(obj)
            evaluated = obj.evaluated_get(deps)
            evaluated_mesh = evaluated.to_mesh()
            verts.extend(evaluated.matrix_world @ vertex.co for vertex in evaluated_mesh.vertices)
            evaluated.to_mesh_clear()
        minimum = min(v.z for v in verts)
        center_x = (min(v.x for v in verts)+max(v.x for v in verts))/2
        width = max(v.x for v in verts)-min(v.x for v in verts)
        crown = max(v.z for v in verts if abs(v.x-center_x)<width*.05)
        scale = target_body_height/(crown-minimum)
        parent.scale = (scale,)*3
        parent.location = (.83 - center_x * scale,0,-minimum*scale)
        bpy.context.view_layer.update()
        check=[]
        for obj in visible_meshes:
            evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            data=evaluated.to_mesh()
            check.extend(evaluated.matrix_world@v.co for v in data.vertices)
            evaluated.to_mesh_clear()
        post_minimum=min(v.z for v in check)
        post_crown=max(v.z for v in check if abs(v.x-.83)<width*.05*scale)
        assert abs(post_minimum)<.0001,('Lumo comparison floor',post_minimum)
        assert abs(post_crown-post_minimum-target_body_height)<.001,('Lumo comparison height',post_crown,post_minimum,target_body_height)
        quick=args.mode=='comparison_preview'
        scene.render.resolution_x=1000 if quick else 1900;scene.render.resolution_y=800 if quick else 1500;scene.render.resolution_percentage=100
        scene.cycles.samples=8 if quick else 48
        camera.data.type='ORTHO';camera.data.ortho_scale=3.8
        for view,pos in ([('preview',(0,7,1.25))] if quick else [('front',(0,7,1.25)),('three_quarter',(3.8,7,2.4))]):
            camera.location=pos;look_at(camera,(0,0,1.05))
            scene.render.filepath=str(evidence/('rabbit_and_original_lumo_'+view+'.png'))
            bpy.ops.render.render(write_still=True)
        report={'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'driver_source':str(driver_source.relative_to(ROOT)),'driver_source_sha256':driver_source_hash,'source_modified':False,'same_camera_and_lighting':True,'comparison_normalization':'Uniform scale from visible skinned mesh foot minimum to central head crown; long rabbit ears and hidden Blender custom-bone display Icosphere excluded. No nonuniform scaling.','original_lumo_scale':scale,'original_lumo_measured_body_height':crown-minimum,'target_body_height_m':target_body_height,'post_transform_floor_m':post_minimum,'post_transform_body_height_m':post_crown-post_minimum,'visible_source_meshes':[o.name for o in visible_meshes],'resolution':[scene.render.resolution_x,scene.render.resolution_y],'samples_max':scene.cycles.samples}
        (evidence/'comparison_measurement.json').write_text(json.dumps(report,indent=2))
    else:
        rig.animation_data.action=bpy.data.actions['kart_seated'];scene.frame_set(1)
        kart=ROOT/'assets/kart/production/karts/aurora_comet.glb'
        bpy.ops.import_scene.gltf(filepath=str(kart))
        quick=args.mode=='kart_preview'
        scene.render.resolution_x=1000 if quick else 1800;scene.render.resolution_y=850 if quick else 1500;scene.render.resolution_percentage=100
        scene.cycles.samples=8 if quick else 48
        camera.data.type='ORTHO';camera.data.ortho_scale=3.4
        for view,pos,target in ([('kart_preview',(3.5,5,3.1),(0,0,1.15))] if quick else [('kart_front',(3.5,5,3.1),(0,0,1.15)),('kart_rear',(-3.5,-5,2.8),(0,0,1.1)),('hand_contact',(2.4,2.8,1.85),(0,.23,1.1))]):
            camera.location=pos;look_at(camera,target)
            camera.data.ortho_scale=1.5 if view=='hand_contact' else 3.4
            scene.render.filepath=str(evidence/(args.species+'_'+view+'.png'))
            bpy.ops.render.render(write_still=True)


if __name__ == '__main__':main()
