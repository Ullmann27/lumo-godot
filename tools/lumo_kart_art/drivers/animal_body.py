"""Shared sculpt description for the LUMO rival animals (no bpy needed).

Every figure is one continuous signed-distance body: torso, neck, head, ears,
arms, legs and tail are blended with smooth unions, so the skin flows from
fur into suit like Lumo instead of being a set of plugged-together balls.
A part carries its colour label and the bones it follows; paint volumes add
suit panels, muzzle and inner-ear colours on the same surface.

Blender axes: X = right of the figure, +Y = forward, Z = up, metres, seated
in the measured kart pose of the existing driver rig.
"""
from __future__ import annotations

import math

import numpy as np

import sdf_kit as K

F = np.float32

# Measured seated rig points (unchanged from the shipped driver contract).
SHOULDER = {'L': (-.255, -.015, 1.235), 'R': (.255, -.015, 1.235)}
ELBOW = {'L': (-.325, .16, 1.04), 'R': (.325, .16, 1.04)}
HAND = {'L': (-.16, .34, 1.055), 'R': (.16, .34, 1.055)}
HIP = {'L': (-.145, -.04, .83), 'R': (.145, -.04, .83)}
KNEE = {'L': (-.165, .18, .91), 'R': (.165, .18, .91)}
ANKLE = {'L': (-.18, .24, .80), 'R': (.18, .24, .80)}
SIGN = {'L': -1.0, 'R': 1.0}


class Part:
    """A geometric operation with a colour label and bone weights."""

    def __init__(self, shape, op='union', k=0.0, label='Fur', bones='Head', tau=.012, owns=True):
        self.shape = shape
        self.op = op
        self.k = k
        self.label = label
        self.bones = bones
        self.tau = tau
        # subtractions shape the surface but never own colour or weights
        self.owns = owns and op == 'union'


class Paint:
    """Colour override inside a volume (soft edge in metres)."""

    def __init__(self, shape, label, soft=.004, only=None):
        self.shape = shape
        self.label = label
        self.soft = soft
        self.only = only  # optional set of base labels it may recolour


class Design:
    def __init__(self, species):
        self.species = species
        self.parts: list[Part] = []
        self.paints: list[Paint] = []
        self.palette: dict[str, str] = {}
        self.eyes = {}
        self.bones = {}
        self.mouth = {}
        self.extras = []  # callables building separate accessory meshes
        self.detail = []  # shapes near which decimation keeps more triangles

    def add(self, shape, op='union', k=0.0, label='Fur', bones='Head', tau=.012, owns=True):
        part = Part(shape, op, k, label, bones, tau, owns)
        self.parts.append(part)
        return part

    def paint(self, shape, label, soft=.004, only=None):
        self.paints.append(Paint(shape, label, soft, only))


def v3(x):
    return np.asarray(x, dtype=np.float64)


def lerp(a, b, t):
    return tuple(float(a[i] + (b[i] - a[i]) * t) for i in range(3))


def torso_weights(p):
    z = p[..., 2]
    t1 = np.clip((z - .84) / .10, 0, 1)
    t2 = np.clip((z - .97) / .24, 0, 1)
    pel = np.where(z < .94, 1 - t1, 0.0)
    spi = np.where(z < .94, t1, 1 - t2)
    che = np.where(z < .94, 0.0, t2)
    return {'Pelvis': pel, 'Spine': spi, 'Chest': che}


def neck_weights(p):
    z = p[..., 2]
    t = np.clip((z - 1.27) / .16, 0, 1)
    t = t * t * (3 - 2 * t)
    return {'Chest': np.clip(1 - t * 2, 0, 1), 'Neck': 1 - np.abs(2 * t - 1), 'Head': np.clip(t * 2 - 1, 0, 1)}


def segment_weights(a_bone, b_bone, a, b, start=.35, end=.65):
    a, b = v3(a), v3(b)

    def fn(p):
        ab = b - a
        t = np.clip(((p - a) @ ab) / float(ab @ ab), 0, 1)
        s = np.clip((t - start) / (end - start), 0, 1)
        s = s * s * (3 - 2 * s)
        return {a_bone: 1 - s, b_bone: s}
    return fn


