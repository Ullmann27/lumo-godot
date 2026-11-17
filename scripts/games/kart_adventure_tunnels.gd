extends RefCounted
## Continuous, theme-specific passages built around the authoritative racing curve.
## Natural worlds descend into solid hillside cover; sky/space worlds use galleries.
## The original road, guards, collision and checkpoints remain the only driving authority.

const ROUTES = preload("res://scripts/games/kart_adventure_routes.gd")
const HALF_WIDTH := 8.15
const SHOULDER := 2.2
const ROOF := 7.6
const FOOT := -0.55
const COVER_WIDTH := 29.0

const PALETTES: Dictionary = {
	"forest": ["354f49", "65825a", "adca8b", "bce7b8", "9a73aa"],
	"sky": ["53647e", "b6c9dd", "d5b775", "b5e7f2", "b49adc"],
	"city": ["263a56", "4e657d", "8ba1b1", "6bdce8", "b78be4"],
	"crystal": ["473b60", "786a87", "bca5cb", "b8a1ed", "72cad9"],
	"jungle": ["435d50", "7b8c66", "bba676", "a4dfbd", "e9c47c"],
	"candy": ["825c79", "e2b0bb", "f4dfb8", "b4e8db", "db9fc9"],
	"volcano": ["3c3443", "635461", "968276", "efb666", "e97455"],
	"winter": ["52748e", "bfd6e4", "e4edf0", "9de1eb", "adb9e8"],
	"galaxy": ["2c3557", "586482", "a5aac7", "8dbfe9", "c29eea"],
	"desert": ["94795d", "c5a479", "e8cc9c", "93d7c4", "edbd79"],
	"lab": ["405d68", "b8cec8", "dce8db", "85d9cb", "b2a4d9"],
}


static func layout(world) -> Dictionary:
	if not ROUTES.supports(str(world.track_id)) or not world.definition.has("adventure"):
		return {}
	var profile: Dictionary = ROUTES.profile(str(world.track_id))
	var first: int = int(profile.entry_index)
	var last: int = int(profile.exit_index)
	var start: float = world.curve.get_closest_offset(world.curve.get_point_position(first))
	var finish: float = world.curve.get_closest_offset(world.curve.get_point_position(last))
	var minimum: float = INF
	for index in range(65):
		minimum = minf(minimum, world.curve.sample_baked(lerpf(start, finish, float(index) / 64.0), true).y)
	var entry_height: float = world.curve.sample_baked(start, true).y
	var exit_height: float = world.curve.sample_baked(finish, true).y
	var result: Dictionary = profile.duplicate()
	result.merge({
		"track_id": str(world.track_id), "start": start, "end": finish,
		"start_m": start, "end_m": finish, "length_m": finish - start,
		"clearance_m": SHOULDER + ROOF, "half_width_m": HALF_WIDTH,
		"entry_height_m": entry_height, "exit_height_m": exit_height,
		"floor_min_m": minimum, "descent_m": entry_height - minimum,
		"ascent_m": exit_height - minimum,
		"physical_route": "shared_curve3d", "collision_bodies_added": 0,
	}, true)
	return result


static func contains(world, distance: float, padding: float = 0.0) -> bool:
	var span: Dictionary = world.adventure_tunnel
	return not span.is_empty() and distance >= float(span.start) - padding and distance <= float(span.end) + padding


