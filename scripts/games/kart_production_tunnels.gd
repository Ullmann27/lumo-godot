extends Node3D
## Real road-following Blender tunnels, hollow physics, bounded lights and mobile LOD.
const LAYOUT = preload("res://scripts/games/kart_production_tunnel_layout.gd")
const GEOMETRY = preload("res://scripts/games/kart_production_tunnel_mesh.gd")
const GUIDANCE = preload("res://scripts/games/kart_production_guidance.gd")
const COLLISION_LAYER: int = 1 << 20
## Origin is the same road-contact/feet origin as kart_island.player.position.
const BODY_RADIUS: float = 0.85
const BODY_HEIGHT: float = 2.0
const BODY_CENTER := Vector3(0, BODY_HEIGHT * 0.5, 0)
const CAMERA_RADIUS: float = 0.20
const CONTACT_MARGIN: float = 0.015

var race_world
var layout: Dictionary = {}
var modules: Array[Node3D] = []
var light_mounts: Array[Marker3D] = []
var light_pool: Array[OmniLight3D] = []
var collision_bodies: Array[StaticBody3D] = []
var statistics: Dictionary = {}
var guidance
var _curve_map = GEOMETRY.CurveMap.new()
var _scenes: Dictionary = {}
var _materials: Dictionary = {}
var _collision_bounds := AABB()
var _capsule := CapsuleShape3D.new()
var _camera_shape := SphereShape3D.new()
var _light_time: float = 0.0


func build(world, selected_layout: Dictionary) -> bool:
	race_world = world
	layout = selected_layout
	name = "ProductionBlenderTunnel"
	_curve_map.setup(world, float(layout.start), float(layout.end))
	_capsule.radius = BODY_RADIUS
	_capsule.height = BODY_HEIGHT
	_camera_shape.radius = CAMERA_RADIUS
	_collision_bounds = AABB(_curve_map.frames[0].origin, Vector3.ZERO)
	for frame in _curve_map.frames:
		_collision_bounds = _collision_bounds.expand(frame.origin)
	_collision_bounds = _collision_bounds.grow(15.0)
	statistics = {"theme": str(world.track_id), "start": layout.start, "end": layout.end,
		"module_count": layout.modules.size(), "triangles": 0, "collision_triangles": 0,
		"low_detail": bool(world.low_detail), "body_radius": BODY_RADIUS, "body_height": BODY_HEIGHT,
		"collision_layer": COLLISION_LAYER, "runtime_deformation": "Existing baked road curve and bank frame; once during build"}
	for index in layout.modules.size():
		var spec: Dictionary = layout.modules[index]
		if not _build_module(index, spec):
			return false
	_build_ground_aprons()
	guidance = GUIDANCE.new()
	add_child(guidance)
	if not guidance.build(world, layout, _curve_map):
		return false
	statistics["guidance"] = guidance.statistics.duplicate(true)
	# The basalt tunnel needs more local fill beneath the existing ACES
	# night grade. Preserve the original lighting of all other themes.
	var basalt: bool = str(world.track_id) == "volcano_night"
	var light_energy: float = 4.8 if basalt else 1.6
	var light_range: float = 15.0 if basalt else 11.0
	var attenuation: float = 0.60 if basalt else 0.80
	for index in range(3 if world.low_detail else 4):
		var light := OmniLight3D.new()
		light.name = "TunnelLightPool_%02d" % index
		light.omni_range = light_range
		light.omni_attenuation = attenuation
		light.light_energy = light_energy
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		light_pool.append(light)
	statistics["light_mounts"] = light_mounts.size()
	statistics["maximum_live_lights"] = light_pool.size()
	statistics["light_pool_profile"] = {"energy": light_energy, "range_m": light_range,
		"attenuation": attenuation, "shadows": false,
		"socket_color_warm_white_mix": 0.65 if basalt else 0.0}
	statistics["shared_materials"] = _materials.size()
	set_meta("production_tunnel", statistics)
	world.set_meta("production_tunnel", statistics.duplicate())
	_scenes.clear()
	return true