def band(base, center, normal, half, thick):
    """A raised band hugging another shape (cuff, collar, belt, boot top)."""
    c = v3(center)
    n = v3(normal) / np.linalg.norm(normal)
    lo = np.asarray(base.lo, dtype=np.float64)
    hi = np.asarray(base.hi, dtype=np.float64)

    def fn(p):
        slab = np.abs((p - c) @ n.astype(F)) - half
        return np.maximum(slab, base(p) - thick)
    return K.Fn(fn, lo - thick, hi + thick)


def slab_paint(fn, lo=(-1, -1, 0), hi=(1, 1, 3)):
    return K.Fn(fn, lo, hi)


def joints_of(d):
    """Per-species joint positions (hands and ankles stay on wheel and pedals)."""
    j = getattr(d, 'joints', None) or {}
    out = {}
    for name, base in (('shoulder', SHOULDER), ('elbow', ELBOW), ('hand', HAND), ('hip', HIP), ('knee', KNEE), ('ankle', ANKLE)):
        if name in j:
            x, y, z = j[name]
            out[name] = {'L': (-abs(x), y, z), 'R': (abs(x), y, z)}
        else:
            out[name] = dict(base)
    # the wheel grips and pedals are part of the kart contract
    out['hand'] = dict(HAND)
    out['ankle'] = dict(ANKLE)
    return out


def limb_weights(a_bone, b_bone, a, b, start, end):
    return segment_weights(a_bone, b_bone, a, b, start, end)