static func build(world) -> void:
	var span: Dictionary = world.adventure_tunnel
	if span.is_empty():
		return
	var root := Node3D.new()
	root.name = "AdventureTunnel"
	world.add_child(root)
	var palette: Array = PALETTES[str(span.theme)]
	var inner := SurfaceTool.new()
	var cover := SurfaceTool.new()
	var portals := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	cover.begin(Mesh.PRIMITIVE_TRIANGLES)
	portals.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: float = float(span.start)
	var finish: float = float(span.end)
	var segments: int = 12 if world.low_detail else 20
	var sections: int = maxi(2, ceili((finish - start) / (5.0 if world.low_detail else 2.6)))
	var grounded: bool = str(span.covered_type) == "hillside"
	for index in range(sections):
		var d0: float = lerpf(start, finish, float(index) / sections)
		var d1: float = lerpf(start, finish, float(index + 1) / sections)
		var ring0: PackedVector3Array = cross_section(world, d0, segments)
		var ring1: PackedVector3Array = cross_section(world, d1, segments)
		for side in range(ring0.size() - 1):
			var tint: Color = Color(palette[0]).lerp(Color(palette[1]), 0.13 + float((side + index / 3) % 3) * 0.065)
			# Inward normals are intentional; no backface switch hides inverted topology.
			_quad(inner, ring0[side], ring1[side], ring1[side + 1], ring0[side + 1], tint)
		if grounded:
			_cover_hill(cover, world, d0, d1, Color(palette[1]), start, finish)
		else:
			for side in range(ring0.size() - 1):
				var a: Vector3 = _outer(world, d0, ring0[side])
				var b: Vector3 = _outer(world, d0, ring0[side + 1])
				var c: Vector3 = _outer(world, d1, ring1[side + 1])
				var d: Vector3 = _outer(world, d1, ring1[side])
				_quad(cover, a, b, c, d, Color(palette[1]))
	_portal(portals, world, start, segments, Color(palette[2]), false)
	_portal(portals, world, finish, segments, Color(palette[2]), true)
	var technical: bool = str(span.theme) in ["city", "galaxy", "lab"]
	_mesh(root, "ContinuousInnerVault", inner, Color(palette[0]), 0.50 if technical else 0.84, 0.24 if technical else 0.0)
	_mesh(root, "SolidHillsideCover" if grounded else "GalleryOuterHull", cover, Color(palette[1]), 0.88, 0.0)
	_mesh(root, "CarvedEntranceAndExit", portals, Color(palette[2]), 0.65, 0.12 if technical else 0.0)
	var batches: Dictionary = {}
	var bays: int = maxi(6, ceili((finish - start) / (23.0 if world.low_detail else 17.0)))
	for bay in range(bays + 1):
		var along: float = lerpf(start + 1.2, finish - 1.2, float(bay) / bays)
		_rib(batches, world, along, segments, Color(palette[2]), str(span.theme), bay)
		_details(batches, world, along, str(span.theme), palette, bay)
	var instances: int = _flush(root, world, batches)
	var metrics: Dictionary = span.duplicate()
	metrics["sections"] = sections
	metrics["ring_segments"] = segments
	metrics["detail_instances"] = instances
	metrics["draw_batches"] = root.get_child_count()
	metrics["hillside_cover"] = grounded
	root.set_meta("adventure_tunnel", metrics)
	world.set_meta("adventure_tunnel", metrics)


static func cross_section(world, distance: float, segments: int) -> PackedVector3Array:
	var at: Vector3 = world.position_at(distance)
	var basis: Basis = world.frame(distance)
	var theme: String = str(world.adventure_tunnel.theme)
	var points := PackedVector3Array([at - basis.x * HALF_WIDTH + basis.y * FOOT])
	for index in range(segments + 1):
		var angle: float = PI * (1.0 - float(index) / segments)
		var x: float = cos(angle) * HALF_WIDTH
		var y: float = SHOULDER + sin(angle) * ROOF
		if theme in ["city", "lab"]:
			# A broad, bevelled transit/laboratory gallery, distinct from the caves.
			y = SHOULDER + minf(1.0, sin(angle) * 1.35) * ROOF
		elif theme == "sky":
			y += pow(sin(angle), 5.0) * 1.4
		elif theme in ["crystal", "volcano", "forest", "jungle"]:
			# Outward-only relief retains the complete smooth driving envelope.
			var relief: float = 0.15 + 0.30 * (0.5 + 0.5 * sin(distance * 0.11 + index * 1.7))
			x *= 1.0 + relief * 0.025
			y += relief * sin(angle)
		points.append(at + basis.x * x + basis.y * y)
	points.append(at + basis.x * HALF_WIDTH + basis.y * FOOT)
	return points


