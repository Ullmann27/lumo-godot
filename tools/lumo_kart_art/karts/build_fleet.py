"""Build the selectable coachwork and transparent catalog renders with Blender 4.3+.

blender -b -t 2 --python tools/lumo_kart_art/karts/build_fleet.py -- --flutter ../lumo-lernen
Repeat --only ID to rebuild selected karts. Dimensions use Godot metres, front = -Z.
Each GLB contains three independent shell meshes, fitted decal anchors and showroom detail.
The photographed wheels, steering and suspension are imported from the same GLB used in races.
"""
import argparse
import math
from pathlib import Path
import shutil
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_karts as k
import console_fleet

# Mechanical platform, paint, trim, accent, luminous accent.
DESIGNS = {
    "comet": ("comet", "2557d6", "dfe9f6", "f08a2c", "2fd0ff"),
    "gecko_velo": ("glider", "a9dd37", "edf9ff", "f08a2c", "72e6ff"),
    "boru_rally": ("comet", "cc7d3f", "edf9ff", "b7cddd", "72e6ff"),
    "glider": ("glider", "dff0ff", "3fd0c0", "ffffff", "4fffe6"),
    "nala_comet": ("comet", "ef7968", "edf9ff", "ffd36a", "72e6ff"),
    "noa_tide": ("glider", "478de1", "edf9ff", "ba8452", "72e6ff"),
    "iva_aurora": ("glider", "a0a6e9", "edf9ff", "ffd36a", "c79bff"),
    "turbo": ("turbo", "3a1f6e", "ffd36a", "ffb43a", "c79bff"),
    "zuri_volt": ("comet", "efc044", "101c30", "72e6ff", "72e6ff"),
    "blitz": ("turbo", "ffcf2e", "1a1c24", "ff5a2c", "ffe45c"),
    "terra": ("comet", "2f6b4a", "c9b38a", "ff9a3c", "8cff7a"),
    "koloss": ("comet", "8c1f2e", "5a6272", "ffb43a", "ff7a6a"),
    "phantom": ("turbo", "1b1233", "ff4fd8", "7a5cff", "ff5ce6"),
    "stella": ("turbo", "f2c24a", "fff4cf", "1d3e8a", "ffe9a0"),
}

DESIGNS.update(console_fleet.DESIGNS)


