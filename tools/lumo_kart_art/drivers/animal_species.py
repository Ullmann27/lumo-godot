"""Species sculpts for the LUMO rivals: lion, owl, rabbit, squirrel, turtle, frog.

Each function adds the head, face, ears, tail and species body features to a
Design that already carries the shared racing suit. Heads follow Lumo's
measured in-kart proportions (about 0.7 m wide, eyes near 1.6 m, chin at
about 1.36 m in the authored seat space), so every rival reads at Lumo's size.
"""
from __future__ import annotations

import math

import numpy as np

import sdf_kit as K
from animal_body import Design, band, body, vest_paint, v3, rot_axis

F = np.float32
TAU = math.tau

PALETTE_COMMON = {
    'Suit': '1F4E9A', 'Navy': '16274A', 'White': 'EEF1F4', 'Orange': 'EE7A2B',
    'Glove': '20242E', 'Rubber': '1A1F26', 'Metal': 'A9B5BF', 'GoggleGlass': '2A78C8',
    'EyeWhite': 'FBF7F0', 'Pupil': '0D0B0C', 'Mouth': '5E1E2A', 'Tongue': 'E07A88', 'Lash': '2E1C14',
    'Claw': '3A2A22', 'Nail': 'E8DCC0',
    'Teeth': 'FBF6EC', 'Catch': 'FFFFFF',
}


def fbm_bump(shape, amount, scale, seed=0):
    """Organic fur/feather relief: displaces a shape by fractal noise."""
    def fn(p):
        return shape(p) - amount * (K.fbm(p * scale, 3, seed) - .5) * 2.0
    return K.Fn(fn, np.asarray(shape.lo) - amount, np.asarray(shape.hi) + amount)


def mouth_cavity(center, rx, ry, rz, top, curve):
    c = v3(center)
    ell = K.Ellipsoid(c, (rx, ry, rz))

    def fn(p):
        x = p[..., 0]
        upper = p[..., 2] - (top + curve * x * x)
        return np.maximum(ell(p), upper)
    return K.Fn(fn, c - v3((rx, ry, rz)) - .02, c + v3((rx, ry, rz)) + .02)


def standard_face(d: Design, eye_center, eye_radius, iris, lid_label, socket=1.03, gaze=(0.0, 1.0, 0.0)):
    ex, ey, ez = eye_center
    d.eyes = {
        'center': {'L': (-ex, ey, ez), 'R': (ex, ey, ez)},
        'radius': eye_radius, 'iris': iris, 'lid': lid_label,
        'gaze': gaze,
    }
    r = max(eye_radius)
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * ex, ey, ez), tuple(x * socket for x in eye_radius)), op='subtract', k=.022)
        d.detail.append(K.Sphere((s * ex, ey, ez), r * 1.9))


def mouth(d: Design, center, rx, ry, rz, top, curve, teeth='upper'):
    cav = mouth_cavity(center, rx, ry, rz, top, curve)
    d.add(cav, op='subtract', k=.012)
    d.paint(K.Fn(lambda p: cav(p) + .0035, np.asarray(cav.lo), np.asarray(cav.hi)), 'Mouth', .002)
    d.mouth = {'center': center, 'rx': rx, 'ry': ry, 'rz': rz, 'top': top, 'curve': curve, 'teeth': teeth}
    d.detail.append(K.Ellipsoid(center, (rx * 2.2, ry * 2, rz * 3)))


def smile(d: Design, cx, cz, half_width, lift=.018, depth=.006, y_of=None):
    """Upturned smile creases at the mouth corners (Lumo's friendly rest face)."""
    for s in (-1, 1):
        a = (s * half_width * .78, 0, cz + .002)
        b = (s * (half_width + .022), 0, cz + lift)
        ya = y_of(a[0], a[2]) if y_of else .2
        yb = y_of(b[0], b[2]) if y_of else .19
        d.add(K.RoundCone((a[0], ya, a[2]), (b[0], yb, b[2]), depth, depth * .55), op='subtract', k=.006)


def tuft(base, direction, length, r0, bend=(0, 0, 0)):
    """A soft hair tuft: thick root, rounded (not pointed) tip, slightly bowed."""
    base = v3(base)
    dvec = v3(direction) / np.linalg.norm(direction)
    bend = v3(bend)
    pts = [base, base + dvec * length * .5 + bend * .5, base + dvec * length + bend]
    return K.Tube(pts, [r0, r0 * .82, r0 * .52])


def bulk(center, radii, seed, amount=.012, scale=14.0, rot=None):
    return fbm_bump(K.Ellipsoid(center, radii, rot), amount, scale, seed)


