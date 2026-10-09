extends SceneTree

const Vehicle = preload("res://scripts/games/kart_vehicle.gd")
const World = preload("res://scripts/games/kart_world.gd")
# Numerical finish-state fixtures on real track geometry; the full race flow is a
# separate regression. Keep the fixed case payloads and thresholds unchanged.
const STEP: float = 1.0 / 60.0
const SOURCE_PATHS: Array[String] = [
	"scripts/games/kart_island.gd",
	"scripts/games/kart_vehicle.gd",
	"scripts/games/kart_world.gd",
	"project.godot",
	"scripts/tests/kart_finish_coast_regression.gd",
	"scripts/tests/kart_finish_coast_fixtures.gd",
]
var game: Variant
var rows: Array[Dictionary] = []
var poses: Array[Dictionary] = []
var observer_boxes: Array[Dictionary] = []
var observer_world: int = 0


func _init() -> void:
	call_deferred("_run")


func _row(name: String, passed: bool, actual: Variant) -> void:
	rows.append({"name": name, "passed": passed, "actual": actual})


func _snapshot() -> Dictionary:
	return {
		"elapsed": game.elapsed,
		"distance": game.distance,
		"checkpoint_index": game.checkpoint_index,
		"previous_road_distance": game.previous_road_distance,
		"lap_times": game.lap_times.duplicate(),
		"lap_started_at": game.lap_started_at,
		"result_id": game.result_id,
		"payload": game.result_payload.duplicate(true),
		"resets": game.reset_count
	}


func _setup(
	distance: float,
	lateral: float,
	angle: float,
	magnitude: float,
	reverse: bool = false,
	reduced: bool = false
) -> void:
	game.player.transform = Transform3D(
		game.world.frame(distance), game.world.position_at(distance, lateral)
	)
	var entry_road: Dictionary = game.world.sample_road(game.player.position, distance)
	game.player.position.y = (
		float(entry_road.height)
		+ 0.035
		+ game.world.ramp_height(float(entry_road.distance))
		+ game.world.alternate_route_height(float(entry_road.distance), float(entry_road.lateral))
	)
	var forward: Vector3 = game.world.forward(distance).rotated(Vector3.UP, deg_to_rad(angle))
	forward.y = 0.0
	forward = forward.normalized()
	game.player_heading = atan2(-forward.x, -forward.z)
	game.physical_velocity = forward * magnitude * (-1.0 if reverse else 1.0)
	game.speed = magnitude * (-1.0 if reverse else 1.0)
	game.lane = lateral
	game.elapsed = 85.517
	game.distance = game.world.length * 2.0
	game.previous_road_distance = distance
	game.checkpoint_index = 16
	game.lap_times.assign([42.283, 43.234])
	game.lap_started_at = 85.517
	game.result_id = "numerical-assigned-finish"
	game.result_payload = {
		"resultId": game.result_id,
		"elapsedSeconds": 85.517,
		"bestLapSeconds": 42.283,
		"stars": 3,
		"solved": 0,
		"checkpoints": 16
	}
	game.reset_count = 0
	game.wall_contacts = 0
	game.airborne = false
	game.vertical_speed = 0.0
	game.menu_active = false
	game.finished = true
	game.paused = false
	game.reduced_motion = reduced
	game.result_seen = false
	game.confetti_calls = 0
	game.camera.position = game.player.position - forward * 6.6 + Vector3.UP * 3.5
	game.camera.look_at(game.player.position + Vector3.UP * 1.25)


