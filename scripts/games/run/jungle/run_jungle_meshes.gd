extends RefCounted
## Original low-poly models for the Dschungelherz adventure, built in code with
## vertex colours (no image files, no foreign assets). Vertex alpha carries how
## much a vertex sways in the wind: 0 at the root, 1 at the tip of a leaf.
## Every builder is deterministic for a given seed.

const UP := Vector3.UP


class Kit:
	extends RefCounted
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color = Color(-1, 0, 0), cc: Color = Color(-1, 0, 0)) -> void:
		var normal: Vector3 = (b - a).cross(c - a)
		if normal.length_squared() < 1e-12:
			return
		normal = -normal.normalized()
		if cb.r < 0.0:
			cb = ca
		if cc.r < 0.0:
			cc = ca
		for pair in [[a, ca], [b, cb], [c, cc]]:
			st.set_normal(normal)
			st.set_color(pair[1])
			st.add_vertex(pair[0])

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color = Color(-1, 0, 0), cc: Color = Color(-1, 0, 0), cd: Color = Color(-1, 0, 0)) -> void:
		if cb.r < 0.0:
			cb = ca
		if cc.r < 0.0:
			cc = ca
		if cd.r < 0.0:
			cd = ca
		tri(a, b, c, ca, cb, cc)
		tri(a, c, d, ca, cc, cd)

	## Smooth-shaded vertex (for tubes and blobs).
	func vert(at: Vector3, normal: Vector3, colour: Color) -> void:
		st.set_normal(normal)
		st.set_color(colour)
		st.add_vertex(at)

	func mesh() -> ArrayMesh:
		return st.commit()


static func _shade(colour: Color, amount: float) -> Color:
	var result: Color = colour.darkened(amount) if amount > 0.0 else colour.lightened(-amount)
	result.a = colour.a
	return result


static func _with_alpha(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, alpha)