class Coachwork:
    def __init__(self, design):
        self.design = design
        self.root = k.empty("Shell_" + design)
        core, paint, trim, accent, lamp = DESIGNS[design]
        self.axle = .77 * k.STANCES[core]
        self.mats = {
            "p": k.material("Fleet_" + design + "_paint", paint, .34, .25, coat=.5),
            "t": k.material("CeramicPearl", trim, .28, .28, coat=.3),
            "a": k.material("SatinAccent", accent, .55, .30),
            "c": k.material("GraphiteComposite", "18232d", .18, .45),
            "m": k.material("BrushedAluminium", "b9c9cd", .8, .26),
            "s": k.material("WovenSeatUpholstery", "29435e", .02, .8),
            "l": k.material("InsetCyanLens", lamp, .15, .22, .6),
            "b": k.material("RearBrakeLens", "ee5050", .12, .24, .4),
        }

    def loft(self, name, rows, mat="p", x=0, power=.78):
        part = k.loft(name, rows, self.mats[mat], self.root, 24, 3, power=power)
        part.location.x = x
        return part

    def box(self, name, at, size, mat, bevel=.02):
        return k.bevel_box(name, at, size, self.mats[mat], self.root, bevel)

    def bulb(self, name, at, radii, mat):
        return k.ellipsoid(name, at, radii, self.mats[mat], self.root, 24, 12)

    def tube(self, name, points, r, mat):
        return k.tube(name, points, r, self.mats[mat], self.root, 10)

    def blade(self, name, stations, mat):
        return k.wing(name, stations, self.mats[mat], self.root)

    def panel(self, name, outline, depth, mat):
        # Extrude a side elevation with individual X stations to allow splayed fins.
        n = len(outline)
        verts = [(x + offset, y, z) for offset in (-depth/2, depth/2) for x, y, z in outline]
        faces = [tuple(range(n)), tuple(range(n, 2*n))]
        faces.extend((i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n))
        obj = k.mesh(name, verts, faces, self.mats[mat], self.root)
        for p in obj.data.polygons:
            p.use_smooth = False
        modifier = obj.modifiers.new("Rolled edge", "BEVEL")
        modifier.width = min(.016, depth/4)
        modifier.segments = 3
        return obj

    def lamp(self, x, y, z, r):
        self.bulb("Cast lamp bezel", (x,y,z), (r,r,r*.65), "m")
        self.bulb("Lens", (x,y,z-r*.43), (r*.82,r*.82,r*.39), "l")

    def cockpit(self):
        self.box("Floor tub",(0,.14,.0),(.83,.12,1.9),"c",.045)
        self.box("Seat base",(0,.217,.24),(.53,.113,.47),"c",.045)
        self.bulb("Seat squab",(0,.27,.20),(.26,.048,.23),"s")
        seat = [(.49,.15,.035,.39),(.60,.245,.052,.406),(.80,.255,.053,.475),
                (.915,.205,.048,.516),(.948,.075,.030,.53)]
        k.loft("Bucket back",seat,self.mats["c"],self.root,24,3,vertical=True)
        k.loft("Padded back",[(y,w*.86,h*.64,z-.037) for y,w,h,z in seat],
               self.mats["s"],self.root,24,3,vertical=True)
        for side in (-1,1):
            x=side*.34
            self.tube("Coaming",[(x,.49,-.31),(x,.54,-.17),(x,.56,.16),
                                   (x,.58,.40),(x,.60,.59)],.027,"c")
            self.box("Foot pedal",(side*.15,.213,-.40),(.15,.045,.20),"m")
            self.tube("Harness",[(side*.105,.91,.48),(side*.11,.80,.425),
                                 (side*.11,.65,.375),(side*.115,.58,.342)],.019,"a")
            self.tube("Exhaust",[(side*.19,.38,.72),(side*.19,.43,.94),
                                  (side*.12,.467,1.112)],.055,"m")
            self.box("Boost outlet",(side*.12,.467,1.122),(.087,.038,.015),"c")
            self.box("Rear brake lamp",(side*.242,.683,1.064),(.162,.045,.028),"b")
        self.loft("Engine cover",[(.51,.31,.09,.465),(.65,.36,.12,.51),
                  (.87,.37,.13,.54),(1.06,.31,.097,.575)],"c",power=.54)
        for z in (.70,.79,.88,.97):
            self.box("Cooling rib",(0,.654,z),(.42,.024,.031),"m",.009)

    def sides(self, width, height, mat="p", power=.70):
        for s in (-1,1):
            self.loft("Side sill",[(-.37,.035,.08,.36),(-.24,width*.56,.12,.38),
                     (-.10,width,height,.39),(.18,width,height,.40),
                     (.31,width*.72,.13,.40),(.55,.05,.12,.43),(.66,.024,.09,.46)],
                     mat,s*(.32+width*.86),power)

    def stripe(self, points, width, material):
        k.ribbon("Coach stripe",points,(0,1,0),width,.009,self.mats[material],self.root)

    def arch(self, s, z, length, width, height, material, boxy=False):
        # The tyres rotate below the crowns of the wheel arches.
        x=s*self.axle
        if boxy:
            # Folded fender with chamfered leading edge and an inner wing that
            # physically joins the bonnet to the arch over the steered tyre.
            self.loft("Pressed wheel arch",[(z-length*.51,width*.32,.030,height-.075),
                      (z-length*.43,width*.48,.048,height-.025),
                      (z-length*.20,width*.50,.044,height),(z+length*.25,width*.50,.048,height),
                      (z+length*.44,width*.47,.055,height-.035),
                      (z+length*.51,width*.35,.04,height-.105)],material,x,.32)
            self.blade("Inner wing",[(s*.31,height-.13,z,.46,.13),
                       (s*.49,height-.086,z,.50,.10),(x,height-.018,z,.47,.075)],material)
            for edge in (-1,1):
                z0=z+edge*length*.33
                self.tube("Fender bracket",[(s*.37,height-.23,z0+edge*.04),
                          (s*.51,height-.14,z0),(s*(self.axle-.095),height-.044,z0)],.024,"m")
            self.box("Trailing mud flap",(x,height-.148,z+length*.44),
                     (width*.89,.164,.039),"c",.012)
        else:
            self.loft("Wheel-arch crown",[(z-length*.5,.022,.025,height-.15),
                   (z-length*.43,width*.41,.052,height-.055),(z-length*.12,width*.5,.079,height+.02),
                   (z+length*.18,width*.48,.078,height),(z+length*.44,width*.34,.055,height-.08),
                   (z+length*.5,.025,.024,height-.145)], material,x)

    def tailfin(self,s,x,base,peak,start,end,mat="p"):
        self.panel("Swept tailfin",[(s*x,base,start),(s*(x+.025),base+.10,start+.14),
                   (s*(x+.085),peak,end),(s*(x+.069),base+.07,end-.025),
                   (s*x,base,end-.15)],.079,mat)

    def spoiler(self,span,height,z,chord,material):
        for s in (-1,1):
            self.tube("Spoiler stay",[(s*.29,.62,.80),(s*.36,height,z)],.03,"m")
        self.blade("Rear aerofoil",[(x*span,height+abs(x)*.045,z+abs(x)*.07,
                    chord*(1-.2*abs(x)),.081) for x in (-1,-.72,0,.72,1)],material)

    def grille(self,z,width,height,y):
        self.box("Grille opening",(0,y,z),(width,height,.026),"c")
        for i in range(3):
            self.box("Grille louvre",(0,y+(i-1)*height*.245,z-.019),
                     (width*.87,.013,.018),"m",.004)


