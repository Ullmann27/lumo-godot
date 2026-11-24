"""Six original Parcours landmarks. Run blender -b -t 2 -P tools/lumo_parcours_art/build_landmarks.py.
Metres, Y-up. Each GLB uses one opaque vertex-coloured mesh and one surface.
"""
from math import cos, sin, pi, tau
from pathlib import Path
import sys

import bpy

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/lumo_windwerk_art"))
from build_windwerk import Builder, k

COLORS = dict(
    teal="286b73", deep="203c4c", orange="c95633", gold="e6a44a", canvas="f4dcac",
    wood="78462c", stone="8e7266", snow="d6e7ee", blue="3d7190", glacier="3398ae",
    frost="8adad6", shadow="234655", slate="475563", moss="4e763d", jade="278675",
    fern="719644", ochre="b99b62", river="54bdb3", foam="b5e3d1",
)


def airship(b):
    # Tapered sewn gores along the long axis, hoops and a keel with suspended cabin.
    rings = [(-10, .16), (-8.8, 2), (-6, 3.15), (-2, 3.8), (2, 3.8),
             (5.8, 3.2), (8.4, 2.05), (9.8, .12)]
    def hull(x, r, i):
        a = i * tau / 16
        return (x, 6.3 + sin(a) * r, cos(a) * r * .85)
    for (x, r), (nx, nr) in zip(rings, rings[1:]):
        for i in range(16):
            tint = "orange" if i % 8 in (0, 7) else ("teal" if i % 8 == 6 else "canvas")
            b.solid([hull(x, r, i), hull(nx, nr, i), hull(nx, nr, i+1), hull(x, r, i+1)], [(0,1,2,3)], tint)
        if r > .5:
            for i in range(16):
                b.beam(hull(x, r+.035, i), hull(x, r+.035, i+1), .10, .09, "gold")
    for x in (-3.5, 3.5):
        for side in (-1,1):
            b.beam((x, 4.7, side * 2.45), (x*.8, 1.1, side * .96), .12, .12, "deep")
    b.face([(-4.6,1.36), (4.7,1.36), (3.5,.05), (-2.9,-.2)], 0, 2.45, "wood")
    b.box((0,1.55,0), (6.7,1.14,2.18), "teal")
    b.box((0,2.19,0), (7.3,.24,2.66), "gold")
    for side in (-1,1):
        for x in (-2.5,-1.25,0,1.25,2.5):
            b.box((x,1.64,side*1.10), (.85,.57,.08), "canvas")
    b.face([(5.3,8.3),(8.9,10.6),(9.6,10.45),(8.8,7)], 0, .23, "teal")
    b.face([(5.6,4.6),(9.4,2.5),(9.6,2.8),(8.8,5.9)], 0, .2, "orange")


def dock(b):
    # A suspended goods crane with a tied-off cargo net and counterweight.
    b.profile([(-6,.45),(-2,4.3),(-.4,5.7),(0,5.7)], "slate", n=8)
    b.box((0,.13,0), (9.2,.48,6.4), "wood")
    for z in (-1.8,1.8):
        for x in (-1.9,1.9):
            b.beam((x,.3,z),(x*.48,7,z*.53),.46,.48,"teal")
        for i in range(3):
            h = .65 + 2*i
            b.beam((-1.7 + i*.21,h,z*(1-h*.065)),(1.5-i*.21,h+1.75,z*(1-(h+1.75)*.065)),.22,.22,"gold")
    b.box((0,7.25,0),(3.6,.63,3.4),"teal")
    for z in (-.7,.7):
        b.beam((-3.7,7.7,z),(6.9,10.2,z),.42,.4,"orange")
        b.beam((-1.4,7.6,z),(1.3,11.25,z),.29,.28,"teal")
        b.beam((1.3,11.25,z),(6.9,10.2,z),.15,.15,"teal")
    b.box((-3.3,7.1,0),(1.65,1.38,2),"slate")
    b.beam((6.3,10,0),(6.3,3.9,0),.12,.12,"deep")
    b.box((6.3,3.0,0),(1.8,1.8,1.8),"wood")
    for x in (5.78,6.82):
        b.box((x,3.0,0),(.14,1.87,1.87),"canvas")


def floe(b):
    b.profile([(-2.7,3.7),(-1,6.3),(-.25,6.5)], "glacier", n=10)
    b.profile([(-.25,6.5),(0,6.15)], "snow", n=10)


def observatory(b):
    floe(b)
    b.profile([(0,4.1),(.7,4.1),(1,3.6),(4.7,3.4)], "blue", n=12)
    for i in range(12):
        a = i*tau/12
        p=(cos(a)*3.48, 2.8, sin(a)*3.48)
        b.beam((p[0],1.9,p[2]), (p[0],3.7,p[2]), .52,.52,"gold")
    b.profile([(4.5,3.88),(4.85,3.90),(5.0,3.5)], "gold", n=20)
    b.profile([(5.0,3.53),(5.7,3.49),(6.4,3.23),(7.25,2.60),(8.0,1.62),(8.3,.22)], "teal", n=24)
    # Copper dome ribs arch over the meridian shutter.
    for i in range(8):
        a=i*tau/8
        for j in range(6):
            def rib(t):
                t=t*pi/12
                return (cos(a)*3.56*cos(t),5+3.33*sin(t),sin(a)*3.56*cos(t))
            b.beam(rib(j),rib(j+1),.10,.11,"gold")
    b.beam((0,6.45,2.35),(0,9.05,5.66),.89,.87,"deep")
    b.beam((0,8.81,5.35),(0,9.15,5.83),1.19,1.11,"gold")
    b.gable(-3.72,2,1.8,3.8,1.65,4,"snow")
    b.box((-3.7,1,1.8),(3.3,2,3.7),"slate")


