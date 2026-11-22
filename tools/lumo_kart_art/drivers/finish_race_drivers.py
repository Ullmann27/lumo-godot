"""Breed-specific racing wardrobes, sculpted fur/feathers and transparent studio portraits.

blender -b -t 2 -P tools/lumo_kart_art/drivers/finish_race_drivers.py -- --species lion
Run without --species to finish all six. Regenerates a missing neutral .blend with
build_animal_drivers.py. The source rig remains in bind space for all sculpting.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import build_animal_drivers as animal

ROOT=animal.ROOT
TEAMS={
    # racing garment, edge piping, embroidery, irises
    "lion":("175952","eabb63","f2dbac","a77c37"),
    "owl":("41475f","cfa771","d9d8bc","a06e37"),
    "rabbit":("7858a7","b69bcb","ffda96","786239"),
    "squirrel":("376676","b46b42","eec476","805a29"),
    "turtle":("2b756c","c87345","ffe09a","6d793c"),
    "frog":("277a83","f39d57","f9d074","b48c39"),
}
UP=Vector((0,0,1))
FRONT=Vector((0,1,0))


def sculpt_base(obj,species):
    """Model the muzzle, facial ruff, belly and outer head in the original bind pose."""
    mesh=obj.data
    verts=np.array([v.co[:] for v in mesh.vertices])
    cols=np.empty(len(verts)*4,np.float32)
    attr=mesh.color_attributes["Palette"]
    attr.data.foreach_get("color",cols)
    cols=cols.reshape(-1,4)
    organic=np.zeros(len(verts),bool)
    for poly in mesh.polygons:
        if mesh.materials[poly.material_index].name=="Finish_Organic":
            organic[list(poly.vertices)]=True
    groups={g.index:g.name for g in obj.vertex_groups}
    faces=np.array([min(1.0,sum(g.weight for g in v.groups if
                      groups[g.group] in ("Head","Jaw"))) for v in mesh.vertices])
    x,y,z=verts.T.copy()
    muzzle=np.exp(-((z-1.494)/.103)**2)*np.clip((y-.015)/.115,0,1)*faces
    # Lion has a rounded muzzle, Nova a petite chin, the squirrel wider cheek pouches.
    # Extend the owl's hooked keratin profile and broaden the two amphibian/reptile jaws.
    width,length,chin={
        "lion":(.165,.034,-.014),"owl":(-.055,.028,-.025),"rabbit":(-.12,.023,-.005),
        "squirrel":(.24,.016,.008),"turtle":(.13,.024,-.003),"frog":(.14,.022,.008),
    }[species]
    verts[:,0]+=x*width*muzzle
    verts[:,1]+=length*muzzle
    verts[:,2]+=chin*muzzle*(1-np.clip(abs(x)/.26,0,1))
    # Broad coat tones are vertex-coloured: warm guard hairs, cream cheek down,
    # frog flank spots and tortoise scale mottling stay visible at mobile distance.
    f=organic.astype(float)*np.clip((z-.88)/.36,0,1)
    wave=np.sin(31*x+18*z+2*np.cos(16*y))*np.cos(15*y-19*z)
    fleck=np.sin(79*x-18*y+13*z)*np.cos(74*z+7*np.sin(14*x))
    if species in ("frog","turtle"):
        glaze=np.clip((wave+.12)*1.4,0,1)
        lower=.19 if species=="frog" else .13
        cols[:,:3]*=(1-lower*glaze*f)[:,None]
        cols[:,0]+=np.maximum(fleck,0)*f*.023
        cols[:,1]+=np.maximum(-wave,0)*f*.034
    else:
        warmth={"lion":(1.05,.93,.85),"owl":(.99,.95,1.0),
                "rabbit":(1.05,1.00,.97),"squirrel":(1.07,.92,.86)}[species]
        darker=np.clip((.91-cols[:,:3].max(axis=1))/.6,0,1)
        strength=f*darker
        for j in range(3):
            cols[:,j]*=(1+(warmth[j]-1)*strength) * (1+(.105*wave+.055*fleck)*strength)
    mesh.vertices.foreach_set("co",verts.astype(np.float32).ravel())
    attr.data.foreach_set("color",np.clip(cols,0,1).ravel())
    mesh.update()


class Sculptor:
    def __init__(self,body,species):
        self.body=body
        self.id=species
        self.colors=TEAMS[species]
        self.rng=np.random.default_rng(tuple(TEAMS).index(species)+82)
        self.tree=BVHTree.FromPolygons([v.co.copy() for v in body.data.vertices],
                                       [list(p.vertices) for p in body.data.polygons])
        animal.PARTS.clear()

    def hit(self,origin,direction):
        p,n,_,_=self.tree.ray_cast(Vector(origin),Vector(direction).normalized(),2)
        return p,n

    def front(self,x,z):
        return self.hit((x,.89,z),(0,-1,0))

    def organic(self,name,p,q,wide,thick,color,bone,front=FRONT,bend=(0,0,0),tip_color=None,finish="Organic"):
        # Seven cross-sections build a closed tapered lock, feather or scarf end.
        start,end=Vector(p),Vector(q)
        axis=(end-start).normalized()
        side=axis.cross(Vector(front)).normalized()
        if side.length<.02: side=axis.cross(UP).normalized()
        outward=side.cross(axis).normalized()
        vs=[];fs=[];cols=[]
        for j,(t,r) in enumerate(((0,.15),(.12,.76),(.30,1),(.52,.87),(.73,.61),(.89,.31),(1,.035))):
            centre=start.lerp(end,t)+Vector(bend)*math.sin(t*math.pi)
            for i in range(8):
                a=i*math.tau/8
                vs.append(tuple(centre+side*(wide*r*math.cos(a))+outward*(thick*r*math.sin(a))))
                dark=animal.srgb_to_linear(color)
                light=animal.srgb_to_linear(tip_color or color)
                cols.append(np.clip((dark*(1-t*.7)+light*t*.7)*(.93+.07*max(0,math.sin(a))),0,1))
                if j:
                    a0=(j-1)*8+i;a1=(j-1)*8+(i+1)%8
                    fs.append((a0,a1,a1+8,a0+8))
        fs.extend([tuple(range(7,-1,-1)),tuple(range(48,56))])
        return animal.primitive(name,vs,fs,cols,finish,bone)

    def bead(self,name,p,rad,color,bone,finish="Organic",seg=12):
        v,f,_=animal.ellipsoid_mesh(p,rad,seg=seg,rings=6)
        return animal.primitive(name,v,f,color,finish,bone)

    def cord(self,name,pts,r,color,bone,finish="Fabric"):
        v,f=animal.tube_mesh(pts,r,6)
        return animal.primitive(name,v,f,color,finish,bone)

    def cheek(self,s,z,y,dx,dz,width,base,tip):
        p,n=self.hit((s*.84,y,z),(-s,0,0))
        if p is None: return
        self.organic("Groomed cheek",p-n*.027,p+Vector((s*dx,-.022,dz)),
                     width,width*.40,base,"Head",front=(0,1,0),bend=(s*.016,.012,.015),tip_color=tip)

    def tailored(self):
        base,piping,badge,iris=self.colors
        data=self.body.data
        colors=data.color_attributes['Palette']
        # Keep the existing suit's contrasting seams and light panels, replace
        # the common blue fabric with a different, fitted racing livery per animal.
        cloth={v for face in data.polygons if 'Fabric' in data.materials[face.material_index].name for v in face.vertices}
        for index in cloth:
            attr=colors.data[index]
            r,g,b,a=attr.color
            if b>r*1.15 and b>g*1.02:
                value=np.clip(.72+max(b,g)*.50,.63,1.27)
                attr.color=(*np.clip(animal.srgb_to_linear(base)*value,0,1),a)
            elif r>g*1.22 and r>b*1.6:
                attr.color=(*animal.srgb_to_linear(piping),a)
        # Cuff/shoulder construction follows each individual's seated arm shape.
        for s,side in [(-1,"L"),(1,"R")]:
            z={"frog":1.11,"turtle":1.17}.get(self.id,1.207)
            p,n=self.hit((s*.78,.055,z),(-s,0,0))
            if p is not None:
                p=p+n*.005
                bone="UpperArm."+side
                self.bead("Quilted shoulder cap",p,(.034,.087,.074),base,bone,"Fabric",16)
                for row in range(2):
                    at=p+Vector((s*.029,.002,.024-row*.037))
                    self.cord("Embroidered sleeve chevron",[at+Vector((0,-.035,.003)),
                              at+Vector((s*.003,0,.009)),at+Vector((0,.033,-.010))],
                              .006,piping,bone)
        # Small brass flywheel badge sits on a padded chest patch, never on the hands.
        z=1.125 if self.id=="frog" else 1.158
        p,n=self.front(-.090,z)
        if p is not None:
            p=p+n*.007
            self.bead("Team escutcheon",p,(.037,.012,.041),piping,"Chest","Fabric")
            for side in (-1,1):
                self.cord("Badge wings",[p+Vector((side*.006,.014,-.018)),
                          p+Vector((side*.023,.014,.013))],.004,badge,"Chest","Metal")
        # Refract the eye's existing iris colours into warm fibres. The old whites,
        # pupils, glints, separately animated lids and eye bone pivot are preserved.
        for side in ("L","R"):
            group=self.body.vertex_groups.get("Eye."+side)
            if not group: continue
            for v in data.vertices:
                if not any(w.group==group.index and w.weight>.8 for w in v.groups): continue
                attr=colors.data[v.index];rgb=np.array(attr.color[:3]); lum=rgb.max()
                if lum>.033 and lum<.81 and rgb.max()-rgb.min()>.035:
                    variation=.85+.30*math.sin(v.co.x*79+v.co.z*137)**2
                    attr.color=(*np.clip(animal.srgb_to_linear(iris)*variation,0,1),1)

    def scarf(self,z,width,color,tail):
        # Tubular bias-cut collar, sampled from the actual surface.
        ring=[]
        for j in range(32):
            a=j*math.tau/32
            radial=Vector((math.cos(a),math.sin(a),0))
            h=z-.04*max(0,math.sin(a))
            p,n=self.hit(Vector((0,-.015,h))+radial*.64,-radial)
            if p is not None:
                # A shoulder or a mane can reach farther sideways than the collar.
                # Use the close neck ellipse there and let it disappear under the fur.
                half_width={"lion":.222,"rabbit":.145,"frog":.225,"turtle":.151}[self.id]
                half_depth={"lion":.242,"rabbit":.145,"frog":.225,"turtle":.164}[self.id]
                limit=1/math.sqrt((radial.x/half_width)**2+(radial.y/half_depth)**2)
                center=Vector((0,-.015,h))
                distance=min(limit,(p+n*.009-center).dot(radial))
                ring.append(center+radial*distance)
        if len(ring)>20:
            self.cord("Turned collar",ring+[ring[0]],width,color,"Chest")
            self.cord("Contrast selvedge",[v+UP*width*.77 for v in ring+[ring[0]]],
                      .005,self.colors[2],"Chest")
        p,n=self.front(.072,z-.043)
        if p is not None:
            p+=n*.018
            self.bead("Knotted neckerchief",p,(.035,.028,.027),color,"Chest","Fabric")
            self.organic("Folded kerchief",p,p+Vector(tail),.033,.011,color,"Chest",
                         bend=(.014,.028,.0),tip_color=self.colors[1],finish="Fabric")

    def fur_material(self):
        mat=bpy.data.materials['Finish_Organic']
        bs=mat.node_tree.nodes.get("Principled BSDF")
        nm=next((x for x in mat.node_tree.nodes if x.type=='NORMAL_MAP'),None)
        if self.id in ('turtle','frog'):
            bs.inputs["Roughness"].default_value=.44 if self.id=='frog' else .62
            bs.inputs['Sheen Weight'].default_value=.04
            if nm: nm.inputs['Strength'].default_value=.12
        else:
            bs.inputs["Roughness"].default_value=.73
            bs.inputs['Sheen Weight'].default_value=.36
            if nm: nm.inputs['Strength'].default_value=.32


def lion(c):
    # Two asymmetric courses of brushed, crescent-shaped mane locks wrap around
    # the sides and the nape; forehead and whisker pads remain unobscured.
    for j in range(2):
        for i in range(21):
            a=math.tau*(i+.31*j)/21
            radial=Vector((math.cos(a),math.sin(a),0))
            if radial.y>.58: continue
            z=1.71+j*.125+.038*math.sin(3*a+.7)
            p,n=c.hit(Vector((0,-.015,z))+radial*.77,-radial)
            if p is None: continue
            drift=Vector((-.025*math.sin(a),.012*math.cos(a),-.118-.026*math.cos(a*2)))
            goal=p+radial*(.036+.014*math.sin(4*a))+drift
            c.organic("Layered lion mane",p-n*.04+UP*.046,goal,.051,.028,
                      ("974a27","ae592d","a24e29")[i%3],"Head",front=radial,
                      bend=radial*.025,tip_color=("d88c4f","c97640")[i%2])
    for s in (-1,1):
        for j in range(3):
            c.cheek(s,1.58-j*.037,.105,.059+j*.013,-.043-j*.013,.045,
                    "c87938","e3aa64")
    c.scarf(1.325,.035,"2c8274",(-.10,.025,-.11))


def owl(c):
    # Broad two-part hooked beak; the mandible follows the existing jaw action.
    c.organic("Upper beak sheath",(0,.225,1.636),(0,.326,1.512),.047,.032,
              "d89a4c","Head",bend=(0,.035,.005),tip_color="785333",finish="Face")
    c.bead("Lower mandible",(0,.246,1.513),(.033,.048,.016),"9c683e","Jaw","Face")
    for s in (-1,1):
        for j in range(3):
            p,n=c.front(s*(.09+j*.048),1.77-j*.025)
            if p is None:continue
            c.organic("Expressive brow plume",p-n*.016,p+Vector((s*(.09+.015*j),-.025,.066+.015*j)),
                      .032,.013,"bf9f76","Head",bend=(0,.023,.012),tip_color="efe1bf")
        for j in range(4):
            z=1.62-j*.048
            c.cheek(s,z,.035,.044,-.067,.039,"947654","d4bc8d")
        for j in range(5):
            p,n=c.hit((s*.76,.01+(j-2)*.032,1.22-abs(j-2)*.018),(-s,0,0))
            if p is None:continue
            q=p+Vector((s*(.057+.012*j),-.052,-.14-.007*j))
            c.organic("Layered flight feather",p-n*.022,q,.029,.012,
                      "665746","UpperArm."+("L" if s<0 else "R"),
                      front=(s,.2,.0),bend=(s*.025,0,0),tip_color="dfbd83")
    for row in range(2):
        for j in range(5-row):
            x=(j-(4-row)/2)*.042
            p,n=c.front(x,1.32-row*.049)
            if p is None:continue
            c.organic("Breast feather",p-n*.01,p+Vector((x*.12,.007,-.07)),
                      .025,.010,"d1b28a","Chest",bend=(0,.016,0),tip_color="f9e5bc")


def rabbit(c):
    for s,side in [(-1,"L"),(1,"R")]:
        group=c.body.vertex_groups.get("Ear."+side)
        for v in c.body.data.vertices:
            if not group or not any(w.group==group.index and w.weight>.3 for w in v.groups):continue
            t=max(0,min(1,(v.co.z-1.83)/.38))
            # A relaxed ear tip folds out; the other points up into the wind.
            v.co.x+=s*t*t*(.108 if s==1 else .039)
            v.co.y+=t*t*(.095 if s==1 else -.032)
            v.co.z-=t*t*(.074 if s==1 else .009)
        for j in range(5):
            c.cheek(s,1.57-j*.026,.06+(j%2)*.029,.024+.012*math.sin(j),
                    -.037-j*.006,.035,"bc916f","f6d9bb")
    c.scarf(1.315,.030,"ad89bf",(.14,.012,-.112))
    for x in (-.125,.125):
        points=[]
        for z in np.linspace(1.02,1.20,8):
            p,n=c.front(x*(1+(z-1.1)*1.2),z)
            if p is not None:points.append(p+n*.007)
        if len(points)>3: c.cord("Jacket princess seam",points,.005,"dbc1df","Chest")


def squirrel(c):
    for j,(x,y,z) in enumerate(((.11,-.52,1.28),(.16,-.55,1.46),(.20,-.52,1.62),
                                (.24,-.45,1.79),(.27,-.38,1.92),(.275,-.29,2.0))):
        for i in range(8):
            a=i*math.tau/8+j*.39
            radial=Vector((math.cos(a),math.sin(a),0))
            p,n=c.hit(Vector((x,y,z))+radial*.50,-radial)
            if p is None or p.y>-.16:continue
            c.organic("Brush tail lock",p-n*.027,p+radial*.028+Vector((.018,.025,.087)),
                      .039,.013,"a85939" if i%3 else "ce855a","Tail",front=radial,
                      bend=radial*.016,tip_color="f1c398")
    for s in (-1,1):
        for i in range(4):
            c.cheek(s,1.55-i*.03,.06,.047,-.044,.031,"b86e45","ecc195")
    # A belted courier satchel and a soft leather flap across the outer hip.
    c.bead("Courier pouch",(-.177,.077,.994),(.073,.037,.075),"a76542","Pelvis","Fabric",18)
    c.bead("Satchel flap",(-.181,.10,1.020),(.069,.02,.043),"c58958","Pelvis","Fabric",16)
    c.bead("Brass snap",(-.18,.121,1.003),(.013,.005,.013),"e9bc72","Pelvis","Metal")
    pts=[]
    for t in np.linspace(0,1,14):
        p,n=c.front(.126-.26*t,1.244-.216*t)
        if p is not None:pts.append(p+n*.013)
    if len(pts)>4: c.cord("Courier baldric",pts,.019,"a46946","Chest")


def turtle(c):
    # Broad overlapping scutes are visible from behind the kart and give the
    # shell an anatomical edge. Fit the centre of each one to the curved back.
    for j in range(3):
        for i in range(3-j%2):
            x=(i-(2-j%2)/2)*.177
            z=.948+.143*j
            p,n=c.hit((x,-.88,z),(0,1,0))
            if p is None:continue
            base=p+n*.008
            rad=.09 if j==1 else .083
            outline=[base+Vector((rad*math.sin(a),0,rad*math.cos(a))) for a in
                    (math.tau*k/6 for k in range(7))]
            c.cord("Scute rim",outline,.009,"d9b579","Chest","Organic")
            c.bead("Convex scute",base+n*.009,(rad*.87,.028,rad*.88),
                   ("967247","b3874a","a47a45")[(j+i)%3],"Chest")
    for s in (-1,1):
        for i in range(5):
            x=s*(.10+.016*i)
            p,n=c.front(x,1.528+.012*(i%2))
            if p is not None:
                c.bead("Face scale",p+n*.001,(.013,.004,.009),"bdcf82","Head")
        # Deep ear cups with concentric pressure rings turn the stock lid into
        # an unmistakable rally helmet while leaving the eyes and mouth open.
        p,n=c.hit((s*.62,-.018,1.742),(-s,0,0))
        if p is not None:
            c.bead("Leather helmet ear pad",p+n*.006,(.032,.082,.091),"5d4735","Head","Rubber",18)
            c.bead("Helmet wing badge",p+n*.036,(.010,.046,.054),"dfa951","Head","Metal",16)
    c.scarf(1.295,.019,"c37750",(-.075,.012,-.07))


def frog(c):
    # Repaint the rotating eyeball in its own rest coordinates. The horizontal
    # pupil remains an amphibian trait, with a clear lower amber iris and glint.
    for side,s in (("L",-1),("R",1)):
        group=c.body.vertex_groups["Eye."+side].index
        vs=[v for v in c.body.data.vertices if any(w.group==group and w.weight>.95 for w in v.groups)]
        pts=np.array([v.co[:] for v in vs]);centre=(pts.max(0)+pts.min(0))*.5
        rr=(pts.max(0)-pts.min(0))*.5
        for v,co in zip(vs,pts):
            x,y,z=(co-centre)/rr
            if y<.09:continue
            x-=s*.115
            pupil=(x/.69)**2+((z-.014)/.33)**2
            rim=(x/.98)**2+((z-.01)/.91)**2
            rgb=("32291e" if pupil<1 else
                 ("bc8933" if z>.0 else "ecca65") if rim<1 else "d2d297")
            c.body.data.color_attributes["Palette"].data[v.index].color=(*animal.srgb_to_linear(rgb),1)
        glint=centre+rr*np.array([-.25,.88,.38])
        c.bead("Dew catchlight",glint,(.009,.004,.009),"fff7d8","Eye."+side,"Face")
    for s in (-1,1):
        for j in range(3):
            pts=[]
            for t in np.linspace(0,1,9):
                x=s*(.247-.13*t);z=1.438+j*.027+.015*math.sin(t*math.pi)
                p,n=c.front(x,z)
                if p is not None:pts.append(p+n*.004)
            if len(pts)>4:c.cord("Reed frog cheek markings",pts,.0045,
                                 ("739e58","8caa54","a7bd64")[j],"Head","Organic")
        for j in range(7):
            a=math.tau*j/7
            x=s*(.196+.035*math.cos(a))
            z=1.506+.033*math.sin(a)
            p,n=c.front(x,z)
            if p is not None:c.bead("Freckle",p+n*.001,(.009,.004,.007),
                                     "d8cd7d" if j%2 else "557e45","Head")
    c.scarf(1.233,.029,"da914b",(.11,.015,-.074))
    for s in (-1,1):
        p,n=c.front(s*.15,1.038)
        if p is not None:
            c.bead("Floating vest panel",p+n*.007,(.058,.026,.079),"5a9a97","Spine","Fabric",18)


SCULPTS={f.__name__:f for f in (lion,owl,rabbit,squirrel,turtle,frog)}


def portrait(id,rig,path):
    scene=bpy.context.scene
    scene.render.engine="CYCLES";scene.cycles.samples=32;scene.cycles.max_bounces=4
    scene.cycles.use_denoising=False
    scene.render.threads_mode="FIXED";scene.render.threads=2
    scene.render.resolution_x=400;scene.render.resolution_y=400;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format="WEBP"
    scene.render.image_settings.color_mode="RGBA";scene.render.image_settings.quality=93
    scene.world=scene.world or bpy.data.worlds.new("PortraitWorld")
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get("Background");bg.inputs[0].default_value=(.6,.70,.75,1)
    bg.inputs[1].default_value=.32
    scene.view_settings.view_transform='AgX'
    target_z={"frog":1.36,"lion":1.59,"rabbit":1.68,"squirrel":1.62,"owl":1.59,"turtle":1.57,
              "otter":1.47,"badger":1.49,"cat":1.54}[id]
    target=(0,-.02,target_z)
    for name,loc,power,col,size in [
            ("PortraitKey",(-2.4,3.8,4.3),380,(1,.87,.76),2.7),
            ("PortraitFill",(2.5,2.6,2.9),190,(.76,.88,1),3),
            ("PortraitRim",(1.2,-2.6,3.3),430,(1,.81,.59),1.9)]:
        light=bpy.data.lights.new(name,"AREA");light.energy=power;light.color=col;light.size=size
        o=bpy.data.objects.new(name,light);scene.collection.objects.link(o);o.location=loc;animal.look_at(o,target)
    camera=bpy.data.objects.new("PortraitCamera",bpy.data.cameras.new("PortraitCamera"))
    scene.collection.objects.link(camera);scene.camera=camera
    camera.data.type="ORTHO";camera.data.ortho_scale={"frog":.86,"rabbit":1.20,"squirrel":1.13,"lion":1.06}.get(id,1.03)
    camera.location=(.88,4.2,target_z+.31);animal.look_at(camera,target)
    rig.animation_data.action=bpy.data.actions["kart_seated"];scene.frame_set(8)
    scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    for obj in list(scene.objects):
        if obj.name.startswith('Portrait'):bpy.data.objects.remove(obj,do_unlink=True)


def build(species,before):
    source=ROOT/"art/lumo_kart/blender/drivers"/(species+".blend")
    if not source.exists():
        subprocess.run([bpy.app.binary_path,"-b","-t","2","--python-exit-code","1","-P",
                 str(HERE/"build_animal_drivers.py"),"--","--species",species],check=True)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig=next(o for o in bpy.data.objects if o.type=="ARMATURE")
    obj=bpy.data.objects["DriverMesh"]
    if before:
        before.mkdir(parents=True,exist_ok=True)
        portrait(species,rig,before/(species+".webp"))
    sculpt_base(obj,species)
    c=Sculptor(obj,species)
    c.tailored();c.fur_material();SCULPTS[species](c)
    extras=animal.PARTS.copy()
    # One skinned draw node / six material surfaces in every LOD. All detail
    # weights refer to the very same bones as the exported facial animation.
    bpy.ops.object.select_all(action="DESELECT")
    for node in extras:
        group=node.vertex_groups.new(name="LODBody")
        group.add(list(range(len(node.data.vertices))),1.0,'REPLACE')
        node.select_set(True)
    obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
    # Store the shared UVs as the active layer before export so the woven cloth
    # and micro-normal wardrobe materials align on the freshly joined vertices.
    uv=obj.data.uv_layers.active
    if uv:
        for poly in obj.data.polygons:
            for li in poly.loop_indices:
                if uv.data[li].uv.length_squared<1e-10:
                    p=obj.data.vertices[obj.data.loops[li].vertex_index].co
                    uv.data[li].uv=(.5+math.atan2(p.y+.02,p.x)/math.tau*4,.5+(p.z-1.3)*4)
    obj.data.calc_loop_triangles()
    lods=animal.export_lods(obj,rig,ROOT/"assets/kart/production/drivers"/species)
    report=ROOT/"evidence/lumo_kart_art/drivers"/species/"measurement.json"
    meta=json.loads(report.read_text());meta["lods"]=lods
    meta["authoring"]="Original seated sculpt, fitted race garment, species-specific modeled coat or scales and weighted facial detailing; 26 bones and 12 authored clips."
    report.write_text(json.dumps(meta,indent=2)+"\n")
    portrait(species,rig,ROOT/"assets/kart/menu/drivers"/(species+".webp"))
    print("RACE_DRIVER_COMPLETE",species,flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--species",nargs="+",choices=SCULPTS)
    parser.add_argument("--before",type=Path)
    parser.add_argument("--flutter",type=Path,help="Also write the portraits declared by the Flutter roster")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    for id in (args.species or SCULPTS):
        build(id,args.before)
        if args.flutter:
            from PIL import Image
            identities=json.loads((args.flutter/"assets/rivals/roster.json").read_text())["opponents"]
            for entry in identities:
                if entry["id"]==id:
                    path=args.flutter/entry["flutterPortrait"]
                    path.parent.mkdir(parents=True,exist_ok=True)
                    Image.open(ROOT/"assets/kart/menu/drivers"/(id+".webp")).save(path)