def comet(c):
    c.sides(.19,.15)
    c.loft("Formula nose",[(-1.30,.07,.039,.29),(-1.18,.16,.085,.34),
           (-.95,.21,.13,.395),(-.58,.28,.17,.47),(-.30,.36,.20,.461)])
    c.stripe([(0,.338,-1.28),(0,.44,-1.14),(0,.535,-.93),(0,.639,-.58),(0,.669,-.32)],.115,"t")
    c.blade("Front mainplane",[(x,.214+.05*abs(x),-1.17+.065*abs(x),.21,.066)
            for x in (-.91,-.70,0,.70,.91)],"p")
    for s in (-1,1):
        c.blade("Wing flap",[(s*.19,.257,-1.12,.10,.053),(s*.61,.285,-1.10,.12,.045),
                              (s*.89,.306,-1.07,.115,.042)],"t")
        c.box("Front end plate",(s*.91,.284,-1.115),(.044,.19,.32),"a")
        c.lamp(s*.145,.43,-1.10,.043)
        c.tailfin(s,.39,.53,.82,.52,1.06)
    c.spoiler(.52,.74,1.01,.20,"p")


def gecko_velo(c):
    c.sides(.137,.125,power=.93)
    for s in (-1,1):
        c.loft("Forked muzzle",[(-1.30,.02,.027,.335),(-1.14,.075,.075,.395),
               (-.92,.132,.12,.455),(-.67,.143,.16,.475),(-.33,.165,.17,.465)],"p",s*.175)
        c.bulb("Raised eye fairing",(s*.256,.576,-.872),(.10,.085,.14),"p")
        c.lamp(s*.26,.591,-.974,.064)
        c.blade("Hind haunch",[(s*.33,.52,.55,.62,.24),(s*.50,.62,.60,.64,.18),
                               (s*.62,.70,.80,.42,.11),(s*.73,.80,1.13,.10,.04)],"p")
        for n in range(3):
            c.blade("Gill blade",[(s*.44,.48,.00+n*.078,.082,.032),
                   (s*.67,.53,.09+n*.08,.129,.047),(s*.76,.59,.21+n*.066,.035,.02)],"t")
    c.loft("Spine",[(-.92,.035,.05,.40),(-.76,.075,.084,.49),
           (-.64,.095,.089,.544),(-.31,.17,.11,.53)],"t")


def boru_rally(c):
    c.sides(.20,.20,power=.36)
    c.loft("Rally bonnet",[(-1.14,.325,.102,.53),(-1.06,.39,.135,.545),
           (-.75,.398,.15,.55),(-.37,.38,.148,.53)],power=.32)
    c.grille(-1.149,.45,.135,.52)
    for s in (-1,1):
        for z in (-.66,.66): c.arch(s,z,.83,.38,.748,"p",True)
        c.lamp(s*.291,.686,-1.07,.105)
        c.tube("Rally hoop",[(s*.382,.38,.35),(s*.412,1.25,.66),
               (s*.34,1.36,.685),(0,1.39,.69)],.042,"c")
        c.tube("Hoop brace",[(s*.39,1.21,.64),(s*.39,.59,.95)],.035,"m")
        c.tube("Brush guard",[(s*.52,.37,-1.13),(s*.47,.56,-1.21),(0,.56,-1.21)],.026,"m")
        c.stripe([(s*.22,.656,-1.10),(s*.22,.699,-.83),(s*.22,.681,-.41)],.067,"t")
        c.lamp(s*.255,1.414,.672,.075)
        c.lamp(s*.087,1.414,.672,.075)


