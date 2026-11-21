extends RefCounted
## Sichtbare Bauteile der Spannungsstellen (kart_track_thrills.gd). Was gezeichnet wird,
## ist genau das, was gefahren wird: Rampen folgen world.frame() und denselben Höhen wie
## die Fahrphysik; der Spalt ist ein echtes Loch in der Fahrbahn (kart_world._ribbon).

const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const SEGMENTS_PER_METRE: float = 2.0
## Same foot lift as kart_ramp_piece (DECK_LIFT): flush with the asphalt, no z-fighting.
const RAMP_LIFT: float = 0.012


static func build(world) -> void:
	for entry in THRILLS.of(world):
		match str(entry.kind):
			"crest":
				_crest(world, entry)
			"leap":
				_leap(world, entry)
			"bank":
				_bank(world, entry)
			"turbo":
				_turbo(world, entry)
		_sign(world, entry)


static func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _quad(
	tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color
) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	for corner in [a, b, c, a, c, d]:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.add_vertex(corner)


## Swept deck between two laterals with a height profile; closed sides and front.
## With a road material the top uses the asphalt itself (UV = lateral, distance, like
## kart_world._ribbon), so a crest reads as part of the road and not as a crate.
static func _sweep(
	world,
	name: String,
	start: float,
	length: float,
	lat_a: float,
	lat_b: float,
	height_at: Callable,
	top_a: Color,
	top_b: Color,
	side: Color,
	road_material: Material = null
) -> void:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = maxi(4, ceili(length * SEGMENTS_PER_METRE))
	var rows: Array = []
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var d: float = start + length * t
		var basis: Basis = world.frame(d)
		var lift: Vector3 = basis.y * (float(height_at.call(t)) + RAMP_LIFT)
		(
			rows
			. append(
				{
					"d": d,
					"a": world.position_at(d, lat_a) + lift,
					"b": world.position_at(d, lat_b) + lift,
					"fa": world.position_at(d, lat_a) - basis.y * 0.08,
					"fb": world.position_at(d, lat_b) - basis.y * 0.08,
				}
			)
		)
	for i in range(steps):
		var r: Dictionary = rows[i]
		var s: Dictionary = rows[i + 1]
		if road_material != null:
			var normal: Vector3 = (r.b - r.a).cross(s.a - r.a).normalized()
			if normal.y < 0.0:
				normal = -normal
			var corners: Array = [
				[r.a, Vector2(lat_a, r.d)],
				[s.a, Vector2(lat_a, s.d)],
				[s.b, Vector2(lat_b, s.d)],
				[r.a, Vector2(lat_a, r.d)],
				[s.b, Vector2(lat_b, s.d)],
				[r.b, Vector2(lat_b, r.d)]
			]
			for corner in corners:
				top.set_normal(normal)
				top.set_uv(corner[1])
				top.add_vertex(corner[0])
		else:
			var stripe: Color = top_a if int(floor((float(r.d) - start) / 1.0)) % 2 == 0 else top_b
			_quad(body, r.a, r.b, s.b, s.a, stripe)
		_quad(body, r.fa, r.a, s.a, s.fa, side)
		_quad(body, r.b, r.fb, s.fb, s.b, side)
	var last: Dictionary = rows[steps]
	_quad(body, last.fa, last.fb, last.b, last.a, side)
	var node := MeshInstance3D.new()
	node.name = name + ("Sides" if road_material != null else "")
	node.mesh = body.commit()
	node.material_override = _material()
	world.add_child(node)
	if road_material != null:
		var deck := MeshInstance3D.new()
		deck.name = name
		deck.mesh = top.commit()
		deck.material_override = road_material
		world.add_child(deck)