def body(d: Design, plan: dict):
    """Species body in the shared skeleton.

    plan keys (all optional except torso):
      torso: list of (center, radii) ellipsoids from pelvis to chest
      skin: label of bare body (Fur, Skin, Feather)
      top: 'overall' | 'jersey' | 'vest' | 'harness' | 'none'
      sleeves: 'long' | 'short' | 'none'; legs: 'long' | 'short' | 'none'
      arm: (upper r0, upper r1, fore r0, fore r1); leg: (thigh r0, r1, shin r0, r1)
      hand: glove | paw | small_paw | web | wing | claw
      foot: boot | long | web | talon | stump | small
      neck: (radius, top z) or None for no visible neck
    """
    J = joints_of(d)
    d.joints_resolved = J
    d.plan = plan
    skin = plan.get('skin', 'Fur')
    top = plan.get('top', 'overall')
    sleeves = plan.get('sleeves', 'long' if top in ('overall', 'jersey') else 'none')
    legs = plan.get('legs', 'long' if top == 'overall' else 'none')
    torso_label = 'Suit' if top in ('overall', 'jersey') else skin
    for center, radii in plan['torso']:
        d.add(K.Ellipsoid(center, radii), k=plan.get('torso_k', .07), label=torso_label, bones=torso_weights)
    sh_l, sh_r = v3(J['shoulder']['L']), v3(J['shoulder']['R'])
    yoke_r = plan.get('yoke', .085)
    if yoke_r:
        d.add(K.RoundCone(sh_l * (1, 1, 1) + v3((.05, -.015, -.02)), sh_r + v3((-.05, -.015, -.02)), yoke_r, yoke_r), k=.07, label=torso_label, bones=torso_weights)
    neck = plan.get('neck', (.085, 1.42))
    if neck:
        nr, ntop = neck
        d.add(K.RoundCone((0, -.035, sh_r[2] - .02), (0, -.01, ntop), nr + .015, nr + .01), k=.05, label=plan.get('neck_label', skin), bones=neck_weights)
        d.add(K.Ellipsoid((0, -.005, ntop - .015), (nr + .065, nr + .045, .075)), k=.07, label=plan.get('neck_label', skin), bones=neck_weights)
        if top in ('overall', 'jersey', 'vest'):
            collar = band(K.RoundCone((0, -.035, sh_r[2] - .035), (0, -.03, sh_r[2] + .125), nr + .028, nr + .02), (0, -.03, sh_r[2] + .055), (0, .12, 1), .028, .006)
            d.add(collar, k=.012, label='Navy', bones=neck_weights)
            cz = sh_r[2] + .09
            d.paint(K.Fn(lambda p, cz=cz: np.abs(p[..., 2] - (cz + .12 * p[..., 1])) - .008, (-.2, -.25, cz - .08), (.2, .25, cz + .08)), 'Orange', .002, only={'Navy'})
    if top == 'overall':
        pel = plan['torso'][0]
        belt_base = K.Ellipsoid((0, pel[0][1], .875), (pel[1][0] * 1.035, pel[1][1] * 1.045, .2))
        d.add(band(belt_base, (0, 0, .872), (0, 0, 1), .026, .012), k=.006, label='Rubber', bones={'Pelvis': 1.0})
    if top in ('vest', 'jersey') and plan.get('hem', True):
        pel = plan['torso'][0]
        zh = plan.get('hem_z', .9)
        hem_base = K.Ellipsoid((0, pel[0][1], zh), (plan.get('hem_r', (pel[1][0] * 1.04, pel[1][1] * 1.05))[0], plan.get('hem_r', (pel[1][0] * 1.04, pel[1][1] * 1.05))[1], .25))
        d.add(band(hem_base, (0, 0, zh), (0, .05, 1), .014, .008), k=.006, label='Navy', bones=torso_weights)
    ua0, ua1, fa0, fa1 = plan.get('arm', (.078, .064, .064, .054))
    th0, th1, sh0, sh1 = plan.get('leg', (.1, .082, .08, .068))
    for side in 'LR':
        s = SIGN[side]
        sh, el, ha = v3(J['shoulder'][side]), v3(J['elbow'][side]), v3(J['hand'][side])
        axis = (ha - el) / np.linalg.norm(ha - el)
        wrist = ha - axis * plan.get('wrist', .075)
        upper_label = 'Suit' if sleeves in ('long', 'short') else skin
        fore_label = 'Suit' if sleeves == 'long' else skin
        if plan.get('shoulder_ball', True):
            d.add(K.Ellipsoid(sh + v3((s * .01, .0, -.01)), (ua0 + .017, ua0 + .017, ua0 + .012)), k=.05, label=upper_label, bones={'UpperArm.' + side: .7, 'Chest': .3})
        d.add(K.RoundCone(sh, el, ua0, ua1), k=.03, label=upper_label, bones=segment_weights('UpperArm.' + side, 'Forearm.' + side, sh, el, .78, 1.0))
        d.add(K.RoundCone(el, wrist, fa0, fa1), k=.03, label=fore_label, bones=segment_weights('UpperArm.' + side, 'Forearm.' + side, el, wrist, 0.0, .22))
        if sleeves == 'long':
            d.add(band(K.RoundCone(wrist - axis * .03, wrist + axis * .02, fa1 + .008, fa1 + .006), wrist - axis * .008, axis, .018, .006), k=.008, label='White', bones={'Forearm.' + side: 1.0})
        elif sleeves == 'short':
            mid = sh + (el - sh) * .78
            ax2 = (el - sh) / np.linalg.norm(el - sh)
            d.add(band(K.RoundCone(mid - ax2 * .03, mid + ax2 * .03, ua1 + .02, ua1 + .018), mid, ax2, .016, .008), k=.008, label='White', bones=segment_weights('UpperArm.' + side, 'Forearm.' + side, sh, el, .78, 1.0))
        HANDS[plan.get('hand', 'glove')](d, side, s, ha, axis, plan)
        hip, knee, ankle = v3(J['hip'][side]), v3(J['knee'][side]), v3(J['ankle'][side])
        thigh_label = 'Suit' if legs in ('long', 'short') else skin
        shin_label = 'Suit' if legs == 'long' else skin
        d.add(K.RoundCone(hip, knee, th0, th1), k=.05, label=thigh_label, bones=segment_weights('Thigh.' + side, 'Shin.' + side, hip, knee, .8, 1.0))
        d.add(K.RoundCone(knee, ankle + v3((0, 0, .04)), sh0, sh1), k=.03, label=shin_label, bones=segment_weights('Thigh.' + side, 'Shin.' + side, knee, ankle, 0.0, .25))
        if legs == 'long' and plan.get('knee_pad', True):
            kd = v3(plan.get('knee_pad_offset', (0, .045, .025)))
            d.add(K.Ellipsoid(knee + kd, (sh0 - .012, .05, .055)), k=.015, label='Rubber', bones={'Shin.' + side: 1.0})
        elif legs == 'short':
            ax3 = (knee - hip) / np.linalg.norm(knee - hip)
            cuff = hip + (knee - hip) * .8
            d.add(band(K.RoundCone(cuff - ax3 * .03, cuff + ax3 * .03, th1 + .02, th1 + .018), cuff, ax3, .016, .008), k=.008, label='White', bones=segment_weights('Thigh.' + side, 'Shin.' + side, hip, knee, .8, 1.0))
        FEET[plan.get('foot', 'boot')](d, side, s, ankle, plan)


