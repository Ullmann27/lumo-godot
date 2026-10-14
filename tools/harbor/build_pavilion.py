"""Original Sonnenhafen wave pavilion. Blender 4.3; metres, UVs, 3 LODs.
Uses existing Aqua Harbor reference for palette/nautical architecture only.
No downloaded meshes, textures, paid services, or third-party typography.
"""
import bpy, math, json, hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/kart/harbor_pavilion'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
MATS={}
for name,color,metal,rough,emission in [
 ('navy_ceramic',(0.018,.066,.13,1),.35,.26,0),
 ('ivory_stone',(.79,.83,.75,1),.08,.58,0),
 ('warm_brass',(.86,.48,.12,1),.72,.3,0),
 ('cyan_light',(.08,.73,.94,1),.15,.24,1.3),
 ('blue_canopy',(.035,.23,.38,1),.4,.22,0)]:
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color
 p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 p.inputs['Emission Color'].default_value=color;p.inputs['Emission Strength'].default_value=emission
 MATS[name]=m

def cube(name,at,size,mat,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(MATS[mat])
 if bevel:
  mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=2
  bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def tube(name,pts,thickness,mat,res):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=1;c.bevel_depth=thickness;c.bevel_resolution=res;c.resolution_u=1
 p=c.splines.new('POLY');p.points.add(len(pts)-1)
 for v,co in zip(p.points,pts):v.co=(*co,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(MATS[mat]);return o

proof=[]
for lod,n in enumerate([32,16,8]):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for x in [-7.65,7.65]:
  cube('stone_foot',(x,0,.35),(1.65,3.6,.7),'ivory_stone',.08 if lod==0 else 0)
  cube('navy_pier',(x,0,3.1),(1.05,2.8,5.5),'navy_ceramic',.08 if lod==0 else 0)
  cube('pillar_inlay',(x, -1.43,3.3),(.24,.08,4.7),'cyan_light')
  cube('capital',(x,0,5.8),(1.65,3.5,.35),'warm_brass',.04 if lod==0 else 0)
  if lod<2:
   for z in [1.2,2.4,3.6,4.8]:cube('pier_seam',(x,0,z),(1.1,2.85,.09),'ivory_stone')
 # Two elliptical structural arches and a solid, reflective roof shell.
 for y in [-1.7,1.7]:
  pts=[(7.65*math.cos(math.pi*i/n), y, 5.65+2.9*math.sin(math.pi*i/n)) for i in range(n+1)]
  tube('wave_arch',pts,.32,'ivory_stone',1 if lod==0 else 0)
  tube('luminous_crown',[(x,y-.05,z+.27) for x,y,z in pts],.075,'cyan_light',0)
 verts=[];faces=[]
 for i in range(n+1):
  a=math.pi*i/n
  verts.extend([(7.65*math.cos(a),y,5.68+2.9*math.sin(a)) for y in [-1.7,1.7]])
 for i in range(n):faces.append((i*2,i*2+1,i*2+3,i*2+2))
 me=bpy.data.meshes.new('curved_roof');me.from_pydata(verts,[],faces);me.update()
 o=bpy.data.objects.new('curved_roof',me);bpy.context.collection.objects.link(o);o.data.materials.append(MATS['blue_canopy'])
 for i in range(1,n,4 if lod<2 else 2):
  a=math.pi*i/n;x=7.65*math.cos(a);z=5.75+2.9*math.sin(a)
  tube('roof_rib',[(x,-1.75,z),(x,1.75,z)],.055,'warm_brass',0)
 cube('sign_back',(0,-1.83,7.6),(4.7,.22,1.4),'navy_ceramic',.12 if lod==0 else 0)
 for side in [-1,1]:
  # Original flowing wave motif, geometry rather than a raster billboard.
  pts=[(-1.8+i*.12,-2,7.6+side*.23+.12*math.sin(i*.5)) for i in range(31 if lod<2 else 0)]
  if pts:tube('wave_emblem',pts,.045,'cyan_light',0)
 # Consolidate per material: five surfaces per instance, no per-bolt nodes.
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH')
 for name,mat in MATS.items():
  bpy.ops.object.select_all(action='DESELECT')
  objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
  if not objs:continue
  for o in objs:o.select_set(True)
  bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
 bpy.ops.object.select_all(action='SELECT')
 triangles=sum(len(p.vertices)-2 for o in bpy.context.scene.objects if o.type=='MESH' for p in o.data.polygons)
 if lod==0:bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'docs/design/1939-harbor/Sonnenhafen-Wave-Pavilion.blend'))
 dest=OUT/f'wave_pavilion_lod{lod}.glb'
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_apply=True,export_yup=True,use_selection=True)
 proof.append({'lod':lod,'triangles':triangles,'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
(OUT/'PROVENANCE.json').write_text(json.dumps({'authoring':'Original Lumo geometry authored in Blender; existing project palette/reference, no imported third-party meshes','reference':'docs/design_targets/2026-10-05-tracks/Track_04_aqua_harbor_rush/track_04_hero_2560.png','units':'metres','materials':'5 PBR materials, UV0, no image textures','lods':proof},indent=2)+'\n')
print('PAVILION_EXPORTED',json.dumps(proof))