# ------------------------------------------------------------------ lion
def lion(d: Design):
    """Broad chest and shoulders, thick arms, big paws, soft voluminous mane
    (tufts, no spikes) that flows over the shoulders, tasselled tail."""
    d.palette.update({'Fur': 'F0A640', 'Cream': 'FCE9C2', 'Mane': 'B9541E', 'ManeDark': '8C3A14', 'ManeLight': 'D9773A',
                      'Nose': '3E1E14', 'InnerEar': 'E39A72', 'Iris': '8A4A14', 'Brow': '8C3A14'})
    d.joints = {'shoulder': (.29, -.02, 1.245), 'elbow': (.36, .15, 1.03), 'hip': (.155, -.04, .83), 'knee': (.18, .18, .92)}
    body(d, {'torso': [((0, -.055, .86), (.22, .165, .12)), ((0, -.035, 1.0), (.235, .18, .17)), ((0, -.02, 1.15), (.265, .175, .15)),
                       ((-.095, .085, 1.15), (.1, .075, .085)), ((.095, .085, 1.15), (.1, .075, .085))],
             'skin': 'Fur', 'top': 'overall', 'arm': (.098, .088, .088, .074), 'leg': (.112, .094, .092, .078),
             'hand': 'paw', 'foot': 'big_boot', 'neck': (.1, 1.42), 'yoke': .1, 'wrist': .085})
    head = K.Ellipsoid((0, -.02, 1.675), (.255, .235, .245))
    d.add(head, k=.06, label='Fur')
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * .13, .07, 1.535), (.155, .14, .12)), k=.08, label='Fur')
        d.add(K.Ellipsoid((s * .115, .16, 1.758), (.09, .05, .03)), k=.04, label='Fur')
    d.add(K.Ellipsoid((0, .15, 1.53), (.13, .11, .09)), k=.05, label='Cream')
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * .06, .205, 1.522), (.074, .066, .058)), k=.03, label='Cream')
    d.add(K.Ellipsoid((0, .118, 1.445), (.09, .085, .055)), k=.05, label='Cream')
    d.add(K.RoundCone((0, .16, 1.72), (0, .232, 1.59), .05, .04), k=.045, label='Fur')
    d.add(K.Ellipsoid((0, .262, 1.578), (.058, .034, .034)), k=.012, label='Nose')
    d.add(K.RoundCone((0, .262, 1.56), (0, .256, 1.535), .02, .012), k=.012, label='Nose')
    standard_face(d, (.118, .16, 1.655), (.08, .068, .088), 'Iris', 'Fur')
    mouth(d, (0, .232, 1.492), .066, .046, .04, 1.482, 12.0)
    smile(d, 0, 1.49, .066, y_of=lambda x, z: .215 - 2.0 * x * x)
    # Mane: one soft mass around the face, then three rings of rounded tufts
    # that fall back and down over the shoulders (a cape of hair, no spikes).
    d.add(bulk((0, -.10, 1.62), (.36, .22, .37), 3, .012, 8.0), k=.06, label='Mane')
    d.add(bulk((0, -.13, 1.36), (.37, .22, .2), 4, .012, 9.0), k=.08, label='Mane', bones={'Neck': .5, 'Head': .2, 'Chest': .3})
    d.add(bulk((0, .07, 1.30), (.2, .1, .11), 5, .01, 12.0), k=.07, label='ManeLight', bones={'Neck': .4, 'Chest': .6})
    count = 18
    for layer, (radius, back, length, label, r0) in enumerate([(.30, -.04, .10, 'Mane', .075), (.33, -.12, .13, 'ManeDark', .085), (.31, -.2, .12, 'Mane', .08)]):
        for k in range(count):
            a = TAU * (k + .5 * layer) / count
            ca, sa = math.cos(a), math.sin(a)
            if sa < -.55 and layer == 0:
                continue
            droop = -.07 if sa < .3 else 0.0
            base = (radius * ca, back, 1.63 + radius * sa * .95)
            dirv = (ca, -.55, sa + droop * 3 - .25)
            reach = length * (1.0 + .15 * math.sin(2.7 * k + layer))
            bones = 'Head' if sa > -.2 else {'Head': .55, 'Neck': .45}
            d.add(tuft(base, dirv, reach, r0, (-sa * .03, -.02, -.03)), k=.045, label=label, bones=bones)
    for side, s in (('L', -1), ('R', 1)):
        ear = K.Ellipsoid((s * .225, -.01, 1.875), (.085, .045, .08), rot_axis((0, 1, 0), s * .4))
        d.add(ear, k=.03, label='Fur', bones={'Ear.' + side: 1.0})
        d.paint(K.Ellipsoid((s * .228, .03, 1.872), (.052, .022, .05)), 'InnerEar', .006)
    d.bones.update({'Ear.L': ((-.2, -.01, 1.83), (-.25, -.01, 1.93)), 'Ear.R': ((.2, -.01, 1.83), (.25, -.01, 1.93)),
                    'Tail': ((0, -.20, .92), (0, -.36, 1.06))})
    tail = [(0, -.17, .93), (0, -.30, 1.0), (.06, -.42, 1.1), (.18, -.5, 1.16), (.3, -.52, 1.12)]
    d.add(K.Tube(tail, [.032, .028, .025, .022, .02]), k=.02, label='Fur', bones={'Tail': 1.0})
    d.add(bulk((.33, -.53, 1.11), (.07, .06, .085), 7, .012, 26), k=.025, label='ManeDark', bones={'Tail': 1.0})
    d.brows = {'label': 'Brow', 'points': lambda s: [(s * .06, 1.752), (s * .11, 1.772), (s * .17, 1.762)], 'radius': .013}
    d.whisker_dots = True
    d.goggle = {'z': 1.835, 'tilt': .15, 'spread': .11, 'no_strap': True, 'strap_stub': .12}
    d.head_scale = .88