# ------------------------------------------------------------------ hands
def _fingers(d, side, s, ha, label, n, r0, r1, spread, length=.04, lift=.035, drop=-.01, tip=None, tip_label=None, tip_r=.0):
    for i in range(n):
        x = ha[0] + s * (-spread * (n - 1) / 2 + spread * i)
        a = (x, ha[1] + .02, ha[2] + lift)
        b = (x, ha[1] + .02 + length, ha[2] + drop)
        d.add(K.RoundCone(a, b, r0, r1), k=.012, label=label, bones={'Hand.' + side: 1.0})
        if tip_label:
            d.add(K.Sphere(v3(b) + v3((0, .006, -.008)), tip_r), k=.006, label=tip_label, bones={'Hand.' + side: 1.0})


def hand_glove(d, side, s, ha, axis, plan, scale=1.0, label='Glove', cuff_paint=True):
    d.add(K.Ellipsoid(ha + v3((0, -.01, .0)), (.062 * scale, .07 * scale, .058 * scale)), k=.025, label=label, bones={'Hand.' + side: 1.0})
    _fingers(d, side, s, ha, label, 4, .019 * scale, .017 * scale, .027 * scale)
    d.add(K.RoundCone(ha + v3((-s * .05 * scale, .0, .01)), ha + v3((-s * .045 * scale, .05, .045)), .022 * scale, .018 * scale), k=.015, label=label, bones={'Hand.' + side: 1.0})
    if cuff_paint:
        d.paint(K.Ellipsoid(ha + v3((0, -.005, .055 * scale)), (.045 * scale, .05 * scale, .02)), 'Orange', .003, only={label})


def hand_paw(d, side, s, ha, axis, plan):
    """Big lion paw: broad furry mitt, thick toes with pale pads under the rim."""
    lab = plan.get('skin', 'Fur')
    d.add(K.Ellipsoid(ha + v3((0, -.012, .006)), (.083, .084, .07)), k=.03, label=lab, bones={'Hand.' + side: 1.0})
    _fingers(d, side, s, ha, lab, 4, .028, .025, .034, length=.045, lift=.045, drop=-.012)
    d.add(K.RoundCone(ha + v3((-s * .066, -.005, .01)), ha + v3((-s * .058, .05, .05)), .029, .024), k=.015, label=lab, bones={'Hand.' + side: 1.0})
    # dark claws peeking over the rim
    for i in range(4):
        x = ha[0] + s * (-.051 + .034 * i)
        d.add(K.RoundCone((x, ha[1] + .075, ha[2] - .008), (x, ha[1] + .088, ha[2] - .03), .008, .003), k=.003, label='Claw', bones={'Hand.' + side: 1.0})
    d.paint(K.Ellipsoid(ha + v3((0, .02, -.05)), (.07, .07, .03)), 'Cream', .006, only={lab})


def hand_small_paw(d, side, s, ha, axis, plan):
    """Squirrel hand: small palm, four slim fingers with dark claws."""
    lab = plan.get('skin', 'Fur')
    d.add(K.Ellipsoid(ha + v3((0, -.008, .0)), (.045, .052, .042)), k=.02, label=lab, bones={'Hand.' + side: 1.0})
    for i in range(4):
        x = ha[0] + s * (-.033 + .022 * i)
        a = (x, ha[1] + .012, ha[2] + .028)
        b = (x, ha[1] + .05, ha[2] + .012)
        c = (x, ha[1] + .062, ha[2] - .018)
        d.add(K.Tube([a, b, c], [.0115, .0105, .009]), k=.008, label=lab, bones={'Hand.' + side: 1.0})
        d.add(K.RoundCone(c, v3(c) + v3((0, -.006, -.016)), .006, .002), k=.002, label='Claw', bones={'Hand.' + side: 1.0})
    d.add(K.RoundCone(ha + v3((-s * .04, .0, .008)), ha + v3((-s * .036, .045, .04)), .013, .01), k=.01, label=lab, bones={'Hand.' + side: 1.0})