func _scene(kind: String, suffix: String) -> PackedScene:
	var path: String = "res://assets/kart/production/tracks/%s/%s%s.glb" % [race_world.track_id, kind, suffix]
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene
	if _scenes[path] == null:
		push_error("Missing imported production tunnel: " + path)
	return _scenes[path] as PackedScene


func _build_module(index: int, spec: Dictionary) -> bool:
	var kind: String = str(spec.kind)
	var start: float = float(spec.start)
	var assembly := Node3D.new()
	assembly.name = "Module_%02d_%s" % [index, kind]
	assembly.set_meta("road_start", start)
	assembly.set_meta("road_end", start + float(spec.length))
	assembly.set_meta("module_kind", kind)
	add_child(assembly)
	modules.append(assembly)
	var levels: Array[int] = [1]
	if not race_world.low_detail:
		levels.push_front(0)
	for level in levels:
		for terrain in [false, true]:
			var suffix: String = ("_terrain" if terrain else "") + ("_lod1" if level == 1 else "")
			var source: PackedScene = _scene(kind, suffix)
			if source == null:
				return false
			var built: Dictionary = GEOMETRY.make_visible(source, _curve_map, start, _materials)
			var model: Node3D = built.node
			model.name = ("Terrain" if terrain else "Core") + "LOD" + str(level)
			model.set_meta("source_asset", "assets/kart/production/tracks/%s/%s%s.glb" % [race_world.track_id, kind, suffix])
			assembly.add_child(model)
			statistics.triangles += int(built.triangles)
			for mesh in built.meshes:
				mesh.visibility_range_begin = 0.0 if level == 0 or race_world.low_detail else 65.0
				mesh.visibility_range_end = 65.0 if level == 0 else (170.0 if race_world.low_detail else 225.0)
				mesh.visibility_range_begin_margin = 0.0
				mesh.visibility_range_end_margin = 0.0
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if not terrain and level == levels[0]:
				for marker in built.markers:
					if bool(marker.get_meta("lumo_light_socket", false)):
						light_mounts.append(marker as Marker3D)
	var proxy: PackedScene = _scene(kind, "_collision")
	if proxy == null:
		return false
	var collision: StaticBody3D = GEOMETRY.make_collision(proxy, _curve_map, start, COLLISION_LAYER)
	assembly.add_child(collision)
	collision_bodies.append(collision)
	statistics.collision_triangles += int(collision.get_meta("triangle_count"))
	return true


func _build_ground_aprons() -> void:
	# Floating islands/stations keep their closed authored geological/deck underside.
	# Ordinary land receives an actual sloped join to its existing terrain surface.
	if race_world.track_id in ["bergwelt", "holo_city", "candy_cloud", "galaxy_ringway"]:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = ceili(float(layout.length))
	var ground_color: Color = race_world.definition.ground
	for side in [-1.0, 1.0]:
		for index in count:
			var d0: float = float(layout.start) + float(index) * float(layout.length) / count
			var d1: float = float(layout.start) + float(index + 1) * float(layout.length) / count
			var points: Array[Vector3] = []
			for distance in [d0, d1]:
				var radius: float = _outer_radius(distance)
				var frame: Transform3D = _curve_map.sample(distance)
				var inner: Vector3 = frame.origin + frame.basis.x * side * (radius - 0.05) - frame.basis.y * 0.16
				var outer: Vector3 = frame.origin + frame.basis.x * side * (radius + 6.5)
				outer.y = race_world._ground_height(outer.x, outer.z) - 0.03 if race_world.track_id == "zauberwald" else -2.03
				points.append(inner)
				points.append(outer)
			for corner in ([0, 2, 1, 1, 2, 3] if side > 0 else [0, 1, 2, 1, 3, 2]):
				surface.set_color(ground_color)
				surface.add_vertex(points[corner])
	surface.generate_normals()
	var apron := MeshInstance3D.new()
	apron.name = "TunnelGroundAprons"
	apron.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	apron.material_override = material
	add_child(apron)
	statistics["terrain_apron_triangles"] = count * 4


