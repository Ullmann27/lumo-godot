extends RefCounted
## Authoritative metre-scale centreline for Dschungelherz – Expedition Smaragd.
## The authored control polygon, elevation keys and width keys remain editable.
const ID: String = "jungle_emerald_3600"
const TARGET_LENGTH: float = 3600.0
const SECTION_LENGTH: float = 300.0
const SECTION_NAMES: Array[String] = [
	"Expeditionshafen", "Allee der Riesenwurzeln", "Smaragdfluss",
	"Hinter dem Wasserfall", "Wurzelgrotte", "Aufstieg ins Blätterdach",
	"Kronenbrücke", "Lichtung des Sonnentempels", "Schmetterlingsgarten",
	"Flusskaskaden", "Tropischer Regenkessel", "Rückkehr zum Hafen"
]
const HEIGHTS: Array[float] = [3.0, 3.5, 5.0, 6.0, 8.0, 9.0, 21.0, 24.0, 22.0, 17.0, 6.0, 3.0, 3.0]

static func definition() -> Dictionary:
	return {
		"id": ID, "name": "Dschungelherz", "subtitle": "Expedition Smaragd · 3.600 Meter",
		"accent": Color("2ca6a4"), "asphalt": Color("5f6257"),
		"sky": Color("69b5dc"), "horizon": Color("cce7d9"), "fog": Color("719c80"),
		"sun": Color("ffe7b5"), "ground": Color("34784a"), "seed": 36001115,
		"points": author_points(), "length_m": TARGET_LENGTH,
		"road_width_m": 14.0, "section_names": SECTION_NAMES
	}

static func author_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0, 0, -370), Vector3(140, 0, -365), Vector3(280, 0, -330),
		Vector3(340, 0, -260), Vector3(430, 0, -290), Vector3(520, 0, -220),
		Vector3(580, 0, -130), Vector3(610, 0, -10), Vector3(570, 0, 80),
		Vector3(500, 0, 150), Vector3(420, 0, 180), Vector3(390, 0, 260),
		Vector3(420, 0, 340), Vector3(350, 0, 430), Vector3(240, 0, 440),
		Vector3(120, 0, 420), Vector3(40, 0, 360), Vector3(-60, 0, 330),
		Vector3(-160, 0, 390), Vector3(-270, 0, 430), Vector3(-380, 0, 400),
		Vector3(-420, 0, 320), Vector3(-400, 0, 240), Vector3(-300, 0, 220),
		Vector3(-220, 0, 170), Vector3(-250, 0, 100), Vector3(-350, 0, 60),
		Vector3(-450, 0, 30), Vector3(-520, 0, -50), Vector3(-500, 0, -150),
		Vector3(-420, 0, -210), Vector3(-340, 0, -190), Vector3(-280, 0, -240),
		Vector3(-200, 0, -310), Vector3(-120, 0, -350)
	])

