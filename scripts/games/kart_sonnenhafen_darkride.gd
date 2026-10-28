extends RefCounted
## Lumo Kart Sonnenhafen: playable, deterministic dark-ride geometry.
## Visual only: no physics body, no changed checkpoints, road or saved progress.
## One shell + one road overlay + two MultiMeshes; scales down on low-detail.
const GEOLOGY = preload("res://scripts/games/kart_cavern_geology.gd")
const SHADER = preload("res://assets/shaders/kart_sonnenhafen_darkride.gdshader")
const START_FRACTION: float = 0.690
const END_FRACTION: float = 0.800
const HALF_TUNNEL_WIDTH: float = 7.85
const INNER_ROAD_HALF_WIDTH: float = 5.37
const WALL_SHOULDER_HEIGHT: float = 1.75
const CEILING_RADIUS: float = 7.25
const FOOT_DROP: float = 0.35
const RIB_INTERVAL: float = 19.0

static func is_supported(world) -> bool:
	return world.track_id == "sonnenhafen" and world.length > 1500.0

static func metrics_for(world) -> Dictionary:
	return {
		"start_m": world.length * START_FRACTION,
		"end_m": world.length * END_FRACTION,
		"length_m": world.length * (END_FRACTION - START_FRACTION),
		"inside_road_width_m": INNER_ROAD_HALF_WIDTH * 2.0,
		"tunnel_clearance_m": WALL_SHOULDER_HEIGHT + CEILING_RADIUS,
	}

static func build(world) -> void:
	if not is_supported(world):
		return
	var old: Node = world.get_node_or_null("SonnenhafenBioluminescentDarkride")
	if old != null:
		world.remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = "SonnenhafenBioluminescentDarkride"
	world.add_child(root)
	var low: bool = world.low_detail
	var metrics: Dictionary = metrics_for(world)
	var from_m: float = float(metrics["start_m"])
	var to_m: float = float(metrics["end_m"])
	var longitudinal_step: float = 5.0 if low else 2.8
	var ring_segments: int = 10 if low else 16
	var sections: int = ceili((to_m - from_m) / longitudinal_step)

	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var overlay := SurfaceTool.new()
	overlay.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(sections):
		var d0: float = lerpf(from_m, to_m, float(i) / float(sections))
		var d1: float = lerpf(from_m, to_m, float(i + 1) / float(sections))
		var ring0: Array[Vector3] = _ring(world, d0, ring_segments)
		var ring1: Array[Vector3] = _ring(world, d1, ring_segments)
		var alpha0: float = _fade(d0, from_m, to_m)
		var alpha1: float = _fade(d1, from_m, to_m)
		for j in range(ring_segments + 2):
			var u0: float = float(j) / float(ring_segments + 2)
			var u1: float = float(j + 1) / float(ring_segments + 2)
			_tri(shell, ring0[j], ring1[j], ring1[j + 1],
				Vector2(u0, d0 * 0.042), Vector2(u0, d1 * 0.042),
				Vector2(u1, d1 * 0.042), alpha0, alpha1, alpha1)
			_tri(shell, ring0[j], ring1[j + 1], ring0[j + 1],
				Vector2(u0, d0 * 0.042), Vector2(u1, d1 * 0.042),
				Vector2(u1, d0 * 0.042), alpha0, alpha1, alpha0)
		var b0: Basis = world.frame(d0)
		var b1: Basis = world.frame(d1)
		var mid0: Vector3 = world.position_at(d0) + b0.y * 0.045
		var mid1: Vector3 = world.position_at(d1) + b1.y * 0.045
		var left0: Vector3 = mid0 - b0.x * INNER_ROAD_HALF_WIDTH
		var right0: Vector3 = mid0 + b0.x * INNER_ROAD_HALF_WIDTH
		var left1: Vector3 = mid1 - b1.x * INNER_ROAD_HALF_WIDTH
		var right1: Vector3 = mid1 + b1.x * INNER_ROAD_HALF_WIDTH
		_tri(overlay, left0, right0, right1,
			Vector2(-1.0, d0 * 0.04), Vector2(1.0, d0 * 0.04),
			Vector2(1.0, d1 * 0.04), alpha0, alpha0, alpha1)
		_tri(overlay, left0, right1, left1,
			Vector2(-1.0, d0 * 0.04), Vector2(1.0, d1 * 0.04),
			Vector2(-1.0, d1 * 0.04), alpha0, alpha1, alpha1)

	# Solid-looking carved lips close the exposed paper-thin ends of the shell.
	# Their entire inner edge is the original clear tunnel cross-section.
	_portal_lip(shell, world, from_m, ring_segments, false)
	_portal_lip(shell, world, to_m, ring_segments, true)
	_shell_instance(root, "DarkrideRockAndCanopy", shell.commit(), 0.0, low)
	_shell_instance(root, "DarkrideIlluminatedRoad", overlay.commit(), 1.0, low)
	var road_mesh: MeshInstance3D = root.get_node("DarkrideIlluminatedRoad")
	var flow_sections: int = _flow_channels(road_mesh, world, from_m, to_m, low)
	var arch_count: int = maxi(4, floori((to_m - from_m) / RIB_INTERVAL))
	var arc_ribs: int = _make_ribs(root, world, from_m, to_m, ring_segments, arch_count)
	var light_count: int = _make_crystals(root, world, from_m, to_m, arch_count, low)
	GEOLOGY.build(root, world, from_m, to_m)
	metrics["shell_sections"] = sections
	metrics["ring_segments"] = ring_segments
	metrics["arch_rib_instances"] = arc_ribs
	metrics["crystal_instances"] = light_count
	metrics["flow_sections"] = flow_sections
	metrics["flow_inner_edge_m"] = 5.85
	metrics["collision_bodies_added"] = 0
	metrics["surface_count"] = 4
	root.set_meta("darkride_metrics", metrics)
	world.set_meta("sonnenhafen_darkride", metrics)