## A tube along `points` with one radius per point; smooth normals.
static func tube(kit: Kit, points: Array, radii: Array, sides: int, colours: Array, cap: bool = false) -> void:
	var rings: Array = []
	for index in range(points.size()):
		var here: Vector3 = points[index]
		var along: Vector3 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var side: Vector3 = along.cross(Vector3.FORWARD if absf(along.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var other: Vector3 = along.cross(side).normalized()
		var ring: Array = []
		for k in range(sides):
			var angle: float = TAU * float(k) / float(sides)
			var normal: Vector3 = (side * cos(angle) + other * sin(angle)).normalized()
			ring.append([here + normal * float(radii[index]), normal])
		rings.append(ring)
	for index in range(rings.size() - 1):
		for k in range(sides):
			var n: int = (k + 1) % sides
			var a: Array = rings[index][k]
			var b: Array = rings[index][n]
			var c: Array = rings[index + 1][n]
			var d: Array = rings[index + 1][k]
			var ca: Color = colours[index]
			var cc: Color = colours[index + 1]
			kit.vert(a[0], a[1], ca)
			kit.vert(c[0], c[1], cc)
			kit.vert(b[0], b[1], ca)
			kit.vert(a[0], a[1], ca)
			kit.vert(d[0], d[1], cc)
			kit.vert(c[0], c[1], cc)
	if cap:
		var last: Vector3 = points[points.size() - 1]
		var ring: Array = rings[rings.size() - 1]
		for k in range(sides):
			kit.tri(last, ring[(k + 1) % sides][0], ring[k][0], colours[colours.size() - 1])


## Displaced sphere: rocks, bushes, canopy clumps, moss. Flat-shaded facets read well small.
static func blob(kit: Kit, centre: Vector3, size: Vector3, colour: Color, rng: RandomNumberGenerator, rough: float = 0.18, rings: int = 5, segments: int = 8, sway: float = 0.0, flat_bottom: bool = false) -> void:
	var grid: Array = []
	for r in range(rings + 1):
		var v: float = float(r) / float(rings)
		var phi: float = PI * v
		var row: Array = []
		for k in range(segments):
			var theta: float = TAU * float(k) / float(segments)
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var bump: float = 1.0 + rng.randf_range(-rough, rough) if r > 0 and r < rings else 1.0
			var p: Vector3 = dir * size * bump
			if flat_bottom and p.y < -size.y * 0.25:
				p.y = -size.y * 0.25
			row.append(centre + p)
		grid.append(row)
	for r in range(rings):
		for k in range(segments):
			var n: int = (k + 1) % segments
			var a: Vector3 = grid[r][k]
			var b: Vector3 = grid[r][n]
			var c: Vector3 = grid[r + 1][n]
			var d: Vector3 = grid[r + 1][k]
			var shade: float = lerpf(-0.12, 0.22, float(r) / float(rings)) + rng.randf_range(-0.05, 0.05)
			var col: Color = _with_alpha(_shade(colour, shade), sway * (1.0 - float(r) / float(rings)))
			var col2: Color = _with_alpha(_shade(colour, shade + 0.04), sway * (1.0 - float(r + 1) / float(rings)))
			if r == 0:
				kit.tri(a, c, d, col, col2, col2)
			elif r == rings - 1:
				kit.tri(a, b, d, col, col, col2)
			else:
				kit.quad(a, b, c, d, col, col, col2, col2)


# ------------------------------------------------------------------ plants

## A fern: fronds arching out from the centre, each a spine with leaflets.
static func fern(seed: int, fronds: int = 7, reach: float = 1.4, colour: Color = Color("2f8f3e")) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for f in range(fronds):
		var angle: float = TAU * float(f) / float(fronds) + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side: Vector3 = out.cross(UP).normalized()
		var length: float = reach * rng.randf_range(0.75, 1.15)
		var lift: float = rng.randf_range(0.7, 1.1)
		var tint: Color = _shade(colour, rng.randf_range(-0.12, 0.15))
		var segments: int = 6
		var previous: Vector3 = Vector3.ZERO
		for k in range(1, segments + 1):
			var u: float = float(k) / float(segments)
			var point: Vector3 = out * length * u + UP * length * lift * (u * 1.1 - u * u * 0.95)
			var width: float = length * 0.22 * (1.0 - u * 0.75)
			var c0: Color = _with_alpha(_shade(tint, 0.18 - u * 0.25), u - 1.0 / float(segments))
			var c1: Color = _with_alpha(_shade(tint, -u * 0.18), u)
			kit.quad(previous - side * width * 0.15, previous + side * width * 0.15, point + side * 0.02, point - side * 0.02, c0, c0, c1, c1)
			# Leaflets to both sides, drooping a little.
			for sign in [-1.0, 1.0]:
				var tip: Vector3 = previous.lerp(point, 0.5) + side * sign * width - UP * width * 0.25
				kit.tri(previous, point, tip, c0, c1, _with_alpha(_shade(tint, -0.1), u))
			previous = point
	return kit.mesh()


## Big glossy leaves (elephant ears) on stems: the foreground plant of the jungle.
static func broadleaf(seed: int, leaves: int = 5, size: float = 1.3, colour: Color = Color("2c8a47")) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for l in range(leaves):
		var angle: float = TAU * float(l) / float(leaves) + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side: Vector3 = out.cross(UP).normalized()
		var stem_top: Vector3 = out * size * 0.35 + UP * size * rng.randf_range(0.6, 1.1)
		var stem_col := Color("4a7a2a", 0.0)
		kit.quad(Vector3.ZERO - side * 0.03, Vector3.ZERO + side * 0.03, stem_top + side * 0.02, stem_top - side * 0.02, stem_col, stem_col, Color("4a7a2a", 0.5), Color("4a7a2a", 0.5))
		var leaf_len: float = size * rng.randf_range(0.8, 1.2)
		var tint: Color = _shade(colour, rng.randf_range(-0.1, 0.15))
		var droop: float = rng.randf_range(0.2, 0.5)
		var steps: int = 5
		var spine: Array = []
		for k in range(steps + 1):
			var u: float = float(k) / float(steps)
			spine.append(stem_top + out * leaf_len * u + UP * leaf_len * (0.25 * u - droop * u * u))
		for k in range(steps):
			var u0: float = float(k) / float(steps)
			var u1: float = float(k + 1) / float(steps)
			var w0: float = leaf_len * 0.42 * sin(PI * clampf(u0 * 0.95 + 0.05, 0.0, 1.0))
			var w1: float = leaf_len * 0.42 * sin(PI * clampf(u1 * 0.95 + 0.05, 0.0, 1.0))
			var a: Vector3 = spine[k]
			var b: Vector3 = spine[k + 1]
			var mid: Color = _with_alpha(_shade(tint, -0.25), 0.5 + u0 * 0.5)
			var edge0: Color = _with_alpha(_shade(tint, 0.12), 0.6 + u0 * 0.4)
			var edge1: Color = _with_alpha(_shade(tint, 0.12), 0.6 + u1 * 0.4)
			var cup0: Vector3 = UP * w0 * 0.25
			var cup1: Vector3 = UP * w1 * 0.25
			kit.quad(a, a + side * w0 + cup0, b + side * w1 + cup1, b, mid, edge0, edge1, mid)
			kit.quad(a, b, b - side * w1 + cup1, a - side * w0 + cup0, mid, mid, edge1, edge0)
	return kit.mesh()


static func grass(seed: int, blades: int = 9, height: float = 0.7, colour: Color = Color("5aa83c")) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for b in range(blades):
		var angle: float = rng.randf() * TAU
		var at := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.0, 0.35)
		var lean := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.1, 0.4)
		var side := Vector3(-sin(angle), 0.0, cos(angle)) * 0.05
		var top: Vector3 = at + lean + UP * height * rng.randf_range(0.6, 1.2)
		var base: Color = _with_alpha(_shade(colour, 0.3), 0.0)
		kit.tri(at - side, at + side, top, base, base, _with_alpha(_shade(colour, rng.randf_range(-0.25, 0.0)), 1.0))
	return kit.mesh()