static func _crest(world, entry: Dictionary) -> void:
	var accent: Color = world.definition.accent
	var half: float = world.road_width_at(float(entry.start)) * 0.5 - 0.1
	var road: Color = Color(world.definition.asphalt).lightened(0.12)
	var height: float = float(entry.height)
	_sweep(
		world,
		"TrackRamp_%d" % int(float(entry.start)),
		float(entry.start),
		THRILLS.CREST_LENGTH,
		-half,
		half,
		func(t: float) -> float: return height * t * t,
		road,
		road.darkened(0.12),
		Color("2a3344"),
		world.road.material_override if is_instance_valid(world.road) else null
	)
	# Back of the hill (the kart flies over it; drawn so the crest reads as a hump).
	_sweep(
		world,
		"ThrillCrestBack_%s" % entry.id,
		float(entry.take_off),
		THRILLS.CREST_BACK,
		-half,
		half,
		func(t: float) -> float: return height * (1.0 - t) * (1.0 - t),
		road.darkened(0.08),
		road.darkened(0.08),
		Color("2a3344"),
		world.road.material_override if is_instance_valid(world.road) else null
	)
	var lip: float = float(entry.take_off) - 0.25
	var basis: Basis = world.frame(lip)
	world._prop(
		"box",
		world.position_at(lip) + basis.y * (height + 0.05),
		Vector3(half * 2.0, 0.08, 0.35),
		accent,
		basis,
		true
	)
	# Glowing approach arrows on the hump, all lanes: "full throttle, fly".
	for k in range(3):
		var d: float = float(entry.start) + 3.0 + float(k) * 4.0
		var t: float = (d - float(entry.start)) / THRILLS.CREST_LENGTH
		var b: Basis = world.frame(d)
		for lane in [-2.8, 0.0, 2.8]:
			var at: Vector3 = world.position_at(d, lane) + b.y * (height * t * t + 0.06)
			for arm in [-1.0, 1.0]:
				var arm_basis: Basis = b.rotated(b.y, arm * 0.7)
				world._prop(
					"box",
					at + b.x * arm * 0.32,
					Vector3(0.9, 0.04, 0.18),
					Color("ffd34a"),
					arm_basis,
					true
				)
	if bool(entry.get("hero", false)):
		for marker in range(3):
			var d: float = float(entry.take_off) + 12.0 + float(marker) * 12.0
			var f: Basis = world.frame(d)
			var arch: Vector3 = world.position_at(d) + f.y * (3.4 + float(marker) * 0.4)
			world._prop(
				"box", arch, Vector3(half * 2.0 + 2.2, 0.22, 0.26), accent.lightened(0.3), f, true
			)
			for side in [-1.0, 1.0]:
				var foot: Vector3 = world.position_at(d, side * (half + 1.1))
				world._prop(
					"box",
					foot + f.y * (1.7 + float(marker) * 0.2),
					Vector3(0.22, 3.4 + float(marker) * 0.4, 0.22),
					Color("1b2a44"),
					f
				)


static func _leap(world, entry: Dictionary) -> void:
	var theme: Dictionary = THRILLS.THEMES.get(str(entry.get("theme", "lava")), THRILLS.THEMES.lava)
	var side: float = float(entry.side)
	var inner: float = float(entry.inner) * side
	var outer: float = float(entry.outer) * side
	var height: float = float(entry.height)
	_sweep(
		world,
		"ThrillLeapRamp_%s" % entry.id,
		float(entry.start),
		THRILLS.LEAP_RAMP_LENGTH,
		minf(inner, outer),
		maxf(inner, outer),
		func(t: float) -> float: return height * t,
		Color("f7c84a"),
		Color("23324a"),
		Color("23324a")
	)
	var lip: float = float(entry.take_off) - 0.2
	var lip_basis: Basis = world.frame(lip)
	world._prop(
		"box",
		world.position_at(lip, (inner + outer) * 0.5) + lip_basis.y * (height + 0.05),
		Vector3(absf(outer - inner), 0.08, 0.3),
		theme.glow,
		lip_basis,
		true
	)
	# The gap: a bright glowing surface (lava, water, ice …) just below the road so it reads
	# from the low driver camera, framed by short rock lips. Nothing to drive on.
	var gap_start: float = float(entry.take_off)
	var gap_end: float = float(entry.gap_end)
	var steps: int = 8
	var far: float = side * 13.0
	for k in range(steps):
		var d: float = lerpf(gap_start, gap_end, (float(k) + 0.5) / float(steps))
		var b: Basis = world.frame(d)
		var seg: float = (gap_end - gap_start) / float(steps) + 0.05
		world._prop(
			"box",
			world.position_at(d, (inner + far) * 0.5) - b.y * 1.1,
			Vector3(absf(far - inner), 0.25, seg),
			theme.deep,
			b,
			true
		)
		# Bright ripples across the surface.
		if k % 2 == 0:
			world._prop(
				"box",
				world.position_at(d, (inner + far) * 0.5) - b.y * 0.95,
				Vector3(absf(far - inner) * 0.8, 0.05, 0.35),
				theme.glow,
				b,
				true
			)
		# Short rock lip on the safe line's edge, with a glowing edge line on the road.
		world._prop(
			"box",
			world.position_at(d, inner - side * 0.2) - b.y * 0.55,
			Vector3(0.4, 1.1, seg),
			theme.wall,
			b
		)
		world._prop(
			"box",
			world.position_at(d, inner - side * 0.25) + b.y * 0.03,
			Vector3(0.22, 0.05, seg),
			theme.glow,
			b,
			true
		)
	for edge in [gap_start, gap_end]:
		var b: Basis = world.frame(edge)
		world._prop(
			"box",
			world.position_at(edge, (inner + far) * 0.5) - b.y * 0.6,
			Vector3(absf(far - inner), 1.2, 0.5),
			theme.wall,
			b
		)
	# Landing edge glows so the far side is visible before the jump.
	var land: Basis = world.frame(gap_end + 0.4)
	world._prop(
		"box",
		world.position_at(gap_end + 0.4, (inner + outer) * 0.5) + land.y * 0.04,
		Vector3(absf(outer - inner), 0.05, 0.5),
		theme.glow,
		land,
		true
	)
	# Gateway arches: a themed one over the brave line, a green one over the safe line.
	var gate_d: float = float(entry.start) - 2.0
	var g: Basis = world.frame(gate_d)
	var brave_mid: float = (inner + outer) * 0.5
	var safe_mid: float = -side * 2.1
	for arch in [
		[brave_mid, absf(outer - inner) + 0.6, theme.glow], [safe_mid, 6.2, Color("6dff9a")]
	]:
		var mid: float = float(arch[0])
		var span: float = float(arch[1])
		var color: Color = arch[2]
		world._prop(
			"box",
			world.position_at(gate_d, mid) + g.y * 4.4,
			Vector3(span, 0.35, 0.35),
			color,
			g,
			true
		)
		for post in [-0.5, 0.5]:
			world._prop(
				"box",
				world.position_at(gate_d, mid + post * span) + g.y * 2.2,
				Vector3(0.28, 4.4, 0.28),
				color,
				g,
				true
			)
	world._sign(world.position_at(gate_d, brave_mid) + g.y * 5.1 + g.z * 0.2, g, "SPRUNG", 0.02)
	world._sign(world.position_at(gate_d, safe_mid) + g.y * 5.1 + g.z * 0.2, g, "SICHER", 0.02)
	# Lane guidance: yellow chevrons on the brave line, a green dashed line on the safe side.
	for k in range(4):
		var d: float = float(entry.start) - 34.0 + float(k) * 8.0
		var b: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, (inner + outer) * 0.5) + b.y * 0.04
		for arm in [-1.0, 1.0]:
			world._prop(
				"box",
				at + b.x * arm * 0.38,
				Vector3(1.05, 0.04, 0.2),
				Color("ffcf3a"),
				b.rotated(b.y, arm * 0.7),
				true
			)
	var safe_lat: float = -side * 1.9
	var d0: float = float(entry.start) - 40.0
	while d0 < gap_end + 6.0:
		var b: Basis = world.frame(d0)
		world._prop(
			"box",
			world.position_at(d0, safe_lat) + b.y * 0.035,
			Vector3(0.24, 0.03, 2.2),
			Color("6dff9a"),
			b,
			true
		)
		d0 += 5.0


