"""Build the three additional racers with the kart's shared skin and clip contract.

blender -b -t 2 -P tools/lumo_kart_art/drivers/build_garage_drivers.py -- --species otter --voxel .007 --tris 17000
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_animal_drivers as build
import animal_species as sp
import sdf_kit as K
from animal_body import body, rot_axis


def suit(d, width, colour, accent, build_type):
    d.palette.update({"Suit": colour, "Orange": accent, "Navy": "273746", "Rubber": "303842"})
    body(d, {"torso": [((0, -.05, .86), (width * .78, .14, .15)),
                       ((0, -.04, 1.01), (width * .9, .15, .17)),
                       ((0, -.03, 1.16), (width, .145, .14))],
             "top": build_type, "hand": "small_paw", "foot": "boot", "sleeves": "short", "legs": "long",
             "neck": (.094, 1.43)})

    # Sewn shoulder panels, double piping and the driver's embroidered badge.
    for side in (-1, 1):
        panel = [(side * .12, .099, 1.225), (side * .175, .067, 1.22),
                 (side * .223, .018, 1.205), (side * .254, -.021, 1.171)]
        d.paint(K.Tube(panel, [.024,.038,.042,.03]), "Navy", .003, only={"Suit"})
        seam = [(x, y + .008, z - .025) for x,y,z in panel]
        d.paint(K.Tube(seam, [.005,.007,.007,.005]), "White", .002, only={"Suit","Navy"})
    badge = K.Ellipsoid((-.096, .100, 1.135), (.039,.036,.042))
    d.paint(badge, "Orange", .003, only={"Suit"})
    d.paint(K.Tube([(-.116,.118,1.133),(-.099,.125,1.117),(-.08,.118,1.151)],
                   [.006,.006,.004]), "Navy", .002, only={"Orange"})


def face(d, eye_x, eye_y, eye_z, nose_y, muzzle_width, lid="Fur"):
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * muzzle_width * .65, nose_y - .054, 1.524),
                          (muzzle_width, .078, .064)), k=.021, label="Cream")
    d.add(K.Ellipsoid((0, nose_y - .066, 1.465), (.105, .061, .055)), k=.044, label="Cream")
    d.add(K.Ellipsoid((0, nose_y + .002, 1.565), (.051, .033, .03)), k=.009, label="Nose")
    d.add(K.RoundCone((0, nose_y + .012, 1.558), (0, nose_y + .003, 1.536), .023, .014), k=.012, label="Nose")
    sp.standard_face(d, (eye_x, eye_y, eye_z), (.065, .055, .074), "Iris", lid)
    sp.mouth(d, (0, nose_y -.013, 1.493), .065, .043, .032, 1.486, 12.)
    # Keep the rounded nose leather legible above the paler paired muzzle pads.
    d.paint(K.Ellipsoid((0, nose_y + .02, 1.572), (.056, .031, .032)), "Nose", .003)
    d.brows = {"label": "Brow", "points": lambda s: [(s * (eye_x - .046), eye_z + .091),
                  (s * eye_x, eye_z + .103), (s * (eye_x + .049), eye_z + .089)], "radius": .009}
    d.whiskers = {"x": muzzle_width, "z": 1.534, "length": muzzle_width * 1.5,
                  "rows": [(.009, .2), (-.004, .05), (-.015, -.16)], "color": "E7D6B6"}


def tail(d, pts, radii):
    d.bones["Tail"] = (pts[0], pts[1])
    d.add(K.Tube(pts, radii), k=.045, label="Fur", bones={"Tail": 1.})


def ears(d, x, z, radius):
    for side, s in (("L", -1), ("R", 1)):
        at = (s * x, -.037, z)
        bone = "Ear." + side
        d.bones[bone] = ((s * (x - .045), -.04, z - .05), (s * (x + .045), -.054, z + .035))
        d.add(K.Ellipsoid(at, (radius, .041, radius * .87)), k=.022, label="Fur", bones={bone: 1.})
        d.paint(K.Ellipsoid((at[0], .004, z), (radius * .68, .024, radius * .53)), "InnerEar", .004)


def otter(d):
    d.palette.update({"Fur": "895237", "Cream": "F2D4A4", "Iris": "67341E",
                      "InnerEar": "B38267", "Nose": "412821", "Brow": "56382B"})
    suit(d, .215, "137E83", "FFD575", "overall")
    d.add(K.Ellipsoid((0, -.008, 1.63), (.279, .205, .206)), k=.076)
    d.add(K.Ellipsoid((0, .079, 1.54), (.251, .161, .114)), k=.053)
    d.paint(K.Ellipsoid((0, .143, 1.465), (.22, .15, .088)), "Cream", .015)
    ears(d, .254, 1.738, .062)
    face(d, .139, .143, 1.654, .249, .113)
    tail(d, [(0,-.14,.88),(.012,-.30,.907),(.065,-.49,.95),(.16,-.60,1.025),(.26,-.63,1.08)],
         [.109,.099,.076,.046,.013])


def badger(d):
    d.palette.update({"Fur": "777A7D", "Cream": "F6ECD6", "Iris": "8C6831", "Stripe": "302C31",
                      "InnerEar": "A69D9A", "Nose": "292329", "Brow": "454046"})
    suit(d, .25, "7D5540", "F7BC67", "overall")
    d.add(K.Ellipsoid((0,-.045,1.647),(.269,.218,.225)), k=.07)
    d.add(K.RoundCone((0,.025,1.627),(0,.245,1.561),.204,.077), k=.065, label="Cream")
    d.paint(K.Ellipsoid((0, .074, 1.687), (.265,.236,.226)), "Cream", .011, only={"Fur","Cream"})
    for s in (-1,1):
        mask = [(s*.217,-.122,1.795),(s*.183,-.004,1.8),(s*.143,.105,1.743),
                (s*.126,.17,1.647),(s*.084,.212,1.598),(s*.048,.247,1.574)]
        d.paint(K.Tube(mask,[.065,.073,.072,.077,.053,.022]), "Stripe", .007)
    ears(d, .213, 1.801, .067)
    face(d,.13,.146,1.656,.273,.074,"Stripe")
    tail(d,[(0,-.15,.88),(0,-.27,.92),(.038,-.384,.948),(.094,-.437,.958)], [.092,.084,.054,.014])


def cat(d):
    d.palette.update({"Fur":"C27A4A","Cream":"F9DBBA","Iris":"3F946C","Stripe":"744536",
                      "InnerEar":"D69A92","Nose":"AE6F6D","Brow":"694539"})
    suit(d, .198, "8E4268", "FFE0AA", "jersey")
    d.add(K.Ellipsoid((0,-.019,1.65),(.247,.185,.209)), k=.07)
    for side,s in (("L",-1),("R",1)):
        d.add(K.Ellipsoid((s*.125,.034,1.552),(.142,.13,.105)), k=.046)
        bone="Ear."+side
        pts=[(s*.12,-.02,1.766),(s*.158,-.028,1.849),(s*.197,-.032,1.947),(s*.218,-.035,2.)]
        d.bones[bone]=(pts[0],pts[-1])
        d.add(K.Leaf(pts,[.085,.093,.066,.036,.006],[.052,.05,.038,.025,.009],(0,1,0)), k=.028,bones={bone:1.})
        inner=[(x,y+.039,z+.006) for x,y,z in pts]
        d.paint(K.Leaf(inner,[.046,.063,.036,.015,.002],[.023,.026,.024,.018,.004],(0,1,0)),"InnerEar",.004)
        for dx in (.047,.111):
            d.paint(K.Tube([(s*dx,-.101,1.846),(s*dx,-.011,1.861),(s*(dx-.015),.095,1.819),
                             (s*(dx-.018),.135,1.766)],[.023,.024,.019,.007]),"Stripe",.004)
        for z in (1.562,1.602):
            d.paint(K.Tube([(s*.24,-.047,z+.023),(s*.24,.062,z),(s*.204,.116,z-.02)],[.023,.015,.006]),"Stripe",.004)
    face(d,.119,.141,1.663,.204,.078)
    tail(d,[(0,-.16,.88),(.031,-.29,.91),(.13,-.42,1.02),(.216,-.42,1.155),
            (.26,-.405,1.24),(.253,-.359,1.286),(.209,-.327,1.286)],[.047,.045,.042,.036,.034,.031,.022])


if __name__ == "__main__":
    build.SP.SPECIES.update(otter=otter,badger=badger,cat=cat)
    import bpy
    from finish_race_drivers import portrait
    species = sys.argv[sys.argv.index("--species") + 1]
    if "--portrait-only" in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(build.ROOT / "art/lumo_kart/blender/drivers" / (species + ".blend")))
    else:
        build.main()
    if "--no-export" not in sys.argv:
        rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
        portrait(species, rig, build.ROOT / "assets/kart/menu/drivers" / (species + ".webp"))
