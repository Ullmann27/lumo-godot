"""Signed-distance sculpting kit for the LUMO rival drivers (numpy only).

Taken over from the earlier, not merged figuren branch; the mesher is sparse now.

Shapes are blended with smooth unions/subtractions on a sparse-updated voxel
field and extracted with naive surface nets plus a Newton projection onto the
exact iso-surface. Everything is local and deterministic; no external
generator, model or download is involved.
"""
from __future__ import annotations

import math

import numpy as np

F = np.float32


def _v(x):
    return np.asarray(x, dtype=F)


def normalize(v):
    v = np.asarray(v, dtype=np.float64)
    return v / max(1e-12, float(np.linalg.norm(v)))


def frame_from(forward, up=(0.0, 0.0, 1.0)):
    """Rows: right, forward, up of an orthonormal frame (world -> local)."""
    f = normalize(forward)
    u = np.asarray(up, dtype=np.float64)
    r = np.cross(f, u)
    if np.linalg.norm(r) < 1e-6:
        r = np.cross(f, (0.0, 1.0, 0.0))
    r = normalize(r)
    u = normalize(np.cross(r, f))
    return np.stack([r, f, u]).astype(F)


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=F)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=F)


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=F)


# ---------------------------------------------------------------- primitives
class Shape:
    """A signed distance function on (...,3) float32 arrays with a bounding box."""

    lo: np.ndarray
    hi: np.ndarray

    def __call__(self, p):
        raise NotImplementedError