def hand_web(d, side, s, ha, axis, plan):
    """Frog hand: flat palm, four long fingers with round sticky pads, webbing."""
    lab = plan.get('skin', 'Skin')
    d.add(K.Ellipsoid(ha + v3((0, -.01, .006)), (.05, .058, .036)), k=.02, label=lab, bones={'Hand.' + side: 1.0})
    tips = []
    for i, spread in enumerate((-1.5, -.5, .5, 1.5)):
        x = ha[0] + s * spread * .03
        a = (ha[0] + s * spread * .012, ha[1] + .01, ha[2] + .03)
        b = (x, ha[1] + .05, ha[2] + .035)
        c = (x * 1.0, ha[1] + .07, ha[2] - .012)
        d.add(K.Tube([a, b, c], [.011, .01, .009]), k=.008, label=lab, bones={'Hand.' + side: 1.0})
        d.add(K.Sphere(c, .017), k=.006, label='Belly', bones={'Hand.' + side: 1.0})
        tips.append(b)
    for i in range(3):
        mid = (v3(tips[i]) + v3(tips[i + 1])) / 2 + v3((0, -.012, -.004))
        d.add(K.Ellipsoid(mid, (.016, .022, .006)), k=.008, label=lab, bones={'Hand.' + side: 1.0})
    d.add(K.RoundCone(ha + v3((-s * .045, .0, .01)), ha + v3((-s * .04, .05, .045)), .012, .01), k=.01, label=lab, bones={'Hand.' + side: 1.0})
    d.add(K.Sphere(ha + v3((-s * .04, .055, .05)), .015), k=.005, label='Belly', bones={'Hand.' + side: 1.0})


def hand_wing(d, side, s, ha, axis, plan):
    """Owl wing tip: primary feathers fold round the rim instead of fingers."""
    J = d.joints_resolved
    sh, el = v3(J['shoulder'][side]), v3(J['elbow'][side])
    d.add(K.Ellipsoid(ha + v3((0, -.02, .01)), (.05, .06, .045)), k=.025, label='Feather', bones={'Hand.' + side: 1.0})
    for i in range(5):
        x = ha[0] + s * (-.045 + .024 * i)
        root = v3((x, ha[1] - .01, ha[2] + .035))
        mid = v3((x + s * .004, ha[1] + .055, ha[2] + .03))
        tip = v3((x + s * .008, ha[1] + .075, ha[2] - .025 - .004 * i))
        d.add(K.Leaf([root, mid, tip], [.016, .015, .005], [.007, .006, .003], (0, 0, 1)), k=.006, label='FeatherDark' if i % 2 else 'Feather', bones={'Hand.' + side: 1.0})
    # broad wing: covert and flight feathers along the whole arm
    for k in range(9):
        t = k / 8
        root = sh + (el - sh) * min(1, t * 1.7) if t < .59 else el + (ha - el) * ((t - .59) / .41) * .8
        out = v3((s * .07, -.045, -.02))
        tip = root + v3((s * .045, -.13 - .015 * k, -.17 + .012 * k))
        bone = 'UpperArm.' + side if t < .5 else 'Forearm.' + side
        d.add(K.Leaf([root + out * .4, (root + tip) / 2 + out * .6, tip + out * .3], [.06, .055, .016], [.016, .013, .004], (s, 0, 0)), k=.02, label='FeatherDark' if k % 2 else 'Feather', bones={bone: 1.0})


def hand_claw(d, side, s, ha, axis, plan):
    """Turtle hand: stubby rounded flipper-hand with three blunt nails."""
    lab = plan.get('skin', 'Skin')
    d.add(K.Ellipsoid(ha + v3((0, -.008, .008)), (.07, .075, .058)), k=.03, label=lab, bones={'Hand.' + side: 1.0})
    for i in range(3):
        x = ha[0] + s * (-.032 + .032 * i)
        d.add(K.RoundCone((x, ha[1] + .03, ha[2] + .04), (x, ha[1] + .07, ha[2] - .005), .024, .021), k=.014, label=lab, bones={'Hand.' + side: 1.0})
        d.add(K.Ellipsoid((x, ha[1] + .088, ha[2] - .018), (.014, .012, .01)), k=.004, label='Nail', bones={'Hand.' + side: 1.0})
    d.add(K.RoundCone(ha + v3((-s * .062, .0, .015)), ha + v3((-s * .055, .045, .05)), .025, .02), k=.015, label=lab, bones={'Hand.' + side: 1.0})