static func flower(seed: int, colour: Color) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var top := Vector3(rng.randf_range(-0.1, 0.1), 0.55, rng.randf_range(-0.1, 0.1))
	var stem := Color("3f7d2c", 0.0)
	kit.quad(Vector3(-0.02, 0, 0), Vector3(0.02, 0, 0), top + Vector3(0.015, 0, 0), top - Vector3(0.015, 0, 0), stem, stem, Color("3f7d2c", 0.6), Color("3f7d2c", 0.6))
	for p in range(5):
		var angle: float = TAU * float(p) / 5.0
		var out := Vector3(cos(angle), 0.25, sin(angle)) * 0.16
		var side := Vector3(-sin(angle), 0.0, cos(angle)) * 0.07
		kit.quad(top, top + out + side, top + out * 1.6, top + out - side, _with_alpha(colour.lightened(0.3), 0.8), _with_alpha(colour, 0.9), _with_alpha(colour, 1.0), _with_alpha(colour, 0.9))
	blob(kit, top + Vector3(0, 0.03, 0), Vector3.ONE * 0.05, Color("ffe066", 0.8), rng, 0.0, 3, 5)
	return kit.mesh()


## A tropical tree: tapered trunk with buttress roots and layered leafy crowns.
static func tree(seed: int, height: float, crowns: int = 4, bark: Color = Color("6b4a31"), leaf: Color = Color("2c8a47")) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var radius: float = clampf(height * 0.045, 0.35, 1.6)
	var points: Array = []
	var radii: Array = []
	var colours: Array = []
	var bend := Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * height * 0.04
	for k in range(8):
		var u: float = float(k) / 7.0
		points.append(UP * height * u + bend * u * u)
		radii.append(radius * lerpf(1.35, 0.5, u) * (1.6 if k == 0 else 1.0))
		colours.append(_with_alpha(_shade(bark, 0.15 - u * 0.25), 0.0))
	tube(kit, points, radii, 7, colours)
	for root in range(5):
		var angle: float = TAU * float(root) / 5.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side: Vector3 = out.cross(UP).normalized() * radius * 0.18
		var foot: Vector3 = out * radius * rng.randf_range(2.4, 3.4)
		var high: Vector3 = UP * radius * rng.randf_range(2.2, 3.4) + out * radius * 0.6
		var root_col: Color = _with_alpha(_shade(bark, 0.05), 0.0)
		kit.tri(out * radius * 0.7 + side, foot, high, root_col)
		kit.tri(out * radius * 0.7 - side, high, foot, _shade(root_col, 0.12))
	var top: Vector3 = points[points.size() - 1]
	for c in range(crowns):
		var angle: float = rng.randf() * TAU
		var spread: float = height * rng.randf_range(0.05, 0.16)
		var at: Vector3 = top + Vector3(cos(angle) * spread, rng.randf_range(-height * 0.12, height * 0.04), sin(angle) * spread)
		var size: float = height * rng.randf_range(0.14, 0.22)
		blob(kit, at, Vector3(size, size * 0.55, size), _shade(leaf, rng.randf_range(-0.1, 0.12)), rng, 0.22, 4, 9, 0.35)
	# Branch stubs reaching to the crowns.
	for b in range(3):
		var angle: float = rng.randf() * TAU
		var from: Vector3 = UP * height * rng.randf_range(0.55, 0.8)
		var to: Vector3 = from + Vector3(cos(angle), 0.6, sin(angle)) * height * 0.18
		tube(kit, [from, to], [radius * 0.3, radius * 0.14], 5, [_with_alpha(bark, 0.0), _with_alpha(bark, 0.1)])
	return kit.mesh()