def ring_paint(center, radii, band, rot=None):
    """Paint a band along the rim of an ellipsoid (owl facial disc edge)."""
    e = K.Ellipsoid(center, radii, rot)
    c = v3(center)
    r = max(radii)
    return K.Fn(lambda p: np.abs(e(p)) - band, c - r - .05, c + r + .05)


# ------------------------------------------------------------------ owl
def owl(d: Design):
    """Round feathered egg of a body without visible neck, wings instead of arms
    (primaries round the wheel), short feathered legs with talons, open vest."""
    d.palette.update({'Fur': '9C7A58', 'Feather': '9C7A58', 'FeatherDark': '664832', 'FeatherLight': 'EADBC0',
                      'Disc': 'F8EEDC', 'DiscRim': '3E2A1C', 'Beak': 'F0A53A', 'Iris': 'F2A51C', 'Brow': '4A3222', 'Cream': 'F4E7D0',
                      'Bar': 'B79572', 'Talon': 'D9B45A'})
    d.joints = {'shoulder': (.245, -.035, 1.19), 'elbow': (.335, .1, 1.02), 'hip': (.15, -.03, .85), 'knee': (.18, .17, .9)}
    body(d, {'torso': [((0, -.06, .88), (.255, .2, .14)), ((0, -.04, 1.06), (.3, .25, .3)), ((0, -.04, 1.26), (.27, .22, .16))],
             'skin': 'Feather', 'top': 'vest', 'sleeves': 'none', 'legs': 'none', 'arm': (.05, .046, .046, .04),
             'leg': (.092, .085, .075, .062), 'hand': 'wing', 'foot': 'talon', 'neck': None, 'yoke': 0, 'shoulder_ball': False,
             'hem_z': .93, 'hem_r': (.3, .25), 'torso_k': .1})
    d.plan.update({'zip': None, 'stripes': False})
    # feathered breast: light, with soft chevron bars; vest open at the front
    breast = K.Ellipsoid((0, .12, 1.06), (.2, .16, .28))
    d.paint(breast, 'FeatherLight', .03, only={'Feather'})

    def bars(p):
        z = p[..., 2] - .22 * np.abs(p[..., 0])
        stripe = np.abs((z * 24.0) % 1.0 - .5) - .38
        return np.maximum(stripe * .05, breast(p) + .03)
    d.paint(K.Fn(bars, breast.lo, breast.hi), 'Bar', .004, only={'FeatherLight'})
    vest_paint(d, 'Feather', .92, 1.27, open_front=.12)
    # the head sits straight on the round body
    d.add(K.Ellipsoid((0, -.03, 1.4), (.26, .21, .12)), k=.09, label='Feather', bones={'Neck': .5, 'Head': .3, 'Chest': .2})
    head = fbm_bump(K.Ellipsoid((0, -.03, 1.66), (.295, .24, .245)), .006, 22.0, 11)
    d.add(head, k=.07, label='Feather')
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * .15, .02, 1.53), (.16, .16, .14)), k=.09, label='Feather')
    # Heart-shaped facial disc: two shallow dishes, cream, with a dark raised rim.
    for s in (-1, 1):
        dish = K.Ellipsoid((s * .112, .19, 1.66), (.14, .07, .155))
        d.add(dish, k=.035, label='Disc')
        d.paint(K.Ellipsoid((s * .112, .25, 1.66), (.145, .2, .16)), 'Disc', .004)
        d.add(K.Fn(lambda p, e=K.Ellipsoid((s * .112, .17, 1.66), (.158, .1, .172)): np.maximum(np.abs(e(p)) - .01, np.abs(p[..., 1] - .205) - .022),
                   (s * .112 - .2, .05, 1.45), (s * .112 + .2, .3, 1.85)), k=.01, label='DiscRim')
    standard_face(d, (.112, .19, 1.665), (.097, .074, .102), 'Iris', 'Feather', socket=1.025)
    d.eyes['iris_angle'] = .34
    d.eyes['pupil_angle'] = .2
    d.eyes['lid_cover'] = 1.05
    d.add(K.RoundCone((0, .24, 1.66), (0, .335, 1.575), .056, .024), k=.012, label='Beak')
    d.add(K.RoundCone((0, .335, 1.575), (0, .318, 1.525), .024, .008), k=.01, label='Beak')
    d.add(K.Ellipsoid((0, .27, 1.54), (.034, .03, .018)), k=.008, label='Beak', bones={'Jaw': 1.0})
    d.mouth = {}
    d.bones['Jaw'] = ((0, .2, 1.58), (0, .29, 1.535))
    for side, s in (('L', -1), ('R', 1)):
        for k, (dx, dz, r0, label) in enumerate([(0, 0, .05, 'Feather'), (.035, -.03, .042, 'FeatherDark'), (-.03, .01, .04, 'FeatherDark')]):
            base = (s * (.17 + dx), -.03, 1.84 + dz)
            tip = (s * (.27 + dx * 1.5), -.07, 2.04 + dz * 1.3)
            d.add(K.Leaf([base, (s * (.22 + dx), -.05, 1.95 + dz), tip], [r0, r0 * .75, .004], [.022, .018, .004], (0, 1, 0)), k=.025, label=label, bones={'Ear.' + side: 1.0})
    d.bones.update({'Ear.L': ((-.16, -.03, 1.83), (-.26, -.06, 2.0)), 'Ear.R': ((.16, -.03, 1.83), (.26, -.06, 2.0)),
                    'Tail': ((0, -.20, .92), (0, -.30, .86))})
    d.brows = {'label': 'Brow', 'points': lambda s: [(s * .045, 1.79), (s * .1, 1.808), (s * .165, 1.802)], 'radius': .011, 'lift': .0}
    for k in range(5):
        d.add(K.Leaf([((k - 2) * .045, -.2, .93), ((k - 2) * .06, -.30, .90), ((k - 2) * .07, -.38, .86)], [.035, .04, .01], [.012, .01, .004], (0, 0, 1)), k=.02, label='FeatherDark', bones={'Tail': 1.0})
    d.goggle = {'z': 1.845, 'tilt': .1, 'spread': .11}
    d.head_scale = .88


