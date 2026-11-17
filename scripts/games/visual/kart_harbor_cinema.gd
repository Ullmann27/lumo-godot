extends RefCounted
## Original berth hardware with four shared, opaque GPU batches. Geometry is
## local to the existing crane frame; no collision, light, animation or asset.
const CINEMA = preload("res://scripts/games/visual/kart_cinema_materials.gd")
const STEEL := Color("a4b8bd")
const NAVY := Color("253f51")
const BRASS := Color("c49b63")
const ROPE := Color("d2bd94")
const RUBBER := Color("29343a")


static func build(
	world, frame: Transform3D, detail: bool, palette: Array[Color], water_delta: float
) -> Dictionary:
	var root := Node3D.new()
	root.name = "HarborCinema"
	root.transform = frame
	world.add_child(root)
	var batches := {
		"PaintedContainerShells":
		_group(_bevel_box(0.012), CINEMA.material(Color.WHITE, "paint", not detail, true, true), detail),
		"CastMetalHardware":
		_group(_bevel_box(0.12), CINEMA.material(Color.WHITE, "metal", not detail, true, true), detail),
		"MooringRopes": _group(_rope_mesh(detail), _plain_material(ROPE, 0.94), false),
		"QuayFenders": _group(_fender_mesh(detail), _plain_material(RUBBER, 0.86), false),
	}
	var containers: int = _containers(batches, detail, palette, water_delta)
	_crane_hardware(batches, detail)
	var fenders: int = _mooring(batches, detail, water_delta)
	var instances: int = 0
	var triangles: int = 0
	var batch_metrics: Dictionary = {}
	for key: String in batches:
		var data: Dictionary = batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = data.mesh
		multimesh.instance_count = data.transforms.size()
		for i in range(multimesh.instance_count):
			multimesh.set_instance_transform(i, data.transforms[i])
			multimesh.set_instance_color(i, data.colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = key
		node.multimesh = multimesh
		node.material_override = data.material
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if bool(data.shadow)
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		root.add_child(node)
		instances += multimesh.instance_count
		var mesh_triangles: int = int(multimesh.mesh.get_faces().size() / 3)
		triangles += mesh_triangles * multimesh.instance_count
		batch_metrics[key] = {
			"instances": multimesh.instance_count,
			"mesh_triangles": mesh_triangles,
			"triangles": mesh_triangles * multimesh.instance_count,
		}
	var evidence := {
		"draw_batches": batches.size(),
		"instances": instances,
		"containers": containers,
		"fenders": fenders,
		"low_detail": not detail,
		"bevel_triangles": 44,
		"external_assets": 0,
		"triangles": triangles,
		"batches": batch_metrics,
	}
	root.set_meta("production_metrics", evidence)
	world.set_meta("sonnenhafen_harbor_cinema", evidence)
	return evidence


static func _group(mesh: Mesh, material: Material, shadow: bool) -> Dictionary:
	return {"mesh": mesh, "material": material, "shadow": shadow, "transforms": [], "colors": []}


static func _put(
	batches: Dictionary,
	key: String,
	at: Vector3,
	size: Vector3,
	tint: Color,
	basis: Basis = Basis.IDENTITY
) -> void:
	batches[key].transforms.append(Transform3D(basis.scaled_local(size), at))
	batches[key].colors.append(tint)


static func _at(f: float, y: float, s: float) -> Vector3:
	return Vector3(s, y, f)


static func _containers(
	batches: Dictionary, detail: bool, palette: Array[Color], water: float
) -> int:
	var heights: Array[int] = [3, 2, 1, 2, 3, 1]
	if not detail:
		heights = [2, 1, 1, 1, 2, 1]
	var count: int = 0
	var index: int = 0
	for f in [-8.2, -10.75]:
		for s in [-7.0, 0.0, 7.0]:
			for tier in range(heights[index]):
				_container(
					batches,
					_at(f, 1.3 + float(tier) * 2.62, s),
					palette[(index * 2 + tier) % palette.size()],
					detail
				)
				count += 1
			index += 1
	var bay: int = 0
	for s in [-3.4, 2.75, 8.9]:
		for f_offset in [-1.3, 1.3]:
			var tiers: int = 2 if detail or bay % 2 == 0 else 1
			for tier in range(tiers):
				_container(
					batches,
					_at(15.0 + f_offset, water + 4.1 + float(tier) * 2.62, s),
					palette[(bay + tier * 2) % palette.size()],
					detail
				)
				count += 1
			bay += 1
	return count


static func _container(batches: Dictionary, at: Vector3, tint: Color, detail: bool) -> void:
	# The 6.13m shell clears the original body and retains the existing 6.15m
	# ship-bay pitch. Door ends, dark seams and the original 288 ribs stay visible.
	_put(batches, "PaintedContainerShells", at, Vector3(6.13, 2.58, 2.53), tint)
	var levels: Array[float] = [1.18]
	if detail:
		levels = [-1.18, 1.18]
	for x in [-2.90, 2.90]:
		for y in levels:
			for z in [-1.275, 1.275]:
				_put(
					batches,
					"CastMetalHardware",
					at + Vector3(x, y, z),
					Vector3(0.28, 0.22, 0.13),
					STEEL
				)
	if not detail:
		return
	# Door locking bars are raised metal, with warm latch blocks below center.
	for end in [-3.115, 3.115]:
		for z in [-0.57, 0.57]:
			_put(
				batches,
				"CastMetalHardware",
				at + Vector3(end, 0.0, z),
				Vector3(0.075, 2.15, 0.065),
				STEEL.darkened(0.16)
			)
			_put(
				batches,
				"CastMetalHardware",
				at + Vector3(end, -0.38, z + 0.10),
				Vector3(0.10, 0.085, 0.28),
				BRASS
			)


static func _crane_hardware(batches: Dictionary, detail: bool) -> void:
	for f in [-4.0, 6.0]:
		for s in [-6.0, 6.0]:
			# Stepped bases physically meet the original wheel-bogie underside.
			_put(
				batches,
				"CastMetalHardware",
				_at(f, 0.24, s),
				Vector3(3.75, 0.18, 1.72),
				STEEL.darkened(0.27)
			)
			for y in [1.48, 5.04, 18.68]:
				_put(
					batches,
					"CastMetalHardware",
					_at(f, y, s),
					Vector3(1.25, 0.20, 1.25),
					STEEL if y > 5.0 else NAVY
				)
			if detail:
				for offset in [-0.45, 0.45]:
					for side in [-1.0, 1.0]:
						_put(
							batches,
							"CastMetalHardware",
							_at(f + side * 0.655, 5.04, s + offset),
							Vector3(0.13, 0.13, 0.12),
							BRASS
						)
	if detail:
		# Flanges turn existing solid crane chords into layered fabricated steel.
		for s in [-2.6, 2.6]:
			for y in [19.875, 20.525]:
				_put(
					batches, "CastMetalHardware", _at(8.0, y, s), Vector3(0.76, 0.075, 44.0), STEEL
				)
		for s in [-6.0, 6.0]:
			for f in [-4.0, 6.0]:
				_put(
					batches,
					"CastMetalHardware",
					_at(f, 18.45, s),
					Vector3(1.54, 0.54, 0.10),
					NAVY.lightened(0.12)
				)


static func _mooring(batches: Dictionary, detail: bool, water: float) -> int:
	var positions: Array[float] = [-10.0, 0.0, 10.0]
	if detail:
		positions = [-10.0, -5.0, 0.0, 5.0, 10.0]
	var ring_basis := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	for s in positions:
		_put(
			batches, "QuayFenders", _at(8.66, -0.30, s), Vector3.ONE * 1.12, Color.WHITE, ring_basis
		)
		_rope(batches, _at(7.95, 0.20, s - 0.25), _at(8.64, 0.28, s - 0.18), 0.026)
		_rope(batches, _at(7.95, 0.20, s + 0.25), _at(8.64, 0.28, s + 0.18), 0.026)
	for s in [-10.0, 10.0]:
		var start := _at(7.3, 0.72, s)
		var end := _at(11.67, water + 2.65, s - signf(s) * 1.35)
		var sections: int = 7 if detail else 3
		for i in range(sections):
			var a: float = float(i) / float(sections)
			var b: float = float(i + 1) / float(sections)
			_rope(batches, _sag(start, end, a), _sag(start, end, b), 0.042)
		# Deck coils have a readable silhouette even when the ship is distant.
		var segments: int = 24 if detail else 10
		for i in range(segments):
			var a: float = float(i) / float(segments)
			var b: float = float(i + 1) / float(segments)
			_rope(
				batches,
				_coil(_at(6.25, 0.115, s), a, detail),
				_coil(_at(6.25, 0.115, s), b, detail),
				0.037
			)
		_put(
			batches,
			"CastMetalHardware",
			_at(11.64, water + 2.56, s - signf(s) * 1.35),
			Vector3(0.78, 0.30, 0.12),
			BRASS.darkened(0.12)
		)
	# A pale gunwale catches the horizon light above the dark original hull.
	for f in [11.65, 18.35]:
		_put(
			batches,
			"CastMetalHardware",
			_at(f, water + 2.78, 0.0),
			Vector3(24.45, 0.10, 0.12),
			STEEL
		)
	return positions.size()


static func _sag(start: Vector3, end: Vector3, t: float) -> Vector3:
	return start.lerp(end, t) - Vector3.UP * sin(t * PI) * 0.35


static func _coil(at: Vector3, t: float, detail: bool) -> Vector3:
	var turns: float = 1.85 if detail else 0.95
	var angle: float = t * TAU * turns
	var radius: float = lerpf(0.32, 0.57, t)
	return at + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


static func _rope(batches: Dictionary, start: Vector3, end: Vector3, radius: float) -> void:
	var delta: Vector3 = end - start
	var axis: Vector3 = delta.normalized()
	var x: Vector3 = Vector3.UP.cross(axis).normalized()
	if x.length_squared() < 0.1:
		x = Vector3.RIGHT
	var basis := Basis(x, axis, x.cross(axis))
	_put(
		batches,
		"MooringRopes",
		(start + end) * 0.5,
		Vector3(radius, delta.length() + radius * 0.5, radius),
		Color.WHITE,
		basis
	)


static func _plain_material(pigment: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = pigment
	material.roughness = roughness
	material.vertex_color_use_as_albedo = true
	return material


static func _rope_mesh(detail: bool) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 7 if detail else 5
	mesh.rings = 1
	return mesh


static func _fender_mesh(detail: bool) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.29
	mesh.outer_radius = 0.55
	mesh.rings = 16 if detail else 10
	mesh.ring_segments = 7 if detail else 5
	return mesh


static func _bevel_box(bevel: float) -> ArrayMesh:
	# 6 inset faces, 12 edge chamfers and 8 corner triangles: 44 triangles.
	# Flat normals give broad, stable highlights without normal textures.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = 0.5
	var inset: float = half - bevel
	for axis in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for side in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var center: Vector3 = normal * half
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			a[u] = inset
			b[v] = inset
			_face(surface, [center - a - b, center + a - b, center + a + b, center - a + b], normal)
	for run in range(3):
		var u: int = (run + 1) % 3
		var v: int = (run + 2) % 3
		for side_u in [-1.0, 1.0]:
			for side_v in [-1.0, 1.0]:
				var normal := Vector3.ZERO
				normal[u] = side_u
				normal[v] = side_v
				var a := Vector3.ZERO
				var b := Vector3.ZERO
				a[u] = half * side_u
				a[v] = inset * side_v
				b[u] = inset * side_u
				b[v] = half * side_v
				var along := Vector3.ZERO
				along[run] = inset
				_face(surface, [a - along, a + along, b + along, b - along], normal.normalized())
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var normal := Vector3(x, y, z).normalized()
				_face(
					surface,
					[
						Vector3(half * x, inset * y, inset * z),
						Vector3(inset * x, half * y, inset * z),
						Vector3(inset * x, inset * y, half * z)
					],
					normal
				)
	return surface.commit()


static func _face(surface: SurfaceTool, points: Array, normal: Vector3) -> void:
	var reverse: bool = (
		(
			(Vector3(points[1]) - Vector3(points[0]))
			. cross(Vector3(points[2]) - Vector3(points[0]))
			. dot(normal)
		)
		> 0.0
	)
	for i in range(1, points.size() - 1):
		var indices: Array[int] = [0, i, i + 1]
		if reverse:
			indices = [0, i + 1, i]
		for index in indices:
			surface.set_normal(normal)
			surface.set_uv(Vector2(Vector3(points[index]).x, Vector3(points[index]).y))
			surface.add_vertex(points[index])
