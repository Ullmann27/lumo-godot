"""Original Windwerk scenery. Rebuild every GLB and transparent part portrait:
blender -b -t 2 -P tools/lumo_windwerk_art/build_windwerk.py
All dimensions in metres. +Y = up, +Z = ornamental front, route travels toward -Z.
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools/lumo_kart_art/karts"))
import build_karts as k
sys.path.insert(0, str(Path(__file__).resolve().parent))
from wind_whale import whale

COLORS={
    "lagoon":("258da3",.09,.45), "coral":("ea785f",.06,.49),
    "cast":("305e64",.48,.36), "dark":("243d42",.27,.46),
    "cream":("f2d997",.09,.53), "red":("c45c3c",.21,.43),
    "wood":("975737",.04,.62), "gold":("e9ab4d",.57,.32),
    "light":("ffdf93",.12,.24), "leaf":("598c62",.02,.72),
    "sunleaf":("91ae65",.02,.71), "stone":("b49d7d",.04,.73),
}


class Builder:
    """Batch solids per material. Each LOD can drop rivets, ribs and roof courses."""
    def __init__(self,root,level,mats):
        self.root=root
        self.level=level
        self.mats=mats
        self.parts={}

    def solid(self,verts,faces,mat):
        v,f=self.parts.setdefault(mat,([],[]))
        start=len(v)
        v.extend(verts)
        f.extend(tuple(start+i for i in face) for face in faces)

    def box(self,p,size,mat):
        x,y,z=p
        a,b,c=[i*.5 for i in size]
        self.solid([(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in
                    ((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                     (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1))],
                   [(0,1,2,3),(4,5,6,7),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],mat)

    def beam(self,p,q,width,depth,mat):
        p,q=Vector(p),Vector(q)
        direction=(q-p).normalized()
        ref=Vector((0,0,1)) if abs(direction.z)<.86 else Vector((1,0,0))
        ux=direction.cross(ref).normalized()*width*.5
        uy=direction.cross(ux).normalized()*depth*.5
        self.solid([tuple(center+sx*ux+sy*uy) for center in (p,q)
                    for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1))],
                   [(0,1,2,3),(4,5,6,7),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],mat)

    def profile(self,rows,mat,x=0,z=0,n=12):
        # Turn a horizontal profile on the vertical lathe axis.
        n=max(5,n//(1+self.level))
        vs=[(x+r*math.cos(i*math.tau/n),h,z+r*math.sin(i*math.tau/n))
            for h,r in rows for i in range(n)]
        self.solid(vs,self.rings(len(rows),n),mat)

    @staticmethod
    def rings(count,n):
        faces=[tuple(range(n)),tuple(range((count-1)*n,count*n))]
        for j in range(count-1):
            faces.extend((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for i in range(n))
        return faces

    def dial(self,c,outer,inner,depth,mat,n=32):
        x,y,z=c
        n=max(8,n//(self.level+1))
        vs=[(x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n),z+dz)
            for dz,r in [(-depth*.5,outer),(depth*.5,outer),(depth*.5,inner),(-depth*.5,inner)]
            for i in range(n)]
        faces=[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i)
               for j in range(4) for i in range(n)]
        self.solid(vs,faces,mat)

    def face(self,outline,z,width,mat):
        n=len(outline)
        self.solid([(x,y,z+offset) for offset in (-width*.5,width*.5) for x,y in outline],
                   self.rings(2,n),mat)

    def gable(self,x,y,z,w,rise,d,mat):
        self.face([(x-w*.5,y),(x,y+rise),(x+w*.5,y)],z,d,mat)

    def window(self,x,y,z,w,h):
        self.box((x,y,z),(w,h,.13),"dark")
        self.box((x,y,z+.09),(w*.84,h*.84,.07),"light")
        if self.level<2:
            self.box((x,y,z+.16),(.11,h,.07),"wood")
            self.box((x,y,z+.16),(w,.10,.07),"wood")
            self.box((x,y-h*.52,z+.12),(w*1.15,.13,.32),"cream")

    def finish(self,name):
        for mat,(verts,faces) in self.parts.items():
            obj=k.mesh(mat,verts,faces,self.mats[mat],self.root)
            for poly in obj.data.polygons: poly.use_smooth=False
        k.batch_assembly(self.root)
        mesh=next(o for o in self.root.children if o.type=="MESH" and o.name.endswith("_Mesh"))
        mesh.name=name
        return mesh


def wheel(b,c,r,spokes=8):
    x,y,z=c
    b.dial(c,r,r*.84,r*.16,"cast")
    b.dial((x,y,z+.08),r*.95,r*.89,r*.18,"gold")
    b.dial(c,r*.235,.035,r*.32,"gold",16)
    for i in range(spokes if b.level<2 else max(4,spokes//2)):
        a=i*math.tau/(spokes if b.level<2 else max(4,spokes//2))
        b.beam((x,y,z),(x+r*.88*math.cos(a),y+r*.88*math.sin(a),z),
               .12*r,.14*r,"red")


def blades(b,r,count):
    for i in range(count):
        angle=i*math.tau/count
        cs,sn=math.cos(angle),math.sin(angle)
        def xy(p):
            x,y=p
            return (x*cs-y*sn,x*sn+y*cs)
        shape=[(.10,.14),(.22,.24),(.23,.52),(.14,.84),(.045,1.0),
               (-.055,.95),(-.06,.67),(-.024,.31)]
        b.face([xy((x*r,y*r)) for x,y in shape],0,r*.045,"cream")
        if b.level<2:
            b.face([xy((x*r,y*r)) for x,y in [(0.015,.90),(.12,.80),(.045,1),(-.055,.95)]],
                   r*.029,r*.014,"red")
            b.beam((*xy((0,.10*r)),r*.03),(*xy((.01*r,.81*r)),r*.03),r*.025,r*.023,"gold")
    b.dial((0,0,0),r*.159,.017,r*.18,"red",20)


def station(b):
    for s in (-1,1):
        x=s*10
        b.box((x,.46,0),(2.20,.92,3.73),"stone")
        b.box((x,5,0),(1.02,9.1,2.30),"cast")
        b.box((x,7.91,0),(1.64,.42,2.95),"gold")
        for z in (-1,1):
            b.beam((x,6.97,z),(s*7.2,9.34,z),.43,.47,"red")
            b.beam((x,7.55,z),(s*7.65,9.45,z),.16,.24,"gold")
        b.gable(x,9.15,0,2.9,1.7,3.3,"red")
        if b.level<2:
            for h in (1.25,2.7,4.15,5.6):
                b.box((x,h,1.19),(.83,.14,.21),"gold")
        b.window(x,7.08,1.24,.72,1.12)
    for z in (-1,1):
        b.beam((-10,8.65,z),(0,10.7,z),.46,.42,"cast")
        b.beam((0,10.7,z),(10,8.65,z),.46,.42,"cast")
        b.beam((-10,8.45,z),(10,8.45,z),.29,.35,"cast")
        if b.level<2:
            for i in range(-5,5):
                x=i*2
                b.beam((x,8.48,z),(x+1,10.46-abs(x+1)*.202,z),.15,.16,"gold")
                b.beam((x+1,10.46-abs(x+1)*.202,z),(x+2,8.48,z),.15,.16,"gold")
    b.box((0,8.48,1.20),(9.65,.68,.20),"cast")
    b.box((0,8.82,1.26),(9.80,.09,.18),"gold")
    wheel(b,(0,9.89,1.36),1.23)
    b.gable(0,10.8,0,6.8,1.15,2.8,"red")


def turbine(b):
    b.profile([(0,2.65),(.42,2.72),(.72,2.20),(1.2,1.99),(8.9,1.15),(9.6,1.23)],"stone",n=16)
    b.profile([(1.08,2.03),(1.28,2.02)],"cast")
    b.profile([(6.9,1.48),(7.1,1.48)],"red")
    b.profile([(9.15,1.44),(9.48,1.62),(10.3,1.28),(10.9,.32)],"red",n=20)
    b.box((0,9.44,.99),(1.64,1.42,1.8),"cast")
    b.window(0,3.95,1.79,.66,1.05)
    if b.level<2:
        for s in (-1,1):
            b.beam((s*1.9,1.1,.82),(s*1.01,8.90,.65),.26,.24,"wood")


def mill(b):
    b.box((0,.41,0),(8.5,.82,6.08),"stone")
    b.box((0,3.14,0),(7.9,5.25,5.69),"cream")
    b.gable(0,5.73,0,8.55,2.95,6.40,"red")
    b.gable(0,5.72,2.93,7.8,2.54,.14,"cream")
    for x in (-3.78,-1.47,1.47,3.78):
        b.box((x,3.14,2.9),(.22,5.3,.22),"wood")
    for s in (-1,1):
        b.window(s*2.40,3.83,2.94,1.28,1.50)
        b.beam((s*3.63,5.86,3.04),(0,8.14,3.04),.22,.26,"wood")
        if b.level<2:
            b.beam((s*3.68,.88,2.94),(s*1.50,3.03,2.94),.18,.19,"wood")
        b.box((s*3.98,3.33,0),(.18,.25,5.8),"wood")
    b.box((0,3.0,2.94),(7.83,.22,.22),"wood")
    b.box((0,1.77,2.9),(1.76,2.92,.19),"cast")
    b.profile([(0,1.4),(5.5,1.33),(5.76,1.49),(6.68,.25)],"cast",x=-4.52,z=-1.15,n=14)
    b.profile([(7.3,.52),(10,.48),(10.12,.62),(10.46,.60)],"red",x=2.16,z=-.70)
    # The attic clock, directly above the running flywheel, marks the mill district.
    b.dial((0,7.09,3.10),.73,.045,.12,"cream",28)
    b.dial((0,7.09,3.19),.78,.68,.14,"gold",28)
    b.beam((0,7.09,3.22),(.34,7.36,3.22),.09,.065,"cast")
    b.beam((0,7.09,3.22),(-.16,7.56,3.22),.065,.07,"cast")
    if b.level==0:
        for i in range(12):
            a=i*math.tau/12
            b.beam((.51*math.sin(a),7.09+.51*math.cos(a),3.205),
                   (.61*math.sin(a),7.09+.61*math.cos(a),3.205),.045,.032,"wood")
        for j in range(5):
            y=5.86+j*.50
            x=4.15-j*.72
            for s in (-1,1): b.box((s*x,y,0),(.17,.118,6.43),"wood")


def bridge(b):
    for s in (-1,1):
        x=8.95*s
        for z in (-6.3,6.3):
            b.box((x,.31,z),(1.2,.62,1.26),"stone")
            b.beam((x,.59,z),(x,6.72,z),.40,.44,"cast")
            b.beam((x,4.72,z),(s*6.42,7.17,z),.29,.32,"red")
        for y in (1.05,4.45,6.68):
            b.beam((x,y,-6.3),(x,y,6.3),.32,.31,"cast")
        for i in range(3):
            z=-6.3+i*4.2
            b.beam((x,1.06,z),(x,4.43,z+2.1),.23,.25,"gold")
            b.beam((x,4.43,z+2.1),(x,1.06,z+4.2),.23,.25,"gold")
        if b.level==0:
            for z in (-6.15,-2.1,2.1,6.15):
                b.box((x,4.45,z),(.39,.65,.67),"red")
                for dz in (-.17,.17):
                    b.box((x-s*.226,4.45,z+dz),(.09,.11,.11),"gold")
        if b.level<2:
            for z in (-4.2,0,4.2): b.box((x,3.9,z),(.24,5.4,.24),"red")
    b.box((0,7.05,-6.3),(18.25,.34,.5),"cast")
    if b.level<2:
        b.beam((-8.9,7.05,-5.9),(8.9,7.05,5.9),.21,.21,"gold")


def signal_gate(b):
    for s in (-1,1):
        x=10.48*s
        b.box((x,.38,0),(1.42,.76,1.72),"stone")
        b.box((x,3.45,0),(.79,6.05,1.03),"cast")
        b.beam((x,4.72,0),(s*8.5,6.64,0),.33,.34,"red")
        for y in ([1.5,2.55,3.6] if b.level<2 else [2.5]):
            b.box((x,y,.56),(.80,.21,.13),"gold")
        b.profile([(5.98,.64),(6.58,.63),(6.9,.11)],"gold",x=x,n=12)
    b.box((0,6.52,0),(21.70,.98,.68),"cast")
    b.box((0,6.98,.21),(21.80,.12,.48),"gold")
    b.box((0,6.09,.23),(21.74,.12,.48),"red")
    for x in (-7.14,0,7.14):
        b.box((x,6.61,.37),(2.33,.71,.09),"dark")


def slider(b):
    b.box((0,.18,0),(2.80,.32,1.5),"dark")
    b.box((0,.71,0),(2.62,.85,1.32),"red")
    b.box((0,1.16,0),(2.70,.18,1.37),"cast")
    b.box((0,1.273,0),(1.47,.054,.71),"gold")
    for s in (-1,1):
        b.box((s*1.23,.68,0),(.16,.94,1.41),"cast")
        b.dial((s*.85,.53,.70),.255,.14,.08,"gold",16)
    if b.level==0:
        for x in (-1.09,1.09):
            for z in (-.46,.46):
                b.box((x,1.259,z),(.105,.07,.12),"gold")
    for j in ([0,1,2] if b.level<2 else [1]):
        x=-.67+j*.61
        b.beam((x-.23,.42,.67),(x+.06,.74,.67),.14,.04,"cream")
        b.beam((x+.06,.74,.67),(x-.23,1.04,.67),.14,.04,"cream")


def workshop(b):
    b.box((0,.36,0),(4.99,.72,3.68),"stone")
    b.box((0,2.18,0),(4.54,3.40,3.29),"cast")
    b.gable(0,3.85,0,5.03,1.83,3.87,"red")
    for x in (-1.96,1.96):
        b.box((x,1.88,2.15),(.18,3.30,.20),"wood")
    b.box((0,1.57,1.92),(4.19,.24,.91),"wood")
    b.box((0,2.32,1.68),(3.49,1.23,.10),"dark")
    for i in range(5):
        b.box((-1.83+i*.913,3.45,1.97),(.923,.17,1.13),
              "cream" if i%2==0 else "red")
    wheel(b,(0,4.36,1.95),.54,6)


def orchard(b):
    for x,z,h in ((0,0,4.65),(2.05,-1.05,3.35),(-1.68,-1.5,3.07)):
        b.profile([(0,.30),(h*.69,.21)],"wood",x=x,z=z,n=9)
        b.profile([(h*.36,.24),(h*.53,h*.22),(h*.74,h*.29),(h*.91,h*.19),(h,.17)],
                  "leaf",x=x,z=z,n=11)
        b.profile([(h*.72,h*.22),(h*.89,h*.19),(h*1.04,.09)],
                  "sunleaf",x=x-.15,z=z+.08,n=9)
        if b.level<2:
            b.beam((x,h*.29,z),(x+h*.16,h*.63,z+.08),.16,.15,"wood")


# The optional rotor has its own persistent pivot in all three camera ranges.
MODULES={
    "wind_whale":(whale,12.3,None), "station":(station,22.4,None), "turbine":(turbine,17.3,(0,9.48,2.03)),
    "mill":(mill,12.7,(0,4.83,3.59)), "bridge":(bridge,24.4,None),
    "signal_gate":(signal_gate,23.6,None), "slider":(slider,3.65,None),
    "workshop":(workshop,7.62,None), "orchard":(orchard,7.9,None),
}


def build(name,args):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src,span,pivot=MODULES[name]
    mats={m:k.material("Windwerk_"+m,c,metal,rough,.38 if m=="light" else 0)
          for m,(c,metal,rough) in COLORS.items()}
    root=k.empty("Windwerk_"+name)
    rotor=k.empty("Rotor",pivot,root) if pivot else None
    near=[]
    for level in range(3):
        group=k.empty("Static"+str(level),parent=root)
        builder=Builder(group,level,mats)
        src(builder)
        static_mesh = builder.finish("LOD"+str(level))
        if name=="wind_whale":
            for polygon in static_mesh.data.polygons:
                mat = static_mesh.data.materials[polygon.material_index]
                if mat in (mats["lagoon"], mats["cream"], mats["dark"]):
                    polygon.use_smooth = True
        near.append((static_mesh,level))
        if rotor:
            spin_group=k.empty("Spinning"+str(level),parent=rotor)
            moving=Builder(spin_group,level,mats)
            if name=="turbine": blades(moving,4.9,5)
            else: wheel(moving,(0,0,0),2.22,10)
            near.append((moving.finish("RotorLOD"+str(level)),level))
    asset=ROOT/"assets/kart/production/windwerk"
    asset.mkdir(exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in k.descendants(root): o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(asset/(name+".glb")),export_format="GLB",
                              use_selection=True,export_animations=False)
    for obj,level in near: obj.hide_render=level!=0
    camera=k.setup_studio()
    bpy.data.objects["StudioGround"].hide_render=True
    scene=bpy.context.scene
    scene.render.film_transparent=True
    scene.cycles.samples=48 if name=="wind_whale" else 12
    scene.cycles.max_bounces=3
    scene.cycles.use_denoising=False
    scene.render.threads=2
    scene.render.resolution_x=760 if name=="wind_whale" else 380
    scene.render.resolution_y=616 if name=="wind_whale" else 308
    scene.render.image_settings.file_format="WEBP"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.image_settings.quality=90
    camera.data.type="ORTHO"
    camera.data.ortho_scale=span*1.17
    for o in scene.objects:
        if o.type=="LIGHT":
            o.location*=span/2.6
            o.data.size*=span/2.6
            o.data.energy*=(span/2.6)**2
    heights={"wind_whale":3.2,"turbine":7.2,"station":5.6,"mill":4.95,"bridge":3.58,"signal_gate":3.6,
             "slider":.62,"workshop":2.60,"orchard":2.30}
    target=(0,heights[name],0)
    k.render_view(camera,asset/(name+".webp"),(.58*span,heights[name]+.47*span,1.6*span),target)
    print("WINDWERK COMPLETE",name,flush=True)


if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--only",choices=MODULES,nargs="+")
    args=cli.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    for name in (args.only or MODULES):
        build(name,args)
