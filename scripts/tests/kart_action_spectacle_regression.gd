extends SceneTree
## Production-world and contact regression, not a text/source-pattern assertion.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const SPECTACLE = preload("res://scripts/games/kart_course_spectacle.gd")
var failures: Array[String] = []
var results: Array = []
var output: String = "/tmp/kart-action-coverage.json"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("[KartSpectacle] FAIL ", description)


func _sequence(world, entry: Dictionary) -> void:
	var label: String = str(world.track_id) + "/" + str(entry.kind)
	var begin: float = float(entry.start)
	var lead: float = float(entry.get("lead_m", 34.0))
	_check(SPECTACLE._free(begin, float(entry.end) - begin, SPECTACLE.of(world).get("base_blocked", []), lead), label + " keeps its complete geometry and approach outside every protected experience")
	_check(begin > 80.0 and float(entry.end) < world.length - 75.0, label + " protects start and finish")
	match str(entry.kind):
		"crest":
			_check(world.ramp_height(begin + 7.0) > 0.45, label + " changes actual contact height")
			_check(world.ramp_pitch(begin + 7.0) > 0.1, label + " changes actual launch pitch")
			var deck: MeshInstance3D = world.get_node_or_null("TrackRamp_%d" % int(begin))
			_check(deck != null, label + " has an actual ramp mesh")
			if deck != null:
				var vertices: PackedVector3Array = deck.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var half: float = world.road_width_at(begin) * 0.5
				var expected: Vector3 = world.position_at(begin + 7.0, half) + world.frame(begin + 7.0).y * (world.ramp_height(begin + 7.0) + 0.012)
				var closest: float = INF
				for vertex in vertices:
					closest = minf(closest, vertex.distance_to(expected))
				_check(closest < 0.002, label + " actual mesh matches quadratic contact height across full road width")
			var crossed: Dictionary = ACTION.kicker_crossed(world.action, begin + 13.8, begin + 14.1)
			_check(bool(crossed.get("spectacle", false)), label + " is detected by swept takeoff")
			if not crossed.is_empty():
				var speed: float = 45.0
				var lift: float = minf(speed * sin(float(crossed.angle)) + float(crossed.lift_bonus), float(crossed.max_lift))
				var gravity: float = float(crossed.flight_gravity)
				var flight: float = (lift + sqrt(lift * lift + 2.0 * gravity * float(crossed.height))) / gravity
				_check(flight > 0.6, label + " has a meaningful physical flight")
				_check(speed * cos(float(crossed.angle)) * flight < float(entry.end) - (begin + 14.0), label + " lands in its reserved road corridor")
		"narrow":
			_check(world.wall_lateral_at(begin + 14.0) <= 3.401, label + " changes the real steering wall")
			var found: bool = false
			for piece in PIECES.pieces_of(world):
				if piece.type == "narrow" and absf(float(piece.start) - begin) < 0.01:
					found = true
			_check(found, label + " has matching visible wall geometry")
		"turbo":
			var matched: int = 0
			for pad in world.action.pads:
				if bool(pad.get("spectacle", false)) and float(pad.start) >= begin and float(pad.end) <= float(entry.end) + 0.01:
					matched += 1
					var d: float = (float(pad.start) + float(pad.end)) * 0.5
					_check(ACTION.pad_at(world.action, d, float(pad.lateral)) >= 0, label + " changes actual boost contact")
			_check(matched >= 2, label + " has distinct optional turbo lines")