# ------------------------------------------------------------------ rabbit
def rabbit(d: Design):
    """Slim hare: narrow chest, long thin limbs, long hind legs folded high,
    long flat feet, cotton tail; light muzzle and cheeks, pink inner ears."""
    d.palette.update({'Fur': 'B08060', 'Cream': 'FFF6EA', 'InnerEar': 'F59AB0', 'Nose': 'E57A93', 'Iris': '8A5228', 'Brow': '6E4529'})
    d.joints = {'shoulder': (.215, -.025, 1.245), 'elbow': (.285, .13, 1.04), 'hip': (.13, -.04, .835), 'knee': (.155, .26, 1.0)}
    body(d, {'torso': [((0, -.05, .86), (.17, .14, .11)), ((0, -.05, 1.0), (.165, .135, .16)), ((0, -.045, 1.15), (.18, .128, .13))],
             'skin': 'Fur', 'top': 'overall', 'legs': 'short', 'arm': (.062, .052, .052, .044), 'leg': (.088, .066, .056, .046),
             'hand': 'slim_glove', 'foot': 'long', 'neck': (.07, 1.42), 'yoke': .07})
    d.add(K.Ellipsoid((0, -.02, 1.665), (.235, .22, .24)), k=.06, label='Fur')
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * .12, .06, 1.54), (.145, .135, .115)), k=.08, label='Fur')
        d.add(K.Ellipsoid((s * .07, .175, 1.52), (.095, .082, .072)), k=.035, label='Cream')
    d.add(K.Ellipsoid((0, .14, 1.53), (.115, .1, .085)), k=.05, label='Cream')
    d.add(K.Ellipsoid((0, .11, 1.45), (.085, .08, .05)), k=.05, label='Cream')
    d.paint(K.Ellipsoid((0, .2, 1.5), (.2, .15, .12)), 'Cream', .014)
    d.add(K.Ellipsoid((0, .248, 1.574), (.04, .026, .028)), k=.012, label='Nose')
    standard_face(d, (.112, .158, 1.65), (.076, .066, .086), 'Iris', 'Fur')
    mouth(d, (0, .225, 1.5), .062, .042, .038, 1.49, 13.0, teeth='buck')
    smile(d, 0, 1.502, .062, y_of=lambda x, z: .214 - 2.2 * x * x)
    for side, s in (('L', -1), ('R', 1)):
        ctrl = [(s * .085, -.05, 1.82), (s * .11, -.07, 1.98), (s * .135, -.11, 2.16), (s * .15, -.16, 2.32)]
        d.add(K.Leaf(ctrl, [.05, .08, .078, .05, .008], [.036, .034, .03, .024, .008], (0, 1, -.35)), k=.035, label='Fur', bones={'Ear.' + side: 1.0})
        inner = [(s * .09, -.03, 1.87), (s * .113, -.045, 1.99), (s * .137, -.085, 2.16), (s * .15, -.13, 2.29)]
        d.paint(K.Leaf([(x, y + .03, z) for x, y, z in inner], [.025, .052, .05, .032, .004], [.04, .04, .036, .03, .014], (0, 1, -.35)), 'InnerEar', .005)
    d.bones.update({'Ear.L': ((-.085, -.05, 1.82), (-.15, -.16, 2.3)), 'Ear.R': ((.085, -.05, 1.82), (.15, -.16, 2.3)),
                    'Tail': ((0, -.20, .92), (0, -.30, 1.0))})
    d.add(bulk((0, -.25, .98), (.075, .065, .07), 3, .012, 26), k=.03, label='Cream', bones={'Tail': 1.0})
    d.brows = {'label': 'Brow', 'points': lambda s: [(s * .06, 1.745), (s * .105, 1.762), (s * .15, 1.752)], 'radius': .011}
    d.whiskers = {'x': .07, 'z': 1.525, 'length': .14, 'rows': [(.012, .25), (-.004, .02), (-.02, -.22)], 'color': 'F2ECE4'}
    d.goggle = {'z': 1.81, 'tilt': .12, 'spread': .1}
    d.head_scale = .9