static func _outer(world, distance: float, inner: Vector3) -> Vector3:
	var basis: Basis = world.frame(distance)
	var at: Vector3 = world.position_at(distance)
	var local: Vector3 = basis.inverse() * (inner - at)
	local.x *= 1.11
	local.y += 0.85
	return at + basis * local


static func _cover_row(world, distance: float, start: float, finish: float) -> PackedVector3Array:
	var basis: Basis = world.frame(distance)
	var center: Vector3 = world.position_at(distance)
	var segments: int = 12 if world.low_detail else 20
	var ring: PackedVector3Array = cross_section(world, distance, segments)
	var result := PackedVector3Array()
	for index in range(ring.size()):
		var local: Vector3 = basis.inverse() * (ring[index] - center)
		var across: float = clampf(local.x / (HALF_WIDTH * 1.02), -1.0, 1.0) * COVER_WIDTH
		var location: Vector3 = center + basis.x * across
		var ground_y: float = -2.0
		if str(world.track_id) == "zauberwald":
			ground_y = world._ground_height(location.x, location.z)
		var radius: float = absf(across) / COVER_WIDTH
		var fullness: float = pow(maxf(0.0, 1.0 - radius * radius), 1.35)
		# The broad cap is at least 3.4 m above the centre vault. Its inner
		# shoulders remain above every wall even on the descending road.
		var roof_y: float = center.y + SHOULDER + ROOF + 3.4
		location.y = lerpf(ground_y - 0.15, roof_y, fullness)
		if index == 0 or index == ring.size() - 1:
			location.y = ground_y - 0.7
		result.append(location)
	return result


static func _cover_hill(surface: SurfaceTool, world, d0: float, d1: float, color: Color,
		start: float, finish: float) -> void:
	var a: PackedVector3Array = _cover_row(world, d0, start, finish)
	var b: PackedVector3Array = _cover_row(world, d1, start, finish)
	for index in range(a.size() - 1):
		var tint: Color = color.lightened(0.045 if index in [2, 3] else 0.0)
		_quad(surface, a[index], a[index + 1], b[index + 1], b[index], tint)


static func _portal(surface: SurfaceTool, world, distance: float, segments: int, color: Color, reverse: bool) -> void:
	var ring: PackedVector3Array = cross_section(world, distance, segments)
	var hillside: PackedVector3Array = _cover_row(world, distance, 0.0, 0.0) if str(world.adventure_tunnel.covered_type) == "hillside" else PackedVector3Array()
	for index in range(ring.size() - 1):
		var a: Vector3 = ring[index]
		var b: Vector3 = ring[index + 1]
		var c: Vector3 = hillside[index + 1] if not hillside.is_empty() else _outer(world, distance, b)
		var d: Vector3 = hillside[index] if not hillside.is_empty() else _outer(world, distance, a)
		if reverse:
			_quad(surface, d, c, b, a, color)
		else:
			_quad(surface, a, b, c, d, color)


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for points: Array in [[a, b, c], [a, c, d]]:
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
		surface.set_normal(normal)
		surface.set_color(color)
		# Godot's visible front faces are clockwise. The cross product above
		# deliberately authors the lighting normal; reverse emitted winding.
		for index in [0, 2, 1]:
			surface.add_vertex(points[index])


static func _mesh(parent: Node3D, name: String, surface: SurfaceTool, color: Color, roughness: float, metal: float) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = roughness
	material.metallic = metal
	node.material_override = material
	# Existing world ambient illumination keeps road readability on mobile.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func _put(batches: Dictionary, kind: String, at: Vector3, size: Vector3, color: Color,
		basis: Basis = Basis.IDENTITY, glow: bool = false) -> void:
	var key: String = kind + ":" + color.to_html() + (":light" if glow else ":solid")
	if not batches.has(key):
		batches[key] = {"kind": kind, "color": color, "glow": glow, "transforms": []}
	batches[key].transforms.append(Transform3D(basis.scaled_local(size), at))