func _loop(world) -> Dictionary:
	var data: Dictionary = world.loop_layout
	if data.is_empty():
		return {}
	_check(bool(data.get("branch", false)), str(world.track_id) + " loop is an exterior branch")
	var start: float = float(data.start)
	var finish: float = start + LOOP.advance_of(data)
	var sector: float = world.length / 8.0
	_check(floori(start / sector) == floori(finish / sector), str(world.track_id) + " failure cannot cross a checkpoint backwards")
	var start_error: float = LOOP.point(world, data, 0.0).distance_to(world.position_at(start, float(data.lane)))
	var end_error: float = LOOP.point(world, data, 1.0).distance_to(world.position_at(finish, LOOP.exit_lane(data)))
	_check(start_error < 0.001 and end_error < 0.001, str(world.track_id) + " both branch seams join the actual road")
	var clearance: float = INF
	for i in range(65):
		var u: float = 0.25 + float(i) / 128.0
		var at: Vector3 = LOOP.point(world, data, u)
		clearance = minf(clearance, world._nearest_horizontal(at).x)
		var basis: Basis = LOOP.frame_at(world, data, u)
		_check(absf(basis.determinant() - 1.0) < 0.001, str(world.track_id) + " loop contact frame remains orthonormal")
	_check(clearance > world.road_width * 0.5 + LOOP.half_width_of(data) + 2.0, str(world.track_id) + " ring clears every primary roadway")
	_check(LOOP.frame_at(world, data, 0.5).y.dot(Vector3.UP) < -0.9, str(world.track_id) + " loop actually inverts the kart")
	var state = LOOP.new()
	state.enter(data, 35.0, 1234.0)
	var step: float = 1.0 / 120.0
	var elapsed: float = 0.0
	var last: Vector3 = LOOP.point(world, data, 0.0) + LOOP.frame_at(world, data, 0.0).y * 0.045
	var longest_step: float = 0.0
	var highest: float = last.y
	var pose := Transform3D.IDENTITY
	while state.active and elapsed < 20.0:
		pose = state.advance(world, step, 0.0, 0.0, true)
		longest_step = maxf(longest_step, last.distance_to(pose.origin))
		highest = maxf(highest, pose.origin.y)
		last = pose.origin
		elapsed += step
	_check(not state.active and not state.failed, str(world.track_id) + " contact solver completes the whole branch")
	_check(longest_step < 0.55, str(world.track_id) + " traversal has no teleport")
	_check(pose.origin.distance_to(LOOP.point(world, data, 1.0) + LOOP.frame_at(world, data, 1.0).y * 0.045) < 0.002, str(world.track_id) + " solver lands exactly on the exit seam")
	var braking = LOOP.new()
	braking.enter(data, 17.0, 100.0)
	elapsed = 0.0
	while braking.active and elapsed < 8.0:
		pose = braking.advance(world, step, 0.0, 1.0, false)
		elapsed += step
	_check(braking.failed, str(world.track_id) + " insufficient momentum returns safely")
	var fallback: Transform3D = world.reset_transform(start, float(data.get("fail_lane", data.lane)))
	_check(pose.origin.distance_to(fallback.origin) < 0.001, str(world.track_id) + " failure uses the real entry road")
	return {"route_metres": LOOP.advance_of(data), "ring_clearance_m": clearance,
		"entry_error_m": start_error, "exit_error_m": end_error, "max_tick_distance_m": longest_step,
		"peak_y": highest, "contact_completed": not state.active and not state.failed, "braking_returned": braking.failed}


func _run() -> void:
	_check(TRACKS.IDS.size() == 15, "all 15 production circuits are covered")
	for track in TRACKS.IDS:
		var world = WORLD.new()
		root.add_child(world)
		world.build(true, track, true)
		var report: Dictionary = SPECTACLE.of(world)
		var actions: Array = report.get("actions", [])
		var sites: Array = report.get("sites", [])
		_check(actions.size() >= 2, str(track) + " gains at least two real action sequences")
		if actions.size() < 2:
			printerr("[KartSpectacle] planning ", track, " ", JSON.stringify({"length": world.length, "actions": actions, "blocked": report.get("base_blocked", [])}))
		_check(sites.size() >= 6, str(track) + " gains multiple distinct scenery clusters")
		_check(bool(report.get("built", false)), str(track) + " actually executes the renderer hook")
		_check(int(report.get("added_instances", 0)) >= 100, str(track) + " actually adds rendered geometry")
		for entry in actions:
			_sequence(world, entry)
		for site in sites:
			_check(not world._near_road(site.position, world.road_width_at(float(site.distance)) * 0.5 + float(site.radius) + 3.9), str(track) + " scenic footprint clears the whole road")
		var loop_report: Dictionary = _loop(world)
		var before: int = world.decoration_count
		SPECTACLE.build(world)
		_check(world.decoration_count == before, str(track) + " render hook is idempotent")
		results.append({"track": track, "length_m": world.length, "actions": actions,
			"new_landmarks": sites.size(), "new_instances": report.get("added_instances", 0),
			"loop": loop_report})
		print("[KartSpectacle] ", track, " actions=", actions.size(), " landmarks=", sites.size(), " loop=", not loop_report.is_empty())
		world.queue_free()
		await process_frame
		await process_frame
	var payload: Dictionary = {"status": "PASS" if failures.is_empty() else "FAIL", "tracks": results,
		"failure_count": failures.size(), "failures": failures, "engine": Engine.get_version_info().string}
	var parent: String = output.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(output, FileAccess.WRITE)
	_check(file != null, "can write coverage evidence")
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
		file.close()
	print("[KartSpectacle] ", "PASS" if failures.is_empty() else "FAIL", " tracks=", results.size(), " errors=", failures.size())
	quit(0 if failures.is_empty() else 1)