static func palm(seed: int, height: float) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)).normalized()
	var points: Array = []
	var radii: Array = []
	var colours: Array = []
	for k in range(7):
		var u: float = float(k) / 6.0
		points.append(lean * height * u + Vector3(lean.x, 0, lean.z) * height * 0.25 * u * u)
		radii.append(lerpf(0.32, 0.2, u))
		colours.append(Color("8a6a45", 0.0) if k % 2 == 0 else Color("74573a", 0.0))
	tube(kit, points, radii, 6, colours)
	var top: Vector3 = points[points.size() - 1]
	for f in range(8):
		var angle: float = TAU * float(f) / 8.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side: Vector3 = out.cross(UP).normalized()
		var reach: float = height * 0.32
		var previous: Vector3 = top
		for k in range(1, 6):
			var u: float = float(k) / 5.0
			var point: Vector3 = top + out * reach * u + UP * reach * (0.35 * u - 0.75 * u * u)
			var width: float = reach * 0.16 * sin(PI * clampf(u, 0.1, 0.95))
			var col: Color = _with_alpha(_shade(Color("3c9a4a"), 0.2 - u * 0.3), u)
			kit.quad(previous - side * width, previous + side * width, point + side * width * 0.8, point - side * width * 0.8, col)
			previous = point
	blob(kit, top - UP * 0.3, Vector3.ONE * 0.35, Color("6b4a2a", 0.0), rng, 0.1, 3, 6)
	return kit.mesh()


## A hanging liana with small leaves; sways most at its lower end.
static func liana(seed: int, length: float) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var points: Array = []
	var radii: Array = []
	var colours: Array = []
	var steps: int = 8
	for k in range(steps + 1):
		var u: float = float(k) / float(steps)
		points.append(Vector3(sin(u * 5.0 + float(seed)) * 0.25, -length * u, cos(u * 4.0) * 0.15))
		radii.append(0.05)
		colours.append(Color("3b6b2a", u))
	tube(kit, points, radii, 4, colours)
	for k in range(1, steps):
		var u: float = float(k) / float(steps)
		var at: Vector3 = points[k]
		var angle: float = rng.randf() * TAU
		var out := Vector3(cos(angle), 0.0, sin(angle)) * 0.35
		var side := Vector3(-sin(angle), 0.0, cos(angle)) * 0.12
		var col := Color("4caf50", u)
		kit.quad(at, at + out * 0.5 + side + Vector3.UP * 0.05, at + out, at + out * 0.5 - side - Vector3.UP * 0.05, col)
	return kit.mesh()


static func rock(seed: int, size: Vector3, colour: Color = Color("7d8270"), moss: bool = true) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	blob(kit, Vector3(0, size.y * 0.3, 0), size, colour, rng, 0.25, 4, 7, 0.0, true)
	if moss:
		blob(kit, Vector3(0, size.y * 1.05, 0), Vector3(size.x * 0.75, size.y * 0.22, size.z * 0.75), Color("4f9a3c"), rng, 0.2, 3, 7)
	return kit.mesh()