def glider(c):
    c.sides(.105,.112,power=.9)
    c.loft("Sailplane fuselage",[(-1.39,.014,.03,.42),(-1.21,.12,.09,.435),
           (-.88,.17,.14,.47),(-.62,.22,.17,.48),(-.30,.35,.16,.46)])
    for s in (-1,1):
        c.blade("Gull wing",[(s*.32,.48,-.05,.70,.125),(s*.60,.57,.03,.60,.115),
                (s*.79,.60,.18,.48,.091),(s*.99,.75,.34,.31,.060),
                (s*1.065,.80,.46,.096,.033)],"p")
        c.blade("Wingtip flash",[(s*.91,.70,.30,.35,.073),(s*.99,.756,.35,.30,.066),
                                (s*1.069,.806,.46,.095,.036)],"t")
        c.blade("Tailplane",[(s*.19,.67,.87,.41,.082),(s*.52,.72,1.00,.25,.060),
                              (s*.61,.78,1.09,.095,.031)],"t")
    c.tailfin(1,0,.64,1.13,.73,1.15,"p")


def nala_comet(c):
    c.sides(.205,.181)
    c.loft("Convertible hood",[(-1.21,.17,.092,.444),(-1.125,.343,.15,.48),
           (-.97,.405,.17,.505),(-.67,.398,.16,.523),(-.33,.365,.145,.52)])
    c.grille(-1.185,.38,.103,.463)
    for s in (-1,1):
        c.loft("Pontoon fender",[(-1.19,.058,.085,.531),(-1.1,.115,.14,.55),
               (-.86,.135,.142,.555),(-.55,.113,.11,.50),(-.17,.055,.074,.43)],"p",s*.374)
        c.lamp(s*.374,.586,-1.164,.095)
        c.loft("Rear pontoon",[(.12,.044,.068,.46),(.36,.108,.14,.48),
               (.64,.125,.17,.57),(1.06,.102,.14,.59),(1.17,.04,.071,.58)],"p",s*.425)
        c.tailfin(s,.445,.58,1.14,.29,1.17)
        c.tube("Chrome fin cap",[(s*.448,.626,.315),(s*.47,.739,.466),
                                 (s*.53,1.139,1.168)],.018,"m")
        c.tube("Side spear",[(s*.486,.562,-.86),(s*.52,.49,-.29),
                              (s*.682,.468,.03),(s*.56,.57,.68)],.017,"t")
        c.bulb("Fin jewel",(s*.505,.77,1.08),(.055,.062,.039),"b")
    c.stripe([(0,.56,-1.18),(0,.667,-.99),(0,.691,-.73),(0,.675,-.37)],.035,"m")


def noa_tide(c):
    c.sides(.165,.18,power=.8)
    c.loft("Clinker bow",[(-1.38,.02,.065,.44),(-1.25,.17,.13,.46),(-1.04,.302,.175,.471),
           (-.81,.385,.195,.478),(-.54,.425,.179,.481),(-.32,.38,.155,.487)],power=.69)
    c.loft("Teak foredeck",[(-1.30,.025,.015,.554),(-1.13,.181,.03,.612),
           (-.86,.284,.035,.649),(-.57,.325,.034,.648),(-.34,.288,.031,.636)],"a",power=.63)
    for s in (-1,1):
        c.tube("Sheerline",[(0,.502,-1.375),(s*.181,.558,-1.234),(s*.322,.593,-1.01),
               (s*.405,.591,-.75),(s*.427,.571,-.46),(s*.46,.569,-.20),
               (s*.51,.56,.13),(s*.42,.60,.58),(s*.40,.626,.95)],.021,"t")
        for n in (0,1):
            x=s*(.09+.086*n)
            c.tube("Deck caulking",[(x,.650,-1.01+n*.10),(x,.685,-.81),
                                    (x,.686,-.57),(x,.665,-.365)],.007,"t")
        c.bulb("Stern buoy",(s*.445,.53,.84),(.10,.095,.29),"t")
        c.tube("Grab rail",[(s*.40,.60,.47),(s*.435,.748,.60),(s*.425,.748,.85),
                            (s*.40,.62,.96)],.018,"m")
    c.lamp(0,.514,-1.36,.055)


