"""Reproducible, original LUMO village cast; run with Blender --background --python.
All geometry is generated here. No provider asset, external texture or Lumo rig is modified.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/creative/village'
OUT.mkdir(parents=True, exist_ok=True)
PALETTE = {
 'cream':(0.95,0.87,0.68,1),'rabbit':(0.79,0.58,0.38,1),'brown':(0.37,0.19,0.08,1),
 'white':(0.97,0.95,0.86,1),'dark':(0.025,0.035,0.045,1),'green':(0.16,0.60,0.44,1),
 'yellow':(0.96,0.65,0.12,1),'blue':(0.12,0.34,0.65,1),'purple':(0.51,0.24,0.65,1),
 'orange':(1.0,0.41,0.04,1),'pink':(0.95,0.51,0.53,1),'teal':(0.13,0.69,0.69,1)
}

def part(name, pos, scale, color, bone='body', shape='sphere'):
 if shape=='cube':
  bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
 elif shape=='ico':
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=pos)
 else:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=pos)
 ob=bpy.context.object; ob.name=name; ob.scale=scale
 bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
 col=ob.data.color_attributes.new(name='village_color',type='FLOAT_COLOR',domain='CORNER')
 for datum in col.data: datum.color=PALETTE.get(color,color)
 group=ob.vertex_groups.new(name=bone); group.add(list(range(len(ob.data.vertices))),1.0,'REPLACE')
 for face in ob.data.polygons: face.use_smooth=True
 return ob

def model(key,species):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 objects=[]
 def p(*args,**kwargs):
  ob=part(*args,**kwargs); objects.append(ob); return ob
 fur='rabbit' if species=='rabbit' else 'brown' if species=='beaver' else 'white'
 shirt={'rabbit':'green','beaver':'blue','duck':'purple'}[species]
 p('body',(0,0,0.83),(0.33,0.25,0.40),shirt)
 p('belly',(0,-0.22,0.85),(0.20,0.055,0.27),'cream')
 p('head',(0,-0.025,1.37),(0.32,0.28,0.31),fur,'head')
 for side,x in [('left',-0.19),('right',0.19)]:
  p(side+'_leg',(x,0,0.30),(0.105,0.115,0.25),fur,side+'_leg')
  p(side+'_foot',(x,-0.09,0.13),(0.15,0.22,0.10),'orange' if species=='duck' else 'brown',side+'_leg')
  arm=p(side+'_arm',(x*2,0,0.87),(0.115,0.12,0.30),fur,side+'_arm'); arm.rotation_euler.y=-0.20 if x<0 else 0.20
  p(side+'_eye',(x*0.60,-0.277,1.44),(0.067,0.026,0.085),'white','head')
  p(side+'_pupil',(x*0.60,-0.301,1.44),(0.031,0.017,0.048),'dark','head')
  p(side+'_glint',(x*0.60-0.01,-0.315,1.46),(0.011,0.007,0.014),'white','head')
 if species=='rabbit':
  for x in [-0.14,0.14]:
   p('ear',(x,0.015,1.81),(0.09,0.09,0.33),fur,'head')
   p('ear_inner',(x,-0.075,1.82),(0.047,0.018,0.24),'pink','head')
  p('muzzle',(0,-0.27,1.29),(0.19,0.10,0.11),'cream','head')
  p('nose',(0,-0.369,1.31),(0.040,0.023,0.030),'pink','head')
  p('hat_brim',(0,0,1.64),(0.40,0.32,0.035),'yellow','head')
  p('hat_top',(0,0.025,1.72),(0.26,0.22,0.12),'yellow','head')
  p('tail',(0,0.26,0.69),(0.15,0.13,0.15),'cream')
 elif species=='beaver':
  for x in [-0.27,0.27]:p('ear',(x,0.0,1.60),(0.085,0.075,0.09),fur,'head')
  p('muzzle',(0,-0.25,1.26),(0.23,0.13,0.13),'cream','head')
  p('nose',(0,-0.375,1.34),(0.085,0.04,0.06),'dark','head')
  for x in [-0.035,0.035]:p('tooth',(x,-0.365,1.20),(0.055,0.045,0.10),'white','head','cube')
  p('helmet',(0,0.0,1.63),(0.34,0.28,0.14),'yellow','head')
  p('helmet_brim',(0,-0.15,1.57),(0.38,0.24,0.035),'yellow','head')
  p('tail',(0,0.34,0.38),(0.24,0.35,0.08),'brown')
  for x in [-0.16,0.16]:p('strap',(x,-0.24,1.00),(0.075,0.025,0.32),'blue',shape='cube')
 else:
  p('bill',(0,-0.32,1.31),(0.19,0.17,0.065),'orange','head')
  p('crest',(0,0.03,1.70),(0.075,0.08,0.12),'white','head')
  p('satchel',(0.31,-0.12,0.64),(0.14,0.12,0.18),'teal')
  p('hat',(0,0,1.64),(0.32,0.27,0.055),'purple','head')
  p('tail',(0,0.28,0.62),(0.17,0.23,0.13),'white')
 # One material and one skinned mesh keep crowd draw calls proportional to visible residents.
 bpy.ops.object.select_all(action='DESELECT')
 for ob in objects: ob.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); mesh=bpy.context.object; mesh.name=key+'_mesh'
 mat=bpy.data.materials.new('VillageVertexPalette'); mat.use_nodes=True
 nodes=mat.node_tree.nodes; shader=nodes.get('Principled BSDF'); vc=nodes.new('ShaderNodeVertexColor'); vc.layer_name='village_color'
 mat.node_tree.links.new(vc.outputs['Color'],shader.inputs['Base Color']); shader.inputs['Roughness'].default_value=.77
 mesh.data.materials.clear();mesh.data.materials.append(mat)
 for polygon in mesh.data.polygons:polygon.material_index=0
 bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0)); arm=bpy.context.object; arm.name=key+'_rig'
 bones=arm.data.edit_bones; bones.remove(bones[0])
 defs={'root':((0,0,0),(0,0,.3),None),'body':((0,0,.5),(0,0,1.1),'root'),'head':((0,0,1.1),(0,0,1.6),'body'),
 'left_arm':((-.34,0,1.10),(-.39,0,.68),'body'),'right_arm':((.34,0,1.10),(.39,0,.68),'body'),
 'left_leg':((-.19,0,.52),(-.19,0,.12),'root'),'right_leg':((.19,0,.52),(.19,0,.12),'root')}
 for name,(head,tail,parent) in defs.items():
  b=bones.new(name);b.head=head;b.tail=tail
  if parent:b.parent=bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT'); mesh.parent=arm;mod=mesh.modifiers.new('VillageRig','ARMATURE');mod.object=arm
 arm.animation_data_create();action=bpy.data.actions.new('Walk');arm.animation_data.action=action
 for frame,phase in [(1,0),(7,math.pi/2),(13,math.pi),(19,3*math.pi/2),(25,2*math.pi)]:
  for name,sign in [('left_leg',1),('right_leg',-1),('left_arm',-1),('right_arm',1)]:
   b=arm.pose.bones[name];b.rotation_mode='XYZ';b.rotation_euler.x=math.sin(phase)*.34*sign;b.keyframe_insert('rotation_euler',frame=frame)
  b=arm.pose.bones['body']; b.location.z=.025*abs(math.sin(phase));b.keyframe_insert('location',frame=frame)
 bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=25;bpy.context.scene.render.fps=24;bpy.context.scene.frame_set(1)
 bpy.ops.object.select_all(action='SELECT')
 path=OUT/(key+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_animations=True,export_skins=True,export_materials='EXPORT',export_yup=True,export_apply=False,export_cameras=False,export_lights=False)
 return {'id':key,'species':species,'vertices':len(mesh.data.vertices),'triangles':sum(len(f.vertices)-2 for f in mesh.data.polygons),'bones':len(defs),'materials':1,'bytes':path.stat().st_size}

manifest={'authoring':'Original geometry generated by tools/art/build_village_friends.py in Blender; no third-party inputs','characters':[]}
for key,species in [('nelli_rabbit','rabbit'),('bruno_beaver','beaver'),('tilda_duck','duck')]:manifest['characters'].append(model(key,species))
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(manifest))