# ------------------------------------------------------------------ ruins

static func pillar(seed: int, height: float, broken: bool) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stone := Color("b8a07a")
	var blocks: int = int(height / 0.9)
	for b in range(blocks):
		var y: float = float(b) * 0.9
		var w: float = 0.55 + rng.randf_range(-0.04, 0.04)
		var shift := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
		_box(kit, shift + Vector3(0, y + 0.43, 0), Vector3(w, 0.42, w), _shade(stone, rng.randf_range(-0.08, 0.12)))
	if not broken:
		_box(kit, Vector3(0, float(blocks) * 0.9 + 0.2, 0), Vector3(0.75, 0.2, 0.75), _shade(stone, -0.08))
	blob(kit, Vector3(0.3, float(blocks) * 0.9 * 0.6, 0.4), Vector3(0.35, 0.6, 0.3), Color("4f9a3c"), rng, 0.2, 3, 6, 0.0)
	return kit.mesh()


## Axis-aligned box with simple light/dark faces (top brighter).
static func _box(kit: Kit, centre: Vector3, half: Vector3, colour: Color) -> void:
	var c: Vector3 = centre
	var x := Vector3(half.x, 0, 0)
	var y := Vector3(0, half.y, 0)
	var z := Vector3(0, 0, half.z)
	var top: Color = _shade(colour, -0.12)
	var side: Color = colour
	var dark: Color = _shade(colour, 0.18)
	kit.quad(c + y - x - z, c + y + x - z, c + y + x + z, c + y - x + z, top)
	kit.quad(c - y - x + z, c - y + x + z, c - y + x - z, c - y - x - z, dark)
	kit.quad(c - x - y + z, c - x + y + z, c + x + y + z, c + x - y + z, side)
	kit.quad(c + x - y - z, c + x + y - z, c - x + y - z, c - x - y - z, _shade(colour, 0.08))
	kit.quad(c + x - y + z, c + x + y + z, c + x + y - z, c + x - y - z, _shade(colour, 0.04))
	kit.quad(c - x - y - z, c - x + y - z, c - x + y + z, c - x - y + z, _shade(colour, 0.1))


static func box(half: Vector3, colour: Color) -> ArrayMesh:
	var kit := Kit.new()
	_box(kit, Vector3.ZERO, half, colour)
	return kit.mesh()


## A friendly stone head of the old temple (an original design: round face, leaf crown).
static func statue(seed: int) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stone := Color("a8956e")
	_box(kit, Vector3(0, 0.6, 0), Vector3(1.0, 0.6, 0.9), _shade(stone, 0.1))
	blob(kit, Vector3(0, 2.3, 0), Vector3(1.2, 1.25, 1.0), stone, rng, 0.04, 6, 10)
	for side in [-1.0, 1.0]:
		blob(kit, Vector3(side * 0.42, 2.55, 0.86), Vector3(0.22, 0.14, 0.1), Color("2d3b2f"), rng, 0.0, 3, 6)
		blob(kit, Vector3(side * 1.15, 2.4, 0.0), Vector3(0.2, 0.42, 0.2), _shade(stone, 0.06), rng, 0.05, 3, 6)
	blob(kit, Vector3(0, 1.95, 0.9), Vector3(0.4, 0.1, 0.1), Color("5a4a36"), rng, 0.0, 3, 6)
	for leaf in range(5):
		var angle: float = -0.9 + float(leaf) * 0.45
		blob(kit, Vector3(sin(angle) * 0.9, 3.45 + cos(angle) * 0.2, cos(angle) * 0.2), Vector3(0.3, 0.55, 0.12), Color("4f9a3c"), rng, 0.1, 3, 6)
	return kit.mesh()


static func arch(width: float, height: float, colour: Color = Color("b8a07a")) -> ArrayMesh:
	var kit := Kit.new()
	for side in [-1.0, 1.0]:
		_box(kit, Vector3(side * width * 0.5, height * 0.5, 0), Vector3(0.45, height * 0.5, 0.5), colour)
	_box(kit, Vector3(0, height + 0.35, 0), Vector3(width * 0.5 + 0.7, 0.35, 0.6), _shade(colour, -0.05))
	_box(kit, Vector3(0, height + 0.85, 0), Vector3(width * 0.3, 0.2, 0.5), _shade(colour, 0.05))
	return kit.mesh()