static func _beam(batches: Dictionary, a: Vector3, b: Vector3, thickness: float, color: Color, glow: bool = false) -> void:
	var direction: Vector3 = b - a
	var rotation := Quaternion(Vector3.UP, direction.normalized())
	_put(batches, "cylinder", (a + b) * 0.5, Vector3(thickness, direction.length(), thickness), color, Basis(rotation), glow)


static func _rib(batches: Dictionary, world, distance: float, segments: int, color: Color, theme: String, bay: int) -> void:
	var ring: PackedVector3Array = cross_section(world, distance, segments)
	var width: float = 0.13 if theme in ["city", "galaxy", "lab"] else 0.21
	for index in range(ring.size() - 1):
		_beam(batches, ring[index], ring[index + 1], width, color)
	if theme in ["city", "galaxy", "lab", "sky"]:
		var basis: Basis = world.frame(distance)
		for side in [-1.0, 1.0]:
			var at: Vector3 = world.position_at(distance, side * 7.75) + basis.y * 3.8
			_put(batches, "box", at, Vector3(0.12, 0.45, 5.3), Color(PALETTES[theme][3]), basis, true)
	if theme == "candy":
		for index in range(1, ring.size() - 1, 3):
			_put(batches, "ball", ring[index], Vector3.ONE * 0.29,
				Color(PALETTES[theme][3 if (index + bay) % 2 else 4]))


