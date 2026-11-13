extends Node3D
## World-space tyre/exhaust paths and bounded feedback for real race events.
## The race owns timing: pausing, countdown and scene replacement need no timer.

enum Event { BOOST, LANDING, PICKUP }

const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const TRAIL_CAPACITY := 128
const EVENT_CAPACITY := 6
const STARS_PER_EVENT := 8
const CONTACT_START := EVENT_CAPACITY * STARS_PER_EVENT
const BLUE := Color("5edfff")
const ORANGE := Color("ffb345")
const GOLD := Color("ffdc72")
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
const EVENT_LIFETIMES: Array[float] = [0.42, 0.52, 0.58]

var reduced_motion: bool = false
var _vehicle: Node3D
var _tyres: Array[Node3D] = []
var _exhausts: Array[Node3D] = []
var _trails: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var _stars: MultiMeshInstance3D
var _trail_ages := PackedFloat32Array()
var _trail_lives := PackedFloat32Array()
var _trail_colors := PackedColorArray()
var _previous := PackedVector3Array()
var _connected := PackedByteArray()
var _event_ages := PackedFloat32Array()
var _event_kinds := PackedInt32Array()
var _event_origins := PackedVector3Array()
var _event_colors := PackedColorArray()
var _event_power := PackedFloat32Array()
var _event_bases: Array[Basis] = []
var _trail_cursor: int = 0
var _event_cursor: int = 0
var _boost_seen: bool = false
var _last_position := Vector3.ZERO
var _position_valid: bool = false
var _clock: float = 0.0
var _contacts_visible: int = 0
var _reset_clean: bool = false


func _ready() -> void:
	name = "KartDriveFeedback"
	_trail_ages.resize(TRAIL_CAPACITY)
	_trail_lives.resize(TRAIL_CAPACITY)
	_trail_colors.resize(TRAIL_CAPACITY)
	_previous.resize(4)
	_connected.resize(4)
	_event_ages.resize(EVENT_CAPACITY)
	_event_kinds.resize(EVENT_CAPACITY)
	_event_origins.resize(EVENT_CAPACITY)
	_event_colors.resize(EVENT_CAPACITY)
	_event_power.resize(EVENT_CAPACITY)
	_event_bases.resize(EVENT_CAPACITY)
	_trails = _batch("TyreAndExhaustRibbons", _ribbon_mesh(), TRAIL_CAPACITY)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.94
	ring.outer_radius = 1.0
	ring.rings = 36
	ring.ring_segments = 6
	_rings = _batch("EventContactRings", ring, EVENT_CAPACITY * 2)
	_stars = _batch("LumoEnergyStars", SHAPES.star(), CONTACT_START + 2)
	reset()
	set_process(false)


func bind_vehicle(vehicle: Node3D) -> void:
	_vehicle = vehicle
	_tyres.clear()
	_exhausts.clear()
	# Existing spark roots are at the actual wheel contact points for each kart.
	for spark in vehicle.sparks:
		_tyres.append(spark)
	_tyres.sort_custom(
		func(a: Node3D, b: Node3D) -> bool:
			return vehicle.to_local(a.global_position).z > vehicle.to_local(b.global_position).z
	)
	if _tyres.size() > 2:
		_tyres.resize(2)
	for flame in vehicle.flames:
		if _exhausts.size() < 2:
			_exhausts.append(flame)
	reset()