# ------------------------------------------------------------------ gameplay pieces

## Bouncy jungle mushroom: pale stem, round cap with spots.
static func mushroom(cap: Color) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	tube(kit, [Vector3.ZERO, Vector3(0, 0.45, 0), Vector3(0, 0.8, 0)], [0.32, 0.26, 0.3], 8, [Color("f3ead2"), Color("fff7e6"), Color("f3ead2")])
	blob(kit, Vector3(0, 0.82, 0), Vector3(1.15, 0.55, 1.15), cap, rng, 0.0, 5, 12, 0.0, true)
	for spot in range(7):
		var angle: float = TAU * float(spot) / 7.0
		var at := Vector3(cos(angle) * 0.7, 1.12, sin(angle) * 0.7)
		blob(kit, at, Vector3(0.17, 0.06, 0.17), Color("fff4d6"), rng, 0.0, 2, 6)
	blob(kit, Vector3(0, 1.36, 0), Vector3(0.22, 0.06, 0.22), Color("fff4d6"), rng, 0.0, 2, 6)
	return kit.mesh()


static func barrel(colour: Color = Color("a8683a")) -> ArrayMesh:
	var kit := Kit.new()
	var points: Array = []
	var radii: Array = []
	var colours: Array = []
	for k in range(7):
		var u: float = float(k) / 6.0
		points.append(Vector3(0, 0, -0.75 + 1.5 * u))
		radii.append(0.62 + 0.12 * sin(PI * u))
		var band: bool = k == 1 or k == 5
		colours.append(Color("3d4652") if band else _shade(colour, 0.06 * float(k % 2)))
	tube(kit, points, radii, 12, colours, true)
	tube(kit, [Vector3(0, 0, -0.76), Vector3(0, 0, -0.74)], [0.6, 0.0], 12, [Color("2a1d14"), Color("2a1d14")])
	return kit.mesh()


static func crab() -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var shell := Color("ff6f3c")
	blob(kit, Vector3(0, 0.42, 0), Vector3(0.62, 0.32, 0.45), shell, rng, 0.03, 5, 10)
	for side in [-1.0, 1.0]:
		blob(kit, Vector3(side * 0.82, 0.5, 0.25), Vector3(0.26, 0.2, 0.22), _shade(shell, -0.08), rng, 0.0, 4, 8)
		tube(kit, [Vector3(side * 0.45, 0.4, 0.2), Vector3(side * 0.72, 0.48, 0.25)], [0.07, 0.06], 5, [shell, shell])
		tube(kit, [Vector3(side * 0.2, 0.65, 0.2), Vector3(side * 0.24, 0.92, 0.25)], [0.04, 0.035], 5, [shell, shell])
		blob(kit, Vector3(side * 0.24, 0.98, 0.27), Vector3.ONE * 0.11, Color("ffffff"), rng, 0.0, 4, 8)
		blob(kit, Vector3(side * 0.24, 0.99, 0.37), Vector3.ONE * 0.05, Color("1a2030"), rng, 0.0, 3, 6)
		for leg in range(3):
			var z: float = -0.2 + float(leg) * 0.2
			tube(kit, [Vector3(side * 0.45, 0.35, z), Vector3(side * 0.75, 0.25, z), Vector3(side * 0.85, 0.0, z)], [0.05, 0.045, 0.03], 4, [shell, shell, _shade(shell, 0.2)])
	return kit.mesh()


