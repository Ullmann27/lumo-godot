extends RefCounted
## Lumos Riesengarten – die Wahrzeichen der elf Abschnitte (Blender-Modelle aus
## kart_garden_models.gd). Alles hier ist Bild: Fahrbahn, Wände und Kollision kommen aus
## kart_garden_course.gd/kart_garden_world.gd und alle Maße hier folgen genau diesen Zahlen.
## build() liefert die beweglichen Teile (Zug, Tropfen, Ringe, Sprenger …) für die Ereignisse.
const COURSE = preload("res://scripts/games/garden/kart_garden_course.gd")
const MODELS = preload("res://scripts/games/garden/kart_garden_models.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const GLASS = preload("res://assets/shaders/garden/kart_garden_glass.gdshader")
const WATER = preload("res://assets/shaders/garden/kart_garden_water.gdshader")
const DROP = preload("res://assets/shaders/garden/kart_garden_drop.gdshader")
const BEAM = preload("res://assets/shaders/garden/kart_garden_beam.gdshader")
const SPRAY = preload("res://assets/shaders/garden/kart_garden_spray.gdshader")
const RAINBOW = preload("res://assets/shaders/garden/kart_garden_rainbow.gdshader")
## Sonnenblume rechts vor der Startgeraden: die Runde ist eine Linksschleife, eine Blume
## in der geometrischen Mitte stünde immer 90° links außerhalb des Blicks. Hier sieht man
## sie beim Start, auf der Ostseite und im ganzen Zieleinlauf.
const SUNFLOWER_AT: Vector3 = Vector3(126.0, 0.0, 38.0)
const SUNFLOWER_SCALE: float = 1.18
const BAMBOO: Color = Color("c9b273")
const POND_LEVEL: float = 0.35
const GREENHOUSE_HALF: float = 11.0
const GREENHOUSE_STEP: float = 11.8
## Kürbis-Tunnel: seitlicher Maßstab, Höhe, Länge (Modell: Aufstandsradius 0,64).
const PUMPKIN_SCALE: Vector3 = Vector3(7.5, 9.5, 8.5)
const PUMPKIN_AT: Array[float] = [1548.0, 1588.0, 1628.0]
const TOMATO_ARCHES: Array[float] = [2004.0, 2092.0, 2178.0, 2262.0]


static func build(env: Node3D, world: Node3D, low: bool) -> Dictionary:
	var parts: Dictionary = {}
	var root := Node3D.new()
	root.name = "Landmarks"
	env.add_child(root)
	_sunflower(root, low, parts)
	_start_bench(world)
	_finish_arch(root, world, low)
	_garden_wall(root, world)
	_watering_can(root, world, low)
	_pond(root, world, low, parts)
	_dew_drops(root, world, low, parts)
	_hose(root, world, low, parts)
	_pot_tower(root, world, low, parts)
	_railway(root, world, low, parts)
	_pumpkins(root, world, low, parts)
	_meadow(root, world, low, parts)
	_greenhouse(root, world, low, parts)
	_sprinklers(root, world, low, parts)
	_supports(world)
	return parts


# ------------------------------------------------------------------ Hilfen


static func _yaw(world: Node3D, d: float, yaw: float = 0.0) -> Basis:
	return MODELS.along(world.frame(d), yaw)


static func _ground(world: Node3D, d: float, lateral: float) -> Vector3:
	var at: Vector3 = world.position_at(d, lateral)
	return Vector3(at.x, 0.0, at.z)


## Waagrechter Abstand eines Bodenpunkts zur nächsten Fahrbahnkante (Meter, negativ = auf
## der Fahrbahn). below: nur Fahrbahnteile tiefer als diese Höhe zählen (Stützen unter
## hohen Abschnitten dürfen neben tieferen stehen, nicht auf ihnen).
static func clearance(world: Node3D, point: Vector3, below: float = INF) -> float:
	var samples: Array = world.get_meta("garden_plan", [])
	if samples.is_empty():
		var d: float = 0.0
		while d < float(world.length):
			var at: Vector3 = world.position_at(d)
			samples.append(Vector4(at.x, at.y, at.z, COURSE.width_at(d) * 0.5 + 1.2))
			d += 3.0
		world.set_meta("garden_plan", samples)
	var best: float = INF
	for sample: Vector4 in samples:
		if sample.y > below:
			continue
		var gap: float = Vector2(point.x - sample.x, point.z - sample.z).length() - sample.w
		best = minf(best, gap)
	return best


static func _mesh_node(parent: Node3D, name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _standard(colour: Color, rough: float = 0.7, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = rough
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = emission
	return material


## Stütze aus Bambusstab mit Bastknoten (Pflanzstab), vom Boden bis zur Höhe top.
static func _cane(world: Node3D, foot: Vector3, top: float, radius: float = 0.38) -> void:
	var height: float = maxf(top - foot.y, 0.5)
	world._prop("cylinder", foot + Vector3.UP * height * 0.5, Vector3(radius, height, radius), BAMBOO)
	var knot: float = 3.2
	while knot < height - 0.5:
		world._prop(
			"cylinder",
			foot + Vector3.UP * knot,
			Vector3(radius * 1.15, 0.22, radius * 1.15),
			BAMBOO.darkened(0.18)
		)
		knot += 3.6
	world._prop(
		"cylinder", foot + Vector3.UP * (height - 0.6), Vector3(radius * 1.3, 0.5, radius * 1.3),
		Color("d8c08a")
	)


# ------------------------------------------------------------------ 1 Start / 11 Ziel


static func _sunflower(root: Node3D, low: bool, parts: Dictionary) -> void:
	var basis := Basis(Vector3.UP, PI * 0.5 - 0.12).scaled(Vector3.ONE * SUNFLOWER_SCALE)
	var flower: Node3D = MODELS.place(
		root, "sonnenblume", Transform3D(basis, SUNFLOWER_AT), low, Vector2(260.0, 520.0)
	)
	parts["sunflower"] = flower


static func _start_bench(world: Node3D) -> void:
	# Die Startgerade ist die Sitzplanke einer Gartenbank: gusseiserne Füße darunter.
	for d in [12.0, 58.0, 104.0]:
		var basis: Basis = world.frame(d)
		var road: Vector3 = world.position_at(d)
		for side in [-1.0, 1.0]:
			var foot: Vector3 = world.position_at(d, side * (COURSE.width_at(d) * 0.5 - 1.2))
			foot.y = road.y * 0.5 - 0.1
			world._prop("box", foot, Vector3(0.7, road.y - 0.1, 2.2), Color("2f4a3a"), basis)
			world._prop(
				"box",
				Vector3(foot.x, 0.18, foot.z) + basis.x * side * 0.6,
				Vector3(2.0, 0.36, 2.8),
				Color("2f4a3a"),
				basis
			)
		world._prop(
			"box",
			road - basis.y * 0.55,
			Vector3(COURSE.width_at(d) - 2.0, 0.5, 1.2),
			Color("365645"),
			basis
		)


static func _finish_arch(root: Node3D, world: Node3D, low: bool) -> void:
	var d: float = 3.0
	MODELS.place(root, "rosenbogen", Transform3D(_yaw(world, d), world.position_at(d)), low)


# ------------------------------------------------------------------ 3 Gießkanne


## Gartenmauer unter der Auffahrt zur Kanne: Trockenmauer aus einzelnen Steinen.
static func _garden_wall(root: Node3D, world: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stones: Array[Color] = [Color("b9ae9c"), Color("a89c88"), Color("c8bfae"), Color("9a8f7d")]
	var d: float = 300.0
	while d < 462.0:
		var next: float = minf(d + 2.0, 462.0)
		for side in [-1.0, 1.0]:
			var a: Vector3 = world.position_at(d, side * (COURSE.width_at(d) * 0.5 + 0.8))
			var b: Vector3 = world.position_at(next, side * (COURSE.width_at(next) * 0.5 + 0.8))
			var top: float = minf(a.y, b.y)
			var row: float = 0.0
			while row < top - 0.05:
				var row_top: float = minf(row + 1.1, top)
				var colour: Color = stones[(int(d) + int(row * 3.0) + int(side + 1.0)) % stones.size()]
				var normal: Vector3 = Vector3((b - a).z, 0.0, -(b - a).x).normalized() * -side
				st.set_color(colour)
				st.set_normal(normal)
				for v in [
					Vector3(a.x, row, a.z),
					Vector3(b.x, row, b.z),
					Vector3(a.x, row_top, a.z),
					Vector3(a.x, row_top, a.z),
					Vector3(b.x, row, b.z),
					Vector3(b.x, row_top, b.z)
				]:
					st.add_vertex(v)
				row = row_top + 0.0
		d = next
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := _mesh_node(root, "GardenWall", st.commit(), material)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func _watering_can(root: Node3D, world: Node3D, low: bool) -> void:
	var d: float = COURSE.CAN_BODY.x
	MODELS.place(
		root, "giesskanne", Transform3D(_yaw(world, d), world.position_at(d)), low, Vector2(160.0, 420.0)
	)


# ------------------------------------------------------------------ 4 Seerosen-Teich


static func pond_centre(world: Node3D) -> Vector3:
	var a: Vector3 = world.position_at(560.0, 34.0)
	return Vector3(a.x, POND_LEVEL, a.z)


static func _pond(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	var centre: Vector3 = pond_centre(world)
	var radius: float = 112.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 48
	var rim: Array[Vector3] = []
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		var r: float = radius * (0.86 + 0.14 * sin(a * 3.0 + 0.7) * cos(a * 2.0))
		rim.append(centre + Vector3(cos(a) * r, 0.0, sin(a) * r))
	for i in range(count):
		for v in [centre, rim[i], rim[(i + 1) % count]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	var water := ShaderMaterial.new()
	water.shader = WATER
	var pond := _mesh_node(root, "LilyPond", st.commit(), water)
	pond.sorting_offset = -1.0
	parts["pond"] = pond
	# Uferkiesel und Schilf (Grashalme) rund um den Teich.
	for i in range(count):
		var p: Vector3 = rim[i]
		if clearance(world, p) < 2.0:
			continue
		world._prop(
			"rock", p, Vector3(4.0, 2.2, 3.4) * (0.8 + 0.4 * absf(sin(float(i) * 1.7))),
			Color("9a948a"), Basis(Vector3.UP, float(i))
		)
	# Seerosenblätter unter der Landebahn: der rote Rand schaut an den Kanten heraus.
	var pads: Array[Transform3D] = []
	var d: float = ceilf(COURSE.LANDING.x / 13.0) * 13.0
	while d < 733.0:
		var half: float = COURSE.width_at(d) * 0.5
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d) - basis.y * 0.16
		pads.append(Transform3D(Basis(Vector3.UP, d * 0.37).scaled(Vector3(half + 1.6, 1.2, half + 1.6)), at))
		d += 13.0
	# Freie Blätter im Teich (wippen in den Ereignissen) und Blüten.
	var floating: Array[Node3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var tries: int = 0
	while floating.size() < (6 if low else 14) and tries < 200:
		tries += 1
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(18.0, radius * 0.78)
		var at := centre + Vector3(cos(a) * r, 0.05, sin(a) * r)
		if clearance(world, at) < 5.0:
			continue
		var size: float = rng.randf_range(4.0, 8.5)
		var pad: Node3D = MODELS.place(
			root,
			"seerose_blatt",
			Transform3D(Basis(Vector3.UP, a).scaled(Vector3(size, 1.4, size)), at),
			low,
			Vector2(70.0, 160.0),
			false
		)
		pad.set_meta("rest_y", at.y)
		floating.append(pad)
		if floating.size() % 3 == 0:
			MODELS.place(
				root,
				"seerose_bluete",
				Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * size * 0.42), at + Vector3.UP * 0.2),
				low,
				Vector2(60.0, 140.0),
				false
			)
	parts["floating_pads"] = floating
	MODELS.scatter(root, "seerose_blatt", pads, 1, 240.0)


# ------------------------------------------------------------------ 2 Tautropfen-Allee


static func drop_mesh() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 12
	return sphere


static func drop_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DROP
	return material


static func _dew_drops(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	# Turbo-Tropfen links auf der Fahrbahn (Lage = Turbofelder aus action_plan).
	var turbo: Array[Node3D] = []
	var material := drop_material()
	var mesh := drop_mesh()
	for pad in world.action.get("pads", []):
		if str(pad.get("garden", "")) != "tau":
			continue
		var d: float = (float(pad.start) + float(pad.end)) * 0.5
		var basis: Basis = world.frame(d)
		var drop := MeshInstance3D.new()
		drop.name = "TurboDrop%d" % int(d)
		drop.mesh = mesh
		drop.material_override = material
		drop.position = world.position_at(d, float(pad.lateral)) + basis.y * 1.05
		drop.scale = Vector3(1.35, 1.05, 1.35)
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drop.set_meta("distance", d)
		drop.set_meta("lateral", float(pad.lateral))
		root.add_child(drop)
		turbo.append(drop)
	parts["turbo_drops"] = turbo
	# Morgentau am Rand: große Tropfen auf dem Rasen und an den Halmen (MultiMesh).
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 18011
	var d: float = 140.0
	while d < 340.0:
		for side in [-1.0, 1.0]:
			var lateral: float = side * (COURSE.width_at(d) * 0.5 + rng.randf_range(2.0, 14.0))
			var at: Vector3 = _ground(world, d, lateral)
			var size: float = rng.randf_range(0.9, 2.4)
			at.y = size * 0.85
			if clearance(world, at) > 0.8:
				transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 0.85, size)), at))
		d += 4.0 if low else 2.5
	var node := MultiMeshInstance3D.new()
	node.name = "MorningDew"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 200.0
	root.add_child(node)
	parts["dew"] = node


# ------------------------------------------------------------------ 5 Gartenschlauch


static func _hose(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	var start: float = COURSE.HOSE.x - 6.0
	var end: float = COURSE.HOSE.y + 4.0
	var segments: int = 18 if low else 28
	var radius: float = COURSE.HOSE_RADIUS
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rows: int = ceili((end - start) / 2.0)
	for row in range(rows + 1):
		var d: float = lerpf(start, end, float(row) / float(rows))
		var basis: Basis = world.frame(d)
		var axis: Vector3 = world.position_at(d) + basis.y * 2.2
		for k in range(segments + 1):
			var a: float = TAU * float(k) / float(segments)
			var n: Vector3 = basis.x * cos(a) + basis.y * sin(a)
			vertices.append(axis + n * radius)
			normals.append(n)
			uvs.append(Vector2(radius * a, d))
	for row in range(rows):
		for k in range(segments):
			var a: int = row * (segments + 1) + k
			var b: int = a + segments + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var glass := ShaderMaterial.new()
	glass.shader = GLASS
	glass.set_shader_parameter("tint", Color(0.30, 0.78, 0.40, 0.26))
	glass.set_shader_parameter("rib_period", 2.4)
	glass.set_shader_parameter("drops", 0.6)
	var tube := _mesh_node(root, "GardenHose", mesh, glass)
	parts["hose"] = tube
	# Kupplungen an beiden Enden (Einheitsradius 1 = Innenradius).
	for d in [COURSE.HOSE.x - 3.0, COURSE.HOSE.y - 1.0]:
		var basis: Basis = world.frame(d)
		var axis: Vector3 = world.position_at(d) + basis.y * 2.2
		var turn := Basis(basis.x, basis.y, basis.z)
		MODELS.place(
			root,
			"schlauchkupplung",
			Transform3D(turn.scaled(Vector3.ONE * radius), axis),
			low,
			Vector2(120.0, 300.0)
		)
	# Goldene Wandstreifen der Steilkurven (Turbo oben an der Röhrenwand).
	var chevrons := ImmediateMesh.new()
	chevrons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for pad in world.action.get("pads", []):
		if str(pad.get("garden", "")) != "wand":
			continue
		var d: float = float(pad.start)
		while d < float(pad.end) - 1.0:
			var basis: Basis = world.frame(d)
			var centre: Vector3 = world.position_at(d, float(pad.lateral)) + basis.y * 0.04
			var tip: Vector3 = centre - basis.z * 1.2
			chevrons.surface_add_vertex(centre - basis.x * 0.9)
			chevrons.surface_add_vertex(tip)
			chevrons.surface_add_vertex(centre + basis.x * 0.9)
			d += 3.0
	chevrons.surface_end()
	var gold := _standard(Color("ffd23a"), 0.4, 1.6)
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_node(root, "HoseWallTurbo", chevrons, gold)
	# Wasserblasen, die im Schlauch entgegenkommen (bewegt in den Ereignissen).
	var bubbles := MultiMeshInstance3D.new()
	bubbles.name = "HoseBubbles"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = drop_mesh()
	multimesh.instance_count = 14 if low else 36
	bubbles.multimesh = multimesh
	bubbles.material_override = drop_material()
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bubbles)
	parts["bubbles"] = bubbles


# ------------------------------------------------------------------ 6 Topfturm


static func spiral_centre(world: Node3D) -> Vector3:
	var total := Vector3.ZERO
	var count: int = 0
	var d: float = COURSE.SPIRAL.x + 30.0
	while d < COURSE.SPIRAL.y - 30.0:
		total += world.position_at(d)
		count += 1
		d += 4.0
	var centre: Vector3 = total / float(maxi(count, 1))
	return Vector3(centre.x, 0.0, centre.z)


static func _pot_tower(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	var centre: Vector3 = spiral_centre(world)
	var pots: Array = [
		[centre, 22.5, 0.0, 0.0],
		[centre + Vector3(2.5, 22.5 * 0.93, -1.5), 15.5, 0.11, 0.6],
		[centre + Vector3(4.0, 22.5 * 0.93 + 15.5 * 0.93, -2.0), 9.5, -0.08, 1.9],
	]
	var top := Vector3.ZERO
	for pot in pots:
		var size: float = float(pot[1])
		var basis := Basis(Vector3.UP, float(pot[3])) * Basis(Vector3.RIGHT, float(pot[2]))
		MODELS.place(
			root,
			"blumentopf",
			Transform3D(basis.scaled(Vector3.ONE * size), pot[0]),
			low,
			Vector2(220.0, 480.0)
		)
		top = pot[0] + Vector3.UP * size * 0.93
	MODELS.place(
		root, "blumenbusch", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 15.0), top), low,
		Vector2(220.0, 480.0)
	)
	MODELS.place(
		root,
		"blumenbusch",
		Transform3D(Basis(Vector3.UP, 1.2).scaled(Vector3.ONE * 9.0), pots[1][0] + Vector3(-9.0, 14.2, 4.0)),
		low,
		Vector2(200.0, 420.0)
	)
	# Umgekippte kleine Töpfe am Fuß.
	for i in range(4):
		var a: float = 0.6 + float(i) * 1.7
		var at: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * 58.0
		if clearance(world, at) < 6.0:
			continue
		var lying := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5)
		MODELS.place(
			root, "blumentopf", Transform3D(lying.scaled(Vector3.ONE * 5.0), at + Vector3.UP * 5.0), low
		)
	parts["pot_top"] = top
	parts["pot_rims"] = [pots[1][0] + Vector3(-14.0, 15.0, 0.0), pots[2][0] + Vector3(8.0, 9.0, 3.0)]