static func _smooth(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

static func authored_height(distance: float) -> float:
	var wrapped: float = fposmod(distance, TARGET_LENGTH)
	var sector: int = mini(11, floori(wrapped / SECTION_LENGTH))
	return lerpf(HEIGHTS[sector], HEIGHTS[sector + 1], _smooth(fposmod(wrapped, SECTION_LENGTH) / SECTION_LENGTH))

static func width_at(distance: float) -> float:
	var d: float = fposmod(distance, TARGET_LENGTH)
	var start_width: float = 18.0 - 4.0 * _smooth((d - 70.0) / 150.0)
	if d > 300.0:
		start_width = 14.0 + 4.0 * _smooth((d - 3400.0) / 130.0)
	var river: float = 2.0 * _smooth((d - 610.0) / 70.0) * (1.0 - _smooth((d - 820.0) / 70.0))
	var temple: float = 2.0 * _smooth((d - 2080.0) / 80.0) * (1.0 - _smooth((d - 2340.0) / 70.0))
	return maxf(start_width, 14.0 + maxf(river, temple))

static func wall_at(distance: float) -> float:
	# Keep the centre 0.90 m inside the road edge (kart capsule radius 0.85 m).
	return width_at(distance) * 0.5 - 0.90

static func make_curve() -> Curve3D:
	var authored: PackedVector3Array = author_points()
	var planar := Curve3D.new()
	planar.bake_interval = 0.1
	var smooth := PackedVector3Array()
	for i in range(authored.size()):
		smooth.append(authored[i] * 0.52 + (authored[posmod(i - 1, authored.size())] + authored[(i + 1) % authored.size()]) * 0.24)
	for i in range(smooth.size() + 1):
		var n: int = i % smooth.size()
		var tangent: Vector3 = (smooth[(n + 1) % smooth.size()] - smooth[posmod(n - 1, smooth.size())]) * 0.20
		planar.add_point(smooth[n], -tangent, tangent)
	var planar_length: float = planar.get_baked_length()
	var points := PackedVector3Array()
	for i in range(360):
		var fraction: float = float(i) / 360.0
		var p: Vector3 = planar.sample_baked(fraction * planar_length, true) * (TARGET_LENGTH / planar_length)
		p.y = authored_height(fraction * TARGET_LENGTH)
		points.append(p)
	var curve := Curve3D.new()
	curve.bake_interval = 0.10
	for i in range(points.size() + 1):
		var n: int = i % points.size()
		var tangent: Vector3 = (points[(n + 1) % points.size()] - points[posmod(n - 1, points.size())]) / 6.0
		curve.add_point(points[n], -tangent, tangent)
	# Normalize the final, smoothed 3D curve, including its height profile.
	# Scaling around start altitude preserves the harbour datum and C1 closure.
	for pass_index in range(3):
		var ratio: float = TARGET_LENGTH / curve.get_baked_length()
		for i in range(curve.point_count):
			var p: Vector3 = curve.get_point_position(i)
			curve.set_point_position(i, Vector3(p.x * ratio, 3.0 + (p.y - 3.0) * ratio, p.z * ratio))
			curve.set_point_in(i, curve.get_point_in(i) * ratio)
			curve.set_point_out(i, curve.get_point_out(i) * ratio)
	return curve

static func forward(curve: Curve3D, distance: float) -> Vector3:
	var length: float = curve.get_baked_length()
	return (curve.sample_baked(fposmod(distance + 0.5, length), true) - curve.sample_baked(fposmod(distance, length), true)).normalized()

static func frame(curve: Curve3D, distance: float) -> Basis:
	var ahead: Vector3 = forward(curve, distance)
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(ahead).normalized()
	var bend: float = right.dot(forward(curve, distance + 5.0) - ahead)
	return Basis(right, up, -ahead).rotated(ahead, clampf(-bend * 0.68, -0.14, 0.14))

static func build_road(world: Node3D) -> void:
	world.action = {}
	world.road_width = 14.0
	var road_root := Node3D.new()
	road_root.name = "DschungelherzRoad"
	world.add_child(road_root)
	var road_shader: Shader = load("res://assets/shaders/kart_jungle_road.gdshader")
	var surfaces: Array[ShaderMaterial] = []
	for surface_type in range(3):
		var material := ShaderMaterial.new()
		material.shader = road_shader
		material.set_shader_parameter("surface_type", surface_type)
		surfaces.append(material)
	for section in range(12):
		var start: float = section * 300.0
		var end: float = (section + 1) * 300.0 if section < 11 else float(world.length)
		var surface_type: int = 1 if section == 6 else (2 if section == 10 else 0)
		var piece := MeshInstance3D.new()
		piece.name = "RoadSection%02d" % section
		piece.mesh = _road_mesh(world, start, end)
		piece.material_override = surfaces[surface_type]
		road_root.add_child(piece)
		if section == 0:
			world.road = piece
		var collision := StaticBody3D.new()
		collision.name = "RoadCollision%02d" % section
		collision.collision_layer = 1
		collision.collision_mask = 0
		var shape_node := CollisionShape3D.new()
		var shape: ConcavePolygonShape3D = piece.mesh.create_trimesh_shape()
		shape.backface_collision = true
		shape_node.shape = shape
		collision.add_child(shape_node)
		road_root.add_child(collision)
		for side in [-1.0, 1.0]:
			var barrier_shape := CollisionShape3D.new()
			barrier_shape.name = "ContinuousRailLeft" if side < 0.0 else "ContinuousRailRight"
			var barrier: ConcavePolygonShape3D = _wall_mesh(world, start, end, side).create_trimesh_shape()
			barrier.backface_collision = true
			barrier_shape.shape = barrier
			collision.add_child(barrier_shape)
	var count: int = ceili(float(world.length) / 3.0)
	for i in range(count):
		var d: float = float(i) * float(world.length) / count
		var next: float = float(i + 1) * float(world.length) / count
		var middle: float = (d + next) * 0.5
		var basis: Basis = world.frame(middle)
		var half_width: float = width_at(middle) * 0.5
		var step: float = next - d
		for side in [-1.0, 1.0]:
			var curb_color := Color("ede0bf") if i % 4 < 2 else Color("2ca6a4")
			world._prop("box", world.position_at(middle, side * (half_width + 0.26)) + basis.y * 0.06,
				Vector3(0.52, 0.20, step + 0.035), curb_color, basis)
			# Timber rails and warm sandstone posts share the same collision edge.
			world._prop("box", world.position_at(middle, side * (half_width + 0.12)) + basis.y * 1.16,
				Vector3(0.24, 0.24, step + 0.04), Color("744a2e"), basis)
			world._prop("box", world.position_at(middle, side * (half_width + 0.12)) + basis.y * 0.65,
				Vector3(0.18, 0.18, step + 0.04), Color("916440"), basis)
			if i % 2 == 0:
				world._prop("box", world.position_at(middle, side * (half_width + 0.16)) + basis.y * 0.63,
					Vector3(0.40, 1.38, 0.44), Color("c9a16a"), basis)
	for row in range(2):
		var d: float = 1.0 + row * 0.7
		var basis: Basis = world.frame(d)
		for column in range(24):
			world._prop("box", world.position_at(d, (column - 11.5) * 0.72) + basis.y * 0.018,
				Vector3(0.72, 0.028, 0.70), Color("f5eedb") if (row + column) % 2 == 0 else Color("253b33"), basis)
	# Road-local navigation markers remain outside even the widened start zone.
	for section in range(12):
		var d: float = section * 300.0 + 25.0
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, -width_at(d) * 0.5 - 1.0)
		world._prop("box", at + basis.y * 1.8, Vector3(0.22, 3.6, 0.24), Color("744a2e"), basis)
		world._prop("box", at + basis.y * 3.1, Vector3(3.8, 1.0, 0.18), Color("113b2e"), basis)
		world._sign(at + basis.y * 3.1 + basis.z * 0.11, basis, "%02d  %s" % [section + 1, SECTION_NAMES[section]], 0.013)
	world.set_meta("jungle_road_sections", 12)
	world.set_meta("jungle_road_collision_sections", 12)
	world.set_meta("jungle_road_length_m", world.length)

