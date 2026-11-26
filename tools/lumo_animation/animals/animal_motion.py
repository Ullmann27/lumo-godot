"""Clip library for the standing LUMO animal figures (Blender mathutils only).

Every clip is a function of normalised time that returns a *pose description*
(pelvis, spine, head, feet placements, hand targets, face, ears, tail). One
solver turns a pose into armature-space bone matrices:

* legs: analytic two-bone IK to authored foot placements; the stance foot is a
  rigid body that rolls over heel and ball pivots and stays on the ground,
* arms: analytic two-bone IK to hand targets with an elbow pole,
* trunk, head, ears, tail: forward kinematics about the rest joint centres,
* face: jaw hinge, eye gaze and the eyelid shells of the driver rig.

Coordinates: Blender armature space, metres, +Y forward, +Z up, X to the
figure's right. The root never moves: locomotion clips are authored in place,
the stance foot slides backwards at exactly the travelling speed so the game
translates the figure with ``stride / duration`` metres per second.
"""
from __future__ import annotations

import copy
import math

from mathutils import Matrix, Quaternion, Vector

TAU = math.tau
SIDES = (("L", -1.0), ("R", 1.0))
TAIL = ("Tail", "TailMid", "TailTip")
LID_HIDDEN = .93


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def smooth(value):
    value = clamp(value)
    return value * value * (3 - 2 * value)


def smoother(value):
    value = clamp(value)
    return value * value * value * (value * (value * 6 - 15) + 10)


def window(t, start, end, fade=.12):
    """1 inside [start, end] with smooth shoulders of width ``fade``."""
    return smooth((t - start) / fade) * smooth((end - t) / fade)


def pulse(t, centre, width):
    x = (t - centre) / width
    return max(0.0, 1 - x * x) ** 2


def rot(pitch=0.0, roll=0.0, yaw=0.0):
    return Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')


def about(pivot, matrix):
    return Matrix.Translation(pivot) @ matrix @ Matrix.Translation(-Vector(pivot))


def solve_joint(start, end, la, lb, pole):
    delta = end - start
    dist = max(1e-6, min(delta.length, la + lb - 1e-5))
    axis = delta.normalized()
    along = (la * la - lb * lb + dist * dist) / (2 * dist)
    radius = math.sqrt(max(0.0, la * la - along * along))
    perp = Vector(pole) - axis * Vector(pole).dot(axis)
    if perp.length < 1e-6:
        perp = axis.orthogonal()
    return start + axis * along + perp.normalized() * radius, start + axis * dist


def frame(direction, reference):
    d = direction.normalized()
    x = d.cross(reference)
    if x.length < 1e-6:
        x = d.orthogonal()
    x.normalize()
    z = x.cross(d)
    return Matrix((x, d, z)).transposed()


def align(rest_dir, rest_ref, new_dir, new_ref):
    return (frame(new_dir, new_ref) @ frame(rest_dir, rest_ref).transposed()).to_4x4()


def bend_ref(start, mid, end, pole):
    """Direction the middle joint bends to; the pole decides for a straight limb."""
    axis = (end - start).normalized()
    off = (mid - start) - axis * (mid - start).dot(axis)
    pole = Vector(pole)
    side = pole - axis * pole.dot(axis)
    if side.length < 1e-6:
        side = axis.orthogonal()
    side.normalize()
    if off.length < 1e-6:
        return side
    w = smooth(off.length / (.04 * ((mid - start).length + (end - mid).length)))
    if off.normalized().dot(side) < 0:
        w = 0.0
    return (side * (1 - w) + off.normalized() * w).normalized()


