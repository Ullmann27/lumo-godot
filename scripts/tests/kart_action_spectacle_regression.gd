extends SceneTree
## Production-world and contact regression, not a text/source-pattern assertion.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const SPECTACLE = preload("res://scripts/games/kart_course_spectacle.gd")
const PARTS = preload("res://scripts/games/kart_part_catalog.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const SPEED_ZONE = preload("res://scripts/games/kart_stunt_speed_zone.gd")
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



## Real mounted parts enter the actual contact integrator. All runners start at
## the same seam with the same momentum; no fabricated progress or mock physics.
func _loop_parts(world) -> void:
	var data: Dictionary = world.loop_layout
	if data.is_empty():
		return
	var base: Dictionary = FLEET.multipliers(FLEET.base_stats("comet"), FLEET.entry("comet").traits)
	var engine: Dictionary = PARTS.apply(base, {"engine": "axial"})
	var brakes: Dictionary = PARTS.apply(base, {"brakes": "keramik"})
	var handling: Dictionary = PARTS.apply(base, {"steering": "vector", "tires": "performance"})
	var stock = LOOP.new()
	var series = LOOP.new()
	var drive = LOOP.new()
	var stop_stock = LOOP.new()
	var stop_parts = LOOP.new()
	var steer_stock = LOOP.new()
	var steer_parts = LOOP.new()
	stock.enter(data, 30.0, 0.0)
	series.enter(data, 30.0, 0.0, 0.0, 0.0, base)
	drive.enter(data, 30.0, 0.0, 0.0, 0.0, engine)
	stop_stock.enter(data, 30.0, 0.0)
	stop_parts.enter(data, 30.0, 0.0, 0.0, 0.0, brakes)
	steer_stock.enter(data, 30.0, 0.0)
	steer_parts.enter(data, 30.0, 0.0, 0.0, 0.0, handling)
	var step: float = 1.0 / 120.0
	for tick in range(60):
		var before: float = stock.speed
		var slope: float = (-LOOP.frame_at(world, data, stock.progress).z).y
		var a: Transform3D = stock.advance(world, step, 0.0, 0.0, true)
		var b: Transform3D = series.advance(world, step, 0.0, 0.0, true)
		_check(absf(stock.speed - (before + (-LOOP.GRAVITY * slope + 0.9) * step)) < 0.00001, "stock loop keeps the original gravity and throttle equation")
		_check(absf(stock.speed - series.speed) < 0.00001 and a.origin.distance_to(b.origin) < 0.00001, "empty and stock workshop factors drive identically")
		drive.advance(world, step, 0.0, 0.0, true)
		stop_stock.advance(world, step, 0.0, 1.0, false)
		stop_parts.advance(world, step, 0.0, 1.0, false)
		if tick < 12:
			steer_stock.advance(world, step, 0.5, 0.0, true)
			steer_parts.advance(world, step, 0.5, 0.0, true)
	_check(drive.speed > stock.speed + 0.02 and drive.progress > stock.progress, "mounted axial engine gains real loop momentum and distance")
	_check(stop_parts.speed < stop_stock.speed - 0.25 and stop_parts.progress < stop_stock.progress, "mounted ceramic brakes shorten the travelled loop distance")
	_check(steer_parts.lateral > steer_stock.lateral + 0.004, "mounted steering and tires change actual lateral contact")
	var maximum: Dictionary = {}
	for key in PARTS.PART_LIMITS:
		maximum[key] = PARTS.PART_LIMITS[key][1]
	var bounded = LOOP.new()
	bounded.enter(data, 35.0, 0.0, 0.0, 0.0, maximum)
	var elapsed: float = 0.0
	while bounded.active and elapsed < 10.0:
		bounded.advance(world, step, 1.0, 0.0, true)
		_check(absf(bounded.lateral) <= float(data.get("lateral_limit", LOOP.LATERAL_LIMIT)) + 0.0001, "combined controls stay inside the rendered loop deck")
		elapsed += step
	_check(not bounded.active and not bounded.failed, "strongest combined controls still traverse the complete branch")
	print("[KartSpectacle] loop controls stock=", snappedf(stock.speed, 0.001), " engine=", snappedf(drive.speed, 0.001),
		" brake_stock=", snappedf(stop_stock.speed, 0.001), " brake_parts=", snappedf(stop_parts.speed, 0.001),
		" steering_stock=", snappedf(steer_stock.lateral, 0.001), " steering_parts=", snappedf(steer_parts.lateral, 0.001))



## Stress the complete real approach with ordinary brake integration, including
## a carried-in speed higher than any simultaneous catalogue setup can sustain.
func _precision_approach(world) -> void:
	var zone: Dictionary = SPEED_ZONE.of(world)
	_check(not zone.is_empty(), "Sonnenhafen has a planned visible precision approach")
	if zone.is_empty():
		return
	_check(float(zone.start) > 80.0, "braking approach leaves the start corridor clear")
	_check(float(zone.take_off) + float(zone.landing_reserve) <= float(zone.tunnel) - 7.999, "all real road elevations fit inside the reserved landing corridor")
	_check(float(world.loop_layout.start) + LOOP.advance_of(world.loop_layout) + 24.999 <= float(zone.start), "loop returns and settles before the braking approach")
	for kicker in world.action.kickers:
		if not bool(kicker.get("stunt", false)):
			_check(float(kicker.take_off) < float(zone.start) or float(kicker.start) > float(zone.tunnel), "ordinary ramps do not interrupt precision braking")
	var profiles: Array[Dictionary] = []
	for kart in FLEET.KARTS:
		profiles.append(PARTS.apply(FLEET.multipliers(FLEET.base_stats(str(kart.id)), kart.traits), {"brakes": "leicht"}))
	for factors in profiles:
		var d: float = float(zone.start)
		var speed: float = float(zone.max_entry)
		var step: float = 1.0 / 120.0
		var count: int = 0
		while d < float(zone.take_off) and count < 3600:
			var limit: float = SPEED_ZONE.speed_limit(world, d, factors)
			var brake: float = POWERTRAIN.acceleration(factors, true)
			var previous: float = speed
			var target: float = minf(float(zone.max_entry), limit)
			speed = move_toward(speed, target, brake * step)
			_check(previous - speed <= brake * step + 0.00001, "precision approach uses normal brakes without a speed snap")
			d += speed * step
			count += 1
		_check(count < 3600 and speed <= float(zone.limit) + 0.01, "every stock fleet kart with light brakes reaches the ramp inside its physical speed envelope")
	print("[KartSpectacle] precision max_entry=", snappedf(float(zone.max_entry), 0.001),
		" min_brake=", snappedf(float(zone.minimum_brake), 0.001), " lip_limit=", snappedf(float(zone.limit), 0.001),
		" approach_m=", snappedf(float(zone.safe_at) - float(zone.start), 0.1),
		" landing_reserve_m=", snappedf(float(zone.landing_reserve), 0.1))



## Inspect actual instantiated meshes, including their complete radial extent.
## This catches the old fixed mountain ring and planets that hide a driving view.
func _backdrop_clearance(world) -> void:
	if str(world.track_id) == "zauberwald":
		var checked: int = 0
		for child in world.get_children():
			if not child is MultiMeshInstance3D or not str(child.name).begins_with("Decor_mountain_background"):
				continue
			var mesh: MultiMesh = child.multimesh
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for i in range(mesh.instance_count):
				var transform: Transform3D = child.transform * mesh.get_instance_transform(i)
				var radius: float = 0.0
				for vertex in vertices:
					var p: Vector3 = transform.basis * vertex
					radius = maxf(radius, Vector2(p.x, p.z).length())
				_check(not world._near_road(transform.origin, radius + float(world.WIDTH) * 0.5 + 3.0),
					"Zauberwald's actual mountain footprint clears the entire driving corridor")
				checked += 1
		_check(checked == 12, "Zauberwald retains all 12 background mountains")
		print("[KartSpectacle] zauberwald complete mountain footprints=", checked)
	if str(world.track_id) == "galaxy_ringway":
		var checked: int = 0
		for child in world.get_children():
			if not child is MultiMeshInstance3D or not str(child.name).begins_with("Decor_torus"):
				continue
			var mesh: MultiMesh = child.multimesh
			for i in range(mesh.instance_count):
				var transform: Transform3D = child.transform * mesh.get_instance_transform(i)
				var radius: float = maxf(transform.basis.x.length(), transform.basis.z.length()) * 0.5
				var tint: Color = mesh.get_instance_color(i)
				var expected: Color = Color("edbd91")
				# GPU MultiMesh colors use half-float storage, including in realGL.
				var tint_error: float = maxf(absf(tint.r - expected.r), maxf(absf(tint.g - expected.g), absf(tint.b - expected.b)))
				if tint_error > 1.0 / 1024.0 or radius < 11.99:
					continue
				_check(not world._near_road(transform.origin, radius + float(world.WIDTH) * 0.5 + 3.9),
					"Galaxy's actual planet rings clear the entire driving corridor")
				for n in range(65):
					var p: Vector3 = LOOP.point(world, world.loop_layout, float(n) / 64.0)
					_check(Vector2(p.x - transform.origin.x, p.z - transform.origin.z).length() >= radius + 3.5,
						"Galaxy's actual planet rings clear the exterior loop")
				checked += 1
		_check(checked >= 5, "Galaxy retains its full roadside planet sequence")
		print("[KartSpectacle] galaxy complete planet ring footprints=", checked)
		var giants: int = 0
		for child in world.get_children():
			if not child is MultiMeshInstance3D or not str(child.name).begins_with("Decor_ball"):
				continue
			var mesh: MultiMesh = child.multimesh
			for i in range(mesh.instance_count):
				var transform: Transform3D = child.transform * mesh.get_instance_transform(i)
				var radius: float = maxf(transform.basis.x.length(), maxf(transform.basis.y.length(), transform.basis.z.length()))
				if radius < 29.99:
					continue
				_check(not world._near_road(transform.origin, radius + float(world.WIDTH) * 0.5 + 3.9),
					"Galaxy's full60m hero planet clears every driving lane")
				for n in range(65):
					var at: Vector3 = LOOP.point(world, world.loop_layout, float(n) / 64.0)
					_check(Vector2(at.x - transform.origin.x, at.z - transform.origin.z).length() >= radius + 3.5,
						"Galaxy's full60m hero planet clears the exterior loop")
				giants += 1
		_check(giants >= 3, "Galaxy keeps all three giant curve planets")
		var visible_orbits: int = 0
		for child in world.get_children():
			if not child is MultiMeshInstance3D or not str(child.name).begins_with("Decor_torus"):
				continue
			var mesh: MultiMesh = child.multimesh
			for i in range(mesh.instance_count):
				var transform: Transform3D = child.transform * mesh.get_instance_transform(i)
				var radius: float = maxf(transform.basis.x.length(), transform.basis.z.length()) * 0.5
				if radius < 41.99:
					continue
				_check(radius > 30.0 + 10.0, "the hero orbit remains visibly outside its30m sphere")
				_check(not world._near_road(transform.origin, radius + float(world.WIDTH) * 0.5 + 3.9),
					"the full visible hero orbit clears every driving lane")
				for n in range(65):
					var at: Vector3 = LOOP.point(world, world.loop_layout, float(n) / 64.0)
					_check(Vector2(at.x - transform.origin.x, at.z - transform.origin.z).length() >= radius + 3.5,
						"the full visible hero orbit clears the optional loop")
				visible_orbits += 1
		_check(visible_orbits == giants, "every giant planet retains its visible outer orbit")
		print("[KartSpectacle] galaxy giant planet footprints=", giants, " visible orbits=", visible_orbits)


func _run() -> void:
	# Dummy rendering returns identity transforms and black colors for MultiMesh.
	# The geometry checks require the same real renderer as the capture.
	if DisplayServer.get_name() == "headless":
		printerr("[KartSpectacle] FAIL actual MultiMesh readback requires GL/Vulkan, use Xvfb")
		quit(1)
		return
	# 15 Produktionsstrecken plus die Signatur-Strecken (Team B1); jede wird unten geprüft.
	_check(TRACKS.IDS.size() >= 15, "all %d production circuits are covered" % TRACKS.IDS.size())
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
		_backdrop_clearance(world)
		var loop_report: Dictionary = _loop(world)
		if str(track) == "sonnenhafen":
			_loop_parts(world)
			_precision_approach(world)
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