class Ellipsoid(Shape):
    def __init__(self, c, r, rot=None):
        self.c = _v(c)
        self.r = _v(r)
        self.rot = None if rot is None else _v(rot)  # world->local rows
        m = float(np.max(self.r))
        self.lo, self.hi = self.c - m, self.c + m

    def __call__(self, p):
        q = p - self.c
        if self.rot is not None:
            q = q @ self.rot.T
        k0 = np.linalg.norm(q / self.r, axis=-1)
        k1 = np.linalg.norm(q / (self.r * self.r), axis=-1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


class Sphere(Shape):
    def __init__(self, c, r):
        self.c = _v(c)
        self.r = float(r)
        self.lo, self.hi = self.c - self.r, self.c + self.r

    def __call__(self, p):
        return np.linalg.norm(p - self.c, axis=-1) - self.r


class RoundCone(Shape):
    """Capsule with linearly varying radius (exact, Inigo Quilez)."""

    def __init__(self, a, b, ra, rb, squash=None):
        self.a, self.b = _v(a), _v(b)
        self.ra, self.rb = float(ra), float(rb)
        # optional (axis, factor): scales distances across one direction
        self.squash = squash
        m = max(self.ra, self.rb)
        self.lo = np.minimum(self.a, self.b) - m
        self.hi = np.maximum(self.a, self.b) + m

    def __call__(self, p):
        a, b, r1, r2 = self.a, self.b, self.ra, self.rb
        if self.squash is not None:
            axis, factor = self.squash
            axis = _v(normalize(axis))
            q = p - a
            along = q @ axis
            p = p + (np.float32(1.0 / factor) - 1.0) * along[..., None] * axis
        ba = b - a
        l2 = float(ba @ ba)
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - a
        y = pa @ ba
        z = y - l2
        x2v = pa * l2 - y[..., None] * ba
        x2 = np.einsum('...i,...i->...', x2v, x2v)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        d_end = np.sqrt(x2 + z2) * il2 - r2
        d_start = np.sqrt(x2 + y2) * il2 - r1
        d_mid = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
        out = np.where(np.sign(y) * a2 * y2 < k, d_start, d_mid)
        out = np.where(np.sign(z) * a2 * z2 > k, d_end, out)
        if self.squash is not None:
            out = out * np.float32(min(1.0, self.squash[1]))
        return out.astype(F)


class Tube(Shape):
    """Polyline of round cones (hard union keeps it a single smooth tube)."""

    def __init__(self, points, radii, squash=None):
        pts = [_v(x) for x in points]
        rad = list(radii) if isinstance(radii, (list, tuple)) else [radii] * len(pts)
        self.segments = [RoundCone(pts[i], pts[i + 1], rad[i], rad[i + 1], squash) for i in range(len(pts) - 1)]
        self.lo = np.min([s.lo for s in self.segments], axis=0)
        self.hi = np.max([s.hi for s in self.segments], axis=0)

    def __call__(self, p):
        out = None
        for s in self.segments:
            # only evaluate inside the segment's own box when large inputs
            d = s(p)
            out = d if out is None else np.minimum(out, d)
        return out


def catmull(points, n):
    P = [np.asarray(p, dtype=np.float64) for p in points]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    segs = len(P) - 3
    for i in range(segs):
        p0, p1, p2, p3 = P[i:i + 4]
        for j in range(n if i < segs - 1 else n + 1):
            t = j / n
            out.append(.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return np.array(out)


class Leaf(Shape):
    """Smooth flattened blade along a spline: width/thickness profiles over t.

    `facing` is the direction the flat side looks at (e.g. forward for ears)."""

    def __init__(self, ctrl, widths, thick, facing, samples=8):
        self.c = catmull(ctrl, samples).astype(F)
        m = len(self.c)
        tt = np.linspace(0, 1, len(widths))
        ts = np.linspace(0, 1, m)
        self.w = np.interp(ts, tt, widths).astype(F)
        self.th = np.interp(ts, np.linspace(0, 1, len(thick)), thick).astype(F)
        T = np.gradient(self.c.astype(np.float64), axis=0)
        T /= np.linalg.norm(T, axis=1, keepdims=True)
        f = np.asarray(facing, dtype=np.float64)
        Nf = f - T * (T @ f)[:, None]
        Nf /= np.linalg.norm(Nf, axis=1, keepdims=True)
        self.T, self.Nf = T.astype(F), Nf.astype(F)
        self.B = np.cross(T, Nf).astype(F)
        r = float(max(self.w.max(), self.th.max()))
        self.lo = self.c.min(0) - r
        self.hi = self.c.max(0) + r

    def __call__(self, p):
        shp = p.shape[:-1]
        q = p.reshape(-1, 3)
        best = np.full(len(q), np.inf, dtype=F)
        out = np.full(len(q), 1.0, dtype=F)
        c = self.c
        for i in range(len(c) - 1):
            a, b = c[i], c[i + 1]
            ba = b - a
            t = np.clip(((q - a) @ ba) / float(ba @ ba), 0, 1)
            pt = a + t[:, None] * ba
            dist = np.linalg.norm(q - pt, axis=1)
            better = dist < best
            if not better.any():
                continue
            qq = q[better] - pt[better]
            tb = t[better][:, None]
            B = self.B[i] * (1 - tb) + self.B[i + 1] * tb
            Nf = self.Nf[i] * (1 - tb) + self.Nf[i + 1] * tb
            w = self.w[i] * (1 - t[better]) + self.w[i + 1] * t[better]
            th = self.th[i] * (1 - t[better]) + self.th[i + 1] * t[better]
            u = np.sum(qq * B, axis=1) / np.maximum(w, 1e-5)
            v = np.sum(qq * Nf, axis=1) / np.maximum(th, 1e-5)
            along = np.sum(qq * self.T[i], axis=1)
            d = (np.sqrt(u * u + v * v) - 1.0) * np.minimum(w, th)
            # caps beyond the first/last sample
            if i == 0:
                d = np.maximum(d, np.where(t[better] <= 0, -along - .0, -1))
            if i == len(c) - 2:
                d = np.maximum(d, np.where(t[better] >= 1, along, -1))
            best[better] = dist[better]
            out[better] = d
        return out.reshape(shp)


class RoundBox(Shape):
    def __init__(self, c, half, radius, rot=None):
        self.c = _v(c)
        self.half = _v(half)
        self.radius = float(radius)
        self.rot = None if rot is None else _v(rot)
        m = float(np.linalg.norm(self.half)) + self.radius
        self.lo, self.hi = self.c - m, self.c + m

    def __call__(self, p):
        q = p - self.c
        if self.rot is not None:
            q = q @ self.rot.T
        q = np.abs(q) - self.half
        outside = np.linalg.norm(np.maximum(q, 0.0), axis=-1)
        inside = np.minimum(np.max(q, axis=-1), 0.0)
        return outside + inside - self.radius


class Torus(Shape):
    def __init__(self, c, big, small, rot=None, squash_z=1.0):
        self.c = _v(c)
        self.big, self.small = float(big), float(small)
        self.rot = None if rot is None else _v(rot)
        self.sz = float(squash_z)
        m = self.big + self.small
        self.lo, self.hi = self.c - m, self.c + m

    def __call__(self, p):
        q = p - self.c
        if self.rot is not None:
            q = q @ self.rot.T
        xy = np.sqrt(q[..., 0] ** 2 + q[..., 1] ** 2) - self.big
        return np.sqrt(xy * xy + (q[..., 2] / self.sz) ** 2) - self.small


class Plane(Shape):
    """Half-space n.p <= d (inside) restricted to a box for sparse updates."""

    def __init__(self, n, d, lo, hi):
        self.n = _v(normalize(n))
        self.d = float(d)
        self.lo, self.hi = _v(lo), _v(hi)

    def __call__(self, p):
        return p @ self.n - self.d


class Fn(Shape):
    """Arbitrary closure with explicit bounds."""

    def __init__(self, fn, lo, hi):
        self.fn = fn
        self.lo, self.hi = _v(lo), _v(hi)

    def __call__(self, p):
        return self.fn(p).astype(F)


# ---------------------------------------------------------------- operators
def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- noise
def _hash3(ix, iy, iz, seed):
    h = (ix.astype(np.int64) * 73856093) ^ (iy.astype(np.int64) * 19349663) ^ (iz.astype(np.int64) * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return ((h & 0xFFFFFF).astype(F) / F(0xFFFFFF))


def value_noise(p, seed=0):
    """Smooth 3D value noise in [0,1]."""
    p = np.asarray(p, dtype=F)
    i = np.floor(p)
    f = p - i
    u = f * f * (3.0 - 2.0 * f)
    ix, iy, iz = (i[..., 0].astype(np.int64), i[..., 1].astype(np.int64), i[..., 2].astype(np.int64))
    out = 0.0
    for dx in (0, 1):
        wx = u[..., 0] if dx else 1.0 - u[..., 0]
        for dy in (0, 1):
            wy = u[..., 1] if dy else 1.0 - u[..., 1]
            for dz in (0, 1):
                wz = u[..., 2] if dz else 1.0 - u[..., 2]
                out = out + wx * wy * wz * _hash3(ix + dx, iy + dy, iz + dz, seed)
    return out


def fbm(p, octaves=4, seed=0, lacunarity=2.03, gain=0.5):
    total = 0.0
    amp = 1.0
    norm = 0.0
    q = np.asarray(p, dtype=F)
    for o in range(octaves):
        total = total + amp * value_noise(q, seed + 17 * o)
        norm += amp
        amp *= gain
        q = q * lacunarity
    return total / norm


# ---------------------------------------------------------------- field
class Field:
    def __init__(self, lo, hi, voxel):
        self.lo = _v(lo)
        self.h = float(voxel)
        self.shape = tuple(int(math.ceil((hi[i] - lo[i]) / voxel)) + 1 for i in range(3))
        self.d = np.full(self.shape, 1.0, dtype=F)
        self.min_pad = 0.0

    def _slices(self, lo, hi, pad):
        a = np.floor((np.asarray(lo) - pad - self.lo) / self.h).astype(int)
        b = np.ceil((np.asarray(hi) + pad - self.lo) / self.h).astype(int) + 1
        a = np.clip(a, 0, np.array(self.shape))
        b = np.clip(b, 0, np.array(self.shape))
        if np.any(b <= a):
            return None
        return tuple(slice(int(a[i]), int(b[i])) for i in range(3))

    def _points(self, sl):
        axes = [self.lo[i] + self.h * np.arange(sl[i].start, sl[i].stop, dtype=F) for i in range(3)]
        X, Y, Z = np.meshgrid(*axes, indexing='ij')
        return np.stack([X, Y, Z], axis=-1)

    def apply(self, shape, op='union', k=0.0, pad=None):
        pad = max(k + 2 * self.h, self.min_pad) if pad is None else pad
        if op == 'intersect':
            sl = tuple(slice(0, n) for n in self.shape)
        else:
            sl = self._slices(shape.lo, shape.hi, pad)
            if sl is None:
                return
        p = self._points(sl)
        v = shape(p).astype(F)
        cur = self.d[sl]
        if op == 'union':
            self.d[sl] = smin(cur, v, k)
        elif op == 'subtract':
            self.d[sl] = smax(cur, -v, k)
        elif op == 'intersect':
            self.d[sl] = smax(cur, v, k)
        else:
            raise ValueError(op)

    def union(self, shape, k=0.0):
        self.apply(shape, 'union', k)

    def subtract(self, shape, k=0.0):
        self.apply(shape, 'subtract', k)

    def intersect(self, shape, k=0.0):
        self.apply(shape, 'intersect', k)

    def blurred(self, radius, clamp=.02):
        """Copy with a separable box blur (three passes ~ gaussian)."""
        out = Field.__new__(Field)
        out.lo, out.h, out.shape = self.lo, self.h, self.shape
        out.min_pad = self.min_pad
        d = np.clip(self.d, -clamp, clamp).astype(np.float32)
        r = radius
        for _ in range(2):
            for ax in range(3):
                pad = [(0, 0)] * 3
                pad[ax] = (r + 1, r)
                dp = np.pad(d, pad, mode='constant', constant_values=clamp)
                c = np.cumsum(dp, axis=ax, dtype=np.float64)
                n = d.shape[ax]
                hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=ax)
                lo = np.take(c, np.arange(0, n), axis=ax)
                d = ((hi - lo) / (2 * r + 1)).astype(np.float32)
        out.d = d
        return out

    def copy(self):
        out = Field.__new__(Field)
        out.lo, out.h, out.shape = self.lo, self.h, self.shape
        out.min_pad = self.min_pad
        out.d = self.d.copy()
        return out

    def sample(self, pts):
        """Trilinear interpolation of the field at world points (N,3)."""
        g = (np.asarray(pts, dtype=np.float64) - self.lo) / self.h
        n = np.array(self.shape) - 1
        g = np.clip(g, 0, n - 1e-6)
        i = np.floor(g).astype(int)
        f = g - i
        d = self.d
        out = np.zeros(len(g))
        for dx in (0, 1):
            wx = f[:, 0] if dx else 1 - f[:, 0]
            for dy in (0, 1):
                wy = f[:, 1] if dy else 1 - f[:, 1]
                for dz in (0, 1):
                    wz = f[:, 2] if dz else 1 - f[:, 2]
                    out += wx * wy * wz * d[i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz]
        return out

    def gradient(self, pts):
        e = self.h * 0.5
        out = np.zeros((len(pts), 3))
        for k in range(3):
            o = np.zeros(3)
            o[k] = e
            out[:, k] = (self.sample(pts + o) - self.sample(pts - o)) / (2 * e)
        return out

    def mesh(self, newton=3):
        """Sparse naive surface nets. Returns float64 verts (N,3) and quads (M,4).

        Only cells touched by a sign change are stored, so a fine voxel grid
        for a whole seated character stays within a few hundred megabytes.
        """
        d = self.d
        nx, ny, nz = d.shape
        cx, cy, cz = nx - 1, ny - 1, nz - 1
        keys = []
        points = []
        edges = []
        for axis in range(3):
            sl0 = [slice(None)] * 3
            sl1 = [slice(None)] * 3
            sl0[axis] = slice(0, -1)
            sl1[axis] = slice(1, None)
            a = d[tuple(sl0)]
            b = d[tuple(sl1)]
            change = (a < 0) != (b < 0)
            idx = np.argwhere(change)
            if len(idx) == 0:
                continue
            da = a[change].astype(np.float64)
            db = b[change].astype(np.float64)
            t = da / (da - db)
            pts = idx.astype(np.float64)
            pts[:, axis] += t
            others = [o for o in range(3) if o != axis]
            for o1 in (0, -1):
                for o2 in (0, -1):
                    c = idx.copy()
                    c[:, others[0]] += o1
                    c[:, others[1]] += o2
                    ok = np.all((c >= 0) & (c < np.array([cx, cy, cz])), axis=1)
                    keys.append((c[ok, 0] * cy + c[ok, 1]) * cz + c[ok, 2])
                    points.append(pts[ok])
            inner = np.ones(len(idx), dtype=bool)
            for o in others:
                inner &= (idx[:, o] >= 1) & (idx[:, o] <= np.array([cx, cy, cz])[o] - 1)
            e = idx[inner]
            flip = (a[change][inner] < 0) if axis == 1 else (a[change][inner] >= 0)
            c00 = e.copy(); c00[:, others[0]] -= 1; c00[:, others[1]] -= 1
            c10 = e.copy(); c10[:, others[1]] -= 1
            c11 = e.copy()
            c01 = e.copy(); c01[:, others[0]] -= 1
            edges.append(([(c[:, 0] * cy + c[:, 1]) * cz + c[:, 2] for c in (c00, c10, c11, c01)], flip))
        keys = np.concatenate(keys)
        points = np.concatenate(points)
        unique, inverse = np.unique(keys, return_inverse=True)
        counts = np.bincount(inverse).astype(np.float64)
        verts = np.stack([np.bincount(inverse, weights=points[:, k]) for k in range(3)], axis=1) / counts[:, None]
        verts = self.lo + verts * self.h
        faces = []
        for corners, flip in edges:
            q = np.stack([np.searchsorted(unique, c) for c in corners], axis=1)
            q[flip] = q[flip][:, ::-1]
            faces.append(q)
        faces = np.concatenate(faces) if faces else np.zeros((0, 4), dtype=np.int64)
        for _ in range(newton):
            val = self.sample(verts)
            g = self.gradient(verts)
            gg = np.maximum((g * g).sum(1), 1e-9)
            step = (val / gg)[:, None] * g
            lim = self.h * 0.75
            n = np.linalg.norm(step, axis=1, keepdims=True)
            step = np.where(n > lim, step * lim / np.maximum(n, 1e-12), step)
            verts = verts - step
        return verts, faces


def build(shapes_ops, lo, hi, voxel, newton=3):
    """shapes_ops: iterable of (op, shape, k)."""
    field = Field(lo, hi, voxel)
    for op, shape, k in shapes_ops:
        field.apply(shape, op, k)
    return field