## Wasser und Fantasie-Lava links/rechts der Fahrbahn, nicht in der Fahrspur.
## Ein einziges echtes 3D-Mesh, dasselbe kontrollierte ShaderMaterial und keine
## zusätzlichen Lichtquellen oder Kollisionskörper. TIME wird nicht benutzt.
static func _flow_channels(parent: MeshInstance3D, world, from_m: float,
		to_m: float, low: bool) -> int:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = 5.0 if low else 2.5
	var sections: int = ceili((to_m - from_m) / step)
	for section in range(sections):
		var d0: float = lerpf(from_m, to_m, float(section) / float(sections))
		var d1: float = lerpf(from_m, to_m, float(section + 1) / float(sections))
		for side in [-1.0, 1.0]:
			var b0: Basis = world.frame(d0)
			var b1: Basis = world.frame(d1)
			var inner: float = 5.85 * side
			var outer: float = 7.55 * side
			var p00: Vector3 = world.position_at(d0) + b0.x * inner + b0.y * 0.08
			var p01: Vector3 = world.position_at(d0) + b0.x * outer + b0.y * 0.08
			var p10: Vector3 = world.position_at(d1) + b1.x * inner + b1.y * 0.08
			var p11: Vector3 = world.position_at(d1) + b1.x * outer + b1.y * 0.08
			var tag: Color = Color(0.0, 1.0, 1.0, 1.0) if side < 0.0 else Color(1.0, 1.0, 0.0, 1.0)
			var uv0: float = d0 * 0.16
			var uv1: float = d1 * 0.16
			_flow_tri(surface, [p00, p01, p11], [Vector2(0, uv0), Vector2(1, uv0), Vector2(1, uv1)], tag)
			_flow_tri(surface, [p00, p11, p10], [Vector2(0, uv0), Vector2(1, uv1), Vector2(0, uv1)], tag)
	var instance := MeshInstance3D.new()
	instance.name = "DarkrideWaterAndLavaFlow"
	instance.mesh = surface.commit()
	instance.material_override = parent.material_override
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return sections


static func _flow_tri(surface: SurfaceTool, points: Array[Vector3],
		uvs: Array[Vector2], tag: Color) -> void:
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	surface.set_normal(normal)
	surface.set_color(tag)
	for i in range(3):
		surface.set_uv(uvs[i])
		surface.add_vertex(points[i])


static func _fade(d: float, from_m: float, to_m: float) -> float:
	return minf(smoothstep(from_m, from_m + 16.0, d),
		1.0 - smoothstep(to_m - 16.0, to_m, d))

static func _ring(world, distance: float, segments: int) -> Array[Vector3]:
	var at: Vector3 = world.position_at(distance)
	var basis: Basis = world.frame(distance)
	var cross_section: Array[Vector2] = [Vector2(-HALF_TUNNEL_WIDTH, -FOOT_DROP)]
	for j in range(segments + 1):
		var angle: float = PI * (1.0 - float(j) / float(segments))
		cross_section.append(Vector2(
			cos(angle) * HALF_TUNNEL_WIDTH,
			WALL_SHOULDER_HEIGHT + sin(angle) * CEILING_RADIUS
		))
	cross_section.append(Vector2(HALF_TUNNEL_WIDTH, -FOOT_DROP))
	var result: Array[Vector3] = []
	for index in range(cross_section.size()):
		var point: Vector2 = cross_section[index]
		# Outward-only rock folds keep the complete original driving envelope.
		if index > 0 and index < cross_section.size() - 1:
			var fold: float = 0.35 + 0.6 * (0.5 + 0.5 * sin(distance * 0.19 + float(index) * 2.1))
			point.x *= 1.0 + fold * 0.07
			point.y += fold * (0.4 + 0.6 * sin(PI * float(index) / float(cross_section.size() - 1)))
		result.append(at + basis.x * point.x + basis.y * point.y)
	return result