func advance(
	delta: float, enabled: bool, paused: bool, airborne: bool, reduce_motion: bool
) -> void:
	if not is_instance_valid(_vehicle):
		reset()
		return
	if paused:
		return
	if not enabled:
		reset()
		return
	if reduce_motion != reduced_motion:
		_clear_trails()
	reduced_motion = reduce_motion
	var step := maxf(0.0, delta)
	_clock += step
	_advance_trails(step)
	_advance_events(step)
	var position := _vehicle.global_position
	var speed: float = absf(_vehicle.motion_speed)
	var teleported: bool = (
		_position_valid
		and position.distance_to(_last_position) > maxf(4.0, speed * step * 2.0 + 1.0)
	)
	if teleported:
		reset()
	elif step > 0.12:
		_clear_trails()
	_reset_clean = false
	_last_position = position
	_position_valid = true
	var drifting: bool = (
		_vehicle.motion_drift and absf(_vehicle.motion_steer) > 0.2 and speed > 1.0 and not airborne
	)
	var boosting: bool = _vehicle.motion_boost and speed > 0.5
	var tier: int = clampi(_vehicle.drift_spark_tier, 0, 2)
	var drift_color: Color = ORANGE if tier == 2 else BLUE if tier == 1 else Color("b9d7e6")
	if boosting and not _boost_seen and _event_count(Event.BOOST) == 0:
		boost_release(tier)
	_boost_seen = boosting
	var up: Vector3 = _vehicle.global_basis.y.normalized()
	for index in range(2):
		_sample_anchor(index, _tyres, drifting, up, drift_color, 0.11 + tier * 0.045, 0.28)
		_sample_anchor(index + 2, _exhausts, boosting, up, GOLD, 0.25, 0.38)
	_update_contacts(drifting, tier, drift_color)
	_update_bounds()
	_update_visibility()


func boost_release(tier: int = 0) -> void:
	if not is_instance_valid(_vehicle):
		return
	var at := _vehicle.global_position + _vehicle.global_basis * Vector3(0, 0.5, 1.0)
	var color: Color = BLUE if tier == 1 else GOLD
	var basis := _vehicle.global_basis.orthonormalized()
	basis = basis * Basis(Quaternion(Vector3.RIGHT, PI * 0.5))
	_event(Event.BOOST, at, basis, color, 1.0)


func landed(impact: float, rewarded: bool, surface_frame: Basis) -> void:
	if not is_instance_valid(_vehicle) or impact < 1.0:
		return
	# At this instant the chassis may still carry its flight pitch. The race
	# supplies the sampled road frame so the contact ring lies on the surface.
	var basis := surface_frame.orthonormalized()
	var at := _vehicle.global_position + basis.y * 0.075
	_event(
		Event.LANDING,
		at,
		basis,
		GOLD if rewarded else Color("d2c5ab"),
		clampf(impact / 9.0, 0.55, 1.4)
	)


func collect_item(world_position: Vector3, item: String) -> void:
	if not is_instance_valid(_vehicle):
		return
	var color: Color = BLUE if item == "shield" else Color("bd96ff") if item == "pulse" else GOLD
	_event(Event.PICKUP, world_position, Basis.IDENTITY, color, 1.0)


func reset() -> void:
	if _reset_clean:
		return
	_clear_trails()
	for index in range(EVENT_CAPACITY):
		_hide_event(index)
	for index in range(2):
		_stars.multimesh.set_instance_transform(CONTACT_START + index, HIDDEN)
	_contacts_visible = 0
	_position_valid = false
	_boost_seen = false
	_event_cursor = 0
	_update_visibility()
	_reset_clean = true


func _sample_anchor(
	index: int,
	anchors: Array[Node3D],
	emitting: bool,
	up: Vector3,
	color: Color,
	width: float,
	lifetime: float
) -> void:
	var anchor_index := index % 2
	if reduced_motion or not emitting or anchor_index >= anchors.size():
		_connected[index] = 0
		return
	var point := to_local(anchors[anchor_index].global_position + up * 0.025)
	if _connected[index] == 1:
		var direction := point - _previous[index]
		var length := direction.length()
		if length > 0.035 and length < 8.0:
			var z := direction / length
			var local_up := global_basis.inverse() * up
			var x := local_up.cross(z).normalized()
			if x.length_squared() > 0.5:
				# Scale the local axes, so a bend cannot shorten or shear the ribbon.
				var basis := Basis(x * width, z.cross(x).normalized(), z * (length + 0.025))
				var transform := Transform3D(basis, (point + _previous[index]) * 0.5)
				_trails.multimesh.set_instance_transform(_trail_cursor, transform)
				_trails.multimesh.set_instance_color(_trail_cursor, color)
				_trail_ages[_trail_cursor] = 0.0
				_trail_lives[_trail_cursor] = lifetime
				_trail_colors[_trail_cursor] = color
				_trail_cursor = (_trail_cursor + 1) % TRAIL_CAPACITY
	_previous[index] = point
	_connected[index] = 1