# ------------------------------------------------------------------ squirrel
def squirrel(d: Design):
    """Small and wiry: narrow body, thin limbs, small clawed paws, jersey and
    shorts; a huge bushy tail built from soft rounded clumps."""
    d.palette.update({'Fur': 'C8703F', 'Cream': 'FAE5C8', 'InnerEar': 'EBA27C', 'Nose': '3A2018', 'Iris': '5B3218',
                      'Tail': 'BF6A3C', 'TailLight': 'E8AA7A', 'TailTip': 'F4DABA', 'Brow': '8A3A14'})
    d.joints = {'shoulder': (.2, -.025, 1.2), 'elbow': (.265, .12, 1.03), 'hip': (.12, -.04, .845), 'knee': (.15, .2, .93)}
    body(d, {'torso': [((0, -.05, .87), (.158, .13, .105)), ((0, -.05, .99), (.152, .128, .14)), ((0, -.045, 1.11), (.168, .122, .12))],
             'skin': 'Fur', 'top': 'jersey', 'sleeves': 'short', 'legs': 'short', 'arm': (.056, .046, .04, .034),
             'leg': (.078, .058, .046, .04), 'hand': 'small_paw', 'foot': 'small', 'neck': (.065, 1.41), 'yoke': .065,
             'hem_z': .9, 'wrist': .06})
    d.add(K.Ellipsoid((0, -.02, 1.67), (.24, .22, .235)), k=.06, label='Fur')
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * .13, .06, 1.535), (.15, .135, .115)), k=.08, label='Fur')
        d.add(K.Ellipsoid((s * .068, .19, 1.52), (.09, .075, .066)), k=.035, label='Cream')
    d.add(K.RoundCone((0, .08, 1.56), (0, .2, 1.53), .1, .07), k=.05, label='Cream')
    d.add(K.Ellipsoid((0, .11, 1.45), (.085, .08, .05)), k=.05, label='Cream')
    d.paint(K.Ellipsoid((0, .2, 1.49), (.16, .13, .1)), 'Cream', .01)
    d.add(K.Ellipsoid((0, .262, 1.565), (.032, .02, .022)), k=.01, label='Nose')
    standard_face(d, (.112, .158, 1.655), (.076, .066, .086), 'Iris', 'Fur')
    mouth(d, (0, .232, 1.5), .058, .042, .036, 1.491, 14.0, teeth='buck')
    smile(d, 0, 1.502, .058, y_of=lambda x, z: .222 - 2.0 * x * x)
    for side, s in (('L', -1), ('R', 1)):
        d.add(K.Leaf([(s * .15, -.04, 1.83), (s * .19, -.05, 1.94), (s * .215, -.06, 2.04)], [.06, .05, .008], [.028, .022, .006], (0, 1, 0)), k=.03, label='Fur', bones={'Ear.' + side: 1.0})
        d.add(fbm_bump(K.RoundCone((s * .205, -.06, 2.0), (s * .235, -.07, 2.11), .022, .006), .006, 60, 5), k=.012, label='Brow', bones={'Ear.' + side: 1.0})
        d.paint(K.Leaf([(s * .15, -.015, 1.85), (s * .185, -.025, 1.94), (s * .205, -.035, 2.0)], [.035, .03, .006], [.03, .025, .01], (0, 1, 0)), 'InnerEar', .005)
    d.bones.update({'Ear.L': ((-.15, -.04, 1.83), (-.21, -.06, 2.04)), 'Ear.R': ((.15, -.04, 1.83), (.21, -.06, 2.04)),
                    'Tail': ((0, -.20, .95), (.06, -.42, 1.25))})
    # Bushy tail: a soft core along an S-curve with rounded fur clumps
    # around it (cloud-like outline, no flame spikes), lighter rim and tip.
    path = [(0, -.2, .95), (.03, -.36, 1.0), (.08, -.5, 1.16), (.14, -.56, 1.4), (.2, -.53, 1.66), (.25, -.43, 1.86), (.27, -.3, 1.96), (.26, -.2, 1.93)]
    radii = [.045, .08, .13, .16, .17, .155, .115, .06]
    d.add(K.Tube(path, radii), k=.06, label='Tail', bones={'Tail': 1.0}, tau=.02)
    pts = K.catmull(path, 6)
    rads = np.interp(np.linspace(0, 1, len(pts)), np.linspace(0, 1, len(radii)), radii)
    rng = np.random.default_rng(4)
    for i in range(3, len(pts) - 1, 2):
        tan = pts[min(i + 1, len(pts) - 1)] - pts[i - 1]
        tan /= np.linalg.norm(tan)
        ref = np.array([1.0, 0, 0])
        u = np.cross(tan, ref); u /= np.linalg.norm(u)
        w = np.cross(tan, u)
        for k in range(5):
            ang = TAU * (k + .5 * (i % 4)) / 5 + rng.uniform(-.3, .3)
            off = (u * math.cos(ang) + w * math.sin(ang)) * rads[i] * .86
            r = rads[i] * rng.uniform(.5, .64)
            clump = bulk(pts[i] + off, (r, r, r * 1.3), int(rng.integers(0, 99)), .01, 20.0)
            d.add(clump, k=.035, label='TailLight' if (k + i) % 3 == 0 else 'Tail', bones={'Tail': 1.0}, tau=.02)
    d.paint(K.Tube([(x + .06, y - .03, z) for x, y, z in path[2:7]], [.1, .12, .12, .1, .07]), 'TailLight', .03, only={'Tail'})
    d.paint(K.Sphere(path[-2], .1), 'TailTip', .03, only={'Tail', 'TailLight'})
    d.brows = {'label': 'Brow', 'points': lambda s: [(s * .06, 1.75), (s * .105, 1.768), (s * .155, 1.755)], 'radius': .012}
    d.whiskers = {'x': .07, 'z': 1.525, 'length': .12, 'rows': [(.01, .2), (-.01, -.05)], 'color': '3A2018'}
    d.goggle = {'z': 1.82, 'tilt': .12, 'spread': .105, 'no_strap': True, 'strap_stub': .1}
    d.head_scale = .84


