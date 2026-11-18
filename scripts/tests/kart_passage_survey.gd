extends SceneTree
## Messwerkzeug (kein Regressionstest): misst vor jedem Passagen-Umbau die echte,
## fertig geglättete Fahrbahn, alle Kartbreiten und die Fahrtempi.
## Aufruf: godot --headless --path . --script \
## res://scripts/tests/kart_passage_survey.gd -- [karts] [track_id ...]
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ids: Array = []
	for arg in OS.get_cmdline_user_args():
		ids.append(str(arg))
	if ids.is_empty() or "karts" in ids:
		await _karts()
		ids.erase("karts")
	_speeds()
	for id in ids:
		await _track(str(id))
	quit(0)


func _visual_box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inverse: Transform3D = node.global_transform.affine_inverse()
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var visual: VisualInstance3D = child
		if not visual.is_visible_in_tree() or visual is GPUParticles3D or visual is CPUParticles3D:
			continue
		var local: AABB = (inverse * visual.global_transform) * visual.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _karts() -> void:
	var vehicle_script: Script = load("res://scripts/games/kart_vehicle.gd")
	var widest := 0.0
	var widest_id := ""
	for id in FLEET.ids():
		var kart: Node3D = vehicle_script.new()
		root.add_child(kart)
		kart.configure("fox", Color("76d9ff"), id)
		await process_frame
		var box: AABB = _visual_box(kart)
		print(
			(
				"[Survey] kart %-12s width %.2f m  length %.2f m  height %.2f m"
				% [id, box.size.x, box.size.z, box.size.y]
			)
		)
		if box.size.x > widest:
			widest = box.size.x
			widest_id = id
		kart.queue_free()
		await process_frame
	print("[Survey] widest kart %s %.2f m" % [widest_id, widest])


func _speeds() -> void:
	var slowest := INF
	var slowest_id := ""
	var weakest_accel := INF
	for id in FLEET.ids():
		var factors: Dictionary = FLEET.multipliers(FLEET.base_stats(id), FLEET.entry(id).traits)
		var top: float = POWERTRAIN.top_speed(factors, 1.0)
		if top < slowest:
			slowest = top
			slowest_id = id
		weakest_accel = minf(weakest_accel, POWERTRAIN.acceleration(factors, false))
	for difficulty in CATALOG.DIFFICULTIES:
		var comet: float = POWERTRAIN.top_speed(
			FLEET.multipliers(FLEET.base_stats("comet")), float(difficulty.speed)
		)
		print(
			(
				"[Survey] %s: comet top %.1f m/s, slowest (%s) %.1f m/s, rival cruise comet %.1f m/s"
				% [
					difficulty.id,
					comet,
					slowest_id,
					slowest * float(difficulty.speed),
					comet * float(difficulty.rival)
				]
			)
		)
	print(
		(
			"[Survey] weakest acceleration %.1f m/s² (comet %.1f)"
			% [
				weakest_accel,
				POWERTRAIN.acceleration(FLEET.multipliers(FLEET.base_stats("comet")), false)
			]
		)
	)


func _radius(world, d: float) -> float:
	var a: Vector3 = world.forward(d - 6.0)
	var b: Vector3 = world.forward(d + 6.0)
	var turn: float = absf(angle_difference(atan2(a.x, a.z), atan2(b.x, b.z)))
	return 12.0 / maxf(turn, 0.0001)


func _track(id: String) -> void:
	var world_script: Script = load("res://scripts/games/kart_world.gd")
	var world: Node3D = world_script.new()
	root.add_child(world)
	world.build(true, id, true)
	await process_frame
	var length: float = world.length
	var tunnel: Dictionary = world.adventure_tunnel
	print(
		(
			"[Survey] track %s length %.1f m width %.1f m tunnel %s"
			% [
				id,
				length,
				world.road_width_at(1.0),
				"%.0f-%.0f m" % [tunnel.start, tunnel.end] if not tunnel.is_empty() else "-"
			]
		)
	)
	var action: Dictionary = world.action
	for key in ["pads", "kickers", "dives", "edges"]:
		for entry in action.get(key, []):
			print(
				(
					"[Survey]   action %s %.0f-%.0f"
					% [key, float(entry.start), float(entry.get("end", entry.get("take_off", 0.0)))]
				)
			)
	for gate in action.get("gates", []):
		if int(gate.index) == 0:
			print("[Survey]   action slalom from %.0f" % float(gate.distance))
	if id == "jungle_emerald_3600":
		var authored: PackedVector3Array = (
			load("res://scripts/games/kart_jungle_course.gd").author_points()
		)
		var planar_scale: float = 1.0
		for index in range(authored.size()):
			var best := 0.0
			var best_gap := INF
			var probe := 0.0
			while probe < length:
				var p: Vector3 = world.position_at(probe)
				var gap: float = Vector2(p.x, p.z).distance_to(
					Vector2(authored[index].x, authored[index].z) * planar_scale
				)
				if gap < best_gap:
					best_gap = gap
					best = probe
				probe += 2.0
			print(
				(
					"[Survey]   author %2d %s -> d %.0f (gap %.0f m)"
					% [index, authored[index], best, best_gap]
				)
			)
	var d := 0.0
	while d < length:
		var p: Vector3 = world.position_at(d)
		var grade: float = (world.position_at(d + 5.0).y - world.position_at(d - 5.0).y) / 10.0
		var bend: Vector3 = world.forward(d + 6.0) - world.forward(d - 6.0)
		var side: float = signf(world.frame(d).x.dot(bend))
		print(
			(
				"[Survey]   d %6.0f  y %5.1f  grade %+5.1f%%  radius %6.0f m %s  width %.1f"
				% [
					d,
					p.y,
					grade * 100.0,
					_radius(world, d),
					"R" if side > 0.0 else "L",
					world.road_width_at(d)
				]
			)
		)
		d += 10.0
	world.queue_free()
	await process_frame