def iva_aurora(c):
    c.sides(.133,.14)
    c.loft("Falcon beak",[(-1.43,.014,.019,.38),(-1.27,.075,.057,.425),
           (-1.02,.184,.102,.502),(-.68,.235,.137,.524),(-.31,.335,.16,.497)])
    for s in (-1,1):
        for i in range(4):
            z=-.34+i*.218
            x=.73+i*.078
            c.blade("Slotted flight feather",[(s*.33,.455+i*.035,z,.50,.119),
                    (s*.53,.55+i*.051,z+.10,.37,.10),(s*(x-.074),.63+i*.076,z+.32,.24,.06),
                    (s*x,.69+i*.077,z+.54,.043,.023)],"p" if i in (0,2,3) else "t")
            c.blade("Feather shaft",[(s*.42,.527+i*.04,z+.05,.037,.026),
                    (s*.55,.589+i*.055,z+.15,.030,.019),
                    (s*(x-.045),.666+i*.076,z+.45,.017,.014)],"a")
        c.tailfin(s,.34,.59,.969,.63,1.15,"t")
    c.stripe([(0,.434,-1.29),(0,.537,-1.14),(0,.623,-.98),(0,.67,-.68),(0,.669,-.34)],.052,"a")


def turbo(c):
    c.sides(.24,.163,power=.49)
    c.loft("Endurance wedge",[(-1.30,.32,.04,.345),(-1.23,.452,.075,.36),
           (-1.01,.45,.103,.40),(-.70,.40,.152,.472),(-.31,.36,.172,.488)],power=.44)
    c.blade("Splitter",[(x,.25,-1.184+abs(x)*.073,.26,.04) for x in (-.88,-.45,0,.45,.88)],"c")
    for s in (-1,1):
        for z in (-.66,.66): c.arch(s,z,.99,.49,.75,"p")
        c.loft("Fender shoulder",[(-1.23,.045,.05,.42),(-1.04,.20,.095,.52),
               (-.79,.23,.121,.605),(-.54,.168,.095,.597),(-.38,.045,.05,.53)],"p",s*.54)
        c.tube("Headlamp slash",[(s*.378,.458,-1.231),(s*.502,.496,-1.165),
                                 (s*.649,.565,-1.075)],.022,"l")
        c.stripe([(s*.159,.393,-1.28),(s*.15,.45,-1.16),(s*.14,.505,-.98),
                  (s*.11,.632,-.66),(s*.102,.661,-.35)],.079,"t")
        c.blade("Air intake shoulder",[(s*.39,.472,-.02,.48,.16),(s*.65,.52,.08,.43,.17),
                                      (s*.87,.506,.185,.28,.114)],"p")
        c.tailfin(s,.55,.60,.80,.60,1.14,"p")
    c.spoiler(.87,.955,1.035,.27,"p")


def zuri_volt(c):
    c.sides(.187,.167)
    c.loft("Bee carapace",[(-1.22,.255,.15,.486),(-1.11,.35,.192,.502),
           (-.92,.39,.207,.523),(-.64,.405,.193,.51),(-.34,.354,.16,.488)],power=.70)
    c.bulb("Honeycomb grille rim",(0,.494,-1.218),(.27,.145,.038),"t")
    for row in (-1,0,1):
        for col in range(-2,3):
            x=(col+.5*(row%2))*.081
            if abs(x)>.184 and row: continue
            z=-1.257+.02*(abs(x)/.2)**2
            pts=[(x+.044*math.cos(i*math.tau/6),.495+row*.065+.044*math.sin(i*math.tau/6),z)
                 for i in range(7)]
            c.tube("Grille hexagon",pts,.0065,"a")
    for s in (-1,1):
        c.tube("Voltage feeler",[(s*.28,.657,-.63),(s*.32,.80,-.64),
                                 (s*.397,.936,-.75)],.021,"t")
        c.bulb("Feeler tip",(s*.398,.946,-.75),(.048,.057,.045),"l")
        for i in range(3):
            c.panel("Battery cooling vane",[(s*.50,.41,-.14+i*.097),(s*.60,.57,-.09+i*.097),
                    (s*.65,.58,.005+i*.097),(s*.61,.41,-.015+i*.097)],.07,"t")
        c.blade("Bee wing",[(s*.35,.58,.46,.49,.092),(s*.58,.70,.56,.44,.083),
                            (s*.70,.74,.75,.23,.05),(s*.69,.72,.86,.05,.023)],"a")


