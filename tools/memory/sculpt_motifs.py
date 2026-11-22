"""Render the original tabletop miniatures for the Memory deck.

blender -b -t 2 -P tools/memory/sculpt_motifs.py -- output_folder [motif ...]
Then run finish_cards.py on that folder. Blender 4.3, Cycles CPU.
"""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
args = sys.argv[sys.argv.index('--')+1:]
OUT = Path(args[0])
OUT.mkdir(exist_ok=True, parents=True)
TAU = math.tau
INK = '182936'
CREAM = 'fff0c6'
GOLD = 'e7a548'
PALE = 'ffde83'
materials = {}


def material(hexcolor, metal=False):
    key = (hexcolor, metal)
    if key not in materials:
        m = bpy.data.materials.new(hexcolor)
        rgb = [int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
        color = tuple(v/12.92 if v < .04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
        m.diffuse_color = color
        m.use_nodes = True
        shader = m.node_tree.nodes['Principled BSDF']
        shader.inputs['Base Color'].default_value = color
        shader.inputs['Roughness'].default_value = .34 if metal else .40
        shader.inputs['Metallic'].default_value = .54 if metal else .03
        materials[key] = m
    return materials[key]


def finish(o, col, metal=False):
    o.data.materials.append(material(col, metal))
    for poly in o.data.polygons:
        poly.use_smooth = True
    return o


def oval(p,s,col,metal=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=p)
    o=bpy.context.object; o.scale=s
    return finish(o,col,metal)


def box(p,s,col,bevel=.06,metal=False):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    o=bpy.context.object;o.dimensions=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=bevel;mod.segments=5
    o.modifiers.new('Polished facets','WEIGHTED_NORMAL')
    o.data.materials.append(material(col,metal))
    return o


def pipe(points,col,r=.024,metal=False):
    c=bpy.data.curves.new('Line','CURVE');c.dimensions='3D';c.resolution_u=12
    c.bevel_depth=r;c.bevel_resolution=4;c.use_fill_caps=True
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for bp,p in zip(s.bezier_points,points):
        bp.co=p;bp.handle_left_type=bp.handle_right_type='AUTO'
    o=bpy.data.objects.new('Stroke',c);bpy.context.collection.objects.link(o)
    c.materials.append(material(col,metal))
    return o


def plaque(outline,p,col,depth=.16,bevel=.035,metal=False):
    c=bpy.data.curves.new('Inlay','CURVE');c.dimensions='2D';c.resolution_u=3
    c.extrude=depth/2;c.bevel_depth=bevel;c.bevel_resolution=5
    s=c.splines.new('POLY');s.points.add(len(outline)-1)
    for k,(x,z) in enumerate(outline):s.points[k].co=(x,z,0,1)
    s.use_cyclic_u=True
    o=bpy.data.objects.new('Enamel inlay',c);bpy.context.collection.objects.link(o)
    o.rotation_euler.x=math.pi/2;o.location=p;c.materials.append(material(col,metal))
    return o


def eye(x,y,z,size=.11):
    oval((x,y,z),(size,size*.5,size*1.18),INK)
    oval((x-size*.23,y-size*.45,z+size*.28),(size*.29,size*.16,size*.29),'fff8e8')


def face(kind):
    if kind=='pinguin':
        oval((0,0,0),(.72,.54,.92),INK)
        oval((0,-.32,-.10),(.53,.27,.64),CREAM)
        for k in [-1,1]:
            oval((k*.24,-.42,.26),(.25,.13,.27),CREAM)
            eye(k*.23,-.55,.27,.071)
            wing=oval((k*.62,-.01,-.12),(.17,.22,.56),'284355');wing.rotation_euler.y=-k*.4
            oval((k*.34,-.20,-.81),(.24,.30,.104),GOLD)
        beak=plaque([(-.16,.04),(.16,.04),(0,-.14)],(0,-.587,.10),'f2a64d',.12)
        pipe([(-.5,-.2,-.22),(0,-.64,-.26),(.49,-.22,-.18)],'317c89',.08)
        scarf=box((.31,-.45,-.41),(.18,.11,.38),'317c89');scarf.rotation_euler.y=-.27
        return
    if kind=='giraffe':
        oval((0,.07,-.31),(.29,.30,.80),'dda74d')
        for i in range(4):
            oval(((-1)**i*.15,-.19,-.82+i*.23),(.09,.045,.12),'926131')
        for k in [-1,1]:
            ear=oval((k*.63,.0,.39),(.27,.12,.15),'eab75a');ear.rotation_euler.y=-k*.44
            ear=oval((k*.65,-.094,.40),(.17,.05,.091),'bb744c');ear.rotation_euler.y=-k*.44
            pipe([(k*.25,.03,.43),(k*.29,.035,.77)],'ca8c42',.061)
            oval((k*.29,.035,.79),(.13,.12,.11),'785238')
        oval((0,0,.20),(.58,.46,.47),'efbc64')
        oval((0,-.32,-.01),(.49,.31,.265),'f7d3a1')
        for k in [-1,1]:
            eye(k*.267,-.399,.256,.083)
            oval((k*.16,-.59,.032),(.048,.026,.034),'8e6545')
        pipe([(-.13,-.603,-.07),(0,-.627,-.10),(.13,-.602,-.061)],'9b674d',.014)
        return
    rabbit=kind=='hase'
    coat='dbc1a2' if rabbit else 'eee8d8'
    oval((0,.06,-.44),(.54,.4,.49),coat if rabbit else INK)
    for k in [-1,1]:
        if rabbit:
            ear=oval((k*.32,.03,.58),(.17,.14,.47),coat);ear.rotation_euler.y=k*.22
            ear=oval((k*.332,-.085,.60),(.09,.061,.35),'c97f7c');ear.rotation_euler.y=k*.22
        else:
            oval((k*.52,.04,.46),(.272,.22,.252),INK)
        oval((k*.33,-.22,-.64),(.23,.26,.14),coat if rabbit else INK)
    oval((0,0,-.02),(.68,.49,.57),coat)
    for k in [-1,1]:
        if not rabbit:
            o=oval((k*.276,-.378,.066),(.225,.13,.23),INK);o.rotation_euler.y=k*.38
        eye(k*.264,-(.506 if not rabbit else .449),.074,.085)
        oval((k*.127,-.462,-.152),(.202,.14,.15),CREAM)
    oval((0,-.60,-.075),(.104,.073,.066),'775044' if rabbit else INK)
    if rabbit:
        for k in [-1,1]:
            for i in range(2):
                pipe([(k*.235,-.533,-.14-i*.058),(k*.53,-.542,-.14-i*.092)],'957263',.009)
        oval((0,-.395,-.51),(.19,.086,.25),'e89a46').rotation_euler.y=-.48
        for i in [-1,0,1]:
            pipe([(-.08,-.39,-.35),(-.08+i*.10,-.40,-.145)],'608558',.025)
    else:
        pipe([(.28,-.39,-.68),(.46,-.42,-.23),(.51,-.36,.02)],'5e965d',.031)
        for i in range(3): oval((.49+(.062 if i%2 else -.052),-.44,-.35+i*.14),(.12,.027,.054),'77ab62').rotation_euler.y=(-1)**i*.5


def star(n=5,rad=.88,inner=.44):
    return [(math.sin(i*math.pi/n)*(rad if i%2==0 else inner),
             math.cos(i*math.pi/n)*(rad if i%2==0 else inner)) for i in range(n*2)]


def treasure(kind):
    if kind=='stern':
        plaque(star(),(0,0,0),'af6637',.27,.065,True)
        plaque(star(rad=.79,inner=.38),(0,-.188,0),'ffce61',.04,.035)
        plaque(star(n=4,rad=.26,inner=.098),(0,-.245,.015),'fff3b1',.035,.015)
    elif kind=='laterne':
        box((0,0,-.61),(1.05,.62,.16),'916545',.075,True)
        box((0,0,-.49),(.91,.55,.13),GOLD,.05,True)
        box((0,0,-.02),(.78,.51,.86),'ffc057',.095)
        for k in [-1,1]:
            pipe([(k*.43,-.27,-.47),(k*.47,-.27,.40)],'876348',.058,True)
            pipe([(k*.41,-.312,-.43),(-k*.40,-.312,.39)],PALE,.028,True)
        box((0,0,.46),(1.04,.68,.13),'745247',.06,True)
        plaque([(-.53,0),(.53,0),(.22,.24),(-.22,.24)],(0,0,.47),'987650',.49,.05,True)
        pipe([(-.22,.006,.67),(-.26,.02,.88),(0,.02,1.01),(.26,.02,.88),(.22,.006,.67)],'8b7758',.042,True)
    elif kind=='truhe':
        box((0,0,-.26),(1.48,.92,.71),'975a39',.12)
        box((0,0,.13),(1.52,.96,.42),'bb7a46',.18)
        box((0,0,-.08),(1.55,.96,.085),'865435',.025)
        for k in [-1,1]:
            box((k*.49,-.01,-.105),(.12,.97,.79),'dbac60',.04,True)
            for z in [-.42,.2]:oval((k*.49,-.501,z),(.032,.02,.032),CREAM,True)
        box((0,-.515,-.098),(.29,.10,.29),PALE,.046,True)
        oval((0,-.572,-.08),(.041,.018,.056),INK)
    elif kind=='note':
        plaque([(-.5,-.32),(-.39,-.32),(-.39,.43),(.44,.62),(.44,-.18),(.55,-.18),(.55,.83),(-.51,.59)],(0,0,0),'358891',.25,.058,True)
        for k,z in [(-.62,-.43),(.32,-.27)]:
            oval((k,0,z),(.29,.19,.22),'479d9e',True).rotation_euler.y=-.4
            oval((k-.045,-.153,z+.04),(.11,.041,.053),'acd6bc')
        pipe([(-.42,-.184,.51),(.46,-.184,.70)],PALE,.03,True)
    elif kind=='fahne':
        pipe([(-.51,0,-.82),(-.51,0,.80)],GOLD,.055,True)
        oval((-.51,0,.86),(.10,.10,.10),PALE,True)
        plaque([(-.44,.70),(.17,.56),(.74,.70),(.57,.38),(.77,.15),(.18,.01),(-.44,.16)],(0,0,0),'bd4f55',.11,.033)
        plaque(star(rad=.185,inner=.09),(.03,-.11,.36),PALE,.017,.014)
        box((-.51,0,-.77),(.54,.43,.13),'578183')
    elif kind=='pilz':
        oval((0,0,-.34),(.32,.30,.56),'eed9a3')
        oval((0,0,.12),(.81,.61,.23),'f6d8a5')
        oval((-.025,.02,.24),(.81,.60,.43),'bb4438')
        for x,y,z,r in [(-.36,-.39,.44,.13),(.17,-.48,.41,.16),(.43,-.26,.51,.11),(-.06,-.2,.619,.082)]:
            oval((x,y,z),(r,r*.65,r*.40),'fff0cd')
        for i in range(3):
            leaf=oval((-.36+.39*i,-.02,-.72),(.19,.10,.08),'60915a');leaf.rotation_euler.y=-.20+i*.26
    elif kind=='stein':
        for x,y,z,s,col in [(-.38,0,-.26,.64,'32858c'),(.22,.08,-.25,.77,'6574ae'),(.05,-.24,-.48,.47,'427e93')]:
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=s,location=(x,y,z));o=bpy.context.object;o.scale=(1,.76,.69);o.data.materials.append(material(col))
        for x,y,h,tilt,col in [(-.47,.03,.80,-.3,'66cccb'),(-.03,.04,1.12,.12,'b2a8ed'),(.45,.08,.70,.47,'73a8d8')]:
            levels=[(-.34,.16),(.02,.20),(h-.52,.17),(h-.27,.008)]
            vs=[(x+jz*math.sin(tilt)+rad*math.cos(i*TAU/6),y+rad*math.sin(i*TAU/6),jz) for jz,rad in levels for i in range(6)]
            fs=[(j*6+i,j*6+(i+1)%6,(j+1)*6+(i+1)%6,(j+1)*6+i) for j in range(3) for i in range(6)]
            m=bpy.data.meshes.new('Faceted quartz');m.from_pydata(vs,[],fs);o=bpy.data.objects.new('Crystal',m);bpy.context.collection.objects.link(o);m.materials.append(material(col,True))


def light(name,p,power,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.location=p
    obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()


def render(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials.clear()
    scene=bpy.context.scene
    scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.62,.68,.78,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    if kind=='lumo':
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/lumo_facial/Lumo-Facial-Mobile.glb'))
        meshes=[o for o in scene.objects if o.type=='MESH']
        pts=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
        mins=Vector(tuple(min(p[i] for p in pts) for i in range(3)));maxs=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
        midpoint=(mins+maxs)/2; height=maxs.z-mins.z
        center=Vector((midpoint.x,midpoint.y,mins.z+height*.65))
        scale=height*.78
    else:
        (face if kind in ['panda','giraffe','hase','pinguin'] else treasure)(kind)
        center=Vector((0,0,-.01));scale=2.25
    data=bpy.data.cameras.new('Portrait');cam=bpy.data.objects.new('Portrait',data);scene.collection.objects.link(cam)
    cam.location=center+Vector((.085 if kind in ['panda','hase','pinguin','giraffe','lumo'] else .21,-1,.13))*scale*3
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=scale;scene.camera=cam
    light('Key',(-2.6,-4.5,4.6),560,4,(1,.88,.73))
    light('Fill',(3,-2,2),330,4,(.75,.88,1))
    light('Rim',(1,2.5,3.2),850,3,(1,.88,.65))
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=False
    scene.render.film_transparent=True
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.render.filepath=str(OUT/(kind+'.png'))
    bpy.ops.render.render(write_still=True)


for motif in args[1:] or ['panda','giraffe','hase','pinguin','stern','laterne','truhe','note','fahne','pilz','stein','lumo']:
    render(motif)