func _clear_trails() -> void:
	_connected.fill(0)
	_trail_cursor = 0
	_trail_lives.fill(0.0)
	for index in range(TRAIL_CAPACITY):
		_trails.multimesh.set_instance_transform(index, HIDDEN)


func _advance_trails(delta: float) -> void:
	for index in range(TRAIL_CAPACITY):
		if _trail_lives[index] <= 0.0:
			continue
		_trail_ages[index] += delta
		var remaining := 1.0 - _trail_ages[index] / _trail_lives[index]
		if remaining <= 0.0:
			_trail_lives[index] = 0.0
			_trails.multimesh.set_instance_transform(index, HIDDEN)
		else:
			var color := _trail_colors[index]
			color.a = remaining * remaining * 0.82
			_trails.multimesh.set_instance_color(index, color)


func _update_contacts(drifting: bool, tier: int, color: Color) -> void:
	_contacts_visible = 0
	var camera := get_viewport().get_camera_3d()
	for index in range(2):
		var instance := CONTACT_START + index
		if not drifting or index >= _tyres.size() or camera == null:
			_stars.multimesh.set_instance_transform(instance, HIDDEN)
			continue
		var at := to_local(_tyres[index].global_position)
		var size := 0.10 + tier * 0.075
		var basis := global_basis.inverse() * camera.global_basis
		if not reduced_motion:
			basis *= Basis(Quaternion(Vector3.BACK, _clock * 3.0))
		_stars.multimesh.set_instance_transform(
			instance, Transform3D(basis.scaled(Vector3.ONE * size), at)
		)
		_stars.multimesh.set_instance_color(instance, color.lightened(0.2))
		_contacts_visible += 1


func _event(kind: Event, at: Vector3, basis: Basis, color: Color, power: float) -> void:
	_reset_clean = false
	var slot := _event_cursor
	for index in range(EVENT_CAPACITY):
		if _event_kinds[index] < 0:
			slot = index
			break
	_event_cursor = (slot + 1) % EVENT_CAPACITY
	_hide_event(slot)
	_event_kinds[slot] = kind
	_event_ages[slot] = 0.0
	_event_origins[slot] = to_local(at)
	_event_bases[slot] = global_basis.inverse() * basis
	_event_colors[slot] = color
	_event_power[slot] = power
	_draw_event(slot)
	_update_bounds()
	_update_visibility()


func _advance_events(delta: float) -> void:
	for slot in range(EVENT_CAPACITY):
		if _event_kinds[slot] < 0:
			continue
		_event_ages[slot] += delta
		if _event_ages[slot] >= EVENT_LIFETIMES[_event_kinds[slot]]:
			_hide_event(slot)
		else:
			_draw_event(slot)


