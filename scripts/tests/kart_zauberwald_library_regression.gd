extends SceneTree
## Actual production batching, road clearance, placement identity and RNG continuity.

const WORLD = preload("res://scripts/games/kart_world.gd")
const PREVIOUS = preload("res://scripts/tests/helpers/kart_zauberwald_previous_forest.gd")
const DETAIL = preload("res://scripts/games/kart_track_detail.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[ZauberwaldLibrary] FAIL ", message)


func _records(world) -> Dictionary:
	var result: Dictionary = {}
	for key in world.groups:
		var group: Dictionary = world.groups[key]
		for i in range(group.transforms.size()):
			var signature := str(key) + str(group.transforms[i]) + str(group.colors[i])
			result[signature] = int(result.get(signature, 0)) + 1
	return result


func _run() -> void:
	for low: bool in [true, false]:
		var previous = PREVIOUS.new()
		root.add_child(previous)
		previous.build(low, "zauberwald", true)
		var current = WORLD.new()
		root.add_child(current)
		current.build(low, "zauberwald", true)
		var before_sites: Array = previous.get_meta("reference_detail_sites")
		var after_sites: Array = current.get_meta("reference_detail_sites")
		_check(before_sites == after_sites, "Every accepted site retains its exact position")
		_check(
			current._rng.state == previous._rng.state, "Omitted trees preserve the full RNG stream"
		)
		var previous_records := _records(previous)
		var current_records := _records(current)
		for signature in current_records:
			_check(previous_records.has(signature), "No unaffected geometry is moved or recolored")
			_check(
				int(previous_records.get(signature, 0)) >= int(current_records[signature]),
				"Geometry multiplicity preserved"
			)
		var reservations: Array = DETAIL.accepted_sites(current)
		_check(reservations.size() == after_sites.size(), "Planner covers all actual sites")
		for site in reservations:
			_check(
				not current._near_road(site.position, 8.5 + float(site.radius)), "Site clears road"
			)
			if not site.large:
				continue
			for cluster in current.get_meta("forest_library_retained_clusters"):
				var a: Vector3 = site.position
				var b: Vector3 = cluster.position
				_check(
					(
						Vector2(a.x - b.x, a.z - b.z).length()
						>= float(site.radius) + float(cluster.radius)
					),
					"Remaining forest crown clears the library footprint"
				)
		var cleared: int = current.get_meta("forest_library_cleared_clusters")
		_check(cleared > 0 and cleared < 40, "Existing overlap repaired with bounded removal")
		_check(
			current.decoration_count < previous.decoration_count,
			"Omitted geometry leaves actual batches"
		)
		print(
			"[ZauberwaldLibrary] low=",
			low,
			" cleared_clusters=",
			cleared,
			" retained_clusters=",
			current.get_meta("forest_library_retained_clusters").size(),
			" removed_parts=",
			previous.decoration_count - current.decoration_count
		)
		previous.queue_free()
		current.queue_free()
		await process_frame
	print("[ZauberwaldLibrary] ", "PASS" if failures == 0 else "FAIL", " checks=", checks)
	quit(0 if failures == 0 else 1)