HANDS = {'glove': hand_glove, 'paw': hand_paw, 'small_paw': hand_small_paw, 'web': hand_web, 'wing': hand_wing, 'claw': hand_claw,
         'slim_glove': lambda d, side, s, ha, axis, plan: hand_glove(d, side, s, ha, axis, plan, .86)}


# ------------------------------------------------------------------ feet
def foot_boot(d, side, s, a, plan, scale=1.0):
    boot = K.RoundBox(a + v3((0, .055, .0)), (.04 * scale, .085 * scale, .03 * scale), .045 * scale)
    d.add(boot, k=.03, label='White', bones={'Foot.' + side: 1.0})
    d.add(K.RoundBox(a + v3((0, .055, -.055 * scale)), (.05 * scale, .1 * scale, .004), .012), k=.01, label='Orange', bones={'Foot.' + side: 1.0})
    d.add(band(K.RoundCone(a + v3((0, 0, -.02)), a + v3((0, 0, .09)), .07 * scale, .068 * scale), a + v3((0, 0, .055)), (0, 0, 1), .02, .008), k=.008, label='Suit', bones={'Foot.' + side: 1.0})
    d.paint(K.Fn(lambda p, a=a: np.abs((p[..., 1] - a[1]) - .045 - .3 * (p[..., 2] - a[2])) - .016, a - .25, a + .25), 'Orange', .003, only={'White'})


def foot_long(d, side, s, a, plan):
    """Rabbit hind foot: long, flat, furry, three toe pads; pale sole."""
    lab = plan.get('skin', 'Fur')
    heel = a + v3((0, -.04, -.03))
    toe = a + v3((s * .01, .25, -.045))
    d.add(K.RoundCone(heel, toe, .05, .042, squash=((1, 0, 0), .8)), k=.04, label=lab, bones={'Foot.' + side: 1.0})
    for i in (-1, 0, 1):
        d.add(K.Ellipsoid(toe + v3((s * .01 + i * .024, .015, .003)), (.018, .028, .022)), k=.012, label=lab, bones={'Foot.' + side: 1.0})
    d.paint(K.Fn(lambda p, z=float(a[2] - .07): p[..., 2] - z, a - .3, a + .3), 'Cream', .006, only={lab})


def foot_web(d, side, s, a, plan):
    lab = plan.get('skin', 'Skin')
    d.add(K.Ellipsoid(a + v3((0, .04, -.01)), (.07, .08, .04)), k=.04, label=lab, bones={'Foot.' + side: 1.0})
    tips = []
    for ang in (-.55, -.18, .18, .55):
        dvec = v3((math.sin(ang) * s * .9 + s * .12, math.cos(ang), 0))
        dvec /= np.linalg.norm(dvec)
        base = a + v3((0, .07, -.02))
        tip = base + dvec * .16
        d.add(K.RoundCone(base, tip, .022, .015), k=.02, label=lab, bones={'Foot.' + side: 1.0})
        d.add(K.Sphere(tip + dvec * .012, .022), k=.01, label='Belly', bones={'Foot.' + side: 1.0})
        tips.append(tip)
    for i in range(3):
        mid = (tips[i] + tips[i + 1]) / 2 * .75 + (a + v3((0, .07, -.02))) * .25
        d.add(K.Ellipsoid(mid, (.04, .045, .006)), k=.012, label='Web', bones={'Foot.' + side: 1.0})