# ------------------------------------------------------------------ 7 Gartenbahn


static func gate_entry(world: Node3D) -> Dictionary:
	for entry in PASSAGES.of(world):
		if str(entry.id) == "gartenbahn":
			return entry
	return {}


static func _railway(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	var entry: Dictionary = gate_entry(world)
	if entry.is_empty():
		return
	var d: float = float(entry.plane) + float(entry.band) * 0.5
	var basis: Basis = world.frame(d)
	var road: Vector3 = world.position_at(d)
	var half: float = world.road_width_at(d) * 0.5
	# Pendelgleis von links bis zum Prellbock an der Bahnsteiginsel (nur die linke Spur).
	var stop_lateral: float = float(entry.lat_max) + 0.25
	var far_lateral: float = -half - 30.0
	var dam_mid: float = (-half - 0.4 + far_lateral) * 0.5
	var dam_length: float = -half - 0.4 - far_lateral
	world._prop(
		"box",
		world.position_at(d, dam_mid) - basis.y * (road.y * 0.5 + 0.1),
		Vector3(dam_length, road.y + 0.2, 4.6),
		Color("8b7a62"),
		basis
	)
	var lateral: float = far_lateral
	while lateral < stop_lateral:
		world._prop(
			"box",
			world.position_at(d, lateral) + basis.y * 0.06,
			Vector3(0.5, 0.12, 3.6),
			Color("6b4a31"),
			basis
		)
		lateral += 1.3
	for rail in [-0.95, 0.95]:
		var mid: float = (far_lateral + stop_lateral) * 0.5
		world._prop(
			"box",
			world.position_at(d, mid) + basis.y * 0.2 - basis.z * rail,
			Vector3(stop_lateral - far_lateral, 0.18, 0.16),
			Color("c9ced4"),
			basis
		)
	world._prop(
		"box",
		world.position_at(d, stop_lateral + 0.1) + basis.y * 0.7,
		Vector3(0.5, 1.2, 2.8),
		Color("d23b2f"),
		basis
	)
	# Lokschuppen am Ende des Pendelgleises, Bahnhof „Lumo-Hof“ rechts der Fahrbahn.
	var shed_at: Vector3 = world.position_at(d, far_lateral - 3.0)
	shed_at.y = road.y
	MODELS.place(
		root,
		"gartenbahn_bahnhof",
		Transform3D(Basis.looking_at(basis.x, Vector3.UP).scaled(Vector3.ONE * 1.25), shed_at),
		low
	)
	var station_at: Vector3 = world.position_at(d - 16.0, half + 9.0)
	station_at.y = road.y
	MODELS.place(
		root,
		"gartenbahn_bahnhof",
		Transform3D(_yaw(world, d - 16.0).scaled(Vector3.ONE * 1.4), station_at),
		low
	)
	world._sign(station_at + Vector3.UP * 9.6 - basis.x * 4.4, basis, "LUMO-HOF", 0.03)
	# Der Pendelzug: Lok + Blumenwagen, fährt im Takt der Schranke (Ereignisse).
	var train := Node3D.new()
	train.name = "GardenTrain"
	root.add_child(train)
	var scale: float = 0.68
	MODELS.place(train, "gartenbahn_lok", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3(0, 0, 4.2)), low)
	MODELS.place(
		train,
		"gartenbahn_wagen",
		Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3(0, 0, 4.2 + 3.9 + 5.6 * scale + 0.6)),
		low
	)
	train.set_meta("distance", d)
	train.set_meta("rest_lateral", -half - 1.0)
	train.set_meta("stop_lateral", stop_lateral - 0.2)
	parts["train"] = train
	parts["train_basis"] = Basis.looking_at(basis.x, basis.y)
	# Abgestellter Zug auf dem Nebengleis rechts.
	var siding: float = d + 40.0
	var siding_basis: Basis = _yaw(world, siding)
	for k in range(4):
		var at: Vector3 = world.position_at(siding - float(k) * 8.2, world.road_width_at(siding) * 0.5 + 6.0)
		at.y = road.y
		MODELS.place(
			root,
			"gartenbahn_lok" if k == 0 else "gartenbahn_wagen",
			Transform3D(siding_basis.scaled(Vector3.ONE * 0.72), at),
			low
		)


