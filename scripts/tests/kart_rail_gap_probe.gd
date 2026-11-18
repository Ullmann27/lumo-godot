extends SceneTree
## Measurement only (changes nothing): how far is the kart's flank from the
## drawn rail when the collision wall stops it? Per course, every 2 m:
##   gap = (RAIL_LATERAL - half rail beam) - wall_lateral_at(d) - half kart width
## Prints one table row per course plus the sections where the gap exceeds 0.5 m.
## godot --headless --path . --script res://scripts/tests/kart_rail_gap_probe.gd

const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const BEAM_HALF := 0.07
const STEP := 2.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "rail-gap-probe"}
	var only := OS.get_environment("LUMO_TRACKS")
	var rows: Array[String] = []
	for entry in CATALOG.TRACKS:
		var track: String = str(entry.id)
		if not only.is_empty() and not track in only.split(","):
			continue
		var game = load("res://scenes/games/kart_island.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		game._start_selected_race({
			"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "gemuetlich"
		})
		await process_frame
		var world = game.world
		var half_width := _half_width(game.player)
		var rail: float = float(world.get("RAIL_LATERAL")) if world.get("RAIL_LATERAL") != null else NAN
		var length: float = float(game.track_length)
		var gaps := PackedFloat32Array()
		var sections: Array[String] = []
		var open_start := -1.0
		var worst := -INF
		var d := 0.0
		while d < length:
			var wall: float = float(world.wall_lateral_at(d))
			var gap := rail - BEAM_HALF - wall - half_width
			gaps.append(gap)
			worst = maxf(worst, gap)
			if gap > 0.5 and open_start < 0.0:
				open_start = d
			elif gap <= 0.5 and open_start >= 0.0:
				sections.append("%d-%d m" % [int(open_start), int(d)])
				open_start = -1.0
			d += STEP
		if open_start >= 0.0:
			sections.append("%d-%d m" % [int(open_start), int(length)])
		var sorted := gaps.duplicate()
		sorted.sort()
		var median: float = sorted[sorted.size() / 2] if sorted.size() > 0 else NAN
		rows.append("| %s | %.0f m | %.2f | %.2f | %.2f | %.2f | %s |" % [
			track, length, float(world.wall_lateral_at(length * 0.25)), half_width, median, worst,
			", ".join(sections.slice(0, 6)) if not sections.is_empty() else "-"
		])
		print("[RailGap] ", rows[-1])
		game.abandoned = true
		game.queue_free()
		await process_frame
		await process_frame
	print("[RailGap] | Strecke | Länge | Wand (typisch) | halbe Kartbreite | Abstand Median | Abstand max | Abschnitte > 0,5 m |")
	for row in rows:
		print("[RailGap] ", row)
	quit(0)


## Outer edge of the tyres (the part that meets a rail), from the wheel pivots.
func _half_width(kart: Node3D) -> float:
	var widest := 0.0
	var widest_name := ""
	for pivot in kart.wheel_pivots:
		for node in pivot.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null:
				continue
			var box: AABB = kart.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			var edge := maxf(absf(box.position.x), absf(box.end.x))
			if edge > widest:
				widest = edge
				widest_name = str(mesh.name)
	if widest <= 0.0:
		for pivot in kart.wheel_pivots:
			widest = maxf(widest, absf(kart.to_local(pivot.global_position).x) + 0.15)
	print("[RailGap] tyre edge %.3f (%s)" % [widest, widest_name])
	return widest