def ice_arch(b):
    # A carved glacial arch with an actual open centre. The caps trace its broken silhouette.
    floe(b)
    outline=[(-6.5,0),(-6.3,6.8),(-4.8,9.2),(-1.95,9.65),(-.8,10.15),
             (3.9,9.25),(5.7,8),(6.3,1.1),(4.15,-.2),(3.25,4.8),
             (2.2,6.05),(-.7,6.35),(-2.7,5.22),(-3.55,3),(-3.9,0)]
    b.face(outline,0,4,"glacier")
    for (x,y),(u,v) in zip(outline[2:6],outline[3:7]):
        b.face([(x,y),(u,v),(u,v-.30),(x,y-.63)],0,4.28,"snow")
    for i,(x,y,length) in enumerate([(-2.3,6,1.25),(-1.45,6.2,1.07),(.3,6.35,2.1),(1.1,6.15,1.4),(2.15,6,.75)]):
        b.profile([(y-length,.04),(y,.36)],"frost",x=x,z=1.92-i%2*.5,n=6)
    for x,y in [(-4.8,5.3),(4.4,6.3),(-5.6,4.2)]:
        b.beam((x,y,2.02), (x+.52,y+1.55,2.02),.105,.085,"frost")


def leaf(b,origin,angle,length,height):
    x,y,z=origin
    dx,dz=cos(angle),sin(angle)
    side=(-dz,dx)
    def v(f,w,h):
        return (x+dx*f*length+side[0]*w,y+h*height,z+dz*f*length+side[1]*w)
    b.solid([v(0,0,0),v(.48,-length*.13,.82),v(.42,0,1),v(.55,length*.12,.83),v(1,0,.36)],
            [(0,1,2),(0,2,3),(1,4,2),(2,4,3)],"fern")


def temple(b):
    # A stone bird shrine. The brows, terraced feathers and hooked gold beak read in silhouette.
    for h,w in [(0,10.4),(.65,9.45),(1.3,8.4)]:
        b.box((0,h-.25,0),(w,.76,w*.67),"stone" if h==0 else "ochre")
    b.box((0,2.2,0),(4.45,2.4,3.62),"jade")
    b.face([(-2.9,3.3),(-3.25,6.4),(-2.15,7.9),(0,7.18),(2.3,7.84),(3.21,6.47),(2.9,3.3)],0,3.75,"ochre")
    for side in (-1,1):
        for i in range(4):
            x=side*(2.0+.83*i)
            b.face([(x,3.7+i*.6),(x+side*1.03,4.28+i*.6),(x+side*.83,1.74+i*.63),(x,2.33+i*.6)],.23,1.58,"jade" if i%2==0 else "moss")
        b.dial((side*1.38,5.59,1.99),.87,.47,.39,"jade",16)
        b.dial((side*1.38,5.59,2.22),.37,.07,.22,"deep",14)
        b.beam((side*.63,6.06,2.15),(side*2.45,6.87,2.03),.40,.41,"gold")
        for i in range(7):
            leaf(b,(side*4.28,1.36,-1.52),i*tau/7,1.85,1.36)
    b.solid([(-.82,6.04,1.9),(.82,6.04,1.9),(0,6.0,3.4),(0,3.74,3.16),(0,4.8,1.9)],
            [(0,1,2),(0,2,3),(2,1,3),(3,1,4),(0,3,4)],"gold")


def cascade(b):
    for x,h in [(-4.25,7.8),(-1.62,7.0),(1.2,6.1),(4.14,4.8)]:
        b.profile([(-1.8,2.65),(h*.6,2.72),(h,2.18)],"stone",x=x,z=-.45,n=7)
        b.profile([(h-.3,2.34),(h+.17,2.23)],"moss",x=x,z=-.45,n=7)
        for i in range(3):
            y=h-i*.18; z=1.58+i*.13
            b.face([(x-.78+i*.42,y),(x-.43+i*.42,y-.13),(x-.32+i*.42,.12),(x-.78+i*.42,.14)],z,.12,"river" if i%2==0 else "foam")
        for i in range(7):
            leaf(b,(x,h+.14,-.6),i*tau/7+x,1.7,1.6)
    for i in range(4):
        x=-4.4+i*2.7
        b.profile([(-.23,1.2),(.2,1.37),(.58,.46)], "foam",x=x,z=1.66,n=10)


def export(name, draw):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builder=Builder(None,0,{})
    draw(builder)
    vertices, faces, colours = [], [], []
    for tint,(vs,fs) in builder.parts.items():
        base=len(vertices)
        vertices.extend(vs)
        colours.extend([k.linear(COLORS[tint])]*len(vs))
        faces.extend([tuple(base+i for i in f) for f in fs])
    mat=k.material("PaintedCeramic", "ffffff", .08, .68)
    attr=mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name="Pigment"
    mat.node_tree.links.new(attr.outputs["Color"],mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    model=k.mesh(name,vertices,faces,mat)
    data=model.data
    for poly in data.polygons:
        poly.use_smooth=False
    color=data.color_attributes.new(name="Pigment",type="BYTE_COLOR",domain="POINT")
    for index, rgb in enumerate(colours):
        color.data[index].color=rgb
    target=ROOT / "assets/kart/parcours/landmarks" / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(target),export_format="GLB",export_animations=False,export_texcoords=False)
    print("PARCOURS",name,len(faces),target.stat().st_size,flush=True)


for name, draw in dict(airship=airship,freight_dock=dock,observatory=observatory,
                       glacier_arch=ice_arch,bird_shrine=temple,rainfall=cascade).items():
    export(name,draw)