def blitz(c):
    c.sides(.115,.114,power=.65)
    c.loft("Drag rail",[(-1.59,.029,.027,.298),(-1.47,.107,.061,.318),
           (-1.10,.125,.09,.352),(-.80,.139,.115,.397),(-.33,.317,.169,.455)],power=.59)
    c.box("Blower block",(0,.555,-.61),(.31,.253,.33),"m",.025)
    c.box("Blower belt",(0,.56,-.795),(.16,.211,.038),"t")
    for x in (-.109,.109):
        c.loft("Ram scoop",[(-.845,.099,.070,.748),(-.71,.098,.068,.751),
               (-.55,.073,.053,.721),(-.46,.043,.03,.68)],"a",x,.45)
        c.box("Scoop throat",(x,.75,-.849),(.147,.084,.012),"c",.015)
    for s in (-1,1):
        for i in range(3):
            x=s*(.34+i*.028)
            c.tube("Swept header",[(s*.142,.56,-.716+i*.084),(x,.51,-.66+i*.084),
                                   (s*(.492+i*.035),.423,-.22+i*.074)],.033,"m")
        c.tailfin(s,.39,.52,.89,.39,1.15,"p")
        c.box("Parachute pack",(s*.24,.63,1.11),(.25,.18,.145),"t")
    c.spoiler(.68,1.09,1.16,.30,"p")


def terra(c):
    c.sides(.18,.174,power=.36)
    c.loft("Utility hood",[(-1.12,.34,.11,.535),(-1.02,.393,.14,.55),
           (-.68,.385,.15,.563),(-.32,.36,.132,.555)],power=.30)
    c.grille(-1.134,.52,.164,.531)
    for i in range(5):
        c.box("Bonnet louvre",(0,.713,-.83+i*.061),(.30,.018,.026),"c",.005)
    for s in (-1,1):
        for z in (-.66,.66): c.arch(s,z,.83,.44,.745,"t",True)
        c.lamp(s*.305,.635,-1.109,.07)
        c.tube("Expedition cage",[(s*.42,.45,-.38),(s*.46,1.07,-.30),
               (s*.465,1.30,-.13),(s*.465,1.32,.74),(s*.405,.54,.92)],.035,"c")
        c.tube("Frame diagonal",[(s*.402,.51,.61),(s*.462,1.31,.29)],.028,"c")
        c.box("Rock step",(s*.68,.252,0),(.23,.067,.53),"m")
        for z in (.53,.73):
            c.tube("Rear rack rail",[(s*.47,1.337,z),(0,1.344,z)],.024,"m")
    c.box("Rear cargo tray",(0,1.318,.64),(.92,.050,.33),"t",.019)
    c.bulb("Bedroll",(0,1.404,.647),(.30,.088,.089),"a")
    c.box("Rescue case",(0,.746,.846),(.48,.18,.31),"a")
    c.box("Skid bumper",(0,.325,-1.168),(1.13,.133,.16),"c",.036)


def koloss(c):
    c.sides(.29,.205,power=.27)
    c.loft("Armored bow",[(-1.32,.44,.076,.409),(-1.19,.54,.142,.47),
           (-.93,.48,.17,.50),(-.70,.423,.184,.515),(-.31,.385,.175,.517)],power=.28)
    for i in range(3):
        c.box("Stepped glacis",(0,.572+i*.068,-1.174+i*.155),(.80-i*.069,.09,.26),"p",.034)
    for s in (-1,1):
        for z in (-.66,.66):
            c.arch(s,z,.94,.48,.747,"t",True)
            c.panel("Wheel deflector",[(s*.99,.49,z-.30),(s*1.009,.745,z-.37),
                    (s*1.009,.786,z+.32),(s*.99,.53,z+.39)],.065,"p")
        for i in range(3):
            c.box("Side armour tile",(s*.627,.477,-.21+i*.17),(.165,.226,.145),"t")
        c.box("Armored lamp slot",(s*.362,.513,-1.29),(.147,.045,.034),"l")
        for z in (-.66,.66):
            c.box("Capped fender seam",(s*1.025,.693,z),(.020,.042,.57),"t",.006)
            for dz in (-.22,0,.22):
                c.bulb("Armour rivet",(s*1.039,.693,z+dz),(.012,.019,.019),"m")
            c.box("Fender buckle",(s*.79,.789,z-.20),(.13,.027,.065),"a",.009)
        c.box("Amber tow eye",(s*.405,.308,-1.33),(.106,.078,.061),"a")
        c.box("Rear armour buttress",(s*.442,.66,.81),(.31,.268,.53),"p",.049)
    c.box("Impact blade",(0,.329,-1.31),(1.17,.133,.13),"t",.039)