func _case(
	name: String,
	distance: float,
	lateral: float,
	angle: float,
	magnitude: float,
	reverse: bool = false,
	reduced: bool = false,
	frames: int = 192
) -> Dictionary:
	_setup(distance, lateral, angle, magnitude, reverse, reduced)
	var original: Dictionary = _snapshot()
	var start: Vector3 = game.player.position
	var start_basis: Basis = game.player.basis
	var velocity: Vector3 = game.physical_velocity
	game._start_finish_cine(1)
	var entry_kept: bool = (
		game.player.position == start
		and game.player.basis == start_basis
		and game.physical_velocity == velocity
	)
	var max_lane: float = 0.0
	var max_ground_error: float = 0.0
	var minimum_normal_dot: float = 1.0
	var minimum_camera_distance: float = INF
	var clear_camera: bool = true
	var frozen: bool = true
	var damping: bool = true
	var sign_kept: bool = true
	var max_velocity: float = velocity.length()
	var steps: int = 0
	var max_contacts_per_step: int = 0
	var max_camera_roll: float = 0.0
	var max_camera_orbit: float = 0.0
	var initial_camera_offset: Vector3 = game.camera.position - game.player.position
	var initial_camera_heading: float = atan2(initial_camera_offset.x, initial_camera_offset.z)
	for frame in range(frames + 1):
		if game.result_seen:
			break
		steps += 1
		var prior: float = game.physical_velocity.length()
		var contacts_before: int = game.wall_contacts
		game._physics_process(STEP)
		max_contacts_per_step = maxi(max_contacts_per_step, game.wall_contacts - contacts_before)
		damping = damping and game.physical_velocity.length() <= prior + 0.0001
		max_velocity = maxf(max_velocity, game.physical_velocity.length())
		frozen = frozen and _snapshot() == original
		sign_kept = sign_kept and (game.speed <= 0.00001 if reverse else game.speed >= -0.00001)
		sign_kept = (
			sign_kept
			and (
				game.player.motion_speed <= 0.00001
				if reverse
				else game.player.motion_speed >= -0.00001
			)
		)
		var hint: float = game.previous_road_distance
		if game.get("finish_road_distance") != null:
			hint = float(game.get("finish_road_distance"))
		var road: Dictionary = game.world.sample_road(game.player.position, hint)
		max_lane = maxf(max_lane, absf(float(road.lateral)))
		var height: float = (
			float(road.height)
			+ 0.035
			+ game.world.ramp_height(float(road.distance))
			+ game.world.alternate_route_height(float(road.distance), float(road.lateral))
		)
		max_ground_error = maxf(max_ground_error, absf(game.player.position.y - height))
		minimum_normal_dot = minf(
			minimum_normal_dot, game.player.basis.y.dot((road.basis as Basis).y)
		)
		var target: Vector3 = game.player.position + Vector3.UP * 1.25
		minimum_camera_distance = minf(
			minimum_camera_distance, game.camera.position.distance_to(target)
		)
		clear_camera = clear_camera and _camera_segment_clear(target, game.camera.position)
		max_camera_roll = maxf(max_camera_roll, absf(game.camera.rotation.z))
		var camera_offset: Vector3 = game.camera.position - game.player.position
		max_camera_orbit = maxf(
			max_camera_orbit,
			absf(angle_difference(initial_camera_heading, atan2(camera_offset.x, camera_offset.z)))
		)
		poses.append(
			{
				"case": name,
				"frame": frame,
				"position": str(game.player.position),
				"velocity": str(game.physical_velocity),
				"speed": game.speed,
				"lane": float(road.lateral),
				"ground_error": game.player.position.y - height,
				"camera_distance": game.camera.position.distance_to(target)
			}
		)
	var stopped: bool = (
		game.finish_cine_left <= 0.00001
		and game.result_seen
		and steps >= frames
		and steps <= frames + 1
	)
	return {
		"entry_kept": entry_kept,
		"max_lane": max_lane,
		"max_ground_error": max_ground_error,
		"minimum_normal_dot": minimum_normal_dot,
		"minimum_camera_distance": minimum_camera_distance,
		"clear_camera": clear_camera,
		"frozen": frozen,
		"damping": damping,
		"sign_kept": sign_kept,
		"stopped": stopped,
		"wall_contacts": game.wall_contacts,
		"displacement": start.distance_to(game.player.position),
		"end_speed": game.speed,
		"max_velocity": max_velocity,
		"confetti_calls": game.confetti_calls,
		"steps": steps,
		"max_contacts_per_step": max_contacts_per_step,
		"max_camera_roll": max_camera_roll,
		"max_camera_orbit": max_camera_orbit
	}


func _camera_segment_clear(target: Vector3, eye: Vector3) -> bool:
	if observer_world != game.world.get_instance_id():
		observer_world = game.world.get_instance_id()
		observer_boxes.clear()
		for child in game.world.get_children():
			if (
				not child is MultiMeshInstance3D
				or child.multimesh == null
				or not child.multimesh.mesh is BoxMesh
			):
				continue
			var mesh: MultiMesh = child.multimesh
			var bounds: AABB = mesh.mesh.get_aabb()
			for index in range(mesh.instance_count):
				var pose: Transform3D = child.global_transform * mesh.get_instance_transform(index)
				var scale_size: Vector3 = pose.basis.get_scale().abs()
				var margin := Vector3(
					0.15 / maxf(scale_size.x, 0.001),
					0.15 / maxf(scale_size.y, 0.001),
					0.15 / maxf(scale_size.z, 0.001)
				)
				observer_boxes.append(
					{
						"inverse": pose.affine_inverse(),
						"bounds": AABB(bounds.position - margin, bounds.size + 2.0 * margin)
					}
				)
	for box in observer_boxes:
		var inverse: Transform3D = box.inverse
		if (box.bounds as AABB).intersects_segment(inverse * target, inverse * eye):
			return false
	return true