# ------------------------------------------------------------------ turtle
def turtle(d: Design):
    """Shell is the torso: domed carapace with scutes and a wide marginal rim,
    yellow plastron in front, short thick neck, stumpy scaly limbs; racing
    harness instead of an overall. The carapace stays in front of the seat."""
    d.palette.update({'Fur': '8DC062', 'Skin': '8DC062', 'Belly': 'EDE7A4', 'Cream': 'EDE7A4', 'Shell': 'A8743E', 'ShellDark': '6F4826',
                      'ShellRim': 'E2C487', 'Plastron': 'E9D78A', 'Iris': '5A3A1E', 'Brow': '5E8A3E', 'Spot': '6FA34C', 'Scale': '79AC52'})
    d.joints = {'shoulder': (.27, -.01, 1.17), 'elbow': (.345, .15, 1.02), 'hip': (.155, -.03, .845), 'knee': (.2, .18, .93)}
    body(d, {'torso': [((0, -.06, .87), (.22, .17, .12)), ((0, -.05, 1.0), (.245, .18, .17)), ((0, -.05, 1.12), (.25, .17, .13))],
             'skin': 'Skin', 'top': 'harness', 'arm': (.085, .08, .08, .075), 'leg': (.112, .102, .1, .095),
             'hand': 'claw', 'foot': 'stump', 'neck': (.105, 1.42), 'yoke': .085, 'wrist': .09})
    # plastron: flat front plate with grooves
    plastron = K.Ellipsoid((0, .07, 1.02), (.2, .1, .22))
    d.add(plastron, k=.04, label='Plastron', bones={'Spine': .5, 'Chest': .5})
    d.paint(K.Fn(lambda p: np.maximum(np.minimum(np.abs(p[..., 2] - 1.08), np.minimum(np.abs(p[..., 2] - .95), np.abs(p[..., 0]))) - .005, -(p[..., 1] - .1)),
                 (-.25, .0, .8), (.25, .25, 1.25)), 'ShellDark', .003, only={'Plastron'})
    # carapace: shallow at the back (seat), broad and high, with a wide rim
    shell = K.Ellipsoid((0, -.1, 1.1), (.4, .24, .32))
    shell_cut = K.Fn(lambda p, e=shell: np.maximum(e(p), p[..., 1] - .02), (-.4, -.4, .7), (.4, .1, 1.45))
    d.add(shell_cut, k=.03, label='Shell', bones=lambda p: {'Chest': np.clip((p[..., 2] - .95) / .25, 0, 1), 'Spine': 1 - np.clip((p[..., 2] - .95) / .25, 0, 1)})
    def rim_tube(p):
        # round rim: distance to the shell outline ellipse in the x-z plane
        ring = (np.sqrt((p[..., 0] / .42) ** 2 + ((p[..., 2] - 1.1) / .33) ** 2) - 1.0) * .37
        return np.sqrt(ring * ring + ((p[..., 1] + .08) / 1.25) ** 2) - .038
    rim_fn = K.Fn(rim_tube, (-.5, -.16, .72), (.5, .0, 1.48))
    d.add(rim_fn, k=.03, label='ShellRim', bones=lambda p: {'Chest': np.clip((p[..., 2] - .95) / .25, 0, 1), 'Spine': 1 - np.clip((p[..., 2] - .95) / .25, 0, 1)})
    for k in range(9):
        a = TAU * k / 9
        d.paint(K.Fn(lambda p, a=a: np.abs((np.arctan2(p[..., 0], p[..., 2] - 1.1) - a + math.pi) % TAU - math.pi) - .012, (-.45, -.2, .75), (.45, .05, 1.45)), 'ShellDark', .004, only={'ShellRim'})
    for k in range(7):
        if k == 0:
            c = (0, -.31, 1.12)
        else:
            a = TAU * (k - 1) / 6
            c = (.18 * math.sin(a), -.28 + .03 * abs(math.cos(a)), 1.12 + .17 * math.cos(a))
        d.add(K.Ellipsoid(c, (.085, .04, .085)), k=.02, label='Shell', bones={'Chest': 1.0})
        d.paint(ring_paint(c, (.1, .055, .1), .008), 'ShellDark', .004, only={'Shell'})
    # racing harness straps over the shoulders and round the waist
    for s in (-1, 1):
        d.add(K.Tube([(s * .15, -.06, 1.29), (s * .14, .1, 1.22), (s * .11, .17, 1.08), (s * .08, .175, .93)], .018), k=.006, label='Suit', bones=lambda p: {'Chest': np.clip((p[..., 2] - 1.0) / .2, 0, 1), 'Spine': 1 - np.clip((p[..., 2] - 1.0) / .2, 0, 1)})
    d.add(K.Fn(lambda p, e=K.Ellipsoid((0, -.02, .92), (.25, .2, .3)): np.maximum(np.abs(e(p)) - .01, np.abs(p[..., 2] - .92) - .02), (-.3, -.3, .85), (.3, .3, 1.0)), k=.006, label='Suit', bones={'Pelvis': .5, 'Spine': .5})
    d.add(K.Ellipsoid((0, .19, .93), (.05, .02, .04)), k=.004, label='Metal', bones={'Pelvis': .5, 'Spine': .5})
    # neck: short and thick, with skin folds, scarf in team colours
    for z in (1.33, 1.37):
        d.add(K.Torus((0, -.02, z), .105, .008), k=.012, label='Scale', bones=lambda p: {'Neck': 1.0})
    d.add(band(K.RoundCone((0, -.035, 1.22), (0, -.02, 1.32), .14, .13), (0, -.03, 1.27), (0, .1, 1), .03, .012), k=.01, label='Suit', bones=lambda p: {'Chest': .5, 'Neck': .5})
    d.paint(K.Fn(lambda p: np.abs(p[..., 2] - 1.27) - .006, (-.3, -.3, 1.2), (.3, .3, 1.35)), 'Orange', .002, only={'Suit'})
    for c, r in [((.3, .12, 1.0), .02), ((-.31, .1, 1.05), .025), ((.38, .1, .98), .018), ((-.2, .23, .82), .02), ((.21, .25, .84), .022)]:
        d.paint(K.Sphere(c, r * 1.5), 'Spot', .008, only={'Skin'})
    d.add(K.Ellipsoid((0, -.01, 1.66), (.225, .23, .23)), k=.06, label='Skin')
    d.add(K.Ellipsoid((0, .1, 1.53), (.19, .16, .12)), k=.08, label='Skin')
    d.add(K.Ellipsoid((0, .2, 1.55), (.12, .085, .075)), k=.06, label='Skin')
    d.add(K.Ellipsoid((0, .12, 1.47), (.15, .13, .07)), k=.06, label='Belly')
    d.paint(K.Fn(lambda p: np.maximum(p[..., 2] - (1.5 + .25 * p[..., 0] ** 2), 1.36 - p[..., 2]), (-.3, 0, 1.3), (.3, .4, 1.6)), 'Belly', .006, only={'Skin'})
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * .04, .262, 1.565), (.009, .006, .006)), op='subtract', k=.004)
    standard_face(d, (.108, .16, 1.665), (.078, .068, .088), 'Iris', 'Skin')
    mouth(d, (0, .24, 1.505), .09, .044, .034, 1.4965, 5.5)
    smile(d, 0, 1.508, .09, y_of=lambda x, z: .228 - 1.8 * x * x)
    d.bones.update({'Ear.L': ((-.15, -.01, 1.8), (-.18, -.01, 1.9)), 'Ear.R': ((.15, -.01, 1.8), (.18, -.01, 1.9)),
                    'Tail': ((0, -.20, .92), (0, -.30, .9))})
    d.add(K.RoundCone((0, -.2, .9), (0, -.27, .86), .035, .015), k=.02, label='Skin', bones={'Tail': 1.0})
    helmet = K.Fn(lambda p, e=K.Ellipsoid((0, -.03, 1.70), (.245, .25, .235)): np.maximum(e(p), (1.73 + .25 * p[..., 1]) - p[..., 2]), (-.3, -.3, 1.6), (.3, .3, 2.0))
    d.add(helmet, k=.01, label='Suit')
    d.paint(K.Fn(lambda p: np.abs(p[..., 0]) - .03, (-.05, -.4, 1.75), (.05, .4, 2.0)), 'Orange', .004, only={'Suit'})
    d.paint(K.Fn(lambda p: np.abs(np.abs(p[..., 0]) - .06) - .012, (-.1, -.4, 1.75), (.1, .4, 2.0)), 'White', .004, only={'Suit'})
    d.brows = {'label': 'Brow', 'points': lambda s: [(s * .06, 1.745), (s * .1, 1.758), (s * .15, 1.748)], 'radius': .011}
    d.goggle = {'z': 1.86, 'tilt': .15, 'spread': .105, 'no_strap': True}
    d.head_scale = .9


