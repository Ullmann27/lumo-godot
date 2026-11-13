"""Render the actual exported GLB cast for asset QA, not an in-game screenshot."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/evidence/village-art-20261113'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
colors=[(.20,.57,.45,1),(.20,.38,.65,1),(.57,.26,.65,1)]
for index,key in enumerate(['nelli_rabbit','bruno_beaver','tilda_duck']):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/creative/village'/f'{key}.glb'))
 created=set(bpy.data.objects)-before
 roots=[o for o in created if o.parent not in created]
 for ob in roots:
  ob.location.x+=(index-1)*1.8
  if ob.animation_data:ob.animation_data_clear()
 # Clear walk actions so the actual rest mesh reads clearly.
 for ob in created:
  if ob.animation_data:ob.animation_data_clear()
 bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.76,depth=.13,location=((index-1)*1.8,0,-.07))
 podium=bpy.context.object;mat=bpy.data.materials.new(key+'_podium');mat.diffuse_color=colors[index];podium.data.materials.append(mat)
 bpy.ops.object.text_add(location=((index-1)*1.8,-.88,.0),rotation=(math.radians(77),0,0))
 label=bpy.context.object;label.data.body=['NELLI · GARTEN','BRUNO · BAUEN','TILDA · HANDEL'][index];label.data.align_x='CENTER';label.data.size=.16
 mat=bpy.data.materials.new('label_'+key);mat.diffuse_color=(.12,.23,.25,1);label.data.materials.append(mat)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.145));ground=bpy.context.object
mat=bpy.data.materials.new('warm studio');mat.diffuse_color=(.64,.75,.72,1);ground.data.materials.append(mat)
world=bpy.context.scene.world or bpy.data.worlds.new('Studio');bpy.context.scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.48,.66,.70,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45
for position,power,size in [((1,-5,7),950,6),((-5,-2,4),450,5),((0,4,5),1000,4)]:
 bpy.ops.object.light_add(type='AREA',location=position);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(4.6,-9.3,5.0));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=7.0;bpy.context.scene.camera=camera
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=96;scene.cycles.use_denoising=False;scene.render.resolution_x=1500;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'village_friends_blender.png');bpy.ops.render.render(write_still=True)
