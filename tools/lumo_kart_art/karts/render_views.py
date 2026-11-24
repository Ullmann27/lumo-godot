#!/usr/bin/env python3
"""Render specified genuine Blender review cameras from saved, editable sources."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
VIEWS={
    'front_three_quarter':((3.1,2.25,-3.7),(0,.54,0),48),
    'rear_three_quarter':((-3.2,2.0,3.9),(0,.54,0),48),
    'side_profile':((4.7,1.15,0),(0,.54,0),55),
    'seat_controls':((1.8,2.6,-1.1),(0,.82,-.06),58),
    'underside':((2.3,-1.4,-2.4),(0,.44,0),48),
    'steering_clearance':((2.0,2.8,-2.4),(0,.45,-.3),50),
    'chase_camera':((0,2.52,4.35),(0,.78,-4.15),24/(2*math.tan(math.radians(55)/2))),
    # Nahaufnahmen für die Garage: Reifenschrift/Bremse, Startnummer, Cockpit, Heck.
    'closeup_wheel':((2.05,.78,-1.5),(.77,.35,-.66),50),
    'closeup_sidepod':((1.95,.75,.35),(.6,.33,.0),55),
    'closeup_cockpit':((.42,1.32,.78),(0,.62,-.12),42),
    'closeup_rear':((.75,1.0,2.15),(0,.55,1.0),50),
    'closeup_nose':((-.7,1.05,-2.15),(0,.35,-1.0),50),
}


def g(p):
    return Vector((p[0],-p[2],p[1]))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--variant',default='comet')
    parser.add_argument('--views',default='rear_three_quarter,side_profile,seat_controls,underside,chase_camera,steering_clearance')
    parser.add_argument('--samples',type=int,default=32)
    parser.add_argument('--width',type=int,default=1440)
    parser.add_argument('--out',default='')
    a=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    source=ROOT/'art/lumo_kart/blender/karts'/('aurora_'+a.variant+'.blend')
    source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    s=bpy.context.scene
    s.render.engine='CYCLES';s.cycles.samples=max(1,a.samples);s.cycles.use_denoising=False
    s.render.threads_mode='FIXED';s.render.threads=3
    s.render.image_settings.file_format='PNG';s.render.resolution_percentage=100
    camera=s.camera
    camera.data.sensor_width=36;camera.data.sensor_height=24
    evidence=Path(a.out) if a.out else ROOT/'evidence/lumo_kart_art/karts'/a.variant
    evidence.mkdir(parents=True,exist_ok=True)
    for name in a.views.split(','):
        at,target,lens=VIEWS[name]
        s.frame_set(13 if name=='steering_clearance' else 1)
        s.render.resolution_x=a.width
        s.render.resolution_y=round(a.width*(9/16 if name=='chase_camera' else 3/4))
        camera.data.sensor_fit='VERTICAL' if name=='chase_camera' else 'AUTO'
        camera.location=g(at);camera.data.lens=lens
        camera.rotation_euler=(g(target)-camera.location).to_track_quat('-Z','Y').to_euler()
        bpy.data.objects['StudioGround'].hide_render=name=='underside'
        path=evidence/(name+'.png');s.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        (evidence/(name+'.camera.json')).write_text(json.dumps({'source':str(source.relative_to(ROOT)),'source_sha256':source_hash,'image_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'engine':'Blender Cycles CPU','samples':a.samples,'resolution':[s.render.resolution_x,s.render.resolution_y],'camera_godot_m':at,'target_godot_m':target,'lens_mm':lens,'frame':s.frame_current,'production_race_camera':name=='chase_camera','postprocess':'Blender AgX only; no AI image generation'},indent=2)+'\n')


if __name__=='__main__':
    main()