func _draw_event(slot: int) -> void:
	var kind := _event_kinds[slot]
	var progress := _event_ages[slot] / EVENT_LIFETIMES[kind]
	var origin := _event_origins[slot]
	var color := _event_colors[slot]
	var basis := _event_bases[slot]
	if kind == Event.PICKUP:
		var destination := to_local(
			_vehicle.global_position + _vehicle.global_basis * Vector3(0, 0.8, 0.3)
		)
		for index in range(STARS_PER_EVENT):
			var t := clampf(progress * 1.3 - float(index) * 0.035, 0.0, 1.0)
			var angle := float(index) * TAU / float(STARS_PER_EVENT)
			var arc := Vector3(cos(angle), 0.9, sin(angle)) * sin(t * PI)
			var at := origin.lerp(destination, t) + arc * (0.12 if reduced_motion else 0.55)
			color.a = (1.0 - smoothstep(0.65, 1.0, t)) * 0.9
			var size := 0.09 * (0.6 + sin(t * PI) * 0.4)
			var spin := Basis(Quaternion(Vector3.UP, angle + t * TAU))
			_stars.multimesh.set_instance_transform(
				slot * STARS_PER_EVENT + index, Transform3D(spin.scaled(Vector3.ONE * size), at)
			)
			_stars.multimesh.set_instance_color(slot * STARS_PER_EVENT + index, color)
		return
	for index in range(2):
		var t := clampf(progress * 1.2 - float(index) * 0.12, 0.0, 1.0)
		var radius := (0.55 + t * (2.0 if kind == Event.LANDING else 0.95)) * _event_power[slot]
		if reduced_motion:
			radius = 0.85 * _event_power[slot]
		color.a = pow(1.0 - t, 1.5) * (0.72 if index == 0 else 0.35)
		var at := origin + basis.y * (0.025 * index)
		var shape := Basis(basis.x * radius, basis.y * 0.36, basis.z * radius)
		_rings.multimesh.set_instance_transform(slot * 2 + index, Transform3D(shape, at))
		_rings.multimesh.set_instance_color(slot * 2 + index, color)


func _hide_event(slot: int) -> void:
	_event_kinds[slot] = -1
	for index in range(2):
		_rings.multimesh.set_instance_transform(slot * 2 + index, HIDDEN)
	for index in range(STARS_PER_EVENT):
		_stars.multimesh.set_instance_transform(slot * STARS_PER_EVENT + index, HIDDEN)


func _event_count(kind: int = -1) -> int:
	var count := 0
	for value in _event_kinds:
		if value >= 0 and (kind < 0 or value == kind):
			count += 1
	return count


func _update_visibility() -> void:
	var trails := 0
	for life in _trail_lives:
		if life > 0.0:
			trails += 1
	_trails.visible = trails > 0
	_rings.visible = _event_count(Event.BOOST) + _event_count(Event.LANDING) > 0
	_stars.visible = _contacts_visible > 0 or _event_count(Event.PICKUP) > 0


func _update_bounds() -> void:
	if not is_instance_valid(_vehicle):
		return
	var bounds := AABB(to_local(_vehicle.global_position) - Vector3.ONE * 80.0, Vector3.ONE * 160.0)
	_trails.multimesh.custom_aabb = bounds
	_rings.multimesh.custom_aabb = bounds
	_stars.multimesh.custom_aabb = bounds


func _batch(label: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.material_override = material
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = count
	add_child(batch)
	return batch


func _ribbon_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Array[float] = [-0.5, -0.16, 0.16, 0.5]
	var alpha: Array[float] = [0.0, 1.0, 1.0, 0.0]
	for strip in range(3):
		for corner in [
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(0, 1),
			Vector2i(1, 0),
			Vector2i(1, 1),
			Vector2i(0, 1)
		]:
			var edge: int = strip + corner.x
			surface.set_color(Color(1, 1, 1, alpha[edge]))
			surface.add_vertex(Vector3(edges[edge], 0.0, float(corner.y) - 0.5))
	surface.generate_normals()
	return surface.commit()


func visual_state() -> Dictionary:
	var trails := 0
	for life in _trail_lives:
		if life > 0.0:
			trails += 1
	return {
		"trail_segments": trails,
		"trail_capacity": TRAIL_CAPACITY,
		"events": _event_count(),
		"event_capacity": EVENT_CAPACITY,
		"boost_events": _event_count(Event.BOOST),
		"landing_events": _event_count(Event.LANDING),
		"pickup_events": _event_count(Event.PICKUP),
		"contacts": _contacts_visible,
		"batch_count": get_child_count(),
		"clock": _clock,
		"reduced_motion": reduced_motion,
	}