# ------------------------------------------------------------------ 8 Kürbisbeet


static func pumpkin_lateral() -> float:
	return COURSE.PUMPKIN_WALL_LATERAL + 0.3 - 0.64 * PUMPKIN_SCALE.x


static func _pumpkins(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	var lights: Array[OmniLight3D] = []
	for d in PUMPKIN_AT:
		var at: Vector3 = world.position_at(d, pumpkin_lateral())
		var basis: Basis = _yaw(world, d).scaled(PUMPKIN_SCALE)
		MODELS.place(root, "kuerbis_tunnel", Transform3D(basis, at), low, Vector2(110.0, 260.0))
		if not low:
			var lamp := OmniLight3D.new()
			lamp.name = "PumpkinLantern%d" % int(d)
			lamp.light_color = Color("ffb455")
			lamp.light_energy = 1.6
			lamp.omni_range = 11.0
			lamp.shadow_enabled = false
			lamp.position = at + Vector3.UP * 5.2
			root.add_child(lamp)
			lights.append(lamp)
	parts["pumpkin_lights"] = lights
	# Rankenhecke zwischen den Kürbissen: dieselbe Linie wie die Schale (Wand).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d: float = COURSE.PUMPKIN.x
	var leaf_spots: Array[Transform3D] = []
	while d < COURSE.PUMPKIN.y - 0.5:
		var next: float = minf(d + 2.0, COURSE.PUMPKIN.y)
		var h0: float = COURSE.pumpkin_wall_half(d)
		var h1: float = COURSE.pumpkin_wall_half(next)
		var b0: Basis = world.frame(d)
		var b1: Basis = world.frame(next)
		var c0: Vector3 = world.position_at(d, COURSE.PUMPKIN_WALL_LATERAL)
		var c1: Vector3 = world.position_at(next, COURSE.PUMPKIN_WALL_LATERAL)
		var tall0: float = 1.6 * h0 / COURSE.PUMPKIN_WALL_HALF
		var tall1: float = 1.6 * h1 / COURSE.PUMPKIN_WALL_HALF
		for side in [-1.0, 1.0]:
			var p0: Vector3 = c0 + b0.x * side * h0
			var p1: Vector3 = c1 + b1.x * side * h1
			st.set_color(Color("3f7f2c") if side < 0.0 else Color("4b8f33"))
			st.set_normal(b0.x * side)
			for v in [p0, p1, p0 + b0.y * tall0, p0 + b0.y * tall0, p1, p1 + b1.y * tall1]:
				st.add_vertex(v)
		st.set_color(Color("6aa83f"))
		st.set_normal(b0.y)
		for v in [
			c0 - b0.x * h0 + b0.y * tall0,
			c1 - b1.x * h1 + b1.y * tall1,
			c0 + b0.x * h0 + b0.y * tall0,
			c0 + b0.x * h0 + b0.y * tall0,
			c1 - b1.x * h1 + b1.y * tall1,
			c1 + b1.x * h1 + b1.y * tall1
		]:
			st.add_vertex(v)
		if int(d) % 6 == 0 and h0 > 0.3:
			leaf_spots.append(
				Transform3D(
					Basis(Vector3.UP, d * 0.9).scaled(Vector3.ONE * 3.2), c0 + b0.y * (tall0 + 0.1)
				)
			)
		d = next
	var hedge := StandardMaterial3D.new()
	hedge.vertex_color_use_as_albedo = true
	hedge.roughness = 0.8
	hedge.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hedge_node := _mesh_node(root, "PumpkinVineWall", st.commit(), hedge)
	hedge_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	MODELS.scatter(root, "gartenblatt", leaf_spots, 1, 160.0)
	# Kürbisbeet außen: große Kürbisse und Blätter rechts der Außenkurve und links.
	var rng := RandomNumberGenerator.new()
	rng.seed = 16480
	var leaves: Array[Transform3D] = []
	var at_d: float = 1505.0
	while at_d < 1690.0:
		for side in [-1.0, 1.0]:
			var lateral: float = side * (COURSE.width_at(at_d) * 0.5 + rng.randf_range(6.0, 26.0))
			if side < 0.0:
				lateral -= 8.0
			var spot: Vector3 = _ground(world, at_d, lateral)
			if clearance(world, spot) < 4.0:
				continue
			if rng.randf() < 0.35:
				var size: float = rng.randf_range(4.0, 11.0)
				MODELS.place(
					root,
					"kuerbis",
					Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), spot),
					low,
					Vector2(90.0, 220.0)
				)
			leaves.append(
				Transform3D(
					Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(5.0, 9.0)),
					spot + Vector3.UP * 0.3
				)
			)
		at_d += 9.0
	MODELS.scatter(root, "gartenblatt", leaves, 1, 220.0)