static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		uv_a: Vector2, uv_b: Vector2, uv_c: Vector2,
		alpha_a: float, alpha_b: float, alpha_c: float) -> void:
	# Actual inward-facing geometry normals support cinematic relief without
	# evaluating screen derivatives on every cave fragment (including mobile).
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	surface.set_normal(normal)
	for vertex in [
		{"position": a, "uv": uv_a, "alpha": alpha_a},
		{"position": b, "uv": uv_b, "alpha": alpha_b},
		{"position": c, "uv": uv_c, "alpha": alpha_c}
	]:
		surface.set_color(Color(1.0, 1.0, 1.0, vertex.alpha))
		surface.set_uv(vertex.uv)
		surface.add_vertex(vertex.position)


static func _portal_lip(surface: SurfaceTool, world, distance: float,
		segments: int, exit_portal: bool) -> void:
	var inner: Array[Vector3] = _ring(world, distance, segments)
	var frame: Basis = world.frame(distance)
	var center: Vector3 = world.position_at(distance)
	var outer: Array[Vector3] = []
	for i in range(inner.size()):
		var local: Vector3 = frame.inverse() * (inner[i] - center)
		local.x *= 1.17 + sin(float(i) * 1.9) * 0.025
		local.y += 1.0 + 0.25 * sin(float(i) * 2.3)
		if i == 0 or i == inner.size() - 1:
			local.y = -0.8
		outer.append(center + frame * local)
	for i in range(inner.size() - 1):
		var u: float = float(i) / float(inner.size() - 1)
		var v: float = distance * 0.042
		if exit_portal:
			_tri(surface, inner[i], outer[i + 1], outer[i],
				Vector2(u, v), Vector2(u + 0.08, v + 0.6), Vector2(u, v + 0.6), 1.0, 1.0, 1.0)
			_tri(surface, inner[i], inner[i + 1], outer[i + 1],
				Vector2(u, v), Vector2(u + 0.08, v), Vector2(u + 0.08, v + 0.6), 1.0, 1.0, 1.0)
		else:
			_tri(surface, inner[i], outer[i], outer[i + 1],
				Vector2(u, v), Vector2(u, v + 0.6), Vector2(u + 0.08, v + 0.6), 1.0, 1.0, 1.0)
			_tri(surface, inner[i], outer[i + 1], inner[i + 1],
				Vector2(u, v), Vector2(u + 0.08, v + 0.6), Vector2(u + 0.08, v), 1.0, 1.0, 1.0)

static func _shell_instance(parent: Node3D, name: String, mesh: ArrayMesh,
		road_factor: float, low_detail: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("road_factor", road_factor)
	material.set_shader_parameter("mobile_detail", low_detail)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

static func _make_ribs(parent: Node3D, world,
		from_m: float, to_m: float, ring_segments: int, arch_count: int) -> int:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var beam := BoxMesh.new()
	beam.size = Vector3(0.14, 1.0, 0.23)
	mm.mesh = beam
	mm.instance_count = arch_count * ring_segments
	var current: int = 0
	for arch in range(arch_count):
		var d: float = lerpf(from_m + 8.0, to_m - 8.0,
			float(arch) / float(maxi(1, arch_count - 1)))
		var ring: Array[Vector3] = _ring(world, d, ring_segments)
		for j in range(1, ring_segments + 1):
			var a: Vector3 = ring[j]
			var b: Vector3 = ring[j + 1]
			var along: Vector3 = b - a
			var basis: Basis = Basis(Quaternion(Vector3.UP, along.normalized()))
			mm.set_instance_transform(current, Transform3D(
				basis.scaled_local(Vector3(1.0, along.length(), 1.0)), (a + b) * 0.5
			))
			mm.set_instance_color(current,
				Color("52f5ef") if arch % 3 != 1 else Color("f6cf7e"))
			current += 1
	var node := MultiMeshInstance3D.new()
	node.name = "DarkrideNeonArchRibs"
	node.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.emission_enabled = true
	mat.emission = Color("42d9ed")
	mat.emission_energy_multiplier = 1.6
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return current

static func _make_crystals(parent: Node3D, world,
		from_m: float, to_m: float, arch_count: int, low: bool) -> int:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.65
	crystal.height = 1.0
	crystal.radial_segments = 5 if low else 7
	mm.mesh = crystal
	mm.instance_count = arch_count * 2
	for index in range(arch_count):
		var d: float = lerpf(from_m + 8.0, to_m - 8.0,
			float(index) / float(maxi(1, arch_count - 1)))
		var basis: Basis = world.frame(d)
		for side_index in range(2):
			var side: float = -1.0 if side_index == 0 else 1.0
			var at: Vector3 = world.position_at(d, side * 7.65) + basis.y * 2.3
			mm.set_instance_transform(index * 2 + side_index,
				Transform3D(basis.scaled_local(Vector3(0.78, 2.5, 0.78)), at))
			mm.set_instance_color(index * 2 + side_index,
				Color("a26eff") if side_index == 0 else Color("63f5ed"))
	var node := MultiMeshInstance3D.new()
	node.name = "DarkrideCrystalLanterns"
	node.multimesh = mm
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.emission_enabled = true
	material.emission = Color("7ae9ec")
	material.emission_energy_multiplier = 2.0
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return mm.instance_count