func _outer_radius(distance: float) -> float:
	var from_entry: float = distance - float(layout.start)
	var to_exit: float = float(layout.end) - distance
	var fade: float = 1.0
	if from_entry < 4.0:
		fade = smoothstep(0.0, 4.0, from_entry)
	elif to_exit < 4.0:
		fade = smoothstep(0.0, 4.0, to_exit)
	return lerpf(9.7, 14.2, fade)


func _process(delta: float) -> void:
	_light_time += delta
	if _light_time < 0.12 or not is_inside_tree():
		return
	_light_time = 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	update_light_focus(race_world.to_local(camera.global_position))


func update_light_focus(point: Vector3) -> void:
	var candidates: Array[Dictionary] = []
	for marker in light_mounts:
		var at: Vector3 = race_world.to_local(marker.global_position)
		var square: float = at.distance_squared_to(point)
		if square < 26.0 * 26.0:
			candidates.append({"marker": marker, "square": square})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.square) < float(b.square))
	for index in light_pool.size():
		var light: OmniLight3D = light_pool[index]
		light.visible = index < candidates.size()
		if not light.visible:
			continue
		var marker: Marker3D = candidates[index].marker
		light.global_position = marker.global_position
		var color_value: Variant = marker.get_meta("light_color_srgb", "d8eadf")
		light.light_color = Color(str(color_value)) if color_value is String else Color("d8eadf")
		if str(race_world.track_id) == "volcano_night":
			light.light_color = light.light_color.lerp(Color("ffe4c0"), 0.65)


func resolve_motion(from: Vector3, desired: Vector3) -> Dictionary:
	var result: Dictionary = {"position": desired, "normal": Vector3.ZERO, "collided": false}
	if not _relevant_segment(from, desired):
		return result
	var current: Vector3 = from
	var target: Vector3 = desired
	for iteration in range(2):
		var hit: Dictionary = _sweep(current, target, _capsule, BODY_CENTER)
		if not bool(hit.collided):
			result.position = target
			return result
		result.collided = true
		result.normal = hit.normal
		result.position = hit.position
		var remaining: Vector3 = (target - (hit.position as Vector3)).slide(hit.normal)
		current = hit.position
		target = current + remaining
		if remaining.length_squared() < 0.000001:
			break
	return result


func clip_camera(anchor: Vector3, desired: Vector3) -> Vector3:
	if not _relevant_segment(anchor, desired):
		return desired
	return _sweep(anchor, desired, _camera_shape, Vector3.ZERO).position


func _relevant_segment(from: Vector3, to: Vector3) -> bool:
	return is_inside_tree() and AABB(from, Vector3.ZERO).expand(to).grow(BODY_RADIUS + 0.1).intersects(_collision_bounds)


func _sweep(from: Vector3, desired: Vector3, shape: Shape3D, offset: Vector3) -> Dictionary:
	var result: Dictionary = {"position": desired, "normal": Vector3.ZERO, "collided": false}
	var motion: Vector3 = desired - from
	if motion.length_squared() < 0.00000001:
		return result
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = race_world.global_transform * Transform3D(Basis.IDENTITY, from + offset)
	query.motion = race_world.global_basis * motion
	query.margin = CONTACT_MARGIN
	query.collision_mask = COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() < 2 or fractions[0] >= 0.999999:
		return result
	var safe_fraction: float = maxf(0.0, float(fractions[0]) - 0.004 / motion.length())
	var unsafe_fraction: float = minf(1.0, float(fractions[1]) + 0.006 / motion.length())
	query.transform.origin = race_world.to_global(from + motion * unsafe_fraction + offset)
	query.motion = Vector3.ZERO
	var rest: Dictionary = space.get_rest_info(query)
	var normal: Vector3 = -motion.normalized()
	if not rest.is_empty():
		normal = (race_world.global_basis.inverse() * (rest.normal as Vector3)).normalized()
	result.position = from + motion * safe_fraction
	result.normal = normal
	result.collided = true
	return result