def phantom(c):
    c.sides(.14,.13,power=.50)
    c.loft("Recessed prow",[(-.94,.067,.044,.32),(-.78,.193,.084,.365),
           (-.53,.283,.134,.43),(-.30,.35,.147,.477)],"c",power=.47)
    for s in (-1,1):
        c.loft("Split hull",[(-1.42,.013,.018,.385),(-1.27,.073,.066,.431),
               (-1.025,.101,.113,.47),(-.66,.106,.145,.504),(-.35,.112,.15,.498),
               (.00,.131,.133,.469),(.29,.084,.104,.46)],"p",s*.392,.40)
        c.tube("Plasma rail",[(s*.40,.397,-1.391),(s*.451,.463,-1.24),
               (s*.485,.505,-1.006),(s*.498,.524,-.68),(s*.501,.525,-.40)],.017,"l")
        c.blade("Drift skate",[(s*.45,.38,-.04,.75,.18),(s*.69,.43,.11,.79,.16),
                               (s*.893,.48,.45,.46,.093),(s*.965,.57,.74,.082,.071)],"a")
        c.tailfin(s,.43,.51,1.012,.43,1.21,"p")
        c.tube("Tail tracer",[(s*.449,.607,.52),(s*.486,.774,.79),(s*.515,1.008,1.208)],.013,"l")
    c.blade("Floating bridge",[(-.415,.60,-.56,.17,.069),(0,.627,-.49,.216,.074),
                                (.415,.60,-.56,.17,.069)],"t")


def stella(c):
    c.sides(.187,.158,power=.77)
    c.loft("Streamlined prow",[(-1.37,.04,.126,.445),(-1.24,.176,.174,.478),
           (-1.02,.263,.201,.50),(-.70,.33,.183,.527),(-.33,.361,.157,.515)],power=.58)
    for s in (-1,1):
        c.loft("Deco wing valance",[(-1.265,.028,.05,.495),(-1.13,.106,.11,.555),
               (-.94,.155,.14,.591),(-.68,.161,.138,.585),(-.41,.126,.117,.53),
               (-.18,.051,.077,.46)],"a",s*.409)
        c.lamp(s*.413,.61,-1.138,.075)
        for i in range(3):
            c.blade("Crown fan",[(s*.37,.51,.35+i*.13,.40,.09),
                    (s*(.48+i*.07),.68+i*.05,.61+i*.13,.32,.085),
                    (s*(.56+i*.09),.83+i*.10,.80+i*.16,.092,.043)],"t" if i==1 else "p")
        for i in range(3):
            c.tube("Speed line",[(s*.358,.48+i*.041,-1.18),
                    (s*.478,.489+i*.047,-1.065),(s*.538,.50+i*.055,-.86)],.009,"t")
    c.tube("Hood ornament mast",[(0,.676,-1.11),(0,.799,-1.11)],.015,"m")
    points=[]
    for i in range(10):
        a=math.pi/2+i*math.pi/5
        r=.115 if i%2==0 else .052
        points.append((r*math.cos(a),.843+r*math.sin(a),-1.108))
    # Closed, bevelled five-point crest mounted in the foredeck.
    n=len(points)
    verts=[(x,y,z+dz) for dz in (-.012,.012) for x,y,z in points]
    k.mesh("Five point crest",verts,[tuple(range(n)),tuple(range(n,2*n))]+
           [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],c.mats["a"],c.root)
    c.stripe([(0,.584,-1.343),(0,.663,-1.20),(0,.712,-1.00),(0,.719,-.75),(0,.687,-.38)],.056,"t")


BUILD = {f.__name__:f for f in (comet,gecko_velo,boru_rally,glider,nala_comet,noa_tide,
         iva_aurora,turbo,zuri_volt,blitz,terra,koloss,phantom,stella)}
BUILD.update(console_fleet.BUILD)


def station_markers(c):
    # Project onto the actual finished surface before adding wheels or nested LODs.
    for suffix,origin,direction in [
        ("Number_Nose",(0,2,-.73),(0,-1,0)),
        *[(key+"_"+label,(s*1.4,.386,z),(-s,0,0)) for s,label in [(-1,"L"),(1,"R")]
          for key,z in [("Number",.0),("Sticker_Front",-.13),("Sticker_Rear",.17)]]]:
        p,n=k.ray_hit(origin,direction)
        if p is None:
            raise RuntimeError(c.design+" missing decal surface "+suffix)
        k.oriented_marker("Decal_"+suffix,p+n*.007,n,c.root,.1)
    for name,z,x in [("engine",.70,0),("wing",.99,.02),("booster",.86,.285)]:
        p,_=k.ray_hit((x,2,z),(0,-1,0))
        if p is not None:
            k.empty("Mount_"+name, (0 if name!="booster" else x,p.y,z),c.root)


