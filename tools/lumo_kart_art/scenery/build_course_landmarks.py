"""Blender -b -P tools/lumo_kart_art/scenery/build_course_landmarks.py [-- track_id ...].

Original roadside sculptures in Godot coordinates. Dimensions in metres.
"""
import math
import sys
from pathlib import Path

from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/lumo_skypost_art'))
import skypost_geo as geo
sys.path.insert(0, str(Path(__file__).resolve().parent))
import course_finish

OUT = ROOT / 'assets/kart/scenery/landmarks'
TAU = math.tau


class Sculpture:
    def __init__(self, label, level, color):
        self.label = label
        self.level = level
        self.segments = (28, 16, 8)[level]
        self.model = geo.Model()
        self.materials = {
            'enamel': geo.material('Glasur', color, rough=.33, coat=.45),
            'gold': geo.material('Messing', 'e7ae55', metal=.64, rough=.32),
            'dark': geo.material('Gusseisen', '30475b', metal=.48, rough=.53),
            'stone': geo.material('Sandstein', 'cbb99c', rough=.85),
            'cream': geo.material('Elfenbeinlack', 'fff0d0', rough=.42),
            'light': geo.material('Lichtglas', 'fff3af', rough=.20, emission=.45),
        }

    def add(self, mesh, material, bevel=0):
        self.model.add(mesh, self.materials[material], bevel=bevel if self.level == 0 else 0)

    def box(self, position, size, material, rotation=(0, 0, 0)):
        self.add(geo.box(position, size, rot=rotation), material, .09)

    def rod(self, a, b, radius, material, end=None):
        self.add(geo.cylinder(a, b, radius, r2=end, segments=max(5, self.segments // 2)), material)

    def globe(self, center, radii, material):
        self.add(geo.sphere(center, radii, self.segments, max(5, self.segments // 2)), material)

    def ring(self, center, radius, tube, material, axis='y'):
        self.add(geo.torus(center, radius, tube, self.segments, (8, 6, 4)[self.level], axis=axis), material)

    def foot(self, width):
        self.add(geo.lathe([(width, -.7), (width, .45), (width * .94, .64),
                            (width * .88, .74)], segments=self.segments), 'stone')
        if self.level < 2:
            self.ring((0, .47, 0), width * .98, .10, 'gold')


def harbour(s):
    # Tall dock crane with pulley, braced jib, suspended lobster pot.
    s.foot(3.8)
    for side in (-1, 1):
        s.rod((side * 2, .65, 0), (side * .85, 9, 0), .44, 'enamel')
        s.rod((side * .85, 8.8, 0), (6, 11, side * .5), .19, 'gold')
        s.rod((side * .85, 4, 0), (6, 11, side * .5), .21, 'dark')
    s.ring((5.7, 10.5, 0), .61, .17, 'gold', 'z')
    s.rod((5.8, 10, 0), (5.8, 4.3, 0), .08, 'dark')
    for y in (2.8, 3.4, 4):
        s.ring((5.8, y, 0), 1.05, .09, 'gold')
    for i in range(8):
        a = TAU * i / 8
        s.rod((5.8+math.cos(a), 2.8, math.sin(a)), (5.8+math.cos(a), 4, math.sin(a)), .08, 'enamel')


def forest(s):
    # A family of great carved mushrooms with luminous gills under the caps.
    s.foot(3.6)
    for x,z,size in ((0,0,1),(-2.4,1,.53),(2,1,.45)):
        s.rod((x,.6,z), (x+.4*size,7*size,z), .85*size, 'cream', end=.45*size)
        s.globe((x,7*size,z),(3.65*size,1.65*size,3.65*size),'enamel')
        for i in range(9 if s.level < 2 else 4):
            a = TAU*i/(9 if s.level < 2 else 4)
            s.rod((x+.55*size,6.3*size,z), (x+2.87*size*math.cos(a),6.23*size,z+2.87*size*math.sin(a)), .08*size,'gold')
            s.globe((x+2*size*math.cos(a),8.32*size,z+2*size*math.sin(a)),(.33*size,.12*size,.33*size),'cream')


def mountain(s):
    # Cable car suspended from a forked pylon.
    s.foot(3)
    for x in (-1.5,1.5):
        s.rod((x,.6,0),(0,10,0),.32,'cream')
    s.box((0,10,0),(7,.5,1.3),'enamel')
    for x in (-2.55,2.55):
        s.ring((x,10,.6),.68,.13,'gold','z')
    s.rod((2.55,10,.8),(2.55,7,.8),.16,'dark')
    s.box((2.55,6,.8),(2.95,1.7,2.1),'enamel')
    s.box((2.55,7.55,.8),(3.18,.27,2.35),'cream')
    for x in (1.18,2.55,3.92):
        for z in (-.2,1.8):
            s.rod((x,6.69,z),(x,7.5,z),.09,'gold')


def city(s):
    s.foot(3.4)
    for k in range(3):
        a=TAU*k/3
        x,z=2.5*math.cos(a),2.5*math.sin(a)
        s.rod((x,.5,z),(x*.4,8,z*.4),.5,'dark',end=.20)
        s.globe((x*.4,8,z*.4),(.46,.8,.46),'light')
    for y,r in ((5,2.2),(7,2.6),(9.4,3.25)):
        s.ring((0,y,0),r,.21,'enamel')
    s.add(geo.star_prism((0,9.8,0),1.8,.55),'gold')


def crystal(s):
    s.foot(3.3)
    for x,z,h in ((0,0,9),(-2,1,4.7),(1.8,.9,6.3),(.6,-1.7,3.7)):
        s.add(geo.lathe([(1.18,.6),(1.35,h*.48),(.94,h*.85),(0,h)],segments=6,center=(x,0,z)),'enamel')
        if s.level < 2:
            s.rod((x+1.02,1,z),(x+.96,h*.78,z),.12,'light')
    s.ring((0,3.7,0),3.32,.21,'gold')


def jungle(s):
    # Carved toucan with overlapping wings and a two-colour bill.
    s.foot(2.85)
    s.rod((0,.6,0),(.65,4.1,0),1,'stone',end=.63)
    s.rod((-2.2,3.6,0),(2.2,4.45,0),.44,'dark')
    s.globe((0,5.5,0),(1.65,2.05,1.28),'enamel')
    s.globe((0,7.65,-.25),(1.3,1.38,1.3),'enamel')
    s.globe((0,7.48,-1.75),(1.01,.75,1.75),'gold')
    s.globe((0,7.26,-2.95),(.66,.48,.85),'dark')
    for side in (-1,1):
        s.globe((side*1.42,5.51,.27),(.4,1.36,1.12),'dark')
        s.globe((side*1.10,7.9,-.65),(.33,.37,.39),'cream')
        s.globe((side*1.31,7.93,-.73),(.16,.19,.18),'dark')


def candy(s):
    s.foot(3.6)
    s.add(geo.lathe([(1.5,.7),(1.18,1.2),(1.26,4.3),(2.7,4.55),(2.9,5.0)],segments=s.segments),'enamel')
    for k in range(6):
        a=TAU*k/6
        s.globe((1.62*math.cos(a),5.2,1.62*math.sin(a)),(1.2,1.22,1.2),'cream' if k%2 else 'enamel')
    s.globe((0,6.7,0),(1.72,1.52,1.72),'cream')
    s.globe((0,8.27,0),(.68,.71,.68),'enamel')
    s.rod((0,8.6,0),(.36,9.6,0),.09,'gold')


def volcano(s):
    # Three clay furnace chimneys, with iron hoops and glowing mouths.
    s.foot(3.8)
    for x,z,h in ((0,0,9.1),(-2.4,1,5.7),(2.25,.9,6.8)):
        s.add(geo.lathe([(1.03,.6),(1.15,1.5),(.72,h-1),(.99,h-.65),(.96,h),(.65,h),(.57,h-.6)],
                        segments=s.segments,center=(x,0,z)), 'enamel')
        s.globe((x,h-.6,z),(.58,.18,.58),'light')
        for y in (h*.35,h*.68):
            s.ring((x,y,z),1.01 if y<h*.5 else .83,.13,'dark')


def winter(s):
    # Two crossed snowshoes woven with brass cords, beside the warming bell.
    s.foot(3.35)
    for side in (-1,1):
        axis=Vector((side*.31,1,0)).normalized()
        perp=Vector((axis.y,-axis.x,0))
        center=Vector((side*1.2,4.7,0))
        count=(24,16,10)[s.level]
        rim=[center+axis*(3.9*math.cos(TAU*i/count))+perp*(1.05*math.sin(TAU*i/count)) for i in range(count)]
        for i in range(count):
            s.rod(rim[i],rim[(i+1)%count],.19,'enamel')
        for t in (-.72,-.43,-.14,.15,.44,.73):
            spread=math.sqrt(1-t*t)
            s.rod(center+axis*(3.9*t)-perp*spread, center+axis*(3.9*t)+perp*spread,.078,'gold')
    s.globe((0,2.1,-.5),(1,1.2,.85),'cream')


def galaxy(s):
    s.foot(3.2)
    s.rod((0,.65,0),(0,5.2,0),.64,'dark',end=.32)
    s.globe((0,6.3,0),(2.0,2.0,2.0),'enamel')
    s.ring((0,6.3,0),3.3,.23,'gold','x')
    s.ring((0,6.3,0),3.7,.17,'cream')
    s.globe((3.66,6.3,0),(.64,.64,.64),'gold')
    s.globe((0,9.64,0),(.4,.4,.4),'light')


def desert(s):
    s.foot(3.25)
    s.add(geo.lathe([(2.15,.65),(2.35,1),(1.92,1.34),(1.45,2.2),(.85,4.1)],segments=s.segments),'enamel')
    top=Vector((0,8.3,0))
    for i in range(12 if s.level < 2 else 6):
        a=TAU*i/(12 if s.level < 2 else 6)
        p=Vector((3.12*math.cos(a),4.7,1.75*math.sin(a)))
        s.rod((0,4,0),p,.14,'gold')
        s.rod(p,top,.085,'cream')
    s.rod((0,2.1,0),top,.16,'dark')
    s.add(geo.star_prism(top, .82,.19),'gold')


def lab(s):
    s.foot(3.25)
    # Oversize microscope with a real tube, rotatable lens wheel and specimen stage.
    s.box((0,1.05,0),(4.4,.7,3.2),'enamel')
    s.rod((-1.5,1.4,0),(-2.05,5.5,0),.57,'enamel')
    s.rod((-2.05,5.5,0),(1.1,7.65,0),.56,'enamel')
    s.rod((1.45,8.4,0),(.48,5.2,0),.49,'gold')
    s.rod((1.45,8.4,0),(1.64,9.03,0),.59,'dark')
    s.ring((.49,5.1,0),.72,.18,'dark')
    for x in (-.1,.55,1.15):
        s.rod((x,5.09,0),(x,4.25,0),.13,'gold')
    s.box((0,3.52,0),(3.25,.23,2.25),'dark')
    s.globe((-.25,3.82,0),(.58,.2,.48),'enamel')
    s.ring((-1.82,4.75,.67),.65,.15,'cream','z')


def canopy(s):
    # Kapok seed pod splitting into three pale, fluffy seed heads.
    s.foot(3.6)
    for i in range(3):
        a=TAU*i/3
        end=Vector((2.6*math.cos(a),7.4+i*.63,2.6*math.sin(a)))
        s.rod((0,.65,0),end,.54,'enamel',end=.21)
        for j in range(7 if s.level < 2 else 4):
            angle=TAU*j/(7 if s.level < 2 else 4)
            tip=end+Vector((1.08*math.cos(angle),.57+.33*(j%2),1.08*math.sin(angle)))
            s.globe(tip,(.79,.84,.79),'cream')
        s.globe(end,(.81,.67,.81),'gold')


COURSES = {
    'sonnenhafen': (harbour,'26898f'), 'zauberwald': (forest,'c96171'),
    'bergwelt': (mountain,'ec8e39'), 'holo_city': (city,'2db4c8'),
    'crystal_canyon': (crystal,'9a78e8'), 'jungle_temple': (jungle,'358f9b'),
    'candy_cloud': (candy,'d14e89'), 'volcano_night': (volcano,'af523b'),
    'winter_sprint': (winter,'288a9c'), 'galaxy_ringway': (galaxy,'7856b9'),
    'desert_drift': (desert,'268f99'), 'learning_lab': (lab,'4385a8'),
    'jungle_emerald_3600': (canopy,'548c49'),
}


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for track in (sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else COURSES):
        make, color = COURSES[track]
        geo.reset_scene()
        root = geo.empty(track)
        atlas = course_finish.make_atlas(track, color)
        counts = []
        for level in range(3):
            piece = Sculpture(track,level,color)
            make(piece)
            obj = piece.model.build(f'{track}_lod{level}',root)
            course_finish.assign(obj, atlas)
            counts.append(geo.tri_count(obj))
        assert counts[0] > counts[1] > counts[2], (track, counts)
        geo.export_glb(root,OUT / (track+'.glb'))
        print('Wahrzeichen', track, counts)