func _valid(value: Dictionary) -> bool:
	return (
		value.entry_kept
		and value.max_lane <= 5.0001
		and value.max_ground_error <= 0.002
		and value.minimum_normal_dot >= 0.999
		and value.frozen
		and value.damping
		and value.sign_kept
		and value.stopped
	)


func _run() -> void:
	game = load("res://scripts/tests/kart_finish_coast_fixtures.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.player = Vehicle.new()
	game.add_child(game.player)
	game.player.set_process(false)
	game.camera = Camera3D.new()
	game.add_child(game.camera)
	game.message = Label.new()
	game.add_child(game.message)
	game.modal = PanelContainer.new()
	game.add_child(game.modal)
	game.controls_row = HBoxContainer.new()
	game.add_child(game.controls_row)
	game.world = World.new()
	game.add_child(game.world)
	game.world.build(true, "sonnenhafen", true)
	game.track_length = game.world.length
	game.mode = "race"
	var normal: Dictionary = _case("normal55degrees", 0.1, -0.649, -55.33, 17.015)
	_row("normal55degrees", _valid(normal), normal)
	var reduced: Dictionary = _case(
		"reduced55degrees", 0.1, -0.649, -55.33, 17.015, false, true, 21
	)
	_row("reduced55degrees", _valid(reduced), reduced)
	var zero: Dictionary = _case("zero_velocity", 12.0, 0.0, 0.0, 0.0)
	_row(
		"zero_velocity",
		_valid(zero) and zero.displacement < 0.002 and zero.max_velocity == 0.0,
		zero
	)
	var near: Dictionary = _case("near_zero_velocity", 12.0, 0.0, 0.0, 0.03)
	_row(
		"near_zero_velocity",
		_valid(near) and near.displacement < 0.002 and near.end_speed == 0.0,
		near
	)
	var reverse: Dictionary = _case("reverse_velocity_and_wheels", 12.0, 0.0, 0.0, 5.0, true)
	_row("reverse_velocity_and_wheels", _valid(reverse), reverse)
	var left: Dictionary = _case("left_edge_outward_contact", 12.0, -4.98, 55.0, 17.0)
	_row(
		"left_edge_outward_contact",
		_valid(left) and left.wall_contacts > 0 and left.max_contacts_per_step <= 1,
		left
	)
	var right: Dictionary = _case("right_edge_outward_contact", 12.0, 4.98, -55.0, 17.0)
	_row(
		"right_edge_outward_contact",
		_valid(right) and right.wall_contacts > 0 and right.max_contacts_per_step <= 1,
		right
	)
	var curve: Dictionary = _case(
		"curved_segment_contact", game.world.length * 0.14, 0.0, 0.0, 20.0
	)
	_row("curved_segment_contact", _valid(curve), curve)
	var slope: Dictionary = _case("sloped_surface_ground", game.world.length * 0.30, 0.0, 0.0, 10.0)
	_row("sloped_surface_ground", _valid(slope), slope)
	game.remove_child(game.world)
	game.world.queue_free()
	await process_frame
	game.world = World.new()
	game.add_child(game.world)
	game.world.build(true, "bergwelt", true)
	game.track_length = game.world.length
	var ramp: Dictionary = _case(
		"ramp_surface_ground", float(game.world.jump.ramp_start) + 1.0, 0.0, 0.0, 1.0
	)
	_row("ramp_surface_ground", _valid(ramp), ramp)
	_setup(0.1, 0.0, 0.0, 0.0)
	game.airborne = true
	game.player.position.y += 3.0
	game.vertical_speed = 4.0
	var air_start: Vector3 = game.player.position
	game._start_finish_cine(1)
	game._physics_process(STEP)
	_row(
		"airborne_gravity",
		(
			game.airborne
			and game.vertical_speed < 4.0
			and game.player.position.y > air_start.y
			and (
				game.player.position.y
				> float(game.world.sample_road(game.player.position).height) + 2.0
			)
		),
		{
			"position": str(game.player.position),
			"vertical_speed": game.vertical_speed,
			"airborne": game.airborne
		}
	)
	_setup(0.1, 0.0, 0.0, 12.0)
	game._start_finish_cine(1)
	game.paused = true
	var pause_position: Vector3 = game.player.position
	var pause_velocity: Vector3 = game.physical_velocity
	var pause_timer: float = game.finish_cine_left
	game._physics_process(STEP)
	_row(
		"pause_freezes_coast",
		(
			game.player.position == pause_position
			and game.physical_velocity == pause_velocity
			and game.finish_cine_left == pause_timer
		),
		{"position": str(game.player.position), "timer": game.finish_cine_left}
	)
	game.paused = false
	game._skip_finish_cine()
	_row(
		"skip_does_not_move",
		(
			game.player.position == pause_position
			and game.finish_cine_left == 0.0
			and game.result_seen
		),
		{
			"position": str(game.player.position),
			"timer": game.finish_cine_left,
			"result_seen": game.result_seen
		}
	)
	_row(
		"progress_payload_remain_frozen",
		normal.frozen and reduced.frozen and left.frozen and right.frozen and ramp.frozen,
		{
			"normal": normal.frozen,
			"reduced": reduced.frozen,
			"left": left.frozen,
			"right": right.frozen,
			"ramp": ramp.frozen
		}
	)
	_row(
		"actual_box_camera_clearance",
		(
			normal.clear_camera
			and reduced.clear_camera
			and left.clear_camera
			and right.clear_camera
			and normal.minimum_camera_distance >= 2.2
			and left.minimum_camera_distance >= 2.2
			and right.minimum_camera_distance >= 2.2
		),
		{
			"normal": normal.minimum_camera_distance,
			"left": left.minimum_camera_distance,
			"right": right.minimum_camera_distance,
			"normal_clear": normal.clear_camera,
			"left_clear": left.clear_camera,
			"right_clear": right.clear_camera
		}
	)
	_row(
		"reduced_motion_camera_no_orbit_roll",
		(
			reduced.confetti_calls == 0
			and reduced.max_camera_roll < 0.0001
			and reduced.max_camera_orbit < 0.15
		),
		{
			"confetti_calls": reduced.confetti_calls,
			"max_camera_roll": reduced.max_camera_roll,
			"max_camera_orbit": reduced.max_camera_orbit,
			"mechanism": "reduced branch uses ordinary chase instead of orbit"
		}
	)
	var failures: int = 0
	for row in rows:
		if not row.passed:
			failures += 1
			print("[PhysicalFinishCoast] FAIL: ", row.name, " ", row.actual)
	if rows.size() != 16:
		push_error("Physical finish regression requires exactly sixteen rows")
		quit(1)
		return
	var source_hashes: Dictionary = {}
	for source_path in SOURCE_PATHS:
		source_hashes[source_path] = FileAccess.get_sha256("res://" + source_path)
	var output: String = OS.get_environment("LUMO_QA_DIR")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://exports/finish-coast")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("numerical-evidence.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"status": "PASS" if failures == 0 else "FAIL",
				"source_sha256": FileAccess.get_sha256("res://scripts/games/kart_island.gd"),
				"source_hashes": source_hashes,
				"engine_executable_sha256": FileAccess.get_sha256(OS.get_executable_path()),
				"checks": rows,
				"failed": failures,
				"assigned_state_scope":
				"Sixteen finish motion/camera unit fixtures on actual geometry; not a driven race",
				"fixed_criteria":
				{
					"absolute_lateral_max_m": 5.0001,
					"ground_error_max_m": 0.002,
					"normal_dot_min": 0.999,
					"camera_distance_min_m": 2.2,
					"reduced_camera_roll_max_rad_exclusive": 0.0001,
					"reduced_camera_orbit_max_rad_exclusive": 0.15,
					"edge_contact_feedback_per_step_max": 1
				},
				"engine": Engine.get_version_info()
			},
			"\t"
		)
	)
	file.close()
	file = FileAccess.open(output.path_join("motion-frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(poses))
	file.close()
	game.queue_free()
	await process_frame
	await process_frame
	print(
		(
			"[PhysicalFinishCoast] %s: 16 numerical controls, %d failures"
			% ["PASS" if failures == 0 else "FAIL", failures]
		)
	)
	quit(0 if failures == 0 else 1)
