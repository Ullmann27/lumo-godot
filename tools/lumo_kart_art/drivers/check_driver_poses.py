"""Check evaluated Blender skin positions, not just action-name presence."""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--species',default='rabbit')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/lumo_kart/blender/drivers'/(args.species+'.blend')))
    rig=bpy.data.objects['DriverRig'];mesh=bpy.data.objects['DriverMesh']
    scene=bpy.context.scene
    mesh.data.calc_loop_triangles()
    zero_area=sum(triangle.area<1e-12 for triangle in mesh.data.loop_triangles)
    invalid_normals=sum(not all(math.isfinite(v) for v in triangle.normal) or triangle.normal.length<.99 for triangle in mesh.data.loop_triangles)
    invalid_uv=sum(not all(math.isfinite(v) for v in item.uv) for item in mesh.data.uv_layers['UVMap'].data)
    assert zero_area==0,('degenerate triangles',zero_area)
    assert invalid_normals==0,('invalid triangle normals',invalid_normals)
    assert invalid_uv==0,('invalid UV coordinates',invalid_uv)
    geometry={'triangles':len(mesh.data.loop_triangles),'degenerate_triangles':zero_area,'invalid_normals':invalid_normals,'nonfinite_uv_coordinates':invalid_uv,'material_count':len(mesh.data.materials),'packed_texture_sizes':[[image.name,image.size[0],image.size[1]] for image in bpy.data.images if image.packed_file]}
    results=[]
    for name in ['idle','kart_seated','kart_steer_left','kart_steer_right','kart_jump','celebrate']:
        action=bpy.data.actions[name];rig.animation_data.action=action
        for fraction in [0,.25,.5,.75,1]:
            scene.frame_set(round(action.frame_range.x+(action.frame_range.y-action.frame_range.x)*fraction))
            deps=bpy.context.evaluated_depsgraph_get()
            evaluated=mesh.evaluated_get(deps);data=evaluated.to_mesh()
            vertices=[evaluated.matrix_world@v.co for v in data.vertices]
            lower=[min(v[i] for v in vertices) for i in range(3)]
            upper=[max(v[i] for v in vertices) for i in range(3)]
            evaluated.to_mesh_clear()
            assert lower[2] > -.06, (name,fraction,'skin below floor',lower)
            assert upper[2] < 2.80, (name,fraction,'skin above allowed envelope',upper)
            assert upper[0]-lower[0] < 1.5, (name,fraction,'excess width',lower,upper)
            assert upper[1]-lower[1] < 1.4, (name,fraction,'excess depth',lower,upper)
            hand_error=0
            if name in ['kart_seated','kart_jump']:
                for side,s in [('L',-1),('R',1)]:
                    hand=(rig.matrix_world@rig.pose.bones['Hand.'+side].matrix).translation
                    hand_error=max(hand_error,(hand-Vector((s*.16,.34,1.055))).length)
                assert hand_error < .0002, (name,fraction,'hand contact',hand_error)
            results.append({'clip':name,'fraction':fraction,'minimum_blender_m':lower,'maximum_blender_m':upper,'hand_error_m':hand_error})
    report={'species':args.species,'status':'PASS','geometry':geometry,'sample_count':len(results),'samples':results,'scope':'Base mesh geometry/normal/UV validity, evaluated Blender skin envelopes and actual hand bone contact. No device performance claim.'}
    out=ROOT/'evidence/lumo_kart_art/drivers'/args.species/'pose_check.json'
    out.write_text(json.dumps(report,indent=2))
    print('POSE_CHECK_PASS',args.species,len(results))


if __name__=='__main__':main()