# ------------------------------------------------------------------ frog
def frog(d: Design):
    """Squat and wide: broad pear-shaped trunk, no neck, flat wide head with
    eyes on top, long hind legs folded out to the sides, webbed feet, slender
    arms with sticky finger pads; sleeveless racing vest."""
    d.palette.update({'Fur': '5DBB5F', 'Skin': '5DBB5F', 'Belly': 'EAF0B4', 'Cream': 'EAF0B4', 'Spot': '3E8C45', 'Web': '7FCB76',
                      'Iris': 'E9B92E', 'Brow': '3E8C45', 'InnerEar': 'F29AA0'})
    d.joints = {'shoulder': (.25, .0, 1.12), 'elbow': (.33, .15, .99), 'hip': (.16, -.03, .845), 'knee': (.37, .1, 1.0)}
    body(d, {'torso': [((0, -.04, .87), (.26, .19, .13)), ((0, -.02, .99), (.285, .21, .17)), ((0, -.03, 1.1), (.26, .18, .14))],
             'skin': 'Skin', 'top': 'vest', 'arm': (.05, .043, .043, .037), 'leg': (.1, .078, .064, .05),
             'hand': 'web', 'foot': 'web', 'neck': None, 'yoke': 0, 'shoulder_ball': True, 'hem_z': .95, 'hem_r': (.3, .22)})
    d.plan.update({'zip': (.96, 1.2)})
    vest_paint(d, 'Skin', .95, 1.21, colour='Suit', arm_clear=.075)
    d.paint(K.Fn(lambda p, e=K.Ellipsoid((0, .1, .93), (.22, .14, .1)): e(p), (-.4, -.1, .7), (.4, .4, 1.1)), 'Belly', .015, only={'Skin'})
    # flat wide head sitting straight on the trunk
    d.add(K.Ellipsoid((0, .0, 1.44), (.33, .25, .16)), k=.08, label='Skin')
    d.add(K.Ellipsoid((0, .06, 1.35), (.3, .21, .11)), k=.08, label='Skin')
    d.paint(K.Fn(lambda p: np.maximum(np.maximum(p[..., 2] - (1.38 + .5 * p[..., 0] ** 2), -p[..., 1] - .02), 1.23 - p[..., 2]), (-.4, -.1, 1.13), (.4, .4, 1.48)), 'Belly', .008, only={'Skin'})
    for side, s in (('L', -1), ('R', 1)):
        d.add(K.Ellipsoid((s * .165, .04, 1.57), (.12, .115, .11)), k=.07, label='Skin')
    standard_face(d, (.165, .085, 1.61), (.088, .082, .088), 'Iris', 'Skin', gaze=(0, 1, .25))
    d.eyes['pupil_aspect'] = (1.45, .5)
    d.eyes['segments'] = 48
    d.eyes['splay'] = .35
    d.eyes['iris_angle'] = .36
    d.eyes['pupil_angle'] = .17
    d.eyes['lid_cover'] = None
    mouth(d, (0, .24, 1.385), .15, .046, .034, 1.3765, 2.0)
    d.add(K.Tube([(-.27, .13, 1.41), (-.17, .21, 1.388), (0, .248, 1.382), (.17, .21, 1.388), (.27, .13, 1.41)], .007), op='subtract', k=.008)
    for s in (-1, 1):
        d.add(K.Ellipsoid((s * .045, .245, 1.465), (.009, .006, .006)), op='subtract', k=.004)
    for c, r in [((.0, -.08, 1.54), .035), ((.12, -.14, 1.48), .03), ((-.14, -.12, 1.5), .028), ((.24, -.06, 1.4), .025), ((-.26, -.03, 1.38), .03),
                 ((.36, .05, 1.0), .03), ((-.37, .06, 1.01), .03), ((.3, .14, .93), .022), ((-.29, .15, .94), .025), ((.1, -.18, 1.05), .03)]:
        d.paint(K.Sphere(c, r * 1.8), 'Spot', .01, only={'Skin'})
    d.detail.append(K.Ellipsoid((0, .12, 1.45), (.34, .2, .2)))
    d.bones.update({'Ear.L': ((-.15, .04, 1.57), (-.15, .04, 1.67)), 'Ear.R': ((.15, .04, 1.57), (.15, .04, 1.67)),
                    'Tail': ((0, -.20, .92), (0, -.30, .9))})
    d.brows = None
    d.goggle = None
    d.head_scale = .92


SPECIES = {'lion': lion, 'owl': owl, 'rabbit': rabbit, 'squirrel': squirrel, 'turtle': turtle, 'frog': frog}