def foot_talon(d, side, s, a, plan):
    """Owl foot: feathered ankle, three forward toes and one back, dark hooks."""
    d.add(K.Ellipsoid(a + v3((0, .0, .03)), (.06, .06, .06)), k=.03, label='FeatherLight', bones={'Foot.' + side: 1.0})
    base = a + v3((0, .03, -.03))
    for ang in (-.45, 0, .45):
        dvec = v3((math.sin(ang) * s * .9, math.cos(ang), -.15)); dvec /= np.linalg.norm(dvec)
        knuckle = base + dvec * .07
        tip = knuckle + dvec * .05 + v3((0, 0, -.025))
        d.add(K.Tube([base, knuckle, tip], [.018, .016, .012]), k=.01, label='Talon', bones={'Foot.' + side: 1.0})
        d.add(K.RoundCone(tip, tip + dvec * .02 + v3((0, 0, -.03)), .01, .003), k=.003, label='Claw', bones={'Foot.' + side: 1.0})
    back = base + v3((s * .02, -.08, -.005))
    d.add(K.RoundCone(base, back, .016, .012), k=.01, label='Talon', bones={'Foot.' + side: 1.0})


def foot_stump(d, side, s, a, plan):
    """Turtle foot: thick round column foot with four blunt nails."""
    lab = plan.get('skin', 'Skin')
    d.add(K.RoundCone(a + v3((0, .0, .05)), a + v3((0, .07, -.03)), .07, .075, squash=((0, 0, 1), .7)), k=.04, label=lab, bones={'Foot.' + side: 1.0})
    for i in range(4):
        ang = (-.5 + i / 3) * 1.1
        p = a + v3((math.sin(ang) * .062, .07 + math.cos(ang) * .068, -.04))
        d.add(K.Ellipsoid(p, (.016, .014, .012)), k=.004, label='Nail', bones={'Foot.' + side: 1.0})


def foot_small(d, side, s, a, plan):
    """Squirrel foot: slim paw with four toes and claws."""
    lab = plan.get('skin', 'Fur')
    d.add(K.RoundCone(a + v3((0, -.02, -.01)), a + v3((0, .12, -.04)), .04, .032, squash=((1, 0, 0), .85)), k=.03, label=lab, bones={'Foot.' + side: 1.0})
    for i in range(4):
        x = (i - 1.5) * .018
        p = a + v3((x, .15, -.045))
        d.add(K.RoundCone(a + v3((x * .6, .1, -.035)), p, .012, .01), k=.008, label=lab, bones={'Foot.' + side: 1.0})
        d.add(K.RoundCone(p, p + v3((0, .015, -.012)), .006, .002), k=.002, label='Claw', bones={'Foot.' + side: 1.0})


FEET = {'boot': foot_boot, 'big_boot': lambda d, side, s, a, plan: foot_boot(d, side, s, a, plan, 1.15), 'long': foot_long,
        'web': foot_web, 'talon': foot_talon, 'stump': foot_stump, 'small': foot_small}


def vest_paint(d, base_label, z_lo, z_hi, open_front=0.0, colour='Suit', arm_clear=.1):
    """Paint a sleeveless racing vest onto the torso (optionally open at the front)."""
    J = d.joints_resolved
    sh = v3(J['shoulder']['R'])
    torso = [K.Ellipsoid(c, r) for c, r in d.plan['torso']]

    def fn(p):
        x, y, z = p[..., 0], p[..., 1], p[..., 2]
        dz = np.maximum(z - (z_hi + .03 * np.cos(x * 6)), z_lo - z)
        armhole = arm_clear - np.sqrt((np.abs(x) - sh[0]) ** 2 + (y - sh[1]) ** 2 + (z - sh[2]) ** 2)
        near = np.min(np.stack([t(p) for t in torso]), axis=0) - .03
        out = np.maximum(np.maximum(dz, armhole), near)
        if open_front > 0:
            gap = open_front * np.clip((z - z_lo) / max(z_hi - z_lo, 1e-3), .25, 1) - np.abs(x)
            out = np.maximum(out, np.where(y > 0, gap, -1.0))
        return out
    d.paint(K.Fn(fn, (-.6, -.6, z_lo - .05), (.6, .6, z_hi + .1)), colour, .004, only={base_label})


def ellipsoid_surface_y(center, radii, x, z):
    c, r = center, radii
    q = 1 - ((x - c[0]) / r[0]) ** 2 - ((z - c[2]) / r[2]) ** 2
    return c[1] + r[1] * math.sqrt(max(q, 0.0))


def rot_axis(axis, angle):
    axis = np.asarray(axis, dtype=np.float64)
    axis = axis / np.linalg.norm(axis)
    x, y, z = axis
    c, s = math.cos(angle), math.sin(angle)
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])