# --------------------------------------------------------------------- skeleton
class Skeleton:
    """Rest measurements taken once from the built armature."""

    def __init__(self, rig, lid_rest=2.6, lid_shown=1.045, max_gaze=None):
        bones = rig.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.head = {b.name: b.head_local.copy() for b in bones}
        self.tail = {b.name: b.tail_local.copy() for b in bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.order = [b.name for b in bones]
        self.lid_rest = lid_rest
        self.lid_shown = lid_shown
        self.max_gaze = max_gaze
        self.top = float(rig.get('figure_height', 1.6))
        self.hip = {s: self.head['Thigh.' + s] for s, _ in SIDES}
        self.knee = {s: self.head['Shin.' + s] for s, _ in SIDES}
        self.ankle = {s: self.head['Foot.' + s] for s, _ in SIDES}
        self.ball = {s: self.head['Toe.' + s] for s, _ in SIDES}
        self.heel = {s: Vector((self.ankle[s].x, float(rig['heel_y_' + s]), 0.0)) for s, _ in SIDES}
        self.ball_ground = {s: Vector((self.ball[s].x, self.ball[s].y, 0.0)) for s, _ in SIDES}
        self.leg_a = {s: (self.knee[s] - self.hip[s]).length for s, _ in SIDES}
        self.leg_b = {s: (self.ankle[s] - self.knee[s]).length for s, _ in SIDES}
        self.shoulder = {s: self.head['UpperArm.' + s] for s, _ in SIDES}
        self.elbow = {s: self.head['Forearm.' + s] for s, _ in SIDES}
        self.wrist = {s: self.head['Hand.' + s] for s, _ in SIDES}
        self.arm_a = {s: (self.elbow[s] - self.shoulder[s]).length for s, _ in SIDES}
        self.arm_b = {s: (self.wrist[s] - self.elbow[s]).length for s, _ in SIDES}
        self.hip_height = (self.hip['L'].z + self.hip['R'].z) / 2
        self.ankle_height = (self.ankle['L'].z + self.ankle['R'].z) / 2
        self.leg = min(self.leg_a[s] + self.leg_b[s] for s, _ in SIDES)
        self.arm = min(self.arm_a[s] + self.arm_b[s] for s, _ in SIDES)
        down = Vector((0, 0, -1))
        self.rest_abduction = sum((self.elbow[s] - self.shoulder[s]).angle(down) for s, _ in SIDES) / 2
        self.has_tail = bool(rig.get('tail_weighted', True))

    # Hand position for a hanging/swinging arm, relative to the shoulder (chest rest frame).
    def arm_hand(self, side, sign, abduction, flexion, elbow, inward=.3, twist=0.0):
        upper = Matrix.Rotation(flexion, 3, 'X') @ Matrix.Rotation(-sign * abduction, 3, 'Y') @ Vector((0, 0, -1))
        forward = Vector((-sign * inward, 1, 0)).normalized()
        bend = forward - upper * forward.dot(upper)
        if bend.length < 1e-6:
            bend = upper.orthogonal()
        bend.normalize()
        fore = upper * math.cos(elbow) + bend * math.sin(elbow)
        fore = Matrix.Rotation(twist, 3, upper) @ fore
        return upper * self.arm_a[side] + fore * self.arm_b[side]


# --------------------------------------------------------------------- poses
def neutral(sk: Skeleton):
    feet = {}
    hands = {}
    for side, sign in SIDES:
        a = sk.ankle[side]
        width = sk.hip[side].x + .32 * (a.x - sk.hip[side].x)
        feet[side] = {'x': width, 'y': a.y, 'lift': 0.0, 'pitch': 0.0, 'yaw': sign * .06, 'toe': 0.0}
        abduction = clamp(.82 * sk.rest_abduction, .18, .62)
        hands[side] = {'pos': sk.arm_hand(side, sign, abduction, .06, .32), 'space': 'chest',
                       'pole': Vector((sign * .35, -1, -.25)), 'wrist': (0.0, 0.0, 0.0)}
    pose = {
        'pelvis': {'off': Vector((0, 0, 0)), 'rot': (0.0, 0.0, 0.0)},
        'Spine': (0.0, 0.0, 0.0), 'Chest': (0.0, 0.0, 0.0), 'Neck': (0.0, 0.0, 0.0),
        'Head': (0.0, 0.0, 0.0), 'head_follow': .55,
        'feet': feet, 'hands': hands,
        'jaw': 0.0, 'blink': 0.0, 'lid_open': 0.0, 'gaze': (0.0, 0.0),
        'ears': {'L': (0.0, 0.0), 'R': (0.0, 0.0)},
        'tail': [(0.0, 0.0), (0.0, 0.0), (0.0, 0.0)],
    }
    pose['pelvis']['off'] = Vector((0, 0, -stand_drop(sk, pose)))
    return pose


def stand_drop(sk, pose, ratio=.985):
    """Lower the pelvis until every foot placement is comfortably reachable."""
    drop = 0.0
    for _ in range(200):
        ok = True
        for side, _sign in SIDES:
            f = pose['feet'][side]
            hip = sk.hip[side] + Vector((0, 0, -drop))
            ankle = Vector((f['x'], f['y'], sk.ankle[side].z + f['lift']))
            if (ankle - hip).length > ratio * (sk.leg_a[side] + sk.leg_b[side]):
                ok = False
        if ok:
            return drop
        drop += .001 * sk.top
    return drop


def mix(a, b, t):
    """Blend two pose descriptions (numbers, vectors, tuples, dicts)."""
    if isinstance(a, dict):
        return {k: mix(a[k], b[k], t) if k in b else a[k] for k in a}
    if isinstance(a, Vector):
        return a.lerp(b, t)
    if isinstance(a, (tuple, list)):
        return type(a)(mix(x, y, t) for x, y in zip(a, b))
    if isinstance(a, str):
        return a if t < .5 else b
    return a + (b - a) * t


def offset(a, b):
    return tuple(x + y for x, y in zip(a, b))


# --------------------------------------------------------------------- solver
def solve(sk: Skeleton, pose):
    D = {'Root': Matrix.Identity(4)}
    pelvis = pose['pelvis']
    hip_centre = sk.head['Pelvis']
    D['Pelvis'] = Matrix.Translation(pelvis['off']) @ about(hip_centre, rot(*pelvis['rot']))
    for name, parent in (('Spine', 'Pelvis'), ('Chest', 'Spine'), ('Neck', 'Chest')):
        D[name] = D[parent] @ about(sk.head[name], rot(*pose[name]))
    # Head: partly stabilised against the trunk (gaze stays level while walking).
    pivot = D['Neck'] @ sk.head['Head']
    trunk = D['Neck'].to_quaternion()
    head_rotation = Quaternion().slerp(trunk, pose['head_follow']).to_matrix().to_4x4() @ rot(*pose['Head'])
    D['Head'] = Matrix.Translation(pivot) @ head_rotation @ Matrix.Translation(-sk.head['Head'])
    yaw = pelvis['rot'][2]
    for side, sign in SIDES:
        f = pose['feet'][side]
        a = sk.ankle[side]
        move = Matrix.Translation(Vector((f['x'] - a.x, f['y'] - a.y, f['lift'])))
        turn = about(move @ a, Matrix.Rotation(f['yaw'], 4, 'Z'))
        pivot_rest = sk.ball_ground[side] if f['pitch'] < 0 else sk.heel[side]
        pivot_now = turn @ move @ pivot_rest
        axis = Matrix.Rotation(f['yaw'], 3, 'Z') @ Vector((1, 0, 0))
        foot = about(pivot_now, Matrix.Rotation(f['pitch'], 4, axis)) @ turn @ move
        target = foot @ a
        hip = D['Pelvis'] @ sk.hip[side]
        pole = Matrix.Rotation(yaw * .5 + f['yaw'] * .5, 3, 'Z') @ Vector((sign * .12, 1, 0))
        knee, ankle = solve_joint(hip, target, sk.leg_a[side], sk.leg_b[side], pole)
        rest_ref = bend_ref(sk.hip[side], sk.knee[side], sk.ankle[side], Vector((sign * .12, 1, 0)))
        new_ref = bend_ref(hip, knee, ankle, pole)
        D['Thigh.' + side] = Matrix.Translation(hip) @ align(
            sk.knee[side] - sk.hip[side], rest_ref, knee - hip, new_ref) @ Matrix.Translation(-sk.hip[side])
        D['Shin.' + side] = Matrix.Translation(knee) @ align(
            sk.ankle[side] - sk.knee[side], rest_ref, ankle - knee, new_ref) @ Matrix.Translation(-sk.knee[side])
        D['Foot.' + side] = Matrix.Translation(ankle - target) @ foot
        D['Toe.' + side] = D['Foot.' + side] @ about(sk.ball[side], Matrix.Rotation(f['toe'], 4, 'X'))
    for side, sign in SIDES:
        h = pose['hands'][side]
        shoulder = D['Chest'] @ sk.shoulder[side]
        chest_rotation = D['Chest'].to_3x3()
        if h['space'] == 'chest':
            target = shoulder + chest_rotation @ Vector(h['pos'])
        else:
            target = Vector(h['pos'])
        pole = chest_rotation @ Vector(h['pole'])
        elbow, hand = solve_joint(shoulder, target, sk.arm_a[side], sk.arm_b[side], pole)
        rest_ref = bend_ref(sk.shoulder[side], sk.elbow[side], sk.wrist[side], Vector((sign * .35, -1, -.25)))
        new_ref = bend_ref(shoulder, elbow, hand, pole)
        upper = align(sk.elbow[side] - sk.shoulder[side], rest_ref, elbow - shoulder, new_ref)
        fore = align(sk.wrist[side] - sk.elbow[side], rest_ref, hand - elbow, new_ref)
        D['UpperArm.' + side] = Matrix.Translation(shoulder) @ upper @ Matrix.Translation(-sk.shoulder[side])
        D['Forearm.' + side] = Matrix.Translation(elbow) @ fore @ Matrix.Translation(-sk.elbow[side])
        D['Hand.' + side] = Matrix.Translation(hand) @ fore @ rot(*h['wrist']) @ Matrix.Translation(-sk.wrist[side])
    parent = 'Pelvis'
    for index, name in enumerate(TAIL):
        pitch, yaw_t = pose['tail'][index]
        D[name] = D[parent] @ about(sk.head[name], rot(pitch, 0.0, yaw_t))
        parent = name
    for side, sign in SIDES:
        pitch, droop = pose['ears'][side]
        D['Ear.' + side] = D['Head'] @ about(sk.head['Ear.' + side], rot(pitch, sign * droop, 0.0))
    D['Jaw'] = D['Head'] @ about(sk.head['Jaw'], Matrix.Rotation(-.24 * pose['jaw'], 4, 'X'))
    gaze_yaw, gaze_pitch = pose['gaze']
    if sk.max_gaze is not None:
        gaze_yaw = clamp(gaze_yaw, -sk.max_gaze, sk.max_gaze)
        gaze_pitch = clamp(gaze_pitch, -sk.max_gaze, sk.max_gaze)
    M = {}
    for side, _sign in SIDES:
        D['Eye.' + side] = D['Head'] @ about(sk.head['Eye.' + side],
                                             Matrix.Rotation(gaze_yaw, 4, 'Z') @ Matrix.Rotation(gaze_pitch, 4, 'X'))
        close = clamp(pose['blink'])
        angle = sk.lid_rest * close - .25 * pose['lid_open']
        grow = 1.0 + (sk.lid_shown / LID_HIDDEN - 1.0) * smooth(close / .25)
        M['Lid.' + side] = D['Head'] @ sk.rest['Lid.' + side] @ Matrix.Rotation(-angle, 4, 'X') @ Matrix.Scale(grow, 4)
    for name in sk.order:
        if name not in M:
            M[name] = D[name] @ sk.rest[name]
    return M


def basis(sk: Skeleton, M):
    """Local pose-bone matrices from armature-space pose matrices."""
    out = {}
    for name in sk.order:
        parent = sk.parent[name]
        if parent:
            out[name] = sk.rest[name].inverted() @ sk.rest[parent] @ M[parent].inverted() @ M[name]
        else:
            out[name] = sk.rest[name].inverted() @ M[name]
    return out


# --------------------------------------------------------------------- gait
class Gait:
    def __init__(self, sk, kind):
        self.kind = kind
        H = sk.hip_height
        if kind == 'walk':
            self.duration, self.stride, self.duty = .96, 1.15 * H, .62
            self.clear, self.bob, self.sway, self.lean = .13 * H, .022 * H, .028 * H, -.06
            self.heel, self.toe_off, self.arm_swing, self.elbow = .22, -.55, .32, .32
            self.pelvis_yaw, self.pelvis_roll, self.width = .09, .05, .30
        else:
            self.duration, self.stride, self.duty = .64, 2.05 * H, .38
            self.clear, self.bob, self.sway, self.lean = .30 * H, .045 * H, .016 * H, -.2
            self.heel, self.toe_off, self.arm_swing, self.elbow = .08, -.75, .62, 1.35
            self.pelvis_yaw, self.pelvis_roll, self.width = .13, .04, .18
        self.speed = self.stride / self.duration

    def foot(self, sk, side, phase, base):
        """Foot placement for one leg at its own phase (0 = heel strike)."""
        d = self.duty
        reach = self.stride * d / 2
        f = dict(base)
        if phase < d:
            u = phase / d
            f['y'] = base['y'] + reach - u * self.stride * d
            f['lift'] = 0.0
            strike = 1 - smooth(u / .16)
            roll = smooth((u - .68) / .32)
            f['pitch'] = self.heel * strike + self.toe_off * .55 * roll
            f['toe'] = -min(0.0, f['pitch'])
        else:
            u = (phase - d) / (1 - d)
            travel = u - math.sin(TAU * u) / TAU
            f['y'] = base['y'] - reach + travel * self.stride * d
            f['lift'] = self.clear * math.sin(math.pi * clamp(u) ** .85) ** 1.4
            # toe-off, tuck, then prepare the heel strike
            f['pitch'] = (self.toe_off * .55 * (1 - smooth(u / .35)) + -.18 * window(u, .25, .7, .2)
                          + self.heel * smooth((u - .7) / .3))
            f['toe'] = -min(0.0, f['pitch']) * (1 - smooth(u / .3))
        return f


def locomotion(sk, kind):
    gait = Gait(sk, kind)
    base = neutral(sk)
    for side, _sign in SIDES:
        foot = base['feet'][side]
        foot['x'] = sk.hip[side].x + gait.width * (sk.ankle[side].x - sk.hip[side].x)
        foot['y'] = sk.ankle[side].y + .02 * sk.hip_height

    # pelvis height so that the longest reach stays below 96 % of the leg
    def worst_drop():
        drop = 0.0
        while drop < .4 * sk.hip_height:
            fine = True
            for i in range(48):
                phase = i / 48
                for side, sign in SIDES:
                    own = (phase + (0 if side == 'L' else .5)) % 1
                    f = gait.foot(sk, side, own, base['feet'][side])
                    hip = sk.hip[side] + Vector((0, 0, -drop - gait.bob))
                    ankle = Vector((f['x'], f['y'], sk.ankle[side].z + f['lift']))
                    if (ankle - hip).length > .965 * (sk.leg_a[side] + sk.leg_b[side]):
                        fine = False
            if fine:
                return drop
            drop += .002 * sk.top
        return drop
    drop = worst_drop()

    def pose_at(t):
        p = copy.deepcopy(base)
        phase = t % 1.0
        for side, sign in SIDES:
            own = (phase + (0 if side == 'L' else .5)) % 1
            p['feet'][side] = gait.foot(sk, side, own, base['feet'][side])
        if kind == 'walk':
            bob = -math.cos(2 * TAU * phase) * gait.bob
        else:
            bob = -math.cos(2 * TAU * (phase - gait.duty / 2)) * gait.bob
        sway = -math.sin(TAU * phase) * gait.sway
        p['pelvis']['off'] = Vector((sway, .0, -drop + bob))
        yaw = -gait.pelvis_yaw * math.cos(TAU * phase)
        roll = gait.pelvis_roll * math.sin(TAU * phase)
        p['pelvis']['rot'] = (gait.lean * .5, roll, yaw)
        p['Spine'] = (gait.lean * .25, -roll * .6, -yaw * .5)
        p['Chest'] = (gait.lean * .25 + .02 * math.sin(2 * TAU * phase), -roll * .4, -yaw * .9)
        p['Neck'] = (-gait.lean * .3, 0.0, 0.0)
        p['Head'] = (-gait.lean * .35 + .03 * math.sin(2 * TAU * phase - .6), 0.0, 0.0)
        p['head_follow'] = .25
        for side, sign in SIDES:
            swing = gait.arm_swing * math.cos(TAU * (phase - .04)) * (-sign)
            elbow = gait.elbow + (.22 if kind == 'walk' else .1) * max(0.0, swing / gait.arm_swing)
            abduction = clamp(.78 * sk.rest_abduction, .16, .58) * (1.0 if kind == 'walk' else .8)
            p['hands'][side]['pos'] = sk.arm_hand(side, sign, abduction, swing - gait.lean, elbow,
                                                  inward=.45 if kind == 'run' else .3)
            p['hands'][side]['wrist'] = (-.1 * swing, 0.0, 0.0)
        lag = .35
        amp = .07 if kind == 'walk' else .12
        p['tail'] = [(.05 * math.sin(2 * TAU * phase - lag * (i + 1)) - (.1 if kind == 'run' else 0.0) * (i == 0),
                      amp * (1 + i * .45) * math.sin(TAU * phase - lag * (i + 1))) for i in range(3)]
        ear = (.10 if kind == 'walk' else .2) * math.sin(2 * TAU * phase - 1.1)
        p['ears'] = {'L': (ear + (.12 if kind == 'run' else 0.0), .03), 'R': (ear + (.12 if kind == 'run' else 0.0), .03)}
        p['blink'] = pulse(phase, .55, .05) if kind == 'walk' else 0.0
        p['jaw'] = .12 if kind == 'run' else 0.0
        return p
    return gait, pose_at, drop


# --------------------------------------------------------------------- clips
def idle_pose(sk, t, base=None):
    """Breathing, slow weight shift, a look-around, a blink, a tail flick."""
    p = copy.deepcopy(base or neutral(sk))
    breath = math.sin(TAU * t * 2)
    shift = math.sin(TAU * t)
    p['pelvis']['off'] = p['pelvis']['off'] + Vector((.012 * sk.hip_height * shift, 0, .004 * sk.hip_height * breath))
    p['pelvis']['rot'] = (0.0, -.025 * shift, .02 * shift)
    p['Spine'] = (.012 * breath, .02 * shift, 0.0)
    p['Chest'] = (-.018 * breath, .012 * shift, -.015 * shift)
    look = math.sin(TAU * t) * window(t, .15, .85, .15)
    p['Head'] = (.04 * math.sin(TAU * t * 2 + .5) * .5, .03 * shift, .22 * look)
    p['gaze'] = (.25 * look, .05 * math.sin(TAU * t * 3))
    p['blink'] = pulse(t, .32, .035) + pulse(t, .80, .03)
    for side, sign in SIDES:
        h = p['hands'][side]
        h['pos'] = h['pos'] + Vector((0, 0, .006 * breath))
        p['ears'][side] = (.05 * pulse(t, .6 if side == 'L' else .64, .05), .02 * breath)
    p['tail'] = [(.03 * breath, .08 * math.sin(TAU * t + i * .5) * (1 + i * .5)) for i in range(3)]
    return p


def apply_feet_contact(sk, p):
    p['pelvis']['off'] = Vector((p['pelvis']['off'].x, p['pelvis']['off'].y,
                                 min(p['pelvis']['off'].z, -stand_drop(sk, p))))
    return p


def wave_pose(sk, t):
    p = idle_pose(sk, t * .5)
    up = smooth(t / .22) * (1 - smooth((t - .78) / .22))
    side, sign = 'R', 1.0
    shoulder_to_hand = Vector((sign * .42 * sk.arm, .12 * sk.arm, .78 * sk.arm))
    shoulder_to_hand.x += sign * .16 * sk.arm * math.sin(TAU * 3 * clamp((t - .18) / .64)) * window(t, .2, .8, .08)
    h = p['hands'][side]
    h['pos'] = h['pos'].lerp(shoulder_to_hand, up)
    h['pole'] = h['pole'].lerp(Vector((sign, 0, -1)), up)
    h['wrist'] = (0.0, .25 * up * math.sin(TAU * 3 * t), 0.0)
    p['Chest'] = offset(p['Chest'], (0.0, -.05 * up, .06 * up))
    p['Head'] = offset(p['Head'], (-.06 * up, .1 * up, .12 * up))
    p['jaw'] = .35 * up
    p['blink'] = max(p['blink'], .3 * up)
    p['ears'] = {'L': (-.08 * up, .05 * up * math.sin(TAU * 4 * t)), 'R': (-.08 * up, -.05 * up * math.sin(TAU * 4 * t))}
    p['tail'] = [(.04 * up, .25 * up * math.sin(TAU * 3 * t + i * .6)) for i in range(3)]
    return p


def listen_pose(sk, t):
    p = idle_pose(sk, t)
    tilt = .14 * smooth(t / .2) * (1 - smooth((t - .85) / .15))
    nod = .1 * (pulse(t, .32, .06) + pulse(t, .68, .06))
    p['Head'] = offset(p['Head'], (nod, tilt, .05))
    p['Chest'] = offset(p['Chest'], (-.04 * tilt / .14, 0.0, 0.0))
    p['ears'] = {s: (-.12 * tilt / .14 + .05 * pulse(t, .5, .05), .02) for s, _ in SIDES}
    p['gaze'] = (.04, .03)
    p['blink'] = pulse(t, .5, .035)
    for side, sign in SIDES:
        h = p['hands'][side]
        h['pos'] = h['pos'].lerp(sk.arm_hand(side, sign, .18, .45, 1.05, inward=.9), .7)
    return p


def talk_pose(sk, t):
    p = idle_pose(sk, t)
    syll = abs(math.sin(TAU * 5 * t)) * (.55 + .45 * math.sin(TAU * 2 * t + 1.3) ** 2)
    pauses = 1 - pulse(t, .48, .06)
    p['jaw'] = .75 * syll * pauses
    p['Head'] = offset(p['Head'], (.05 * math.sin(TAU * 4 * t), .04 * math.sin(TAU * t), .08 * math.sin(TAU * t + .5)))
    gesture = smooth(t / .15) * (1 - smooth((t - .85) / .15))
    side, sign = 'R', 1.0
    h = p['hands'][side]
    open_hand = Vector((sign * .28 * sk.arm, .55 * sk.arm, -.32 * sk.arm))
    open_hand += Vector((sign * .12 * sk.arm * math.sin(TAU * 2 * t), 0, .08 * sk.arm * math.sin(TAU * 4 * t)))
    h['pos'] = h['pos'].lerp(open_hand, gesture)
    h['wrist'] = (-.3 * gesture, .5 * gesture, 0.0)
    other = p['hands']['L']
    other['pos'] = other['pos'].lerp(Vector((-.2 * sk.arm, .4 * sk.arm, -.55 * sk.arm)), .5 * window(t, .3, .7, .1))
    p['ears'] = {s: (-.04 * syll, .02) for s, _ in SIDES}
    p['blink'] = pulse(t, .62, .035)
    return p


def think_pose(sk, t):
    p = idle_pose(sk, t * .5)
    up = smooth(t / .2) * (1 - smooth((t - .82) / .18))
    side, sign = 'R', 1.0
    chin = sk.tail['Jaw'] + Vector((0, .03 * sk.top, -.035 * sk.top))
    h = p['hands'][side]
    h['pos'] = h['pos'].lerp(chin - sk.shoulder[side], up)
    h['pole'] = h['pole'].lerp(Vector((sign * .7, -.1, -1)), up)
    h['wrist'] = (.5 * up, 0.0, 0.0)
    left = p['hands']['L']
    left['pos'] = left['pos'].lerp(sk.arm_hand('L', -1.0, .2, .7, 1.45, inward=1.2), up)
    p['Head'] = offset(p['Head'], (-.12 * up, -.12 * up, -.1 * up + .05 * math.sin(TAU * t)))
    p['gaze'] = (-.3 * up, .32 * up)
    p['Chest'] = offset(p['Chest'], (.03 * up, 0.0, 0.0))
    p['jaw'] = .05
    p['blink'] = pulse(t, .45, .035)
    tap = window(t, .3, .7, .05) * max(0.0, math.sin(TAU * 4 * t))
    p['feet']['L']['pitch'] = .22 * tap
    p['ears'] = {'L': (.06 * up, .08 * up), 'R': (-.04 * up, .02)}
    p['tail'] = [(.05, .15 * math.sin(TAU * t + i * .7)) for i in range(3)]
    return p


def joy_pose(sk, t):
    p = idle_pose(sk, 0.0)
    hops = [(.12, .44), (.5, .82)]
    lift = 0.0
    crouch = 0.0
    for start, end in hops:
        u = (t - start) / (end - start)
        if 0 <= u <= 1:
            lift = max(lift, math.sin(math.pi * u) * .16 * sk.hip_height * (1.0 if start < .3 else .7))
        crouch += pulse(t, start - .02, .07) + pulse(t, end + .02, .07)
    arms = smooth(t / .14) * (1 - smooth((t - .86) / .14))
    p['pelvis']['off'] = p['pelvis']['off'] + Vector((0, 0, lift - .06 * sk.hip_height * crouch))
    for side, sign in SIDES:
        f = p['feet'][side]
        f['lift'] = lift
        f['pitch'] = -.3 * min(1.0, lift / (.05 * sk.hip_height + 1e-6))
        f['toe'] = 0.0
        h = p['hands'][side]
        beat = math.sin(TAU * 3 * t + (0 if side == 'L' else 1.2))
        up = Vector((sign * (.45 + .06 * beat) * sk.arm, .1 * sk.arm, (.78 + .06 * beat) * sk.arm))
        h['pos'] = h['pos'].lerp(up, arms)
        h['pole'] = h['pole'].lerp(Vector((sign, -.2, -1)), arms)
    p['Chest'] = offset(p['Chest'], (.06 * arms, 0.0, 0.0))
    p['Head'] = offset(p['Head'], (-.15 * arms, .08 * math.sin(TAU * 2 * t) * arms, 0.0))
    p['jaw'] = .85 * arms
    p['blink'] = .4 * arms
    p['ears'] = {s: (-.1 * arms, -.04 * arms) for s, _ in SIDES}
    p['tail'] = [(-.2 * arms, .35 * arms * math.sin(TAU * 4 * t + i * .7)) for i in range(3)]
    return p


def surprise_pose(sk, t):
    p = idle_pose(sk, 0.0)
    dip = pulse(t, .08, .07)
    start = smooth((t - .1) / .1)
    hold = start * (1 - .8 * smooth((t - .62) / .38))
    tremble = .015 * math.sin(TAU * 9 * t) * window(t, .25, .6, .05)
    p['pelvis']['off'] = p['pelvis']['off'] + Vector((0, -.05 * sk.hip_height * hold, -.05 * sk.hip_height * dip + .02 * sk.hip_height * hold))
    p['pelvis']['rot'] = (.08 * hold, 0.0, 0.0)
    p['Chest'] = (.12 * hold + tremble, 0.0, 0.0)
    p['Head'] = (.08 * hold, 0.0, 0.0)
    for side, sign in SIDES:
        h = p['hands'][side]
        guard = Vector((sign * .38 * sk.arm, .42 * sk.arm, .1 * sk.arm))
        h['pos'] = h['pos'].lerp(guard, hold)
        h['pole'] = h['pole'].lerp(Vector((sign, -.4, -1)), hold)
        h['wrist'] = (-.6 * hold, 0.0, 0.0)
    p['jaw'] = .9 * hold
    p['lid_open'] = 1.0 * hold
    p['blink'] = pulse(t, .07, .03)
    p['gaze'] = (0.0, .1 * hold)
    p['ears'] = {s: (.16 * hold, -.1 * hold) for s, _ in SIDES}
    p['tail'] = [(-.35 * hold, .03 * math.sin(TAU * 8 * t)) for _ in range(3)]
    return p


def disappointed_pose(sk, t):
    p = idle_pose(sk, 0.0)
    slump = smooth(t / .3) * (1 - smooth((t - .82) / .18))
    sigh = pulse(t, .18, .12)
    p['pelvis']['off'] = p['pelvis']['off'] + Vector((0, 0, -.025 * sk.hip_height * slump + .01 * sk.hip_height * sigh))
    p['Spine'] = (-.08 * slump, 0.0, 0.0)
    p['Chest'] = (-.14 * slump - .05 * sigh, 0.0, 0.0)
    shake = .12 * math.sin(TAU * 2.5 * t) * window(t, .45, .75, .08)
    p['Head'] = (-.28 * slump, 0.0, shake)
    for side, sign in SIDES:
        h = p['hands'][side]
        h['pos'] = h['pos'].lerp(sk.arm_hand(side, sign, .12, .02, .12), slump)
    p['blink'] = .45 * slump + pulse(t, .7, .04) * .55
    p['gaze'] = (0.0, -.2 * slump)
    p['jaw'] = .15 * sigh
    p['ears'] = {s: (.12 * slump, .35 * slump) for s, _ in SIDES}
    p['tail'] = [(.35 * slump, .02 * math.sin(TAU * t)) for _ in range(3)]
    return p


def interact_pose(sk, t):
    p = idle_pose(sk, 0.0)
    reach = smooth((t - .12) / .28) * (1 - smooth((t - .6) / .25))
    hold = smooth((t - .55) / .15) * (1 - smooth((t - .8) / .2))
    press = pulse(t, .44, .06)
    side, sign = 'R', 1.0
    goal = Vector((sign * .08 * sk.top, sk.shoulder[side].y + .78 * sk.arm, sk.shoulder[side].z - .55 * sk.arm + .02 * sk.top * press))
    h = p['hands'][side]
    chest_goal = goal - sk.shoulder[side]
    h['pos'] = h['pos'].lerp(chest_goal, reach)
    holding = Vector((sign * .18 * sk.arm, .5 * sk.arm, -.3 * sk.arm))
    h['pos'] = h['pos'].lerp(holding, hold)
    h['pole'] = h['pole'].lerp(Vector((sign * .8, -.4, -1)), max(reach, hold))
    h['wrist'] = (-.4 * reach, 0.0, 0.0)
    p['pelvis']['rot'] = (-.14 * reach, 0.0, .06 * reach)
    p['Spine'] = (-.08 * reach, 0.0, .04 * reach)
    p['Chest'] = (-.14 * reach, 0.0, .1 * reach)
    p['Head'] = (-.2 * reach + .1 * hold, 0.0, .05 * reach)
    p['gaze'] = (.05 * reach, -.3 * reach)
    p['jaw'] = .2 * hold
    p['blink'] = pulse(t, .9, .03)
    return apply_feet_contact(sk, p)


def turn_pose(sk, t, sign_turn):
    """Shuffle steps in place while the body leans into the turn (node rotates)."""
    p = idle_pose(sk, 0.0)
    lead = sign_turn
    p['Head'] = (0.0, .04 * lead, .32 * lead)
    p['gaze'] = (.35 * lead, 0.0)
    p['Chest'] = (0.0, -.03 * lead, .14 * lead)
    p['Spine'] = (0.0, 0.0, .06 * lead)
    p['pelvis']['rot'] = (0.0, .03 * lead * math.sin(TAU * t), .05 * lead)
    for side, sign in SIDES:
        phase = (t + (0 if (side == 'L') == (lead > 0) else .5)) % 1
        step = math.sin(math.pi * clamp(phase / .45)) if phase < .45 else 0.0
        f = p['feet'][side]
        f['lift'] = .08 * sk.hip_height * step
        f['yaw'] += lead * .12 * step
        f['y'] += .03 * sk.hip_height * step * sign * lead
        f['pitch'] = -.12 * step
    p['pelvis']['off'] = p['pelvis']['off'] + Vector((0, 0, .012 * sk.hip_height * math.sin(2 * TAU * t)))
    p['tail'] = [(0.0, -.18 * lead * (1 + i * .5)) for i in range(3)]
    p['ears'] = {s: (-.05, .03) for s, _ in SIDES}
    return p


def seated(sk, seat_height=None):
    """Sitting on a seat at knee height; thighs level, feet planted ahead."""
    p = neutral(sk)
    seat = seat_height if seat_height is not None else sk.ankle_height + .92 * min(sk.leg_b.values())
    back = -.25 * min(sk.leg_a.values())
    p['pelvis']['off'] = Vector((0, back, seat - sk.hip_height))
    p['pelvis']['rot'] = (.08, 0.0, 0.0)
    p['Spine'] = (-.06, 0.0, 0.0)
    p['Chest'] = (-.04, 0.0, 0.0)
    for side, sign in SIDES:
        f = p['feet'][side]
        f['x'] = sk.hip[side].x * 1.25
        f['y'] = sk.hip[side].y + back + .93 * sk.leg_a[side]
        h = p['hands'][side]
        knee = Vector((sk.hip[side].x * 1.1, sk.hip[side].y + back + .7 * sk.leg_a[side], seat + .06 * sk.hip_height))
        h['pos'] = knee - sk.shoulder[side]
        h['pole'] = Vector((sign * .6, -.6, -.6))
        h['space'] = 'chest'
    p['_seat'] = seat
    return p


def sit_idle_pose(sk, t):
    p = seated(sk)
    breath = math.sin(TAU * 2 * t)
    p['Chest'] = offset(p['Chest'], (-.02 * breath, 0.0, .03 * math.sin(TAU * t)))
    look = math.sin(TAU * t) * window(t, .15, .85, .15)
    p['Head'] = (0.0, .03 * math.sin(TAU * t), .2 * look)
    p['gaze'] = (.22 * look, 0.0)
    p['blink'] = pulse(t, .4, .035)
    swing = .12 * math.sin(TAU * 2 * t)
    p['feet']['R']['lift'] = .02 * sk.hip_height * max(0.0, swing / .12)
    p['tail'] = [(.0, .06 * math.sin(TAU * t + i * .5)) for i in range(3)]
    return p


def transition(sk, t, start, end, lean=-.32):
    """Sit down / stand up: lean forward while the pelvis travels."""
    u = smoother(t)
    p = mix(start, end, u)
    over = math.sin(math.pi * clamp(t))
    p['Chest'] = offset(p['Chest'], (lean * over, 0.0, 0.0))
    p['Spine'] = offset(p['Spine'], (lean * .5 * over, 0.0, 0.0))
    p['Head'] = offset(p['Head'], (-lean * .6 * over, 0.0, 0.0))
    for side, sign in SIDES:
        h = p['hands'][side]
        h['pos'] = h['pos'] + Vector((0, .2 * sk.arm * over, .05 * sk.arm * over))
    p['blink'] = pulse(t, .5, .05)
    return p


def drive_pose(sk, t, seat_shift=Vector((0, 0, 0))):
    p = seated(sk)
    p['pelvis']['off'] = p['pelvis']['off'] + seat_shift
    steer = .5 * math.sin(TAU * t) + .25 * math.sin(TAU * 2 * t + .7)
    for side, sign in SIDES:
        h = p['hands'][side]
        # wheel centre in front of the chest, grips at both sides of its rim
        centre = Vector((-sk.shoulder[side].x, .62 * sk.arm, -.3 * sk.arm))
        grip = Matrix.Rotation(-.35 * steer, 3, 'Y') @ Vector((sign * .62 * abs(sk.shoulder[side].x), 0, 0))
        h['pos'] = centre + grip
        h['pole'] = Vector((sign, -.3, -.8))
        p['feet'][side]['y'] += .1 * sk.leg_a[side]
    p['Head'] = (-.04, .05 * steer, .1 * steer)
    p['Chest'] = offset(p['Chest'], (0.0, .04 * steer, .05 * steer))
    p['gaze'] = (.15 * steer, 0.0)
    p['blink'] = pulse(t, .6, .035)
    p['tail'] = [(.0, .05 * math.sin(TAU * t + i)) for i in range(3)]
    return p


def stop_pose(sk, t, walk_pose_at):
    """Plant the leading foot, bring the trailing foot alongside, settle."""
    start = walk_pose_at(0.0)
    end = idle_pose(sk, 0.0)
    p = mix(start, end, smoother(t / .75))
    # trailing (right) foot: one closing step with a real lift
    f = p['feet']['R']
    step = clamp(t / .55)
    f['lift'] = math.sin(math.pi * step) * .09 * sk.hip_height
    f['pitch'] = mix(start['feet']['R']['pitch'], 0.0, smooth(step)) + .1 * math.sin(math.pi * step)
    left = p['feet']['L']
    settle_left = smooth(clamp(t / .3))
    for key in ('x', 'pitch', 'toe', 'lift'):
        left[key] = mix(start['feet']['L'][key], end['feet']['L'][key], settle_left)
    left['y'] = mix(start['feet']['L']['y'], end['feet']['L']['y'], smoother(clamp((t - .35) / .5)))
    settle = pulse(t, .62, .18)
    p['pelvis']['off'] = p['pelvis']['off'] + Vector((0, .03 * sk.hip_height * settle, -.03 * sk.hip_height * settle))
    p['Chest'] = offset(p['Chest'], (-.06 * settle, 0.0, 0.0))
    p['Head'] = offset(p['Head'], (.05 * settle, 0.0, 0.0))
    p['ears'] = {s: (.12 * settle, .04 * settle) for s, _ in SIDES}
    p['tail'] = [(.0, .18 * settle * math.sin(TAU * 2 * t + i * .6)) for i in range(3)]
    return p


def vehicle_pose(sk, t, entering=True, side_offset=None):
    """Generic side entry: stand beside the seat (left), step across, sit down."""
    side_offset = side_offset if side_offset is not None else .55 * sk.leg
    beside = idle_pose(sk, 0.0)
    beside['pelvis']['off'] = beside['pelvis']['off'] + Vector((-side_offset, 0, 0))
    for side, _sign in SIDES:
        beside['feet'][side]['x'] -= side_offset
    beside = apply_feet_contact(sk, beside)
    seat = drive_pose(sk, 0.0)
    u = t if entering else 1 - t
    p = mix(beside, seat, smoother(clamp((u - .2) / .65)))
    # the inner (right) foot steps in first, the outer foot follows
    for side, delay in (('R', .1), ('L', .3)):
        v = clamp((u - delay) / .35)
        step = math.sin(math.pi * v)
        f = p['feet'][side]
        target = seat['feet'][side]
        f['x'] = mix(beside['feet'][side]['x'], target['x'], smoother(v))
        f['y'] = mix(beside['feet'][side]['y'], target['y'], smoother(v))
        f['lift'] = .22 * sk.hip_height * step
        f['pitch'] = -.25 * step
    duck = math.sin(math.pi * clamp((u - .15) / .7))
    p['Chest'] = offset(p['Chest'], (-.22 * duck, 0.0, .1 * duck))
    p['Head'] = offset(p['Head'], (.12 * duck, 0.0, -.15 * duck))
    p['blink'] = pulse(u, .5, .04)
    return p