static func _bank(world, entry: Dictionary) -> void:
	var accent: Color = world.definition.accent
	var middle: float = (float(entry.start) + float(entry.end)) * 0.5
	var ahead: Vector3 = world.forward(middle)
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var bend: float = right.dot(world.forward(middle + 6.0) - ahead)
	var outer_side: float = -1.0 if bend > 0.0 else 1.0
	var d: float = float(entry.start) + 25.0
	var k: int = 0
	while d < float(entry.end) - 20.0:
		var b: Basis = world.frame(d)
		var foot: Vector3 = world.position_at(d, outer_side * 6.6)
		world._prop("box", foot + b.y * 0.9, Vector3(0.18, 1.8, 1.6), Color("1b2a44"), b)
		var chevron: Color = accent if k % 2 == 0 else Color("ffffff")
		world._prop(
			"box",
			foot + b.y * 1.2 - b.x * outer_side * 0.1,
			Vector3(0.06, 0.9, 1.4),
			chevron,
			b,
			true
		)
		d += 9.0
		k += 1


static func _turbo(world, entry: Dictionary) -> void:
	var accent: Color = Color("4fe6ff")
	for k in range(3):
		var d: float = float(entry.start) + THRILLS.TURBO_SPACING * float(k) + 3.0
		if world.ADVENTURE_TUNNELS.contains(world, d, 8.0):
			continue  # Inside a tunnel the pads glow on their own; no arches through the roof.
		var b: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5 + 0.9
		var top: Vector3 = world.position_at(d) + b.y * 5.6
		world._prop("box", top, Vector3(half * 2.0 - 0.2, 0.3, 0.4), accent, b, true)
		for side in [-1.0, 1.0]:
			var foot: Vector3 = world.position_at(d, side * half)
			world._prop("box", foot + b.y * 2.8, Vector3(0.3, 5.6, 0.4), Color("ff9a3c"), b, true)


static func _sign(world, entry: Dictionary) -> void:
	if str(entry.kind) == "bank":
		return
	var title: String = str(entry.get("name", "")).to_upper()
	if title.is_empty():
		return
	var d: float = float(entry.sign_at)
	var b: Basis = world.frame(d)
	var side: float = float(entry.get("side", 1.0))
	var at: Vector3 = world.position_at(d, side * 7.2) + b.y * 3.2
	world._prop("box", at - b.y * 1.6, Vector3(0.25, 3.2, 0.25), Color("1b2a44"), b)
	world._prop("box", at + b.z * 0.06, Vector3(4.6, 1.3, 0.12), Color("142d48"), b)
	var text: String = title
	if str(entry.kind) == "leap":
		text = (
			"%s\n%s" % [title, "→ SPRUNG  ·  ← SICHER" if side > 0.0 else "SICHER →  ·  SPRUNG ←"]
		)
	world._sign(at + b.z * 0.14, b, text, 0.012)
