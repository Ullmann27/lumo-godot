#!/usr/bin/env python3
"""Verify all three exported kart LOD chains and their actual UV/animation data."""
import json
from pathlib import Path
import sys

import numpy as np

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/lumo_kart_art'))
from audit_glb import BinaryModel, inspect

STANCES={'comet':1.0,'glider':.91,'turbo':1.10}


def main():
    records=[]
    for variant,stance in STANCES.items():
        mechanical=json.loads((ROOT/'evidence/lumo_kart_art/karts'/variant/'mechanical_clearance.json').read_text())
        if not mechanical['passed']:
            raise AssertionError(variant+' has failed source-mechanics validation')
        for level in range(3):
            suffix='' if level==0 else '_lod'+str(level)
            path=ROOT/'assets/kart/production/karts'/('aurora_'+variant+suffix+'.glb')
            model=BinaryModel(path)
            report=inspect(path,ROOT)
            uv_degenerate=0
            for mesh in model.document['meshes']:
                for primitive in mesh['primitives']:
                    indices=model.array(primitive['indices']).reshape((-1,3))
                    uv=model.array(primitive['attributes']['TEXCOORD_0']).astype(float)[indices]
                    a,b=uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]
                    area=np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])
                    uv_degenerate+=int(np.count_nonzero(area<1e-12))
            errors=list(report['errors'])
            if report['degenerate_triangles']:
                errors.append('Zero-area geometry')
            if uv_degenerate:
                errors.append('Zero-area UV triangles')
            clips=report['animations']
            if len(clips)!=1 or clips[0]['name']!='mechanical_demo' or clips[0]['changing_channels']!=7 or abs(clips[0]['duration_seconds']-2)>1e-5:
                errors.append('Expected a genuine 2-second clip with seven changing channels')
            for axle,z in (('F',-.66),('R',.66)):
                for side,label in ((-1,'L'),(1,'R')):
                    expected=np.array([side*.77*stance,.35,z])
                    for prefix in ('Steer_','Wheel_'):
                        actual=np.array(report['node_positions_m'][prefix+axle+label])
                        if np.linalg.norm(actual-expected)>1e-5:
                            errors.append('Incorrect wheel pivot '+prefix+axle+label)
            for side,label in ((-1,'L'),(1,'R')):
                actual=np.array(report['node_positions_m']['Grip_'+label])
                if np.linalg.norm(actual-np.array([side*.16,.70,-.04]))>1e-5:
                    errors.append('Incorrect driver grip '+label)
            budget=(50000,25000,17000)[level]
            if report['triangles_unique_meshes']>budget:
                errors.append('Triangle budget exceeded')
            source_report='mesh_report.json' if level==0 else 'lod'+str(level)+'_report.json'
            mesh_report=json.loads((ROOT/'evidence/lumo_kart_art/karts'/variant/source_report).read_text())
            if mesh_report['non_manifold_edges']:
                errors.append('Non-manifold edges in authored mesh')
            report.update({'variant':variant,'lod':level,'degenerate_uv_triangles':uv_degenerate,
                           'authored_non_manifold_edges':mesh_report['non_manifold_edges'],
                           'triangle_budget':budget,'errors':errors,'passed':not errors})
            records.append(report)
    out={'schema_version':1,'method':'Independent binary geometry/UV/animation and marker checks plus evaluated Blender tyre sweep; no hardware FPS claim.','assets':records,'passed':all(r['passed'] for r in records)}
    target=ROOT/'evidence/lumo_kart_art/karts/export_validation.json'
    target.write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({'passed':out['passed'],'assets':len(records),'report':str(target),
                      'errors':{r['path']:r['errors'] for r in records if r['errors']}},indent=2))
    if not out['passed']:
        raise SystemExit(1)


if __name__=='__main__':
    main()