def make_showroom(c):
    # A separate optional batch contains the transparent tail lenses, stitchwork,
    # machined exhaust collars and heat bands. It stays hidden during races.
    group=k.empty("Polish",parent=c.root)
    glass=k.showcase_material("LampGlass","e9f4fc",.04,.07,alpha=.31)
    heat=[k.material("Titanium_"+color,color,.78,.25) for color in ("bbb29d","847199","697998")]
    for s in (-1,1):
        k.bevel_box("Lens cover",(s*.242,.683,1.082),(.166,.046,.007),glass,group,.003)
        a,b=Vector((s*.19,.43,.94)),Vector((s*.12,.467,1.112))
        for j,mat in enumerate(heat):
            k.tube("Titanium weld",[a.lerp(b,.38+j*.16),a.lerp(b,.50+j*.16)],.0554,mat,group,16)
        for j in range(7):
            y=.63+j*.036
            k.tube("Seat topstitch",[(s*.16,y,.375+(y-.63)*.28),
                   (s*.16,y+.018,.376+(y-.63)*.28)],.003,c.mats["a"],group,5)
    k.apply_modifiers(group)
    k.batch_assembly(group)
    group.children[0].name="ShowroomDetail"
    return group.children[0]


def export(path,root):
    bpy.ops.object.select_all(action="DESELECT")
    for o in k.descendants(root):
        o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
                              export_extras=False,export_animations=False,export_yup=True)


def render(c,output,samples):
    scene=bpy.context.scene
    core=DESIGNS[c.design][0]
    shell_names=set(bpy.data.objects.keys())
    source=k.ROOT/"assets/kart/production/karts"/("aurora_"+core+".glb")
    bpy.ops.import_scene.gltf(filepath=str(source))
    imported=[o for o in bpy.data.objects if o.name not in shell_names]
    old=next(o for o in imported if o.name=="Coachwork")
    for o in reversed(k.descendants(old)):
        bpy.data.objects.remove(o,do_unlink=True)
    # Export frame 1 is the mechanical rest pose.
    scene.frame_set(1)
    camera=k.setup_studio()
    bpy.data.objects["StudioGround"].hide_render=True
    scene.render.film_transparent=True
    scene.cycles.samples=samples
    scene.cycles.use_denoising=False
    scene.cycles.max_bounces=4
    scene.render.threads=2
    scene.render.resolution_x=480
    scene.render.resolution_y=360
    scene.render.image_settings.file_format="WEBP"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.image_settings.quality=91
    camera.data.type="ORTHO"
    camera.data.ortho_scale=3.23
    k.render_view(camera,output,(2.65,1.98,-3.30),(0,.56,-.045))


def build(design,args):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    c=Coachwork(design)
    c.cockpit()
    BUILD[design](c)
    k.apply_modifiers(c.root)
    station_markers(c)
    k.batch_assembly(c.root)
    body=next(o for o in c.root.children if o.type=="MESH")
    body.name="LOD0"
    levels=[]
    for i,ratio in ((1,.43),(2,.17)):
        reduced=body.copy()
        reduced.data=body.data.copy()
        reduced.name="LOD"+str(i)
        bpy.context.collection.objects.link(reduced)
        bpy.context.view_layer.objects.active=reduced
        dec=reduced.modifiers.new("Reduce interior detail","DECIMATE")
        dec.ratio=ratio
        bpy.ops.object.modifier_apply(modifier=dec.name)
        levels.append(reduced)
    make_showroom(c)
    model_dir=k.ROOT/"assets/kart/production/fleet"
    model_dir.mkdir(exist_ok=True)
    export(model_dir/(design+".glb"),c.root)
    for reduced in levels:
        reduced.hide_render=True
    portrait=k.ROOT/"assets/kart/menu/fleet"/(design+".webp")
    render(c,portrait,args.samples)
    if args.flutter:
        shutil.copyfile(portrait,Path(args.flutter)/"assets/lumo_design/karts"/portrait.name)
    print("FLEET COMPLETE",design,flush=True)


if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("--only", choices=DESIGNS, action="append")
    cli.add_argument("--samples",type=int,default=20)
    cli.add_argument("--flutter",type=Path)
    args=cli.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    for design in (args.only or DESIGNS):
        build(design,args)