# ------------------------------------------------------------------ 9 Löwenzahn-Wiese


static func _meadow(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	# Schanze: ein aufgerolltes Riesenblatt über die ganze Breite (Höhe = Schanze im Kurs).
	var kicker: Dictionary = {}
	for candidate in world.action.get("kickers", []):
		if str(candidate.get("garden", "")) == "loewenzahn":
			kicker = candidate
	if not kicker.is_empty():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var start: float = float(kicker.start)
		var end: float = float(kicker.take_off)
		var steps: int = 8
		for i in range(steps):
			for half_step in range(2):
				var d0: float = lerpf(start, end, float(i) / float(steps))
				var d1: float = lerpf(start, end, float(i + 1) / float(steps))
				var r0: float = world.ramp_height(d0)
				var r1: float = world.ramp_height(d1)
				var b0: Basis = world.frame(d0)
				var b1: Basis = world.frame(d1)
				var w: float = COURSE.width_at(d0) * 0.5
				var lat0: float = -w if half_step == 0 else 0.0
				var lat1: float = 0.0 if half_step == 0 else w
				var colour := Color("5fae3a") if (i + half_step) % 2 == 0 else Color("6cbd45")
				st.set_color(colour)
				st.set_normal(b0.y)
				var a: Vector3 = world.position_at(d0, lat0) + b0.y * (r0 + 0.03)
				var b: Vector3 = world.position_at(d0, lat1) + b0.y * (r0 + 0.03)
				var c: Vector3 = world.position_at(d1, lat0) + b1.y * (r1 + 0.03)
				var e: Vector3 = world.position_at(d1, lat1) + b1.y * (r1 + 0.03)
				for v in [a, c, b, b, c, e]:
					st.add_vertex(v)
		# Vorderkante (Lippe) des Blattes.
		var tip: Basis = world.frame(end)
		var h: float = world.ramp_height(end - 0.01)
		var lip_l: Vector3 = world.position_at(end, -COURSE.width_at(end) * 0.5)
		var lip_r: Vector3 = world.position_at(end, COURSE.width_at(end) * 0.5)
		st.set_color(Color("3e7a26"))
		st.set_normal(-tip.z)
		for v in [lip_l, lip_r, lip_l + tip.y * h, lip_l + tip.y * h, lip_r, lip_r + tip.y * h]:
			st.add_vertex(v)
		var leaf := StandardMaterial3D.new()
		leaf.vertex_color_use_as_albedo = true
		leaf.roughness = 0.55
		leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_node(root, "LeafRamp", st.commit(), leaf)
		var vein: Vector3 = world.position_at(start - 6.0, 0.0)
		MODELS.place(
			root,
			"gartenblatt",
			Transform3D(_yaw(world, start).scaled(Vector3(15.0, 4.0, 19.0)), vein - Vector3.UP * 0.4),
			low
		)
	# Schirmchen-Ringe: zwölf Schirmchen im Kranz um einen weichen Lichtring.
	var rings: Array[Node3D] = []
	var glow := _standard(Color("fff3c4"), 0.4, 1.3)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.95, 0.75, 0.55)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ring in COURSE.dandelion_rings():
		var d: float = float(ring.d)
		var basis: Basis = world.frame(d)
		var holder := Node3D.new()
		holder.name = "SeedRing%d" % int(d)
		holder.position = world.position_at(d, float(ring.lateral)) + basis.y * float(ring.height)
		holder.basis = Basis(basis.x, -basis.z, basis.y)
		root.add_child(holder)
		var torus := TorusMesh.new()
		torus.inner_radius = COURSE.RING_RADIUS - 0.18
		torus.outer_radius = COURSE.RING_RADIUS + 0.18
		torus.rings = 28
		torus.ring_segments = 8
		var light := MeshInstance3D.new()
		light.mesh = torus
		light.material_override = glow
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(light)
		var seeds: Array[Transform3D] = []
		for k in range(12):
			var a: float = TAU * float(k) / 12.0
			var out := Vector3(cos(a), 0.0, sin(a))
			var turn := Basis.looking_at(out, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
			seeds.append(Transform3D(turn.scaled(Vector3.ONE * 2.1), out * (COURSE.RING_RADIUS + 0.2)))
		MODELS.scatter(holder, "schirmchen", seeds, 1, 260.0, 1000.0)
		holder.set_meta("distance", d)
		holder.set_meta("lateral", float(ring.lateral))
		holder.set_meta("height", float(ring.height))
		rings.append(holder)
	parts["rings"] = rings


# ------------------------------------------------------------------ 10 Gewächshaus


static func greenhouse_profile() -> Array[Vector2]:
	return [
		Vector2(-GREENHOUSE_HALF, 0.0),
		Vector2(-GREENHOUSE_HALF, 8.5),
		Vector2(0.0, 14.0),
		Vector2(GREENHOUSE_HALF, 8.5),
		Vector2(GREENHOUSE_HALF, 0.0),
	]


static func _greenhouse(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	var start: float = COURSE.GREENHOUSE.x
	var end: float = COURSE.GREENHOUSE.y
	var stations: Array[float] = []
	var d: float = start
	while d < end - 1.0:
		stations.append(d)
		d += GREENHOUSE_STEP
	stations.append(end)
	var profile: Array[Vector2] = greenhouse_profile()
	var glass_vertices := PackedVector3Array()
	var glass_normals := PackedVector3Array()
	var glass_uvs := PackedVector2Array()
	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arches: Array[Transform3D] = []
	for i in range(stations.size()):
		var basis: Basis = _yaw(world, stations[i])
		arches.append(Transform3D(basis, world.position_at(stations[i])))
	for i in range(stations.size() - 1):
		var a: Transform3D = arches[i]
		var b: Transform3D = arches[i + 1]
		var run: float = 0.0
		for k in range(profile.size() - 1):
			var p0: Vector3 = a * Vector3(profile[k].x, profile[k].y, 0.0)
			var p1: Vector3 = a * Vector3(profile[k + 1].x, profile[k + 1].y, 0.0)
			var q0: Vector3 = b * Vector3(profile[k].x, profile[k].y, 0.0)
			var q1: Vector3 = b * Vector3(profile[k + 1].x, profile[k + 1].y, 0.0)
			var span: float = profile[k].distance_to(profile[k + 1])
			var normal: Vector3 = (p1 - p0).cross(q0 - p0).normalized()
			for v in [[p0, run, stations[i]], [q0, run, stations[i + 1]], [p1, run + span, stations[i]],
				[p1, run + span, stations[i]], [q0, run, stations[i + 1]], [q1, run + span, stations[i + 1]]]:
				glass_vertices.append(v[0])
				glass_normals.append(normal)
				glass_uvs.append(Vector2(float(v[1]), float(v[2])))
			run += span
		# Boden: Fliesen-Sockel neben der Fahrbahn bis an die Glaswand.
		for side in [-1.0, 1.0]:
			var r0: Vector3 = world.position_at(stations[i], side * (COURSE.width_at(stations[i]) * 0.5 + 0.9))
			var r1: Vector3 = world.position_at(stations[i + 1], side * (COURSE.width_at(stations[i + 1]) * 0.5 + 0.9))
			var w0: Vector3 = a * Vector3(side * GREENHOUSE_HALF, 0.0, 0.0)
			var w1: Vector3 = b * Vector3(side * GREENHOUSE_HALF, 0.0, 0.0)
			floor_st.set_color(Color("b9a88f"))
			floor_st.set_normal(Vector3.UP)
			for v in [r0 - Vector3.UP * 0.05, r1 - Vector3.UP * 0.05, w0 - Vector3.UP * 0.05,
				w0 - Vector3.UP * 0.05, r1 - Vector3.UP * 0.05, w1 - Vector3.UP * 0.05]:
				floor_st.add_vertex(v)
			# Ziegelsockel bis zum Rasen.
			floor_st.set_color(Color("a5583a"))
			floor_st.set_normal(a.basis.x * side)
			var g0 := Vector3(w0.x, 0.0, w0.z)
			var g1 := Vector3(w1.x, 0.0, w1.z)
			for v in [g0, g1, w0, w0, g1, w1]:
				floor_st.add_vertex(v)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = glass_vertices
	arrays[Mesh.ARRAY_NORMAL] = glass_normals
	arrays[Mesh.ARRAY_TEX_UV] = glass_uvs
	var glass_mesh := ArrayMesh.new()
	glass_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var glass := ShaderMaterial.new()
	glass.shader = GLASS
	glass.set_shader_parameter("tint", Color(0.80, 0.94, 0.92, 0.13))
	glass.set_shader_parameter("rim_colour", Color(0.95, 1.0, 0.98))
	glass.set_shader_parameter("rib_period", 2.0)
	glass.set_shader_parameter("rib_strength", 0.10)
	glass.set_shader_parameter("drops", 1.0)
	parts["greenhouse_glass"] = _mesh_node(root, "GreenhouseGlass", glass_mesh, glass)
	var floor_material := StandardMaterial3D.new()
	floor_material.vertex_color_use_as_albedo = true
	floor_material.roughness = 0.75
	floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_node(root, "GreenhouseFloor", floor_st.commit(), floor_material)
	# Stahlspanten (MultiMesh: ein Draw-Call je Material), Giebel an Ein- und Ausfahrt.
	var inner: Array[Transform3D] = []
	for i in range(1, arches.size() - 1):
		inner.append(arches[i])
	MODELS.scatter(root, "gewaechshaus_bogen", inner, 0 if not low else 1, 320.0, 400.0)
	MODELS.place(root, "gewaechshaus_giebel", arches[0], low, Vector2(140.0, 320.0))
	MODELS.place(
		root,
		"gewaechshaus_giebel",
		Transform3D(arches[arches.size() - 1].basis * Basis(Vector3.UP, PI), arches[arches.size() - 1].origin),
		low,
		Vector2(140.0, 320.0)
	)
	# Pflanztische beidseits (die innere Tischkante ist der Fahrbahnrand „tisch“).
	var tables: Array[Transform3D] = []
	d = start + 5.0
	while d < end - 5.0:
		for side in [-1.0, 1.0]:
			var at: Vector3 = world.position_at(d, side * (COURSE.width_at(d) * 0.5 + 2.6))
			tables.append(Transform3D(_yaw(world, d), at - Vector3.UP * 0.05))
		d += 7.0
	MODELS.scatter(root, "pflanztisch", tables, 1, 150.0)
	# Tomatenranken als Tore über der Fahrbahn.
	for at_d in TOMATO_ARCHES:
		MODELS.place(
			root,
			"tomatenbogen",
			Transform3D(_yaw(world, at_d).scaled(Vector3(1.05, 0.95, 1.0)), world.position_at(at_d)),
			low,
			Vector2(80.0, 200.0)
		)
	# Lichtstrahlen durch die Scheiben (additive Lichtkarten, schräg wie die Sonne).
	var beam_material := ShaderMaterial.new()
	beam_material.shader = BEAM
	var beams := ImmediateMesh.new()
	beams.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var sun_dir := Vector3(0.42, -0.74, 0.52).normalized()
	var count: int = 0
	d = start + 9.0
	while d < end - 6.0:
		var side: float = 1.0 if count % 2 == 0 else -1.0
		var basis: Basis = _yaw(world, d)
		var top: Vector3 = world.position_at(d, side * 5.5) + Vector3.UP * 12.0
		var down: Vector3 = top + sun_dir * 15.0
		var across: Vector3 = basis.z * 2.6
		var quad: Array = [
			[top - across, Vector2(0, 0)], [top + across, Vector2(1, 0)], [down - across, Vector2(0, 1)],
			[down - across, Vector2(0, 1)], [top + across, Vector2(1, 0)], [down + across, Vector2(1, 1)]
		]
		for v in quad:
			beams.surface_set_uv(v[1])
			beams.surface_set_normal(basis.x)
			beams.surface_add_vertex(v[0])
		count += 1
		d += 26.0
	beams.surface_end()
	var beam_node := _mesh_node(root, "GreenhouseLightShafts", beams, beam_material)
	beam_node.visible = not low
	parts["greenhouse_stations"] = stations


# ------------------------------------------------------------------ Rasensprenger (Runde 2)


static func _sprinklers(root: Node3D, world: Node3D, low: bool, parts: Dictionary) -> void:
	var list: Array[Dictionary] = []
	for sprinkler in COURSE.sprinklers():
		var d: float = float(sprinkler.d)
		var side: float = float(sprinkler.side)
		var basis: Basis = world.frame(d)
		var foot: Vector3 = world.position_at(d, side * (COURSE.width_at(d) * 0.5 + 4.5))
		foot.y = maxf(0.0, world.position_at(d).y - 0.2)
		var model: Node3D = MODELS.place(
			root,
			"rasensprenger",
			Transform3D(_yaw(world, d, PI * 0.5 * side).scaled(Vector3.ONE * 1.1), foot + Vector3.UP * 1.6),
			low
		)
		var nozzle: Vector3 = foot + Vector3.UP * 8.2
		# Wasserbogen: Band entlang einer Wurfparabel über die Fahrbahn zur anderen Seite.
		var target: Vector3 = world.position_at(d, -side * (COURSE.width_at(d) * 0.5 + 5.0))
		var arc := _arc_mesh(nozzle, target, 13.0, basis.z * 1.6)
		var spray := ShaderMaterial.new()
		spray.shader = SPRAY
		spray.set_shader_parameter("amount", 0.0)
		var arc_node := _mesh_node(root, "SprinklerArc%d" % int(d), arc, spray)
		arc_node.visible = false
		var bow := ShaderMaterial.new()
		bow.shader = RAINBOW
		bow.set_shader_parameter("amount", 0.0)
		var rainbow := _mesh_node(
			root, "Rainbow%d" % int(d), _arc_mesh(nozzle + basis.z * 3.0, target + basis.z * 3.0, 15.5, basis.z * 2.4), bow
		)
		rainbow.visible = false
		list.append(
			{
				"distance": d,
				"line": float(sprinkler.line),
				"model": model,
				"arc": arc_node,
				"rainbow": rainbow,
				"nozzle": nozzle,
				"target": target,
			}
		)
	parts["sprinklers"] = list


## Band entlang einer Parabel von a nach b mit Scheitelhöhe apex über a (Breite width).
static func _arc_mesh(a: Vector3, b: Vector3, apex: float, width: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var steps: int = 20
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector3 = a.lerp(b, t) + Vector3.UP * (4.0 * apex * t * (1.0 - t))
		vertices.append(p - width)
		vertices.append(p + width)
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for i in range(steps):
		var k: int = i * 2
		indices.append_array(PackedInt32Array([k, k + 2, k + 1, k + 1, k + 2, k + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ------------------------------------------------------------------ Stützen


## Bambusstäbe unter Schlauch, Topfspirale und Wasserrutsche (nie auf tieferer Fahrbahn).
static func _supports(world: Node3D) -> void:
	var runs: Array[Vector3] = [
		Vector3(COURSE.CAN_SLIDE_END - 50.0, COURSE.CAN_SLIDE_END, 16.0),
		Vector3(COURSE.HOSE.x + 20.0, COURSE.HOSE.y, 22.0),
		Vector3(COURSE.SPIRAL.x + 8.0, COURSE.SPIRAL.y - 30.0, 24.0),
	]
	for run in runs:
		var d: float = run.x
		while d < run.y:
			var road: Vector3 = world.position_at(d)
			if road.y > 3.5:
				for side in [-1.0, 1.0]:
					var lateral: float = side * (COURSE.width_at(d) * 0.5 + 1.1)
					if d >= COURSE.HOSE.x and d <= COURSE.HOSE.y:
						lateral = side * (COURSE.HOSE_RADIUS + 0.6)
					var top: Vector3 = world.position_at(d, lateral)
					var foot := Vector3(top.x, 0.0, top.z)
					if clearance(world, foot, road.y - 3.0) < 1.5:
						continue
					_cane(world, foot, top.y + 1.2)
			d += run.z