static func _details(batches: Dictionary, world, distance: float, theme: String, palette: Array, bay: int) -> void:
	var basis: Basis = world.frame(distance)
	var stone := Color(palette[1])
	var trim := Color(palette[2])
	var light := Color(palette[3])
	var second := Color(palette[4])
	for side in [-1.0, 1.0]:
		var at: Vector3 = world.position_at(distance, side * 7.35)
		# Every object stays beyond the guardrail; no collider or obstacle is invented.
		_put(batches, "box", at + basis.y * 0.35, Vector3(0.65, 0.7, 2.5), stone, basis)
		match theme:
			"crystal", "winter":
				for shard in range(3):
					var pos: Vector3 = at + basis.z * (shard - 1) * 0.72 + basis.y * (1.25 + shard * 0.3)
					_put(batches, "crystal", pos, Vector3(0.38, 1.20 + shard * 0.30, 0.42), light if shard % 2 else second, basis, shard == 1)
			"forest", "jungle":
				_beam(batches, at + basis.y * 0.5, at + basis.y * 4.7 + basis.x * side * 0.1, 0.32, trim)
				for leaf in range(3):
					_put(batches, "crown", at - basis.x * side * 0.4 + basis.y * (3.8 + leaf * 0.5) + basis.z * (leaf - 1) * 0.5,
						Vector3(0.45, 0.30, 0.76), stone.lightened(0.17), basis)
				if theme == "forest":
					_put(batches, "cylinder", at + basis.y * 1.1, Vector3(0.16, 0.9, 0.16), trim, basis)
					_put(batches, "crown", at + basis.y * 1.6, Vector3(0.63, 0.24, 0.63), second, basis)
					# Recessed root shelves turn this passage into a readable forest library.
					for shelf in range(2):
						_put(batches, "box", at + basis.y * (2.0 + shelf * 0.85), Vector3(0.72, 0.10, 1.9), trim, basis)
						for book in range(5):
							var book_at: Vector3 = at - basis.x * side * 0.26 + basis.z * (float(book) - 2.0) * 0.30 + basis.y * (2.35 + shelf * 0.85)
							_put(batches, "box", book_at, Vector3(0.23, 0.54 + float(book % 2) * 0.08, 0.20), light if book % 3 == 0 else second, basis)
				else:
					_put(batches, "box", at + basis.y * 2.0, Vector3(0.60, 2.8, 0.95), stone, basis)
					for glyph in range(3):
						_put(batches, "box", at - basis.x * side * 0.32 + basis.y * (1.2 + glyph * 0.67), Vector3(0.08, 0.19, 0.6), light, basis, true)
			"volcano":
				_put(batches, "rock", at + basis.y * 2.1, Vector3(0.67, 3.9, 1.5), stone, basis)
				_put(batches, "box", at - basis.x * side * 0.42 + basis.y * 0.8,
					Vector3(0.16, 0.18, 8.0), second, basis, true)
				_put(batches, "crystal", at + basis.y * 3.7, Vector3(0.3, 1.6, 0.3), light, basis, true)
			"desert":
				_put(batches, "cylinder", at + basis.y * 2.3, Vector3(0.45, 4.0, 0.45), stone, basis)
				_put(batches, "box", at + basis.y * 4.1, Vector3(0.95, 0.30, 1.1), trim, basis)
				_put(batches, "star", at - basis.x * side * 0.55 + basis.y * 3.4, Vector3.ONE * 0.35, light, basis, true)
			"candy":
				_put(batches, "cylinder", at + basis.y * 2.1, Vector3(0.34, 3.5, 0.34), trim, basis)
				_put(batches, "torus", at + basis.y * 4.0, Vector3.ONE * 1.1, second, basis)
				for stripe in range(4):
					_put(batches, "cylinder", at + basis.y * (0.8 + stripe * 0.75), Vector3(0.36, 0.19, 0.36), second, basis)
			"lab":
				_put(batches, "box", at + basis.y * 2.3, Vector3(0.7, 2.8, 1.6), trim, basis)
				for atom in range(3):
					var pos: Vector3 = at - basis.x * side * 0.4 + basis.y * (1.4 + atom * 0.72) + basis.z * (0.34 if atom % 2 else -0.34)
					_put(batches, "ball", pos, Vector3.ONE * 0.22, light if atom % 2 else second, basis, true)
			"galaxy":
				_put(batches, "torus", at + basis.y * 3.6, Vector3.ONE * 1.3, trim, basis)
				_put(batches, "ball", at + basis.y * 3.6, Vector3.ONE * 0.42, second, basis)
				_put(batches, "star", at - basis.x * side * 0.55 + basis.y * 5.8, Vector3.ONE * 0.32, light, basis, true)
			"sky":
				_put(batches, "crown", at + basis.y * 0.75, Vector3(0.55, 0.45, 1.2), trim, basis)
				_put(batches, "star", at + basis.y * 3.6, Vector3.ONE * 0.6, light, basis, true)
				_put(batches, "crystal", at - basis.x * side * 0.45 + basis.y * 3.7, Vector3(0.3, 1.05, 0.35), second, basis)
			"city":
				_put(batches, "box", at + basis.y * 3.0, Vector3(0.52, 5.5, 0.7), trim, basis)
				for line in range(3):
					_put(batches, "box", at - basis.x * side * 0.28 + basis.y * (1.8 + line * 0.85),
						Vector3(0.05, 0.20, 0.78 + line * 0.23), light if (line + bay) % 2 else second, basis, true)
		_put(batches, "ball", at - basis.x * side * 0.55 + basis.y * 5.9, Vector3.ONE * 0.14, light, basis, true)


static func _flush(parent: Node3D, world, batches: Dictionary) -> int:
	var total: int = 0
	var index: int = 0
	for batch: Dictionary in batches.values():
		var data := MultiMesh.new()
		data.transform_format = MultiMesh.TRANSFORM_3D
		data.mesh = world._shape(str(batch.kind))
		data.instance_count = batch.transforms.size()
		for instance in range(data.instance_count):
			data.set_instance_transform(instance, batch.transforms[instance])
		var node := MultiMeshInstance3D.new()
		node.name = "Theme_%02d_%s" % [index, batch.kind]
		node.multimesh = data
		node.material_override = world._material(batch.color, bool(batch.glow))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		total += data.instance_count
		index += 1
	return total