static func _road_mesh(world: Node3D, start: float, end: float) -> ArrayMesh:
	var count: int = ceili((end - start) / 2.0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Four strips preserve a centre vertex and stable interpolated banking.
	for row in range(count + 1):
		var d: float = lerpf(start, end, float(row) / count)
		var basis: Basis = world.frame(d)
		var half_width: float = width_at(d) * 0.5
		for column in range(5):
			var lateral: float = lerpf(-half_width, half_width, float(column) / 4.0)
			vertices.append(world.position_at(d, lateral))
			normals.append(basis.y)
			uvs.append(Vector2(lateral, d))
	for row in range(count):
		for column in range(4):
			var a: int = row * 5 + column
			indices.append_array(PackedInt32Array([a, a + 5, a + 1, a + 1, a + 5, a + 6]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _wall_mesh(world: Node3D, start: float, end: float, side: float) -> ArrayMesh:
	var count: int = ceili((end - start) / 2.0)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(count + 1):
		var d: float = lerpf(start, end, float(row) / count)
		var basis: Basis = world.frame(d)
		var edge: Vector3 = world.position_at(d, side * width_at(d) * 0.5)
		vertices.append(edge - basis.y * 0.08)
		vertices.append(edge + basis.y * 1.45)
	for row in range(count):
		var a: int = row * 2
		indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func clip_camera(world: Node3D, anchor: Vector3, desired: Vector3) -> Vector3:
	var anchor_road: Dictionary = world.sample_road(anchor)
	var road: Dictionary = world.sample_road(desired, float(anchor_road.distance))
	var d: float = float(road.distance)
	if not (d >= 930.0 and d <= 1170.0 or d >= 1190.0 and d <= 1510.0):
		return desired
	var basis: Basis = road.basis
	var centre: Vector3 = world.position_at(d)
	var lateral: float = clampf((desired - centre).dot(basis.x), -width_at(d) * 0.5 + 0.4, width_at(d) * 0.5 - 0.4)
	var elevation: float = clampf((desired - centre).dot(basis.y), 1.0, 6.5)
	return centre + basis.x * lateral + basis.y * elevation