static func beetle() -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var shell := Color("4fd1c5")
	blob(kit, Vector3(0, 0.42, 0), Vector3(0.5, 0.36, 0.62), shell, rng, 0.02, 5, 10)
	_box(kit, Vector3(0, 0.62, 0.0), Vector3(0.02, 0.15, 0.6), _shade(shell, 0.4))
	blob(kit, Vector3(0, 0.38, 0.62), Vector3(0.3, 0.24, 0.24), Color("2b3346"), rng, 0.0, 4, 8)
	for side in [-1.0, 1.0]:
		blob(kit, Vector3(side * 0.13, 0.46, 0.8), Vector3.ONE * 0.09, Color("ffffff"), rng, 0.0, 4, 8)
		blob(kit, Vector3(side * 0.13, 0.47, 0.87), Vector3.ONE * 0.045, Color("1a2030"), rng, 0.0, 3, 6)
		tube(kit, [Vector3(side * 0.1, 0.55, 0.75), Vector3(side * 0.3, 0.85, 0.95)], [0.025, 0.02], 4, [Color("2b3346"), Color("2b3346")])
		for leg in range(3):
			var z: float = -0.3 + float(leg) * 0.3
			tube(kit, [Vector3(side * 0.4, 0.3, z), Vector3(side * 0.62, 0.2, z), Vector3(side * 0.7, 0.0, z)], [0.04, 0.035, 0.03], 4, [Color("2b3346"), Color("2b3346"), Color("2b3346")])
	return kit.mesh()


static func coconut() -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	blob(kit, Vector3(0, 0.45, 0), Vector3(0.45, 0.45, 0.45), Color("7a5232"), rng, 0.05, 6, 10)
	for side in [-1.0, 1.0]:
		blob(kit, Vector3(side * 0.15, 0.55, 0.38), Vector3(0.1, 0.12, 0.08), Color("ffffff"), rng, 0.0, 4, 8)
		blob(kit, Vector3(side * 0.15, 0.55, 0.45), Vector3.ONE * 0.05, Color("1a2030"), rng, 0.0, 3, 6)
	blob(kit, Vector3(0, 0.95, 0), Vector3(0.18, 0.12, 0.18), Color("4caf50"), rng, 0.2, 3, 6)
	return kit.mesh()


static func boulder() -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	blob(kit, Vector3.ZERO, Vector3.ONE * 1.5, Color("8c8778"), rng, 0.08, 8, 14)
	for patch in range(6):
		var dir: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		blob(kit, dir * 1.45, Vector3(0.6, 0.6, 0.6), Color("4f9a3c"), rng, 0.2, 3, 6)
	for line in range(4):
		var angle: float = TAU * float(line) / 4.0
		_box(kit, Vector3(cos(angle) * 1.3, sin(angle) * 1.3, 0), Vector3(0.14, 0.14, 1.2), Color("c7a35a"))
	return kit.mesh()


static func cart() -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var wood := Color("9a6436")
	_box(kit, Vector3(0, 0.55, 0), Vector3(0.8, 0.12, 1.1), _shade(wood, 0.1))
	for side in [-1.0, 1.0]:
		_box(kit, Vector3(side * 0.78, 0.95, 0), Vector3(0.06, 0.4, 1.1), wood)
		_box(kit, Vector3(0, 0.95, side * 1.08), Vector3(0.8, 0.4, 0.06), _shade(wood, -0.05))
		_box(kit, Vector3(side * 0.8, 1.32, 0), Vector3(0.09, 0.06, 1.15), Color("c9a34a"))
		for end in [-0.7, 0.7]:
			tube(kit, [Vector3(side * 0.62, 0.3, end), Vector3(side * 0.9, 0.3, end)], [0.28, 0.28], 10, [Color("3d4652"), Color("59636f")], true)
	return kit.mesh()


static func torch() -> ArrayMesh:
	var kit := Kit.new()
	tube(kit, [Vector3.ZERO, Vector3(0, 1.9, 0)], [0.09, 0.07], 6, [Color("5a3d28"), Color("6b4a31")])
	tube(kit, [Vector3(0, 1.8, 0), Vector3(0, 2.1, 0)], [0.16, 0.22], 7, [Color("3d4652"), Color("59636f")])
	return kit.mesh()


## Flame: three crossed tongues, coloured from white-gold core to orange tips.
static func flame() -> ArrayMesh:
	var kit := Kit.new()
	for k in range(3):
		var angle: float = PI * float(k) / 3.0
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.2
		kit.quad(-side, side, side * 0.3 + UP * 0.55, -side * 0.3 + UP * 0.55, Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.45, 0.1, 0.0), Color(1.0, 0.45, 0.1, 0.0))
	return kit.mesh()


static func crystal(seed: int, colour: Color) -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for spike in range(5):
		var tilt := Vector3(rng.randf_range(-0.5, 0.5), 1.0, rng.randf_range(-0.5, 0.5)).normalized()
		var length: float = rng.randf_range(0.6, 1.5)
		var base := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var side: Vector3 = tilt.cross(Vector3.FORWARD).normalized() * 0.16
		var other: Vector3 = tilt.cross(side).normalized() * 0.16
		var tip: Vector3 = base + tilt * length
		var corners: Array = [base + side, base + other, base - side, base - other]
		for c in range(4):
			var mid: Vector3 = (corners[c] + corners[(c + 1) % 4]) * 0.5 + tilt * length * 0.7
			kit.quad(corners[c], corners[(c + 1) % 4], mid, corners[c] + tilt * length * 0.7, _shade(colour, 0.15 * float(c % 2)), _shade(colour, 0.1), colour.lightened(0.3), colour.lightened(0.2))
			kit.tri(corners[c] + tilt * length * 0.7, mid, tip, colour.lightened(0.35), colour.lightened(0.3), Color(1, 1, 1))
	return kit.mesh()


static func leaf_card() -> ArrayMesh:
	var kit := Kit.new()
	var col := Color("6fc24a")
	kit.quad(Vector3(-0.08, 0, 0), Vector3(0, 0.02, -0.12), Vector3(0.08, 0, 0), Vector3(0, -0.02, 0.12), col, col.lightened(0.2), col, col.darkened(0.2))
	return kit.mesh()


static func butterfly() -> ArrayMesh:
	var kit := Kit.new()
	# Two wings that the fauna shader flaps by their vertex alpha (0 body, 1 wing tip).
	for side in [-1.0, 1.0]:
		kit.quad(Vector3(0, 0, -0.06), Vector3(side * 0.22, 0.0, -0.16), Vector3(side * 0.26, 0.0, 0.06), Vector3(0, 0, 0.05), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0))
		kit.quad(Vector3(0, 0, 0.0), Vector3(side * 0.16, 0.0, 0.08), Vector3(side * 0.12, 0.0, 0.2), Vector3(0, 0, 0.08), Color(1, 1, 1, 0), Color(0.85, 0.85, 0.85, 1), Color(0.85, 0.85, 0.85, 1), Color(1, 1, 1, 0))
	return kit.mesh()


static func bird() -> ArrayMesh:
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	blob(kit, Vector3.ZERO, Vector3(0.16, 0.16, 0.38), Color(1, 1, 1, 0), rng, 0.0, 4, 6)
	for side in [-1.0, 1.0]:
		kit.quad(Vector3(side * 0.1, 0.02, -0.15), Vector3(side * 0.6, 0.0, -0.05), Vector3(side * 0.55, 0.0, 0.18), Vector3(side * 0.1, 0.02, 0.15), Color(1, 1, 1, 0), Color(0.9, 0.9, 0.9, 1), Color(0.9, 0.9, 0.9, 1), Color(1, 1, 1, 0))
	kit.tri(Vector3(0, 0, 0.3), Vector3(0.12, 0, 0.75), Vector3(-0.12, 0, 0.75), Color(0.8, 0.8, 0.8, 0))
	blob(kit, Vector3(0, 0.02, -0.42), Vector3(0.05, 0.05, 0.1), Color("ffcf33", 0), rng, 0.0, 3, 5)
	return kit.mesh()


## Flat card used for light shafts, mist and waterfall curtains (UV from vertex positions).
static func card(width: float, height: float, rows: int = 1) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rows):
		var v0: float = float(r) / float(rows)
		var v1: float = float(r + 1) / float(rows)
		var corners: Array = [
			[Vector3(-width * 0.5, height * (1.0 - v0), 0), Vector2(0, v0)],
			[Vector3(width * 0.5, height * (1.0 - v0), 0), Vector2(1, v0)],
			[Vector3(width * 0.5, height * (1.0 - v1), 0), Vector2(1, v1)],
			[Vector3(-width * 0.5, height * (1.0 - v1), 0), Vector2(0, v1)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.BACK)
			st.set_uv(corners[index][1])
			st.add_vertex(corners[index][0])
	st.commit(mesh)
	return mesh
